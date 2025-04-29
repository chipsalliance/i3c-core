# Copyright (c) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

import random

import crc

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge


@cocotb.test()
async def test_pec(dut):

    # Generate some data
    data = []
    for i in range(32):
        data.append(random.randint(0, 255))
    data = bytes(data)

    # Initialize CRC calculator, compute CRC
    conf = crc.Configuration(
        width=8,
        polynomial=0x7,
        init_value=0x00,
        final_xor_value=0x00,
        reverse_input=False,
        reverse_output=False,
    )

    calc = crc.Calculator(conf, optimized=True)
    crc_ref = int(calc.checksum(data))

    # Drive clock
    clock = Clock(dut.clk_i, 1, "ns")
    await cocotb.start(clock.start())

    dut.rst_ni.value = 0
    dut.soft_reset_ni.value = 1
    dut.valid_i = 0
    dut.init_i = 0

    # Deassert reset
    await ClockCycles(dut.clk_i, 5)
    dut.rst_ni.value = 1

    # Feed data to the module
    idx = 0
    while idx < len(data):

        valid = int(random.random() > 0.5)  # Randomize valid

        # Drive
        await RisingEdge(dut.clk_i)
        dut.dat_i.value = data[idx]
        dut.valid_i.value = valid

        # Next byte
        if valid:
            idx = idx + 1

    await RisingEdge(dut.clk_i)
    dut.valid_i.value = 0

    # Collect PEC checksum
    await RisingEdge(dut.clk_i)
    crc_out = int(dut.crc_o.value)

    await ClockCycles(dut.clk_i, 5)

    dut._log.info("ref: 0x{:02X}".format(crc_ref))
    dut._log.info("out: 0x{:02X}".format(crc_out))

    # Compare
    assert crc_out == crc_ref
