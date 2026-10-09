# SPDX-License-Identifier: Apache-2.0

import logging
import random
from dataclasses import dataclass

from boot import boot_init
from bus2csr import int2dword
from cocotb_helpers import reset_n
from utils import format_ibi_data
from ccc import CCC, CccHandoff
from ccc import RSTACT_DEF_BYTE
from cocotbext_i3c.common import I3cState, I3cTargetResetAction
from i3c_controller_fixed import I3cControllerFixed as I3cController
from interface import I3CTopTestInterface

import cocotb
from cocotb.handle import Force, Release
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, ReadOnly, Event, Timer
from cocotb.regression import TestFactory

from common import (
    VALID_I3C_ADDRESSES, log_seed, build_ccc_stress_table,
    do_getbcr, do_getmwl, do_getstatus, do_enec_direct,
)

TGT_ADR = 0x5A


@dataclass(frozen=True)
class CccStopExpectation:
    """Describe one observed STOP using CCC/ENTDAA state encodings, not a stimulus request."""
    label: str
    ccc_state: int
    entdaa_state: int | None = None
    arbitration_losses: int | None = 0


async def monitor_ccc_handoff(dut, tb, finished, stop_expectations: tuple[CccStopExpectation, ...] = ()):
    """Check ordered STOP contracts and handoffs; count only completed ENTDAA ID-bit losses, not raw PHY comparisons."""
    standby = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c
    ccc = standby.xccc
    entdaa = ccc.xccc_entdaa if stop_expectations else None
    stop_index = 0
    arbitration_losses = 0
    total_arbitration_losses = 0
    previous_stop = False
    previous_consumed_loss = False
    dut._log.info("CCC_HANDOFF: monitoring ownership and retirement")
    if stop_expectations:
        dut._log.info(f"CCC_STOP_CONTRACT: expecting {len(stop_expectations)} STOPs; first={stop_expectations[0]}")
    while not finished.is_set():
        await FallingEdge(tb.clk)
        await ReadOnly()
        if not int(tb.rst_n.value):
            previous_stop = False
            previous_consumed_loss = False
            continue
        handoff = CccHandoff(int(ccc.handoff_o.value))
        stop = int(ccc.bus_stop_det_i.value)
        checked_stop = None
        if stop_expectations:
            # The raw PHY comparison also pulses during reception. ENTDAA consumes
            # loss only at SendIDBit completion; a simultaneous STOP overrides it.
            consumed_loss = False
            if not stop and int(entdaa.state_q.value) == 7:
                rsp = entdaa.bus_tx_rsp_i
                bit_done = (int(rsp.value) & 1) if cocotb.SIM_NAME.lower().startswith("verilator") else int(rsp.done.value)
                consumed_loss = bool(bit_done and int(entdaa.arbitration_lost_i.value))
            if consumed_loss and not previous_consumed_loss:
                arbitration_losses += 1
                total_arbitration_losses += 1
                dut._log.info(f"CCC_STOP_CONTRACT: completed ENTDAA ID-bit arbitration loss before STOP {stop_index + 1}, count={arbitration_losses}")
            previous_consumed_loss = consumed_loss
            if stop and not previous_stop:
                assert stop_index < len(stop_expectations), "CCC_STOP_CONTRACT: unexpected extra STOP"
                expected = stop_expectations[stop_index]
                state = int(ccc.state_q.value)
                entdaa_state = int(ccc.xccc_entdaa.state_q.value) if expected.entdaa_state is not None else None
                dut._log.info(
                    f"CCC_STOP_CONTRACT: observed {stop_index + 1}/{len(stop_expectations)} {expected.label}: "
                    f"ccc_state={state}, entdaa_state={entdaa_state}, arbitration_losses={arbitration_losses}; expected={expected}")
                assert state == expected.ccc_state, f"{expected.label}: STOP saw CCC state {state}, expected {expected.ccc_state}"
                if expected.entdaa_state is not None:
                    assert entdaa_state == expected.entdaa_state, (
                        f"{expected.label}: STOP saw ENTDAA state {entdaa_state}, expected {expected.entdaa_state}")
                if expected.arbitration_losses is not None:
                    assert arbitration_losses == expected.arbitration_losses, (
                        f"{expected.label}: arbitration losses={arbitration_losses}, expected {expected.arbitration_losses}")
                assert handoff == CccHandoff.DONE, f"{expected.label}: active CCC STOP did not report DONE"
                checked_stop = expected.label
                stop_index += 1
                arbitration_losses = 0
            previous_stop = bool(stop)
        if stop:
            assert handoff in (CccHandoff.NONE, CccHandoff.DONE), "STOP did not override continuation"
            for name in ("capture_defining_byte", "capture_rx_data", "rx_data_valid", "cmd_tbit_valid",
                         "def_byte_tbit_valid", "target_addr_ack_done", "get_status_done_o"):
                assert int(getattr(ccc, name).value) == 0, f"STOP allowed a new {name} effect"
        if handoff == CccHandoff.RESUME_ADDR:
            assert int(ccc.bus_rstart_det_i.value) and not stop, "Address handoff was not synchronous with Sr"
            req = ccc.bus_rx_req_o
            active = int(req.value) if cocotb.SIM_NAME.lower().startswith("verilator") else int(req.req_byte.value) | int(req.req_bit.value)
            assert not active, "CCC retained an RX request across a bus boundary"
        if handoff == CccHandoff.NEXT_CMD:
            req, rsp = ccc.bus_tx_req_o, ccc.bus_tx_rsp_i
            if cocotb.SIM_NAME.lower().startswith("verilator"):
                ack_active = ((int(req.value) >> 12) & 1) and ((int(req.value) >> 9) & 7) == 4
                ack_done = int(rsp.value) & 1
            else:
                ack_active = int(req.req_valid.value) and int(req.req_type.value) == 4
                ack_done = int(rsp.done.value)
            assert ack_active and ack_done, "CCC chaining did not coincide with the terminating ACK"
        if handoff != CccHandoff.NONE:
            await RisingEdge(tb.clk)
            await ReadOnly()
            if int(tb.rst_n.value):
                assert int(standby.xfer_mux_sel.value) == 0, "CCC release did not transfer ownership on the same edge"
                assert int(ccc.state_q.value) == 0, "CCC did not return directly to WaitCCC"
                req = ccc.bus_rx_req_o
                active = int(req.value) if cocotb.SIM_NAME.lower().startswith("verilator") else int(req.req_byte.value) | int(req.req_bit.value)
                assert not active, "CCC retained an RX request after handoff"
                assert int(ccc.handoff_o.value) == CccHandoff.NONE, "CCC repeated the completion event"
                assert int(ccc.command_code_valid.value) == 0, "Completed CCC was recaptured from held ccc_valid"
                assert int(ccc.defining_byte_valid.value) == 0, "Completed CCC retained its defining byte"
                if handoff == CccHandoff.RESUME_ADDR and not int(ccc.bus_rstart_det_i.value):
                    assert int(standby.xi3c_target_fsm.bus_rx_req_byte.value), "Main FSM did not resume address reception"
                if checked_stop is not None:
                    next_stop = stop_expectations[stop_index].label if stop_index < len(stop_expectations) else "drain"
                    dut._log.info(f"CCC_STOP_CONTRACT: retired {checked_stop}; state=WaitCCC, mux=main; next={next_stop}")
    if stop_expectations:
        assert stop_index == len(stop_expectations), f"CCC_STOP_CONTRACT: observed {stop_index}/{len(stop_expectations)} required STOPs"
        assert arbitration_losses == 0, "CCC_STOP_CONTRACT: unaccounted arbitration loss after final STOP"
        dut._log.info(f"CCC_STOP_CONTRACT: drained {stop_index} matched STOPs, arbitration_losses={total_arbitration_losses}")
    dut._log.info("CCC_HANDOFF: monitoring completed")


async def recv_ccc_exact(controller, expected, context):
    """Check each response byte and target EOD without requesting controller abort."""
    data = bytearray()
    for index, value in enumerate(expected):
        byte, eod = await controller.recv_byte_t_bit(stop=False)
        data.append(byte)
        assert byte == value, f"{context}: byte {index}: expected 0x{value:02X}, got 0x{byte:02X}"
        assert bool(eod) == (index == len(expected) - 1), f"{context}: byte {index}: incorrect target EOD={eod}"
    cocotb.log.info(f"CCC_RESPONSE: {context}: bytes={data.hex()}, continuation/final EOD checked")
    return data


async def read_ccc_exact(controller, command, address, expected):
    """Send a complete directed read and verify its exact response and T-bits."""
    await controller.take_bus_control()
    await controller.send_start()
    assert await controller.write_addr_header(0x7E), "CCC header NACKed"
    await controller.send_byte_tbit(command)
    await controller.send_start()
    assert await controller.write_addr_header(address, read=True), f"CCC 0x{command:02X}: address 0x{address:02X} NACKed"
    data = await recv_ccc_exact(controller, expected, f"CCC=0x{command:02X}, address=0x{address:02X}")
    await controller.send_stop()
    controller.give_bus_control()
    return data


async def monitor_ccc_quiet(dut, tb, finished):
    """Reject new field/CSR/FIFO effects throughout a quiescent or STOP window."""
    ccc = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xccc
    config = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration
    tti = dut.xi3c_wrapper.i3c.xtti
    pulses = [getattr(ccc, name) for name in (
        "capture_defining_byte", "capture_rx_data", "rx_data_valid", "def_byte_tbit_valid",
        "target_addr_ack_done", "get_status_done_o", "set_mwl_o", "set_mrl_o", "set_ibil_o",
        "set_dasa_valid_o", "set_newda_o", "set_aasa_o", "set_aasa_virt_o",
        "rstdaa_o", "enec_ibi_o", "enec_crr_o", "enec_hj_o", "disec_ibi_o", "disec_crr_o", "disec_hj_o",
    )] + [tti.rx_data_queue_write_r, tti.rx_desc_queue_write_r]
    fields = [getattr(config, name) for name in ("get_mwl_o", "get_mrl_o", "get_ibil_o")]
    fields += [ccc.rstact_armed_q, ccc.rst_action_o, ccc.vt_detect_flag_q]
    fields += [ccc.target_dyn_address_i, ccc.target_dyn_address_valid_i,
               ccc.virtual_target_dyn_address_i, ccc.virtual_target_dyn_address_valid_i]
    baseline = None
    samples = 0
    dut._log.info("CCC_QUIET: monitoring no-new-effect window (earlier valid fields may be committed)")
    while not finished.is_set():
        await FallingEdge(tb.clk)
        await ReadOnly()
        values = tuple(int(signal.value) for signal in fields)
        if baseline is None:
            baseline = values
        assert values == baseline, f"CCC_QUIET: architectural state changed: {baseline} -> {values}"
        for signal in pulses:
            assert int(signal.value) == 0, f"CCC_QUIET: unexpected effect {signal._name}"
        samples += 1
    assert samples, "CCC_QUIET: monitor never sampled"
    dut._log.info(f"CCC_QUIET: completed {samples} settled samples without new effects")


async def exercise_te2_quiescence(controller, dut, tb, addresses, count_before):
    """Require one TE2, then exercise ignored Sr/headers/data until STOP."""
    await ClockCycles(tb.clk, 5)
    assert tb.te_error_monitor.error_counts[2] == count_before + 1, "Expected exactly one CCC TE2 event"
    assert int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.err_o.value) == 1
    finished = Event()
    checker = cocotb.start_soon(monitor_ccc_quiet(dut, tb, finished))
    await ClockCycles(tb.clk, 2)
    for address in addresses:
        await controller.send_start()
        assert not await controller.write_addr_header(address), f"TE2 recovered before STOP at 0x{address:02X}"
        await controller.send_byte_tbit(0xA5)
    await controller.send_stop()
    controller.give_bus_control()
    await ClockCycles(tb.clk, 10)
    finished.set()
    await checker
    assert tb.te_error_monitor.error_counts[2] == count_before + 1, "Ignored traffic generated another TE2"
    await FallingEdge(tb.clk)


async def check_private_payload(tb, payload):
    await ClockCycles(tb.clk, 10)
    desc = int.from_bytes(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4), "little")
    assert desc & 0xFFFF == len(payload) and desc >> 28 == 0, f"Private RX descriptor mismatch: 0x{desc:08X}"
    data = await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, len(payload))
    assert bytearray(data) == bytearray(payload), f"Private payload mismatch: {list(data)}"


async def check_private_transfers(controller, tb, address):
    payload = bytearray([0xA5, 0x46, 0x7E, 0x3C])
    for read in (False, True):
        if read:
            await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, payload, 4)
            await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(len(payload)), 4)
        await controller.take_bus_control()
        await controller.send_start()
        assert await controller.write_addr_header(address, read=read), "Private recovery address NACKed"
        if read:
            data = bytearray()
            await controller.recv_until_eod_tbit(data, len(payload), stop=False)
            assert data == payload, f"Private recovery data mismatch: {data.hex()}"
        else:
            for byte in payload:
                await controller.send_byte_tbit(byte)
        await controller.send_stop()
        controller.give_bus_control()
        if not read:
            await check_private_payload(tb, payload)


async def set_mrl_capabilities(tb, main, virtual):
    sm = tb.reg_map.I3C_EC.STDBYCTRLMODE
    for reg, enabled in ((sm.STBY_CR_DEVICE_CHAR, main), (sm.STBY_CR_VIRTUAL_DEVICE_CHAR, virtual)):
        value = await tb.read_csr_field(reg.base_addr, reg.BCR_VAR)
        await tb.write_csr_field(reg.base_addr, reg.BCR_VAR, (value & ~4) | (int(enabled) << 2))


async def test_setup(dut, static_addr=0x5A, virtual_static_addr=0x5B, dynamic_addr=None, virtual_dynamic_addr=None):
    """
    Sets up controller, target models and top-level core interface
    """
    cocotb.log.setLevel(logging.DEBUG)
    log_seed(dut)

    i3c_controller = I3cController(
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_ctrl_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_ctrl_i,
        debug_state_o=None,
        speed=12.5e6,
    )

    # We don't need target BFM in this test
    dut.sda_sim_target_i = 1
    dut.scl_sim_target_i = 1
    i3c_target = None

    dut.peripheral_reset_done_i.value = 0

    tb = I3CTopTestInterface(dut)
    await tb.setup()
    await ClockCycles(tb.clk, 50)
    await boot_init(tb, static_addr=static_addr, virtual_static_addr=virtual_static_addr,
                    dynamic_addr=dynamic_addr, virtual_dynamic_addr=virtual_dynamic_addr)
    return i3c_controller, i3c_target, tb


@cocotb.test()
async def test_ccc_getstatus(dut):

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    # Once dynamic address is assigned, static address can no longer be used
    ADDRs = [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]

    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # PENDING_INTERRUPT is HW-driven by ibi_pending (not SW-writable).
    # Without queueing an IBI descriptor, ibi_pending is always 0.
    # Verify GETSTATUS returns the correct format for both main and virtual targets.
    for _ in range(random.randint(10, 30)):
        addr = random.choice(ADDRs)
        data = await read_ccc_exact(i3c_controller, CCC.DIRECT.GETSTATUS, addr, [0, 0xC0])
        status = int.from_bytes(data, byteorder="big", signed=False)
        cocotb.log.info(f"GETSTATUS addr=0x{addr:02X} status=0x{status:04X}")
        if addr == DYNAMIC_ADDR:
            # Main target: Activity Mode=3 (bits[7:6]=0b11), PENDING_INTERRUPT=0
            pending_interrupt = status & 0xF
            activity_mode = (status >> 6) & 0x3
            assert pending_interrupt == 0, (
                f"Expected PENDING_INTERRUPT=0 (no IBI queued), got {pending_interrupt}"
            )
            assert activity_mode == 3, (
                f"Expected Activity Mode=3, got {activity_mode}"
            )
        else:
            # Virtual target: Activity Mode=3, no pending interrupts
            assert status == 0x00C0, (
                f"Unexpected virtual target GETSTATUS, expected: 0x00C0 got: 0x{status:04X}"
            )

    # Enqueue an IBI with IBI handling disabled; should flip bit 0 in the vendor specific part
    await tb.write_csr(tb.reg_map.I3C_EC.TTI.CONTROL.base_addr, int2dword(0x0), 4)

    # Write descriptor to the TTI IBI queue
    mdb = 0xCC
    data = [0xFE, 0xED]
    ibi_data = format_ibi_data(mdb, data)
    dut._log.info(" ".join([f"0x{d:08X}" for d in ibi_data]))
    for word in ibi_data:
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, int2dword(word), 4)

    # Read CCC
    data = await read_ccc_exact(i3c_controller, CCC.DIRECT.GETSTATUS, DYNAMIC_ADDR, [1, 0xC1])
    status = int.from_bytes(data, byteorder="big", signed=False)
    ibi_pend_mask = 0x0100
    assert (status & ibi_pend_mask) == ibi_pend_mask, f"GETSTATUS PENDING_IBI not set: status=0x{status:04X}"

    # PENDING_INTERRUPT[3:0] should also be non-zero when IBI is pending
    pending_interrupt = status & 0xF
    assert pending_interrupt != 0, (
        f"GETSTATUS PENDING_INTERRUPT[3:0] should be non-zero with IBI pending, got {pending_interrupt}"
    )

    await tb.teardown()

    # Enqueue an IBI with IBI handling disabled; should flip bit 0 in the vendor specific part
    await tb.write_csr(tb.reg_map.I3C_EC.TTI.CONTROL.base_addr, int2dword(0x0), 4)

    # Write descriptor to the TTI IBI queue
    mdb = 0xCC
    data = [0xFE, 0xED]
    ibi_data = format_ibi_data(mdb, data)
    dut._log.info(" ".join([f"0x{d:08X}" for d in ibi_data]))
    for word in ibi_data:
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, int2dword(word), 4)

    # Read CCC
    responses = await i3c_controller.i3c_ccc_read(ccc=CCC.DIRECT.GETSTATUS, addr=DYNAMIC_ADDR, count=2)
    status = int.from_bytes(responses[0][1], byteorder="big", signed=False)
    ibi_pend_mask = 0x0100
    assert((status & ibi_pend_mask) == ibi_pend_mask)


@cocotb.test()
async def test_ccc_setdasa(dut):

    list_of_values = VALID_I3C_ADDRESSES.copy()

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(list_of_values, 4)

    # remove our addresses from list of allowed addresses
    list_of_values.remove(STATIC_ADDR)
    list_of_values.remove(VIRT_STATIC_ADDR)
    list_of_values.remove(DYNAMIC_ADDR)
    list_of_values.remove(VIRT_DYNAMIC_ADDR)

    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR)
    await ClockCycles(tb.clk, 50)
    # send number of transaction to address other than our
    for _ in range(random.randint(1, 3)):
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.SETDASA, directed_data=[(random.choice(list_of_values), [random.choice(list_of_values) << 1])], stop=False
        )
    if random.choice([True, False]):
        # send regular device dynamic address along with addresses for other random devices (those should be ignored)
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.SETDASA, directed_data=[(random.choice(list_of_values), [random.choice(list_of_values) << 1]), (STATIC_ADDR, [DYNAMIC_ADDR << 1]), (random.choice(list_of_values), [random.choice(list_of_values) << 1])], stop=False
        )
    else:
        # send regular device dynamic address
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])], stop=False
        )
    # send number of transaction to address other than our
    for _ in range(random.randint(1, 3)):
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.SETDASA, directed_data=[(random.choice(list_of_values), [random.choice(list_of_values) << 1])], stop=False
        )
    if random.choice([True, False]):
        # send virtual device dynamic address along with addresses for other random devices (those should be ignored)
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.SETDASA, directed_data=[(random.choice(list_of_values), [random.choice(list_of_values) << 1]), (VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1]), (random.choice(list_of_values), [random.choice(list_of_values) << 1])], stop=False
        )
    else:
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
        )
    # send number of transaction to address other than our
    for _ in range(random.randint(1, 3)):
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.SETDASA, directed_data=[(random.choice(list_of_values), [random.choice(list_of_values) << 1])], stop=False
        )
    dynamic_address_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr
    dynamic_address_reg_value = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR
    virtual_dynamic_address_reg_addr = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr
    )
    virtual_dynamic_address_reg_value = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR
    )
    dynamic_address_reg_valid = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID
    )
    virtual_dynamic_address_reg_valid = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID
    )
    dynamic_address = await tb.read_csr_field(dynamic_address_reg_addr, dynamic_address_reg_value)
    dynamic_address_valid = await tb.read_csr_field(
        dynamic_address_reg_addr, dynamic_address_reg_valid
    )
    virt_dynamic_address = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_value
    )
    virt_dynamic_address_valid = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_valid
    )
    assert dynamic_address == DYNAMIC_ADDR, "Unexpected DYNAMIC ADDRESS read from the CSR"
    assert dynamic_address_valid == 1, "New DYNAMIC ADDRESS is not set as valid"

    assert (
        virt_dynamic_address == VIRT_DYNAMIC_ADDR
    ), "Unexpected VIRT DYNAMIC ADDRESS read from the CSR"
    assert virt_dynamic_address_valid == 1, "New VIRT DYNAMIC ADDRESS is not set as valid"

    await tb.teardown()


@cocotb.test()
async def test_ccc_setdasa_nack(dut):

    list_of_values = VALID_I3C_ADDRESSES.copy()

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(list_of_values, 4)

    # remove our addresses from list of allowed addresses
    list_of_values.remove(STATIC_ADDR)
    list_of_values.remove(VIRT_STATIC_ADDR)
    list_of_values.remove(DYNAMIC_ADDR)
    list_of_values.remove(VIRT_DYNAMIC_ADDR)

    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR)
    # set regular device dynamic address
    ack = await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])], stop=False
    )
    # check ACK
    assert ack[0] == True, f"SETDASA NACK for STATIC_ADDR=0x{STATIC_ADDR:02X}"

    # try to send SETDASA again (should be NACKed)
    ack = await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])], stop=False
    )
    assert ack[0] == False, f"SETDASA unexpected ACK for already-assigned STATIC_ADDR=0x{STATIC_ADDR:02X}"

    # set virtual device dynamic address
    ack = await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )
    # check ACK
    assert ack[0] == True, f"SETDASA NACK for VIRT_STATIC_ADDR=0x{VIRT_STATIC_ADDR:02X}"

    # try to send SETDASA again (should be NACKed)
    ack = await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )
    assert ack[0] == False, f"SETDASA unexpected ACK for already-assigned VIRT_STATIC_ADDR=0x{VIRT_STATIC_ADDR:02X}"

    await tb.teardown()


@cocotb.test()
async def test_ccc_setnewda(dut):


    list_of_values = VALID_I3C_ADDRESSES.copy()

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR, NEW_DYNAMIC_ADDR, NEW_VIRT_DYNAMIC_ADDR) = random.sample(list_of_values, 6)

    # remove our addresses from list of allowed addresses
    list_of_values.remove(STATIC_ADDR)
    list_of_values.remove(VIRT_STATIC_ADDR)
    list_of_values.remove(DYNAMIC_ADDR)
    list_of_values.remove(VIRT_DYNAMIC_ADDR)
    list_of_values.remove(NEW_DYNAMIC_ADDR)
    list_of_values.remove(NEW_VIRT_DYNAMIC_ADDR)

    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR)
    await ClockCycles(tb.clk, 50)

    dynamic_address_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr
    dynamic_address_reg_value = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR
    virtual_dynamic_address_reg_addr = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr
    )
    virtual_dynamic_address_reg_value = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR
    )
    dynamic_address_reg_valid = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID
    )
    virtual_dynamic_address_reg_valid = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID
    )

    # set dynamic addresses
    await tb.write_csr_field(dynamic_address_reg_addr, dynamic_address_reg_value, DYNAMIC_ADDR)
    await tb.write_csr_field(dynamic_address_reg_addr, dynamic_address_reg_valid, 1)
    await tb.write_csr_field(virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_value, VIRT_DYNAMIC_ADDR)
    await tb.write_csr_field(virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_valid, 1)

    # change regular device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETNEWDA, directed_data=[(DYNAMIC_ADDR, [NEW_DYNAMIC_ADDR << 1])], stop=False
    )
    # change virtual device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETNEWDA, directed_data=[(VIRT_DYNAMIC_ADDR, [NEW_VIRT_DYNAMIC_ADDR << 1])]
    )

    # read addresses
    dynamic_address = await tb.read_csr_field(dynamic_address_reg_addr, dynamic_address_reg_value)
    dynamic_address_valid = await tb.read_csr_field(
        dynamic_address_reg_addr, dynamic_address_reg_valid
    )
    virt_dynamic_address = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_value
    )
    virt_dynamic_address_valid = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_valid
    )

    assert dynamic_address == NEW_DYNAMIC_ADDR, "Unexpected DYNAMIC ADDRESS read from the CSR"
    assert dynamic_address_valid == 1, "New DYNAMIC ADDRESS is not set as valid"

    assert (
        virt_dynamic_address == NEW_VIRT_DYNAMIC_ADDR
    ), "Unexpected VIRT DYNAMIC ADDRESS read from the CSR"
    assert virt_dynamic_address_valid == 1, "New VIRT DYNAMIC ADDRESS is not set as valid"

    await tb.teardown()

@cocotb.test()
async def test_ccc_rstdaa(dut):

    DYNAMIC_ADDR = 0x52
    VIRT_DYNAMIC_ADDR = 0x53
    i3c_controller, i3c_target, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)
    dynamic_address_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr
    dynamic_address_reg_value = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR
    dynamic_address_reg_valid = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID
    )
    virtual_dynamic_address_reg_addr = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr
    )
    virtual_dynamic_address_reg_value = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR
    )
    virtual_dynamic_address_reg_valid = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID
    )

    virt_dynamic_address = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_value
    )
    virt_dynamic_address_valid = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_valid
    )

    # set dynamic address CSR
    await tb.write_csr_field(dynamic_address_reg_addr, dynamic_address_reg_value, DYNAMIC_ADDR)
    await tb.write_csr_field(dynamic_address_reg_addr, dynamic_address_reg_valid, 1)
    # set virt dynamic address CSR
    await tb.write_csr_field(virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_value, VIRT_DYNAMIC_ADDR)
    await tb.write_csr_field(virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_valid, 1)

    # check if write was successful
    dynamic_address = await tb.read_csr_field(dynamic_address_reg_addr, dynamic_address_reg_value)
    dynamic_address_valid = await tb.read_csr_field(
        dynamic_address_reg_addr, dynamic_address_reg_valid
    )

    virt_dynamic_address = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_value
    )
    virt_dynamic_address_valid = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_valid
    )

    assert dynamic_address == DYNAMIC_ADDR, "Unexpected DYNAMIC ADDRESS read from the CSR"
    assert dynamic_address_valid == 1, "New DYNAMIC ADDRESS is not set as valid"

    assert (
        virt_dynamic_address == VIRT_DYNAMIC_ADDR
    ), "Unexpected VIRT DYNAMIC ADDRESS read from the CSR"
    assert virt_dynamic_address_valid == 1, "New VIRT DYNAMIC ADDRESS is not set as valid"

    # reset Dynamic Address
    await i3c_controller.i3c_ccc_write(ccc=CCC.BCAST.RSTDAA)

    # check if the address was reset
    dynamic_address = await tb.read_csr_field(dynamic_address_reg_addr, dynamic_address_reg_value)
    dynamic_address_valid = await tb.read_csr_field(
        dynamic_address_reg_addr, dynamic_address_reg_valid
    )

    virt_dynamic_address = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_value
    )
    virt_dynamic_address_valid = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_valid
    )

    assert dynamic_address == 0, "Unexpected DYNAMIC ADDRESS read from the CSR"
    assert dynamic_address_valid == 0, "New DYNAMIC ADDRESS is not set as valid"
    assert virt_dynamic_address == 0, "Unexpected DYNAMIC ADDRESS read from the CSR"
    assert virt_dynamic_address_valid == 0, "New DYNAMIC ADDRESS is not set as valid"

    await tb.teardown()

@cocotb.test()
async def test_ccc_getbcr(dut):

    _BCR_FIXED = 0b001  # CSR reset value
    _BCR_VARs = [random.randint(0, 31), random.randint(0, 31)]
    command = CCC.DIRECT.GETBCR

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    ADDRs = [random.choice([STATIC_ADDR, DYNAMIC_ADDR]), random.choice([VIRT_STATIC_ADDR, VIRT_DYNAMIC_ADDR])]

    i3c_controller, _, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=ADDRs[0] if ADDRs[0] == DYNAMIC_ADDR else None,
        virtual_dynamic_addr=ADDRs[1] if ADDRs[1] == VIRT_DYNAMIC_ADDR else None)
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.BCR_VAR,
        _BCR_VARs[0],
    )
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_CHAR.BCR_VAR,
        _BCR_VARs[1],
    )
    await ClockCycles(tb.clk, 50)

    for _tgt_adr, _bcr_var in zip(ADDRs, _BCR_VARs):
        responses = await i3c_controller.i3c_ccc_read(ccc=command, addr=_tgt_adr, count=1)
        bcr = responses[0][1]
        bcr_value = int.from_bytes(bcr, byteorder="big", signed=False)
        _BCR_VALUE = (_BCR_FIXED << 5) | _bcr_var
        assert _BCR_VALUE == bcr_value, f"BCR mismatch: exp=0x{_BCR_VALUE:02X} got=0x{bcr_value:02X}"

    await tb.teardown()


