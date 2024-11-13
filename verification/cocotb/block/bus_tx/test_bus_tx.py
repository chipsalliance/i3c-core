# SPDX-License-Identifier: Apache-2.0

from bus_monitor import BusMonitor

import cocotb
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, RisingEdge

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
    dut.t_su_dat_i.value = 5
    dut.t_hd_dat_i.value = 5
    dut.drive_i.value = 0
    dut.drive_value_i.value = 0
    dut.scl_negedge_i.value = 0
    dut.scl_posedge_i.value = 0
    dut.scl_stable_low_i.value = 0
    dut.sel_od_pp_i.value = 0

    await ClockCycles(dut.clk_i, 10)

    await reset(dut)

    await ClockCycles(dut.clk_i, 10)

    assert dut.tx_idle_o.value == 1
    assert dut.tx_done_o.value == 0
    assert dut.sda_o.value == 1


async def assert_drive_start(dut, sda_value):
    if not dut.scl_stable_low_i.value:
        await RisingEdge(dut.scl_negedge_i)
        await ReadOnly()
        assert dut.tx_idle_o.value == 0
    else:
        await ReadOnly()
    # SDA should not be driven 1 cycle after SCL negedge
    assert dut.sda_o.value == 1
    assert dut.tx_done_o.value == 0
    await ClockCycles(dut.clk_i, dut.t_su_dat_i.value + dut.t_r_i.value)
    await ReadOnly()
    assert dut.sda_o.value == sda_value

    await RisingEdge(dut.tx_done_o)
    # Stop requesting bus tx
    dut.drive_i.value = 0
    await ReadOnly()
    # SDA should be driven until tx_idle_o is HIGH
    assert dut.tx_idle_o.value == 0
    assert dut.sda_o.value == sda_value

    await RisingEdge(dut.tx_idle_o)
    await ReadOnly()
    assert dut.sda_o.value == 1


async def send_bit(dut, value):
    # Ensure we're out of ReadOnly phase and setup data
    await RisingEdge(dut.clk_i)
    dut.drive_value_i.value = value

    # If SCL is already low, wait setup time only
    if not dut.scl_stable_low_i.value:
        await RisingEdge(dut.scl_negedge_i)
    await ClockCycles(dut.clk_i, dut.t_su_dat_i.value + dut.t_r_i.value)

    # Ensure data is correct until tx is finished
    while not dut.tx_done_o.value:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        assert dut.sda_o.value == value
        assert dut.tx_idle_o.value == 0


async def send_byte(dut, data):
    for i in range(8):
        bit = (data >> i) & 1
        await send_bit(dut, bit)

    # Leave ReadOnly phase
    await RisingEdge(dut.clk_i)


async def test_bit_tx_negedge(dut, value):
    await setup_test(dut)

    await FallingEdge(dut.scl_i)
    dut.drive_i.value = 1
    dut.drive_value_i.value = value

    await assert_drive_start(dut, value)
    await ClockCycles(dut.clk_i, 10)


tf = TestFactory(test_function=test_bit_tx_negedge)
tf.add_option(name="value", optionlist=[0, 1])
tf.generate_tests()


async def test_bit_tx_pre_posedge(dut, value):
    await setup_test(dut)

    await FallingEdge(dut.scl_i)
    await ClockCycles(dut.clk_i, int((SCL_CLK_RATIO / 2) - dut.t_su_dat_i.value))
    dut.drive_i.value = 1
    dut.drive_value_i.value = value

    await assert_drive_start(dut, value)
    await ClockCycles(dut.clk_i, 10)


tf = TestFactory(test_function=test_bit_tx_pre_posedge)
tf.add_option(name="value", optionlist=[0, 1])
tf.generate_tests()


async def test_bit_tx_high_level(dut, value):
    await setup_test(dut)

    await RisingEdge(dut.scl_i)
    await ClockCycles(dut.clk_i, int((SCL_CLK_RATIO / 2) - dut.t_su_dat_i.value))
    dut.drive_i.value = 1
    dut.drive_value_i.value = value

    await assert_drive_start(dut, value)
    await ClockCycles(dut.clk_i, 10)


tf = TestFactory(test_function=test_bit_tx_high_level)
tf.add_option(name="value", optionlist=[0, 1])
tf.generate_tests()


async def test_bit_tx_low_level(dut, value):
    await setup_test(dut)

    await FallingEdge(dut.scl_i)
    await ClockCycles(dut.clk_i, 10)
    dut.drive_i.value = 1
    dut.drive_value_i.value = value

    await assert_drive_start(dut, value)
    await ClockCycles(dut.clk_i, 10)


tf = TestFactory(test_function=test_bit_tx_low_level)
tf.add_option(name="value", optionlist=[0, 1])
tf.generate_tests()


@cocotb.test()
async def test_byte_tx(dut):
    data = 0xAF
    await setup_test(dut)

    # Begin driving bus request after SCL negedge
    await FallingEdge(dut.scl_i)
    dut.drive_i.value = 1
    # Send data
    await send_byte(dut, data)
    # Send T-Bit (arbitrary)
    await send_bit(dut, 0)
    # Leave ReadOnly phase
    await RisingEdge(dut.clk_i)
    dut.drive_i.value = 0

    # Wait for bus tx module to finish
    await RisingEdge(dut.tx_idle_o)
    await ReadOnly()

    # Ensure that the bus is free
    assert dut.sda_o.value == 1
    await ClockCycles(dut.clk_i, 10)
