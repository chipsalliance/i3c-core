# SPDX-License-Identifier: Apache-2.0

import random

from ccc import CCC, CccHandoff
from cocotb_helpers import cycle, reset_n

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer, with_timeout

_STATUS = 0xC64B


# Detect if we're running on Verilator (packed struct access) or VCS (hierarchical struct access)
def is_verilator():
    return cocotb.SIM_NAME.lower().startswith("verilator")


# Helper functions for struct access (works with both VCS and Verilator)
# bus_tx_rsp_t = {error[3], idle[2], abort[1], done[0]}
def set_bus_tx_rsp(dut, done=0, idle=0, error=0, abort=0):
    if is_verilator():
        dut.bus_tx_rsp_i.value = (error << 3) | (idle << 2) | (abort << 1) | done
    else:
        dut.bus_tx_rsp_i.error.value = error
        dut.bus_tx_rsp_i.idle.value = idle
        dut.bus_tx_rsp_i.abort.value = abort
        dut.bus_tx_rsp_i.done.value = done


# bus_rx_rsp_t = {idle[9], done[8], data[7:0]}
def set_bus_rx_rsp(dut, data=0, done=0, idle=0):
    if is_verilator():
        dut.bus_rx_rsp_i.value = (idle << 9) | (done << 8) | (data & 0xFF)
    else:
        dut.bus_rx_rsp_i.idle.value = idle
        dut.bus_rx_rsp_i.done.value = done
        dut.bus_rx_rsp_i.data.value = data & 0xFF


# bus_rx_req_t = {req_byte[1], req_bit[0]}
def get_rx_req_bit(dut):
    if is_verilator():
        return int(dut.bus_rx_req_o.value) & 0x1
    else:
        return int(dut.bus_rx_req_o.req_bit.value)


def get_rx_req_byte(dut):
    if is_verilator():
        return (int(dut.bus_rx_req_o.value) >> 1) & 0x1
    else:
        return int(dut.bus_rx_req_o.req_byte.value)


# bus_tx_req_t = {req_valid[12], req_type[11:9], drive_type[8], data[7:0]}
def get_tx_req_valid(dut):
    if is_verilator():
        return (int(dut.bus_tx_req_o.value) >> 12) & 0x1
    else:
        return int(dut.bus_tx_req_o.req_valid.value)


def get_tx_req_type(dut):
    if is_verilator():
        return (int(dut.bus_tx_req_o.value) >> 9) & 0x7
    else:
        return int(dut.bus_tx_req_o.req_type.value)


def get_tx_req_data(dut):
    if is_verilator():
        return int(dut.bus_tx_req_o.value) & 0xFF
    else:
        return int(dut.bus_tx_req_o.data.value)


def initialize_inputs(dut):
    dut.ccc_data_i.value = 0
    dut.ccc_valid_i.value = 0
    dut.bus_start_det_i.value = 0
    dut.bus_rstart_det_i.value = 0
    dut.bus_stop_det_i.value = 0
    dut.scl_negedge_i.value = 0
    dut.arbitration_lost_i.value = 0
    dut.te0_err_i.value = 0
    for name in ("te0_err_det_en_i", "te1_err_det_en_i", "te2_err_det_en_i", "te3_err_det_en_i", "te4_err_det_en_i", "te5_err_det_en_i", "framing_err_det_en_i"):
        getattr(dut, name).value = 1
    
    # Bus TX/RX response - use helper for simulator compatibility
    set_bus_tx_rsp(dut, done=0, idle=0, error=0)
    set_bus_rx_rsp(dut, data=0, done=0, idle=0)
    
    dut.target_sta_address_i.value = 0
    dut.target_sta_address_valid_i.value = 0
    dut.target_dyn_address_i.value = 0
    dut.target_dyn_address_valid_i.value = 0
    dut.virtual_target_sta_address_i.value = 0
    dut.virtual_target_sta_address_valid_i.value = 0
    dut.virtual_target_dyn_address_i.value = 0
    dut.virtual_target_dyn_address_valid_i.value = 0
    dut.get_mwl_i.value = 0
    dut.get_mrl_i.value = 0
    dut.get_ibil_i.value = 0
    dut.get_pid_i.value = 0
    dut.get_bcr_i.value = 0
    dut.get_dcr_i.value = 0
    dut.virtual_get_pid_i.value = 0
    dut.virtual_get_bcr_i.value = 0
    dut.virtual_get_dcr_i.value = 0
    dut.get_status_fmt1_i.value = 0
    dut.get_acccr_i.value = 0
    dut.get_mxds_i.value = 0
    dut.target_reset_detect_i.value = 0
    dut.peripheral_reset_done_i.value = 0
    dut.exit_hdr_i.value = 0


async def setup(dut):
    """
    Initialize inputs of the DUT
    """
    dut.get_mwl_i.value = random.randint(0, 2**16 - 1)
    dut.get_mrl_i.value = random.randint(0, 2**16 - 1)
    dut.get_pid_i.value = random.randint(0, 2**48 - 1)
    dut.get_bcr_i.value = random.randint(0, 2**8 - 1)
    dut.get_dcr_i.value = random.randint(0, 2**8 - 1)
    dut.get_status_fmt1_i.value = _STATUS

    dut.target_sta_address_i.value = 0x2D
    dut.target_sta_address_valid_i.value = 1
    dut.target_dyn_address_i.value = 0x2D  # Use same as static for matching
    dut.target_dyn_address_valid_i.value = 1

    await ClockCycles(dut.clk_i, 10)


