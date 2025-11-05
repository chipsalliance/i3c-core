# SPDX-License-Identifier: Apache-2.0

import logging
import random

from boot import boot_init
from bus2csr import bytes2int
from ccc import CCC
from cocotbext_i3c.common import I3cTargetResetAction
from cocotbext_i3c.i3c_controller import I3cController
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import ClockCycles
from cocotb.regression import TestFactory

TGT_ADR = 0x5A

VALID_I3C_ADDRESSES = (
    [i for i in range(0x03, 0x3E)]
    + [i for i in range(0x3F, 0x5E)]
    + [i for i in range(0x5F, 0x6E)]
    + [i for i in range(0x6F, 0x76)]
    + [i for i in range(0x77, 0x7A)]
    + [0x7B, 0x7D]
)

async def test_setup(dut, static_addr=0x5A, virtual_static_addr=0x5B):
    """
    Sets up controller, target models and top-level core interface
    """
    cocotb.log.setLevel(logging.DEBUG)

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
    await boot_init(tb, static_addr=static_addr, virtual_static_addr=virtual_static_addr)
    return i3c_controller, i3c_target, tb


@cocotb.test()
async def test_ccc_getstatus(dut):
    PENDING_INTERRUPT = 0
    PENDING_INTERRUPT_MASK = 0b1111

    i3c_controller, i3c_target, tb = await test_setup(dut)
    interrupt_status_reg_addr = tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS.base_addr
    pending_interrupt_field = tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS.PENDING_INTERRUPT
    interrupt_status = bytes2int(await tb.read_csr(interrupt_status_reg_addr, 4))
    dut._log.info(f"Interrupt status from CSR: {interrupt_status}")

    # NOTE: The field INTERRUPT_STATUS.PENDING_INTERRUPT is not writable by
    # software and cocotb does not allow to set the underlying register directly.
    # So the only value that can be read back is 0.

    pending_interrupt = await tb.read_csr_field(interrupt_status_reg_addr, pending_interrupt_field)
    assert (
        pending_interrupt == PENDING_INTERRUPT
    ), "Unexpected pending interrupt value read from CSR"

    responses = await i3c_controller.i3c_ccc_read(ccc=CCC.DIRECT.GETSTATUS, addr=TGT_ADR, count=2)
    status = responses[0][1]
    print("status", status)
    pending_interrupt = (
        int.from_bytes(status, byteorder="big", signed=False) & PENDING_INTERRUPT_MASK
    )
    assert (
        pending_interrupt == PENDING_INTERRUPT
    ), "Unexpected pending interrupt value received from GETSTATUS CCC"

    cocotb.log.info(f"GET STATUS = {status}")


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
    # send number of transaction to address other than our
    for _ in range(random.randint(1, 3)):
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.SETDASA, directed_data=[(random.choice(VALID_I3C_ADDRESSES), [random.choice(VALID_I3C_ADDRESSES) << 1])], stop=False
        )
    if random.choice([True, False]):
        # send regular device dynamic address along with addresses for other random devices (those should be ignored)
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.SETDASA, directed_data=[(random.choice(VALID_I3C_ADDRESSES), [random.choice(VALID_I3C_ADDRESSES) << 1]), (STATIC_ADDR, [DYNAMIC_ADDR << 1]), (random.choice(VALID_I3C_ADDRESSES), [random.choice(VALID_I3C_ADDRESSES) << 1])], stop=False
        )
    else:
        # send regular device dynamic address
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])], stop=False
        )
    # send number of transaction to address other than our
    for _ in range(random.randint(1, 3)):
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.SETDASA, directed_data=[(random.choice(VALID_I3C_ADDRESSES), [random.choice(VALID_I3C_ADDRESSES) << 1])], stop=False
        )
    if random.choice([True, False]):
        # send virtual device dynamic address along with addresses for other random devices (those should be ignored)
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.SETDASA, directed_data=[(random.choice(VALID_I3C_ADDRESSES), [random.choice(VALID_I3C_ADDRESSES) << 1]), (VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1]), (random.choice(VALID_I3C_ADDRESSES), [random.choice(VALID_I3C_ADDRESSES) << 1])], stop=False
        )
    else:
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
        )
    # send number of transaction to address other than our
    for _ in range(random.randint(1, 3)):
        await i3c_controller.i3c_ccc_write(
            ccc=CCC.DIRECT.SETDASA, directed_data=[(random.choice(VALID_I3C_ADDRESSES), [random.choice(VALID_I3C_ADDRESSES) << 1])], stop=False
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
    assert ack[0] == True

    # try to send SETDASA again (should be NACKed)
    ack = await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])], stop=False
    )
    assert ack[0] == False

    # set virtual device dynamic address
    ack = await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )
    # check ACK
    assert ack[0] == True

    # try to send SETDASA again (should be NACKed)
    ack = await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )
    assert ack[0] == False


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

