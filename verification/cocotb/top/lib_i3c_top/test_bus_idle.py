# SPDX-License-Identifier: Apache-2.0

import logging
import cocotb
from cocotb.triggers import ClockCycles, Timer
from boot import boot_init
from i3c_controller_fixed import I3cControllerFixed as I3cController
from interface import I3CTopTestInterface
from common import log_seed

async def test_setup(dut):
    cocotb.log.setLevel(logging.DEBUG)
    log_seed(dut)
    i3c_controller = I3cController(
        sda_i=dut.bus_sda, sda_o=dut.sda_sim_ctrl_i,
        scl_i=dut.bus_scl, scl_o=dut.scl_sim_ctrl_i,
        debug_state_o=None, speed=12.5e6,
    )
    i3c_controller.monitor_enable.clear()
    await i3c_controller.monitor_idle.wait()
    dut.sda_sim_target_i.value = 1
    dut.scl_sim_target_i.value = 1
    dut.peripheral_reset_done_i.value = 0
    tb = I3CTopTestInterface(dut)
    await tb.setup(fclk=333.0)
    await ClockCycles(tb.clk, 50)
    await boot_init(tb, fclk=333.0)
    return i3c_controller, tb

@cocotb.test()
async def test_bus_idle_coverage(dut):
    """
    Coverage: bus_idle_o is toggled and reset_counter = 0 and bus_idle_o = 1.
    """
    i3c_controller, tb = await test_setup(dut)
    
    # 1. Generate a manual STOP condition to start the bus timers
    # (The timer requires a STOP detection edge to restart its internal counters)
    dut._log.info("Generating STOP condition (SDA 0->1 while SCL=1) to start bus timers")
    i3c_controller.scl = 1
    i3c_controller.sda = 0
    await Timer(2, "us")
    i3c_controller.sda = 1  # STOP edge
    await Timer(2, "us")
    
    # 2. Wait > 200us for T_IDLE. This forces bus_idle_o to toggle 0 -> 1.
    dut._log.info("Waiting 210us for bus_idle_o to assert")
    await Timer(210, "us")
    
    # 3. Generate a manual START condition to break the idle state (1 -> 0 toggle)
    dut._log.info("Generating START condition (SDA 1->0 while SCL=1) to deassert bus_idle_o")
    i3c_controller.sda = 0
    await Timer(2, "us")
    
    await tb.teardown()