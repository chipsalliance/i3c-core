# SPDX-License-Identifier: Apache-2.0

from random import randint

import cocotb
from cocotb.handle import SimHandleBase
from interface import HCIQueuesTestInterface

TEST_SIZE = 5


async def test_write_read(data, write_handle, read_handle):
    for e in data:
        await write_handle(e)

    for e in data:
        received_desc = await read_handle()
        assert e == received_desc, f"Expected: {hex(e)}, got: {hex(received_desc)}"


@cocotb.test()
async def issue_command_through_command_port(dut: SimHandleBase):
    """
    Enqueue immediate transfer command through COMMAND_PORT &
    verify the enqueued descriptor from the controller's side
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    cmd_data = [randint(1, 2**64 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(cmd_data, tb.put_command_desc, tb.get_command_desc)


@cocotb.test()
async def issue_data_through_xfer_data_port(dut: SimHandleBase):
    """
    Place TX data through XFER_DATA_PORT & verify it from the other (controller's) side of the queue
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    tx_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(tx_data, tb.put_tx_data, tb.get_tx_data)


@cocotb.test()
async def fetch_read_data_from_xfer_data_port(dut: SimHandleBase):
    """
    Put read data onto the RX queue & fetch it through XFER_DATA_PORT
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    rx_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(rx_data, tb.put_rx_data, tb.get_rx_data)


@cocotb.test()
async def fetch_response_from_response_port(dut: SimHandleBase):
    """
    Put response onto the response queue (from controller logic) & fetch it from
    the RESPONSE_PORT
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    resp_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(resp_data, tb.put_response_desc, tb.get_response_desc)