@cocotb.test()
async def test_ccc_rstdaa(dut):

    DYNAMIC_ADDR = 0x52
    VIRT_DYNAMIC_ADDR = 0x53
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

@cocotb.test()
async def test_ccc_getbcr(dut):

    _BCR_FIXED = 0b001  # CSR reset value
    _BCR_VARs = [random.randint(0, 31), random.randint(0, 31)]
    command = CCC.DIRECT.GETBCR

    list_of_values = VALID_I3C_ADDRESSES.copy()

    (STATIC_ADDR, VIRT_STATIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 2)

    i3c_controller, _, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR)
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

    for _tgt_adr, _bcr_var in zip([STATIC_ADDR, VIRT_STATIC_ADDR], _BCR_VARs):
        responses = await i3c_controller.i3c_ccc_read(ccc=command, addr=_tgt_adr, count=1)
        bcr = responses[0][1]
        bcr_value = int.from_bytes(bcr, byteorder="big", signed=False)
        _BCR_VALUE = (_BCR_FIXED << 5) | _bcr_var
        assert _BCR_VALUE == bcr_value


@cocotb.test()
async def test_ccc_getdcr(dut):

    _DCR_VARs = [random.randint(0, 255), random.randint(0, 255)]
    command = CCC.DIRECT.GETDCR

    (STATIC_ADDR, VIRT_STATIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 2)

    i3c_controller, _, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR)
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

    for _tgt_adr, _dcr_value in zip([STATIC_ADDR, VIRT_STATIC_ADDR], _DCR_VARs):
        responses = await i3c_controller.i3c_ccc_read(ccc=command, addr=_tgt_adr, count=1)
        dcr = responses[0][1]
        dcr_value = int.from_bytes(dcr, byteorder="big", signed=False)
        assert _dcr_value == dcr_value


@cocotb.test()
async def test_ccc_getmwl(dut):

    _TXRX_QUEUE_SIZE = 2 ** (5 + 1)  # Dwords
    _MWL_VALUE = 4 * _TXRX_QUEUE_SIZE  # Bytes

    command = CCC.DIRECT.GETMWL

    i3c_controller, _, tb = await test_setup(dut)

    responses = await i3c_controller.i3c_ccc_read(ccc=command, addr=TGT_ADR, count=2)
    [mwl_msb, mwl_lsb] = responses[0][1]

    mwl = (mwl_msb << 8) | mwl_lsb
    assert mwl == _MWL_VALUE


@cocotb.test()
async def test_ccc_getmrl(dut):

    _TXRX_QUEUE_SIZE = 2 ** (5 + 1)  # Dwords
    _MRL_VALUE = 4 * _TXRX_QUEUE_SIZE  # Bytes
    _IBI_PAYLOAD_SIZE = 255  # Bytes
    command = CCC.DIRECT.GETMRL

    i3c_controller, _, tb = await test_setup(dut)

    responses = await i3c_controller.i3c_ccc_read(ccc=command, addr=TGT_ADR, count=3)
    [mrl_msb, mrl_lsb, ibi_payload_size] = responses[0][1]

    mrl = (mrl_msb << 8) | mrl_lsb
    assert mrl == _MRL_VALUE
    assert ibi_payload_size == _IBI_PAYLOAD_SIZE


@cocotb.test()
async def test_ccc_setaasa(dut):

    STATIC_ADDR = 0x5A
    VIRT_STATIC_ADDR = 0x5B
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

