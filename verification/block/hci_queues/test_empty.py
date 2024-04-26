# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.handle import SimHandleBase
from hci_queues_defs import HCIQueuesTestInterface


async def should_be_empty_after_rst(dut: SimHandleBase, queue: str):
    queues = HCIQueuesTestInterface(dut)
    await queues.setup()  # Reset is performed with the setup
    assert queues.get_empty(queue) == 1, "Command queue should be empty after reset"


@cocotb.test()
async def run_cmd_capacity_status_test(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "cmd")


@cocotb.test()
async def run_rx_capacity_status_test(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "rx")


@cocotb.test()
async def run_resp_capacity_status_test(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "resp")


@cocotb.test()
async def run_tx_capacity_status_test(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tx")
