# SPDX-License-Identifier: Apache-2.0

from common_methods import should_be_empty_after_rst
import cocotb
from cocotb.handle import SimHandleBase


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_cmd_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "hci", "cmd")


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_rx_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "hci", "rx")


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_resp_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "hci", "resp")


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_tx_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "hci", "tx")


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_ibi_capacity_status(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "hci", "ibi")
