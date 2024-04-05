# Copyright (c) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

import cocotb
from common import init_phy


@cocotb.test()
async def run_test(dut):
    """Run simple reset test."""
    clk = dut.clk
    rst_n = dut.rst_n

    await init_phy(clk, rst_n)

    assert dut.ctrl_scl_o.value == 0, "Incorrect value of SCL after module reset"
    assert dut.ctrl_sda_o.value == 0, "Incorrect value of SDA after module reset"
