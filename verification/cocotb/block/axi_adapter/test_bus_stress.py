# SPDX-License-Identifier: Apache-2.0

import logging
import random

from bus2csr import (
    FrontBusTestInterface,
    compare_values,
    dword2int,
    get_frontend_bus_if,
    int2bytes,
    int2dword,
)
from utils import mask_bits, rand_bits, rand_bits32

import cocotb
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, Combine, Event, RisingEdge, Timer, with_timeout
from cocotb_helpers import reset_n

from cocotbext.axi.constants import AxiBurstType


async def timeout_task(timeout):
    await Timer(timeout, "us")
    raise RuntimeError("Test timeout!")


async def initialize(dut, timeout=50):
    """
    Common test initialization routine which sets up environment and starts a timeout coroutine
    to observe whether the test did not fall in infinite loop.
    """

    cocotb.log.setLevel(logging.DEBUG)

    # Start the background timeout task
    cocotb.start_soon(timeout_task(timeout))

    # Initialize inputs
    dut.araddr.value = 0
    dut.arburst.value = 0
    dut.arsize.value = 0
    dut.arlen.value = 0
    dut.aruser.value = 0
    dut.arid.value = 0
    dut.arlock.value = 0
    dut.arvalid.value = 0
    dut.rready.value = 0
    dut.awaddr.value = 0
    dut.awburst.value = 0
    dut.awsize.value = 0
    dut.awlen.value = 0
    dut.awuser.value = 0
    dut.awid.value = 0
    dut.awlock.value = 0
    dut.awvalid.value = 0
    dut.wdata.value = 0
    dut.wstrb.value = 0
    dut.wlast.value = 0
    dut.wvalid.value = 0
    dut.bready.value = 0

    # Configure testbench
    tb = get_frontend_bus_if()(dut)
    tb.log = dut._log
    await tb.register_test_interfaces()
    await ClockCycles(tb.clk, 20)
    await reset_n(tb.clk, tb.rst_n, cycles=5)

    data_len = random.randint(10, 100)
    test_data = [random.randint(0, 2**32 - 1) for _ in range(data_len)]

    tb.log.info(f"Generated {data_len} dwords to transfer.")

    return tb, data_len, test_data


@cocotb.test()
async def test_collision_with_write(dut):
    tb, data_len, test_data = await initialize(dut)

    fifo_addr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    async def writer():
        # Write sequence should just write data
        for d in test_data:
            await tb.write_csr(fifo_addr, int2bytes(d))
            # Wait for read to finish to avoid multiple writes per read
            await tb.axi_m.wait_read()

    async def reader(return_data):
        # Wait until there is data in FIFO
        read_offset = 2
        while int(dut.fifo_depth_o.value) < read_offset:
            await RisingEdge(tb.clk)

        # Read sequence should read data on each write data
        for i in range(data_len):
            # Awaiting `awvalid` causes reading simultaneously with write data channel activity
            if i < (data_len - read_offset):
                await RisingEdge(dut.awvalid)
            return_data.append(dword2int(await tb.read_csr(fifo_addr)))

    received_data = []
    w = cocotb.start_soon(writer())
    r = cocotb.start_soon(reader(received_data))

    await Combine(w, r)

    assert received_data == test_data, "Received data does not match sent data!"

    tb.log.info("Test finished!")


@cocotb.test()
async def test_collision_with_read(dut):
    tb, data_len, test_data = await initialize(dut)

    fifo_addr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    async def writer():
        # Write sequence should write data on each read data
        for i, d in enumerate(test_data):
            # Awaiting read request causes writing simultaneously with read data channel activity
            if i > 2:
                await RisingEdge(dut.s_cpuif_req)
                assert not dut.s_cpuif_req_is_wr.value
                # Wait additional cycle to line up write with FIFO read delay
                await RisingEdge(tb.clk)
            await tb.write_csr(fifo_addr, int2dword(d))

    async def reader(return_data):
        # Wait until there is data in FIFO
        read_offset = 2
        while int(dut.fifo_depth_o.value) < read_offset:
            await RisingEdge(tb.clk)

        # Read sequence should just read data
        for _ in range(data_len):
            # Wait for write to finish to avoid multiple reads per write
            await tb.axi_m.wait_write()
            return_data.append(dword2int(await tb.read_csr(fifo_addr)))
            await RisingEdge(tb.clk)

    received_data = []
    w = cocotb.start_soon(writer())
    r = cocotb.start_soon(reader(received_data))

    await Combine(w, r)

    assert received_data == test_data, "Received data does not match sent data!"

    tb.log.info("Test finished!")


@cocotb.test()
async def test_write_read_burst(dut):
    tb, data_len, test_data = await initialize(dut)

    fifo_addr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    await with_timeout(tb.axi_m.write_dwords(fifo_addr, test_data, burst=AxiBurstType.FIXED), 1, "us")
    received_data = await with_timeout(tb.axi_m.read_dwords(fifo_addr, count=data_len, burst=AxiBurstType.FIXED), 1, "us")

    assert received_data == test_data, "Received data does not match sent data!"


@cocotb.test(skip=True)
async def test_read_burst_collision_with_write(dut):
    tb, data_len, test_data = await initialize(dut)

    fifo_addr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr


@cocotb.test(skip=True)
async def test_write_burst_collision_with_read(dut):
    tb, data_len, test_data = await initialize(dut)

    fifo_addr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr
