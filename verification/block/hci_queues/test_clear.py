# SPDX-License-Identifier: Apache-2.0

from random import randint

import cocotb
from cocotb.handle import SimHandleBase
from hci_queues_defs import (
    RESET_CONTROL,
    ErrorStatus,
    HCIQueuesTestInterface,
    ResponseDescriptor,
    immediate_transfer_descriptor,
)
from test_csr_sw_access import ahb_data_to_int, int_to_ahb_data


@cocotb.test()
async def run_clear_on_nonempty_resp_queue(dut: SimHandleBase):
    """
    Issue Response queue clear through RESET_CONTROL and verify the newly enqueued
    response will be returned on the read
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    resp = ResponseDescriptor(4, 42, ErrorStatus.SUCCESS).to_int()
    for _ in range(10):
        await tb.put_response_desc(resp)
    await tb.write_csr(RESET_CONTROL, int_to_ahb_data(1 << 2), 4)

    # Respond queue reset bit should be cleared after successful soft reset
    while ahb_data_to_int(await tb.read_csr(RESET_CONTROL, 4), 4):
        pass

    # Enqueue a new response & ensure no other response was in the FIFO
    resp = ResponseDescriptor(4, 44, ErrorStatus.HC_ABORTED).to_int()
    await tb.put_response_desc(resp)
    received_resp = await tb.get_response_desc()

    assert (
        received_resp == resp
    ), f"Expected: {hex(resp)} response descriptor, got: {hex(received_resp)}"


@cocotb.test()
async def run_clear_on_nonempty_cmd_queue(dut: SimHandleBase):
    """
    Issue Command queue clear through RESET_CONTROL and verify the newly enqueued
    command will be returned on the read
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    for i in range(10):
        cmd = immediate_transfer_descriptor(i, 0, 0, 0, 1, 0, 0, 1, 1, 0xBEEF).to_int()
        # Command is expected to be sent over 2 transfers
        await tb.put_command_desc(cmd)

    await tb.write_csr(RESET_CONTROL, int_to_ahb_data(1 << 1), 4)
    # Respond queue reset bit should be cleared after successful soft reset
    while ahb_data_to_int(await tb.read_csr(RESET_CONTROL, 4), 4):
        pass

    # Enqueue a new command & ensure no other command was in the FIFO
    cmd = immediate_transfer_descriptor(i, 0, 0, 0, 1, 0, 0, 1, 1, 0xBEEF).to_int()
    await tb.put_command_desc(cmd)
    received_cmd = await tb.get_command_desc()

    assert received_cmd == cmd, f"Expected: {hex(cmd)} command descriptor, got: {hex(received_cmd)}"


@cocotb.test()
async def run_clear_on_nonempty_rx_queue(dut: SimHandleBase):
    """
    Issue RX queue clear through RESET_CONTROL and verify the newly enqueued
    data will be returned on the read
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    for _ in range(10):
        await tb.put_rx_data(randint(0, 4294967295))
    await tb.write_csr(RESET_CONTROL, int_to_ahb_data(1 << 4), 4)

    # Respond queue reset bit should be cleared after successful soft reset
    while ahb_data_to_int(await tb.read_csr(RESET_CONTROL, 4), 4):
        pass

    # Enqueue a new response & ensure no other response was in the FIFO
    rx = 0xC0FFEE
    await tb.put_rx_data(rx)
    received_rx = await tb.get_rx_data()

    assert received_rx == rx, f"Expected: {hex(rx)} data from RX fifo, got: {hex(received_rx)}"


@cocotb.test()
async def run_clear_on_nonempty_tx_queue(dut: SimHandleBase):
    """
    Issue TX queue clear through RESET_CONTROL and verify the newly enqueued
    data will be returned on the read
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    for _ in range(10):
        await tb.put_tx_data()

    await tb.write_csr(RESET_CONTROL, int_to_ahb_data(1 << 3), 4)
    # Respond queue reset bit should be cleared after successful soft reset
    while ahb_data_to_int(await tb.read_csr(RESET_CONTROL, 4), 4):
        pass

    # Enqueue a new command & ensure no other command was in the FIFO
    tx = 0xC0FFEE
    await tb.put_tx_data(tx)
    received_tx = await tb.get_tx_data()

    assert received_tx == tx, f"Expected: {hex(tx)} data from TX fifo, got: {hex(received_tx)}"