async def rx_bit(dut, value):
    """
    Send bit on the RX interface
    bus_rx_rsp_t = {idle, done, data[7:0]}
    """
    # Wait for req_bit to go high
    while not get_rx_req_bit(dut):
        await RisingEdge(dut.clk_i)
    await ClockCycles(dut.clk_i, 3)
    set_bus_rx_rsp(dut, data=value & 0xFF, done=1)
    await ClockCycles(dut.clk_i, 1)
    set_bus_rx_rsp(dut, data=0, done=0)


async def rx_byte(dut, value):
    """
    Send byte on the RX interface
    bus_rx_rsp_t = {idle, done, data[7:0]}
    """
    # Wait for req_byte to go high
    while not get_rx_req_byte(dut):
        await RisingEdge(dut.clk_i)
    await ClockCycles(dut.clk_i, 3)
    set_bus_rx_rsp(dut, data=value & 0xFF, done=1)
    await ClockCycles(dut.clk_i, 1)
    set_bus_rx_rsp(dut, data=0, done=0)


async def tx_bit(dut):
    """
    bus_tx_rsp_t = {error, idle, done}
    bus_tx_req_t = {drive_type, req_byte, req_bit, data[7:0]}
    """
    # Wait for a RawBit request to be sent
    while not (get_tx_req_valid(dut) and (get_tx_req_type(dut) == 1)):
        await RisingEdge(dut.clk_i)
    val = get_tx_req_data(dut)  # Get the data from the request
    await ClockCycles(dut.clk_i, 3)
    set_bus_tx_rsp(dut, done=1)
    await ClockCycles(dut.clk_i, 1)
    set_bus_tx_rsp(dut, done=0)
    return val & 0xFF


async def tx_byte(dut):
    """
    bus_tx_rsp_t = {error, idle, done}
    bus_tx_req_t = {drive_type, req_byte, req_bit, data[7:0]}
    """
    # Wait for RawByte request to be sent
    while not (get_tx_req_valid(dut) and (get_tx_req_type(dut) == 0)):
        await RisingEdge(dut.clk_i)
    val = get_tx_req_data(dut)  # Get the data from the request
    await ClockCycles(dut.clk_i, 10)
    set_bus_tx_rsp(dut, done=1)
    await ClockCycles(dut.clk_i, 1)
    set_bus_tx_rsp(dut, done=0)
    return val & 0xFF

async def tx_tread_end(dut):
    """
    bus_tx_rsp_t = {error, idle, done}
    bus_tx_req_t = {drive_type, req_byte, req_bit, data[7:0]}
    """
    # Wait for a RawBit request to be sent
    while not (get_tx_req_valid(dut) and (get_tx_req_type(dut) == 7)):
        await RisingEdge(dut.clk_i)
    await ClockCycles(dut.clk_i, 3)
    set_bus_tx_rsp(dut, done=1)
    await ClockCycles(dut.clk_i, 1)
    set_bus_tx_rsp(dut, done=0)

async def tx_tread_cont(dut):
    """
    bus_tx_rsp_t = {error, idle, done}
    bus_tx_req_t = {drive_type, req_byte, req_bit, data[7:0]}
    """
    # Wait for a RawBit request to be sent
    while not (get_tx_req_valid(dut) and (get_tx_req_type(dut) == 6)):
        await RisingEdge(dut.clk_i)
    val = get_tx_req_data(dut)  # Get the data from the request
    await ClockCycles(dut.clk_i, 3)
    set_bus_tx_rsp(dut, done=1)
    await ClockCycles(dut.clk_i, 1)
    set_bus_tx_rsp(dut, done=0)
    return val & 0xFF

async def get_status(dut):
    # CCC - set command code and valid
    await ClockCycles(dut.clk_i, 7)
    dut.ccc_data_i.value = CCC.DIRECT.GETSTATUS
    await cycle(dut.clk_i, dut.ccc_valid_i)

    # T-bit (odd parity of command code)
    cmd_parity = bin(CCC.DIRECT.GETSTATUS).count('1') % 2
    tbit_value = 1 - cmd_parity  # Odd parity: if odd 1s, T=0; if even 1s, T=1
    await rx_bit(dut, tbit_value)

    # RS
    await ClockCycles(dut.clk_i, 5)
    await cycle(dut.clk_i, dut.bus_rstart_det_i)

    # Target Address (0x2D with R bit = 0x5B for read)
    await rx_byte(dut, 0x5B)

    # ACK
    await tx_bit(dut)

    # TX Bytes (GETSTATUS returns 2 bytes)
    status = []
    r = range(2)
    for i in r:
        byte_val = await tx_byte(dut)
        status.append(byte_val)
        # T-bit
        if i == r[-1]:
            await tx_tread_end(dut)
        else:
            await tx_tread_cont(dut)

    # Stop the frame
    await cycle(dut.clk_i, dut.bus_stop_det_i)
    await ClockCycles(dut.clk_i, 5)

    return status