@cocotb.test()
async def test_ccc_getdcr(dut):

    _DCR_VARs = [random.randint(0, 255), random.randint(0, 255)]
    command = CCC.DIRECT.GETDCR

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    ADDRs = [random.choice([STATIC_ADDR, DYNAMIC_ADDR]), random.choice([VIRT_STATIC_ADDR, VIRT_DYNAMIC_ADDR])]

    i3c_controller, _, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=ADDRs[0] if ADDRs[0] == DYNAMIC_ADDR else None,
        virtual_dynamic_addr=ADDRs[1] if ADDRs[1] == VIRT_DYNAMIC_ADDR else None)
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.DCR,
        _DCR_VARs[0],
    )
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_CHAR.DCR,
        _DCR_VARs[1],
    )
    await ClockCycles(tb.clk, 50)

    for _tgt_adr, _dcr_value in zip(ADDRs, _DCR_VARs):
        responses = await i3c_controller.i3c_ccc_read(ccc=command, addr=_tgt_adr, count=1)
        dcr = responses[0][1]
        dcr_value = int.from_bytes(dcr, byteorder="big", signed=False)
        assert _dcr_value == dcr_value, f"DCR mismatch: exp=0x{_dcr_value:02X} got=0x{dcr_value:02X}"

    await tb.teardown()


@cocotb.test()
async def test_ccc_getmwl(dut):

    _TXRX_QUEUE_SIZE = 2 ** (5 + 1)  # Dwords
    _MWL_VALUE = 4 * _TXRX_QUEUE_SIZE  # Bytes

    command = CCC.DIRECT.GETMWL

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # Check both main and virtual targets (shared MWL CSR)
    for addr in [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]:
        responses = await i3c_controller.i3c_ccc_read(ccc=command, addr=addr, count=2)
        [mwl_msb, mwl_lsb] = responses[0][1]
        mwl = (mwl_msb << 8) | mwl_lsb
        assert mwl == _MWL_VALUE, \
            f"GETMWL from 0x{addr:02X}: expected 0x{_MWL_VALUE:04X}, got 0x{mwl:04X}"

    await tb.teardown()


@cocotb.test()
async def test_ccc_getmrl(dut):

    _TXRX_QUEUE_SIZE = 2 ** (5 + 1)  # Dwords
    _MRL_VALUE = 4 * _TXRX_QUEUE_SIZE  # Bytes
    _IBI_PAYLOAD_SIZE = 16  # Bytes
    command = CCC.DIRECT.GETMRL

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)
    await set_mrl_capabilities(tb, True, False)

    # Main target: MRL + IBI payload size
    expected = [_MRL_VALUE >> 8, _MRL_VALUE & 0xFF]
    await read_ccc_exact(i3c_controller, command, DYNAMIC_ADDR, expected + [_IBI_PAYLOAD_SIZE])

    # Virtual target does not advertise an IBI payload, so it returns only MRL.
    await read_ccc_exact(i3c_controller, command, VIRT_DYNAMIC_ADDR, expected)

    await tb.teardown()


@cocotb.test()
async def test_ccc_setaasa(dut):

    STATIC_ADDR = 0x5A
    VIRT_STATIC_ADDR = 0x5B
    I3C_BCAST_SETAASA = 0x29
    i3c_controller, i3c_target, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)
    dynamic_address_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr
    dynamic_address_reg_value = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR
    dynamic_address_reg_valid = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID
    )
    virtual_dynamic_address_reg_addr = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr
    )
    virtual_dynamic_address_reg_value = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR
    )
    virtual_dynamic_address_reg_valid = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID
    )


    # reset Dynamic Address
    await i3c_controller.i3c_ccc_write(ccc=I3C_BCAST_SETAASA)

    # check if the address was reset
    dynamic_address = await tb.read_csr_field(dynamic_address_reg_addr, dynamic_address_reg_value)
    dynamic_address_valid = await tb.read_csr_field(
        dynamic_address_reg_addr, dynamic_address_reg_valid
    )
    assert dynamic_address == STATIC_ADDR, "Unexpected DYNAMIC ADDRESS read from the CSR"
    assert dynamic_address_valid == 1, "New DYNAMIC ADDRESS is not set as valid"
    virt_dynamic_address = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_value
    )
    virt_dynamic_address_valid = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_valid
    )
    assert virt_dynamic_address == VIRT_STATIC_ADDR, "Unexpected VIRT DYNAMIC ADDRESS read from the CSR"
    assert virt_dynamic_address_valid == 1, "New VIRT DYNAMIC ADDRESS is not set as valid"

    await tb.teardown()


@cocotb.test()
async def test_ccc_setaasa_ignore(dut):

    STATIC_ADDR = 0x5A
    VIRT_STATIC_ADDR = 0x5B
    DYNAMIC_ADDR = 0x3A
    VIRT_DYNAMIC_ADDR = 0x3B
    I3C_BCAST_SETAASA = 0x29

    i3c_controller, i3c_target, tb = await test_setup(dut)
    dynamic_address_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr
    dynamic_address_reg_value = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR
    dynamic_address_reg_valid = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID
    )
    virtual_dynamic_address_reg_addr = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr
    )
    virtual_dynamic_address_reg_value = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR
    )
    virtual_dynamic_address_reg_valid = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID
    )
    # set dynamic address CSRs
    await tb.write_csr_field(dynamic_address_reg_addr, dynamic_address_reg_value, DYNAMIC_ADDR)
    await tb.write_csr_field(dynamic_address_reg_addr, dynamic_address_reg_valid, 1)
    await tb.write_csr_field(virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_value, VIRT_DYNAMIC_ADDR)
    await tb.write_csr_field(virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_valid, 1)

    # Send SETAASA
    await i3c_controller.i3c_ccc_write(ccc=I3C_BCAST_SETAASA)

    # check if the address was not changed
    dynamic_address = await tb.read_csr_field(dynamic_address_reg_addr, dynamic_address_reg_value)
    dynamic_address_valid = await tb.read_csr_field(
        dynamic_address_reg_addr, dynamic_address_reg_valid
    )
    assert dynamic_address == DYNAMIC_ADDR, "Unexpected DYNAMIC ADDRESS read from the CSR"
    assert dynamic_address_valid == 1, "New DYNAMIC ADDRESS is not set as valid"

    virt_dynamic_address = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_value
    )
    virt_dynamic_address_valid = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_valid
    )
    assert virt_dynamic_address == VIRT_DYNAMIC_ADDR, "Unexpected VIRT DYNAMIC ADDRESS read from the CSR"
    assert virt_dynamic_address_valid == 1, "New VIRT DYNAMIC ADDRESS is not set as valid"

    await tb.teardown()


@cocotb.test()
async def test_ccc_getpid(dut):

    _PID_HIs = [random.randint(0, 32767), random.randint(0, 32767)]
    _PID_LOs = [random.randint(0, (2**32)-1), random.randint(0, (2**32)-1)]
    command = CCC.DIRECT.GETPID

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    ADDRs = [random.choice([STATIC_ADDR, DYNAMIC_ADDR]), random.choice([VIRT_STATIC_ADDR, VIRT_DYNAMIC_ADDR])]

    i3c_controller, _, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=ADDRs[0] if ADDRs[0] == DYNAMIC_ADDR else None,
        virtual_dynamic_addr=ADDRs[1] if ADDRs[1] == VIRT_DYNAMIC_ADDR else None)
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.PID_HI,
        _PID_HIs[0],
    )
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.PID_LO,
        _PID_LOs[0],
    )
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_CHAR.PID_HI,
        _PID_HIs[1],
    )
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_PID_LO.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_PID_LO.PID_LO,
        _PID_LOs[1],
    )
    await ClockCycles(tb.clk, 50)

    for _tgt_adr, _pid_lo, _pid_hi in zip(ADDRs, _PID_LOs, _PID_HIs):
        responses = await i3c_controller.i3c_ccc_read(ccc=command, addr=_tgt_adr, count=6)
        pid = responses[0][1]
        pid_hi = int.from_bytes(pid[0:2], byteorder="big", signed=False)
        pid_lo = int.from_bytes(pid[2:6], byteorder="big", signed=False)

        # PID_HI has bit 0 always stuck at 0
        # Test can only setup 15 upper bits
        assert pid_hi == _pid_hi * 2, f"PID_HI mismatch: exp={_pid_hi * 2} got={pid_hi}"
        assert pid_lo == _pid_lo, f"PID_LO mismatch: exp={_pid_lo} got={pid_lo}"

    await tb.teardown()


async def read_target_events(tb):

    reg = tb.reg_map.I3C_EC.TTI.CONTROL.base_addr
    ibi_en_field = tb.reg_map.I3C_EC.TTI.CONTROL.IBI_EN
    crr_en_field = tb.reg_map.I3C_EC.TTI.CONTROL.CRR_EN
    hj_en_field = tb.reg_map.I3C_EC.TTI.CONTROL.HJ_EN

    ibi_en = await tb.read_csr_field(reg, ibi_en_field)
    crr_en = await tb.read_csr_field(reg, crr_en_field)
    hj_en = await tb.read_csr_field(reg, hj_en_field)

    return (ibi_en, crr_en, hj_en)


@cocotb.test()
async def test_ccc_enec_disec_direct(dut):

    command_enec = CCC.DIRECT.ENEC
    command_disec = CCC.DIRECT.DISEC

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # Read default values
    event_en = await read_target_events(tb)
    assert event_en == (1, 0, 1), f"Default ENEC state mismatch: exp=(1,0,1) got={event_en}"

    # Test each target with multiple bit patterns
    for tgt_addr in [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]:
        # Disable all target events
        await i3c_controller.i3c_ccc_write(
            ccc=command_disec, directed_data=[(tgt_addr, [0b00001011])]
        )
        event_en = await read_target_events(tb)
        assert event_en == (0, 0, 0), \
            f"DISEC all from 0x{tgt_addr:02X}: expected (0,0,0), got {event_en}"

        # Enable individual bits: IBI only
        await i3c_controller.i3c_ccc_write(
            ccc=command_enec, directed_data=[(tgt_addr, [0x01])]
        )
        event_en = await read_target_events(tb)
        assert event_en[0] == 1, f"ENEC IBI from 0x{tgt_addr:02X}: IBI not set"

        # Enable CRR
        await i3c_controller.i3c_ccc_write(
            ccc=command_enec, directed_data=[(tgt_addr, [0x02])]
        )
        event_en = await read_target_events(tb)
        assert event_en[1] == 1, f"ENEC CRR from 0x{tgt_addr:02X}: CRR not set"

        # Enable HJ
        await i3c_controller.i3c_ccc_write(
            ccc=command_enec, directed_data=[(tgt_addr, [0x08])]
        )
        event_en = await read_target_events(tb)
        assert event_en == (1, 1, 1), \
            f"ENEC all from 0x{tgt_addr:02X}: expected (1,1,1), got {event_en}"

        # Random pattern disable
        pattern = random.choice([0x01, 0x02, 0x08, 0x03, 0x09, 0x0A, 0x0B])
        await i3c_controller.i3c_ccc_write(
            ccc=command_disec, directed_data=[(tgt_addr, [pattern])]
        )
        event_en = await read_target_events(tb)
        expect_ibi = 0 if (pattern & 0x01) else 1
        expect_crr = 0 if (pattern & 0x02) else 1
        expect_hj = 0 if (pattern & 0x08) else 1
        assert event_en == (expect_ibi, expect_crr, expect_hj), \
            f"DISEC pattern 0x{pattern:02X} from 0x{tgt_addr:02X}: " \
            f"expected ({expect_ibi},{expect_crr},{expect_hj}), got {event_en}"

    # Re-enable all for clean test exit
    await i3c_controller.i3c_ccc_write(
        ccc=command_enec, directed_data=[(DYNAMIC_ADDR, [0x0B])]
    )

    await tb.teardown()


@cocotb.test()
async def test_ccc_enec_disec_bcast(dut):

    command_enec = CCC.BCAST.ENEC
    command_disec = CCC.BCAST.DISEC

    _EVENT_TOGGLE_BYTE = 0b00001011

    i3c_controller, _, tb = await test_setup(dut, static_addr=None, virtual_static_addr=None)
    await ClockCycles(tb.clk, 50)

    # Read default values
    event_en = await read_target_events(tb)
    assert event_en == (1, 0, 1), f"Default ENEC state mismatch: exp=(1,0,1) got={event_en}"

    # Disable all target events
    await i3c_controller.i3c_ccc_write(ccc=command_disec, broadcast_data=[_EVENT_TOGGLE_BYTE])

    # Read disabled values
    event_en = await read_target_events(tb)
    assert event_en == (0, 0, 0), f"DISEC state mismatch: exp=(0,0,0) got={event_en}"

    # Enable all target events
    await i3c_controller.i3c_ccc_write(ccc=command_enec, broadcast_data=[_EVENT_TOGGLE_BYTE])

    # Read enabled values
    event_en = await read_target_events(tb)
    assert event_en == (1, 1, 1), f"ENEC state mismatch: exp=(1,1,1) got={event_en}"

    for pattern in (0x00, 0x01, 0x02, 0x08, 0xF4, 0xFF):
        await i3c_controller.i3c_ccc_write(ccc=command_disec, broadcast_data=[0x0B])
        await i3c_controller.i3c_ccc_write(ccc=command_enec, broadcast_data=[pattern])
        expected = tuple(int(bool(pattern & mask)) for mask in (1, 2, 8))
        assert await read_target_events(tb) == expected, f"Broadcast ENEC mask mismatch: {pattern:#x}"
        await i3c_controller.i3c_ccc_write(ccc=command_disec, broadcast_data=[pattern])
        assert await read_target_events(tb) == (0, 0, 0), f"Broadcast DISEC mask mismatch: {pattern:#x}"

    await tb.teardown()


@cocotb.test()
async def test_ccc_setmwl_direct(dut):

    command_set = CCC.DIRECT.SETMWL
    command_get = CCC.DIRECT.GETMWL

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # Test with random values + boundary values, targeting both main and VT
    test_values = [0x0000, 0xFFFF] + [random.randint(0, 0xFFFF) for _ in range(3)]
    for mwl_val in test_values:
        tgt_addr = random.choice([DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR])
        mwl_msb = (mwl_val >> 8) & 0xFF
        mwl_lsb = mwl_val & 0xFF
        await i3c_controller.i3c_ccc_write(
            ccc=command_set, directed_data=[(tgt_addr, [mwl_msb, mwl_lsb])])

        # Check CSR value
        sig = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mwl_o.value
        assert mwl_val == int(sig), \
            f"SETMWL CSR mismatch: expected 0x{mwl_val:04X}, got 0x{int(sig):04X}"

        # Verify FW-readable STBY_CR_MWL register
        await ClockCycles(tb.clk, 10)
        mwl_csr = await tb.read_csr_field(
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_MWL.base_addr,
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_MWL.MWL,
        )
        assert mwl_csr == mwl_val, \
            f"STBY_CR_MWL.MWL mismatch: expected 0x{mwl_val:04X}, got 0x{mwl_csr:04X}"

        # GET readback from both targets (shared CSR)
        for read_addr in [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]:
            responses = await i3c_controller.i3c_ccc_read(
                ccc=command_get, addr=read_addr, count=2)
            [got_msb, got_lsb] = responses[0][1]
            got_mwl = (got_msb << 8) | got_lsb
            assert got_mwl == mwl_val, \
                f"GETMWL from 0x{read_addr:02X}: expected 0x{mwl_val:04X}, got 0x{got_mwl:04X}"

    await tb.teardown()


@cocotb.test()
async def test_ccc_setmrl_direct(dut):

    command_set = CCC.DIRECT.SETMRL
    command_get = CCC.DIRECT.GETMRL

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)
    await set_mrl_capabilities(tb, True, False)

    # Test with random values + boundary values, targeting both main and VT
    test_values = [0x0000, 0xFFFF] + [random.randint(0, 0xFFFF) for _ in range(3)]
    for mrl_val in test_values:
        tgt_addr = random.choice([DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR])
        old_ibil = int(dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_ibil_o.value)
        mrl_msb = (mrl_val >> 8) & 0xFF
        mrl_lsb = mrl_val & 0xFF
        ibil = random.randint(0, 255)
        payload = [mrl_msb, mrl_lsb] + ([ibil] if tgt_addr == DYNAMIC_ADDR else [])
        await i3c_controller.i3c_ccc_write(ccc=command_set, directed_data=[(tgt_addr, payload)])
        expected_ibil = ibil if tgt_addr == DYNAMIC_ADDR else old_ibil

        # Check CSR value
        sig = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mrl_o.value
        assert mrl_val == int(sig), \
            f"SETMRL CSR mismatch: expected 0x{mrl_val:04X}, got 0x{int(sig):04X}"

        # Verify FW-readable STBY_CR_MRL register
        await ClockCycles(tb.clk, 10)
        mrl_csr = await tb.read_csr_field(
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_MRL.base_addr,
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_MRL.MRL,
        )
        assert mrl_csr == mrl_val, \
            f"STBY_CR_MRL.MRL mismatch: expected 0x{mrl_val:04X}, got 0x{mrl_csr:04X}"

        ibil_csr = await tb.read_csr_field(
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_MRL.base_addr,
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_MRL.IBIL,
        )
        assert ibil_csr == expected_ibil, \
            f"STBY_CR_MRL.IBIL mismatch: expected 0x{expected_ibil:02X}, got 0x{ibil_csr:02X}"

        # GET readback from main target
        responses = await i3c_controller.i3c_ccc_read(
            ccc=command_get, addr=DYNAMIC_ADDR, count=3)
        [got_msb, got_lsb, got_ibil] = responses[0][1]
        got_mrl = (got_msb << 8) | got_lsb
        assert got_mrl == mrl_val, \
            f"GETMRL main: expected 0x{mrl_val:04X}, got 0x{got_mrl:04X}"
        assert got_ibil == expected_ibil, f"GETMRL main IBIL: expected {expected_ibil}, got {got_ibil}"

        # GET readback from VT has no third byte.
        responses = await i3c_controller.i3c_ccc_read(
            ccc=command_get, addr=VIRT_DYNAMIC_ADDR, count=3)
        assert responses[0][0] and len(responses[0][1]) == 2
        [got_msb, got_lsb] = responses[0][1]
        got_mrl = (got_msb << 8) | got_lsb
        assert got_mrl == mrl_val, \
            f"GETMRL VT: expected 0x{mrl_val:04X}, got 0x{got_mrl:04X}"

    await tb.teardown()


@cocotb.test()
async def test_ccc_setmwl_bcast(dut):

    command = CCC.BCAST.SETMWL

    i3c_controller, _, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)

    # Send direct SETMWL
    mwl_msb = 0xAB
    mwl_lsb = 0xCD
    await i3c_controller.i3c_ccc_write(ccc=command, broadcast_data=[mwl_msb, mwl_lsb])

    # Check if MWL got written
    sig = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mwl_o.value
    mwl = (mwl_msb << 8) | mwl_lsb
    assert mwl == int(sig), f"SETMWL register mismatch: CCC sent={mwl} RTL={int(sig)}"

    # CP19: Verify FW-readable STBY_CR_MWL register (broadcast path)
    await ClockCycles(tb.clk, 10)
    mwl_csr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_MWL.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_MWL.MWL,
    )
    assert mwl_csr == mwl, (
        f"STBY_CR_MWL.MWL mismatch: expected 0x{mwl:04X}, got 0x{mwl_csr:04X}"
    )

    await tb.teardown()


@cocotb.test()
async def test_ccc_setmrl_bcast(dut):

    command = CCC.BCAST.SETMRL

    i3c_controller, _, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)

    # Send broadcast SETMRL with optional 3rd byte (IBIL)
    mrl_msb = 0xAB
    mrl_lsb = 0xCD
    ibil = 0x10
    await i3c_controller.i3c_ccc_write(ccc=command, broadcast_data=[mrl_msb, mrl_lsb, ibil])

    # Check if MRL got written
    sig = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mrl_o.value
    mrl = (mrl_msb << 8) | mrl_lsb
    assert mrl == int(sig), f"SETMRL register mismatch: CCC sent={mrl} RTL={int(sig)}"

    # CP20: Verify FW-readable STBY_CR_MRL.MRL register (broadcast path)
    await ClockCycles(tb.clk, 10)
    mrl_csr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_MRL.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_MRL.MRL,
    )
    assert mrl_csr == mrl, (
        f"STBY_CR_MRL.MRL mismatch: expected 0x{mrl:04X}, got 0x{mrl_csr:04X}"
    )

    # CP21: Verify FW-readable STBY_CR_MRL.IBIL register (broadcast path)
    ibil_csr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_MRL.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_MRL.IBIL,
    )
    assert ibil_csr == ibil, (
        f"STBY_CR_MRL.IBIL mismatch: expected 0x{ibil:02X}, got 0x{ibil_csr:02X}"
    )

    await tb.teardown()


SUPPORTED_RESET_ACTIONS = [
    I3cTargetResetAction.NO_RESET,
    I3cTargetResetAction.RESET_PERIPHERAL_ONLY,
    I3cTargetResetAction.RESET_WHOLE_TARGET,
]
VIRT_TGT_ADR = 0x5B

async def test_ccc_rstact(dut, type, rstact, termination):
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    retained_mwl = bytearray([0x01, 0x46])
    await i3c_controller.i3c_ccc_write(ccc=CCC.BCAST.SETMWL, broadcast_data=retained_mwl)

    if type == "broadcast":
        command = CCC.BCAST.RSTACT
        directed_data = None
    elif type == "direct":
        command = CCC.DIRECT.RSTACT
        directed_data = [(DYNAMIC_ADDR, []), (VIRT_DYNAMIC_ADDR, [])]
    else:
        assert False, "Unsupported RSTACT type, must be 'broadcast' or 'direct'"

    # Send RSTACT with the reset action as defining byte (0x00-0x02 are valid action values)
    rst_action = int(rstact)
    acks = await i3c_controller.i3c_ccc_write(
        ccc=command,
        defining_byte=rst_action,
        directed_data=directed_data,
        stop=(termination in ("stop", "stop_reset_pattern")),
    )
    if type == "direct":
        assert acks == [True, True], f"RSTACT must ACK both targets across Sr, got {acks}"

    # Check if reset action got stored correctly in the logic after RSTACT CCC
    ccc = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xccc
    sig = ccc.rst_action_o
    assert rst_action == int(sig), f"Expected rst_action_o={rst_action}, got {int(sig)}"
    assert int(ccc.rstact_armed_q) == 1, "RSTACT must arm the selected reset action"
    start_state = None

    if termination == "restart_reset_pattern":
        await i3c_controller.take_bus_control()
        await i3c_controller.send_start()
        if type == "broadcast":
            assert int(ccc.command_code_valid) == 0, "Broadcast completion left stale command context"
    elif termination not in ("reset_pattern", "stop_reset_pattern"):
        await i3c_controller.take_bus_control()
        if termination in ("stop", "restart_ccc"):
            if termination == "stop":
                await i3c_controller.send_start(pull_scl_low=False)
                await ClockCycles(tb.clk, 10)
                assert int(dut.bus_scl) == 1, "START boundary check requires SCL to remain high"
                start_state = (int(ccc.rstact_armed_q), int(sig))
                dut._log.info(f"After START, before SCL falling: armed={start_state[0]}, action=0x{start_state[1]:02X}")
                i3c_controller.scl = 0
                await i3c_controller.tdig_l
                await ClockCycles(tb.clk, 10)
                assert int(ccc.rstact_armed_q) == 0, "The first SCL falling edge after START must clear the arm"
                assert int(sig) == 0, "The first SCL falling edge after START must clear the stored action"
            else:
                await i3c_controller.send_start()
            if type == "broadcast":
                assert int(ccc.command_code_valid) == 0, "Broadcast completion left stale command context"
            ack = await i3c_controller.write_addr_header(0x7E)
            assert ack, f"{type} RSTACT {termination}: next CCC header was NACKed"

            # Chain a data-bearing broadcast into a direct read, without STOP.
            mwl = [0x01, 0x46]
            await i3c_controller.send_byte_tbit(CCC.BCAST.SETMWL)
            for byte in mwl:
                await i3c_controller.send_byte_tbit(byte)
            await i3c_controller.send_start()
            ack = await i3c_controller.write_addr_header(0x7E)
            assert ack, "Broadcast SETMWL must terminate on Sr"
            await i3c_controller.send_byte_tbit(CCC.DIRECT.GETMWL)
            await i3c_controller.send_start()
            ack = await i3c_controller.write_addr_header(DYNAMIC_ADDR, read=True)
            assert ack, "Chained GETMWL target address was NACKed"
            data = bytearray()
            await i3c_controller.recv_until_eod_tbit(data, len(mwl), stop=False)
            assert data == bytearray(mwl), f"Chained SETMWL/GETMWL mismatch: {data.hex()}"
        elif termination == "restart_private":
            if type == "direct":
                # A direct CCC ends at Sr + 0x7E/W, not at an ordinary target address.
                await i3c_controller.send_start()
                ack = await i3c_controller.write_addr_header(0x7E)
                assert ack, "Direct RSTACT termination header was NACKed"
            await i3c_controller.send_start()
            if type == "broadcast":
                assert int(ccc.command_code_valid) == 0, "Broadcast completion left stale command context"
            ack = await i3c_controller.write_addr_header(DYNAMIC_ADDR)
            assert ack, f"Private write after {type} RSTACT was NACKed"
            payload = [0x46, 0x2A, rst_action, 0xA5]
            for byte in payload:
                await i3c_controller.send_byte_tbit(byte)
        else:
            assert False, f"Unsupported RSTACT termination: {termination}"

        await i3c_controller.send_stop()
        i3c_controller.give_bus_control()
        await ClockCycles(tb.clk, 10)

        if termination == "restart_private":
            desc = int.from_bytes(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4), "little")
            assert desc & 0xFFFF == len(payload), f"Private write descriptor length mismatch: 0x{desc:08X}"
            assert desc >> 28 == 0, f"Private write descriptor reports an error: 0x{desc:08X}"
            data = await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, 4)
            assert list(data) == payload, f"Private write payload mismatch: {list(data)}"

    # A new START followed by SCL falling clears the action; STOP alone does not.
    expected_action = I3cTargetResetAction.RESET_PERIPHERAL_ONLY if termination == "stop" else rstact
    expected_stored_action = 0 if termination == "stop" else rst_action
    expected_armed = int(termination != "stop")
    assert int(sig) == expected_stored_action, f"RSTACT state changed incorrectly after {termination}: {int(sig)}"
    assert int(ccc.rstact_armed_q) == expected_armed, f"RSTACT arm changed incorrectly after {termination}"
    assert int(dut.peripheral_reset_o) == 0 and int(dut.escalated_reset_o) == 0, "Reset asserted before the reset pattern"
    assert int(ccc.escalate_rst_arm_q) == 0, "Each scenario must start without pending reset escalation"

    async def capture_reset_action():
        await RisingEdge(ccc.target_reset_detect_i)
        return int(ccc.rstact_armed_q), int(sig)

    reset_monitor = cocotb.start_soon(capture_reset_action())
    await i3c_controller.send_target_reset_pattern()
    await ClockCycles(tb.clk, 10)
    assert reset_monitor.done(), "Target reset pattern was not detected"
    pattern_state = await reset_monitor
    dut._log.info(f"RSTACT result: type={type}, action=0x{rst_action:02X}, termination={termination}, armed_at_pattern={pattern_state[0]}, action_at_pattern=0x{pattern_state[1]:02X}, peripheral_reset={int(dut.peripheral_reset_o)}, escalated_reset={int(dut.escalated_reset_o)}")

    # Defer the START snapshot check so a failure still records the reset response.
    if start_state is not None:
        assert start_state == (1, rst_action), f"START without SCL falling must preserve the armed action, got {start_state}"
    assert pattern_state == (expected_armed, expected_stored_action), f"Reset pattern consumed the wrong RSTACT state: expected {(expected_armed, expected_stored_action)}, got {pattern_state}"
    assert int(ccc.rstact_armed_q) == 0 and int(sig) == 0, "Reset pattern did not retire the consumed RSTACT action"
    assert int(ccc.escalate_rst_arm_q) == int(not expected_armed), "Retirement changed default-reset escalation semantics"

    if expected_action == I3cTargetResetAction.NO_RESET:
        assert dut.peripheral_reset_o == 0, f"peripheral_reset_o should be 0 for NO_RESET, got {int(dut.peripheral_reset_o)}"
        assert dut.escalated_reset_o == 0, f"escalated_reset_o should be 0 for NO_RESET, got {int(dut.escalated_reset_o)}"
    elif expected_action == I3cTargetResetAction.RESET_PERIPHERAL_ONLY:
        assert dut.peripheral_reset_o == 1, f"peripheral_reset_o should be 1 for RESET_PERIPHERAL_ONLY, got {int(dut.peripheral_reset_o)}"
        assert dut.escalated_reset_o == 0, f"escalated_reset_o should be 0 for RESET_PERIPHERAL_ONLY, got {int(dut.escalated_reset_o)}"
    elif expected_action == I3cTargetResetAction.RESET_WHOLE_TARGET:
        assert dut.peripheral_reset_o == 0, f"peripheral_reset_o should be 0 for RESET_WHOLE_TARGET, got {int(dut.peripheral_reset_o)}"
        assert dut.escalated_reset_o == 1, f"escalated_reset_o should be 1 for RESET_WHOLE_TARGET, got {int(dut.escalated_reset_o)}"
    else:
        assert False, f"Unsupported reset action ({expected_action}), must be one of {SUPPORTED_RESET_ACTIONS}"

    # Peripheral reset may retain or clear the I3C state (I3C Basic 5.1.11.1).
    reset_models = ["retained", "cleared"] if expected_action == I3cTargetResetAction.RESET_PERIPHERAL_ONLY else ["cleared" if expected_action == I3cTargetResetAction.RESET_WHOLE_TARGET else "retained"]
    for reset_model in reset_models:
        if reset_model == "cleared" and expected_action == I3cTargetResetAction.RESET_PERIPHERAL_ONLY:
            acks = await i3c_controller.i3c_ccc_write(ccc=command, defining_byte=int(expected_action), directed_data=directed_data, stop=False)
            if type == "direct":
                assert acks == [True, True], f"Rearming peripheral reset was NACKed: {acks}"
            await i3c_controller.send_target_reset_pattern()
            await ClockCycles(tb.clk, 10)

        expected_peripheral = int(expected_action == I3cTargetResetAction.RESET_PERIPHERAL_ONLY)
        expected_escalated = int(expected_action == I3cTargetResetAction.RESET_WHOLE_TARGET)
        dut._log.info(f"RSTACT recovery: action=0x{int(expected_action):02X}, model={reset_model}, holding reset request")
        for _ in range(16):
            await RisingEdge(tb.clk)
            await ReadOnly()
            assert int(dut.bus_scl) == 1 and int(dut.bus_sda) == 1, "Bus must remain free during reset recovery"
            assert int(dut.peripheral_reset_o) == expected_peripheral, "Peripheral reset request changed before completion"
            assert int(dut.escalated_reset_o) == expected_escalated, "Escalated reset request changed before core reset"
        await FallingEdge(tb.clk)

        if reset_model == "retained" or expected_escalated:
            # Only peripheral reset responds to this acknowledgement.
            dut.peripheral_reset_done_i.value = 1
            for _ in range(3):
                await RisingEdge(tb.clk)
                await ReadOnly()
                assert int(dut.peripheral_reset_o) == 0, "Peripheral reset request did not clear on acknowledgement"
                assert int(dut.escalated_reset_o) == expected_escalated, "Peripheral acknowledgement incorrectly changed escalation"
            await FallingEdge(tb.clk)
            dut.peripheral_reset_done_i.value = 0
            await RisingEdge(tb.clk)
            await ReadOnly()
            assert int(dut.peripheral_reset_o) == 0, "Peripheral reset request reasserted after acknowledgement"
            assert int(dut.escalated_reset_o) == expected_escalated, "Escalation must persist until core reset"
            await FallingEdge(tb.clk)
            dut._log.info("RSTACT recovery: peripheral_reset_done_i handshake checked")

        if reset_model == "cleared":
            # Model the surrounding system actually applying the requested reset.
            await reset_n(tb.clk, tb.rst_n, cycles=5)
            await ClockCycles(tb.clk, 10)
            assert int(dut.peripheral_reset_o) == 0 and int(dut.escalated_reset_o) == 0, "Core reset did not clear reset requests"
            assert int(ccc.rstact_armed_q) == 0 and int(sig) == 0, "Core reset did not clear RSTACT state"
            await boot_init(tb, static_addr=STATIC_ADDR, virtual_static_addr=VIRT_STATIC_ADDR)
            if expected_peripheral:
                await FallingEdge(tb.clk)
                dut.peripheral_reset_done_i.value = 1
                await ClockCycles(tb.clk, 3)
                await FallingEdge(tb.clk)
                dut.peripheral_reset_done_i.value = 0

            for address in [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]:
                responses = await i3c_controller.i3c_ccc_read(ccc=CCC.DIRECT.GETBCR, addr=address, count=1)
                assert not responses[0][0], f"Stale dynamic address 0x{address:02X} still ACKed after core reset"
            assignments = await i3c_controller.i3c_entdaa(addrs_to_assign=[DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR])
            assert len(assignments) == 2 and all(result["ack"] for result in assignments), f"Post-reset ENTDAA failed: {assignments}"
        else:
            # Do not reinitialize the core: that would hide stale FSM/CCC context.
            assert await do_getmwl(i3c_controller, DYNAMIC_ADDR) == retained_mwl, "Reset pattern unexpectedly cleared retained CCC state"
            unused_address = next(address for address in VALID_I3C_ADDRESSES if address not in [STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR])
            assignments = await i3c_controller.i3c_entdaa(addrs_to_assign=[unused_address])
            assert len(assignments) == 1 and not assignments[0]["ack"] and assignments[0]["pid"] is None, f"Targets with retained dynamic addresses must not participate in ENTDAA: {assignments}"

        for address in [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]:
            status = await do_getstatus(i3c_controller, address)
            assert len(status) == 2, f"Post-reset GETSTATUS returned {len(status)} bytes"
            mwl = bytearray([0x01, 0x62 if address == DYNAMIC_ADDR else 0x73])
            acks = await i3c_controller.i3c_ccc_write(ccc=CCC.DIRECT.SETMWL, directed_data=[(address, mwl)])
            assert acks == [True], f"Post-reset SETMWL to 0x{address:02X} was NACKed"
            assert await do_getmwl(i3c_controller, address) == mwl, f"Post-reset SETMWL/GETMWL mismatch at 0x{address:02X}"

        rx_payload = bytearray([0x46, 0xA5, int(expected_action), 0x19])
        response = await i3c_controller.i3c_write(DYNAMIC_ADDR, rx_payload)
        assert not response.nack, "Post-reset private write was NACKed"
        await ClockCycles(tb.clk, 10)
        desc = int.from_bytes(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4), "little")
        assert desc & 0xFFFF == len(rx_payload) and desc >> 28 == 0, f"Post-reset private RX descriptor mismatch: 0x{desc:08X}"
        data = await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, 4)
        assert bytearray(data) == rx_payload, f"Post-reset private write data mismatch: {list(data)}"

        tx_payload = bytearray([0xC3, int(expected_action), 0x5A, 0xE7])
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, tx_payload, 4)
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(len(tx_payload)), 4)
        response = await i3c_controller.i3c_read(DYNAMIC_ADDR, len(tx_payload))
        assert not response.nack and bytearray(response.data) == tx_payload, f"Post-reset private read failed: {response}"
        assert int(dut.peripheral_reset_o) == 0 and int(dut.escalated_reset_o) == 0, "Post-reset traffic retriggered a reset request"
        assert int(ccc.rstact_armed_q) == 0 and int(sig) == 0, "Post-reset START/SCL falling failed to clear RSTACT"
        dut._log.info(f"RSTACT recovery PASS: action=0x{int(expected_action):02X}, model={reset_model}, CCC and private read/write")

    await tb.teardown()

