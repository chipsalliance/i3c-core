# SPDX-License-Identifier: Apache-2.0

from cocotb_helpers import reset_n, cycle
from cocotbext_i3c.i3c_controller import I3cController

import cocotb
import random
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, RisingEdge, with_timeout, First
from ccc import CCC

async def setup(dut):
    """
        Initialize inputs of the DUT
    """
    dut.get_mwl_i.value = random.randint(0, 2**16-1)
    dut.get_mrl_i.value = random.randint(0, 2**16-1)
    dut.get_pid_i.value = random.randint(0, 2**48-1)
    dut.get_bcr_i.value = random.randint(0, 2**8-1)
    dut.get_dcr_i.value = random.randint(0, 2**8-1)
    dut.get_status_fmt1_i.value =random.randint(0, 2**16-1)
    await ClockCycles(dut.clk_i, 10)


async def rx_bit(dut, value):
    """
        Send bit on the RX interface
    """
    await RisingEdge(dut.bus_rx_req_bit_o)
    await ClockCycles(dut.clk_i, 3)
    dut.bus_rx_data_i.value = value
    await cycle(dut.clk_i, dut.bus_rx_done_i)

async def rx_byte(dut, value):
    """
        Send byte on the RX interface
    """
    await RisingEdge(dut.bus_rx_req_byte_o)
    await ClockCycles(dut.clk_i, 3)
    dut.bus_rx_data_i.value = value
    await cycle(dut.clk_i, dut.bus_rx_done_i)

async def tx_bit(dut):
    await RisingEdge(dut.bus_tx_req_bit_o)
    await ClockCycles(dut.clk_i, 3)
    await cycle(dut.clk_i, dut.bus_tx_done_i)

async def tx_byte(dut):
    await RisingEdge(dut.bus_tx_req_byte_o)
    await ClockCycles(dut.clk_i, 10)
    await cycle(dut.clk_i, dut.bus_tx_done_i)

async def ccc_rdata(dut):
    """

    """
    # CCC
    await ClockCycles(dut.clk_i, 7)
    dut.ccc_i.value = CCC.DIRECT.GETBCR
    await cycle(dut.clk_i, dut.ccc_valid_i)

    # T-bit
    await rx_bit(dut, 0)

    # RS
    await ClockCycles(dut.clk_i, 5)
    await cycle(dut.clk_i, dut.bus_start_det_i)

    # Target Address
    await rx_byte(dut, 0x5A)

    # ACK
    await tx_bit(dut)

    # BCR
    await tx_byte(dut)
    rdata = dut.bus_tx_req_value_o.value
    # T-bit
    await tx_bit(dut)

    # Stop the frame
    await cycle(dut.clk_i, dut.bus_stop_det_i)

    return rdata

async def get_ccc(dut):
    status = await ccc_rdata(dut)
    return status

@cocotb.test()
async def test_ccc(dut: SimHandleBase):
    """
        Test CCC
    """
    cocotb.log.setLevel("INFO")
    clk = dut.clk_i
    rst_n = dut.rst_ni

    clock = Clock(clk, 2, units="ns")
    cocotb.start_soon(clock.start())

    await setup(dut)
    await reset_n(clk, rst_n, cycles=5)

    status = await with_timeout(get_ccc(dut), 200, 'ns')
    print(f"Test returned {status}")
    # assert status == 0xFACE