@cocotb.test()
async def test_ccc_getpid(dut):

    _PID_HIs = [random.randint(0, 32767), random.randint(0, 32767)]
    _PID_LOs = [random.randint(0, (2**32)-1), random.randint(0, (2**32)-1)]
    command = CCC.DIRECT.GETPID

    (STATIC_ADDR, VIRT_STATIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 2)

    i3c_controller, _, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR)
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

    for _tgt_adr, _pid_lo, _pid_hi in zip([STATIC_ADDR, VIRT_STATIC_ADDR], _PID_LOs, _PID_HIs):
        responses = await i3c_controller.i3c_ccc_read(ccc=command, addr=_tgt_adr, count=6)
        pid = responses[0][1]
        pid_hi = int.from_bytes(pid[0:2], byteorder="big", signed=False)
        pid_lo = int.from_bytes(pid[2:6], byteorder="big", signed=False)

        # PID_HI has bit 0 always stuck at 0
        # Test can only setup 15 upper bits
        assert pid_hi == _pid_hi * 2
        assert pid_lo == _pid_lo


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

    _EVENT_TOGGLE_BYTE = 0b00001011

    i3c_controller, _, tb = await test_setup(dut)

    # Read default values
    event_en = await read_target_events(tb)
    assert event_en == (1, 0, 1)

    # Disable all target events
    await i3c_controller.i3c_ccc_write(
        ccc=command_disec, directed_data=[(TGT_ADR, [_EVENT_TOGGLE_BYTE])]
    )

    # Read disabled values
    event_en = await read_target_events(tb)
    assert event_en == (0, 0, 0)

    # Enable all target events
    await i3c_controller.i3c_ccc_write(
        ccc=command_enec, directed_data=[(TGT_ADR, [_EVENT_TOGGLE_BYTE])]
    )

    # Read enabled values
    event_en = await read_target_events(tb)
    assert event_en == (1, 1, 1)


@cocotb.test()
async def test_ccc_enec_disec_bcast(dut):

    command_enec = CCC.BCAST.ENEC
    command_disec = CCC.BCAST.DISEC

    _EVENT_TOGGLE_BYTE = 0b00001011

    i3c_controller, _, tb = await test_setup(dut)

    # Read default values
    event_en = await read_target_events(tb)
    assert event_en == (1, 0, 1)

    # Disable all target events
    await i3c_controller.i3c_ccc_write(ccc=command_disec, broadcast_data=[_EVENT_TOGGLE_BYTE])

    # Read disabled values
    event_en = await read_target_events(tb)
    assert event_en == (0, 0, 0)

    # Enable all target events
    await i3c_controller.i3c_ccc_write(ccc=command_enec, broadcast_data=[_EVENT_TOGGLE_BYTE])

    # Read enabled values
    event_en = await read_target_events(tb)
    assert event_en == (1, 1, 1)


@cocotb.test()
async def test_ccc_setmwl_direct(dut):

    command = CCC.DIRECT.SETMWL

    i3c_controller, _, tb = await test_setup(dut)

    # Send direct SETMWL
    mwl_msb = 0xAB
    mwl_lsb = 0xCD
    await i3c_controller.i3c_ccc_write(ccc=command, directed_data=[(TGT_ADR, [mwl_msb, mwl_lsb])])

    # Check if MWL got written
    sig = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mwl_o.value
    mwl = (mwl_msb << 8) | mwl_lsb
    assert mwl == int(sig)


@cocotb.test()
async def test_ccc_setmrl_direct(dut):

    command = CCC.DIRECT.SETMRL

    i3c_controller, _, tb = await test_setup(dut)

    # Send direct SETMRL
    mrl_msb = 0xAB
    mrl_lsb = 0xCD
    await i3c_controller.i3c_ccc_write(ccc=command, directed_data=[(TGT_ADR, [mrl_msb, mrl_lsb])])

    # Check if MRL got written
    sig = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mrl_o.value
    mrl = (mrl_msb << 8) | mrl_lsb
    assert mrl == int(sig)