@cocotb.test()
async def test_ccc(dut: SimHandleBase):
    """
    Test CCC
    """
    cocotb.log.setLevel("INFO")
    clk = dut.clk_i
    rst_n = dut.rst_ni

    clock = Clock(clk, 2, units="ns")
    cocotb.start_soon(clock.start())

    initialize_inputs(dut)
    await setup(dut)
    await reset_n(clk, rst_n, cycles=5)

    status = await with_timeout(get_status(dut), 200, "ns")
    _status = (int(status[0]) << 8) | int(status[1])
    print(f"Test returned {hex(_status)}, expected {hex(_STATUS)}")
    assert _status == _STATUS


async def ccc_tick(dut, rx_done=0, data=0, tx_done=0, abort=0, sr=0, stop=0, **inputs):
    await FallingEdge(dut.clk_i)
    set_bus_rx_rsp(dut, data=data, done=rx_done)
    set_bus_tx_rsp(dut, done=tx_done, abort=abort)
    dut.bus_rstart_det_i.value = sr
    dut.bus_stop_det_i.value = stop
    for name, value in inputs.items():
        getattr(dut, name).value = value
    await Timer(1, "ps")
    observed = {name: int(getattr(dut, name).value) for name in (
        "handoff_o", "get_status_done_o",
        "capture_defining_byte", "capture_rx_data", "rx_data_valid",
        "cmd_tbit_valid", "def_byte_tbit_valid", "target_addr_ack_done",
        "enter_hdr_mode", "te0_err_o", "te1_err_o",
        "te2_err_ccc_o", "set_dasa_valid_o", "set_newda_o", "set_aasa_o", "set_aasa_virt_o",
    )}
    observed["tx_data"] = get_tx_req_data(dut)
    observed["rx_req_byte"] = get_rx_req_byte(dut)
    if stop:
        assert not get_tx_req_valid(dut)
        assert observed["handoff_o"] in (CccHandoff.NONE, CccHandoff.DONE)
    if observed["handoff_o"] == CccHandoff.RESUME_ADDR:
        assert sr and not stop
        assert not get_rx_req_byte(dut) and not get_rx_req_bit(dut) and not get_tx_req_valid(dut)
    if observed["handoff_o"] == CccHandoff.NEXT_CMD:
        assert tx_done and not stop
        assert get_tx_req_valid(dut) and get_tx_req_type(dut) == 4, "Handoff cancelled the terminating ACK"
    await RisingEdge(dut.clk_i)
    await Timer(1, "ps")
    if observed["handoff_o"] != CccHandoff.NONE:
        assert not get_rx_req_byte(dut) and not get_rx_req_bit(dut) and not get_tx_req_valid(dut), "CCC retained a request after handoff"
    return observed


async def ccc_block_setup(dut):
    initialize_inputs(dut)
    dut.rst_ni.value = 0
    cocotb.start_soon(Clock(dut.clk_i, 2, units="ns").start())
    dut.target_dyn_address_i.value = 0x2D
    dut.target_dyn_address_valid_i.value = 1
    dut.virtual_target_dyn_address_i.value = 0x35
    dut.virtual_target_dyn_address_valid_i.value = 1
    dut.get_status_fmt1_i.value = _STATUS
    dut.get_mrl_i.value = 0x1234
    dut.get_ibil_i.value = 0x56
    await reset_n(dut.clk_i, dut.rst_ni, cycles=5)


async def ccc_command(dut, command, defining_byte=None):
    await ccc_tick(dut, ccc_valid_i=1, ccc_data_i=command)
    await ccc_tick(dut)
    await ccc_tick(dut, rx_done=1, data=1 ^ (int(command).bit_count() & 1))
    await ccc_tick(dut)
    if defining_byte is not None:
        await ccc_payload(dut, defining_byte)


async def ccc_payload(dut, byte):
    assert get_rx_req_byte(dut), "CCC did not request the expected payload byte"
    await ccc_tick(dut, rx_done=1, data=byte)
    assert get_rx_req_bit(dut), "CCC did not request the payload T-bit"
    observed = await ccc_tick(dut, rx_done=1, data=1 ^ (byte.bit_count() & 1))
    await ccc_tick(dut)
    return observed


async def ccc_address(dut, address, read=False, *, complete_ack=True):
    observed = await ccc_tick(dut, sr=1)
    assert observed["rx_req_byte"] == 0, "Sr must cancel the previous RX request before address reception"
    await ccc_tick(dut)
    assert get_rx_req_byte(dut), "CCC did not request a directed address"
    await ccc_tick(dut, rx_done=1, data=(address << 1) | read)
    ack = not (get_tx_req_data(dut) & 0x80)
    if complete_ack:
        await ccc_tick(dut, tx_done=1)
    return ack


async def ccc_response(dut, count, status=False):
    response = []
    for index in range(count):
        assert get_tx_req_valid(dut) and get_tx_req_type(dut) == 0
        observed = await ccc_tick(dut, tx_done=1)
        response.append(observed["tx_data"])
        assert not observed["get_status_done_o"]
        assert get_tx_req_type(dut) == (7 if index == count - 1 else 6)
        observed = await ccc_tick(dut, tx_done=1)
        assert observed["get_status_done_o"] == int(status and index == count - 1)
    observed = await ccc_tick(dut)
    assert not observed["get_status_done_o"]
    return response


