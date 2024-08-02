# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.handle import SimHandleBase
from hci_queues import HCIQueuesTestInterface
from tti_queues import TTIQueuesTestInterface


async def should_be_empty_after_rst(dut: SimHandleBase, if_name: str, queue: str):
    assert if_name in ["hci", "tti"]
    if if_name == "hci":
        interface = HCIQueuesTestInterface(dut)
    elif if_name == "tti":
        interface = TTIQueuesTestInterface(dut)
    else:
        raise ValueError(f"Unsupported Queues type: {if_name}")
    await interface.setup()  # Reset is performed with the setup
    assert interface.get_empty(queue) == 1, "Command queue should be empty after reset"


@cocotb.test()
async def run_cmd_capacity_status_test(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "hci", "cmd")


@cocotb.test()
async def run_rx_capacity_status_test(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "hci", "rx")


@cocotb.test()
async def run_resp_capacity_status_test(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "hci", "resp")


@cocotb.test()
async def run_tx_capacity_status_test(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "hci", "tx")


@cocotb.test()
async def run_ibi_capacity_status_test(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "hci", "ibi")


@cocotb.test()
async def run_tti_tx_desc_capacity_status_test(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tti", "tx_desc")


@cocotb.test()
async def run_tti_rx_capacity_status_test(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tti", "rx")


@cocotb.test()
async def run_tti_rx_desc_capacity_status_test(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tti", "rx_desc")


@cocotb.test()
async def run_tti_tx_capacity_status_test(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tti", "tx")


@cocotb.test()
async def run_tti_ibi_capacity_status_test(dut: SimHandleBase):
    await should_be_empty_after_rst(dut, "tti", "ibi")
