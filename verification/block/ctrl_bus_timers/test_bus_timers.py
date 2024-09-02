# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles
from cocotb_helpers import cycle, reset_n


async def setup(dut):
    """
    Happy path testing:
     - t_bus_available_i > t_bus_free_i
     - t_bus_idle_i >> t_bus_available_i
     - t_bus_idle_i >> t_bus_free_i
    """
    dut.t_bus_free_i.value = 5
    dut.t_bus_available_i.value = 10
    dut.t_bus_idle_i.value = 50
    await ClockCycles(dut.clk_i, 10)


@cocotb.test()
async def test_bus_timers(dut: SimHandleBase):
    """
    Test bus timers
    """
    # Start clock
    clock = Clock(dut.clk_i, 2, units="ns")
    cocotb.start_soon(clock.start())

    clk = dut.clk_i
    rst_n = dut.rst_ni

    await reset_n(clk, rst_n, cycles=5)
    await setup(dut)

    # Enable counter
    dut.enable_i.value = 1

    for _ in range(3):
        await cycle(dut.clk_i, dut.restart_counter_i)
        await ClockCycles(dut.clk_i, 1)
        assert dut.bus_free_o.value == 0
        assert dut.bus_available_o.value == 0
        assert dut.bus_idle_o.value == 0
        await ClockCycles(dut.clk_i, 75)
        assert dut.bus_free_o.value == 1
        assert dut.bus_available_o.value == 1
        assert dut.bus_idle_o.value == 1
