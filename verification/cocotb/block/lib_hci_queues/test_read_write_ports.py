# SPDX-License-Identifier: Apache-2.0

from random import randint

from hci_queues import HCIQueuesTestInterface
from tti_queues import TTIQueuesTestInterface

import cocotb
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, Combine

TEST_SIZE = 5
QUEUE_SIZE = 64


async def test_write(data, write_handle):
    for e in data:
        await write_handle(e)


async def test_read(data, read_handle):
    for e in data:
        received_desc = await read_handle()
        assert e == received_desc, f"Expected: {hex(e)}, got: {hex(received_desc)}"


async def test_write_read(data, write_handle, read_handle):
    await test_write(data, write_handle)
    await test_read(data, read_handle)


@cocotb.test()
async def write_read_command_queue(dut: SimHandleBase):
    """
    Enqueue multiple transfers through COMMAND_PORT and verify
    whether the data matches after fetching it from the controller
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    cmd_data = [randint(1, 2**64 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(cmd_data, tb.put_command_desc, tb.get_command_desc)


@cocotb.test()
async def overflow_command_queue(dut: SimHandleBase):
    """
    Enqueue multiple transfers through COMMAND_PORT and verify
    whether the data matches after fetching it from the controller
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    cmd_data = [randint(1, 2**64 - 1) for _ in range(QUEUE_SIZE + TEST_SIZE)]
    await test_write(cmd_data[:-TEST_SIZE], tb.put_command_desc)

    write_coroutine = cocotb.start_soon(test_write(cmd_data[-TEST_SIZE:], tb.put_command_desc))
    await ClockCycles(tb.clk, 10)

    read_coroutine = cocotb.start_soon(test_read(cmd_data, tb.get_command_desc))

    await Combine(write_coroutine, read_coroutine)


