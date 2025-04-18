# SPDX-License-Identifier: Apache-2.0

from random import randint

from common_methods import test_write, test_read, test_write_read
from tti_queues import TTIQueuesTestInterface

import cocotb
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, Combine
from utils import target_test
TEST_SIZE = 5
QUEUE_SIZE = 64


@target_test()
async def write_read_tti_tx_desc_queue(dut: SimHandleBase):
    """
    Enqueue multiple transfers through TTI_TX_DESC_QUEUE_PORT and verify
    whether the data matches after fetching it from the controller
    """
    tb = TTIQueuesTestInterface(dut)
    await tb.setup()

    data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(data, tb.put_tx_desc, tb.get_tx_desc)


@target_test()
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


@target_test()
async def write_read_tti_tx_queue(dut: SimHandleBase):
    """
    Place TX data through XFER_DATA_PORT & verify it from the other (controller's)
    side of the queue
    """
    tb = TTIQueuesTestInterface(dut)
    await tb.setup()

    tx_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(tx_data, tb.put_tx_data, tb.get_tx_data)


@target_test()
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


@target_test()
async def write_read_tti_rx_queue(dut: SimHandleBase):
    """
    Put read data onto the RX queue & fetch it through XFER_DATA_PORT
    """
    tb = TTIQueuesTestInterface(dut)
    await tb.setup()

    rx_data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(rx_data, tb.put_rx_data, tb.get_rx_data)


@target_test()
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


@target_test()
async def fetch_response_from_tti_rx_desc_port(dut: SimHandleBase):
    """
    Put response into the response queue (from controller logic) & fetch it from
    the RESPONSE_PORT
    """
    tb = TTIQueuesTestInterface(dut)
    await tb.setup()

    data = [randint(1, 2**32 - 1) for _ in range(TEST_SIZE)]
    await test_write_read(data, tb.put_rx_desc, tb.get_rx_desc)


@target_test()
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
