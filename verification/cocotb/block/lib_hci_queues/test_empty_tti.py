# SPDX-License-Identifier: Apache-2.0

from common_methods import should_be_empty_after_rst

import cocotb
from cocotb.handle import SimHandleBase


@cocotb.test()
async def test_tti_tx_desc_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tti", "tx_desc")


@cocotb.test()
async def test_tti_rx_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tti", "rx")


@cocotb.test()
async def test_tti_rx_desc_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tti", "rx_desc")


@cocotb.test()
async def test_tti_tx_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tti", "tx")


@cocotb.test()
async def test_tti_ibi_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tti", "ibi")