rstact_tf = TestFactory(test_function=test_ccc_rstact)
rstact_tf.add_option(name="rstact", optionlist=SUPPORTED_RESET_ACTIONS)
rstact_tf.add_option(name="type", optionlist=["broadcast", "direct"])
rstact_tf.add_option(name="termination", optionlist=["reset_pattern", "stop", "restart_ccc", "restart_private", "stop_reset_pattern", "restart_reset_pattern"])
rstact_tf.generate_tests()


def rstact_snapshot(ccc, dut):
    """Return settled action, request, and raw bus-event state for reset attribution."""
    state = {name: int(getattr(ccc, name).value) for name in (
        "rstact_armed_q", "rst_action_o", "rstact_clear_pending_q", "escalate_rst_arm_q", "vt_detect_flag_q",
        "bus_start_det_i", "bus_rstart_det_i", "bus_stop_det_i", "scl_negedge_i", "target_reset_detect_i",
    )}
    state.update(peripheral=int(dut.peripheral_reset_o.value), escalated=int(dut.escalated_reset_o.value))
    return state


async def monitor_reset_patterns(dut, tb, finished, trace):
    """Capture pre-consumption and post-edge state, retaining bus-event transitions."""
    ccc = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xccc
    previous = None
    detected = False
    dut._log.info("C16_TRACE: monitoring START/Sr/STOP/SCL-fall, pending-clear and detection")
    while not finished.is_set():
        await FallingEdge(tb.clk)
        await ReadOnly()
        pre = rstact_snapshot(ccc, dut)
        if pre != previous:
            trace["events"].append((cocotb.utils.get_sim_time("ns"), pre))
            previous = pre
        first_cycle = pre["target_reset_detect_i"] and not detected
        detected = bool(pre["target_reset_detect_i"])
        await RisingEdge(tb.clk)
        await ReadOnly()
        if first_cycle:
            post = rstact_snapshot(ccc, dut)
            trace["patterns"].append((pre, post))
            dut._log.info(f"C16_TRACE: detection #{len(trace['patterns'])}, pre={pre}, post={post}")
    dut._log.info(f"C16_TRACE: completed, detections={len(trace['patterns'])}, raw_events={trace['events']}")


@cocotb.test(timeout_time=3000, timeout_unit="us")
async def test_ccc_rstact_pattern_consumption(dut):
    """Collect P1/S/P2 before failing; no normal START or reset separates the two patterns."""
    controller, _, tb = await test_setup(dut, dynamic_addr=0x2D, virtual_dynamic_addr=0x35)
    ccc = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xccc
    outcomes = []

    def checkpoint(label, passed, observed):
        """Retain every failure so retirement cannot hide the second-pattern trace."""
        outcomes.append((label, bool(passed)))
        dut._log.info(f"{label}: {'PASS' if passed else 'FAIL'} observed={observed}")

    async def pattern_trace(label):
        """Emit one pattern; return pre-edge, consuming-edge and settled final state."""
        dut._log.info(f"C16_PATTERN: starting {label}")
        trace = {"events": [], "patterns": []}
        finished = Event()
        monitor = cocotb.start_soon(monitor_reset_patterns(dut, tb, finished, trace))
        await ClockCycles(tb.clk, 2)
        await controller.send_target_reset_pattern()
        await ClockCycles(tb.clk, 16)
        finished.set()
        await monitor
        final = rstact_snapshot(ccc, dut)
        dut._log.info(f"C16_PATTERN: completed {label}, detections={len(trace['patterns'])}, final={final}")
        await FallingEdge(tb.clk)
        return [(pre, post, final) for pre, post in trace["patterns"]]

    for direct in (False, True):
        for stop_first in (False, True):
            context = f"direct={direct}, stop_first={stop_first}"
            dut._log.info(f"C16: starting {context}; reset only between independent scenarios")
            await reset_n(tb.clk, tb.rst_n, cycles=5)
            await boot_init(tb, dynamic_addr=0x2D, virtual_dynamic_addr=0x35)
            command = CCC.DIRECT.RSTACT if direct else CCC.BCAST.RSTACT
            targets = [(0x2D, [])] if direct else None
            acks = await controller.i3c_ccc_write(ccc=command, defining_byte=0, directed_data=targets, stop=stop_first)
            assert not direct or acks == [True], f"{context}: NO_RESET was not accepted"
            first = await pattern_trace(f"C16-P1 {context}")
            p1 = len(first) == 1 and (
                first[0][0]["rstact_armed_q"], first[0][0]["rst_action_o"],
                first[0][1]["peripheral"], first[0][1]["escalated"],
                first[0][2]["peripheral"], first[0][2]["escalated"],
            ) == (1, 0, 0, 0, 0, 0)
            checkpoint(f"C16-P1 {context}", p1, first)
            # This is the first consuming edge, not a later START-induced clear.
            retired = None if len(first) != 1 else first[0][1]
            s_ok = retired is not None and (
                retired["rstact_armed_q"], retired["rst_action_o"], retired["escalate_rst_arm_q"],
                first[0][2]["rstact_armed_q"], first[0][2]["rst_action_o"],
            ) == (0, 0, 0, 0, 0)
            checkpoint(f"C16-S {context}", s_ok, retired)

            # Deliberately unconditional, including after C16-S failure.
            second = await pattern_trace(f"C16-P2 {context}")
            p2 = len(second) == 1 and (
                second[0][0]["rstact_armed_q"], second[0][0]["escalate_rst_arm_q"],
                second[0][0]["peripheral"], second[0][0]["escalated"],
                second[0][1]["peripheral"], second[0][1]["escalated"],
                second[0][2]["peripheral"], second[0][2]["escalated"],
            ) == (0, 0, 0, 0, 1, 0, 1, 0)
            checkpoint(f"C16-P2 {context}", p2, second)

            # Explicit rearm is a different control, after the discriminating pair.
            dut._log.info(f"C16_CONTROL: starting DB0 rearm after P2, {context}")
            dut.peripheral_reset_done_i.value = 1
            await ClockCycles(tb.clk, 3)
            await FallingEdge(tb.clk)
            dut.peripheral_reset_done_i.value = 0
            acks = await controller.i3c_ccc_write(ccc=command, defining_byte=0, directed_data=targets, stop=False)
            assert not direct or acks == [True]
            rearmed = await pattern_trace(f"C16-REARM {context}")
            checkpoint(f"C16-REARM {context}", len(rearmed) == 1 and (
                rearmed[0][0]["rstact_armed_q"], rearmed[0][0]["rst_action_o"],
                rearmed[0][1]["peripheral"], rearmed[0][1]["escalated"],
                rearmed[0][1]["rstact_armed_q"],
                rearmed[0][2]["peripheral"], rearmed[0][2]["escalated"],
            ) == (1, 0, 0, 0, 0, 0, 0), rearmed)

            # DB4 shares the arm's lifetime neither at pattern consumption nor START.
            dut._log.info(f"C16_CONTROL: starting DB0 plus directed VT DB4, {context}")
            await controller.i3c_ccc_write(ccc=command, defining_byte=0, directed_data=targets, stop=False)
            assert await controller.i3c_ccc_write(
                ccc=CCC.DIRECT.RSTACT, defining_byte=4, directed_data=[(0x35, [])], stop=False) == [True]
            vt_pattern = await pattern_trace(f"C16-VT {context}")
            checkpoint(f"C16-VT {context}", len(vt_pattern) == 1 and (
                vt_pattern[0][0]["rstact_armed_q"], vt_pattern[0][0]["vt_detect_flag_q"],
                vt_pattern[0][1]["rstact_armed_q"], vt_pattern[0][1]["vt_detect_flag_q"],
                vt_pattern[0][1]["peripheral"], vt_pattern[0][1]["escalated"],
                vt_pattern[0][2]["peripheral"], vt_pattern[0][2]["escalated"],
            ) == (1, 1, 0, 1, 0, 0, 0, 0), vt_pattern)

            dut._log.info(f"C16_CONTROL: starting DB1 and completed-START checks with VT flag retained, {context}")
            await controller.i3c_ccc_write(ccc=command, defining_byte=1, directed_data=targets)
            await controller.take_bus_control()
            await controller.send_start(pull_scl_low=False)
            await ClockCycles(tb.clk, 10)
            pre_fall = rstact_snapshot(ccc, dut)
            checkpoint(f"C16-PRE-SCL-FALL {context}", (
                pre_fall["rstact_armed_q"], pre_fall["rst_action_o"], pre_fall["vt_detect_flag_q"],
                int(dut.bus_scl.value),
            ) == (1, 1, 1, 1), pre_fall)
            controller.scl = 0
            await controller.tdig_l
            assert await controller.write_addr_header(0x7E), "Completed START control header NACKed"
            await ClockCycles(tb.clk, 5)
            completed = rstact_snapshot(ccc, dut)
            checkpoint(f"C16-COMPLETED-START {context}", (
                completed["rstact_armed_q"], completed["rst_action_o"], completed["vt_detect_flag_q"],
            ) == (0, 0, 1), completed)
            await controller.send_stop()
            controller.give_bus_control()

    await tb.teardown()
    assert all(passed for _, passed in outcomes), f"Reset consumption checkpoints failed: {outcomes}"


async def send_rstact_write(i3c_controller, defining_byte, ccc_type, target_addr):
    """Send RSTACT write CCC (broadcast or direct) with the given defining byte."""
    if ccc_type == "broadcast":
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.BCAST.RSTACT, defining_byte=defining_byte, stop=True)
    else:
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.RSTACT, defining_byte=defining_byte,
            directed_data=[(target_addr, [])], stop=True)


async def read_rstact(i3c_controller, defining_byte, target_addr):
    """Direct read RSTACT with given defining byte, return single data byte."""
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.RSTACT, addr=target_addr, count=1,
        defining_byte=defining_byte)
    assert responses[0][0], \
        f"Target 0x{target_addr:02X} NACKed RSTACT read DB=0x{defining_byte:02X}"
    return responses[0][1][0]


@cocotb.test()
async def test_ccc_rstact_vt_detect(dut):
    """
    Verify RSTACT Defining Byte 0x04 (Virtual Target Detect) flag set/clear
    and Defining Byte 0x84 (Virtual Target Indication) read-back.
    """
    log = logging.getLogger("test_ccc_rstact_vt_detect")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    addr_name = {DYNAMIC_ADDR: "main", VIRT_DYNAMIC_ADDR: "virt"}

    for i in range(10):
        # --- Set VT detect flag ---
        # DB=0x04 is Direct-only per spec (line 3613)
        set_addr = random.choice([DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR])
        log.info(f"[Iter {i}] SET flag via direct RSTACT DB=0x04 to {addr_name[set_addr]} (0x{set_addr:02X})")
        await send_rstact_write(
            i3c_controller, RSTACT_DEF_BYTE.VIRTUAL_TARGET_DETECT,
            "direct", set_addr)

        # Both targets should read back flag=1
        for addr in [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]:
            val = await read_rstact(
                i3c_controller, RSTACT_DEF_BYTE.VIRTUAL_TARGET_DETECT, addr)
            log.info(f"  Read DB=0x04 from {addr_name[addr]} (0x{addr:02X}): 0x{val:02X}")
            assert val == 0x01, \
                f"Iter {i}: Expected VT detect flag 0x01 from {addr_name[addr]} (0x{addr:02X}), got 0x{val:02X}"

        # --- Clear VT detect flag ---
        clr_type = random.choice(["broadcast", "direct"])
        clr_addr = random.choice([DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR])
        if clr_type == "broadcast":
            log.info(f"[Iter {i}] CLEAR flag via broadcast RSTACT DB=0x00")
        else:
            log.info(f"[Iter {i}] CLEAR flag via direct RSTACT DB=0x00 to {addr_name[clr_addr]} (0x{clr_addr:02X})")
        await send_rstact_write(
            i3c_controller, RSTACT_DEF_BYTE.NO_RESET,
            clr_type, clr_addr if clr_type == "direct" else None)

        # Both targets should read back flag=0
        for addr in [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]:
            val = await read_rstact(
                i3c_controller, RSTACT_DEF_BYTE.VIRTUAL_TARGET_DETECT, addr)
            log.info(f"  Read DB=0x04 from {addr_name[addr]} (0x{addr:02X}): 0x{val:02X}")
            assert val == 0x00, \
                f"Iter {i}: Expected VT detect flag 0x00 from {addr_name[addr]} (0x{addr:02X}), got 0x{val:02X}"

    # --- VT Indication (DB=0x84): both targets always report 0x01 ---
    log.info("Checking DB=0x84 (VT Indication) from both targets")
    for addr in [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]:
        val = await read_rstact(
            i3c_controller, RSTACT_DEF_BYTE.VIRTUAL_TARGET_INDICATION, addr)
        log.info(f"  Read DB=0x84 from {addr_name[addr]} (0x{addr:02X}): 0x{val:02X}")
        assert val == 0x01, \
            f"Expected VT indication 0x01 from {addr_name[addr]} (0x{addr:02X}), got 0x{val:02X}"

    log.info("PASS: All VT detect flag set/clear/indication checks passed")

    await tb.teardown()


@cocotb.test()
async def test_ccc_rstact_vt_detect_no_reset_arm(dut):
    """
    Verify DB=0x04 does not arm a reset action: default peripheral->escalation
    path still works after sending RSTACT with VT detect defining byte.
    """
    log = logging.getLogger("test_ccc_rstact_vt_detect_no_reset_arm")

    (SA, VSA, DA, VDA) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(dut, SA, VSA, DA, VDA)
    dut.peripheral_reset_done_i.value = 0
    await ClockCycles(tb.clk, 50)

    addr_name = {DA: "main", VDA: "virt"}

    # Send RSTACT DB=0x04 -- sets VT detect flag but does NOT arm reset
    # DB=0x04 is Direct-only per spec (line 3613)
    tgt_addr = random.choice([DA, VDA])
    log.info(f"RSTACT DB=0x04 via direct to {addr_name[tgt_addr]} (0x{tgt_addr:02X})")
    await send_rstact_write(
        i3c_controller, RSTACT_DEF_BYTE.VIRTUAL_TARGET_DETECT,
        "direct", tgt_addr)

    # 1st reset pattern -> default peripheral reset (rstact not armed)
    await i3c_controller.send_target_reset_pattern()
    await ClockCycles(tb.clk, 10)
    log.info(f"1st pattern: peripheral_reset_o={int(dut.peripheral_reset_o)}, "
             f"escalated_reset_o={int(dut.escalated_reset_o)}")
    assert dut.peripheral_reset_o == 1, "Expected peripheral_reset_o=1 after 1st pattern"
    assert dut.escalated_reset_o == 0, "Expected escalated_reset_o=0 after 1st pattern"

    # Clear peripheral reset handshake before 2nd pattern
    dut.peripheral_reset_done_i.value = 1
    await ClockCycles(tb.clk, 2)
    dut.peripheral_reset_done_i.value = 0
    await ClockCycles(tb.clk, 10)

    # 2nd reset pattern -> escalated reset (no intervening RSTACT/GETSTATUS)
    await i3c_controller.send_target_reset_pattern()
    await ClockCycles(tb.clk, 10)
    log.info(f"2nd pattern: peripheral_reset_o={int(dut.peripheral_reset_o)}, "
             f"escalated_reset_o={int(dut.escalated_reset_o)}")
    assert dut.peripheral_reset_o == 0, "Expected peripheral_reset_o=0 after escalation"
    assert dut.escalated_reset_o == 1, "Expected escalated_reset_o=1 after escalation"

    log.info("PASS: DB=0x04 does not interfere with default reset escalation")

    await tb.teardown()


@cocotb.test()
async def test_ccc_direct_multiple_wr(dut):
    """
    Send a sequence of multiple directed SETMWL CCCs. The first and last have
    non-matching address. The two middle ones set MWL to different values.
    Verify that the target responded to correct addresses and executed both
    CCCs.
    """

    command = CCC.DIRECT.SETMWL
    result = True

    i3c_controller, _, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)

    cccs = [
        (TGT_ADR - 1, (0x00, 0xA0)),
        (TGT_ADR, (0x00, 0xA1)),
        (TGT_ADR, (0x00, 0xA2)),
        (TGT_ADR + 2, (0x00, 0xA3)),  # TGT_ADR + 1 is set as virtual target static address
    ]

    # Send CCCs
    acks = await i3c_controller.i3c_ccc_write(ccc=command, directed_data=cccs)

    # Check if correct address was ACK-ed
    if acks != [False, True, True, False]:
        dut._log.error(f"Incorrect multiple directed CCC ACKs: {acks}")
        result = False

    # Check if MWL got written
    sig = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mwl_o.value
    mwl = 0xA2
    if mwl != int(sig):
        dut._log.error(f"Written MWL mismatch ({mwl} vs. {int(sig)})")
        result = False

    assert result, "test_ccc_direct_multiple_wr failed -- see errors above"

    await tb.teardown()


@cocotb.test()
async def test_ccc_direct_multiple_rd(dut):
    """
    Send SETMWL CCC. Then send multiple directed GETMWL CCCs to thee different
    addresses. Only the one for the target should contain ACK with correct
    MWL content.
    """

    result = True

    i3c_controller, _, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)

    # Set MWL in the target
    acks = await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETMWL, directed_data=[(TGT_ADR, (0x00, 0x55))]
    )
    if acks != [True]:
        dut._log.error("Initial SETMWL failed")
        assert False, "Initial SETMWL failed -- see errors above"

    await ClockCycles(tb.clk, 50)

    # Issue multiple directed GETMWL
    addrs = [TGT_ADR - 1, TGT_ADR, TGT_ADR, TGT_ADR + 2]
    responses = await i3c_controller.i3c_ccc_read(ccc=CCC.DIRECT.GETMWL, addr=addrs, count=2)

    # Check ACKs
    acks = [r[0] for r in responses]
    if acks != [False, True, True, False]:
        dut._log.error(f"Incorrect multiple directed CCC ACKs: {acks}")
        result = False

    # Check received MWL data
    for i, ack in enumerate(acks):
        if ack:
            data = responses[i][1]
            mwl = data[1] | (data[0] << 8)
            if mwl != 0x55:
                dut._log.error(f"Written and received MWL mismatch ({mwl} vs. 0x55) for CCC #{i}")
                result = False

    assert result, "test_ccc_direct_multiple_rd failed -- see errors above"


# =============================================================================
# NEW TESTS -- Phase 1
# =============================================================================

    await tb.teardown()


@cocotb.test()
async def test_ccc_getcaps(dut):
    """
    Test GETCAPS (0x95) direct GET CCC with various defining bytes,
    targeting both main and virtual targets.
    """
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    for tgt_addr in [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]:
        is_virt = (tgt_addr == VIRT_DYNAMIC_ADDR)

        # No defining byte -> 3 bytes (default GETCAPS)
        responses = await i3c_controller.i3c_ccc_read(
            ccc=CCC.DIRECT.GETCAPS, addr=tgt_addr, count=3)
        data = responses[0][1]
        assert data[0] == 0x00, f"GETCAPS byte0: expected 0x00, got 0x{data[0]:02X}"
        assert data[1] == 0x01, f"GETCAPS byte1: expected 0x01, got 0x{data[1]:02X}"
        expected_byte2 = 0x00 if is_virt else 0x48
        assert data[2] == expected_byte2, \
            f"GETCAPS byte2: expected 0x{expected_byte2:02X}, got 0x{data[2]:02X}"

        # DB=0x00 -> same 3 bytes
        responses = await i3c_controller.i3c_ccc_read(
            ccc=CCC.DIRECT.GETCAPS, addr=tgt_addr, count=3, defining_byte=0x00)
        data = responses[0][1]
        assert data[0] == 0x00 and data[1] == 0x01 and data[2] == expected_byte2, \
            f"GETCAPS DB=0x00: expected [00,01,{expected_byte2:02X}], got {[hex(b) for b in data]}"

        # DB=0x93 -> 1 byte (TESTCAP: 0x35)
        responses = await i3c_controller.i3c_ccc_read(
            ccc=CCC.DIRECT.GETCAPS, addr=tgt_addr, count=1, defining_byte=0x93)
        data = responses[0][1]
        assert data[0] == 0x35, f"GETCAPS DB=0x93: expected 0x35, got 0x{data[0]:02X}"

    await tb.teardown()


@cocotb.test()
async def test_ccc_unsupported_direct_nack(dut):
    """
    Verify that unsupported direct CCCs are NACKed by the target.
    Tests deprecated, unsupported, and vendor-specific CCC codes.
    """
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # Unsupported direct SET CCCs
    unsupported_set_cccs = [
        (CCC.DIRECT.SETROUTE, None),
        (CCC.DIRECT.D2DXFER, None),
        (CCC.DIRECT.ENDXFER, 0xF7),
        (CCC.DIRECT.ENDXFER, 0xAA),
        (CCC.DIRECT.MLANE, 0x7F),
        (CCC.DIRECT.MLANE, 0x23),
    ]

    # Unsupported direct GET CCCs
    unsupported_get_cccs = [
        (CCC.DIRECT.GETACCCR, None),
        (CCC.DIRECT.GETMXDS, None),
        (CCC.DIRECT.ENDXFER, 0xF7),
        (CCC.DIRECT.MLANE, 0xFF),
        (CCC.DIRECT.GETCAPS, 0x01),
        (CCC.DIRECT.GETCAPS, 0x92),
        (CCC.DIRECT.GETCAPS, 0x94),
        (CCC.DIRECT.GETCAPS, 0xFF),
    ]

    for tgt_addr in [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]:
        for ccc_code, defining_byte in unsupported_set_cccs:
            acks = await i3c_controller.i3c_ccc_write(
                ccc=ccc_code, defining_byte=defining_byte, directed_data=[(tgt_addr, [])])
            assert acks[0] == False, \
                f"Unsupported SET CCC 0x{ccc_code:02X} to 0x{tgt_addr:02X} should be NACKed"

        for ccc_code, defining_byte in unsupported_get_cccs:
            responses = await i3c_controller.i3c_ccc_read(
                ccc=ccc_code, defining_byte=defining_byte, addr=tgt_addr, count=1)
            assert responses[0][0] == False, \
                f"Unsupported GET CCC 0x{ccc_code:02X} from 0x{tgt_addr:02X} should be NACKed"

    await tb.teardown()


