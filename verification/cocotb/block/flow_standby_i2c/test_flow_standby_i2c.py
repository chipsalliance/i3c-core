# SPDX-License-Identifier: Apache-2.0

from dataclasses import dataclass
from enum import IntEnum
import logging
import random

from cocotb_helpers import reset_n

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.queue import Queue, QueueEmpty, QueueFull
from cocotb.triggers import ClockCycles, RisingEdge


AwaitStart = 0
ReceiveByte = 1
PushDWordToTTIQueue = 2
ReportError = 3
PushResponseToTTIQueue = 4
PopCommandFromTTIQueue = 5
PopDWordFromTTIQueue = 6
SendByte = 7
SwitchByteToSend = 8
AwaitStopOrRestart = 9


class I2CByteID(IntEnum):
    AcqData = 0b000
    AcqStart = 0b001
    AcqStop = 0b010
    AcqRestart = 0b011
    AcqNack = 0b100
    AcqNackStart = 0b101
    AcqNackStop = 0b110


@dataclass
class TTICmdDesc:
    data_length: int
    end_of_transfer: int

    def pack(self):
        return (self.data_length & (2**16 - 1)) << 16 | (self.end_of_transfer & 0x1) << 15


class FlowStandbyTB:
    def __init__(self, dut) -> None:
        self.dut = dut


async def setup(dut):
    """Generic flow_standby_i2c testbench setup."""

    cocotb.log.setLevel(logging.INFO)
    # Start clock
    await cocotb.start(Clock(dut.clk_i, 2, "ns").start())
    await reset_n(dut.clk_i, dut.rst_ni, cycles=5)

    dut.acq_fifo_wvalid_i.value = 0
    dut.acq_fifo_wdata_i.value = 0
    dut.acq_fifo_wready_i.value = 0
    dut.tx_fifo_rready_i.value = 0
    dut.cmd_fifo_rdata_i.value = 0
    dut.cmd_fifo_rvalid_i.value = 0
    dut.response_fifo_wready_i.value = 0
    dut.tx_fifo_rdata_i.value = 0
    dut.tx_fifo_rvalid_i.value = 0
    dut.rx_fifo_wready_i.value = 0

    await ClockCycles(dut.clk_i, 10)


@cocotb.test()
async def test_reset(dut: SimHandleBase):
    await setup(dut)

    assert dut.acq_fifo_depth_o.value == 0
    assert dut.tx_fifo_rvalid_o.value == 0
    assert dut.tx_fifo_rdata_o.value == 0
    assert dut.cmd_fifo_rready_o.value == 0
    assert dut.response_fifo_wdata_o.value == 0
    assert dut.response_fifo_wvalid_o.value == 0
    assert dut.tx_fifo_rready_o.value == 0
    assert dut.rx_fifo_wdata_o.value == 0
    assert dut.rx_fifo_wvalid_o.value == 0
    assert dut.err_o.value == 0


async def test_detect(dut: SimHandleBase, byteID, state_indicator):
    await setup(dut)

    dut.acq_fifo_wvalid_i.value = 1
    dut.acq_fifo_wdata_i.value = byteID << 8

    for _ in range(2):
        await RisingEdge(dut.clk_i)
    assert state_indicator.value == 1


@cocotb.test()
async def test_detect_start(dut: SimHandleBase):
    await test_detect(dut, I2CByteID.AcqStart, dut.flow_standby_i2c.start_detected)


@cocotb.test()
async def test_detect_stop(dut: SimHandleBase):
    await test_detect(dut, I2CByteID.AcqStop, dut.flow_standby_i2c.stop_detected)


@cocotb.test()
async def test_detect_data(dut: SimHandleBase):
    await test_detect(dut, I2CByteID.AcqData, dut.flow_standby_i2c.data_detected)


@cocotb.test()
async def test_detect_nack(dut: SimHandleBase):
    await test_detect(dut, I2CByteID.AcqNack, dut.flow_standby_i2c.nack_detected)


@cocotb.test()
async def test_detect_restart(dut: SimHandleBase):
    await test_detect(dut, I2CByteID.AcqRestart, dut.flow_standby_i2c.restart_detected)

