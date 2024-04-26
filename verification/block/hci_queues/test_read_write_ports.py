# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.handle import SimHandleBase
from hci_queues_defs import (
    ErrorStatus,
    HCIQueuesTestInterface,
    ResponseDescriptor,
    immediate_transfer_descriptor,
)


@cocotb.test()
async def issue_command_through_command_port(dut: SimHandleBase):
    """
    Enqueue immediate transfer command through COMMAND_PORT &
    verify the enqueued descriptor from the controller's side
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    cmd_desc = immediate_transfer_descriptor(0, 0, 0, 0, 1, 0, 0, 1, 1, 0xBEEF).to_int()
    await tb.put_command_desc(cmd_desc)

    received_desc = await tb.get_command_desc()
    assert (
        received_desc == cmd_desc
    ), f"Expected: {hex(cmd_desc)} command descriptor, got: {hex(received_desc)}"


@cocotb.test()
async def issue_data_through_xfer_data_port(dut: SimHandleBase):
    """
    Place TX data through XFER_DATA_PORT & verify it from the other (controller's) side of the queue
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    tx = 0xAAC0FFEE
    await tb.put_tx_data(tx)

    received_tx = await tb.get_tx_data()
    assert received_tx == tx, f"Expected: {hex(tx)} command descriptor, got: {hex(received_tx)}"


@cocotb.test()
async def fetch_read_data_from_xfer_data_port(dut: SimHandleBase):
    """
    Put read data onto the RX queue & fetch it through XFER_DATA_PORT
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()
    rx = 0xAAC0FFEE
    await tb.put_rx_data(rx)
    received_rx = await tb.get_rx_data()
    assert received_rx == rx, f"Expected: {hex(rx)} command descriptor, got: {hex(received_rx)}"


@cocotb.test()
async def fetch_response_from_response_port(dut: SimHandleBase):
    """
    Put response onto the response queue (from controller logic) & fetch it from
    the RESPONSE_PORT
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    resp = ResponseDescriptor(4, 42, ErrorStatus.SUCCESS).to_int()
    await tb.put_response_desc(resp)
    received_resp = await tb.get_response_desc()

    assert (
        received_resp == resp
    ), f"Expected: {hex(resp)} response descriptor, got: {hex(received_resp)}"
