# SPDX-License-Identifier: Apache-2.0

from random import randint

from bus_monitor import BusMonitor

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, First, ReadOnly, RisingEdge

CLOCK_PERIOD_NS = 2
SCL_CLK_RATIO = 40


async def reset(dut):
    await FallingEdge(dut.clk_i)
    dut.rst_ni.value = 0
    await ClockCycles(dut.clk_i, 10)
    await FallingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)


async def setup_test(dut):
    """
    Spawn system clock, reset the module and
    Happy path testing, arbitrarily selected:
        - 5 -> 10ns for the data hold time (spec has no constraint)
        - 2 -> 4ns for the rise/fall time (spec lowest is 12ns)
    """
    cocotb.log.setLevel("INFO")

    clock = Clock(dut.clk_i, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())
    scl_clock = Clock(dut.scl_i, CLOCK_PERIOD_NS * SCL_CLK_RATIO, units="ns")
    cocotb.start_soon(scl_clock.start())
    bus_monitor = BusMonitor(dut)
    bus_monitor.start()

    dut.rst_ni.value = 0
    dut.scl_i.value = 1  # pull-up
    dut.t_r_i.value = 2
    dut.t_f_i.value = 2
    dut.scl_posedge_i.value = 0
    dut.scl_stable_high_i.value = 0
    dut.rx_req_bit_i.value = 0
    dut.rx_req_byte_i.value = 0

    await ClockCycles(dut.clk_i, 10)
    await reset(dut)
    await ClockCycles(dut.clk_i, 10)

    assert dut.rx_done_o.value == 0
    assert dut.rx_idle_o.value == 1


@cocotb.test()
async def test_multiple_bit_reads(dut):
    TEST_COUNT = 10
    data = [randint(0, 1) for _ in range(TEST_COUNT)]
    dut._log.info(f"Send values: {data}")

    await setup_test(dut)

    for d in data:
        await FallingEdge(dut.scl_i)
        await RisingEdge(dut.clk_i)
        dut.rx_req_bit_i.value = 1

        dut.sda_i.value = d
        scl_negedge = FallingEdge(dut.scl_i)
        done_posedge = RisingEdge(dut.rx_done_o)
        result = await First(scl_negedge, done_posedge)

        if result == done_posedge:
            await RisingEdge(dut.clk_i)
            assert dut.rx_data_o.value == d
            dut.rx_req_bit_i.value = 0
            dut._log.debug(f"Bit correct, rx_data_o: {dut.rx_data_o.value}, expected: {d}")
        else:
            assert False, "Did not detect RX Done when expected"

        await ClockCycles(dut.clk_i, 100)

    await ClockCycles(dut.clk_i, 10)


@cocotb.test()
async def test_multiple_byte_reads(dut):
    TEST_COUNT = 10
    data = [randint(0, 255) for _ in range(TEST_COUNT)]

    await setup_test(dut)

    for d in data:
        await FallingEdge(dut.scl_i)
        await RisingEdge(dut.clk_i)
        dut.rx_req_byte_i.value = 1

        for b in range(8):
            dut.sda_i.value = (d >> (7 - b)) & 1
            scl_negedge = FallingEdge(dut.scl_i)
            done_posedge = RisingEdge(dut.rx_done_o)

            result = await First(scl_negedge, done_posedge)

            if result == done_posedge:
                await ReadOnly()
                assert dut.rx_data_o.value == d
                break

            if b == 7:
                assert False, "Did not detect RX Done when expected"

        await RisingEdge(dut.clk_i)
        dut.rx_req_byte_i.value = 0
        await ClockCycles(dut.clk_i, 100)

    await ClockCycles(dut.clk_i, 10)
