# Copyright (c) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Join, RisingEdge, with_timeout


async def data_feeder(dut, data):
    """
    Input port handler
    """

    await RisingEdge(dut.clk_i)

    # Feed data to the converter
    for word in data:

        # Put a data word, wait for it to be accepted
        dut.in_data_i.value = word
        dut.in_valid_i.value = 1

        while True:
            await RisingEdge(dut.clk_i)
            if dut.in_valid_i.value and dut.in_ready_o.value:
                break

        # Wait at random
        if random.random() > 0.5:
            dut.in_valid_i.value = 0
            await ClockCycles(dut.clk_i, random.randint(1, 5))

    await RisingEdge(dut.clk_i)
    dut.in_valid_i.value = 0


async def data_receiver(dut, data):
    """
    Output port handler
    """

    # Receive data
    while True:
        await RisingEdge(dut.clk_i)

        # Receive a word
        if dut.out_valid_o.value and dut.out_ready_i.value:
            data.append(int(dut.out_data_o.value))

        # Accept or not accept at random
        dut.out_ready_i.value = random.random() > 0.5


@cocotb.test()
async def run_test(dut):

    # Drive clock
    clock = Clock(dut.clk_i, 1, "ns")
    await cocotb.start(clock.start())

    # Reset
    dut.rst_ni.value = 0
    await ClockCycles(dut.clk_i, 5)
    dut.rst_ni.value = 1

    # Generate random data bytes
    inp_bytes = [random.randint(0, 1 << 7) for i in range(50)]
    out_words = []

    # Feed data to the module, collect output
    t1 = await cocotb.start(data_feeder(dut, inp_bytes))
    await cocotb.start(data_receiver(dut, out_words))

    await with_timeout(Join(t1), 1, "us")
    await ClockCycles(dut.clk_i, 100)  # Ensure that all output is collected

    # Convert input to words
    inp_words = []
    for i in range(len(inp_bytes) // 4):
        word = (
            (inp_bytes[4 * i + 3] << 24)
            | (inp_bytes[4 * i + 2] << 16)
            | (inp_bytes[4 * i + 1] << 8)
            | inp_bytes[4 * i + 0]
        )
        inp_words.append(word)

    dut._log.info(" ".join(["{:08X}h".format(b) for b in inp_words]))
    dut._log.info(" ".join(["{:08X}h".format(b) for b in out_words]))

    # Compare
    assert out_words == inp_words