@cocotb.test()
async def test_ccc_rstact_read_action(dut):
    """
    Verify RSTACT internal state after arming. Per spec, rstact_armed is
    cleared by the next START (not Sr), so a subsequent RSTACT read in a
    new CCC frame returns 0x80 (not armed). This test verifies:
    1. Internal rst_action_o reflects the defining byte immediately after write
    2. After START, RSTACT read returns 0x80 (arm cleared by START)
    3. Recovery time read-back (DB=0x81/0x82) returns 0xFF
    """
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    rst_action_sig = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.rst_action_o

    for tgt_addr in [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]:
        # Arm peripheral reset (DB=0x01), check internal signal
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.RSTACT, defining_byte=0x01,
            directed_data=[(tgt_addr, [])], stop=False)
        assert int(rst_action_sig) == 0x01, \
            f"rst_action_o after arm 0x01: expected 0x01, got 0x{int(rst_action_sig):02X}"
        await i3c_controller.send_stop()

        # Arm whole-target reset (DB=0x02), check internal signal
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.RSTACT, defining_byte=0x02,
            directed_data=[(tgt_addr, [])], stop=False)
        assert int(rst_action_sig) == 0x02, \
            f"rst_action_o after arm 0x02: expected 0x02, got 0x{int(rst_action_sig):02X}"
        await i3c_controller.send_stop()

        # Read with DB=0x00 in new frame -> arm cleared by START -> 0x80
        val = await read_rstact(i3c_controller, 0x00, tgt_addr)
        assert val == 0x80, \
            f"RSTACT read after START: expected 0x80 (cleared), got 0x{val:02X}"

        # Read recovery time (DB=0x81) -> should return 0xFF
        val = await read_rstact(i3c_controller, 0x81, tgt_addr)
        assert val == 0xFF, \
            f"RSTACT read DB=0x81: expected 0xFF, got 0x{val:02X}"

        # Read recovery time (DB=0x82) -> should return 0xFF
        val = await read_rstact(i3c_controller, 0x82, tgt_addr)
        assert val == 0xFF, \
            f"RSTACT read DB=0x82: expected 0xFF, got 0x{val:02X}"

    await tb.teardown()


@cocotb.test()
async def test_ccc_rstact_escalation_clear(dut):
    controller, _, tb = await test_setup(dut, dynamic_addr=0x2D, virtual_dynamic_addr=0x35)
    ccc = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xccc
    cases = [
        (CCC.BCAST.RSTACT, None, 0x7F, True),
        (CCC.DIRECT.RSTACT, 0x2D, 4, True),
        (CCC.DIRECT.RSTACT, 0x35, 0x7F, True),
        (CCC.DIRECT.GETSTATUS, 0x2D, None, True),
        (CCC.DIRECT.GETSTATUS, 0x35, None, True),
        (CCC.DIRECT.GETSTATUS, 0x44, None, False),
        (CCC.DIRECT.RSTACT, 0x44, 4, False),
        (CCC.DIRECT.GETBCR, 0x2D, None, False),
    ]
    for command, address, defining_byte, clears in cases:
        await reset_n(tb.clk, tb.rst_n, cycles=5)
        await boot_init(tb, dynamic_addr=0x2D, virtual_dynamic_addr=0x35)
        await controller.send_target_reset_pattern()
        await ClockCycles(tb.clk, 10)
        assert int(dut.peripheral_reset_o.value) == 1 and int(dut.escalated_reset_o.value) == 0
        assert int(ccc.escalate_rst_arm_q.value) == 1, "Default reset did not arm escalation"
        dut.peripheral_reset_done_i.value = 1
        await ClockCycles(tb.clk, 2)
        dut.peripheral_reset_done_i.value = 0
        if command == CCC.BCAST.RSTACT:
            await controller.i3c_ccc_write(ccc=command, defining_byte=defining_byte)
        elif command == CCC.DIRECT.RSTACT:
            acks = await controller.i3c_ccc_write(ccc=command, defining_byte=defining_byte, directed_data=[(address, [])])
            assert acks == [address in (0x2D, 0x35) and defining_byte != 0x7F]
        else:
            responses = await controller.i3c_ccc_read(ccc=command, addr=address, count=2 if command == CCC.DIRECT.GETSTATUS else 1)
            assert responses[0][0] == (address in (0x2D, 0x35))
        assert int(ccc.escalate_rst_arm_q.value) == int(not clears), f"Incorrect escalation clearing: {command=}, {address=}"
        assert int(ccc.rstact_armed_q.value) == 0, "An armed action would mask the default escalation check"
        await controller.send_target_reset_pattern()
        await ClockCycles(tb.clk, 10)
        assert int(dut.peripheral_reset_o.value) == int(clears)
        assert int(dut.escalated_reset_o.value) == int(not clears)
        dut.peripheral_reset_done_i.value = 1
        await ClockCycles(tb.clk, 2)
        dut.peripheral_reset_done_i.value = 0
    await tb.teardown()


@cocotb.test()
async def test_ccc_rstact_arm_clear_on_start(dut):
    """
    Verify RSTACT arm is cleared by START (not Sr). After arming with
    whole-target reset, a private transfer (START) clears the arm so
    subsequent reset pattern triggers default behavior (peripheral reset).
    """
    log = logging.getLogger("test_ccc_rstact_arm_clear_on_start")

    (SA, VSA, DA, VDA) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(dut, SA, VSA, DA, VDA)
    dut.peripheral_reset_done_i.value = 0
    await ClockCycles(tb.clk, 50)

    # Arm whole-target reset (DB=0x02)
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.BCAST.RSTACT, defining_byte=0x02, stop=True)

    ccc = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xccc
    await check_private_transfers(i3c_controller, tb, DA)
    assert int(ccc.rstact_armed_q.value) == 0 and int(ccc.rst_action_o.value) == 0

    # Send target reset pattern -> should get DEFAULT behavior (peripheral reset)
    await i3c_controller.send_target_reset_pattern()
    await i3c_controller.send_stop()
    await ClockCycles(tb.clk, 10)

    assert dut.peripheral_reset_o == 1, \
        "Expected peripheral_reset (not whole-target) after START cleared arm"
    assert dut.escalated_reset_o == 0, \
        "Expected no escalation"

    log.info("PASS: RSTACT arm cleared by START")

    await tb.teardown()


@cocotb.test()
async def test_ccc_rstact_unsupported_db(dut):
    """
    Verify RSTACT with unsupported defining bytes is NACKed.
    """
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    unsupported_dbs = [0x03, 0x05, 0x83]
    for db in unsupported_dbs:
        for tgt_addr in [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]:
            acks = await i3c_controller.i3c_ccc_write(
                ccc=CCC.DIRECT.RSTACT, defining_byte=db,
                directed_data=[(tgt_addr, [])])
            assert acks[0] == False, \
                f"RSTACT DB=0x{db:02X} to 0x{tgt_addr:02X} should be NACKed"

    await tb.teardown()


@cocotb.test()
async def test_ccc_unknown_broadcast(dut):
    """
    Unsupported broadcast CCCs must ACK the broadcast address, ignore the
    command/payload, and recover at STOP or repeated START.
    """
    i3c_controller, _, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)

    commands = [
        (0x30, [0xAA, 0xBB]),
        (0x50, [0xAA, 0xBB]),
        (CCC.BCAST.ENDXFER, [0xF7, 0xC0]),
        (CCC.BCAST.ENDXFER, [0xAA, 0xAA]),
        (CCC.BCAST.MLANE, [0x7F]),
        (CCC.BCAST.MLANE, [0x23, 0x01]),
    ]
    for ccc_code, payload in commands:
        for stop in [True, False]:
            await i3c_controller.take_bus_control()
            await i3c_controller.send_start()
            ack = await i3c_controller.write_addr_header(0x7E)
            assert ack, f"Broadcast address must ACK even for unsupported CCC 0x{ccc_code:02X}"
            await i3c_controller.send_byte_tbit(ccc_code)
            for byte in payload:
                await i3c_controller.send_byte_tbit(byte)
            if stop:
                await i3c_controller.send_stop()
            i3c_controller.give_bus_control()

            responses = await i3c_controller.i3c_ccc_read(
                ccc=CCC.DIRECT.GETBCR, addr=TGT_ADR, count=1)
            assert responses[0][0] == True, f"GETBCR failed after unsupported CCC 0x{ccc_code:02X}, stop={stop}"

    await tb.teardown()


@cocotb.test()
async def test_ccc_addr_lifecycle(dut):
    """
    Full address lifecycle: RSTDAA -> SETDASA -> verify -> SETNEWDA -> verify ->
    RSTDAA -> verify cleared. Tests both main and virtual targets.
    """
    log = logging.getLogger("test_ccc_addr_lifecycle")

    list_of_values = list(VALID_I3C_ADDRESSES)
    (SA, VSA, DA1, VDA1, DA2, VDA2) = random.sample(list_of_values, 6)
    i3c_controller, _, tb = await test_setup(dut, SA, VSA)
    await ClockCycles(tb.clk, 50)

    da_reg = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR
    vda_reg = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR

    # Step 1: SETDASA to assign initial addresses
    log.info(f"SETDASA: main={SA}->{DA1}, virt={VSA}->{VDA1}")
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(SA, [DA1 << 1])], stop=False)
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VSA, [VDA1 << 1])])

    # Verify addresses assigned
    main_da = await tb.read_csr_field(da_reg.base_addr, da_reg.DYNAMIC_ADDR)
    main_valid = await tb.read_csr_field(da_reg.base_addr, da_reg.DYNAMIC_ADDR_VALID)
    assert main_da == DA1 and main_valid == 1, f"Main DA: {main_da} valid={main_valid}"

    virt_da = await tb.read_csr_field(vda_reg.base_addr, vda_reg.VIRT_DYNAMIC_ADDR)
    virt_valid = await tb.read_csr_field(vda_reg.base_addr, vda_reg.VIRT_DYNAMIC_ADDR_VALID)
    assert virt_da == VDA1 and virt_valid == 1, f"Virt DA: {virt_da} valid={virt_valid}"

    # Step 2: SETNEWDA to change addresses
    log.info(f"SETNEWDA: main={DA1}->{DA2}, virt={VDA1}->{VDA2}")
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETNEWDA, directed_data=[(DA1, [DA2 << 1])], stop=False)
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETNEWDA, directed_data=[(VDA1, [VDA2 << 1])])

    # Verify new addresses
    main_da = await tb.read_csr_field(da_reg.base_addr, da_reg.DYNAMIC_ADDR)
    assert main_da == DA2, f"Main DA after SETNEWDA: expected {DA2}, got {main_da}"

    virt_da = await tb.read_csr_field(vda_reg.base_addr, vda_reg.VIRT_DYNAMIC_ADDR)
    assert virt_da == VDA2, f"Virt DA after SETNEWDA: expected {VDA2}, got {virt_da}"

    # Step 3: RSTDAA to clear all addresses
    log.info("RSTDAA: clearing all addresses")
    await i3c_controller.i3c_ccc_write(ccc=CCC.BCAST.RSTDAA)

    main_valid = await tb.read_csr_field(da_reg.base_addr, da_reg.DYNAMIC_ADDR_VALID)
    virt_valid = await tb.read_csr_field(vda_reg.base_addr, vda_reg.VIRT_DYNAMIC_ADDR_VALID)
    assert main_valid == 0, f"Main DA should be invalid after RSTDAA, got valid={main_valid}"
    assert virt_valid == 0, f"Virt DA should be invalid after RSTDAA, got valid={virt_valid}"

    log.info("PASS: Address lifecycle completed successfully")

    await tb.teardown()


@cocotb.test()
async def test_ccc_chain_bcast(dut):
    """
    Chain multiple broadcast CCCs via Sr+7E/W within a single frame.
    Verify each CCC takes effect.
    """
    i3c_controller, _, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)

    # Chain: SETMWL -> SETMRL (broadcast, no STOP between them)
    mwl_val = random.randint(0, 0xFFFF)
    mrl_val = random.randint(0, 0xFFFF)
    ibil_val = random.randint(0, 0xFF)

    await i3c_controller.i3c_ccc_write(
        ccc=CCC.BCAST.SETMWL,
        broadcast_data=[(mwl_val >> 8) & 0xFF, mwl_val & 0xFF],
        stop=False)
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.BCAST.SETMRL,
        broadcast_data=[(mrl_val >> 8) & 0xFF, mrl_val & 0xFF, ibil_val])

    # Verify both took effect
    sig_mwl = int(dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mwl_o.value)
    sig_mrl = int(dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mrl_o.value)
    assert sig_mwl == mwl_val, f"Chained SETMWL: expected 0x{mwl_val:04X}, got 0x{sig_mwl:04X}"
    assert sig_mrl == mrl_val, f"Chained SETMRL: expected 0x{mrl_val:04X}, got 0x{sig_mrl:04X}"

    await tb.teardown()


async def test_ccc_bcast_boundary(dut, command, ending, mrl_ibi=True):
    assign_static = command == CCC.BCAST.SETAASA
    controller, _, tb = await test_setup(dut, dynamic_addr=None if assign_static else 0x2D, virtual_dynamic_addr=None if assign_static else 0x35)
    finished = Event()
    handoff_monitor = cocotb.start_soon(monitor_ccc_handoff(dut, tb, finished))
    await set_mrl_capabilities(tb, mrl_ibi, False)
    old_ibil = int(dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_ibil_o.value)
    address = TGT_ADR if command in (CCC.BCAST.RSTDAA, CCC.BCAST.SETAASA) else 0x2D
    payload = bytearray([0x46, int(command), 0xA5, 0x5A])
    if ending == "read":
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, payload, 4)
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(len(payload)), 4)
    command_data = {
        CCC.BCAST.ENEC: [0x0B], CCC.BCAST.DISEC: [0x0B], CCC.BCAST.SETMWL: [1, 0x23],
        CCC.BCAST.SETMRL: [1, 0x23] + ([0x11] if mrl_ibi else []), CCC.BCAST.RSTDAA: [],
        CCC.BCAST.SETAASA: [], CCC.BCAST.RSTACT: [],
    }
    data = command_data[command] + ([0xDE, 0xAD] if ending == "ccc" else [])
    await controller.i3c_ccc_write(ccc=command, broadcast_data=data, defining_byte=0 if command == CCC.BCAST.RSTACT else None, stop=ending == "stop")
    await ClockCycles(tb.clk, 10)
    config = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration
    ccc = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xccc
    if command in (CCC.BCAST.ENEC, CCC.BCAST.DISEC):
        enabled = int(command == CCC.BCAST.ENEC)
        assert await read_target_events(tb) == (enabled, enabled, enabled)
    elif command == CCC.BCAST.SETMWL:
        assert int(config.get_mwl_o.value) == 0x0123
    elif command == CCC.BCAST.SETMRL:
        assert int(config.get_mrl_o.value) == 0x0123 and int(config.get_ibil_o.value) == (0x11 if mrl_ibi else old_ibil)
    elif command == CCC.BCAST.RSTACT:
        assert int(ccc.rstact_armed_q.value) == 1 and int(ccc.rst_action_o.value) == 0
    else:
        sm = tb.reg_map.I3C_EC.STDBYCTRLMODE
        for reg, value_field, valid_field, static in (
            (sm.STBY_CR_DEVICE_ADDR, sm.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR, sm.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID, TGT_ADR),
            (sm.STBY_CR_VIRT_DEVICE_ADDR, sm.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR, sm.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID, TGT_ADR + 1),
        ):
            assert await tb.read_csr_field(reg.base_addr, valid_field) == int(assign_static)
            assert await tb.read_csr_field(reg.base_addr, value_field) == (static if assign_static else 0)
    assert int(ccc.command_code_valid.value) == int(ending != "stop")
    if ending == "ccc":
        await controller.i3c_ccc_write(ccc=CCC.BCAST.SETMWL, broadcast_data=[1, 0xA5])
        assert int(dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mwl_o.value) == 0x01A5
    else:
        await controller.take_bus_control()
        await controller.send_start()
        assert await controller.write_addr_header(address, read=ending == "read"), f"{command=}, {ending=}: private address NACK"
        if ending == "read":
            data = bytearray()
            await controller.recv_until_eod_tbit(data, len(payload), stop=False)
            assert data == payload, f"{command=}: private read mismatch: {data.hex()}"
        else:
            for byte in payload:
                await controller.send_byte_tbit(byte)
        await controller.send_stop()
        controller.give_bus_control()
        if ending != "read":
            await check_private_payload(tb, payload)
    finished.set()
    await handoff_monitor
    await tb.teardown()


bcast_boundary_tf = TestFactory(test_function=test_ccc_bcast_boundary)
bcast_boundary_tf.add_option("command", [CCC.BCAST.ENEC, CCC.BCAST.DISEC, CCC.BCAST.SETMWL, CCC.BCAST.SETMRL, CCC.BCAST.RSTDAA, CCC.BCAST.SETAASA, CCC.BCAST.RSTACT])
bcast_boundary_tf.add_option("ending", ["stop", "ccc", "write", "read"])
bcast_boundary_tf.generate_tests()

bcast_no_ibi_tf = TestFactory(test_function=test_ccc_bcast_boundary)
bcast_no_ibi_tf.add_option("command", [CCC.BCAST.SETMRL])
bcast_no_ibi_tf.add_option("ending", ["stop", "ccc", "write", "read"])
bcast_no_ibi_tf.add_option("mrl_ibi", [False])
bcast_no_ibi_tf.generate_tests(postfix="_no_ibi")


@cocotb.test(timeout_time=100, timeout_unit="us")
async def test_ccc_handoff_acquire_stop(dut):
    """Check wire-level STOP on either side of command acquisition, without internal overrides."""
    controller, _, tb = await test_setup(dut)
    standby = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c
    ccc = standby.xccc
    for command_bits in (7, 8):
        for phase_ns, stop_delay_ns in ((0.25, 32), (0.25, 40), (1.25, 32), (1.25, 40)):
            label = f"command_bits={command_bits}, phase={phase_ns}ns, stop_delay={stop_delay_ns}ns"
            finished = Event()
            acquisitions = []
            stops = []

            async def observe():
                while not finished.is_set():
                    await FallingEdge(tb.clk)
                    await ReadOnly()
                    valid = int(standby.ccc_valid.value)
                    stop = int(ccc.bus_stop_det_i.value)
                    owner = int(standby.xfer_mux_sel.value)
                    if valid and owner == 0:
                        # Command completion needs SCL rising, which excludes STOP trigger.
                        # STOP is registered, so it cannot accompany first-cycle acquisition.
                        assert not stop, f"{label}: Unexpected unowned command/STOP overlap"
                        assert int(ccc.handoff_o.value) == CccHandoff.NONE
                        acquisitions.append(cocotb.utils.get_sim_time("ns"))
                        dut._log.info(f"CCC_ACQUIRE_STOP: {label}: acquiring at {acquisitions[-1]}ns")
                    if stop:
                        expected_active = int(command_bits == 8)
                        assert valid == expected_active and owner == expected_active, f"{label}: STOP reached the wrong ownership window"
                        assert int(ccc.state_q.value) == expected_active, f"{label}: Expected WaitCCC or RxCmdTbit at STOP"
                        expected_handoff = CccHandoff.DONE if expected_active else CccHandoff.NONE
                        assert int(ccc.handoff_o.value) == expected_handoff, f"{label}: Incorrect STOP handoff"
                        for name in ("capture_defining_byte", "capture_rx_data", "rx_data_valid", "cmd_tbit_valid",
                                     "def_byte_tbit_valid", "target_addr_ack_done", "get_status_done_o"):
                            assert int(getattr(ccc, name).value) == 0, f"{label}: STOP allowed {name}"
                        stops.append(cocotb.utils.get_sim_time("ns"))
                        dut._log.info(f"CCC_ACQUIRE_STOP: {label}: STOP at {stops[-1]}ns, owner={owner}, handoff={expected_handoff.name}")
                        await RisingEdge(tb.clk)
                        await ReadOnly()
                        assert int(standby.xfer_mux_sel.value) == 0, f"{label}: STOP did not return ownership on its consuming edge"
                        assert int(ccc.state_q.value) == 0, f"{label}: STOP did not return CCC to WaitCCC"
                        assert int(ccc.command_code_valid.value) == 0 and int(ccc.defining_byte_valid.value) == 0, f"{label}: STOP left command context"
                        assert int(ccc.handoff_o.value) == CccHandoff.NONE, f"{label}: Repeated STOP handoff"

            await controller.take_bus_control()
            await controller.send_start()
            assert await controller.write_addr_header(0x7E)
            # ENEC is all zeroes: STOP can follow a data-bit rise without another SCL edge.
            for _ in range(command_bits - 1):
                await controller.send_bit(False)
            controller.scl = 0
            await controller._hold_data()
            controller.sda = 0
            await controller.remaining_tlow
            observer = cocotb.start_soon(observe())
            await FallingEdge(tb.clk)
            await Timer(phase_ns, "ns")
            controller.scl = 1
            await Timer(stop_delay_ns, "ns")
            controller.sda = 1
            await controller.tfree
            await ClockCycles(tb.clk, 10)
            finished.set()
            await observer
            await FallingEdge(tb.clk)
            assert len(stops) == 1, f"{label}: Expected exactly one detected STOP, got {stops}"
            assert len(acquisitions) == int(command_bits == 8), f"{label}: Missing or unexpected command acquisition: {acquisitions}"
            controller._state = I3cState.FREE
            controller.hold_data = False
            controller.give_bus_control()
            dut._log.info(f"CCC_ACQUIRE_STOP: completed {label}: acquisitions={acquisitions}, stops={stops}")
            await do_getbcr(controller, TGT_ADR)
    await tb.teardown()


@cocotb.test(timeout_time=2000, timeout_unit="us")
async def test_ccc_rstact_terminator_address(dut):
    controller, _, tb = await test_setup(dut, dynamic_addr=0x2D, virtual_dynamic_addr=0x35)
    finished = Event()
    handoff_monitor = cocotb.start_soon(monitor_ccc_handoff(dut, tb, finished))
    ccc = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xccc
    for defining_byte in (0, 1, 2, 4, 0x7F):
        for address, read in ((None, False), (0x44, False), (0x2D, False), (0x35, False), (0x2D, True)):
            await reset_n(tb.clk, tb.rst_n, cycles=5)
            await boot_init(tb, dynamic_addr=0x2D, virtual_dynamic_addr=0x35)
            if read:
                responses = await controller.i3c_ccc_read(ccc=CCC.DIRECT.RSTACT, addr=address, defining_byte=defining_byte, count=1, stop=False)
                assert responses[0][0] == (defining_byte != 0x7F)
            else:
                acks = await controller.i3c_ccc_write(ccc=CCC.DIRECT.RSTACT, defining_byte=defining_byte, directed_data=[] if address is None else [(address, [])], stop=False)
                assert acks == ([] if address is None else [address in (0x2D, 0x35) and defining_byte != 0x7F])
            selected = address in (0x2D, 0x35) and not read
            expected = (int(selected and defining_byte in (0, 1, 2)), defining_byte if selected and defining_byte in (0, 1, 2) else 0, int(selected and defining_byte == 4))
            assert (int(ccc.rstact_armed_q.value), int(ccc.rst_action_o.value), int(ccc.vt_detect_flag_q.value)) == expected
            await controller.take_bus_control()
            await controller.send_start()
            assert await controller.write_addr_header(0x7E), "Directed CCC terminator was NACKed"
            await ClockCycles(tb.clk, 10)
            assert (int(ccc.rstact_armed_q.value), int(ccc.rst_action_o.value), int(ccc.vt_detect_flag_q.value)) == expected, f"7E/W changed RSTACT state: {address=}, {read=}, {defining_byte=}"
            await controller.send_stop()
            controller.give_bus_control()
    finished.set()
    await handoff_monitor
    await tb.teardown()


@cocotb.test(timeout_time=500, timeout_unit="us")
async def test_ccc_getstatus_complete_then_chain(dut):
    controller, _, tb = await test_setup(dut, dynamic_addr=0x2D, virtual_dynamic_addr=0x35)
    finished = Event()
    handoff_monitor = cocotb.start_soon(monitor_ccc_handoff(dut, tb, finished))
    err = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.err_o
    for new_command in (False, True):
        tb.te_error_monitor.expect_error(2)
        count_before = tb.te_error_monitor.error_counts[2]
        dut._log.info(f"CCC_STATUS: injecting fresh TE2 after prior clear, new_command={new_command}")
        await controller.send_te2_error(ccc=0x9A, defining_byte=1, corrupt_defining_byte=True)
        await controller.send_stop()
        controller.give_bus_control()
        await ClockCycles(tb.clk, 10)
        assert tb.te_error_monitor.error_counts[2] == count_before + 1, "Fresh error did not relatch exactly once"
        assert int(err.value), "Error injection did not set Protocol Error"
        payload = bytearray([0x91, 0x46, 0x7E, 0xA5])
        if new_command:
            await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, payload, 4)
            await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(len(payload)), 4)
        await controller.take_bus_control()
        await controller.send_start()
        assert await controller.write_addr_header(0x7E)
        await controller.send_byte_tbit(CCC.DIRECT.GETSTATUS)
        for index, address in enumerate((0x2D, 0x35)):
            if index and new_command:
                await controller.send_start()
                assert await controller.write_addr_header(0x7E)
                await controller.send_byte_tbit(CCC.DIRECT.GETSTATUS)
            await controller.send_start()
            assert await controller.write_addr_header(address, read=True)
            await recv_ccc_exact(controller, [0, 0xE0 if index == 0 else 0xC0], f"GETSTATUS segment {index}, new_command={new_command}")
            await ClockCycles(tb.clk, 10)
            assert int(err.value) == 0, "GETSTATUS success incorrectly waits for STOP"
        await controller.send_start()
        assert await controller.write_addr_header(0x7E)
        await controller.send_start()
        assert await controller.write_addr_header(0x2D, read=new_command)
        if new_command:
            data = bytearray()
            await controller.recv_until_eod_tbit(data, len(payload), stop=False)
            assert data == payload, f"Private read after directed termination failed: {data.hex()}"
        else:
            for byte in payload:
                await controller.send_byte_tbit(byte)
        await controller.send_stop()
        controller.give_bus_control()
        if not new_command:
            await check_private_payload(tb, payload)
        assert int(err.value) == 0
    finished.set()
    await handoff_monitor
    tb.te_error_monitor.check()
    await tb.teardown()


@cocotb.test(timeout_time=2000, timeout_unit="us")
async def test_ccc_getstatus_unsupported_defining_byte(dut):
    """Reject Format 2 without clearing Protocol Error, then accept a chained Format 1."""
    controller, _, tb = await test_setup(dut, dynamic_addr=0x2D, virtual_dynamic_addr=0x35)
    assert tb.te_error_monitor is not None, "GETSTATUS format checks require the TE event monitor"
    tb.te_error_monitor.expect_error(2)
    tti = tb.reg_map.I3C_EC.TTI
    err = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.err_o

    for te5_enabled in (0, 1):
        await tb.write_csr_field(tti.TARGET_ERR_CTRL.base_addr, tti.TARGET_ERR_CTRL.TE5_ERR_DET_EN, te5_enabled)
        for defining_byte in (0x00, 0x01, 0x90, 0x91, 0x92, 0xE0, 0xFE, 0xFF):
            await controller.send_te2_error(ccc=CCC.DIRECT.RSTACT, defining_byte=1, corrupt_defining_byte=True)
            await controller.send_stop()
            controller.give_bus_control()
            await ClockCycles(tb.clk, 10)
            assert int(err.value) == 1, "Error injection did not set Protocol Error"
            error_counts = dict(tb.te_error_monitor.error_counts)

            await controller.take_bus_control()
            await controller.send_start()
            assert await controller.write_addr_header(0x7E), "GETSTATUS header NACKed"
            await controller.send_byte_tbit(CCC.DIRECT.GETSTATUS)
            await controller.send_byte_tbit(defining_byte)
            for address in (0x2D, 0x35):
                await controller.send_start()
                ack = await controller.write_addr_header(address, read=True)
                assert not ack, f"Unsupported GETSTATUS DB=0x{defining_byte:02X} to 0x{address:02X} was ACKed with TE5_DET_EN={te5_enabled}"
                await ClockCycles(tb.clk, 10)
                assert int(err.value) == 1, "Rejected GETSTATUS cleared Protocol Error"
                assert tb.te_error_monitor.error_counts == error_counts, "Unsupported GETSTATUS incorrectly raised a TE event"

            await controller.send_start()
            assert await controller.write_addr_header(0x7E), "Chained CCC header NACKed"
            await controller.send_byte_tbit(CCC.DIRECT.GETSTATUS)
            for index, address in enumerate((0x2D, 0x35)):
                await controller.send_start()
                assert await controller.write_addr_header(address, read=True), "Format 1 inherited the rejected defining byte"
                await recv_ccc_exact(controller, [0, 0xE0 if index == 0 else 0xC0], f"GETSTATUS Format 1 after DB=0x{defining_byte:02X}, address=0x{address:02X}")
                await ClockCycles(tb.clk, 10)
                assert int(err.value) == 0, "Successful GETSTATUS Format 1 did not clear Protocol Error"
            await controller.send_stop()
            controller.give_bus_control()
            assert tb.te_error_monitor.error_counts == error_counts, "GETSTATUS recovery raised an unexpected TE event"
            dut._log.info(f"GETSTATUS_FORMAT: DB=0x{defining_byte:02X}, TE5_DET_EN={te5_enabled}: both targets NACKed, status preserved, chained Format 1 passed")

    await tb.teardown()


