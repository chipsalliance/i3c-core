# SPDX-License-Identifier: Apache-2.0
import logging

from bus2csr import get_frontend_bus_if
from cocotb_helpers import reset_n

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


async def initialize_dut(dut, disable_id_filtering=False, priv_ids=None, timeout=50):
    """
    Common test initialization routine which sets up environment and starts a timeout coroutine
    to observe whether the test did not fall into infinite loop.
    """

    cocotb.log.setLevel(logging.DEBUG)

    tb = get_frontend_bus_if()(dut)
    tb.log = dut._log
    await tb.register_test_interfaces()

    # Start the background timeout task
    cocotb.start_soon(timeout_task(timeout))
    cocotb.start_soon(error_monitor(dut))
    cocotb.start_soon(tb.read_access_monitor())
    cocotb.start_soon(tb.write_access_monitor())

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

    await ClockCycles(tb.clk, 20)
    await reset_n(tb.clk, tb.rst_n, cycles=5)

    return tb