@cocotb.test()
async def test_ccc_setmwl_bcast(dut):

    command = CCC.BCAST.SETMWL

    i3c_controller, _, tb = await test_setup(dut)

    # Send direct SETMWL
    mwl_msb = 0xAB
    mwl_lsb = 0xCD
    await i3c_controller.i3c_ccc_write(ccc=command, broadcast_data=[mwl_msb, mwl_lsb])

    # Check if MWL got written
    sig = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mwl_o.value
    mwl = (mwl_msb << 8) | mwl_lsb
    assert mwl == int(sig)


@cocotb.test()
async def test_ccc_setmrl_bcast(dut):

    command = CCC.BCAST.SETMRL

    i3c_controller, _, tb = await test_setup(dut)

    # Send direct SETMRL
    mrl_msb = 0xAB
    mrl_lsb = 0xCD
    await i3c_controller.i3c_ccc_write(ccc=command, broadcast_data=[mrl_msb, mrl_lsb])

    # Check if MRL got written
    sig = dut.xi3c_wrapper.i3c.xcontroller.xconfiguration.get_mrl_o.value
    mrl = (mrl_msb << 8) | mrl_lsb
    assert mrl == int(sig)


SUPPORTED_RESET_ACTIONS = [
    I3cTargetResetAction.NO_RESET,
    I3cTargetResetAction.RESET_PERIPHERAL_ONLY,
    I3cTargetResetAction.RESET_WHOLE_TARGET,
]
async def test_ccc_rstact(dut, type, rstact):
    i3c_controller, _, tb = await test_setup(dut)

    if type == "broadcast":
        command = CCC.BCAST.RSTACT
        directed_data = None
        reset_actions = rstact
    elif type == "direct":
        command = CCC.DIRECT.RSTACT
        directed_data = [(TGT_ADR, [])]
        reset_actions = [(TGT_ADR, rstact)]
    else:
        assert False, "Unsupported RSTACT type, must be 'broadcast' or 'direct'"

    # Send directed RSTACT
    rst_action = 0xAA
    await i3c_controller.i3c_ccc_write(
        ccc=command,
        defining_byte=rst_action,
        directed_data=directed_data,
        stop=False,
    )

    # Check if reset action got stored correctly in the logic after Target Reset Pattern
    sig = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.rst_action_o
    assert int(sig) == 0
    await i3c_controller.send_target_reset_pattern()
    assert rst_action == int(sig)
    await i3c_controller.send_stop()

    # Start new frame and reset target with reset action set to peripheral reset
    await i3c_controller.target_reset(reset_actions)
    if rstact == I3cTargetResetAction.NO_RESET:
        assert dut.peripheral_reset_o == 0
        assert dut.escalated_reset_o == 0
    elif rstact == I3cTargetResetAction.RESET_PERIPHERAL_ONLY:
        assert dut.peripheral_reset_o == 1
        assert dut.escalated_reset_o == 0
    elif rstact == I3cTargetResetAction.RESET_WHOLE_TARGET:
        assert dut.peripheral_reset_o == 0
        assert dut.escalated_reset_o == 1
    else:
        assert False, f"Unsupported reset action ({rstact}), must be one of {SUPPORTED_RESET_ACTIONS}"
    await ClockCycles(tb.clk, 50)

rstact_tf = TestFactory(test_function=test_ccc_rstact)
rstact_tf.add_option(name="rstact", optionlist=SUPPORTED_RESET_ACTIONS)
rstact_tf.add_option(name="type", optionlist=["broadcast", "direct"])
rstact_tf.generate_tests()


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

    assert result


@cocotb.test()
async def test_ccc_direct_multiple_rd(dut):
    """
    Send SETMWL CCC. Then send multiple directed GETMWL CCCs to thee different
    addresses. Only the one for the target should contain ACK with correct
    MWL content.
    """

    result = True

    i3c_controller, _, tb = await test_setup(dut)

    # Set MWL in the target
    acks = await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETMWL, directed_data=[(TGT_ADR, (0x00, 0x55))]
    )
    if acks != [True]:
        dut._log.error("Initial SETMWL failed")
        assert False

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

    assert result
