# SPDX-License-Identifier: Apache-2.0

from common_methods import should_be_empty_after_rst
from cocotb.handle import SimHandleBase
from utils import controller_test


@controller_test()
async def test_cmd_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "hci", "cmd")


@controller_test()
async def test_rx_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "hci", "rx")


@controller_test()
async def test_resp_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "hci", "resp")


@controller_test()
async def test_tx_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "hci", "tx")


@controller_test()
async def test_ibi_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "hci", "ibi")
