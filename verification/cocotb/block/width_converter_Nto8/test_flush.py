# Copyright (c) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, RisingEdge


async def test_flush(dut, count):
    """
    Tests converter's flush opeation by feeding count bytes and requesting
    the flush.
    """

    # Reset
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 0
    dut.soft_reset_ni.value = 1
    dut.sink_valid_i.value = 0
    dut.sink_data_i.value = 0
    dut.source_flush_i.value = 0
    dut.source_ready_i.value = 0

    await ClockCycles(dut.clk_i, 20)
    dut.rst_ni.value = 1

    # Feed N words into the module
    dword = 0
    for i in range(4):
        if i < count:
            byte = random.randint(0, 255)
        dword |= byte << (i * 8)

    await RisingEdge(dut.clk_i)
    dut.sink_data_i.value = dword
    dut.sink_valid_i.value = 1
    dut.source_ready_i.value = 1

    for i in range(4):
        expected = 0 if (i >= count) else ((dword >> (i * 8)) & 0xFF)
        dut.source_flush_i.value = i >= count
        await RisingEdge(dut.clk_i)
        dut.sink_valid_i.value = 0
        await ReadOnly()
        assert dut.source_data_o.value == expected
        await FallingEdge(dut.clk_i)

    # Intentional delay gap
    await ClockCycles(dut.clk_i, 5)


@cocotb.test()
async def test_width_converter_nto8_flush(dut):

    # Drive clock
    clock = Clock(dut.clk_i, 1, "ns")
    await cocotb.start(clock.start())

    # Make output always ready
    dut.source_ready_i.value = 1

    # Test flushing for 1-3 bytes of input
    for i in [1, 2, 3]:
        await test_flush(dut, i)
