# SPDX-License-Identifier: Apache-2.0

from cocotb_helpers import cycle, reset_n

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles


async def setup(dut):
    """ """
    await ClockCycles(dut.clk_i, 10)


@cocotb.test()
async def test_descriptor_tx(dut: SimHandleBase):
    """ """
    cocotb.log.setLevel("INFO")
    clk = dut.clk_i
    rst_n = dut.rst_ni

    clock = Clock(clk, 2, units="ns")
    cocotb.start_soon(clock.start())

    await setup(dut)
    await reset_n(clk, rst_n, cycles=5)

    # Send descriptor

    dut.tti_tx_desc_queue_rdata_i.value = 0x5
    await cycle(dut.clk_i, dut.tti_tx_desc_queue_rvalid_i)

    # Send data
    dut.tti_tx_queue_rvalid_i.value = 1

    dut.tti_tx_queue_depth_i.value = 5
    data = [i for i in range(6)]
    data_id = 0
    dut.tti_tx_queue_rdata_i.value = data[data_id]

    for _ in range(5):
        await cycle(dut.clk_i, dut.tx_byte_ready_i)
        await ClockCycles(dut.clk_i, 3)
        data_id += 1
        dut.tti_tx_queue_rdata_i.value = data[data_id]

    print(dut.tx_byte_o.value)
    print(dut.tx_byte_last_o.value)
    print(dut.tx_byte_valid_o.value)
