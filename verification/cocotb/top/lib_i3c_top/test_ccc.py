# SPDX-License-Identifier: Apache-2.0

import logging

from boot import boot_init
from bus2csr import bytes2int
from ccc import CCC
from cocotbext_i3c.i3c_controller import I3cController
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import ClockCycles

TGT_ADR = 0x5A


async def test_setup(dut):
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

    tb = I3CTopTestInterface(dut)
    await tb.setup()
    await ClockCycles(tb.clk, 50)
    await boot_init(tb)
    return i3c_controller, i3c_target, tb


@cocotb.test()
async def test_ccc_getstatus(dut):
    I3C_DIRECT_GETSTATUS = 0x90
    PENDING_INTERRUPT = 7
    PENDING_INTERRUPT_MASK = 0b1111

    i3c_controller, i3c_target, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)
    interrupt_status_reg_addr = tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS.base_addr
    pending_interrupt_field = tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS.PENDING_INTERRUPT
    interrupt_status = bytes2int(await tb.read_csr(interrupt_status_reg_addr, 4))
    dut._log.info(f"Interrupt status from CSR: {interrupt_status}")

    # Write arbitrary value to the pending interrupt field
    dut._log.info(
        f"Write {PENDING_INTERRUPT} to interrupt status register at pending interrupt field"
    )
    await tb.write_csr_field(interrupt_status_reg_addr, pending_interrupt_field, PENDING_INTERRUPT)
    interrupt_status = bytes2int(await tb.read_csr(interrupt_status_reg_addr, 4))
    dut._log.info(f"Interrupt status from CSR: {interrupt_status}")

    pending_interrupt = await tb.read_csr_field(interrupt_status_reg_addr, pending_interrupt_field)
    assert (
        pending_interrupt == PENDING_INTERRUPT
    ), "Unexpected pending interrupt value read from CSR"

    status = await i3c_controller.i3c_ccc_read(ccc=I3C_DIRECT_GETSTATUS, addr=TGT_ADR, count=2)
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

    STATIC_ADDR = 0x5A
    DYNAMIC_ADDR = 0x52
    I3C_DIRECT_SETDASA = 0x87
    i3c_controller, i3c_target, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)
    await i3c_controller.i3c_ccc_write(
        ccc=I3C_DIRECT_SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR])]
    )
    dynamic_address_reg_addr = tb.reg_map.I3CBASE.CONTROLLER_DEVICE_ADDR.base_addr
    dynamic_address_reg_value = tb.reg_map.I3CBASE.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR
    dynamic_address_reg_valid = tb.reg_map.I3CBASE.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR_VALID
    dynamic_address = await tb.read_csr_field(dynamic_address_reg_addr, dynamic_address_reg_value)
    dynamic_address_valid = await tb.read_csr_field(
        dynamic_address_reg_addr, dynamic_address_reg_valid
    )
    assert dynamic_address == DYNAMIC_ADDR, "Unexpected DYNAMIC ADDRESS read from the CSR"
    assert dynamic_address_valid == 1, "New DYNAMIC ADDRESS is not set as valid"

@cocotb.test()
async def test_ccc_rstdaa(dut):

    DYNAMIC_ADDR = 0x52
    I3C_DIRECT_RSTDAA = 0x06
    i3c_controller, i3c_target, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)
    dynamic_address_reg_addr = tb.reg_map.I3CBASE.CONTROLLER_DEVICE_ADDR.base_addr
    dynamic_address_reg_value = tb.reg_map.I3CBASE.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR;
    dynamic_address_reg_valid = tb.reg_map.I3CBASE.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR_VALID;

    # set dynamic address CSR
    await tb.write_csr_field(dynamic_address_reg_addr, dynamic_address_reg_value, DYNAMIC_ADDR)
    await tb.write_csr_field(dynamic_address_reg_addr, dynamic_address_reg_valid, 1)

    # check if write was successful
    dynamic_address = await tb.read_csr_field(dynamic_address_reg_addr, dynamic_address_reg_value)
    dynamic_address_valid = await tb.read_csr_field(dynamic_address_reg_addr, dynamic_address_reg_valid)
    assert (
            dynamic_address == DYNAMIC_ADDR
    ), "Unexpected DYNAMIC ADDRESS read from the CSR"
    assert (
            dynamic_address_valid == 1
    ), "New DYNAMIC ADDRESS is not set as valid"

    # reset Dynamic Address
    await i3c_controller.i3c_ccc_write(ccc=I3C_DIRECT_RSTDAA)

    # check if the address was reset
    dynamic_address = await tb.read_csr_field(dynamic_address_reg_addr, dynamic_address_reg_value)
    dynamic_address_valid = await tb.read_csr_field(dynamic_address_reg_addr, dynamic_address_reg_valid)
    assert (
            dynamic_address == 0
    ), "Unexpected DYNAMIC ADDRESS read from the CSR"
    assert (
            dynamic_address_valid == 0
    ), "New DYNAMIC ADDRESS is not set as valid"


@cocotb.test()
async def test_ccc_getbcr(dut):

    _BCR_FIXED = 0b001  # CSR reset value
    _BCR_VAR = 0b00110  # CSR reset value
    _BCR_VALUE = (_BCR_FIXED << 5) | _BCR_VAR

    command = CCC.DIRECT.GETBCR

    i3c_controller, _, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)

    bcr = await i3c_controller.i3c_ccc_read(ccc=command, addr=TGT_ADR, count=1)
    bcr_value = int.from_bytes(bcr, byteorder="big", signed=False)
    assert _BCR_VALUE == bcr_value


@cocotb.test()
async def test_ccc_getdcr(dut):

    _DCR_VALUE = 0xBD  # OCP Recovery Device

    command = CCC.DIRECT.GETDCR

    i3c_controller, _, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)

    dcr = await i3c_controller.i3c_ccc_read(ccc=command, addr=TGT_ADR, count=1)
    dcr_value = int.from_bytes(dcr, byteorder="big", signed=False)
    assert _DCR_VALUE == dcr_value


@cocotb.test()
async def test_ccc_getmwl(dut):

    _TXRX_QUEUE_SIZE = 2 ** (5 + 1)  # Dwords
    _MWL_VALUE = 4 * _TXRX_QUEUE_SIZE  # Bytes

    command = CCC.DIRECT.GETMWL

    i3c_controller, _, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)

    [mwl_msb, mwl_lsb] = await i3c_controller.i3c_ccc_read(ccc=command, addr=TGT_ADR, count=2)

    mwl = (mwl_msb << 8) | mwl_lsb
    assert mwl == _MWL_VALUE


@cocotb.test()
async def test_ccc_getmrl(dut):

    _TXRX_QUEUE_SIZE = 2 ** (5 + 1)  # Dwords
    _MRL_VALUE = 4 * _TXRX_QUEUE_SIZE  # Bytes
    _IBI_PAYLOAD_SIZE = 255  # Bytes
    command = CCC.DIRECT.GETMRL

    i3c_controller, _, tb = await test_setup(dut)
    await ClockCycles(tb.clk, 50)

    [mrl_msb, mrl_lsb, ibi_payload_size] = await i3c_controller.i3c_ccc_read(
        ccc=command, addr=TGT_ADR, count=3
    )

    mrl = (mrl_msb << 8) | mrl_lsb
    assert mrl == _MRL_VALUE
    assert ibi_payload_size == _IBI_PAYLOAD_SIZE
