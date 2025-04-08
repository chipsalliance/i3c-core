# SPDX-License-Identifier: Apache-2.0

from random import randint

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
    dut.req_byte_i.value = 0
    dut.req_bit_i.value = 0
    dut.req_value_i.value = 0
    dut.scl_negedge_i.value = 0
    dut.scl_posedge_i.value = 0
    dut.scl_stable_low_i.value = 0
    dut.sel_od_pp_i.value = 0

    await reset(dut)

    assert dut.bus_tx_idle_o.value == 1
    assert dut.bus_tx_done_o.value == 0
    assert dut.sda_o.value == 1


async def assert_bit_request(dut, sda_value):
    if not dut.scl_stable_low_i.value:
        await RisingEdge(dut.scl_negedge_i)
        await ReadOnly()
        assert dut.bus_tx_idle_o.value == 0
    else:
        await ReadOnly()
    # SDA should not be driven 1 cycle after SCL negedge
    assert dut.sda_o.value == 1
    assert dut.bus_tx_done_o.value == 0
    await ClockCycles(dut.clk_i, dut.t_su_dat_i.value + dut.t_r_i.value)
    await ReadOnly()
    assert dut.sda_o.value == sda_value

    # Ensure data is correct until tx is finished
    while True:
        if dut.bus_tx_done_o.value:
            break
        assert dut.sda_o.value == sda_value
        assert dut.bus_tx_idle_o.value == 0
        await RisingEdge(dut.clk_i)
        await ReadOnly()

    await RisingEdge(dut.clk_i)
    dut.req_bit_i.value = 0
    await RisingEdge(dut.bus_tx_idle_o)
    await ReadOnly()
    assert dut.sda_o.value == 1


async def test_bit_tx_negedge(dut, value):
    await setup_test(dut)

    await FallingEdge(dut.scl_i)
    dut.req_bit_i.value = 1
    dut.req_value_i.value = value

    await assert_bit_request(dut, value)


tf = TestFactory(test_function=test_bit_tx_negedge)
tf.add_option(name="value", optionlist=[0, 1])
tf.generate_tests()


async def test_bit_tx_pre_posedge(dut, value):
    await setup_test(dut)

    await FallingEdge(dut.scl_i)
    await ClockCycles(dut.clk_i, int((SCL_CLK_RATIO / 2) - dut.t_su_dat_i.value))
    dut.req_bit_i.value = 1
    dut.req_value_i.value = value

    await assert_bit_request(dut, value)


tf = TestFactory(test_function=test_bit_tx_pre_posedge)
tf.add_option(name="value", optionlist=[0, 1])
tf.generate_tests()


async def test_bit_tx_high_level(dut, value):
    await setup_test(dut)

    await RisingEdge(dut.scl_i)
    await ClockCycles(dut.clk_i, int((SCL_CLK_RATIO / 2) - dut.t_su_dat_i.value))
    dut.req_bit_i.value = 1
    dut.req_value_i.value = value

    await assert_bit_request(dut, value)


tf = TestFactory(test_function=test_bit_tx_high_level)
tf.add_option(name="value", optionlist=[0, 1])
tf.generate_tests()


async def test_bit_tx_low_level(dut, value):
    await setup_test(dut)

    await FallingEdge(dut.scl_i)
    await ClockCycles(dut.clk_i, 10)
    dut.req_bit_i.value = 1
    dut.req_value_i.value = value

    await assert_bit_request(dut, value)


tf = TestFactory(test_function=test_bit_tx_low_level)
tf.add_option(name="value", optionlist=[0, 1])
tf.generate_tests()


async def send_byte_with_tbit(dut, data, tbit):
    dut._log.info(f"Start transfer, data: {data}, T-Bit: {tbit}")
    # Begin driving bus request after SCL negedge
    await FallingEdge(dut.scl_i)
    dut.req_byte_i.value = 1
    dut.req_bit_i.value = 0
    dut.req_value_i.value = data

    captured_data = 0
    last_scl = dut.scl_i.value
    while True:
        await RisingEdge(dut.clk_i)
        if not last_scl and dut.scl_i.value:
            captured_data = (captured_data << 1) | dut.sda_o.value
        last_scl = dut.scl_i.value

        if dut.bus_tx_done_o.value:
            break

    dut._log.info(f"Received data: {captured_data}")
    assert data == captured_data

    # Send T-Bit (arbitrary)
    dut.req_byte_i.value = 0
    dut.req_bit_i.value = 1
    dut.req_value_i.value = tbit
    await RisingEdge(dut.bus_tx_done_o)
    dut.req_bit_i.value = 0
    await RisingEdge(dut.bus_tx_idle_o)


@cocotb.test()
async def test_byte_tx(dut):
    data = [randint(0, 0xFF) for x in range(10)]
    await setup_test(dut)

    for d in data:
        await send_byte_with_tbit(dut, d, 0)
        await ReadOnly()
        # Ensure that the bus is free
        assert dut.sda_o.value == 1
