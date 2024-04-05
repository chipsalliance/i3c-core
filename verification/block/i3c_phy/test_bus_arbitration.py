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
    """Run simple reset test."""
    cocotb.log.setLevel(logging.DEBUG)
    TEST_DATA = [0, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0, 1, 0]

    clk = dut.clk
    rst_n = dut.rst_n

    dut.sda_io.value = 1
    dut.scl_io.value = 1

    await init_phy(clk, rst_n)

    for bit in TEST_DATA:
        not_scl = not int(dut.ctrl_scl_i.value)
        dut.ctrl_scl_i._log.debug(f"Setting SCL to {not_scl}")
        dut.ctrl_scl_i.value = not_scl
        dut.ctrl_sda_i._log.debug(f"Setting SDA to {bit}")
        dut.ctrl_sda_i.value = bit

        cocotb.start_soon(check_delayed(clk, dut.ctrl_scl_o, 0))
        cocotb.start_soon(check_delayed(clk, dut.ctrl_sda_o, 0))
        await RisingEdge(clk)