@cocotb.test(timeout_time=100, timeout_unit="us")
async def test_ccc_ending_contract(dut):
    await ccc_block_setup(dut)
    for direct in (False, True):
        for phase in ("command", "def_byte", "def_tbit", "data", "data_tbit", "data_tbit_valid", "complete"):
            await ccc_tick(dut, ccc_valid_i=0)
            await reset_n(dut.clk_i, dut.rst_ni, cycles=5)
            rstact = phase.startswith("def")
            command = (CCC.DIRECT.RSTACT if direct else CCC.BCAST.RSTACT) if rstact else (CCC.DIRECT.SETMWL if direct else CCC.BCAST.SETMWL)
            if phase == "command":
                await ccc_tick(dut, ccc_valid_i=1, ccc_data_i=command)
            else:
                await ccc_command(dut, command)
                if phase == "def_tbit":
                    await ccc_tick(dut, rx_done=1, data=1)
                elif not rstact:
                    if direct:
                        assert await ccc_address(dut, 0x2D)
                    if phase == "data_tbit_valid":
                        # Prime the high byte so a valid low byte would change MWL and assert set_mwl_o.
                        await ccc_payload(dut, 0x34)
                    if phase in ("data_tbit", "data_tbit_valid"):
                        await ccc_tick(dut, rx_done=1, data=0x12)
                    elif phase == "complete":
                        await ccc_payload(dut, 0x12)
                        await ccc_payload(dut, 0x34)
            if phase == "data_tbit_valid":
                assert get_rx_req_bit(dut), f"{direct=}: Valid-parity STOP case did not reach the payload T-bit"
                mwl_before_stop = int(dut.mwl_o.value)
                assert mwl_before_stop == 0x3400, f"{direct=}: Valid-parity STOP case did not prime MWL"
                dut._log.info("CCC_ENDING: direct=%s, STOP with final data=0x12/T=1; MWL=0x%04X must not commit 0x3412", direct, mwl_before_stop)
            # Byte 0x12 has two set bits: T=1 is correct odd parity; retain the original T=0 cases.
            observed = await ccc_tick(dut, stop=1, rx_done=1, data=int(phase == "data_tbit_valid"))
            for signal in ("capture_defining_byte", "capture_rx_data", "rx_data_valid", "cmd_tbit_valid", "def_byte_tbit_valid"):
                assert observed[signal] == 0, f"{direct=}, {phase=}: STOP allowed {signal}"
            assert observed["handoff_o"] == CccHandoff.DONE
            assert int(dut.command_code_valid.value) == 0
            assert int(dut.defining_byte_valid.value) == 0
            if phase == "data_tbit_valid":
                assert int(dut.mwl_o.value) == mwl_before_stop, f"{direct=}: STOP committed valid-parity payload data"
                assert int(dut.set_mwl_o.value) == 0, f"{direct=}: STOP asserted the MWL update strobe"
            observed = await ccc_tick(dut, ccc_valid_i=0)
            assert observed["handoff_o"] == CccHandoff.NONE
            if phase == "data_tbit_valid":
                assert int(dut.mwl_o.value) == mwl_before_stop, f"{direct=}: Valid-parity STOP caused a delayed MWL commit"
                assert int(dut.set_mwl_o.value) == 0, f"{direct=}: Valid-parity STOP caused a delayed MWL update strobe"
                dut._log.info("CCC_ENDING: direct=%s, valid-parity STOP checked; MWL preserved and no immediate or delayed update strobe", direct)

        await ccc_command(dut, CCC.DIRECT.SETMWL if direct else CCC.BCAST.SETMWL)
        if direct:
            assert await ccc_address(dut, 0x2D)
        await ccc_payload(dut, 0x12)
        await ccc_payload(dut, 0x34)
        observed = await ccc_tick(dut, sr=1)
        assert observed["handoff_o"] == (CccHandoff.NONE if direct else CccHandoff.RESUME_ADDR)
        await ccc_tick(dut, ccc_valid_i=int(direct))
        if direct:
            await ccc_tick(dut, rx_done=1, data=0x6A)
            assert get_tx_req_valid(dut), "A directed segment lost its command context"
            await ccc_tick(dut, stop=1)
            await ccc_tick(dut, ccc_valid_i=0)
        assert int(dut.command_code_valid.value) == 0

        for defining_byte in (False, True):
            command = (CCC.DIRECT.RSTACT if direct else CCC.BCAST.RSTACT) if defining_byte else (CCC.DIRECT.SETMWL if direct else CCC.BCAST.SETMWL)
            await ccc_command(dut, command)
            if direct and not defining_byte:
                assert await ccc_address(dut, 0x2D)
            await ccc_tick(dut, rx_done=1, data=1)
            observed = await ccc_tick(dut, rx_done=1, data=1)  # Incorrect parity for 0x01.
            assert observed["te2_err_ccc_o"] == 1, "Bad parity did not produce a TE2 event"
            assert not observed["def_byte_tbit_valid"] and not observed["rx_data_valid"], "TE2 committed the corrupt field"
            fields = ("mwl_o", "mrl_o", "ibil_o", "rstact_armed_q", "rst_action_o", "vt_detect_flag_q")
            baseline = tuple(int(getattr(dut, name).value) for name in fields)
            for sr in (0, 1, 0):
                observed = await ccc_tick(dut, sr=sr, rx_done=1, data=0xFC)
                assert observed["handoff_o"] == CccHandoff.NONE
                assert not get_rx_req_byte(dut) and not get_rx_req_bit(dut) and not get_tx_req_valid(dut)
                for signal in ("capture_defining_byte", "capture_rx_data", "rx_data_valid", "def_byte_tbit_valid",
                               "target_addr_ack_done", "set_dasa_valid_o", "set_newda_o", "set_aasa_o", "set_aasa_virt_o"):
                    assert observed[signal] == 0, f"TE2 quiescence allowed {signal}"
                assert observed["te2_err_ccc_o"] == 0, "Ignored traffic generated another TE2"
                assert tuple(int(getattr(dut, name).value) for name in fields) == baseline, "TE2 quiescent state changed"
            await ccc_tick(dut, stop=1)
            await ccc_tick(dut, ccc_valid_i=0)
            assert int(dut.command_code_valid.value) == 0