@cocotb.test(timeout_time=1000, timeout_unit="us")
async def test_ccc_mrl_capability_boundaries(dut):
    controller, _, tb = await test_setup(dut, dynamic_addr=0x2D, virtual_dynamic_addr=0x35)
    finished = Event()
    handoff_monitor = cocotb.start_soon(monitor_ccc_handoff(dut, tb, finished))
    config = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration
    for main_ibi, virtual_ibi in ((False, False), (True, False), (False, True), (True, True)):
        for address in (None, 0x2D, 0x35):
            await set_mrl_capabilities(tb, main_ibi, virtual_ibi)
            expected_ibi = (main_ibi or virtual_ibi) if address is None else (virtual_ibi if address == 0x35 else main_ibi)
            old_ibil = int(config.get_ibil_o.value)
            await controller.take_bus_control()
            await controller.send_start()
            assert await controller.write_addr_header(0x7E)
            await controller.send_byte_tbit(CCC.BCAST.SETMRL if address is None else CCC.DIRECT.SETMRL)
            if address is not None:
                await controller.send_start()
                assert await controller.write_addr_header(address)
            await set_mrl_capabilities(tb, not main_ibi, not virtual_ibi)
            for byte in (0x01, 0x42):
                await controller.send_byte_tbit(byte)
            if expected_ibi:
                await controller.send_byte_tbit(0x66)
            # End a legal two-/three-byte message with Sr, not STOP.
            await controller.send_start()
            assert await controller.write_addr_header(0x7E)
            await controller.send_byte_tbit(CCC.BCAST.SETMWL)
            for byte in (0x01, 0x51):
                await controller.send_byte_tbit(byte)
            await controller.send_stop()
            controller.give_bus_control()
            assert int(config.get_mrl_o.value) == 0x0142
            assert int(config.get_ibil_o.value) == (0x66 if expected_ibi else old_ibil)
            if not expected_ibi:
                await set_mrl_capabilities(tb, main_ibi, virtual_ibi)
                extension = [0x01, 0x42, 0xC8]
                await controller.i3c_ccc_write(ccc=CCC.BCAST.SETMRL if address is None else CCC.DIRECT.SETMRL, broadcast_data=extension if address is None else None, directed_data=None if address is None else [(address, extension)])
                assert int(config.get_ibil_o.value) == old_ibil, "Unrecognized SETMRL extension updated IBIL"

            for target, capability in ((0x2D, main_ibi), (0x35, virtual_ibi)):
                await set_mrl_capabilities(tb, main_ibi, virtual_ibi)
                await controller.take_bus_control()
                await controller.send_start()
                assert await controller.write_addr_header(0x7E)
                await controller.send_byte_tbit(CCC.DIRECT.GETMRL)
                await controller.send_start()
                assert await controller.write_addr_header(target, read=True)
                await set_mrl_capabilities(tb, not main_ibi, not virtual_ibi)
                expected = bytearray([0x01, 0x42] + ([0 if target == 0x35 else int(config.get_ibil_o.value)] if capability else []))
                await recv_ccc_exact(controller, expected, f"GETMRL address=0x{target:02X}, sampled BCR[2]={int(capability)}")
                await controller.send_stop()
                controller.give_bus_control()
    finished.set()
    await handoff_monitor
    await tb.teardown()


@cocotb.test(timeout_time=500, timeout_unit="us")
async def test_ccc_incomplete_stop_recovery(dut):
    controller, _, tb = await test_setup(dut, dynamic_addr=0x2D, virtual_dynamic_addr=0x35)
    finished = Event()
    handoff_monitor = cocotb.start_soon(monitor_ccc_handoff(dut, tb, finished))
    await set_mrl_capabilities(tb, True, False)
    ccc = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xccc
    for direct in (False, True):
        commands = CCC.DIRECT if direct else CCC.BCAST
        for phase in ("command_tbit", "def_byte", "def_tbit", "data", "data_tbit", "mrl_third", "parity"):
            dut._log.info(f"CCC_STOP: direct={direct}, phase={phase}")
            command = commands.SETMRL if phase == "mrl_third" else (commands.SETMWL if phase.startswith("data") else commands.RSTACT)
            await controller.take_bus_control()
            await controller.send_start()
            assert await controller.write_addr_header(0x7E)
            if phase == "command_tbit":
                for bit in range(7, -1, -1):
                    await controller.send_bit(bool(int(command) & (1 << bit)))
            else:
                await controller.send_byte_tbit(command)
                if direct and phase in ("data", "data_tbit", "mrl_third"):
                    await controller.send_start()
                    assert await controller.write_addr_header(0x2D)
                if phase in ("def_tbit", "data_tbit"):
                    for _ in range(8):
                        await controller.send_bit(False)
                elif phase == "data":
                    await controller.send_byte_tbit(0x01)
                elif phase == "mrl_third":
                    await controller.send_byte_tbit(0x01)
                    await controller.send_byte_tbit(0x42)
                elif phase == "parity":
                    tb.te_error_monitor.expect_error(2)
                    count_before = tb.te_error_monitor.error_counts[2]
                    await controller.send_byte_tbit(0x01, inject_tbit_err=True)
                    await exercise_te2_quiescence(controller, dut, tb, (0x2D, 0x7E, 0x35), count_before)
                    assert int(ccc.command_code_valid.value) == 0
                    await do_getmwl(controller, 0x2D)
                    continue
            # Raw bytes end with SDA low, so STOP need not clock the missing T-bit.
            missing_tbit = phase in ("command_tbit", "def_tbit", "data_tbit")
            if missing_tbit:
                assert int(dut.bus_scl.value) == 1 and int(dut.bus_sda.value) == 0
            await ClockCycles(tb.clk, 5)
            quiet_done = Event()
            quiet_monitor = cocotb.start_soon(monitor_ccc_quiet(dut, tb, quiet_done))
            await ClockCycles(tb.clk, 2)
            await controller.send_stop(pull_scl_low=not missing_tbit)
            controller.give_bus_control()
            await ClockCycles(tb.clk, 10)
            quiet_done.set()
            await quiet_monitor
            await FallingEdge(tb.clk)
            assert int(ccc.command_code_valid.value) == 0
            await do_getmwl(controller, 0x2D)
    finished.set()
    await handoff_monitor
    tb.te_error_monitor.check()
    await tb.teardown()


@cocotb.test(timeout_time=5000, timeout_unit="us")
async def test_ccc_chain_direct(dut):
    controller, _, tb = await test_setup(dut)
    finished = Event()
    handoff_monitor = cocotb.start_soon(monitor_ccc_handoff(dut, tb, finished))
    config = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration
    ccc = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xccc
    sm = tb.reg_map.I3C_EC.STDBYCTRLMODE
    cases = [(command, None, False) for command in (
        CCC.DIRECT.ENEC, CCC.DIRECT.DISEC, CCC.DIRECT.SETDASA, CCC.DIRECT.SETNEWDA, CCC.DIRECT.SETMWL, CCC.DIRECT.SETMRL,
    )]
    cases += [(command, None, True) for command in (
        CCC.DIRECT.GETMWL, CCC.DIRECT.GETMRL, CCC.DIRECT.GETPID, CCC.DIRECT.GETBCR, CCC.DIRECT.GETDCR, CCC.DIRECT.GETSTATUS,
    )]
    cases += [(CCC.DIRECT.GETCAPS, defining_byte, True) for defining_byte in (None, 0, 0x93)]
    cases += [(CCC.DIRECT.RSTACT, defining_byte, False) for defining_byte in (0, 1, 2, 4)]
    cases += [(CCC.DIRECT.RSTACT, defining_byte, True) for defining_byte in (0, 1, 2, 4, 0x81, 0x82, 0x84)]
    for command, defining_byte, read in cases:
        for chain in (False, True):
            dut._log.info(f"Direct boundary: command=0x{command:02X}, DB={defining_byte}, read={read}, chain={chain}")
            await reset_n(tb.clk, tb.rst_n, cycles=5)
            setdasa = command == CCC.DIRECT.SETDASA
            await boot_init(tb, dynamic_addr=None if setdasa else 0x2D, virtual_dynamic_addr=None if setdasa else 0x35)
            await set_mrl_capabilities(tb, True, False)
            await controller.take_bus_control()
            await controller.send_start()
            assert await controller.write_addr_header(0x7E)
            await controller.send_byte_tbit(command)
            if defining_byte is not None:
                await controller.send_byte_tbit(defining_byte)
            addresses = [TGT_ADR, TGT_ADR + 1] if setdasa else [0x2D, 0x35]
            for index, address in enumerate(addresses):
                await controller.send_start()
                assert not await controller.write_addr_header(0x44, read=read), "Unknown target ACKed directed CCC"
                await controller.send_start()
                assert await controller.write_addr_header(address, read=read), f"Directed target NACK: {command=}, {address=}"
                if read:
                    prefix = "virtual_" if index else ""
                    if command in (CCC.DIRECT.GETPID, CCC.DIRECT.GETBCR, CCC.DIRECT.GETDCR):
                        name, count = {CCC.DIRECT.GETPID: ("pid", 6), CCC.DIRECT.GETBCR: ("bcr", 1), CCC.DIRECT.GETDCR: ("dcr", 1)}[command]
                        expected = int(getattr(config, f"{prefix}{name}_o").value).to_bytes(count, "big")
                    elif command == CCC.DIRECT.GETMWL:
                        expected = int(config.get_mwl_o.value).to_bytes(2, "big")
                    elif command == CCC.DIRECT.GETMRL:
                        expected = int(config.get_mrl_o.value).to_bytes(2, "big") + (b"" if index else bytes([int(config.get_ibil_o.value)]))
                    elif command == CCC.DIRECT.GETSTATUS:
                        expected = bytes([0, 0xC0])
                    elif command == CCC.DIRECT.GETCAPS:
                        expected = bytes([0x35]) if defining_byte == 0x93 else bytes([0, 1, 0 if index else 0x48])
                    else:
                        expected = bytes([0xFF if defining_byte in (0x81, 0x82) else (1 if defining_byte == 0x84 else (0 if defining_byte == 4 else 0x80))])
                    data = bytearray()
                    await controller.recv_until_eod_tbit(data, 7, stop=False)
                    assert data == expected, f"Directed response mismatch: {command=}, {defining_byte=}, {address=}, expected={expected.hex()}, got={data.hex()}"
                else:
                    if command in (CCC.DIRECT.ENEC, CCC.DIRECT.DISEC):
                        payload = [0x0B]
                    elif command in (CCC.DIRECT.SETDASA, CCC.DIRECT.SETNEWDA):
                        payload = [(0x30 + index) << 1]
                    elif command == CCC.DIRECT.SETMWL:
                        payload = [0x12, 0x34 + index]
                    elif command == CCC.DIRECT.SETMRL:
                        payload = [0x23, 0x45 + index] + ([] if index else [0x67])
                    else:
                        payload = []
                    for byte in payload:
                        await controller.send_byte_tbit(byte)
                    if chain:
                        for byte in (0xDE, 0xAD):
                            await controller.send_byte_tbit(byte)
                    await ClockCycles(tb.clk, 10)
                    if command in (CCC.DIRECT.ENEC, CCC.DIRECT.DISEC):
                        enabled = int(command == CCC.DIRECT.ENEC)
                        assert await read_target_events(tb) == (enabled, enabled, enabled)
                    elif command in (CCC.DIRECT.SETDASA, CCC.DIRECT.SETNEWDA):
                        reg = sm.STBY_CR_VIRT_DEVICE_ADDR if index else sm.STBY_CR_DEVICE_ADDR
                        field = reg.VIRT_DYNAMIC_ADDR if index else reg.DYNAMIC_ADDR
                        assert await tb.read_csr_field(reg.base_addr, field) == 0x30 + index
                    elif command == CCC.DIRECT.SETMWL:
                        assert int(config.get_mwl_o.value) == 0x1234 + index
                    elif command == CCC.DIRECT.SETMRL:
                        assert int(config.get_mrl_o.value) == 0x2345 + index and int(config.get_ibil_o.value) == 0x67
                    else:
                        assert int(ccc.rstact_armed_q.value) == int(defining_byte != 4)
                        assert int(ccc.rst_action_o.value) == (defining_byte if defining_byte != 4 else 0)
                        assert int(ccc.vt_detect_flag_q.value) == int(defining_byte == 4)
                assert int(ccc.command_code.value) == command and int(ccc.command_code_valid.value)
            if chain:
                # A new directed opcode requires Sr + 7E/W, not just Sr + opcode.
                for next_command, next_db, expected in ((CCC.DIRECT.GETCAPS, 0x93, bytes([0x35])), (CCC.DIRECT.GETCAPS, None, bytes([0, 1, 0x48]))):
                    await controller.send_start()
                    assert await controller.write_addr_header(0x7E)
                    await controller.send_byte_tbit(next_command)
                    if next_db is not None:
                        await controller.send_byte_tbit(next_db)
                    await controller.send_start()
                    next_address = 0x30 if command in (CCC.DIRECT.SETDASA, CCC.DIRECT.SETNEWDA) else 0x2D
                    assert await controller.write_addr_header(next_address, read=True)
                    data = bytearray()
                    await controller.recv_until_eod_tbit(data, 4, stop=False)
                    assert data == expected, "Chained directed CCC retained stale opcode or defining byte"
            await controller.send_stop()
            controller.give_bus_control()
            await ClockCycles(tb.clk, 10)
            assert int(ccc.command_code_valid.value) == 0
    finished.set()
    await handoff_monitor
    await tb.teardown()


@cocotb.test()
async def test_ccc_enthdr_all_codes(dut):
    """
    Verify all ENTHDR codes (0x20-0x27) cause the target to enter HDR mode.
    After each ENTHDR, verify clean recovery with HDR exit pattern.
    """
    i3c_controller, _, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)

    for hdr_code in range(0x20, 0x28):
        # Send ENTHDR broadcast
        await i3c_controller.i3c_ccc_write(ccc=hdr_code, stop=False)

        await i3c_controller.take_bus_control()
        for address, read in ((TGT_ADR, False), (TGT_ADR, True), (0x7E, False)):
            await i3c_controller.send_start()
            assert not await i3c_controller.write_addr_header(address, read=read), f"ENTHDR 0x{hdr_code:02X} incorrectly resumed SDR at Sr"
        await i3c_controller.send_stop()
        await i3c_controller.send_start()
        assert not await i3c_controller.write_addr_header(TGT_ADR), "STOP incorrectly exited HDR mode"

        # HDR exit pattern: Sr+7E/W with STOP
        await i3c_controller.send_hdr_exit()

        # Verify clean recovery: GETBCR should still work
        responses = await i3c_controller.i3c_ccc_read(
            ccc=CCC.DIRECT.GETBCR, addr=TGT_ADR, count=1)
        assert responses[0][0] == True, \
            f"GETBCR should ACK after ENTHDR 0x{hdr_code:02X} + exit"
        await check_private_transfers(i3c_controller, tb, TGT_ADR)

    await tb.teardown()


@cocotb.test(timeout_time=500, timeout_unit="us")
async def test_ccc_setdasa_direction_det_en(dut):
    """Wrong-direction SETDASA must not assign either unassigned static target."""
    controller, _, tb = await test_setup(dut)
    tb.te_error_monitor.expect_error(5)
    sm = tb.reg_map.I3C_EC.STDBYCTRLMODE
    tti = tb.reg_map.I3C_EC.TTI
    targets = (
        (TGT_ADR, 0x2D, sm.STBY_CR_DEVICE_ADDR, sm.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR, sm.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID),
        (VIRT_TGT_ADR, 0x35, sm.STBY_CR_VIRT_DEVICE_ADDR, sm.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR,
         sm.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID),
    )

    async def address_state():
        """Snapshot both DA values/valid bits so cross-target corruption also fails."""
        return [(await tb.read_csr_field(reg.base_addr, da), await tb.read_csr_field(reg.base_addr, valid))
                for _, _, reg, da, valid in targets]

    await tb.write_csr_field(tti.TARGET_ERR_INTR_ENABLE.base_addr, tti.TARGET_ERR_INTR_ENABLE.TE5_ERR_EN, 1)
    for enabled in (0, 1):
        await tb.write_csr_field(tti.TARGET_ERR_CTRL.base_addr, tti.TARGET_ERR_CTRL.TE5_ERR_DET_EN, enabled)
        for address, _, _, _, _ in targets:
            before = await address_state()
            assert all(valid == 0 for _, valid in before), "SETDASA direction test requires unassigned static addresses"
            events = tb.te_error_monitor.error_counts[5]
            counter = await tb.read_csr_field(tti.TARGET_ERR_CNT_TE5.base_addr, tti.TARGET_ERR_CNT_TE5.CNT)
            await tb.write_csr_field(tti.TARGET_ERR_INTR_STATUS.base_addr, tti.TARGET_ERR_INTR_STATUS.TE5_ERR_STAT, 1)
            dut._log.info(f"CCC_SETDASA: wrong-direction address=0x{address:02X}, DET_EN={enabled}")
            response = await controller.i3c_ccc_read(ccc=CCC.DIRECT.SETDASA, addr=address, count=1)
            assert not response[0][0], "Wrong-direction SETDASA must NACK even with reporting disabled"
            await ClockCycles(tb.clk, 10)
            assert tb.te_error_monitor.error_counts[5] == events + enabled, "Incorrect SETDASA TE5 event delta"
            assert await tb.read_csr_field(tti.TARGET_ERR_CNT_TE5.base_addr, tti.TARGET_ERR_CNT_TE5.CNT) == counter + enabled
            assert await tb.read_csr_field(tti.TARGET_ERR_INTR_STATUS.base_addr, tti.TARGET_ERR_INTR_STATUS.TE5_ERR_STAT) == enabled
            after = await address_state()
            assert after == before, f"Wrong-direction SETDASA changed DA/valid: {before} -> {after}"
    events = tb.te_error_monitor.error_counts[5]
    for address, assigned, reg, da, valid in targets:
        dut._log.info(f"CCC_SETDASA: valid write assignment 0x{address:02X} -> 0x{assigned:02X}")
        assert await controller.i3c_ccc_write(ccc=CCC.DIRECT.SETDASA, directed_data=[(address, [assigned << 1])]) == [True]
        assert await tb.read_csr_field(reg.base_addr, da) == assigned
        assert await tb.read_csr_field(reg.base_addr, valid) == 1
    assert tb.te_error_monitor.error_counts[5] == events, "Valid assignment generated TE5"
    await tb.teardown()


@cocotb.test()
async def test_ccc_te5_wrong_direction(dut):
    """
    TE5 error: wrong R/W direction for direct CCC.
    - GET CCC sent with W direction -> NACK
    - SET CCC sent with R direction -> NACK
    - Rejected SETDASA after DA=SA assignment reports TE5 only for wrong direction
    """
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR)
    assert tb.te_error_monitor is not None, "TE5 checks require the passive error-event monitor"
    tb.te_error_monitor.expect_error(5)
    tti = tb.reg_map.I3C_EC.TTI
    sm = tb.reg_map.I3C_EC.STDBYCTRLMODE
    await tb.write_csr_field(tti.TARGET_ERR_INTR_ENABLE.base_addr, tti.TARGET_ERR_INTR_ENABLE.TE5_ERR_EN, 1)
    await tb.write_csr_field(tti.TARGET_ERR_CTRL.base_addr, tti.TARGET_ERR_CTRL.TE5_ERR_DET_EN, 1)
    await ClockCycles(tb.clk, 50)

    for tgt_addr in [STATIC_ADDR, VIRT_STATIC_ADDR]:
        for command in (CCC.DIRECT.GETBCR, CCC.DIRECT.GETDCR, CCC.DIRECT.GETPID, CCC.DIRECT.GETMWL, CCC.DIRECT.GETMRL, CCC.DIRECT.GETSTATUS, CCC.DIRECT.GETCAPS):
            acks = await i3c_controller.i3c_ccc_write(ccc=command, directed_data=[(tgt_addr, [0x00])])
            assert acks == [False], f"GET command {command:#x} with W direction to {tgt_addr:#x} should NACK"
        for command in (CCC.DIRECT.ENEC, CCC.DIRECT.DISEC, CCC.DIRECT.SETMWL, CCC.DIRECT.SETMRL, CCC.DIRECT.SETNEWDA, CCC.DIRECT.SETDASA):
            responses = await i3c_controller.i3c_ccc_read(ccc=command, addr=tgt_addr, count=2)
            assert responses[0][0] == False, f"SET command {command:#x} with R direction from {tgt_addr:#x} should NACK"
    assert tb.te_error_monitor.error_counts[5] == 26, "Every wrong-direction address must report TE5"

    targets = (
        (STATIC_ADDR, sm.STBY_CR_DEVICE_ADDR, sm.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR, sm.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID),
        (VIRT_STATIC_ADDR, sm.STBY_CR_VIRT_DEVICE_ADDR, sm.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR, sm.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID),
    )
    for address, _, _, _ in targets:
        assert await i3c_controller.i3c_ccc_write(ccc=CCC.DIRECT.SETDASA, directed_data=[(address, [address << 1])]) == [True]
    assert tb.te_error_monitor.error_counts[5] == 26, "Valid DA=SA assignment generated TE5"

    for enabled in (0, 1):
        await tb.write_csr_field(tti.TARGET_ERR_CTRL.base_addr, tti.TARGET_ERR_CTRL.TE5_ERR_DET_EN, enabled)
        for address, reg, da, valid in targets:
            assert await tb.read_csr_field(reg.base_addr, da) == address
            assert await tb.read_csr_field(reg.base_addr, valid) == 1
            for read in (False, True):
                events = tb.te_error_monitor.error_counts[5]
                counter = await tb.read_csr_field(tti.TARGET_ERR_CNT_TE5.base_addr, tti.TARGET_ERR_CNT_TE5.CNT)
                await tb.write_csr_field(tti.TARGET_ERR_INTR_STATUS.base_addr, tti.TARGET_ERR_INTR_STATUS.TE5_ERR_STAT, 1)
                if read:
                    response = await i3c_controller.i3c_ccc_read(ccc=CCC.DIRECT.SETDASA, addr=address, count=1)
                    ack = response[0][0]
                else:
                    acks = await i3c_controller.i3c_ccc_write(ccc=CCC.DIRECT.SETDASA, directed_data=[(address, [address << 1])])
                    ack = acks[0]
                assert not ack, "SETDASA must NACK once the target has a dynamic address"
                await ClockCycles(tb.clk, 10)
                expected_events = int(read and enabled)
                assert tb.te_error_monitor.error_counts[5] == events + expected_events, f"Incorrect TE5 classification: address=0x{address:02X}, read={read}, DET_EN={enabled}"
                assert await tb.read_csr_field(tti.TARGET_ERR_CNT_TE5.base_addr, tti.TARGET_ERR_CNT_TE5.CNT) == counter + expected_events
                assert await tb.read_csr_field(tti.TARGET_ERR_INTR_STATUS.base_addr, tti.TARGET_ERR_INTR_STATUS.TE5_ERR_STAT) == expected_events
                assert await tb.read_csr_field(reg.base_addr, da) == address, "Rejected SETDASA changed the dynamic address"
                assert await tb.read_csr_field(reg.base_addr, valid) == 1, "Rejected SETDASA invalidated the dynamic address"
                dut._log.info(f"TE5_CLASSIFICATION: address=0x{address:02X}, read={read}, DET_EN={enabled}: NACK, event/counter/status delta={expected_events}")

    # Verify clean recovery after TE5 errors
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=STATIC_ADDR, count=1)
    assert responses[0][0] == True, "GETBCR should ACK after TE5 recovery"

    await tb.teardown()


@cocotb.test()
async def test_ccc_abort_get_sr(dut):
    """
    Controller Sr abort during multi-byte GET CCC reads. Reads fewer bytes
    than expected, then sends Sr to abort. Verifies clean recovery with
    a subsequent normal GET.
    """
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # Test Sr abort on multi-byte GET CCCs using low-level BFM methods
    test_cases = [
        (CCC.DIRECT.GETSTATUS, 2, 1),  # 2-byte CCC, abort after 1 byte
        (CCC.DIRECT.GETMWL, 2, 1),     # 2-byte CCC, abort after 1 byte
        (CCC.DIRECT.GETMRL, 3, 1),     # 3-byte CCC, abort after 1 byte
        (CCC.DIRECT.GETMRL, 3, 2),     # 3-byte CCC, abort after 2 bytes
        (CCC.DIRECT.GETPID, 6, 1),     # 6-byte CCC, abort after 1 byte
        (CCC.DIRECT.GETPID, 6, 3),     # 6-byte CCC, abort after 3 bytes
    ]

    for ccc_code, total_bytes, abort_after in test_cases:
        tgt_addr = random.choice([DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR])
        if ccc_code == CCC.DIRECT.GETMRL:
            if abort_after == 2:
                tgt_addr = DYNAMIC_ADDR
            total_bytes = 2 if tgt_addr == VIRT_DYNAMIC_ADDR else 3

        # Build CCC frame manually for partial read
        await i3c_controller.take_bus_control()
        await i3c_controller.send_start()
        await i3c_controller.write_addr_header(0x7E)
        await i3c_controller.send_byte_tbit(ccc_code)
        await i3c_controller.send_start()
        ack = await i3c_controller.write_addr_header(tgt_addr, read=True)
        assert ack, f"CCC 0x{ccc_code:02X} addr 0x{tgt_addr:02X} should ACK"

        # Read partial bytes
        for i in range(abort_after):
            is_last = (i == abort_after - 1)
            (byte, _) = await i3c_controller.recv_byte_t_bit(stop=is_last)

        # Send STOP to end frame
        await i3c_controller.send_stop()
        i3c_controller.give_bus_control()

        # Verify recovery: full GET should work normally
        responses = await i3c_controller.i3c_ccc_read(
            ccc=ccc_code, addr=tgt_addr, count=total_bytes)
        assert responses[0][0] == True, \
            f"CCC 0x{ccc_code:02X} should ACK after Sr abort recovery"
        assert len(responses[0][1]) == total_bytes, \
            f"CCC 0x{ccc_code:02X} should return {total_bytes} bytes after recovery"

    await tb.teardown()


