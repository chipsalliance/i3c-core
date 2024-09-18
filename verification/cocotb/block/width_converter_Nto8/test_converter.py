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
        dut.sink_data_i.value = word
        dut.sink_valid_i.value = 1

        while True:
            await RisingEdge(dut.clk_i)
            if dut.sink_valid_i.value and dut.sink_ready_o.value:
                break

        # Wait at random
        if random.random() > 0.5:
            dut.sink_valid_i.value = 0
            await ClockCycles(dut.clk_i, random.randint(5, 10))

    await RisingEdge(dut.clk_i)
    dut.sink_valid_i.value = 0


async def data_receiver(dut, data):
    """
    Output port handler
    """

    # Receive data
    while True:
        await RisingEdge(dut.clk_i)

        # Receive a byte
        if dut.source_valid_o.value and dut.source_ready_i.value:
            data.append(int(dut.source_data_o.value))

        # Accept or not accept at random
        dut.source_ready_i.value = random.random() > 0.5


@cocotb.test()
async def run_test(dut):

    # Drive clock
    clock = Clock(dut.clk_i, 1, "ns")
    await cocotb.start(clock.start())

    # Reset
    dut.rst_ni.value = 0
    await ClockCycles(dut.clk_i, 5)
    dut.rst_ni.value = 1

    # Generate random words
    inp_data = [random.randint(0, 1 << 31) for i in range(10)]
    out_bytes = []

    # Feed data to the module, collect output
    t1 = await cocotb.start(data_feeder(dut, inp_data))
    await cocotb.start(data_receiver(dut, out_bytes))

    await with_timeout(Join(t1), 1, "us")
    await ClockCycles(dut.clk_i, 100)  # Ensure that all output is collected

    # Convert input to bytes
    inp_bytes = []
    for word in inp_data:
        inp_bytes.append((word) & 0xFF)
        inp_bytes.append((word >> 8) & 0xFF)
        inp_bytes.append((word >> 16) & 0xFF)
        inp_bytes.append((word >> 24) & 0xFF)

    dut._log.info(" ".join(["{:02X}h".format(b) for b in inp_bytes]))
    dut._log.info(" ".join(["{:02X}h".format(b) for b in out_bytes]))

    # Compare
    assert out_bytes == inp_bytes