@cocotb.test()
async def underflow_command_queue(dut: SimHandleBase):
    """
    Fetch data from Command Queue to cause underflow and write the data to ensure
    it's correct when available
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    cmd_data = [randint(1, 2**64 - 1) for _ in range(TEST_SIZE)]
    read_coroutine = cocotb.start_soon(test_read(cmd_data, tb.get_command_desc))
    await ClockCycles(tb.clk, 10)
    write_coroutine = cocotb.start_soon(test_write(cmd_data, tb.put_command_desc))

    await Combine(write_coroutine, read_coroutine)


@cocotb.test()
async def write_read_tx_queue(dut: SimHandleBase):
    """
    Place TX data through XFER_DATA_PORT & verify it from the other (controller's)
    side of the queue
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    tx_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(tx_data, tb.put_tx_data, tb.get_tx_data)


@cocotb.test()
async def overflow_tx_queue(dut: SimHandleBase):
    """
    Place TX data through XFER_DATA_PORT (and overflow it) & verify it from the
    other (controller's) side of the queue
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    tx_data = [randint(1, 2**32 - 1) for _ in range(QUEUE_SIZE + TEST_SIZE)]
    await test_write(tx_data[:-TEST_SIZE], tb.put_tx_data)

    write_coroutine = cocotb.start_soon(test_write(tx_data[-TEST_SIZE:], tb.put_tx_data))
    await ClockCycles(tb.clk, 10)

    read_coroutine = cocotb.start_soon(test_read(tx_data, tb.get_tx_data))

    await Combine(write_coroutine, read_coroutine)


@cocotb.test()
async def underflow_tx_queue(dut: SimHandleBase):
    """
    Fetch data from TX Queue to cause underflow and write the data to ensure
    it's correct when available
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    tx_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    read_coroutine = cocotb.start_soon(test_read(tx_data, tb.get_tx_data))
    await ClockCycles(tb.clk, 10)
    write_coroutine = cocotb.start_soon(test_write(tx_data, tb.put_tx_data))

    await Combine(write_coroutine, read_coroutine)


@cocotb.test()
async def write_read_rx_queue(dut: SimHandleBase):
    """
    Put read data onto the RX queue & fetch it through XFER_DATA_PORT
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    rx_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(rx_data, tb.put_rx_data, tb.get_rx_data)


@cocotb.test()
async def overflow_rx_queue(dut: SimHandleBase):
    """
    Put read data onto the RX queue (and overflow it) & fetch it through XFER_DATA_PORT
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    rx_data = [randint(1, 2**32 - 1) for _ in range(QUEUE_SIZE + TEST_SIZE)]
    await test_write(rx_data[:-TEST_SIZE], tb.put_rx_data)

    write_coroutine = cocotb.start_soon(test_write(rx_data[-TEST_SIZE:], tb.put_rx_data))
    await ClockCycles(tb.clk, 10)

    read_coroutine = cocotb.start_soon(test_read(rx_data, tb.get_rx_data))

    await Combine(write_coroutine, read_coroutine)


@cocotb.test()
async def underflow_rx_queue(dut: SimHandleBase):
    """
    Fetch data from RX Queue to cause underflow and write the data to ensure
    it's correct when available
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    rx_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    read_coroutine = cocotb.start_soon(test_read(rx_data, tb.get_rx_data))
    await ClockCycles(tb.clk, 10)
    write_coroutine = cocotb.start_soon(test_write(rx_data, tb.put_rx_data))

    await Combine(write_coroutine, read_coroutine)


@cocotb.test()
async def fetch_response_from_response_port(dut: SimHandleBase):
    """
    Put response into the response queue (from controller logic) & fetch it from
    the RESPONSE_PORT
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    resp_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(resp_data, tb.put_response_desc, tb.get_response_desc)


@cocotb.test()
async def overflow_response_queue(dut: SimHandleBase):
    """
    Put multiple response data into the response queue (from controller logic)
    to overflow it & fetch it from the RESPONSE_PORT
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    resp_data = [randint(1, 2**32 - 1) for _ in range(QUEUE_SIZE + TEST_SIZE)]
    await test_write(resp_data[:-TEST_SIZE], tb.put_response_desc)

    write_coroutine = cocotb.start_soon(test_write(resp_data[-TEST_SIZE:], tb.put_response_desc))
    await ClockCycles(tb.clk, 10)

    read_coroutine = cocotb.start_soon(test_read(resp_data, tb.get_response_desc))

    await Combine(write_coroutine, read_coroutine)


@cocotb.test()
async def underflow_response_queue(dut: SimHandleBase):
    """
    Fetch data from Response Queue to cause underflow and write the data to ensure
    it's correct when available
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    resp_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    read_coroutine = cocotb.start_soon(test_read(resp_data, tb.get_response_desc))
    await ClockCycles(tb.clk, 10)
    write_coroutine = cocotb.start_soon(test_write(resp_data, tb.put_response_desc))

    await Combine(write_coroutine, read_coroutine)


# ======================== TTI TESTS ========================
@cocotb.test()
async def write_read_tti_tx_desc_queue(dut: SimHandleBase):
    """
    Enqueue multiple transfers through TTI_TX_DESC_QUEUE_PORT and verify
    whether the data matches after fetching it from the controller
    """
    tb = TTIQueuesTestInterface(dut)
    await tb.setup()

    data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(data, tb.put_tx_desc, tb.get_tx_desc)


@cocotb.test()
async def underflow_tti_tx_desc_queue(dut: SimHandleBase):
    """
    Fetch data from Command Queue to cause underflow and write the data to ensure
    it's correct when available
    """
    tb = TTIQueuesTestInterface(dut)
    await tb.setup()

    data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    read_coroutine = cocotb.start_soon(test_read(data, tb.get_tx_desc))
    await ClockCycles(tb.clk, 10)
    write_coroutine = cocotb.start_soon(test_write(data, tb.put_tx_desc))

    await Combine(write_coroutine, read_coroutine)


@cocotb.test()
async def write_read_tti_tx_queue(dut: SimHandleBase):
    """
    Place TX data through XFER_DATA_PORT & verify it from the other (controller's)
    side of the queue
    """
    tb = TTIQueuesTestInterface(dut)
    await tb.setup()

    tx_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(tx_data, tb.put_tx_data, tb.get_tx_data)


@cocotb.test()
async def underflow_tti_tx_queue(dut: SimHandleBase):
    """
    Fetch data from TX Queue to cause underflow and write the data to ensure
    it's correct when available
    """
    tb = TTIQueuesTestInterface(dut)
    await tb.setup()

    tx_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    read_coroutine = cocotb.start_soon(test_read(tx_data, tb.get_tx_data))
    await ClockCycles(tb.clk, 10)
    write_coroutine = cocotb.start_soon(test_write(tx_data, tb.put_tx_data))

    await Combine(write_coroutine, read_coroutine)


@cocotb.test()
async def write_read_tti_rx_queue(dut: SimHandleBase):
    """
    Put read data onto the RX queue & fetch it through XFER_DATA_PORT
    """
    tb = TTIQueuesTestInterface(dut)
    await tb.setup()

    rx_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(rx_data, tb.put_rx_data, tb.get_rx_data)


@cocotb.test()
async def overflow_tti_rx_queue(dut: SimHandleBase):
    """
    Put read data onto the RX queue (and overflow it) & fetch it through XFER_DATA_PORT
    """
    tb = TTIQueuesTestInterface(dut)
    await tb.setup()

    rx_data = [randint(1, 2**32 - 1) for _ in range(QUEUE_SIZE + TEST_SIZE)]
    await test_write(rx_data[:-TEST_SIZE], tb.put_rx_data)

    write_coroutine = cocotb.start_soon(test_write(rx_data[-TEST_SIZE:], tb.put_rx_data))
    await ClockCycles(tb.clk, 10)

    read_coroutine = cocotb.start_soon(test_read(rx_data, tb.get_rx_data))

    await Combine(write_coroutine, read_coroutine)


@cocotb.test()
async def fetch_response_from_tti_rx_desc_port(dut: SimHandleBase):
    """
    Put response into the response queue (from controller logic) & fetch it from
    the RESPONSE_PORT
    """
    tb = TTIQueuesTestInterface(dut)
    await tb.setup()

    data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(data, tb.put_rx_desc, tb.get_rx_desc)


@cocotb.test()
async def overflow_tti_rx_desc_queue(dut: SimHandleBase):
    """
    Put multiple response data into the response queue (from controller logic)
    to overflow it & fetch it from the RESPONSE_PORT
    """
    tb = TTIQueuesTestInterface(dut)
    await tb.setup()

    data = [randint(1, 2**32 - 1) for _ in range(QUEUE_SIZE + TEST_SIZE)]
    await test_write(data[:-TEST_SIZE], tb.put_rx_desc)

    write_coroutine = cocotb.start_soon(test_write(data[-TEST_SIZE:], tb.put_rx_desc))
    await ClockCycles(tb.clk, 10)

    read_coroutine = cocotb.start_soon(test_read(data, tb.get_rx_desc))

    await Combine(write_coroutine, read_coroutine)


@cocotb.test()
async def write_read_ibi_queue(dut: SimHandleBase):
    """
    Put read data onto the IBI queue & fetch it through IBI_PORT
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    ibi_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(ibi_data, tb.put_ibi_data, tb.get_ibi_data)


@cocotb.test()
async def underflow_ibi_queue(dut: SimHandleBase):
    """
    Fetch data from IBI Queue to cause underflow and write the data to ensure
    it's correct when available
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()

    ibi_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    read_coroutine = cocotb.start_soon(test_read(ibi_data, tb.get_ibi_data))
    await ClockCycles(tb.clk, 10)
    write_coroutine = cocotb.start_soon(test_write(ibi_data, tb.put_ibi_data))

    await Combine(write_coroutine, read_coroutine)
