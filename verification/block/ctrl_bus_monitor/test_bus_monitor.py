# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, RisingEdge
from cocotb_helpers import reset_n
from cocotbext_i3c.i3c_controller import I3cController


async def setup(dut):
    """
    Happy path testing, arbitrarily selected:
        - 5 -> 10ns for the data hold time (spec has no constraint)
        - 2 -> 4ns for the rise/fall time (spec lowest is 12ns)
    """
    dut.enable_i.value = 0
    dut.t_hd_dat_i.value = 0x05
    dut.t_r_i.value = 0x02
    await ClockCycles(dut.clk_i, 10)


async def count_high_cycles(clk, sig, e_terminate):
    """
    Counts number of clock cycles during which the signal was HIGH
    """
    num_det = 0
    while not e_terminate.is_set():
        if sig.value:
            num_det += 1
        await RisingEdge(clk)
    return num_det


@cocotb.test()
async def test_bus_monitor(dut: SimHandleBase):
    """
    Test bus monitor:
        - Check if START, REPEATED START and STOP conditions are detected
        - For each i3c private write, we should observe:
            - 2 START detections and 1 STOP detection
            - 1 of the STARTs is a REPEATED START
        - Implementation does not differentiate STARTs from REPEATED STARTs
    """
    cocotb.log.setLevel("INFO")
    clk = dut.clk_i
    rst_n = dut.rst_ni

    i3c_controller = I3cController(
        sda_i=None,
        sda_o=dut.sda_i,
        scl_i=None,
        scl_o=dut.scl_i,
        speed=12.5e6,
    )

    clock = Clock(clk, 2, units="ns")
    cocotb.start_soon(clock.start())

    await setup(dut)
    await reset_n(clk, rst_n, cycles=5)

    test_data = [[0xAA, 0x00, 0xBB, 0xCC, 0xDD], [0xDE, 0xAD, 0xBA, 0xBE]]
    test_addr = 0x5A
    e_terminate = cocotb.triggers.Event()

    dut.enable_i.value = 1
    for test_vec in test_data:
        t_detect_start = cocotb.start_soon(count_high_cycles(clk, dut.start_detect_o, e_terminate))
        t_detect_stop = cocotb.start_soon(count_high_cycles(clk, dut.stop_detect_o, e_terminate))

        cocotb.log.info("Private Write {")
        cocotb.log.info(f"\tAddr: {test_addr}")
        cocotb.log.info(f"\tData: {test_vec}")
        cocotb.log.info("}")

        await i3c_controller.i3c_write(test_addr, test_vec)
        await ClockCycles(clk, 10)

        e_terminate.set()
        await RisingEdge(clk)

        num_starts = t_detect_start.result()
        cocotb.log.info(f"STARTs detected: {num_starts}")
        assert num_starts == 2

        num_stops = t_detect_stop.result()
        cocotb.log.info(f"STOPs detected: {num_stops}")
        assert num_stops == 1

        e_terminate.clear()

    await ClockCycles(clk, 10)
