# SPDX-License-Identifier: Apache-2.0

import logging

from boot import boot_init
from ccc import CCC
from cocotbext_i3c.i3c_controller import I3cController
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import ReadOnly, RisingEdge

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

    # Set initial signals
    dut.peripheral_reset_done_i.value = 0

    tb = I3CTopTestInterface(dut)
    await tb.setup()
    await boot_init(tb)
    return i3c_controller, tb


async def do_pattern_reset(dut, tb, i3c_controller, expect_escalation=False):
    dut.log.info(
        f"Initiating reset with Target Reset Pattern (expect escalation set to {expect_escalation})"
    )
    await i3c_controller.send_target_reset_pattern()

    # Core should initiate peripheral reset after Target Reset Pattern
    assert dut.peripheral_reset_o == (not expect_escalation)
    assert dut.escalated_reset_o == expect_escalation
    await RisingEdge(tb.clk)

    # Indicate that peripheral reset is finished
    dut.peripheral_reset_done_i.value = not expect_escalation
    await RisingEdge(tb.clk)

    # Peripheral reset should be deasserted at this point
    await ReadOnly()
    assert dut.peripheral_reset_o == 0
    assert dut.escalated_reset_o == expect_escalation

    # Clear reset done
    await RisingEdge(tb.clk)
    dut.peripheral_reset_done_i.value = 0


@cocotb.test()
async def test_target_peripheral_reset(dut):
    i3c_controller, tb = await test_setup(dut)

    await do_pattern_reset(dut, tb, i3c_controller)


@cocotb.test()
async def test_target_escalated_reset(dut):
    i3c_controller, tb = await test_setup(dut)

    await do_pattern_reset(dut, tb, i3c_controller)

    # Clear escalated reset by sending GETSTATUS
    await i3c_controller.i3c_ccc_read(ccc=CCC.DIRECT.GETSTATUS, addr=TGT_ADR, count=2)

    await do_pattern_reset(dut, tb, i3c_controller)

    await do_pattern_reset(dut, tb, i3c_controller, True)
