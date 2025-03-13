# SPDX-License-Identifier: Apache-2.0
import random

from axi_utils import Access, draw_ids, get_ids, initialize_dut
from bus2csr import dword2int, int2bytes, int2dword
from cocotbext.axi.constants import AxiBurstType

import cocotb
from cocotb.triggers import ClockCycles, Combine, RisingEdge, with_timeout


async def initialize(dut, filter_off=False, priv_ids=None, timeout=50):
    tb = await initialize_dut(
        dut, disable_id_filtering=filter_off, priv_ids=priv_ids, timeout=timeout
    )

    # Generate test data
    data_len = random.randint(10, 64)
    test_data = [random.randint(0, 2**32 - 1) for _ in range(data_len)]
    return tb, data_len, test_data


def verify_data(write_data, awids, read_data, arids, disable_id_filtering=False, priv_ids=None):
    assert len(write_data) == len(read_data)
    awid_len = len(awids)
    if not disable_id_filtering:
        write_data = [d for i, d in enumerate(write_data) if awids[i % awid_len] in priv_ids]

    arid_len = len(arids)
    ptr = 0
    for i in range(arid_len):
        if arids[i % arid_len] in priv_ids or disable_id_filtering:
            assert read_data[i] == write_data[ptr]
            ptr += 1
        else:
            assert read_data[i] == 0


async def collision_with_write(dut, filter_off=False, awid_priv=Access.Priv, arid_priv=Access.Priv):
    priv_ids = draw_ids()
    tb, data_len, test_data = await initialize(dut, filter_off, priv_ids)
    awids = get_ids(priv_ids, data_len, awid_priv)
    arids = get_ids(priv_ids, data_len, arid_priv)

    waddr = tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr
    raddr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    async def writer():
        # Write sequence should just write data
        for d, awid in zip(test_data, awids):
            await tb.write_csr(waddr, int2bytes(d), awid=awid)
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
            resp = await tb.read_csr(raddr, arid=arids[i])
            return_data.append(dword2int(resp))

    received_data = []
    w = cocotb.start_soon(writer())
    r = cocotb.start_soon(reader(received_data))

    await Combine(w, r)

    verify_data(test_data, awids, received_data, arids, filter_off, priv_ids)


@cocotb.test()
async def test_collision_with_write_id_filter_off(dut):
    await collision_with_write(dut, True)


@cocotb.test()
async def test_collision_with_write_id_filter_on_priv(dut):
    await collision_with_write(dut, False, Access.Priv, Access.Priv)


@cocotb.test()
async def test_collision_with_write_id_filter_on_non_priv(dut):
    await collision_with_write(dut, False, Access.Priv, Access.Unpriv)


@cocotb.test()
async def test_collision_with_write_id_filter_on_mixed(dut):
    await collision_with_write(dut, False, Access.Priv, Access.Mixed)


async def collision_with_read(dut, filter_off=False, awid_priv=True, arid_priv=True):
    priv_ids = draw_ids()
    tb, data_len, test_data = await initialize(dut, filter_off, priv_ids)
    awids = get_ids(priv_ids, data_len, awid_priv)
    arids = get_ids(priv_ids, data_len, arid_priv)

    waddr = tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr
    raddr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    read_offset = 2

    async def writer():
        # Write sequence should write data on each read data
        for (i, d), awid in zip(enumerate(test_data), awids):
            # Load first two dwords independently
            if i > read_offset:
                # TODO: Won't it cause a deadlock?
                # Awaiting read request causes writing simultaneously with read data channel activity
                await tb.axi_m.wait_read()
                assert not dut.s_cpuif_req_is_wr.value
                # Wait additional cycle to line up write with FIFO read delay
                await RisingEdge(tb.clk)
            await tb.write_csr(waddr, int2dword(d), awid=awid)

    async def reader(return_data):
        # Wait until there is data in FIFO
        while int(dut.fifo_depth_o.value) < read_offset:
            await RisingEdge(tb.clk)

        # Read sequence should just read data
        for i in range(data_len):
            # Wait for write to finish to avoid multiple reads per write
            await tb.axi_m.wait_write()
            resp = await tb.read_csr(raddr, arid=arids[i])
            return_data.append(dword2int(resp))
            await RisingEdge(tb.clk)

    received_data = []
    w = cocotb.start_soon(writer())
    r = cocotb.start_soon(reader(received_data))

    await Combine(w, r)

    verify_data(test_data, awids, received_data, arids, filter_off, priv_ids)


