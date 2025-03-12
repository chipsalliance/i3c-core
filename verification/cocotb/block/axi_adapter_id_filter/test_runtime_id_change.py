# SPDX-License-Identifier: Apache-2.0
import random

from axi_utils import initialize_dut
from bus2csr import dword2int, int2bytes
from cocotbext.axi.constants import AxiBurstType
from utils import Access, draw_axi_priv_ids, get_axi_ids_seq

import cocotb
from cocotb.triggers import Combine, RisingEdge


async def initialize(dut, filter_off=False, priv_ids=None, timeout=50):
    tb = await initialize_dut(
        dut, disable_id_filtering=filter_off, priv_ids=priv_ids, timeout=timeout
    )

    # Generate test data
    data_len = random.randint(10, 64)
    test_data = [random.randint(0, 2**32 - 1) for _ in range(data_len)]
    return tb, data_len, test_data


async def id_filter_disable_toggle(dut, cond):
    while True:
        filter_off = int(dut.disable_id_filtering_i.value)
        while not cond:
            await RisingEdge(dut.aclk)
        dut.disable_id_filtering_i.value = not filter_off
        await RisingEdge(dut.aclk)


async def priv_ids_swapper(dut, cond, new_priv_ids):
    assert isinstance(new_priv_ids, list)
    i, n = 0, len(new_priv_ids)
    while i < n:
        while not cond:
            await RisingEdge(dut.aclk)
        dut.priv_ids_i.value = new_priv_ids[i]
        i += 1
        await RisingEdge(dut.aclk)


async def writer(tb, addr, data, tids):
    # Write sequence should just write data

    for tid, d in zip(tids, data):
        while int(tb.dut.fifo_full_o.value):
            await RisingEdge(tb.clk)
        await tb.write_csr(addr, int2bytes(d), awid=tid)
        # Wait for read to finish in order to avoid multiple writes per read
        await tb.axi_m.wait_read()


async def reader(tb, addr, count, tids, return_data):
    # Wait until there is data in FIFO
    read_offset = 2
    while int(tb.dut.fifo_depth_o.value) < read_offset:
        await RisingEdge(tb.clk)
    # Read sequence should read data on each write data
    for i in range(count):
        # Awaiting `awvalid` causes reading simultaneously with write data channel activity
        if i < (count - read_offset):
            await RisingEdge(tb.dut.awvalid)
        resp = await tb.read_csr(addr, arid=tids[i])
        return_data.append(dword2int(resp))


async def toggle_filtering(dut, cond):
    priv_ids = draw_axi_priv_ids()
    tb, data_len, test_data = await initialize(dut, True, priv_ids)
    waddr = tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr
    raddr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    # Fill fifo halfway to avoid reads when empty
    await tb.axi_m.write_dwords(waddr, range(64), burst=AxiBurstType.FIXED, awid=priv_ids[0])

    cocotb.start_soon(id_filter_disable_toggle(dut, cond))

    awid = get_axi_ids_seq(priv_ids, data_len, Access.Mixed)
    arid = get_axi_ids_seq(priv_ids, data_len, Access.Mixed)

    received_data = []
    w = cocotb.start_soon(writer(tb, waddr, test_data, awid))
    r = cocotb.start_soon(reader(tb, raddr, data_len, arid, received_data))

    await Combine(w, r)


@cocotb.test()
async def test_toggle_filtering_mid_read(dut):
    await toggle_filtering(dut, lambda: dut.arready.value and dut.arvalid.value)


@cocotb.test()
async def test_toggle_filtering_mid_write(dut):
    await toggle_filtering(dut, lambda: dut.wready.value and dut.wvalid.value)


async def swap_priv_ids(dut, cond):
    priv_ids = draw_axi_priv_ids()
    tb, data_len, test_data = await initialize(dut, True, priv_ids)
    waddr = tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr
    raddr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    # Fill fifo halfway to avoid reads when empty
    await tb.axi_m.write_dwords(waddr, range(64), burst=AxiBurstType.FIXED, awid=priv_ids[0])

    priv_ids_seq = [draw_axi_priv_ids() for _ in range(data_len)]
    cocotb.start_soon(priv_ids_swapper(dut, cond, priv_ids_seq))

    awid = get_axi_ids_seq(priv_ids, data_len, Access.Mixed)
    arid = get_axi_ids_seq(priv_ids, data_len, Access.Mixed)

    received_data = []
    w = cocotb.start_soon(writer(tb, waddr, test_data, awid))
    r = cocotb.start_soon(reader(tb, raddr, data_len, arid, received_data))

    await Combine(w, r)


@cocotb.test()
async def test_swap_priv_ids_mid_read(dut):
    await swap_priv_ids(dut, lambda: dut.arready.value and dut.arvalid.value)


@cocotb.test()
async def test_swap_priv_ids_mid_write(dut):
    await swap_priv_ids(dut, lambda: dut.wready.value and dut.wvalid.value)


@cocotb.test()
async def test_randomized_id_configuration_swap(dut):
    async def disable_random():
        while True:
            filter_off = int(dut.disable_id_filtering_i.value)
            if abs(random.random()) < 0.1:
                dut.disable_id_filtering_i.value = not filter_off
            await RisingEdge(dut.aclk)

    async def priv_id_swap_random():
        while True:
            if abs(random.random()) < 0.2:
                dut.priv_ids_i.value = draw_axi_priv_ids()
            await RisingEdge(dut.aclk)

    priv_ids = draw_axi_priv_ids()
    tb, data_len, test_data = await initialize(dut, True, priv_ids)
    waddr = tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr
    raddr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr

    # Fill fifo halfway to avoid reads when empty
    await tb.axi_m.write_dwords(waddr, range(64), burst=AxiBurstType.FIXED, awid=priv_ids[0])

    cocotb.start_soon(disable_random())
    cocotb.start_soon(priv_id_swap_random())

    awid = get_axi_ids_seq(priv_ids, data_len, Access.Mixed)
    arid = get_axi_ids_seq(priv_ids, data_len, Access.Mixed)

    received_data = []
    w = cocotb.start_soon(writer(tb, waddr, test_data, awid))
    r = cocotb.start_soon(reader(tb, raddr, data_len, arid, received_data))

    await Combine(w, r)
