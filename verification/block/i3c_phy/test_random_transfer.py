# Copyright (c) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

import logging
import random

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge
from utils import check_delayed

from common import I3C_CLOCK_DIV, init_phy
from i2c import I3C_PHY_DELAY

random.seed()


@cocotb.test()
async def run_test(dut):
    """Run test with comparison to I3C bus input lines."""
    cocotb.log.setLevel(logging.INFO)
    TEST_DATA = [random.randint(0, 1) for _ in range(20)]

    await init_phy(dut)

    clk = dut.clk_i

    clock_counter = 0
    while True:
        # Simulate I3C bus slower than internal clock
        await FallingEdge(clk)
        clock_counter += 1
        if clock_counter % I3C_CLOCK_DIV:
            continue

        # If TEST_DATA is empty, leave the loop
        if not TEST_DATA:
            break
        test_sda_bit = TEST_DATA.pop()

        # Assign new values to SCL and SDA
        not_scl = int(not int(dut.ctrl_scl_i.value))
        dut.ctrl_scl_i._log.debug(f"Setting SCL to {not_scl}")
        dut.ctrl_scl_i.value = not_scl
        dut.ctrl_sda_i._log.debug(f"Setting SDA to {test_sda_bit}")
        dut.ctrl_sda_i.value = test_sda_bit

        # We expect bus input value if we do not control the bus
        expected_scl = int(dut.scl_i.value) if not_scl else 0
        expected_sda = int(dut.sda_i.value) if test_sda_bit else 0

        # Spawn a coroutine that will check SCL state after synchronization cycles
        cocotb.start_soon(check_delayed(clk, dut.ctrl_scl_o, expected_scl, delay=I3C_PHY_DELAY))

        # Spawn a coroutine that will check SDA state after synchronization cycles
        cocotb.start_soon(check_delayed(clk, dut.ctrl_sda_o, expected_sda, delay=I3C_PHY_DELAY))

        await RisingEdge(clk)

    await ClockCycles(clk, 5)
