# SPDX-License-Identifier: Apache-2.0

import logging

from boot import boot_init
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface
from recovery_interface import RecoveryInterface

import cocotb
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_recovery(dut):

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

    recovery = RecoveryInterface(i3c_controller)

    tb = I3CTopTestInterface(dut)
    await tb.setup()

    # TODO: Implement control of recovery handler enable. Write to the relevant
    # CSR to enable it somewehere here.

    # Configure the top level
    await boot_init(tb)

    # Send a packet
    await recovery.command(
        0x5A, RecoveryInterface.Command.DEVICE_RESET, True, [0x01, 0x02, 0x03, 0x04]
    )
    await ClockCycles(tb.clk, 100)
