# SPDX-License-Identifier: Apache-2.0

from common_methods import should_be_empty_after_rst

from cocotb.handle import SimHandleBase
from utils import target_test


@target_test()
async def test_tti_tx_desc_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tti", "tx_desc")


@target_test()
async def test_tti_rx_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tti", "rx")


@target_test()
async def test_tti_rx_desc_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tti", "rx_desc")


@target_test()
async def test_tti_tx_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tti", "tx")


@target_test()
async def test_tti_ibi_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tti", "ibi")
