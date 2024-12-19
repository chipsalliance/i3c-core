# SPDX-License-Identifier: Apache-2.0

import random

from ccc import CCC
from cocotb_helpers import cycle, reset_n

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, RisingEdge, with_timeout

_STATUS = 0xC64B


async def setup(dut):
    """
    Initialize inputs of the DUT
    """
    dut.get_mwl_i.value = random.randint(0, 2**16 - 1)
    dut.get_mrl_i.value = random.randint(0, 2**16 - 1)
    dut.get_pid_i.value = random.randint(0, 2**48 - 1)
    dut.get_bcr_i.value = random.randint(0, 2**8 - 1)
    dut.get_dcr_i.value = random.randint(0, 2**8 - 1)
    dut.get_status_fmt1_i.value = _STATUS

    dut.target_sta_address_i.value = 0x2D
    dut.target_sta_address_valid_i.value = 1
    dut.target_dyn_address_i.value = 0
    dut.target_dyn_address_valid_i.value = 0

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
    val = dut.bus_tx_req_value_o.value
    await ClockCycles(dut.clk_i, 3)
    await cycle(dut.clk_i, dut.bus_tx_done_i)
    return val


async def tx_byte(dut):
    await RisingEdge(dut.bus_tx_req_byte_o)
    await ClockCycles(dut.clk_i, 10)
    await cycle(dut.clk_i, dut.bus_tx_done_i)


async def get_status(dut):
    # CCC
    await ClockCycles(dut.clk_i, 7)
    dut.ccc_i.value = CCC.DIRECT.GETSTATUS
    await cycle(dut.clk_i, dut.ccc_valid_i)

    # T-bit
    await rx_bit(dut, 0)

    # RS
    await ClockCycles(dut.clk_i, 5)
    await cycle(dut.clk_i, dut.bus_rstart_det_i)

    # Target Address
    await rx_byte(dut, 0x5B)

    # ACK
    await tx_bit(dut)

    # RX Bytes
    last_byte = False
    status = []
    while not last_byte:
        await tx_byte(dut)
        status.append(dut.bus_tx_req_value_o.value)
        # T-bit
        tbit = await tx_bit(dut)
        last_byte = tbit == 0

    # Stop the frame
    await cycle(dut.clk_i, dut.bus_stop_det_i)
    await ClockCycles(dut.clk_i, 5)

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

    status = await with_timeout(get_status(dut), 200, "ns")
    _status = (status[0] << 8) | (status[1])
    print(f"Test returned {hex(_status)}")
    assert _status == _STATUS