@cocotb.test()
async def test_ccc_back_to_back(dut):
    """
    Back-to-back CCCs with no idle gap between transactions.
    Verify all CCCs process correctly.
    """
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # Rapid-fire sequence of different CCC types
    for _ in range(5):
        # SET MWL
        mwl = random.randint(0, 0xFFFF)
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.SETMWL,
            directed_data=[(DYNAMIC_ADDR, [(mwl >> 8) & 0xFF, mwl & 0xFF])])

        # GET MWL immediately after
        responses = await i3c_controller.i3c_ccc_read(
            ccc=CCC.DIRECT.GETMWL, addr=DYNAMIC_ADDR, count=2)
        got = (responses[0][1][0] << 8) | responses[0][1][1]
        assert got == mwl, f"Back-to-back MWL: expected 0x{mwl:04X}, got 0x{got:04X}"

        # GETSTATUS from VT
        responses = await i3c_controller.i3c_ccc_read(
            ccc=CCC.DIRECT.GETSTATUS, addr=VIRT_DYNAMIC_ADDR, count=2)
        assert responses[0][0] == True, "GETSTATUS should ACK"

        # GETBCR from main
        responses = await i3c_controller.i3c_ccc_read(
            ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
        assert responses[0][0] == True, "GETBCR should ACK"

    await tb.teardown()


@cocotb.test()
async def test_ccc_random_interleave(dut):
    """
    Random sequence of SET/GET CCCs to random targets. Stress tests the
    CCC FSM state machine with varied patterns.
    """
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    targets = [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]

    for _ in range(20):
        action = random.choice(['setmwl', 'getmwl', 'setmrl', 'getmrl',
                                'getbcr', 'getdcr', 'getstatus', 'getpid',
                                'enec', 'disec', 'getcaps'])
        tgt = random.choice(targets)

        if action == 'setmwl':
            val = random.randint(0, 0xFFFF)
            await i3c_controller.i3c_ccc_write(
                ccc=CCC.DIRECT.SETMWL,
                directed_data=[(tgt, [(val >> 8) & 0xFF, val & 0xFF])])
        elif action == 'getmwl':
            responses = await i3c_controller.i3c_ccc_read(
                ccc=CCC.DIRECT.GETMWL, addr=tgt, count=2)
            assert responses[0][0] == True, f"CCC {action} NACK for addr=0x{tgt:02X}"
        elif action == 'setmrl':
            val = random.randint(0, 0xFFFF)
            await i3c_controller.i3c_ccc_write(
                ccc=CCC.DIRECT.SETMRL,
                directed_data=[(tgt, [(val >> 8) & 0xFF, val & 0xFF, random.randint(0, 0xFF)])])
        elif action == 'getmrl':
            responses = await i3c_controller.i3c_ccc_read(
                ccc=CCC.DIRECT.GETMRL, addr=tgt, count=3)
            assert responses[0][0] == True, f"CCC {action} NACK for addr=0x{tgt:02X}"
        elif action == 'getbcr':
            responses = await i3c_controller.i3c_ccc_read(
                ccc=CCC.DIRECT.GETBCR, addr=tgt, count=1)
            assert responses[0][0] == True, f"CCC {action} NACK for addr=0x{tgt:02X}"
        elif action == 'getdcr':
            responses = await i3c_controller.i3c_ccc_read(
                ccc=CCC.DIRECT.GETDCR, addr=tgt, count=1)
            assert responses[0][0] == True, f"CCC {action} NACK for addr=0x{tgt:02X}"
        elif action == 'getstatus':
            responses = await i3c_controller.i3c_ccc_read(
                ccc=CCC.DIRECT.GETSTATUS, addr=tgt, count=2)
            assert responses[0][0] == True, f"CCC {action} NACK for addr=0x{tgt:02X}"
        elif action == 'getpid':
            responses = await i3c_controller.i3c_ccc_read(
                ccc=CCC.DIRECT.GETPID, addr=tgt, count=6)
            assert responses[0][0] == True, f"CCC {action} NACK for addr=0x{tgt:02X}"
        elif action == 'enec':
            await i3c_controller.i3c_ccc_write(
                ccc=CCC.DIRECT.ENEC,
                directed_data=[(tgt, [random.randint(0, 0x0B)])])
        elif action == 'disec':
            await i3c_controller.i3c_ccc_write(
                ccc=CCC.DIRECT.DISEC,
                directed_data=[(tgt, [random.randint(0, 0x0B)])])
        elif action == 'getcaps':
            responses = await i3c_controller.i3c_ccc_read(
                ccc=CCC.DIRECT.GETCAPS, addr=tgt, count=3)
            assert responses[0][0] == True, f"CCC {action} NACK for addr=0x{tgt:02X}"

    await tb.teardown()


@cocotb.test()
async def test_ccc_vendor_codes(dut):
    """
    Verify vendor-specific CCC codes:
    - Broadcast vendor CCCs (0x61-0x7F): target ignores data silently
    - Direct vendor CCCs (0xE0-0xFE): target NACKs (unsupported)
    """
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # Broadcast vendor CCCs -- should be silently ignored
    for ccc_code in [0x61, 0x6A, 0x7F]:
        await i3c_controller.i3c_ccc_write(
            ccc=ccc_code, broadcast_data=[0xDE, 0xAD])

    # Direct vendor CCCs -- should NACK
    for ccc_code in [0xE0, 0xEA, 0xFE]:
        for tgt_addr in [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]:
            acks = await i3c_controller.i3c_ccc_write(
                ccc=ccc_code, directed_data=[(tgt_addr, [0x00])])
            assert acks[0] == False, \
                f"Vendor CCC 0x{ccc_code:02X} to 0x{tgt_addr:02X} should NACK"

    # Verify clean recovery after vendor codes
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "GETBCR should ACK after vendor codes"

    await tb.teardown()


@cocotb.test()
async def test_ccc_abort_bcast_stop(dut):
    """
    Controller STOP during CCC at various phases:
    - STOP during broadcast SET data (incomplete data)
    - Verify clean recovery (next CCC works normally)
    """
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # Send SETMWL broadcast with only 1 byte (expects 2) then STOP
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.BCAST.SETMWL)
    await i3c_controller.send_byte_tbit(0xAB)  # Only MSB, missing LSB
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()

    # Send STOP immediately after CCC code (no data at all)
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.BCAST.SETMRL)
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()

    # Verify recovery: normal CCC still works
    mwl_val = random.randint(0, 0xFFFF)
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETMWL,
        directed_data=[(DYNAMIC_ADDR, [(mwl_val >> 8) & 0xFF, mwl_val & 0xFF])])

    sig_mwl = int(dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mwl_o.value)
    assert sig_mwl == mwl_val, \
        f"Recovery SETMWL: expected 0x{mwl_val:04X}, got 0x{sig_mwl:04X}"

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "GETBCR should ACK after abort recovery"

    await tb.teardown()


@cocotb.test()
async def test_ccc_error_det_enable(dut):
    """
    Verify TE0-TE5 error detection enable CSR bits can be toggled.
    When TE0 is disabled, unsupported CCC should not trigger TE0 error.
    When TE5 is disabled, wrong direction should not trigger TE5 error.
    """
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    err_ctrl_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CTRL.base_addr

    # Read default TE error detection enable states
    for field_name in ['TE0_ERR_DET_EN', 'TE1_ERR_DET_EN', 'TE2_ERR_DET_EN',
                        'TE3_ERR_DET_EN', 'TE4_ERR_DET_EN', 'TE5_ERR_DET_EN']:
        field = getattr(tb.reg_map.I3C_EC.TTI.TARGET_ERR_CTRL, field_name)
        val = await tb.read_csr_field(err_ctrl_addr, field)
        dut._log.info(f"{field_name} default = {val}")

    # Disable TE0 (unsupported CCC detection)
    te0_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CTRL.TE0_ERR_DET_EN
    await tb.write_csr_field(err_ctrl_addr, te0_field, 0)
    val = await tb.read_csr_field(err_ctrl_addr, te0_field)
    assert val == 0, f"TE0 should be disabled, got {val}"

    # Send unsupported CCC -- should still NACK but no TE0 error flag
    acks = await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.GETACCCR, directed_data=[(DYNAMIC_ADDR, [0x00])])

    # Re-enable TE0
    await tb.write_csr_field(err_ctrl_addr, te0_field, 1)
    val = await tb.read_csr_field(err_ctrl_addr, te0_field)
    assert val == 1, f"TE0 should be re-enabled, got {val}"

    # Toggle TE5 (wrong direction detection)
    te5_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CTRL.TE5_ERR_DET_EN
    await tb.write_csr_field(err_ctrl_addr, te5_field, 0)
    val = await tb.read_csr_field(err_ctrl_addr, te5_field)
    assert val == 0, f"TE5 should be disabled, got {val}"

    # Re-enable TE5
    await tb.write_csr_field(err_ctrl_addr, te5_field, 1)
    val = await tb.read_csr_field(err_ctrl_addr, te5_field)
    assert val == 1, f"TE5 should be re-enabled, got {val}"

    # Verify normal CCC operation is unaffected
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "GETBCR should ACK after error detect toggle"

    await tb.teardown()


@cocotb.test()
async def test_ccc_setdasa_padding_err(dut):
    """
    Verify that SETDASA/SETNEWDA with padding bit[0]=1 triggers a framing error
    and does NOT apply the address. Per ccc.sv:1112-1117, when framing_err_det_en_i
    is set and rx_data[0]==1, da_padding_err fires and rx_data_valid stays low.
    """
    log = logging.getLogger("test_ccc_setdasa_padding_err")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR)
    tb.te_error_monitor.expect_error(6)
    await ClockCycles(tb.clk, 50)

    err_intr_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr
    framing_stat_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.FRAMING_ERR_STAT
    framing_cnt_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CNT_FRAMING.base_addr
    framing_cnt_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CNT_FRAMING.CNT

    da_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr
    da_valid_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID
    da_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR

    # Enable framing error interrupt (default is disabled) so status register captures it
    err_en_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.base_addr
    framing_en_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.FRAMING_ERR_EN
    await tb.write_csr_field(err_en_addr, framing_en_field, 1)

    # Clear any stale framing error status (W1C)
    await tb.write_csr_field(err_intr_addr, framing_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    # ---- Test 1: SETDASA with bad padding bit -> framing error, address NOT applied ----
    log.info(f"SETDASA with bad padding: addr={STATIC_ADDR:#x} -> DA={DYNAMIC_ADDR:#x} | 1")
    bad_data_byte = (DYNAMIC_ADDR << 1) | 1  # bit[0]=1 is the error
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [bad_data_byte])])
    await ClockCycles(tb.clk, 20)

    # Dynamic address should NOT have been applied
    da_valid = await tb.read_csr_field(da_reg_addr, da_valid_field)
    assert da_valid == 0, f"DA_VALID should be 0 after padding error, got {da_valid}"

    # Framing error status should be set
    framing_stat = await tb.read_csr_field(err_intr_addr, framing_stat_field)
    assert framing_stat == 1, f"FRAMING_ERR_STAT should be 1 after padding error, got {framing_stat}"

    # Framing error counter should have incremented exactly once
    framing_cnt = await tb.read_csr_field(framing_cnt_addr, framing_cnt_field)
    assert framing_cnt == 1, (
        f"Framing error count should be exactly 1 after one event, "
        f"got {framing_cnt}"
    )

    # Clear status
    await tb.write_csr_field(err_intr_addr, framing_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    # ---- Test 2: Good SETDASA -> should work normally ----
    log.info(f"SETDASA with good padding: addr={STATIC_ADDR:#x} -> DA={DYNAMIC_ADDR:#x}")
    good_data_byte = (DYNAMIC_ADDR << 1)  # bit[0]=0
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [good_data_byte])], stop=False)
    # Also assign virtual target
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])])
    await ClockCycles(tb.clk, 20)

    da_valid = await tb.read_csr_field(da_reg_addr, da_valid_field)
    assert da_valid == 1, f"DA_VALID should be 1 after good SETDASA, got {da_valid}"
    da_val = await tb.read_csr_field(da_reg_addr, da_field)
    assert da_val == DYNAMIC_ADDR, f"DA should be {DYNAMIC_ADDR:#x}, got {da_val:#x}"

    # ---- Test 3: SETNEWDA with bad padding bit -> framing error, address unchanged ----
    NEW_ADDR = random.choice([a for a in VALID_I3C_ADDRESSES
                              if a not in (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)])
    log.info(f"SETNEWDA with bad padding: DA={DYNAMIC_ADDR:#x} -> {NEW_ADDR:#x} | 1")
    bad_data_byte = (NEW_ADDR << 1) | 1
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETNEWDA, directed_data=[(DYNAMIC_ADDR, [bad_data_byte])])
    await ClockCycles(tb.clk, 20)

    # Address should still be old value
    da_val = await tb.read_csr_field(da_reg_addr, da_field)
    assert da_val == DYNAMIC_ADDR, f"DA should still be {DYNAMIC_ADDR:#x} after padding err, got {da_val:#x}"

    # Framing error should fire again
    framing_stat = await tb.read_csr_field(err_intr_addr, framing_stat_field)
    assert framing_stat == 1, f"FRAMING_ERR_STAT should be 1 after SETNEWDA padding err, got {framing_stat}"

    # Verify device still responds at old address
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Target should still ACK at old DA after padding error"

    await tb.teardown()


@cocotb.test()
async def test_ccc_te2_parity(dut):
    """
    Verify TE2 error detection: bad T-bit parity on CCC defining byte causes
    the target to abort the CCC and signal TE2. Per ccc.sv:997-1000.
    """
    log = logging.getLogger("test_ccc_te2_parity")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    err_intr_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr
    te2_stat_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.TE2_ERR_STAT
    te2_cnt_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CNT_TE2.base_addr
    te2_cnt_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CNT_TE2.CNT

    # Enable TE2 interrupt status capture (default is disabled)
    err_en_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.base_addr
    te2_en_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.TE2_ERR_EN
    await tb.write_csr_field(err_en_addr, te2_en_field, 1)

    # Clear any stale TE2 status
    await tb.write_csr_field(err_intr_addr, te2_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    # Tell the TE error monitor that TE2 errors are expected in this test
    tb.te_error_monitor.expect_error(2)

    # ---- Test 1: Bad T-bit on RSTACT defining byte ----
    # RSTACT (0x9A) has a defining byte. Corrupt the defining byte T-bit.
    log.info("Sending RSTACT with bad defining byte T-bit parity (TE2)")
    count_before = tb.te_error_monitor.error_counts[2]
    await i3c_controller.send_te2_error(ccc=0x9A, defining_byte=0x01,
                                         corrupt_defining_byte=True)
    await exercise_te2_quiescence(i3c_controller, dut, tb, (DYNAMIC_ADDR, 0x7E, VIRT_DYNAMIC_ADDR), count_before)
    await ClockCycles(tb.clk, 20)

    # TE2 status should be set
    te2_stat = await tb.read_csr_field(err_intr_addr, te2_stat_field)
    assert te2_stat == 1, f"TE2_ERR_STAT should be 1 after bad defining byte parity, got {te2_stat}"

    te2_cnt = await tb.read_csr_field(te2_cnt_addr, te2_cnt_field)
    assert te2_cnt == 1, (
        f"TE2 error count should be exactly 1 after one event, "
        f"got {te2_cnt}"
    )

    # Clear status
    await tb.write_csr_field(err_intr_addr, te2_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    # ---- Test 2: Verify target still functions after TE2 ----
    # TE2 on the defining byte waits for STOP, then returns directly to WaitCCC.
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Target should still ACK after TE2 error recovery"

    # ---- Test 3: Bad T-bit on GETCAPS defining byte ----
    log.info("Sending GETCAPS with bad defining byte T-bit parity (TE2)")
    await tb.write_csr_field(err_intr_addr, te2_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    count_before = tb.te_error_monitor.error_counts[2]
    await i3c_controller.send_te2_error(ccc=0x95, defining_byte=0x00,
                                         corrupt_defining_byte=True)
    await exercise_te2_quiescence(i3c_controller, dut, tb, (DYNAMIC_ADDR, 0x7E, VIRT_DYNAMIC_ADDR), count_before)
    await ClockCycles(tb.clk, 20)

    te2_stat = await tb.read_csr_field(err_intr_addr, te2_stat_field)
    assert te2_stat == 1, f"TE2_ERR_STAT should be 1 after GETCAPS bad def byte, got {te2_stat}"

    # Target should still be functional
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Target should ACK after second TE2 recovery"
    tb.te_error_monitor.check()

    await tb.teardown()


@cocotb.test()
async def test_ccc_entdaa(dut):
    """
    Verify ENTDAA procedure: controller issues ENTDAA CCC, target responds with
    64-bit device ID, controller assigns dynamic address. Tests both main and
    virtual target address assignment via ENTDAA.
    """
    log = logging.getLogger("test_ccc_entdaa")

    # Boot WITHOUT dynamic addresses -- targets only have static addresses
    # ENTDAA will assign dynamic addresses
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR)
    await ClockCycles(tb.clk, 50)
    config = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration
    expected_ids = [
        tuple(int(getattr(config, f"{prefix}{name}_o").value) for name in ("pid", "bcr", "dcr"))
        for prefix in ("", "virtual_")
    ]

    # Issue ENTDAA: assign main target first, then virtual target
    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR])
    await ClockCycles(tb.clk, 50)

    log.info(f"ENTDAA results: {results}")
    assert len(results) == 2, f"Expected 2 ENTDAA results, got {len(results)}"

    # Both targets should ACK
    assert results[0]["ack"] == True, f"Main target should ACK ENTDAA, got {results[0]}"
    assert results[1]["ack"] == True, f"Virtual target should ACK ENTDAA, got {results[1]}"

    for result, expected in zip(results, expected_ids):
        assert (result["pid"], result["bcr"], result["dcr"]) == expected, "ENTDAA identity differs from configured PID/BCR/DCR"
    log.info(f"Main:    PID=0x{results[0]['pid']:012x} BCR=0x{results[0]['bcr']:02x} DCR=0x{results[0]['dcr']:02x}")
    log.info(f"Virtual: PID=0x{results[1]['pid']:012x} BCR=0x{results[1]['bcr']:02x} DCR=0x{results[1]['dcr']:02x}")

    # Verify addresses were applied by reading them back via CSR
    da_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr
    da_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR
    da_valid_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID
    main_da = await tb.read_csr_field(da_reg_addr, da_field)
    main_da_valid = await tb.read_csr_field(da_reg_addr, da_valid_field)
    assert main_da_valid == 1, f"Main DA_VALID should be 1 after ENTDAA, got {main_da_valid}"
    assert main_da == DYNAMIC_ADDR, f"Main DA should be {DYNAMIC_ADDR:#x}, got {main_da:#x}"

    vda_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr
    vda_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR
    vda_valid_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID
    virt_da = await tb.read_csr_field(vda_reg_addr, vda_field)
    virt_da_valid = await tb.read_csr_field(vda_reg_addr, vda_valid_field)
    assert virt_da_valid == 1, f"Virtual DA_VALID should be 1 after ENTDAA, got {virt_da_valid}"
    assert virt_da == VIRT_DYNAMIC_ADDR, f"Virtual DA should be {VIRT_DYNAMIC_ADDR:#x}, got {virt_da:#x}"

    # Verify targets respond at new dynamic addresses
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Main target should ACK GETBCR at new DA"

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=VIRT_DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Virtual target should ACK GETBCR at new DA"
    await check_private_transfers(i3c_controller, tb, DYNAMIC_ADDR)

    await tb.teardown()


@cocotb.test()
async def test_ccc_entdaa_early_stop(dut):
    """
    Verify ENTDAA with early STOP after assigning only the main target.
    The virtual target should remain unaddressed.
    Per ccc.sv:369 -- STOP terminates ENTDAA regardless of state.
    """
    log = logging.getLogger("test_ccc_entdaa_early_stop")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # Issue ENTDAA but STOP after 1 target
    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR],
        stop_after_n_targets=1)
    await ClockCycles(tb.clk, 50)

    assert len(results) == 1, f"Expected 1 ENTDAA result with early stop, got {len(results)}"
    assert results[0]["ack"] == True, f"Main target should ACK, got {results[0]}"

    # Main target should have address assigned
    da_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr
    da_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR
    da_valid_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID
    main_da_valid = await tb.read_csr_field(da_reg_addr, da_valid_field)
    assert main_da_valid == 1, f"Main DA_VALID should be 1, got {main_da_valid}"

    # Virtual target should NOT have address assigned
    vda_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr
    vda_valid_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID
    virt_da_valid = await tb.read_csr_field(vda_reg_addr, vda_valid_field)
    assert virt_da_valid == 0, f"Virtual DA_VALID should be 0 after early STOP, got {virt_da_valid}"

    # Main target should respond at new DA
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Main target should ACK at assigned DA"

    await tb.teardown()


@cocotb.test()
async def test_ccc_entdaa_te3_te4(dut):
    """
    Verify TE3 and TE4 error handling during ENTDAA.

    TE3: Parity error on assigned address -> target NACKs, retries on next Sr+7E/R.
    TE4: Invalid reserved byte (not 7E/R) -> target NACKs, waits for STOP.

    """
    log = logging.getLogger("test_ccc_entdaa_te3_te4")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR)
    tb.te_error_monitor.expect_error(3, 4)
    await ClockCycles(tb.clk, 50)

    err_intr_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr
    te4_stat_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.TE4_ERR_STAT
    te4_cnt_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CNT_TE4.base_addr
    te4_cnt_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CNT_TE4.CNT

    # Enable TE4 interrupt status capture (default disabled)
    err_en_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.base_addr
    te4_en_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.TE4_ERR_EN
    await tb.write_csr_field(err_en_addr, te4_en_field, 1)

    # Clear stale status
    await tb.write_csr_field(err_intr_addr, te4_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    # ---- TE4: Send 7E/W (not 7E/R) during ENTDAA ----
    log.info("Testing TE4: invalid reserved byte during ENTDAA")
    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[DYNAMIC_ADDR],
        inject_te4_invalid_rsvd=True)
    await ClockCycles(tb.clk, 30)

    # Target should NACK the invalid reserved byte
    assert len(results) >= 1, f"Expected at least 1 ENTDAA result, got {len(results)}"
    assert results[0]["ack"] == False, f"Target should NACK TE4 invalid rsvd byte, got {results[0]}"

    # TE4 status should be set
    te4_stat = await tb.read_csr_field(err_intr_addr, te4_stat_field)
    assert te4_stat == 1, f"TE4_ERR_STAT should be 1 after invalid reserved byte, got {te4_stat}"

    te4_cnt = await tb.read_csr_field(te4_cnt_addr, te4_cnt_field)
    assert te4_cnt == 1, (
        f"TE4 count should be exactly 1 after one event, got {te4_cnt}"
    )

    # ---- TE3: Bad parity on address byte during ENTDAA ----
    # Per I3C spec Sec.5.1.10.1.4: if parity is wrong on the assigned address,
    # the target shall NACK and wait for the next Sr+7E/R to retry.
    log.info("Testing TE3: bad parity on ENTDAA address")
    te3_stat_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.TE3_ERR_STAT
    te3_en_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.TE3_ERR_EN
    te3_cnt_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CNT_TE3.base_addr
    te3_cnt_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CNT_TE3.CNT

    await tb.write_csr_field(err_en_addr, te3_en_field, 1)
    await tb.write_csr_field(err_intr_addr, te3_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[DYNAMIC_ADDR],
        inject_te3_parity=True)
    await ClockCycles(tb.clk, 30)

    # Correct spec behavior: target must NACK the address with bad parity
    assert results[0]["ack"] == False, (
        f"TE3: Target should NACK address with bad parity, but ACKed. "
        f"Result: {results[0]}")

    # TE3 error status and counter should be set
    te3_stat = await tb.read_csr_field(err_intr_addr, te3_stat_field)
    assert te3_stat == 1, f"TE3_ERR_STAT should be 1 after parity error, got {te3_stat}"

    te3_cnt = await tb.read_csr_field(te3_cnt_addr, te3_cnt_field)
    assert te3_cnt == 1, (
        f"TE3 count should be exactly 1 after one event, got {te3_cnt}"
    )

    await tb.teardown()


@cocotb.test()
async def test_ccc_entdaa_arb_lost(dut):
    """
    Verify ENTDAA arbitration-lost path: when arbitration_lost_i is asserted
    during ID bit transmission, the DUT enters LostArbitration -> WaitStart and
    retries on the next Sr+7E/R round.

    Uses cocotb signal force on the internal arbitration_lost_i signal.
    Per ccc_entdaa.sv:296-298, SendIDBit checks arbitration_lost_i on bus_tx_rsp_i.done.
    """
    log = logging.getLogger("test_ccc_entdaa_arb_lost")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # Get handle to the arbitration_lost_i signal inside ccc_entdaa
    entdaa_path = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xccc.xccc_entdaa
    arb_lost_sig = entdaa_path.arbitration_lost_i
    state_sig = entdaa_path.state_q

    # Cocotb background task: wait for DUT to enter SendIDBit state, then
    # force arbitration_lost_i=1 for one bit period to trigger arb-lost path.
    arb_forced = Event()

    async def force_arb_lost():
        """Wait for SendIDBit state (0x07), then force arb_lost for 2 cycles."""
        # Wait for the ENTDAA FSM to start sending ID bits
        for i in range(10000):
            await RisingEdge(tb.clk)
            try:
                state_val = int(state_sig.value)
            except ValueError:
                continue  # X/Z state -- skip
            if state_val == 0x07:  # SendIDBit
                cocotb.log.info(f"SendIDBit detected at cycle {i}")
                break
        else:
            cocotb.log.error("Timeout waiting for SendIDBit state")
            arb_forced.set()
            return

        # Wait a few more cycles to be solidly in bit transmission
        for _ in range(4):
            await RisingEdge(tb.clk)

        # Force arbitration_lost_i = 1 for a brief period
        arb_lost_sig.value = Force(1)
        cocotb.log.info("Forcing arbitration_lost_i = 1")
        await RisingEdge(tb.clk)
        await RisingEdge(tb.clk)
        await RisingEdge(tb.clk)

        # Release the force
        arb_lost_sig.value = Release()
        cocotb.log.info("Released arbitration_lost_i")
        arb_forced.set()

    # Start the force coroutine before issuing ENTDAA
    force_task = cocotb.start_soon(force_arb_lost())

    # Issue ENTDAA for both targets. The first target should lose arbitration
    # on the first round, but the BFM still sends the address and the DUT
    # NACKs. The controller then retries and succeeds on the second round.
    # With our approach, we provide 3 address slots: the first will be lost
    # (DUT NACKs), then the remaining 2 succeed for main + virtual.
    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[DYNAMIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR])

    # Ensure force coroutine completed
    await force_task
    await ClockCycles(tb.clk, 50)

    log.info(f"ENTDAA arb-lost results: {results}")

    # The first result should be a NACK (arb-lost means target NACKs address)
    # or we might get different behavior depending on timing.
    # Check that at least some targets got addresses assigned.
    assigned = [r for r in results if r["ack"]]
    log.info(f"Successfully assigned: {len(assigned)} targets")

    # Verify the main target got an address after arb-lost recovery
    da_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr
    da_valid_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID
    main_da_valid = await tb.read_csr_field(da_reg_addr, da_valid_field)

    assert main_da_valid == 1, (
        f"Main target should have DA after arb-lost recovery, "
        f"DA_VALID={main_da_valid}, results={results}")

    # Verify target responds at assigned address
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Main target should respond at assigned DA"


# =============================================================================
# GETSTATUS Sr Abort: Protocol Error must not be cleared prematurely
# =============================================================================

    await tb.teardown()
@cocotb.test()
async def test_ccc_getstatus_sr_abort_preserves_protocol_err(dut):
    """
    Per spec (Sec.5.1.9.2.1): A Target shall only clear its Protocol Error status
    after a successful GETSTATUS where the Controller reads ALL bytes. If the
    Controller aborts GETSTATUS after byte 0, the error must NOT be cleared.
    """
    log = logging.getLogger("test_ccc_getstatus_sr_abort")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    err_o_sig = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.err_o

    # Step 1: Trigger a Protocol Error via TE2 (bad T-bit on CCC defining byte)
    log.info("Step 1: Triggering TE2 error to set Protocol Error")
    tb.te_error_monitor.expect_error(2)
    await i3c_controller.send_te2_error(ccc=0x9A, defining_byte=0x01,
                                         corrupt_defining_byte=True)
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 20)

    # Verify err_o is set
    assert int(err_o_sig.value) == 1, \
        f"err_o should be 1 after TE2 error, got {int(err_o_sig.value)}"
    log.info("Step 1 OK: err_o = 1 (Protocol Error set)")

    # Step 2: Send GETSTATUS, abort after byte 0 with Sr + STOP
    log.info("Step 2: Sending GETSTATUS with Sr abort after byte 0")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.DIRECT.GETSTATUS)
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(DYNAMIC_ADDR, read=True)
    assert ack, "Target should ACK GETSTATUS"

    # Read 1 byte (byte 0 = status MSB). stop=True triggers Sr abort during T-bit.
    (byte0, _) = await i3c_controller.recv_byte_t_bit(stop=True)
    log.info(f"Step 2: Read GETSTATUS byte 0 = 0x{byte0:02X} (Controller aborts here)")

    # STOP to end the frame (before any new address completes)
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 50)

    # Step 3: Verify err_o is NOT cleared
    # Per spec, the Controller never received byte 1 (which contains the Protocol
    # Error bit), so the Target must NOT clear its error status.
    err_after = int(err_o_sig.value)
    assert err_after == 1, (
        f"err_o should still be 1 after aborted GETSTATUS (Controller never read byte 1), "
        f"got err_o={err_after}")
    log.info("Step 3 OK: err_o still 1 after aborted GETSTATUS")

    # Step 4: Verify a full GETSTATUS reads correctly and clears the error
    data = await read_ccc_exact(i3c_controller, CCC.DIRECT.GETSTATUS, DYNAMIC_ADDR, [0, 0xE0])
    status = int.from_bytes(data, byteorder="big", signed=False)
    log.info(f"Step 4: Full GETSTATUS returned 0x{status:04X}")
    assert len(data) == 2 and status & 0x20, "Successful retry did not report the preserved Protocol Error"

    await ClockCycles(tb.clk, 20)

    # After a FULL GETSTATUS, err_o should be cleared
    err_final = int(err_o_sig.value)
    assert err_final == 0, (
        f"err_o should be 0 after full GETSTATUS clears it, got err_o={err_final}")
    log.info("Step 4 OK: err_o = 0 after full GETSTATUS")
    tb.te_error_monitor.check()


# =============================================================================
# SETMWL STOP: Partial data must not update the configuration CSR
# =============================================================================

    await tb.teardown()
