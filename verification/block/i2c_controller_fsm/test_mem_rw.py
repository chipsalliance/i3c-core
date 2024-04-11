# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge
from cocotbext.i2c import I2cMemory
from i2c import i2c_mem_read, i2c_mem_write, init_i2c_controller_ports


@cocotb.test()
async def run_test(dut):
    """
    The test
    """

    # I2C target
    I2cMemory(sda=dut.sda_o, sda_o=dut.sda_i, scl=dut.scl_o, scl_o=dut.scl_i)

    init_i2c_controller_ports(dut)

    # Start clock
    clock = Clock(dut.clk_i, 0.5, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_ni.value = 0
    await ClockCycles(dut.clk_i, 2)
    await FallingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await ClockCycles(dut.clk_i, 2)

    # Test

    payload = [0xCA, 0xFE, 0xBA, 0xCA, 0xDE, 0xAD, 0xBE, 0xEF]

    # I2C memory write
    await i2c_mem_write(dut, 0x50, 0x10, payload)

    # Wait
    await ClockCycles(dut.clk_i, 100)

    # I2C memory read
    received = await i2c_mem_read(dut, 0x50, 0x10, len(payload))
    assert payload == received

    # Dummy
    await ClockCycles(dut.clk_i, 100)
