# SPDX-License-Identifier: Apache-2.0

from cocotb_helpers import reset_n

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, RisingEdge

async def setup(dut):
    """
    Sets up a base for testing
    """

    cocotb.log.setLevel("INFO")

    dut.trigger.value   = 0
    dut.line.value      = 0

    clock = Clock(dut.clk_i, 2, units="ns")
    cocotb.start_soon(clock.start())

    await ClockCycles(dut.clk_i, 2)
    await reset_n(dut.clk_i, dut.rst_ni, cycles=5)
    await ClockCycles(dut.clk_i, 2)

    return dut.clk_i, dut.rst_ni


async def count_cycles(clk, sig):
    """
    Counts clock cycles between now and assertion of the given signal.
    Returns the count. Throws error after 100 cycles.
    """

    for i in range(100):
        await RisingEdge(clk)
        if sig.value:
            cycles = i
            break
    else:
        assert False, "Timeout"

    await ClockCycles(clk, 2)
    return cycles


@cocotb.test()
async def test_pretrigger_with_delay(dut: SimHandleBase):

    clk, rst_n = await setup(dut)

    DELAY = 1

    # Set delay & trigger
    await RisingEdge(clk)
    dut.delay_count.value = DELAY
    dut.trigger.value = 1
    await RisingEdge(clk)
    dut.trigger.value = 0

    # Assert line, count cycles until detect
    await RisingEdge(clk)
    dut.line.value = 1
    cycles = await count_cycles(clk, dut.detect)

    # Check cycle count
    assert cycles == DELAY+1


@cocotb.test()
async def test_posttrigger_with_delay(dut: SimHandleBase):

    clk, rst_n = await setup(dut)

    DELAY = 1

    dut.line.value = 1

    # Set delay
    await RisingEdge(clk)
    dut.delay_count.value = DELAY

    # Trigger
    dut.trigger.value = 1
    await RisingEdge(clk)
    dut.trigger.value = 0

    # Count cycles
    cycles = await count_cycles(clk, dut.detect)

    # Check cycle count
    assert cycles == DELAY + 1


@cocotb.test()
async def test_trigger_with_delay(dut: SimHandleBase):

    clk, rst_n = await setup(dut)

    DELAY = 1

    # Set delay
    await RisingEdge(clk)
    dut.delay_count.value = DELAY

    # Assert trigger and line simultaneously
    dut.trigger.value = 1
    dut.line.value = 1
    await RisingEdge(clk)
    dut.trigger.value = 0

    # Count cycles
    cycles = await count_cycles(clk, dut.detect)

    # Check cycle count
    assert cycles == DELAY + 1


@cocotb.test()
async def test_pretrigger_no_delay(dut: SimHandleBase):

    clk, rst_n = await setup(dut)

    DELAY = 0

    # Set delay & trigger
    await RisingEdge(clk)
    dut.delay_count.value = DELAY
    dut.trigger.value = 0
    await RisingEdge(clk)
    dut.trigger.value = 1

    # Assert line, count cycles until detect
    await RisingEdge(clk)
    dut.line.value = 1
    cycles = await count_cycles(clk, dut.detect)

    # Check cycle count
    assert cycles == DELAY


@cocotb.test()
async def test_posttrigger_no_delay(dut: SimHandleBase):

    clk, rst_n = await setup(dut)

    DELAY = 0

    dut.line.value = 1

    # Set delay
    await RisingEdge(clk)
    dut.delay_count.value = DELAY

    # Trigger
    dut.trigger.value = 0
    await RisingEdge(clk)
    dut.trigger.value = 1
    await RisingEdge(clk)

    # Count cycles
    cycles = await count_cycles(clk, dut.detect)

    # Check cycle count
    assert cycles == DELAY


@cocotb.test()
async def test_trigger_no_delay(dut: SimHandleBase):

    clk, rst_n = await setup(dut)

    DELAY = 0

    # Set delay
    await RisingEdge(clk)
    dut.delay_count.value = DELAY

    # Assert trigger and line simultaneously
    dut.trigger.value = 0
    await RisingEdge(clk)
    dut.trigger.value = 1
    dut.line.value = 1

    # Count cycles
    cycles = await count_cycles(clk, dut.detect)

    # Check cycle count
    assert cycles == DELAY