@cocotb.test(timeout_time=100, timeout_unit="us")
async def test_ccc_mrl_capability_snapshot(dut):
    await ccc_block_setup(dut)
    for main_ibi, virtual_ibi in ((0, 0), (1, 0), (0, 1), (1, 1)):
        for address in (None, 0x2D, 0x35):
            await ccc_tick(dut, ccc_valid_i=0)
            await reset_n(dut.clk_i, dut.rst_ni, cycles=5)
            await ccc_tick(dut, get_bcr_i=main_ibi << 2, virtual_get_bcr_i=virtual_ibi << 2)
            expected_ibi = (main_ibi or virtual_ibi) if address is None else (virtual_ibi if address == 0x35 else main_ibi)
            await ccc_command(dut, CCC.BCAST.SETMRL if address is None else CCC.DIRECT.SETMRL)
            if address is not None:
                assert await ccc_address(dut, address)
            assert int(dut.mrl_has_ibi_q.value) == expected_ibi
            await ccc_tick(dut, get_bcr_i=(1 - main_ibi) << 2, virtual_get_bcr_i=(1 - virtual_ibi) << 2)
            await ccc_payload(dut, 0x12)
            await ccc_payload(dut, 0x34)
            assert int(dut.mrl_o.value) == 0x1234
            assert bool(get_rx_req_byte(dut)) == bool(expected_ibi)
            if expected_ibi:
                await ccc_payload(dut, 0x56)
            else:
                await ccc_tick(dut, rx_done=1, data=0x56)
                await ccc_tick(dut, rx_done=1, data=1)
            assert int(dut.ibil_o.value) == (0x56 if expected_ibi else 0xFF)
            await ccc_tick(dut, stop=1)
            await ccc_tick(dut, ccc_valid_i=0)

            await ccc_command(dut, CCC.DIRECT.GETMRL)
            for target, capability in ((0x2D, 1 - main_ibi), (0x35, 1 - virtual_ibi)):
                assert await ccc_address(dut, target, read=True)
                await ccc_tick(dut, get_bcr_i=main_ibi << 2, virtual_get_bcr_i=virtual_ibi << 2)
                expected = [0x12, 0x34] + ([0 if target == 0x35 else 0x56] if capability else [])
                assert await ccc_response(dut, len(expected)) == expected
                await ccc_tick(dut, get_bcr_i=(1 - main_ibi) << 2, virtual_get_bcr_i=(1 - virtual_ibi) << 2)
            await ccc_tick(dut, stop=1)
            await ccc_tick(dut, ccc_valid_i=0)


@cocotb.test(timeout_time=100, timeout_unit="us")
async def test_ccc_rstact_target_ack(dut):
    await ccc_block_setup(dut)
    for defining_byte in (1, 4, 0x7F):
        for address, read in ((None, False), (0x44, False), (0x2D, False), (0x35, False), (0x2D, True)):
            await ccc_tick(dut, ccc_valid_i=0)
            await reset_n(dut.clk_i, dut.rst_ni, cycles=5)
            await ccc_command(dut, CCC.DIRECT.RSTACT, defining_byte)
            supported = defining_byte != 0x7F and address in (0x2D, 0x35)
            if address is not None:
                assert await ccc_address(dut, address, read) == supported
                if supported and read:
                    await ccc_response(dut, 1)
            armed = int(supported and not read and defining_byte == 1)
            vt_flag = int(supported and not read and defining_byte == 4)
            assert int(dut.rstact_armed_q.value) == armed
            assert int(dut.vt_detect_flag_q.value) == vt_flag
            assert await ccc_address(dut, 0x7E, complete_ack=False)
            observed = await ccc_tick(dut, tx_done=1)
            assert observed["handoff_o"] == CccHandoff.NEXT_CMD
            assert int(dut.command_code_valid.value) == 0
            assert int(dut.defining_byte_valid.value) == 0
            assert int(dut.rstact_armed_q.value) == armed
            assert int(dut.vt_detect_flag_q.value) == vt_flag
            await ccc_tick(dut, ccc_valid_i=0)


