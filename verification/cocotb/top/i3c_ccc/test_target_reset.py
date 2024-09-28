# SPDX-License-Identifier: Apache-2.0

import logging

from boot import boot_init
from bus2csr import dword2int
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import ClockCycles
from cocotb.clock import Clock


@cocotb.test()
async def test_target_reset(dut):
    RSTACT_BCAST = 0x2A
    RSTACT_PERIPHERAL_RESET = 0x1
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
        speed=12.5e6,
    )

    tb = I3CTopTestInterface(dut)
    await tb.setup()
    await ClockCycles(dut.hclk, 50)
    await boot_init(tb)

    await i3c_controller.i3c_ccc_write(RSTACT_BCAST, defining_byte=RSTACT_PERIPHERAL_RESET, broadcast_data=[])

    # Verilator doesn't support struct access so we need this hacky way of accessing
    # the RST_ACTION register where we take the flattened bit vector value of all CSRs
    # and index into a range where RST_ACTION is which happens to be at indices 1183:1191
    csr_values = str(dut.xi3c_wrapper.i3c.xhci.i3c_csr.field_storage.value)
    rst_action = int(csr_values[1183:1191], base=2)
    assert rst_action == RSTACT_PERIPHERAL_RESET

