# SPDX-License-Identifier: Apache-2.0

import logging

from boot import boot_init
from bus2csr import bytes2int
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_target import I3CTarget
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

    i3c_target = I3CTarget(  # noqa
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_target_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_target_i,
        debug_state_o=None,
        address=TGT_ADR,
        speed=12.5e6,
    )

    tb = I3CTopTestInterface(dut)
    await tb.setup()
    await ClockCycles(tb.clk, 50)
    await boot_init(tb)
    return i3c_controller, i3c_target, tb


@cocotb.test()
async def test_target_reset(dut):
    I3C_DIRECT_GETSTATUS = 0x90
    PENDING_INTERRUPT = 7
    PENDING_INTERRUPT_MASK = 0b1111

    i3c_controller, i3c_target, tb = await test_setup(dut)

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
    pending_interrupt = status & PENDING_INTERRUPT_MASK
    assert (
        pending_interrupt == PENDING_INTERRUPT
    ), "Unexpected pending interrupt value received from GETSTATUS CCC"

    cocotb.log.info(f"GET STATUS = {status}")
