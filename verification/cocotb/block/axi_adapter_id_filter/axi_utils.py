# SPDX-License-Identifier: Apache-2.0
import logging
import random
from enum import IntEnum

from bus2csr import get_frontend_bus_if
from cocotb_helpers import reset_n
from cocotbext.axi import AxiResp
from utils import rand_bits

import cocotb
from cocotb.triggers import ClockCycles, RisingEdge, Timer

AxiIdWidth = 8
NumPrivIds = 4


async def timeout_task(timeout):
    await Timer(timeout, "us")
    raise RuntimeError("Test timeout!")


async def error_monitor(dut):
    """
    Only one operation is executed at a time.
    Ensure error is raised for at most one of them.
    """
    await RisingEdge(dut.areset_n)

    while True:
        wr_err = dut.i3c_axi_if.axi_sif_i3c.wr_err.value
        rd_err = dut.i3c_axi_if.axi_sif_i3c.rd_err.value
        assert not (wr_err and rd_err), "Both write and read error asserted"
        await RisingEdge(dut.aclk)


def _report_axi_response(got, expected, is_read=False):
    op = "read" if is_read else "write"
    name = ["OKAY", "EXOKAY", "SLVERR", "DECERR"]
    return (
        f"{hex(expected)} != {hex(got)}."
        f" Anticipated {op} response: {name[expected]} got: {name[got]}."
    )


async def _wait(dut, cond):
    while not cond():
        await RisingEdge(dut.aclk)


async def axi_read_monitor(dut):
    """
    Ensures the AXI read response is set appropriately to
    current filtering configuration and transaction ID.
    """
    await RisingEdge(dut.areset_n)

    while True:
        await _wait(dut, lambda: dut.arvalid.value and dut.arready.value)
        priv_ids = dut.priv_ids_i.value
        filter_off = dut.disable_id_filtering_i.value

        await _wait(dut, lambda: dut.rvalid.value and dut.rready.value)
        rid = dut.rid.value
        rresp = dut.rresp.value
        if filter_off or rid in priv_ids:
            assert rresp == AxiResp.OKAY, _report_axi_response(rresp, AxiResp.OKAY, True)
        else:
            assert rresp == AxiResp.SLVERR, _report_axi_response(rresp, AxiResp.SLVERR, True)

        await RisingEdge(dut.aclk)


async def axi_write_monitor(dut):
    """
    Ensures the AXI write response is set appropriately to
    current filtering configuration and transaction ID.
    """
    await RisingEdge(dut.areset_n)

    while True:
        await _wait(dut, lambda: dut.awvalid.value and dut.awready.value)
        priv_ids = dut.priv_ids_i.value
        filter_off = dut.disable_id_filtering_i.value

        await _wait(dut, lambda: dut.bvalid.value and dut.bready.value)
        bid = dut.bid.value
        bresp = dut.bresp.value

        if filter_off or bid in priv_ids:
            assert bresp == AxiResp.OKAY, _report_axi_response(bresp, AxiResp.OKAY)
        else:
            assert bresp == AxiResp.SLVERR, _report_axi_response(bresp, AxiResp.SLVERR)

        await RisingEdge(dut.aclk)


class Access(IntEnum):
    Priv = 0
    Unpriv = 1
    Mixed = 2


def draw_ids(id_width=AxiIdWidth, num_priv_ids=NumPrivIds):
    return [rand_bits(id_width) for _ in range(num_priv_ids)]


def get_ids(priv_ids, count, priv=False, id_width=AxiIdWidth):
    id_space = range(0, (1 << id_width))
    unpriv = [x for x in id_space if x not in priv_ids]

    is_priv = priv == Access.Priv
    out = []
    for _ in range(count):
        if priv == Access.Mixed:
            is_priv = random.randint(0, 1)

        id_scope = priv_ids if is_priv else unpriv
        out.append(random.choice(id_scope))

    return out


async def initialize_dut(dut, disable_id_filtering=False, priv_ids=None, timeout=50):
    """
    Common test initialization routine which sets up environment and starts a timeout coroutine
    to observe whether the test did not fall into infinite loop.
    """

    cocotb.log.setLevel(logging.DEBUG)

    # Start the background timeout task
    cocotb.start_soon(timeout_task(timeout))
    cocotb.start_soon(error_monitor(dut))
    cocotb.start_soon(axi_read_monitor(dut))
    cocotb.start_soon(axi_write_monitor(dut))

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
        dut.disable_id_filtering_i.value = int(disable_id_filtering)

    if hasattr(dut, "priv_ids_i"):
        dut.priv_ids_i.value = priv_ids

    # Configure testbench
    tb = get_frontend_bus_if()(dut)
    tb.log = dut._log
    await tb.register_test_interfaces()
    await ClockCycles(tb.clk, 20)
    await reset_n(tb.clk, tb.rst_n, cycles=5)

    return tb