@cocotb.test()
async def test_collision_with_read_id_filter_off(dut):
    await collision_with_read(dut, True)


@cocotb.test()
async def test_collision_with_read_id_filter_on_priv(dut):
    await collision_with_read(dut, False, Access.Priv, Access.Priv)


@cocotb.test()
async def test_collision_with_read_id_filter_on_non_priv(dut):
    await collision_with_read(dut, False, Access.Priv, Access.Unpriv)


@cocotb.test()
async def test_collision_with_read_id_filter_on_mixed(dut):
    await collision_with_read(dut, False, Access.Priv, Access.Mixed)


async def write_read_burst(dut, filter_off=False, awid_priv=True, arid_priv=True):
    priv_ids = draw_ids()
    tb, data_len, test_data = await initialize(dut, filter_off, priv_ids)
    awids = get_ids(priv_ids, 1, awid_priv)
    arids = get_ids(priv_ids, 1, arid_priv)
    awid, arid = awids[0], arids[0]

    waddr = tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr
    raddr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    # Run write burst to fill the FIFO
    write = tb.axi_m.write_dwords(waddr, test_data, burst=AxiBurstType.FIXED, awid=awid)
    await with_timeout(write, 1, "us")

    # Run read burst to empty the FIFO
    read = tb.axi_m.read_dwords(raddr, count=data_len, burst=AxiBurstType.FIXED, arid=arid)
    received_data = await with_timeout(read, 1, "us")

    verify_data(test_data, awids, received_data, arids, filter_off, priv_ids)


@cocotb.test()
async def test_write_read_burst_id_filter_off(dut):
    await write_read_burst(dut, True)


@cocotb.test()
async def test_write_read_burst_id_filter_on_priv(dut):
    await write_read_burst(dut, False, Access.Priv, Access.Priv)


@cocotb.test()
async def test_write_read_burst_id_filter_on_non_priv(dut):
    await write_read_burst(dut, False, Access.Priv, Access.Unpriv)


