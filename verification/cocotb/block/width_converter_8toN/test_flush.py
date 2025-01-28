# Copyright (c) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, with_timeout


async def test_flush(dut, count):
    """
    Tests converter's flush opeation by feeding count bytes and requesting
    the flush.
    """

    # Reset
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 0
    dut.sink_flush_i = 0
    dut.sink_valid_i = 0
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1

    # Feed N bytes into the module
    inp_word = 0
    for i in range(count):

        byte = random.randint(0, 1 << 7)
        inp_word |= byte << (i * 8)

        await RisingEdge(dut.clk_i)
        dut.sink_data_i.value = byte
        dut.sink_valid_i.value = 1

    await RisingEdge(dut.clk_i)
    dut.sink_valid_i.value = 0

    # Wait 1 clock and flush
    await RisingEdge(dut.clk_i)
    dut.sink_flush_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.sink_flush_i.value = 0

    # Wait for data
    await with_timeout(RisingEdge(dut.source_valid_o), 1, "us")
    out_word = int(dut.source_data_o.value)

    # Intentional delay gap
    await ClockCycles(dut.clk_i, 5)

    dut._log.info("in  0x{:08X}".format(inp_word))
    dut._log.info("out 0x{:08X}".format(out_word))

    # Check
    assert out_word == inp_word


@cocotb.test()
async def test_width_converter_8ton_flush(dut):

    # Drive clock
    clock = Clock(dut.clk_i, 1, "ns")
    await cocotb.start(clock.start())

    # Make output always ready
    dut.source_ready_i.value = 1

    # Test flushing for 1-3 bytes of input
    for i in [1, 2, 3]:
        await test_flush(dut, i)