@cocotb.test(timeout_time=100, timeout_unit="us")
async def test_ccc_getstatus_segment_completion(dut):
    await ccc_block_setup(dut)
    await ccc_command(dut, CCC.DIRECT.GETSTATUS)
    for address in (0x2D, 0x35):
        assert await ccc_address(dut, address, read=True)
        await ccc_response(dut, 2, status=True)
    assert await ccc_address(dut, 0x7E, complete_ack=False)
    observed = await ccc_tick(dut, tx_done=1)
    assert observed["handoff_o"] == CccHandoff.NEXT_CMD and not observed["get_status_done_o"]
    await ccc_tick(dut, ccc_valid_i=0)

    for simultaneous_sr in (False, True):
        await ccc_command(dut, CCC.DIRECT.GETSTATUS)
        assert await ccc_address(dut, 0x2D, read=True)
        observed = await ccc_tick(dut, tx_done=1)
        assert not observed["get_status_done_o"]
        observed = await ccc_tick(dut, abort=1, sr=int(simultaneous_sr))
        assert not observed["get_status_done_o"]
        if not simultaneous_sr:
            await ccc_tick(dut, sr=1)
        await ccc_tick(dut)
        await ccc_tick(dut, rx_done=1, data=0xFC)
        assert get_tx_req_valid(dut), "Read-abort Sr was mistaken for an incomplete address"
        observed = await ccc_tick(dut, tx_done=1)
        assert observed["handoff_o"] == CccHandoff.NEXT_CMD and not observed["get_status_done_o"]
        await ccc_tick(dut, ccc_valid_i=0)

    # Interface-injected collision: STOP must suppress final-T-bit success.
    for stop in (0, 1):
        dut._log.info(f"CCC_STATUS: final T-bit completion with simultaneous STOP={stop}")
        await ccc_command(dut, CCC.DIRECT.GETSTATUS)
        assert await ccc_address(dut, 0x2D, read=True)
        await ccc_tick(dut, tx_done=1)
        assert get_tx_req_type(dut) == 6
        await ccc_tick(dut, tx_done=1)
        await ccc_tick(dut, tx_done=1)
        assert get_tx_req_type(dut) == 7
        observed = await ccc_tick(dut, tx_done=1, stop=stop)
        assert observed["get_status_done_o"] == 1 - stop, "STOP/final-T-bit success priority violated"
        observed = await ccc_tick(dut, stop=1)
        assert not observed["get_status_done_o"], "STOP emitted a second GETSTATUS completion"
        await ccc_tick(dut, ccc_valid_i=0)


@cocotb.test(timeout_time=100, timeout_unit="us")
async def test_ccc_rstact_consumption(dut):
    """Check local NO_RESET consumption separately from top-level pattern detection."""
    await ccc_block_setup(dut)
    results = []
    for direct in (False, True):
        for stop_first in (False, True):
            dut._log.info(f"C16_BLOCK: starting direct={direct}, stop_first={stop_first}; arming NO_RESET")
            await ccc_tick(dut, ccc_valid_i=0)
            await reset_n(dut.clk_i, dut.rst_ni, cycles=5)
            command = CCC.DIRECT.RSTACT if direct else CCC.BCAST.RSTACT
            await ccc_command(dut, command, 0)
            if direct:
                assert await ccc_address(dut, 0x2D)
            if stop_first:
                await ccc_tick(dut, stop=1)
                await ccc_tick(dut, ccc_valid_i=0)
            boundary = await ccc_tick(dut, sr=int(not stop_first), bus_start_det_i=int(stop_first))
            if boundary["handoff_o"] != CccHandoff.NONE:
                # Retire producer valid after the sampled ownership-return edge.
                dut.ccc_valid_i.value = 0
                dut._log.info(f"C16_BLOCK: handoff consumed; producer valid dropped, direct={direct}, stop_first={stop_first}")
            await ccc_tick(dut, bus_start_det_i=0)
            pre = (int(dut.rstact_armed_q.value), int(dut.rst_action_o.value))
            dut._log.info(f"C16_BLOCK: applying C16-P1 detection, direct={direct}, stop_first={stop_first}, pre={pre}")
            await ccc_tick(dut, stop=1, target_reset_detect_i=1)
            p1 = pre == (1, 0) and (int(dut.peripheral_reset_o.value), int(dut.escalated_reset_o.value)) == (0, 0)
            retired = (int(dut.rstact_armed_q.value), int(dut.rst_action_o.value))
            dut._log.info(f"C16_BLOCK: captured C16-P1={p1}, C16-S state={retired}; proceeding unconditionally to C16-P2")
            await ccc_tick(dut, target_reset_detect_i=0, ccc_valid_i=0)
            # No normal START/SCL falling, rearm, or reset between detections.
            await ccc_tick(dut, bus_start_det_i=1)
            await ccc_tick(dut, bus_start_det_i=0)
            await ccc_tick(dut, stop=1, target_reset_detect_i=1)
            outputs = (int(dut.peripheral_reset_o.value), int(dut.escalated_reset_o.value))
            checks = (p1, retired == (0, 0), outputs == (1, 0))
            dut._log.info(f"C16 block: {direct=}, {stop_first=}, C16-P1={checks[0]} pre={pre}, "
                          f"C16-S={checks[1]} retired={retired}, C16-P2={checks[2]} outputs={outputs}")
            results.append((direct, stop_first, checks))
            await ccc_tick(dut, target_reset_detect_i=0, peripheral_reset_done_i=1)
            await ccc_tick(dut, peripheral_reset_done_i=0)

    assert all(all(checks) for _, _, checks in results), f"RSTACT consumption failed: {results}"


