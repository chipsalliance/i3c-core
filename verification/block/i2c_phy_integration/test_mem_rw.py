# SPDX-License-Identifier: Apache-2.0

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotbext.i2c import I2cMemory
from i2c import (
    i2c_cmd,
    i2c_mem_read,
    i2c_mem_write,
    init_i2c_controller_ports,
    reset,
)


@cocotb.test()
async def run_test(dut):
    """
    Executes random read and writes while checking data on the I2C FSM.
    Additionally runs the observer which checks states of PHY IO lines.
    """
    I2C_DEV_ADDR = 0x50
    I2C_REG_ADDR = 0x10

    # I2C target
    I2cMemory(sda=dut.ctrl_sda_o, sda_o=dut.ctrl_sda_i, scl=dut.ctrl_scl_o, scl_o=dut.ctrl_scl_i)

    # Mock PHY I3C bus pull-up
    dut.i3c_sda_i.value = 1
    dut.i3c_scl_i.value = 1

    # Drive constant DUT inputs
    init_i2c_controller_ports(dut)

    # Start clock
    clock = Clock(dut.clk_i, 0.5, units="us")
    cocotb.start_soon(clock.start())

    cocotb.start_soon(run_bus_observer(dut))

    # Reset
    await reset(dut)

    # Execute single I2C command test -----------------------------------------
    await i2c_cmd(dut, I2C_REG_ADDR << 1, sta_before=True, sto_after=True)
    await ClockCycles(dut.clk_i, 100)

    # Execute single read & write test ----------------------------------------
    # Write single byte to I2C memory
    TEST_PAYLOAD = [random.randint(0, 255)]
    await i2c_mem_write(dut, I2C_DEV_ADDR, I2C_REG_ADDR, TEST_PAYLOAD)
    await ClockCycles(dut.clk_i, 100)

    # Read the byte I2C memory
    received = await i2c_mem_read(dut, I2C_DEV_ADDR, I2C_REG_ADDR, 1)
    assert received == TEST_PAYLOAD

    # Reset
    await reset(dut)

    # Execute long payload read & write test ----------------------------------
    # Write test payload to I2C memory
    TEST_PAYLOAD = [random.randint(0, 255) for _ in range(20)]
    await i2c_mem_write(dut, I2C_DEV_ADDR, I2C_REG_ADDR, TEST_PAYLOAD)
    await ClockCycles(dut.clk_i, 100)

    # Read payload from I2C memory
    received = await i2c_mem_read(dut, I2C_DEV_ADDR, I2C_REG_ADDR, len(TEST_PAYLOAD))
    assert received == TEST_PAYLOAD

    # Dummy
    await ClockCycles(dut.clk_i, 100)
