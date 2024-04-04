# Copyright (c) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def run_test(dut):
    """Run test for mixed signal simulation - automatic trimming of a voltage regulator."""
    clk = dut.clk
    rst = dut.rst_n

    cocotb.start_soon(Clock(clk, 10, "ns").start())

    await ClockCycles(clk, 10)
    rst.value = 1
    await ClockCycles(clk, 10)

    assert dut.ctrl_scl_o.value == 0, "Incorrect value of SCL after module reset"
    assert dut.ctrl_sda_o.value == 0, "Incorrect value of SDA after module reset"
