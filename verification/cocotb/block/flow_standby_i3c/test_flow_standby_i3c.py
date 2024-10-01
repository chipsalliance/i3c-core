# SPDX-License-Identifier: Apache-2.0

import logging
import random

from cocotb_helpers import cycle, reset_n

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.queue import Queue, QueueEmpty, QueueFull
from cocotb.triggers import ClockCycles


async def setup(dut):
    """ """
    dut.enable_i.value = 1
    await ClockCycles(dut.clk_i, 10)


class RxQueue:
    """
    Class to mock RX Queue
    """

    def __init__(self, dut):
        self.full = dut.rx_queue_full_i
        self.empty = dut.rx_queue_empty_i
        self.wvalid = dut.rx_queue_wvalid_o
        self.wready = dut.rx_queue_wready_i
        self.wdata = dut.rx_queue_wdata_o
        self.q = Queue()

    async def bfm(self, dut):
        while True:
            self.empty.value = self.q.empty()
            self.full.value = self.q.full()
            if not self.full.value:
                self.wready.value = 1

            if self.wvalid.value and self.wready.value:
                try:
                    self.q.put_nowait(self.wdata.value)
                    print(f"Data written to queue: {self.wdata.value}")
                except QueueFull:
                    print("Queue is already full")
                    pass
            await ClockCycles(dut.clk_i, 1)


class TxQueue:
    """
    Class to mock TX Queue
    """

    def __init__(self, dut):
        self.full = dut.tx_queue_full_i
        self.empty = dut.tx_queue_empty_i
        self.rvalid = dut.tx_queue_rvalid_i
        self.rready = dut.tx_queue_rready_o
        self.rdata = dut.tx_queue_rdata_i
        self.q = Queue()
        random.seed(10)

    def add_data(self, N):
        """
        Add N random entries to the queue.
        """
        for i in range(N):
            self.q.put_nowait(random.randint(0, 1023))

    def _peek(self):
        """
        Return first element of the queue without removing it from the queue.
        """
        return self.q._queue[0]

    async def bfm(self, dut):
        self.add_data(10)
        self.rdata.value = self._peek()
        while True:
            self.empty.value = self.q.empty()
            self.full.value = self.q.full()
            if not self.empty.value:
                self.rvalid.value = 1

            if self.rvalid.value and self.rready.value:
                try:
                    self.rdata.value = self.q.get_nowait()
                    print(f"Data read from queue: {self.rdata.value}")
                except QueueEmpty:
                    print("Queue is already empty")
                    pass
            await ClockCycles(dut.clk_i, 1)


async def bus_tx(dut):
    clk = dut.clk_i
    # Signal TX
    dut.transfer_type_i.value = 0

    # Signal START
    await cycle(clk, dut.transfer_stop_i)

    # Receive byte from the bus
    dut.rx_byte_valid_i.value = 1
    dut.rx_byte_i.value = 0x21
    while not dut.rx_byte_ready_o.value:
        await ClockCycles(clk, 1)
    dut.rx_byte_valid_i.value = 0

    # Signal STOP
    await ClockCycles(clk, 3)
    await cycle(clk, dut.transfer_stop_i)


@cocotb.test()
async def test_rx(dut: SimHandleBase):
    """
    Test sending data to the bus
    """
    cocotb.log.setLevel(logging.INFO)
    # Start clock
    clock = Clock(dut.clk_i, 2, units="ns")
    cocotb.start_soon(clock.start())

    # RxQueue
    rx_queue = RxQueue(dut)
    tx_queue = TxQueue(dut)
    clk = dut.clk_i
    rst_n = dut.rst_ni
    rst_n.value = 1

    await setup(dut)
    await reset_n(clk, rst_n, cycles=5)
    await setup(dut)

    cocotb.start_soon(rx_queue.bfm(dut))
    cocotb.start_soon(tx_queue.bfm(dut))

    await bus_tx(dut)

    await ClockCycles(clk, 50)
