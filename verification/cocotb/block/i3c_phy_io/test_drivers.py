# Copyright (c) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


async def init_phy(dut):
    clock = dut.clk_i
    reset_n = dut.rst_ni
    cocotb.start_soon(Clock(clock, 10, "ns").start())

    dut.sel_od_pp_i.value = 0
    dut.ctrl_scl_i.value = 0
    dut.ctrl_sda_i.value = 0

    reset_n.value = 0
    await ClockCycles(clock, 10)
    reset_n.value = 1
    await ClockCycles(clock, 10)


async def drive_lines(dut, data):
    """
    Test lines:
      - drive data from the controller side
    """
    dut.ctrl_scl_i.value = data[0]
    dut.ctrl_sda_i.value = data[1]
    await ClockCycles(dut.clk_i, 5)


async def drive_all_states(dut):
    """
    Loop through all possible states of a 2-bit signal
    """
    for i in range(4):
        data = [int(x) for x in bin(i)[2:].zfill(2)]
        cocotb.log.debug(data)
        await drive_lines(dut, data)


@cocotb.test()
async def test_drivers(dut):
    """
    Test the phy_io wrapper

    1. Controller drives the bus
        - Check if feedback signals are OK
    2. External driver

    """
    cocotb.log.setLevel("DEBUG")
    await init_phy(dut)

    # Open-Drain tests
    dut.sel_od_pp_i.value = 0
    await drive_all_states(dut)

    # Push-Pull tests
    dut.sel_od_pp_i.value = 1
    await drive_all_states(dut)
