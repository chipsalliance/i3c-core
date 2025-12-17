# SPDX-License-Identifier: Apache-2.0

from cocotb_helpers import cycle, reset_n

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles


async def setup(dut):
    """ """
    dut.tti_rx_queue_wready_i.value = 1
    dut.rx_byte_last_i.value = 0
    dut.rx_byte_err_i.value = 0
    dut.rx_byte_valid_i.value = 0
    await ClockCycles(dut.clk_i, 10)


async def send_byte(dut, value):
    """ """
    dut.rx_byte_i = value
    await cycle(dut.clk_i, dut.rx_byte_valid_i)


@cocotb.test()
async def test_descriptor_rx(dut: SimHandleBase):
    """
    Test RX descriptor:
    - no errors
    - RX FIFO is never full
    """
    cocotb.log.setLevel("INFO")
    clk = dut.clk_i
    rst_n = dut.rst_ni

    clock = Clock(clk, 2, units="ns")
    cocotb.start_soon(clock.start())

    await setup(dut)
    await reset_n(clk, rst_n, cycles=5)

    assert dut.rx_byte_ready_o.value == 1

    # Send 5 bytes and wait for the RX descriptor
    for i in range(5):
        await send_byte(dut, i)
    await cycle(dut.clk_i, dut.rx_byte_last_i)

    await ClockCycles(dut.clk_i, 1)
    assert dut.tti_rx_desc_queue_wvalid_o.value == 1
    assert dut.tti_rx_desc_queue_wdata_o.value == 5

    await ClockCycles(dut.clk_i, 3)