@cocotb.test(timeout_time=100, timeout_unit="us")
async def test_ccc_rstact_consumption_requests(dut):
    """Retirement must preserve the consumed request, VT flag and default escalation."""
    await ccc_block_setup(dut)
    for action in (1, 2):
        for address in (None, 0x2D, 0x35):
            for done_at_detection in (0, 1):
                dut._log.info(f"RSTACT consumption: {action=}, {address=}, {done_at_detection=}")
                await ccc_tick(dut, ccc_valid_i=0, target_reset_detect_i=0, peripheral_reset_done_i=0)
                await reset_n(dut.clk_i, dut.rst_ni, cycles=5)
                await ccc_command(dut, CCC.DIRECT.RSTACT, 4)
                assert await ccc_address(dut, 0x35)
                await ccc_tick(dut, stop=1)
                await ccc_tick(dut, ccc_valid_i=0)
                command = CCC.BCAST.RSTACT if address is None else CCC.DIRECT.RSTACT
                await ccc_command(dut, command, action)
                if address is not None:
                    assert await ccc_address(dut, address)
                assert int(dut.rstact_armed_q.value) == 1 and int(dut.rst_action_o.value) == action
                assert int(dut.vt_detect_flag_q.value) == 1

                await ccc_tick(dut, stop=1, target_reset_detect_i=1, peripheral_reset_done_i=done_at_detection)
                assert int(dut.rstact_armed_q.value) == 0 and int(dut.rst_action_o.value) == 0
                assert int(dut.rst_action_valid_o.value) == 0
                assert int(dut.escalate_rst_arm_q.value) == 0, "Configured reset must not arm default escalation"
                expected = (int(action == 1), int(action == 2))
                assert (int(dut.peripheral_reset_o.value), int(dut.escalated_reset_o.value)) == expected, "Retirement lost the configured request"
                for _ in range(4):
                    await ccc_tick(dut, ccc_valid_i=0, target_reset_detect_i=0, peripheral_reset_done_i=0)
                    assert (int(dut.peripheral_reset_o.value), int(dut.escalated_reset_o.value)) == expected
                    assert int(dut.vt_detect_flag_q.value) == 1
                await ccc_tick(dut, peripheral_reset_done_i=1)
                assert int(dut.peripheral_reset_o.value) == 0
                assert int(dut.escalated_reset_o.value) == expected[1], "Peripheral acknowledgement cleared a whole-target request"
                await ccc_tick(dut, peripheral_reset_done_i=0)

                # No core reset, normal START or CCC separates the raw detections.
                await ccc_tick(dut, target_reset_detect_i=1)
                assert int(dut.peripheral_reset_o.value) == 1, "The consumed action was reused instead of the default"
                assert int(dut.escalated_reset_o.value) == expected[1]
                assert int(dut.escalate_rst_arm_q.value) == 1
                await ccc_tick(dut, target_reset_detect_i=0, peripheral_reset_done_i=1)
                assert int(dut.peripheral_reset_o.value) == 0
                await ccc_tick(dut, target_reset_detect_i=1, peripheral_reset_done_i=0)
                assert int(dut.peripheral_reset_o.value) == 0 and int(dut.escalated_reset_o.value) == 1
                assert int(dut.escalate_rst_arm_q.value) == 1 and int(dut.vt_detect_flag_q.value) == 1
                await ccc_tick(dut, target_reset_detect_i=0)


@cocotb.test(timeout_time=100, timeout_unit="us")
async def test_ccc_complete_handoff(dut):
    await ccc_block_setup(dut)
    for stop_override in (False, True):
        for ending in ("broadcast_sr", "rstact_sr", "stop", "next_command", "command_error", "hdr", "te0"):
            expected = CccHandoff.DONE
            event = {"stop": int(stop_override)}
            if ending in ("command_error", "hdr"):
                command = CCC.BCAST.ENEC if ending == "command_error" else CCC.BCAST.ENTHDR0
                await ccc_tick(dut, ccc_valid_i=1, ccc_data_i=command)
                await ccc_tick(dut)
                parity = 1 ^ (int(command).bit_count() & 1)
                event.update(rx_done=1, data=parity ^ int(ending == "command_error"))
            elif ending in ("next_command", "te0"):
                await ccc_command(dut, CCC.DIRECT.GETBCR)
                assert await ccc_address(dut, 0x7E, read=(ending == "te0"), complete_ack=False) == (ending == "next_command")
                for _ in range(3):
                    observed = await ccc_tick(dut)
                    assert observed["handoff_o"] == CccHandoff.NONE, "CCC released before the terminating ACK completed"
                    assert get_tx_req_valid(dut)
                event["tx_done"] = 1
                if ending == "next_command":
                    expected = CccHandoff.NEXT_CMD
            elif ending == "rstact_sr":
                await ccc_command(dut, CCC.BCAST.RSTACT, 1)
                assert int(dut.rstact_armed_q.value) == 1
                assert not get_rx_req_byte(dut) and not get_rx_req_bit(dut)
                event["sr"] = 1
                expected = CccHandoff.RESUME_ADDR
            else:
                await ccc_command(dut, CCC.BCAST.SETMWL)
                await ccc_payload(dut, 0x12)
                await ccc_payload(dut, 0x34)
                if ending == "broadcast_sr":
                    event["sr"] = 1
                    expected = CccHandoff.RESUME_ADDR
                else:
                    event["stop"] = 1

            assert int(dut.command_code_valid.value) == 1
            assert int(dut.ccc_valid_i.value) == 1
            release = await ccc_tick(dut, **event)
            assert release["handoff_o"] == (CccHandoff.DONE if stop_override else expected), f"{ending=}, {stop_override=}"
            if stop_override:
                for signal in ("cmd_tbit_valid", "target_addr_ack_done", "enter_hdr_mode", "te0_err_o", "te1_err_o"):
                    assert not release[signal], f"STOP did not suppress {signal}"
            assert int(dut.command_code_valid.value) == 0
            assert int(dut.defining_byte_valid.value) == 0
            assert int(dut.state_q.value) == 0, "Completion did not return directly to WaitCCC"
            if ending == "rstact_sr":
                assert int(dut.rstact_armed_q.value) == 1
                assert int(dut.rst_action_o.value) == 1
            for _ in range(3):
                observed = await ccc_tick(dut, ccc_valid_i=0, exit_hdr_i=1)
                assert observed["handoff_o"] == CccHandoff.NONE, "Completion emitted more than one handoff"
            await ccc_tick(dut, exit_hdr_i=0)

    # Unowned bus events must not generate a CCC completion.
    for stop, sr in ((1, 0), (0, 1), (1, 1)):
        observed = await ccc_tick(dut, stop=stop, sr=sr, rx_done=1, tx_done=1)
        assert observed["handoff_o"] == CccHandoff.NONE
        assert int(dut.state_q.value) == 0

    # STOP also wins when the parent is just handing over a new command.
    observed = await ccc_tick(dut, ccc_valid_i=1, ccc_data_i=CCC.BCAST.SETMWL, stop=1)
    assert observed["handoff_o"] == CccHandoff.DONE
    assert int(dut.command_code_valid.value) == 0
    observed = await ccc_tick(dut, ccc_valid_i=0, stop=1)
    assert observed["handoff_o"] == CccHandoff.NONE

    await ccc_command(dut, CCC.BCAST.SETMWL)
    await ccc_payload(dut, 0x12)
    await ccc_payload(dut, 0x34)
    observed = await ccc_tick(dut, rst_ni=0, ccc_valid_i=0, sr=1)
    assert observed["handoff_o"] == CccHandoff.NONE
    observed = await ccc_tick(dut, rst_ni=1)
    assert observed["handoff_o"] == CccHandoff.NONE