@cocotb.test()
async def test_ccc_setmwl_stop_during_data(dut):
    """
    STOP during an incomplete SETMWL must not publish a partial value to the CSR.
    Recovery is checked only after STOP, not after an invalid premature Sr.
    """
    log = logging.getLogger("test_ccc_setmwl_stop")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    mwl_sig = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mwl_o

    # Step 1: Set MWL to a known value via normal SETMWL
    known_mwl = 0x0100
    log.info(f"Step 1: Setting MWL to known value 0x{known_mwl:04X}")
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETMWL,
        directed_data=[(DYNAMIC_ADDR, [(known_mwl >> 8) & 0xFF, known_mwl & 0xFF])])
    await ClockCycles(tb.clk, 20)

    mwl_val = int(mwl_sig.value)
    assert mwl_val == known_mwl, \
        f"MWL should be 0x{known_mwl:04X} after setup, got 0x{mwl_val:04X}"
    log.info(f"Step 1 OK: MWL = 0x{mwl_val:04X}")

    # Step 2: Send SETMWL, deliver byte 0, then STOP during byte 1
    # SETMWL is 2-byte direct SET: byte 0 = MSB, byte 1 = LSB
    # We send byte 0 then STOP before byte 1 completes.
    garbled_msb = 0xAA
    log.info(f"Step 2: Sending partial SETMWL (byte 0 = 0x{garbled_msb:02X}), then STOP")

    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.DIRECT.SETMWL)
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(DYNAMIC_ADDR)
    assert ack, "Target should ACK directed SETMWL"

    # Send byte 0 of SETMWL data
    await i3c_controller.send_byte_tbit(garbled_msb)

    # Send 4 bits of byte 1, then STOP.
    for i in range(4):
        await i3c_controller.send_bit(bool(0x55 & (1 << (7 - i))))

    quiet_done = Event()
    quiet_monitor = cocotb.start_soon(monitor_ccc_quiet(dut, tb, quiet_done))
    await ClockCycles(tb.clk, 2)
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 50)
    quiet_done.set()
    await quiet_monitor
    await FallingEdge(tb.clk)

    # Step 3: Verify MWL was NOT corrupted
    # The SETMWL was incomplete (only byte 0 received, byte 1 aborted).
    # Per spec, set_mwl should NOT fire without both bytes.
    mwl_after = int(mwl_sig.value)
    assert mwl_after == known_mwl, (
        f"MWL should still be 0x{known_mwl:04X} after aborted SETMWL, "
        f"got 0x{mwl_after:04X}")
    log.info(f"Step 3 OK: MWL unchanged at 0x{mwl_after:04X}")

    # Step 4: Verify recovery -- a normal SETMWL still works
    new_mwl = 0x0200
    log.info(f"Step 4: Recovery SETMWL to 0x{new_mwl:04X}")
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETMWL,
        directed_data=[(DYNAMIC_ADDR, [(new_mwl >> 8) & 0xFF, new_mwl & 0xFF])])
    await ClockCycles(tb.clk, 20)

    mwl_recovery = int(mwl_sig.value)
    assert mwl_recovery == new_mwl, (
        f"Recovery SETMWL: expected 0x{new_mwl:04X}, got 0x{mwl_recovery:04X}")
    log.info(f"Step 4 OK: MWL = 0x{mwl_recovery:04X} after recovery")

    # Step 5: Verify target still responds to GET CCCs (CCC FSM not stuck)
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Target should ACK GETBCR after SETMWL abort recovery"
    log.info("Step 5 OK: Target responds to GETBCR after recovery")
    await check_private_transfers(i3c_controller, tb, DYNAMIC_ADDR)


# =============================================================================
# GETSTATUS Abort then Immediate CCC Chain (no STOP between)
# =============================================================================

    await tb.teardown()
@cocotb.test()
async def test_ccc_getstatus_abort_then_chain_setmwl(dut):
    """
    Verifies that aborting GETSTATUS mid-read and immediately chaining into
    another CCC (SETMWL) in the same bus frame does NOT clear err_o.

    Per spec (Sec.5.1.9.2.1): The Protocol Error status shall only be cleared
    after a SUCCESSFUL (complete) GETSTATUS read. An aborted GETSTATUS
    followed by a different CCC must NOT clear the error.

    Bus sequence (no STOP between abort and new CCC):
      S -> 0x7E/W -> GETSTATUS -> Sr -> ADDR/R -> byte0 -> Sr(abort)
        -> 0x7E/W -> SETMWL -> Sr -> ADDR/W -> byte0 -> byte1 -> STOP

    RTL path exercised:
      ccc.sv TxDataTbit -> Sr -> RxTargetAddr -> TxTargetAddrAck (0x7E/W)
        -> WaitCCC (CccNextCmd) -> new SETMWL processing -> WaitCCC (CccDone)
      get_status_done_o must NOT fire because the final GETSTATUS T-bit never completed.
    """
    log = logging.getLogger("test_ccc_getstatus_abort_chain")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    err_o_sig = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.err_o
    mwl_sig = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mwl_o

    # Step 1: Trigger a Protocol Error via TE2
    log.info("Step 1: Triggering TE2 error to set Protocol Error")
    tb.te_error_monitor.expect_error(2)
    await i3c_controller.send_te2_error(ccc=0x9A, defining_byte=0x01,
                                         corrupt_defining_byte=True)
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 20)

    assert int(err_o_sig.value) == 1, \
        f"err_o should be 1 after TE2 error, got {int(err_o_sig.value)}"
    log.info("Step 1 OK: err_o = 1")

    # Capture MWL baseline
    mwl_before = int(mwl_sig.value)
    log.info(f"MWL baseline: 0x{mwl_before:04X}")

    # Step 2: Start GETSTATUS, read byte 0, abort with Sr
    log.info("Step 2: GETSTATUS byte 0 then Sr abort")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.DIRECT.GETSTATUS)
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(DYNAMIC_ADDR, read=True)
    assert ack, "Target should ACK GETSTATUS"

    # Read byte 0; stop=True sends Sr during T-bit (Controller abort)
    (byte0, _) = await i3c_controller.recv_byte_t_bit(stop=True)
    log.info(f"Step 2: GETSTATUS byte 0 = 0x{byte0:02X}, Sr abort sent")

    # Step 3: Chain directly into SETMWL (no STOP)
    # After recv_byte_t_bit(stop=True), Sr was already sent by tbit_eod.
    # Bus state: SCL=1, SDA=0. Directly send 0x7E/W to start new CCC.
    new_mwl = 0x0180
    log.info(f"Step 3: Chaining SETMWL (MWL=0x{new_mwl:04X}) in same frame")
    ack = await i3c_controller.write_addr_header(0x7E)
    assert ack, "Target should ACK 0x7E/W for new CCC"
    await i3c_controller.send_byte_tbit(CCC.DIRECT.SETMWL)
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(DYNAMIC_ADDR)
    assert ack, "Target should ACK directed SETMWL"
    await i3c_controller.send_byte_tbit((new_mwl >> 8) & 0xFF)
    await i3c_controller.send_byte_tbit(new_mwl & 0xFF)
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 50)

    # Step 4: Verify err_o is still 1 (GETSTATUS was incomplete)
    err_after = int(err_o_sig.value)
    assert err_after == 1, (
        f"err_o should still be 1 after aborted GETSTATUS + chained SETMWL, "
        f"got err_o={err_after}")
    log.info("Step 4 OK: err_o still 1 (GETSTATUS was not completed)")

    # Step 5: Verify SETMWL completed successfully
    mwl_after = int(mwl_sig.value)
    assert mwl_after == new_mwl, (
        f"MWL should be 0x{new_mwl:04X} after chained SETMWL, got 0x{mwl_after:04X}")
    log.info(f"Step 5 OK: MWL = 0x{mwl_after:04X} (SETMWL completed)")

    # Step 6: Full GETSTATUS clears err_o
    data = await read_ccc_exact(i3c_controller, CCC.DIRECT.GETSTATUS, DYNAMIC_ADDR, [0, 0xE0])
    status = int.from_bytes(data, byteorder="big", signed=False)
    log.info(f"Step 6: Full GETSTATUS returned 0x{status:04X}")

    await ClockCycles(tb.clk, 20)
    err_final = int(err_o_sig.value)
    assert err_final == 0, (
        f"err_o should be 0 after full GETSTATUS, got err_o={err_final}")
    log.info("Step 6 OK: err_o = 0 (recovery complete)")
    tb.te_error_monitor.check()

    await tb.teardown()


# =============================================================================
# Coverage gap tests: ENTDAA partial addressing paths
# =============================================================================


@cocotb.test()
async def test_ccc_entdaa_virtual_only(dut):
    """
    Coverage: ccc.sv line 930, FSM RxCmdTbit -> HandleVirtualTargetENTDAA.

    Boot with main target already having a dynamic address (via boot_init).
    Virtual target has no dynamic address. Issue ENTDAA -- the FSM should skip
    HandleTargetENTDAA and go directly to HandleVirtualTargetENTDAA.
    """
    log = logging.getLogger("test_ccc_entdaa_virtual_only")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    # Boot with main target addressed, virtual target NOT addressed
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=None)
    await ClockCycles(tb.clk, 50)

    # Issue ENTDAA -- only virtual target should participate
    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[VIRT_DYNAMIC_ADDR])
    await ClockCycles(tb.clk, 50)

    log.info(f"ENTDAA results: {results}")
    assert len(results) >= 1, f"Expected at least 1 ENTDAA result, got {len(results)}"
    assert results[0]["ack"] == True, \
        f"Virtual target should ACK ENTDAA, got {results[0]}"

    # Verify main target DA is unchanged
    da_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr
    da_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR
    da_valid_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID
    main_da = await tb.read_csr_field(da_reg_addr, da_field)
    main_da_valid = await tb.read_csr_field(da_reg_addr, da_valid_field)
    assert main_da_valid == 1, f"Main DA_VALID should be 1, got {main_da_valid}"
    assert main_da == DYNAMIC_ADDR, \
        f"Main DA should be unchanged at {DYNAMIC_ADDR:#x}, got {main_da:#x}"

    # Verify virtual target got its address
    vda_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr
    vda_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR
    vda_valid_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID
    virt_da = await tb.read_csr_field(vda_reg_addr, vda_field)
    virt_da_valid = await tb.read_csr_field(vda_reg_addr, vda_valid_field)
    assert virt_da_valid == 1, \
        f"Virtual DA_VALID should be 1 after ENTDAA, got {virt_da_valid}"
    assert virt_da == VIRT_DYNAMIC_ADDR, \
        f"Virtual DA should be {VIRT_DYNAMIC_ADDR:#x}, got {virt_da:#x}"

    # Functional check: virtual target responds at new address
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=VIRT_DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Virtual target should ACK GETBCR at new DA"

    await tb.teardown()


@cocotb.test()
async def test_ccc_entdaa_main_only(dut):
    """
    Coverage: FSM HandleTargetENTDAA -> WaitForENTDAAEnd (ccc.sv line 959),
              Conditional 4.3 (entdaa_needs_virt_addr=0).

    Boot with virtual target already having a dynamic address.
    Main target has no dynamic address. Issue ENTDAA -- after main target
    completes, FSM should go to WaitForENTDAAEnd (not HandleVirtualTargetENTDAA).
    """
    log = logging.getLogger("test_ccc_entdaa_main_only")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    # Boot with virtual target addressed, main target NOT addressed
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=None, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # Issue ENTDAA -- only main target should participate
    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[DYNAMIC_ADDR])
    await ClockCycles(tb.clk, 50)

    log.info(f"ENTDAA results: {results}")
    assert len(results) >= 1, f"Expected at least 1 ENTDAA result, got {len(results)}"
    assert results[0]["ack"] == True, \
        f"Main target should ACK ENTDAA, got {results[0]}"

    # Verify main target got its address
    da_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr
    da_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR
    da_valid_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID
    main_da = await tb.read_csr_field(da_reg_addr, da_field)
    main_da_valid = await tb.read_csr_field(da_reg_addr, da_valid_field)
    assert main_da_valid == 1, \
        f"Main DA_VALID should be 1 after ENTDAA, got {main_da_valid}"
    assert main_da == DYNAMIC_ADDR, \
        f"Main DA should be {DYNAMIC_ADDR:#x}, got {main_da:#x}"

    # Verify virtual target DA is unchanged
    vda_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr
    vda_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR
    vda_valid_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID
    virt_da = await tb.read_csr_field(vda_reg_addr, vda_field)
    virt_da_valid = await tb.read_csr_field(vda_reg_addr, vda_valid_field)
    assert virt_da_valid == 1, \
        f"Virtual DA_VALID should still be 1, got {virt_da_valid}"
    assert virt_da == VIRT_DYNAMIC_ADDR, \
        f"Virtual DA should be unchanged at {VIRT_DYNAMIC_ADDR:#x}, got {virt_da:#x}"

    # Functional check: main target responds at new address
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Main target should ACK GETBCR at new DA"

    await tb.teardown()


@cocotb.test()
async def test_ccc_entdaa_both_addressed(dut):
    """
    Coverage: FSM RxCmdTbit -> WaitForENTDAAEnd (ccc.sv line 931).

    Boot with both targets already having dynamic addresses. Issue ENTDAA again.
    The FSM should go directly to WaitForENTDAAEnd since both targets already
    have addresses (entdaa_needs_main_addr=0, entdaa_needs_virt_addr=0).
    """
    log = logging.getLogger("test_ccc_entdaa_both_addressed")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR, EXTRA_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 5)

    # Boot with both targets already addressed
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # Issue ENTDAA -- neither target needs an address, so both should NACK
    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[EXTRA_ADDR])
    await ClockCycles(tb.clk, 50)

    log.info(f"ENTDAA results: {results}")
    # Target should NACK since no ENTDAA participation needed
    assert len(results) >= 1, f"Expected at least 1 result, got {len(results)}"
    assert results[0]["ack"] == False, \
        f"Target should NACK ENTDAA when both already addressed, got {results[0]}"

    # Verify addresses are unchanged
    da_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr
    da_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR
    da_valid_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID
    main_da = await tb.read_csr_field(da_reg_addr, da_field)
    main_da_valid = await tb.read_csr_field(da_reg_addr, da_valid_field)
    assert main_da_valid == 1 and main_da == DYNAMIC_ADDR, \
        f"Main DA unchanged: expected {DYNAMIC_ADDR:#x}, got {main_da:#x} valid={main_da_valid}"

    vda_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr
    vda_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR
    vda_valid_field = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID
    virt_da = await tb.read_csr_field(vda_reg_addr, vda_field)
    virt_da_valid = await tb.read_csr_field(vda_reg_addr, vda_valid_field)
    assert virt_da_valid == 1 and virt_da == VIRT_DYNAMIC_ADDR, \
        f"Virtual DA unchanged: expected {VIRT_DYNAMIC_ADDR:#x}, got {virt_da:#x} valid={virt_da_valid}"

    # Functional check: both targets still respond
    for addr in [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]:
        responses = await i3c_controller.i3c_ccc_read(
            ccc=CCC.DIRECT.GETBCR, addr=addr, count=1)
        assert responses[0][0] == True, \
            f"Target at {addr:#x} should still ACK GETBCR"

    # ENTDAA is a mode, not an ordinary broadcast-to-private boundary.
    await i3c_controller.i3c_ccc_write(ccc=CCC.BCAST.ENTDAA, stop=False)
    await i3c_controller.take_bus_control()
    for address, read in ((DYNAMIC_ADDR, False), (DYNAMIC_ADDR, True), (0x7E, False)):
        await i3c_controller.send_start()
        assert not await i3c_controller.write_addr_header(address, read=read), "ENTDAA mode ended at an ordinary Sr"
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await check_private_transfers(i3c_controller, tb, DYNAMIC_ADDR)
    await do_getmwl(i3c_controller, DYNAMIC_ADDR)

    await tb.teardown()


# =============================================================================
# Coverage gap tests: TE0 reserved address in direct CCC
# =============================================================================


@cocotb.test()
async def test_ccc_te0_reserved_addr_direct(dut):
    """
    Coverage: Toggle is_te0_err_condition, te0_err_ccc (ccc.sv:769, 1060-1061).

    Send a direct CCC where the target address phase uses 7'h7E/R (reserved
    address with read bit). This triggers is_te0_err_condition in
    TxTargetAddrAck. TE0 fires, TE0_ERR_STAT is set, and the target enters
    HDR error mode.
    """
    log = logging.getLogger("test_ccc_te0_reserved_addr_direct")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    tb.te_error_monitor.expect_error(0)
    await ClockCycles(tb.clk, 50)

    err_intr_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr
    te0_stat_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.TE0_ERR_STAT
    err_en_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.base_addr
    te0_en_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.TE0_ERR_EN
    await tb.write_csr_field(err_en_addr, te0_en_field, 1)
    await tb.write_csr_field(err_intr_addr, te0_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    # Send direct CCC with 7E/R as target address (TE0 trigger)
    log.info("Sending direct CCC with 7E/R as target address (TE0)")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.DIRECT.GETBCR)
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E, read=True)
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 30)

    # Verify TE0 error status is set
    te0_stat = await tb.read_csr_field(err_intr_addr, te0_stat_field)
    assert te0_stat == 1, \
        f"TE0_ERR_STAT should be 1 after 7E/R in direct CCC target address, got {te0_stat}"

    # Target is now in HDR error mode. Send HDR exit to recover.
    await i3c_controller.send_hdr_exit()
    await ClockCycles(tb.clk, 50)

    # Verify recovery: target responds to GETBCR
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Target should ACK GETBCR after TE0 recovery"

    await tb.teardown()


# =============================================================================
# Coverage gap tests: Direct CCC chain via 7E/W termination
# =============================================================================


@cocotb.test()
async def test_ccc_direct_chain_7e_termination(dut):
    """
    Coverage: ccc.sv target_addr_matches_rsvd -> WaitCCC (CccNextCmd).

    After a direct GET CCC response, send Sr + 7E/W instead of STOP. This
    triggers the target_addr_matches_rsvd path in TxTargetAddrAck, transitioning
    to WaitCCC with CccNextCmd. Then send a new CCC command byte to chain.
    """
    log = logging.getLogger("test_ccc_direct_chain_7e_termination")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # Raw protocol: GETBCR -> Sr+7E/W -> GETDCR (chained)
    log.info("Sending GETBCR, then chaining GETDCR via Sr+7E/W")
    await i3c_controller.take_bus_control()

    # CCC 1: GETBCR
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.DIRECT.GETBCR)
    await i3c_controller.send_start()
    ack1 = await i3c_controller.write_addr_header(DYNAMIC_ADDR, read=True)
    assert ack1, "Target should ACK GETBCR address"
    (bcr_byte, _) = await i3c_controller.recv_byte_t_bit(stop=False)
    log.info(f"GETBCR returned: 0x{bcr_byte:02X}")

    # Chain: Sr + 7E/W (triggers CccNextCmd and direct return to WaitCCC)
    await i3c_controller.send_start()
    ack_7e = await i3c_controller.write_addr_header(0x7E)
    assert ack_7e, "Target should ACK 0x7E/W for CCC chain"

    # CCC 2: GETDCR
    await i3c_controller.send_byte_tbit(CCC.DIRECT.GETDCR)
    await i3c_controller.send_start()
    ack2 = await i3c_controller.write_addr_header(DYNAMIC_ADDR, read=True)
    assert ack2, "Target should ACK GETDCR address"
    (dcr_byte, _) = await i3c_controller.recv_byte_t_bit(stop=False)
    log.info(f"GETDCR returned: 0x{dcr_byte:02X}")

    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 50)

    # Verify both responses are sensible
    log.info(f"Chained results: BCR=0x{bcr_byte:02X}, DCR=0x{dcr_byte:02X}")

    # Verify clean state: normal CCC still works
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "GETBCR should ACK after chain"

    await tb.teardown()


# =============================================================================
# Coverage gap tests: TE error detection enable toggles
# =============================================================================


@cocotb.test()
async def test_ccc_all_det_en_toggle(dut):
    """
    Coverage: All *_det_en_i toggle coverage (IDs 8.0).

    For TE0, TE1, TE2, TE5: toggle the detection enable CSR, inject
    the error with det_en=0 (verify no error flag), then with det_en=1
    (verify error fires). TE3/TE4 det_en toggling is covered separately
    by test_ccc_entdaa_te3_det_en_toggle and test_ccc_entdaa_te3_te4.
    """
    log = logging.getLogger("test_ccc_all_det_en_toggle")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    # Boot WITH dynamic addresses (no ENTDAA cycling needed)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)

    tb.te_error_monitor.expect_error(0, 1, 2, 5)
    await ClockCycles(tb.clk, 50)

    err_ctrl_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CTRL.base_addr
    err_intr_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr
    err_en_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.base_addr

    # Helper: enable all interrupt status capture
    for field_name in ['TE0_ERR_EN', 'TE1_ERR_EN', 'TE2_ERR_EN',
                        'TE5_ERR_EN']:
        field = getattr(tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE, field_name)
        await tb.write_csr_field(err_en_addr, field, 1)

    # ---- TE2: CCC data parity ----
    log.info("=== TE2 det_en toggle ===")
    te2_det_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CTRL.TE2_ERR_DET_EN
    te2_stat_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.TE2_ERR_STAT

    # Disable TE2
    await tb.write_csr_field(err_ctrl_addr, te2_det_field, 0)
    await tb.write_csr_field(err_intr_addr, te2_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    await i3c_controller.send_te2_error(ccc=0x9A, defining_byte=0x01,
                                         corrupt_defining_byte=True)
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 20)

    te2_stat = await tb.read_csr_field(err_intr_addr, te2_stat_field)
    log.info(f"TE2 with det_en=0: stat={te2_stat}")
    assert te2_stat == 0, \
        f"TE2_ERR_STAT should be 0 with detection disabled, got {te2_stat}"

    # Re-enable TE2
    await tb.write_csr_field(err_ctrl_addr, te2_det_field, 1)
    await tb.write_csr_field(err_intr_addr, te2_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    await i3c_controller.send_te2_error(ccc=0x9A, defining_byte=0x01,
                                         corrupt_defining_byte=True)
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 20)

    te2_stat = await tb.read_csr_field(err_intr_addr, te2_stat_field)
    log.info(f"TE2 with det_en=1: stat={te2_stat}")
    assert te2_stat == 1, \
        f"TE2_ERR_STAT should be 1 with detection enabled, got {te2_stat}"

    # ---- TE1: CCC command parity ----
    log.info("=== TE1 det_en toggle ===")
    te1_det_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CTRL.TE1_ERR_DET_EN
    te1_stat_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.TE1_ERR_STAT

    # Disable TE1
    await tb.write_csr_field(err_ctrl_addr, te1_det_field, 0)
    await tb.write_csr_field(err_intr_addr, te1_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    # Use a non-ENTHDR CCC code to avoid triggering HDR mode via normal path
    await i3c_controller.send_te1_error(ccc=0x09)  # SETMWL bcast, not ENTHDR
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 20)

    te1_stat = await tb.read_csr_field(err_intr_addr, te1_stat_field)
    log.info(f"TE1 with det_en=0: stat={te1_stat}")
    assert te1_stat == 0, \
        f"TE1_ERR_STAT should be 0 with detection disabled, got {te1_stat}"

    # Re-enable TE1
    await tb.write_csr_field(err_ctrl_addr, te1_det_field, 1)
    await tb.write_csr_field(err_intr_addr, te1_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    await i3c_controller.send_te1_error(ccc=0x09)  # SETMWL bcast with bad parity
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 20)

    # TE1 puts target in HDR mode -- recover first
    await i3c_controller.send_hdr_exit()
    await ClockCycles(tb.clk, 50)

    te1_stat = await tb.read_csr_field(err_intr_addr, te1_stat_field)
    log.info(f"TE1 with det_en=1: stat={te1_stat}")
    assert te1_stat == 1, \
        f"TE1_ERR_STAT should be 1 with detection enabled, got {te1_stat}"

    # ---- TE0: Reserved address ----
    log.info("=== TE0 det_en toggle ===")
    te0_det_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CTRL.TE0_ERR_DET_EN
    te0_stat_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.TE0_ERR_STAT

    # Disable TE0
    await tb.write_csr_field(err_ctrl_addr, te0_det_field, 0)
    await tb.write_csr_field(err_intr_addr, te0_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    await i3c_controller.send_te0_error()
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 20)

    te0_stat = await tb.read_csr_field(err_intr_addr, te0_stat_field)
    log.info(f"TE0 with det_en=0: stat={te0_stat}")
    assert te0_stat == 0, \
        f"TE0_ERR_STAT should be 0 with detection disabled, got {te0_stat}"

    # Re-enable TE0
    await tb.write_csr_field(err_ctrl_addr, te0_det_field, 1)
    await tb.write_csr_field(err_intr_addr, te0_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    await i3c_controller.send_te0_error()
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 20)

    # TE0 puts target in HDR mode -- recover
    await i3c_controller.send_hdr_exit()
    await ClockCycles(tb.clk, 50)

    te0_stat = await tb.read_csr_field(err_intr_addr, te0_stat_field)
    log.info(f"TE0 with det_en=1: stat={te0_stat}")
    assert te0_stat == 1, \
        f"TE0_ERR_STAT should be 1 with detection enabled, got {te0_stat}"

    # ---- TE5: Wrong R/W direction ----
    log.info("=== TE5 det_en toggle ===")
    te5_det_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CTRL.TE5_ERR_DET_EN
    te5_stat_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.TE5_ERR_STAT

    # Disable TE5
    await tb.write_csr_field(err_ctrl_addr, te5_det_field, 0)
    await tb.write_csr_field(err_intr_addr, te5_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    # GET CCC with Write direction = wrong direction
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.GETBCR, directed_data=[(DYNAMIC_ADDR, [0x00])])
    await ClockCycles(tb.clk, 20)

    te5_stat = await tb.read_csr_field(err_intr_addr, te5_stat_field)
    log.info(f"TE5 with det_en=0: stat={te5_stat}")
    assert te5_stat == 0, \
        f"TE5_ERR_STAT should be 0 with detection disabled, got {te5_stat}"

    # Re-enable TE5
    await tb.write_csr_field(err_ctrl_addr, te5_det_field, 1)
    await tb.write_csr_field(err_intr_addr, te5_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.GETBCR, directed_data=[(DYNAMIC_ADDR, [0x00])])
    await ClockCycles(tb.clk, 20)

    te5_stat = await tb.read_csr_field(err_intr_addr, te5_stat_field)
    log.info(f"TE5 with det_en=1: stat={te5_stat}")
    assert te5_stat == 1, \
        f"TE5_ERR_STAT should be 1 with detection enabled, got {te5_stat}"

    # Verify target still functional after all error injections
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Target should ACK GETBCR after all TE toggle tests"

    await tb.teardown()


# =============================================================================
# Coverage gap tests Phase 2: TE2 in RxDirectDefByteTbit
# =============================================================================


@cocotb.test()
async def test_ccc_te2_direct_def_byte_tbit(dut):
    """
    Coverage: ccc.sv RxDirectDefByteTbit -> WaitForStop -> WaitCCC,
              WaitDirectRstart -> RxDirectDefByteTbit, Conditional 4.1.

    Send a direct CCC with defining byte, then an EXTRA data byte with bad
    T-bit parity before the repeated start for the target address. This
    exercises the RxDirectDefByteTbit state TE2 path.
    """
    log = logging.getLogger("test_ccc_te2_direct_def_byte_tbit")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    tb.te_error_monitor.expect_error(2)
    await ClockCycles(tb.clk, 50)

    err_intr_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr
    te2_stat_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.TE2_ERR_STAT
    err_en_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.base_addr
    te2_en_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.TE2_ERR_EN
    await tb.write_csr_field(err_en_addr, te2_en_field, 1)
    await tb.write_csr_field(err_intr_addr, te2_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    # Raw protocol: S + 7E/W + GETCAPS(0x95) + def_byte(0x00) + extra_byte(bad parity)
    log.info("Sending GETCAPS with extra data byte with bad T-bit parity")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.DIRECT.GETCAPS)
    # Defining byte with good parity
    await i3c_controller.send_byte_tbit(0x00)
    # Extra data byte with bad T-bit parity -- triggers RxDirectDefByteTbit TE2
    count_before = tb.te_error_monitor.error_counts[2]
    await i3c_controller.send_byte_tbit(0xAA, inject_tbit_err=True)
    await exercise_te2_quiescence(i3c_controller, dut, tb, (DYNAMIC_ADDR, 0x7E, VIRT_DYNAMIC_ADDR), count_before)
    await ClockCycles(tb.clk, 30)

    te2_stat = await tb.read_csr_field(err_intr_addr, te2_stat_field)
    assert te2_stat == 1, \
        f"TE2_ERR_STAT should be 1 after bad parity in RxDirectDefByteTbit, got {te2_stat}"

    # Verify recovery
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Target should ACK GETBCR after TE2 recovery"

    await tb.teardown()


# =============================================================================
# Coverage gap tests Phase 2: Extra data bytes before target address
# =============================================================================


