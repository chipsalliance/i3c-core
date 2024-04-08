# Copyright (c) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

import logging
import random

import cocotb
from cocotb.triggers import RisingEdge
from common import check_delayed, init_phy

random.seed()


@cocotb.test()
async def run_test(dut):
    """Run test of bus data synchronization without any additional checks."""
    cocotb.log.setLevel(logging.DEBUG)
    TEST_LEN = 100

    clk = dut.clk
    await init_phy(dut)

    for _ in range(TEST_LEN):
        rand_sda = random.randint(0, 1)
        rand_scl = random.randint(0, 1)

        dut.ctrl_scl_i._log.debug(f"Setting SCL to {rand_scl}")
        dut.ctrl_scl_i.value = rand_scl
        dut.ctrl_sda_i._log.debug(f"Setting SDA to {rand_sda}")
        dut.ctrl_sda_i.value = rand_sda

        cocotb.start_soon(check_delayed(clk, dut.ctrl_scl_o, rand_scl))
        cocotb.start_soon(check_delayed(clk, dut.ctrl_sda_o, rand_sda))
        await RisingEdge(clk)