async def read_bcr(dut):
    await ccc_command(dut, CCC.DIRECT.GETBCR)
    assert await ccc_address(dut, 0x2D, read=True)
    assert await ccc_response(dut, 1) == [0x26]


@cocotb.test(timeout_time=10, timeout_unit="us")
async def test_next_ccc_command_retirement(dut):
    """STOP and Sr+7E/W emit distinct completion actions and retire the old command."""
    await ccc_block_setup(dut)
    await ccc_tick(dut, get_bcr_i=0x26)

    for ending in ("STOP", "Sr+7E/W"):
        await read_bcr(dut)
        assert int(dut.command_code_valid.value) == 1
        assert int(dut.command_code.value) == CCC.DIRECT.GETBCR
        if ending != "STOP":
            assert await ccc_address(dut, 0x7E, complete_ack=False)

        # The parent holds its old command-valid through the ownership-release edge.
        assert int(dut.ccc_valid_i.value) == 1
        release = await ccc_tick(dut, stop=int(ending == "STOP"), tx_done=int(ending != "STOP"))
        assert release["handoff_o"] == (CccHandoff.DONE if ending == "STOP" else CccHandoff.NEXT_CMD)
        retired = (int(dut.command_code_valid.value), int(dut.command_code.value))
        dut._log.info("%s release: handoff=%s; command_code_valid=%d command_code=0x%02X", ending, CccHandoff(release["handoff_o"]).name, *retired)

        await ccc_tick(dut, ccc_valid_i=0)
        for _ in range(4):
            await ccc_tick(dut)
        assert retired == (0, 0), (
            f"{ending} did not retire GETBCR: valid={retired[0]}, opcode=0x{retired[1]:02X}. "
            "CccNextCmd must retire context just like CccDone."
        )
        assert int(dut.command_code_valid.value) == 0
        assert int(dut.command_code.value) == 0


@cocotb.test(timeout_time=10, timeout_unit="us")
async def test_next_ccc_functional_chain(dut):
    """Check actual chaining independently of the internal retirement assertion."""
    await ccc_block_setup(dut)
    await ccc_tick(dut, get_bcr_i=0x26, get_dcr_i=0x5A)
    await read_bcr(dut)
    assert await ccc_address(dut, 0x7E, complete_ack=False)
    release = await ccc_tick(dut, tx_done=1)
    assert release["handoff_o"] == CccHandoff.NEXT_CMD
    dut._log.info("Functional control: after next, command_code_valid=%d command_code=0x%02X", int(dut.command_code_valid.value), int(dut.command_code.value))

    # Model the main FSM receiving the next opcode: no STOP, and no new CCC-valid yet.
    await ccc_tick(dut, ccc_valid_i=0)
    for _ in range(8):
        await ccc_tick(dut)
        assert not get_rx_req_byte(dut) and not get_rx_req_bit(dut) and not get_tx_req_valid(dut)
        assert int(dut.handoff_o.value) == CccHandoff.NONE

    # GETDCR differs from GETBCR in both command parity and returned data.
    await ccc_command(dut, CCC.DIRECT.GETDCR)
    assert await ccc_address(dut, 0x2D, read=True)
    assert await ccc_response(dut, 1) == [0x5A]
    dut._log.info("GETBCR -> Sr+7E/W -> GETDCR completed correctly without STOP")
    await ccc_tick(dut, stop=1)
    await ccc_tick(dut, ccc_valid_i=0)