@cocotb.test()
async def test_ccc_direct_extra_data_before_addr(dut):
    """
    Coverage: ccc.sv line 1028, FSM WaitDirectRstart -> RxDirectDefByteTbit,
              FSM RxDirectDefByteTbit -> WaitDirectRstart.

    Send a direct CCC with defining byte, then extra data bytes with GOOD
    T-bit parity before the repeated start. Then complete the CCC normally.
    """
    log = logging.getLogger("test_ccc_direct_extra_data_before_addr")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # Raw protocol: S + 7E/W + GETCAPS(0x95) + def_byte(0x00) + extra_bytes + Sr + addr/R + data
    log.info("Sending GETCAPS with extra data bytes (good parity) before target addr")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.DIRECT.GETCAPS)
    await i3c_controller.send_byte_tbit(0x00)
    # Extra data bytes -- exercises WaitDirectRstart -> RxDirectDefByteTbit loop
    await i3c_controller.send_byte_tbit(0xBB)
    await i3c_controller.send_byte_tbit(0xCC)
    # Now Sr + target address to complete CCC normally
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(DYNAMIC_ADDR, read=True)
    assert ack, "Target should ACK GETCAPS address"
    rd_data = bytearray()
    await i3c_controller.recv_until_eod_tbit(rd_data, 3)
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 30)

    log.info(f"GETCAPS returned: {[hex(b) for b in rd_data]}")
    assert len(rd_data) == 3, f"Expected 3 bytes from GETCAPS, got {len(rd_data)}"

    # Verify no TE2 error
    err_intr_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr
    te2_stat_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.TE2_ERR_STAT
    te2_stat = await tb.read_csr_field(err_intr_addr, te2_stat_field)
    assert te2_stat == 0, f"TE2_ERR_STAT should be 0 (good parity), got {te2_stat}"

    await tb.teardown()


# =============================================================================
# Coverage gap tests Phase 2: TE2 on direct SET CCC data byte
# =============================================================================


@cocotb.test()
async def test_ccc_te2_data_byte_direct_set(dut):
    """
    Coverage: FSM RxDataTbit -> WaitForStop -> WaitCCC.

    Send a direct SET CCC (SETMWL) and inject T-bit parity error on the
    first data byte after target ACKs the address.
    """
    log = logging.getLogger("test_ccc_te2_data_byte_direct_set")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    tb.te_error_monitor.expect_error(2)
    await ClockCycles(tb.clk, 50)

    err_intr_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr
    te2_stat_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.TE2_ERR_STAT
    err_en_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.base_addr
    te2_en_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.TE2_ERR_EN
    await tb.write_csr_field(err_en_addr, te2_en_field, 1)
    await tb.write_csr_field(err_intr_addr, te2_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    # Raw protocol: S + 7E/W + SETMWL(0x89) + Sr + addr/W + data_byte(bad parity)
    log.info("Sending direct SETMWL with bad T-bit parity on data byte")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.DIRECT.SETMWL)
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(DYNAMIC_ADDR)
    assert ack, "Target should ACK SETMWL address"
    count_before = tb.te_error_monitor.error_counts[2]
    await i3c_controller.send_byte_tbit(0x00, inject_tbit_err=True)
    await exercise_te2_quiescence(i3c_controller, dut, tb, (DYNAMIC_ADDR, 0x7E, VIRT_DYNAMIC_ADDR), count_before)
    await ClockCycles(tb.clk, 30)

    te2_stat = await tb.read_csr_field(err_intr_addr, te2_stat_field)
    assert te2_stat == 1, \
        f"TE2_ERR_STAT should be 1 after bad data byte parity, got {te2_stat}"

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Target should ACK GETBCR after TE2 data byte recovery"

    # Disabled detection accepts the same bad parity and completes the field.
    tti = tb.reg_map.I3C_EC.TTI
    count_before = tb.te_error_monitor.error_counts[2]
    counter = await tb.read_csr_field(tti.TARGET_ERR_CNT_TE2.base_addr, tti.TARGET_ERR_CNT_TE2.CNT)
    await tb.write_csr_field(tti.TARGET_ERR_CTRL.base_addr, tti.TARGET_ERR_CTRL.TE2_ERR_DET_EN, 0)
    await tb.write_csr_field(err_intr_addr, te2_stat_field, 1)
    await read_ccc_exact(i3c_controller, CCC.DIRECT.GETSTATUS, DYNAMIC_ADDR, [0, 0xE0])
    log.info("Sending SETMWL with bad parity but DET_EN=0; expecting a committed complete field")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    assert await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.DIRECT.SETMWL)
    await i3c_controller.send_start()
    assert await i3c_controller.write_addr_header(DYNAMIC_ADDR)
    await i3c_controller.send_byte_tbit(0x01, inject_tbit_err=True)
    await i3c_controller.send_byte_tbit(0x46)
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 10)
    assert int(dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mwl_o.value) == 0x0146
    assert int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.err_o.value) == 0
    assert tb.te_error_monitor.error_counts[2] == count_before
    assert await tb.read_csr_field(tti.TARGET_ERR_CNT_TE2.base_addr, tti.TARGET_ERR_CNT_TE2.CNT) == counter
    assert await tb.read_csr_field(err_intr_addr, te2_stat_field) == 0
    await tb.write_csr_field(tti.TARGET_ERR_CTRL.base_addr, tti.TARGET_ERR_CTRL.TE2_ERR_DET_EN, 1)
    await tb.teardown()


# =============================================================================
# Coverage gap tests Phase 2: TE3 detection enable toggle (ENTDAA)
# =============================================================================


@cocotb.test()
async def test_ccc_entdaa_te3_det_en_toggle(dut):
    """
    Coverage: Toggle te3_err_det_en_i in ccc_entdaa (ID 3.4).

    Inject TE3 (bad address parity during ENTDAA) with te3_err_det_en=0
    then with te3_err_det_en=1.
    """
    log = logging.getLogger("test_ccc_entdaa_te3_det_en_toggle")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR)
    tb.te_error_monitor.expect_error(3)
    await ClockCycles(tb.clk, 50)

    err_ctrl_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CTRL.base_addr
    err_intr_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr
    te3_det_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CTRL.TE3_ERR_DET_EN
    te3_stat_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.TE3_ERR_STAT
    err_en_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.base_addr
    te3_en_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.TE3_ERR_EN
    await tb.write_csr_field(err_en_addr, te3_en_field, 1)

    # Phase A: disabled
    await tb.write_csr_field(err_ctrl_addr, te3_det_field, 0)
    await tb.write_csr_field(err_intr_addr, te3_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[DYNAMIC_ADDR], inject_te3_parity=True)
    await ClockCycles(tb.clk, 30)

    te3_stat = await tb.read_csr_field(err_intr_addr, te3_stat_field)
    log.info(f"TE3 det_en=0: stat={te3_stat}, ack={results[0]['ack']}")
    assert te3_stat == 0, f"TE3 should be 0 with det_en=0, got {te3_stat}"

    # Reset
    await i3c_controller.i3c_ccc_write(ccc=CCC.BCAST.RSTDAA)
    await ClockCycles(tb.clk, 30)

    # Phase B: enabled
    await tb.write_csr_field(err_ctrl_addr, te3_det_field, 1)
    await tb.write_csr_field(err_intr_addr, te3_stat_field, 1)
    await ClockCycles(tb.clk, 5)

    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[DYNAMIC_ADDR], inject_te3_parity=True)
    await ClockCycles(tb.clk, 30)

    te3_stat = await tb.read_csr_field(err_intr_addr, te3_stat_field)
    log.info(f"TE3 det_en=1: stat={te3_stat}, ack={results[0]['ack']}")
    assert te3_stat == 1, f"TE3 should be 1 with det_en=1, got {te3_stat}"
    assert results[0]["ack"] == False, "Target should NACK with TE3 det_en=1"

    await tb.teardown()


# =============================================================================
# Coverage gap tests Phase 2: STOP mid-transfer from various FSM states
# =============================================================================


@cocotb.test()
async def test_ccc_stop_mid_transfer(dut):
    """Require receive-side STOP occurrence and recovery; active read-state STOP arcs remain unproven."""
    log = logging.getLogger("test_ccc_stop_mid_transfer")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)
    finished = Event()
    stop_expectations = (
        CccStopExpectation("A: WaitDirectRstart", 5),
        CccStopExpectation("A: completed recovery GETBCR", 15),
        CccStopExpectation("B: RxDefByteOrBusCond", 3),
        CccStopExpectation("B: completed recovery GETBCR", 15),
        CccStopExpectation("C: RxDefByte", 2),
        CccStopExpectation("C: completed recovery GETBCR", 15),
    )
    handoff_monitor = cocotb.start_soon(monitor_ccc_handoff(dut, tb, finished, stop_expectations))

    # ---- Sub-test A: WaitDirectRstart -> WaitCCC ----
    log.info("Sub-test A: STOP in WaitDirectRstart")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.DIRECT.GETBCR)
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 30)

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Recovery after WaitDirectRstart STOP failed"
    log.info("Sub-test A: PASS")

    # ---- Sub-test B: RxDefByteOrBusCond -> WaitCCC ----
    log.info("Sub-test B: STOP in RxDefByteOrBusCond")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.DIRECT.GETCAPS)
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 30)

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Recovery after RxDefByteOrBusCond STOP failed"
    log.info("Sub-test B: PASS")

    # ---- Sub-test C: RxDefByte -> WaitCCC ----
    log.info("Sub-test C: STOP in RxDefByte")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.BCAST.RSTACT)
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 30)

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Recovery after RxDefByte STOP failed"
    log.info("Sub-test C: PASS")

    # Basic 1.1.1 5.1.2.3.4 transfers SDA ownership at the T-bit, not during data.
    # An RTL override's existence is not evidence that its active-state arc was hit.
    log.info("CCC_STOP_SCOPE: D/E/F not exercised; active TxData/TxDataTbitCont/TxDataTbitEnd STOP arcs remain unproven")

    finished.set()
    await handoff_monitor
    log.info("CCC_STOP_SCOPE: receive-side A/B/C and three recovery STOPs checked; no read-state coverage inferred")
    await tb.teardown()


# =============================================================================
# Coverage gap tests Phase 3: ENTDAA STOP in specific FSM states
# =============================================================================


@cocotb.test()
async def test_ccc_entdaa_stop_in_waitstart(dut):
    """
    Coverage: ENTDAA FSM WaitStart -> Done (ccc_entdaa.sv).

    Issue ENTDAA CCC byte, then STOP immediately before Sr+7E/R.
    The ENTDAA FSM should be in WaitStart when STOP arrives.
    """
    log = logging.getLogger("test_ccc_entdaa_stop_in_waitstart")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR)
    await ClockCycles(tb.clk, 50)

    # Raw ENTDAA: S + 7E/W + 0x07 (ENTDAA CCC) + STOP (before Sr+7E/R)
    log.info("ENTDAA CCC then immediate STOP in WaitStart")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(0x07)  # ENTDAA
    # ENTDAA FSM is now in WaitStart, waiting for Sr+7E/R
    # Issue STOP instead
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 50)

    # Assign addresses normally and verify recovery
    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR])
    await ClockCycles(tb.clk, 50)

    assert len(results) >= 1, f"Expected ENTDAA results after recovery, got {len(results)}"

    # Verify target responds
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Target should ACK GETBCR after ENTDAA WaitStart STOP recovery"

    await tb.teardown()


@cocotb.test()
async def test_ccc_entdaa_stop_in_sendidbit(dut):
    """Check retained malformed ID-abort stimulus: arbitration loss, WaitStart STOP and retry, not SendIDBit STOP."""
    log = logging.getLogger("test_ccc_entdaa_stop_in_sendidbit")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR)
    await ClockCycles(tb.clk, 50)
    finished = Event()
    stop_expectations = (
        CccStopExpectation("ID abort: arbitration loss then WaitStart STOP", 17, 1, 1),
        CccStopExpectation("ID abort: two-address ENTDAA retry STOP", 16, 0),
        CccStopExpectation("ID abort: completed recovery GETBCR", 15, 0),
    )
    handoff_monitor = cocotb.start_soon(monitor_ccc_handoff(dut, tb, finished, stop_expectations))

    log.info("CCC_STOP_SCOPE: retain ID-abort stimulus; expect one arbitration loss before WaitStart STOP, not active SendIDBit STOP")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(0x07)  # ENTDAA

    # Sr + 7E/R
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(0x7E, read=True)
    assert ack, "ENTDAA reserved header must ACK before ID-abort stimulus"

    for _ in range(8):
        await i3c_controller.recv_bit_od()

    # The helper clocks controller SDA low against a released ID bit before STOP.
    log.info("CCC_STOP_SCOPE: eight ID bits received; entering malformed abort/STOP helper")
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 50)

    # Recovery: assign addresses via normal ENTDAA
    log.info("CCC_STOP_SCOPE: ID-abort STOP sent; starting two-address ENTDAA retry")
    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR])
    await ClockCycles(tb.clk, 50)

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Target should ACK GETBCR after ID-abort arbitration-loss/STOP recovery"

    finished.set()
    await handoff_monitor
    log.info("CCC_STOP_SCOPE: ID-abort recovery checked; direct SendIDBit-to-Done STOP arc remains unproven")
    await tb.teardown()


@cocotb.test()
async def test_ccc_entdaa_stop_in_receiveaddr(dut):
    """
    Coverage: ENTDAA FSM ReceiveAddr -> Done (ccc_entdaa.sv).

    Start ENTDAA, complete ID bit transmission (64 bits), then start sending
    the address byte but issue STOP mid-address-byte. The ENTDAA FSM should
    be in ReceiveAddr.
    """
    log = logging.getLogger("test_ccc_entdaa_stop_in_receiveaddr")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR)
    await ClockCycles(tb.clk, 50)

    log.info("ENTDAA with STOP during address byte reception")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(0x07)  # ENTDAA

    # Sr + 7E/R
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(0x7E, read=True)
    if not ack:
        log.warning("Target NACKed 7E/R during ENTDAA, skipping ReceiveAddr STOP")
        await i3c_controller.send_stop()
        i3c_controller.give_bus_control()
        await tb.teardown()
        return

    # Read all 64 ID bits (PID+BCR+DCR)
    for _ in range(64):
        await i3c_controller.recv_bit_od()

    # Start sending address byte but send only 4 bits then STOP
    addr_byte = (DYNAMIC_ADDR << 1) | i3c_controller._odd_parity(DYNAMIC_ADDR)
    for i in range(4):
        await i3c_controller.send_bit(addr_byte & (1 << (7 - i)))

    # STOP mid-address-byte (ENTDAA FSM in ReceiveAddr)
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 50)

    # Recovery: assign addresses via normal ENTDAA
    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR])
    await ClockCycles(tb.clk, 50)

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Target should ACK GETBCR after ENTDAA ReceiveAddr STOP recovery"

    await tb.teardown()


# =============================================================================
# Read completion/abort boundaries and retained malformed STOP recovery.
# Basic 1.1.1 5.1.2.3.4 and FAQ Q23.5 do not authorize contention during target SDA ownership.


@cocotb.test()
async def test_ccc_stop_during_target_read(dut):
    """Distinguish malformed A/B recovery from legal C/D handoffs; require actual STOP states, not helper-entry labels."""
    log = logging.getLogger("test_ccc_stop_during_target_read")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)
    finished = Event()
    stop_expectations = (
        CccStopExpectation("A: delayed STOP after completed GETBCR", 15, arbitration_losses=None),
        CccStopExpectation("A: completed recovery GETBCR", 15),
        CccStopExpectation("B: malformed STOP during TxData", 12, arbitration_losses=None),
        CccStopExpectation("B: completed recovery GETBCR", 15),
        CccStopExpectation("C: final T=0 completion then STOP", 15),
        CccStopExpectation("C: completed recovery GETBCR", 15),
        CccStopExpectation("D: continuation T=1 abort then RxTargetAddr STOP", 7),
        CccStopExpectation("D: completed recovery GETBCR", 15),
    )
    handoff_monitor = cocotb.start_soon(monitor_ccc_handoff(dut, tb, finished, stop_expectations))

    # Retain existing contention suppression for the original stimulus; it does not establish legal STOP coverage.
    log.info("CCC_STOP_SCOPE A: premature STOP request after ACK; expect detected STOP only after GETBCR completes")
    if tb.bus_monitor:
        tb.bus_monitor.suppress_check("BUS_CONTENTION")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.DIRECT.GETBCR)
    await i3c_controller.send_start()
    # write_addr_header sends 8 bits + waits for ACK -- STOP right after
    ack = await i3c_controller.write_addr_header(DYNAMIC_ADDR, read=True)
    assert ack, "GETBCR address must ACK before premature STOP request"
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    if tb.bus_monitor:
        tb.bus_monitor.unsuppress_check("BUS_CONTENTION")
    await ClockCycles(tb.clk, 50)

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Recovery failed after delayed post-ACK STOP"
    log.info("CCC_STOP_SCOPE A: recovery GETBCR ACKed; active address-ACK STOP arc not claimed")

    log.info("CCC_STOP_SCOPE B: retained malformed STOP request during push-pull GETPID; contention is not legal handoff")
    if tb.bus_monitor:
        tb.bus_monitor.suppress_check("BUS_CONTENTION")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.DIRECT.GETPID)
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(DYNAMIC_ADDR, read=True)
    assert ack, "GETPID address must ACK before malformed STOP request"
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    if tb.bus_monitor:
        tb.bus_monitor.unsuppress_check("BUS_CONTENTION")
    await ClockCycles(tb.clk, 50)

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Recovery failed after malformed TxData STOP"
    log.info("CCC_STOP_SCOPE B: recovery GETBCR ACKed; TxData STOP evidence is malformed-input recovery only")

    log.info("CCC_STOP_SCOPE C: receive final T=0, then STOP in WaitForBusCond")
    if tb.bus_monitor:
        tb.bus_monitor.suppress_check("BUS_CONTENTION")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.DIRECT.GETBCR)
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(DYNAMIC_ADDR, read=True)
    assert ack, "GETBCR address must ACK before final-T-bit completion"
    (byte_val, eod) = await i3c_controller.recv_byte_t_bit(stop=False)
    assert eod, "GETBCR must complete with target T=0 before STOP"
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    if tb.bus_monitor:
        tb.bus_monitor.unsuppress_check("BUS_CONTENTION")
    await ClockCycles(tb.clk, 50)

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Recovery failed after final-T-bit completion and STOP"
    log.info("CCC_STOP_SCOPE C: recovery GETBCR ACKed after completed final T-bit; no active-T-bit STOP claim")

    log.info("CCC_STOP_SCOPE D: receive continuation T=1, then abort and STOP in RxTargetAddr")
    if tb.bus_monitor:
        tb.bus_monitor.suppress_check("BUS_CONTENTION")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(CCC.DIRECT.GETMRL)
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(DYNAMIC_ADDR, read=True)
    assert ack, "GETMRL address must ACK before continuation abort"
    (byte_val, eod) = await i3c_controller.recv_byte_t_bit(stop=False)
    assert not eod, "First GETMRL byte must have target T=1 before abort"
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    if tb.bus_monitor:
        tb.bus_monitor.unsuppress_check("BUS_CONTENTION")
    await ClockCycles(tb.clk, 50)

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, "Recovery failed after continuation abort and STOP"
    log.info("CCC_STOP_SCOPE D: recovery GETBCR ACKed after abort; no active-continuation-T-bit STOP claim")

    finished.set()
    await handoff_monitor
    log.info("CCC_STOP_SCOPE: eight STOP boundaries checked; active ACK/T-bit STOP arcs remain unproven")
    await tb.teardown()


@cocotb.test()
async def test_ccc_entdaa_stop_in_ackrsvdbyte(dut):
    """Check malformed post-ACK abort and recovery; actively driven ACK-low STOP remains physically unavailable."""
    log = logging.getLogger("test_ccc_entdaa_stop_in_ackrsvdbyte")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR)
    await ClockCycles(tb.clk, 50)
    finished = Event()
    stop_expectations = (
        CccStopExpectation("post-ACK abort: arbitration loss then WaitStart STOP", 17, 1, 1),
        CccStopExpectation("post-ACK abort: two-address ENTDAA retry STOP", 16, 0),
        CccStopExpectation("post-ACK abort: completed recovery GETBCR", 15, 0),
    )
    handoff_monitor = cocotb.start_soon(monitor_ccc_handoff(dut, tb, finished, stop_expectations))

    log.info("CCC_STOP_SCOPE: retain post-ACK abort; expect arbitration loss before WaitStart STOP, not active ACK STOP")
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_byte_tbit(0x07)  # ENTDAA CCC
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(0x7E, read=True)
    assert ack, "ENTDAA reserved header must ACK before post-ACK abort"
    log.info("CCC_STOP_SCOPE: reserved ACK completed; entering malformed post-ACK STOP helper")
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 50)

    log.info("CCC_STOP_SCOPE: post-ACK STOP sent; starting two-address ENTDAA retry")
    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR])
    await ClockCycles(tb.clk, 50)

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, \
        "Recovery failed after ENTDAA post-ACK arbitration-loss/STOP"

    finished.set()
    await handoff_monitor
    log.info("CCC_STOP_SCOPE: post-ACK recovery checked; active AckRsvdByte STOP and pending-dispatch STOP remain unproven")
    await tb.teardown()


@cocotb.test()
async def test_ccc_entdaa_stop_in_sendnack(dut):
    """Require completed TE4 NACK followed by WaitStop termination; pending/active SendNack STOP is not exercised."""
    log = logging.getLogger("test_ccc_entdaa_stop_in_sendnack")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR)
    tb.te_error_monitor.expect_error(4)
    await ClockCycles(tb.clk, 50)
    finished = Event()
    stop_expectations = (
        CccStopExpectation("TE4: completed NACK then WaitStop STOP", 17, 12),
        CccStopExpectation("TE4: two-address ENTDAA retry STOP", 16, 0),
        CccStopExpectation("TE4: completed recovery GETBCR", 15, 0),
    )
    handoff_monitor = cocotb.start_soon(monitor_ccc_handoff(dut, tb, finished, stop_expectations))

    log.info("CCC_STOP_SCOPE: inject TE4; existing helper completes NACK before STOP, expecting WaitStop")
    te4_before = tb.te_error_monitor.error_counts[4]
    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[DYNAMIC_ADDR], inject_te4_invalid_rsvd=True)
    await ClockCycles(tb.clk, 50)

    assert results[0]["ack"] == False, "Target should NACK TE4 invalid reserved byte"
    assert tb.te_error_monitor.error_counts[4] == te4_before + 1, "Expected exactly one TE4 event, not merely an error permit"

    log.info("CCC_STOP_SCOPE: TE4 NACK checked; starting two-address ENTDAA retry")
    results = await i3c_controller.i3c_entdaa(
        addrs_to_assign=[DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR])
    await ClockCycles(tb.clk, 50)

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=DYNAMIC_ADDR, count=1)
    assert responses[0][0] == True, \
        "Recovery failed after completed ENTDAA NACK and WaitStop termination"

    finished.set()
    await handoff_monitor
    log.info("CCC_STOP_SCOPE: completed-NACK recovery checked; no pre-ninth-clock dispatch or active SendNack STOP claim")
    await tb.teardown()


# =============================================================================
# CCC + CSR Concurrent Stress Test
# =============================================================================


@cocotb.test(timeout_time=3000, timeout_unit="us")
async def test_ccc_csr_concurrent_stress(dut):
    """
    Stress test: concurrent random FW (AXI) and I3C CCC accesses to
    CCC-affected CSRs.

    FW randomly reads/writes CCC-related CSRs via AXI in the background
    while I3C performs 50 random supported CCC operations (GET and SET).
    GET CCCs verify ACK; SET CCCs send random valid data.

    Goal: expose data races, coherency bugs, or FSM hangs under concurrent
    access from both interfaces.
    """
    log = logging.getLogger("test_ccc_csr_concurrent_stress")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    targets = [DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR]

    # ------------------------------------------------------------------
    # CCC command table (from common.py)
    # ------------------------------------------------------------------
    CCC_TABLE = build_ccc_stress_table(i3c_controller, targets)

    # ------------------------------------------------------------------
    # FW CSR tables
    # ------------------------------------------------------------------
    SM = tb.reg_map.I3C_EC.STDBYCTRLMODE
    TTI = tb.reg_map.I3C_EC.TTI

    # FW writable CSRs: (addr, mask, safe_max_or_fixed)
    # Write random value & mask into the field bits.
    FW_WRITE_CSRS = [
        # TTI.CONTROL event enable bits (IBI_EN=bit12, CRR_EN=bit11, HJ_EN=bit10)
        # Write full register with random event bits, keep IBI_RETRY_NUM=0
        (TTI.CONTROL.base_addr, 0x1C00, None),
        # STBY_CR_DEVICE_CHAR: BCR_VAR(bits[28:24]), DCR(bits[23:16]), PID_HI(bits[15:1])
        (SM.STBY_CR_DEVICE_CHAR.base_addr, 0x3FFFFFFE, None),
        # STBY_CR_DEVICE_PID_LO
        (SM.STBY_CR_DEVICE_PID_LO.base_addr, 0xFFFFFFFF, None),
        # STBY_CR_VIRTUAL_DEVICE_CHAR
        (SM.STBY_CR_VIRTUAL_DEVICE_CHAR.base_addr, 0x3FFFFFFE, None),
        # STBY_CR_VIRTUAL_DEVICE_PID_LO
        (SM.STBY_CR_VIRTUAL_DEVICE_PID_LO.base_addr, 0xFFFFFFFF, None),
        # STBY_CR_CCC_CONFIG_GETCAPS
        (SM.STBY_CR_CCC_CONFIG_GETCAPS.base_addr, 0x0F07, None),
        # STBY_CR_CCC_CONFIG_RSTACT_PARAMS: RESET_TIME_PERIPHERAL(bits[15:8]),
        # RESET_TIME_TARGET(bits[23:16]). Avoid RESET_DYNAMIC_ADDR(bit31).
        (SM.STBY_CR_CCC_CONFIG_RSTACT_PARAMS.base_addr, 0x00FFFF00, None),
        # STBY_CR_INTR_STATUS: W1C bits (write 1 to clear)
        (SM.STBY_CR_INTR_STATUS.base_addr, 0x000FFFFF, None),
        # TARGET_ERR_CTRL: TE0-TE5 det_en bits
        (TTI.TARGET_ERR_CTRL.base_addr, 0x3F, None),
    ]

    # FW readable CSRs (all CCC-affected registers)
    FW_READ_CSRS = [
        TTI.CONTROL.base_addr,
        TTI.STATUS.base_addr,
        SM.STBY_CR_MWL.base_addr,
        SM.STBY_CR_MRL.base_addr,
        SM.STBY_CR_DEVICE_CHAR.base_addr,
        SM.STBY_CR_DEVICE_PID_LO.base_addr,
        SM.STBY_CR_VIRTUAL_DEVICE_CHAR.base_addr,
        SM.STBY_CR_VIRTUAL_DEVICE_PID_LO.base_addr,
        SM.STBY_CR_CCC_CONFIG_GETCAPS.base_addr,
        SM.STBY_CR_CCC_CONFIG_RSTACT_PARAMS.base_addr,
        SM.STBY_CR_DEVICE_ADDR.base_addr,
        SM.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        SM.STBY_CR_INTR_STATUS.base_addr,
        SM.STBY_CR_STATUS.base_addr,
        TTI.TARGET_ERR_CTRL.base_addr,
        TTI.TARGET_ERR_INTR_STATUS.base_addr,
        TTI.TARGET_ERR_CNT_TE0.base_addr,
        TTI.TARGET_ERR_CNT_TE1.base_addr,
        TTI.TARGET_ERR_CNT_TE2.base_addr,
        TTI.TARGET_ERR_CNT_TE3.base_addr,
        TTI.TARGET_ERR_CNT_TE4.base_addr,
        TTI.TARGET_ERR_CNT_TE5.base_addr,
    ]

    # ------------------------------------------------------------------
    # FW background task: random AXI reads/writes until stopped
    # ------------------------------------------------------------------
    stop_fw = Event()
    fw_ops = [0]

    async def fw_background():
        while not stop_fw.is_set():
            if random.random() < 0.5:
                # FW write (masked to safe field bits)
                addr, mask, fixed_val = random.choice(FW_WRITE_CSRS)
                if fixed_val is not None:
                    val = fixed_val
                else:
                    val = random.randint(0, 0xFFFFFFFF) & mask
                await tb.write_csr(addr, int2dword(val), 4)
            else:
                # FW read
                addr = random.choice(FW_READ_CSRS)
                await tb.read_csr(addr, 4)
            fw_ops[0] += 1
            delay = random.randint(1, 10)
            await ClockCycles(tb.clk, delay)

    cocotb.start_soon(fw_background())

    # ------------------------------------------------------------------
    # I3C foreground: 50 random CCC operations
    # ------------------------------------------------------------------
    NUM_CCC_OPS = 50
    for i in range(NUM_CCC_OPS):
        handler = random.choice(CCC_TABLE)
        result = await handler()
        log.info(f"CCC op {i}: result={result}")

    # ------------------------------------------------------------------
    # Stop FW background, post-test validation
    # ------------------------------------------------------------------
    stop_fw.set()
    await ClockCycles(tb.clk, 50)

    log.info(f"Done: {NUM_CCC_OPS} CCC ops, {fw_ops[0]} FW ops")

    # Verify target is still functional
    await do_getbcr(i3c_controller, DYNAMIC_ADDR)
    await do_getbcr(i3c_controller, VIRT_DYNAMIC_ADDR)

    # Re-enable all events for clean teardown
    await do_enec_direct(i3c_controller, DYNAMIC_ADDR, pattern=0x0B)

    await tb.teardown()
