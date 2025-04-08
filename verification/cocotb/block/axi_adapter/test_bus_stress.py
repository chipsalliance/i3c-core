# SPDX-License-Identifier: Apache-2.0

import logging
import random

from bus2csr import dword2int, get_frontend_bus_if, int2bytes, int2dword
from cocotb_helpers import reset_n
from cocotbext.axi.constants import AxiBurstType

import cocotb
from cocotb.triggers import ClockCycles, Combine, RisingEdge, Timer, with_timeout


async def timeout_task(timeout):
    await Timer(timeout, "us")
    raise RuntimeError("Test timeout!")


async def initialize(dut, timeout=50):
    """
    Common test initialization routine which sets up environment and starts a timeout coroutine
    to observe whether the test did not fall into infinite loop.
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
    dut.wuser.value = 0
    dut.wlast.value = 0
    dut.wvalid.value = 0
    dut.bready.value = 0

    if hasattr(dut, "disable_id_filtering_i"):
        dut.disable_id_filtering_i.value = 1

    # Configure testbench
    tb = get_frontend_bus_if()(dut)
    tb.log = dut._log
    await tb.register_test_interfaces()
    await reset_n(tb.clk, tb.rst_n, cycles=5)

    # Generate test data
    data_len = random.randint(10, 64)
    test_data = [random.randint(0, 2**32 - 1) for _ in range(data_len)]

    tb.log.info(f"Generated {data_len} dwords to transfer.")

    return tb, data_len, test_data


@cocotb.test()
async def test_collision_with_write(dut):
    tb, data_len, test_data = await initialize(dut)

    waddr = tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr
    raddr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    async def writer():
        # Write sequence should just write data
        for d in test_data:
            await tb.write_csr(waddr, int2bytes(d))
            # Wait for read to finish in order to avoid multiple writes per read
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
            return_data.append(dword2int(await tb.read_csr(raddr)))

    received_data = []
    w = cocotb.start_soon(writer())
    r = cocotb.start_soon(reader(received_data))

    await Combine(w, r)

    assert received_data == test_data, "Received data does not match sent data!"

    tb.log.info("Test finished!")


@cocotb.test()
async def test_collision_with_read(dut):
    tb, data_len, test_data = await initialize(dut)

    waddr = tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr
    raddr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    read_offset = 2

    async def writer():
        # Write sequence should write data on each read data
        for i, d in enumerate(test_data):
            # Load first two dwords independently
            if i > read_offset:
                # Awaiting read request causes writing simultaneously with read data channel activity
                await RisingEdge(dut.s_cpuif_req)
                assert not dut.s_cpuif_req_is_wr.value
                # Wait additional cycle to line up write with FIFO read delay
                await RisingEdge(tb.clk)
            await tb.write_csr(waddr, int2dword(d))

    async def reader(return_data):
        # Wait until there is data in FIFO
        while int(dut.fifo_depth_o.value) < read_offset:
            await RisingEdge(tb.clk)

        # Read sequence should just read data
        for _ in range(data_len):
            # Wait for write to finish to avoid multiple reads per write
            await tb.axi_m.wait_write()
            return_data.append(dword2int(await tb.read_csr(raddr)))
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

    waddr = tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr
    raddr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    # Run write burst to fill the FIFO
    await with_timeout(
        tb.axi_m.write_dwords(waddr, test_data, burst=AxiBurstType.FIXED), 1, "us"
    )

    # Run read burst to empty the FIFO
    received_data = await with_timeout(
        tb.axi_m.read_dwords(raddr, count=data_len, burst=AxiBurstType.FIXED), 1, "us"
    )

    assert received_data == test_data, "Received data does not match sent data!"

    tb.log.info("Test finished!")


@cocotb.test()
async def test_write_burst_collision_with_read(dut):
    tb, data_len, test_data = await initialize(dut)

    waddr = tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr
    raddr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    # Time in clock cycles to perform single dword write
    single_write_cycles = 3

    async def writer():
        await with_timeout(
            tb.axi_m.write_dwords(waddr, test_data, burst=AxiBurstType.FIXED), 1, "us"
        )

    async def reader(return_data):
        return_data.extend(
            await with_timeout(
                tb.axi_m.read_dwords(raddr, count=data_len, burst=AxiBurstType.FIXED), 1, "us"
            )
        )

    received_data = []
    half_write_timer = ClockCycles(tb.clk, data_len * single_write_cycles // 2)

    # Request write burst
    w = cocotb.start_soon(writer())
    await half_write_timer

    # Request read burst during write burst, should wait for write to finish
    r = cocotb.start_soon(reader(received_data))

    await Combine(w, r)

    assert received_data == test_data, "Received data does not match sent data!"

    tb.log.info("Test finished!")


@cocotb.test()
async def test_read_burst_collision_with_write(dut):
    tb, data_len, test_data = await initialize(dut)

    waddr = tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr
    raddr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    # Time in clock cycles to perform single dword write
    single_write_cycles = 3

    async def writer():
        await with_timeout(
            tb.axi_m.write_dwords(waddr, test_data, burst=AxiBurstType.FIXED), 1, "us"
        )

    async def reader(return_data):
        return_data.extend(
            await with_timeout(
                tb.axi_m.read_dwords(raddr, count=data_len, burst=AxiBurstType.FIXED), 1, "us"
            )
        )

    received_data1 = []
    received_data2 = []
    half_write_timer = ClockCycles(tb.clk, data_len * single_write_cycles // 2)

    # Request 1st write burst
    w1 = cocotb.start_soon(writer())
    await half_write_timer

    # Request 1st read burst during 1st write burst, should wait for write to finish
    r1 = cocotb.start_soon(reader(received_data1))
    await half_write_timer

    # Request 2nd write burst that will collision with 1st read burst, should wait for read to finish
    w2 = cocotb.start_soon(writer())
    await half_write_timer

    # Request 2nd read burst during 2nd write burst, should wait for write to finish
    r2 = cocotb.start_soon(reader(received_data2))

    await Combine(w1, r1, w2, r2)

    assert received_data1 == test_data, "Received data from 1st burst does not match sent data!"
    assert received_data2 == test_data, "Received data from 2nd burst does not match sent data!"

    tb.log.info("Test finished!")