async def write_burst_collision_with_read(dut, filter_off=False, awid_priv=True, arid_priv=True):
    priv_ids = draw_ids()
    tb, data_len, test_data = await initialize(dut, filter_off, priv_ids)
    awids = get_ids(priv_ids, 1, awid_priv)
    arids = get_ids(priv_ids, 1, arid_priv)
    awid, arid = awids[0], arids[0]

    waddr = tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr
    raddr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    # Time in clock cycles to perform single dword write
    single_write_cycles = 3

    async def writer():
        write = tb.axi_m.write_dwords(waddr, test_data, burst=AxiBurstType.FIXED, awid=awid)
        await with_timeout(write, 1, "us")

    async def reader(return_data):
        read = tb.axi_m.read_dwords(raddr, count=data_len, burst=AxiBurstType.FIXED, arid=arid)
        return_data.extend(await with_timeout(read, 1, "us"))

    received_data = []
    half_write_timer = ClockCycles(tb.clk, data_len * single_write_cycles // 2)

    # Request write burst
    w = cocotb.start_soon(writer())
    await half_write_timer

    # Request read burst during write burst, should wait for write to finish
    r = cocotb.start_soon(reader(received_data))

    await Combine(w, r)

    verify_data(test_data, awids, received_data, arids, filter_off, priv_ids)


@cocotb.test()
async def test_write_burst_collision_with_read_id_filter_off(dut):
    await write_burst_collision_with_read(dut, True)


@cocotb.test()
async def test_write_burst_collision_with_read_id_filter_on_priv(dut):
    await write_burst_collision_with_read(dut, False, Access.Priv, Access.Priv)


@cocotb.test()
async def test_write_burst_collision_with_read_id_filter_non_priv(dut):
    await write_burst_collision_with_read(dut, False, Access.Priv, Access.Unpriv)


async def read_burst_collision_with_write(dut, filter_off=False, awid_priv=True, arid_priv=True):
    priv_ids = draw_ids()
    tb, data_len, test_data = await initialize(dut, filter_off, priv_ids)
    awids = get_ids(priv_ids, 1, awid_priv)
    arids = get_ids(priv_ids, 1, arid_priv)
    awid, arid = awids[0], arids[0]

    waddr = tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr
    raddr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    # Time in clock cycles to perform single dword write
    single_write_cycles = 3

    async def writer():
        write = tb.axi_m.write_dwords(waddr, test_data, burst=AxiBurstType.FIXED, awid=awid)
        await with_timeout(write, 1, "us")

    async def reader(return_data):
        read = tb.axi_m.read_dwords(raddr, count=data_len, burst=AxiBurstType.FIXED, arid=arid)
        return_data.extend(await with_timeout(read, 1, "us"))

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

    verify_data(test_data, awids, received_data1, arids, filter_off, priv_ids)
    verify_data(test_data, awids, received_data2, arids, filter_off, priv_ids)


@cocotb.test()
async def test_read_burst_collision_with_write_id_filter_off(dut):
    await read_burst_collision_with_write(dut, True)


@cocotb.test()
async def test_read_burst_collision_with_write_id_filter_on_priv(dut):
    await read_burst_collision_with_write(dut, False, Access.Priv, Access.Priv)


@cocotb.test()
async def test_read_burst_collision_with_write_id_filter_on_non_priv(dut):
    await read_burst_collision_with_write(dut, False, Access.Priv, Access.Unpriv)


@cocotb.test()
async def test_collision_with_write_mixed_priv(dut):
    priv_ids = draw_ids()
    tb, data_len, test_data = await initialize(dut, filter_off=False, priv_ids=priv_ids)
    awids = get_ids(priv_ids, data_len, Access.Mixed)
    arids = get_ids(priv_ids, data_len, Access.Mixed)

    waddr = tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr
    raddr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    async def writer():
        # Ensure appropriate response based on ID
        for d, awid in zip(test_data, awids):
            await tb.write_csr(waddr, int2bytes(d), awid=awid)
            # Wait for read to finish in order to avoid multiple writes per read
            await tb.axi_m.wait_read()

    async def reader():
        # Ensure appropriate response based on ID
        # Wait until there is data in FIFO
        read_offset = 2
        while int(dut.fifo_depth_o.value) < read_offset:
            await RisingEdge(tb.clk)
        # Read sequence should read data on each write data
        for i in range(data_len):
            # Awaiting `awvalid` causes reading simultaneously with write data channel activity
            await RisingEdge(dut.awvalid)
            _ = await tb.read_csr(raddr, arid=arids[i])

    # Fill fifo halfway to avoid reads when empty
    await tb.axi_m.write_dwords(waddr, range(64), burst=AxiBurstType.FIXED, awid=priv_ids[0])

    w = cocotb.start_soon(writer())
    r = cocotb.start_soon(reader())
    await Combine(w, r)


@cocotb.test()
async def test_collision_with_read_mixed_priv(dut):
    priv_ids = draw_ids()
    tb, data_len, test_data = await initialize(dut, filter_off=False, priv_ids=priv_ids)
    awids = get_ids(priv_ids, data_len, Access.Mixed)
    arids = get_ids(priv_ids, data_len, Access.Mixed)

    waddr = tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr
    raddr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    read_offset = 2

    async def writer():
        # Write sequence should write data on each read data
        for (i, d), awid in zip(enumerate(test_data), awids):
            # Load first two dwords independently
            if i > read_offset:
                # Awaiting read request causes writing simultaneously with read data channel activity
                await tb.axi_m.wait_read()
                assert not dut.s_cpuif_req_is_wr.value
                # Wait additional cycle to line up write with FIFO read delay
                await RisingEdge(tb.clk)
            await tb.write_csr(waddr, int2dword(d), awid=awid)

    async def reader():
        # Wait until there is data in FIFO
        while int(dut.fifo_depth_o.value) < read_offset:
            await RisingEdge(tb.clk)

        # Read sequence should just read data
        for i in range(data_len):
            # Wait for write to finish to avoid multiple reads per write
            await tb.axi_m.wait_write()
            _ = await tb.read_csr(raddr, arid=arids[i])
            await RisingEdge(tb.clk)

    await tb.axi_m.write_dwords(waddr, range(64), burst=AxiBurstType.FIXED, awid=priv_ids[0])

    w = cocotb.start_soon(writer())
    r = cocotb.start_soon(reader())

    await Combine(w, r)
