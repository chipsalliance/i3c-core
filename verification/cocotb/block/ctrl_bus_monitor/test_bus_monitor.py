# SPDX-License-Identifier: Apache-2.0

from cocotb_helpers import reset_n
from cocotbext_i3c.i3c_controller import I3cController

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, RisingEdge


async def setup(dut):
    """
    Happy path testing, arbitrarily selected:
        - 5 -> 10ns for the data hold time (spec has no constraint)
        - 2 -> 4ns for the rise/fall time (spec lowest is 12ns)
    """
    dut.enable_i.value = 0
    dut.t_hd_dat_i.value = 0x05
    dut.t_r_i.value = 0x02
    dut.t_f_i.value = 0x02
    dut.is_in_hdr_mode_i.value = 0
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


def create_default_controller(dut: SimHandleBase) -> I3cController:
    return I3cController(
        sda_i=None,
        sda_o=dut.sda_i,
        scl_i=None,
        scl_o=dut.scl_i,
        speed=12.5e6,
    )


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

    i3c_controller = create_default_controller(dut)

    clock = Clock(clk, 2, units="ns")
    cocotb.start_soon(clock.start())

    await setup(dut)
    await reset_n(clk, rst_n, cycles=5)

    test_data = [[0xAA, 0x00, 0xBB, 0xCC, 0xDD], [0xDE, 0xAD, 0xBA, 0xBE]]
    test_addr = 0x5A
    e_terminate = cocotb.triggers.Event()

    dut.enable_i.value = 1
    for test_vec in test_data:
        t_detect_start = cocotb.start_soon(count_high_cycles(clk, dut.start_det_o, e_terminate))
        t_detect_rstart = cocotb.start_soon(count_high_cycles(clk, dut.rstart_det_o, e_terminate))
        t_detect_stop = cocotb.start_soon(count_high_cycles(clk, dut.stop_det_o, e_terminate))

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
        assert num_starts == 1

        num_rstarts = t_detect_rstart.result()
        cocotb.log.info(f"rSTARTs detected: {num_rstarts}")
        assert num_rstarts == 1

        num_stops = t_detect_stop.result()
        cocotb.log.info(f"STOPs detected: {num_stops}")
        assert num_stops == 1

        e_terminate.clear()

    await ClockCycles(clk, 10)


@cocotb.test()
async def test_bus_monitor_hdr_exit(dut: SimHandleBase):
    """
    Test bus monitor:
        - Check if hdr exit condition is detected
        - If the controller is in the HDR mode we should detect HDR exit condition
    """
    cocotb.log.setLevel("INFO")
    clk = dut.clk_i
    rst_n = dut.rst_ni
    e_terminate = cocotb.triggers.Event()

    i3c_controller = I3cController(
        sda_i=None,
        sda_o=dut.sda_i,
        scl_i=None,
        scl_o=dut.scl_i,
        speed=12.5e6,
    )
    t_detect_hdr_exit = cocotb.start_soon(
        count_high_cycles(clk, dut.hdr_exit_detect_o, e_terminate)
    )

    clock = Clock(clk, 2, units="ns")
    cocotb.start_soon(clock.start())

    await setup(dut)
    await reset_n(clk, rst_n, cycles=5)

    dut.enable_i.value = 1
    # initially, the core is in SDR mode, so sending the first
    # HDR exit should not trigger the exit event
    await i3c_controller.send_hdr_exit()
    await RisingEdge(clk)
    # enter hdr mode and send the exit pattern again
    dut.is_in_hdr_mode_i.value = 1
    await i3c_controller.send_hdr_exit()
    await ClockCycles(clk, 10)
    e_terminate.set()
    await RisingEdge(clk)
    num_detects = t_detect_hdr_exit.result()
    cocotb.log.info(f"HDR exits detected {num_detects}")
    assert num_detects == 1
    e_terminate.clear()


@cocotb.test()
async def test_target_reset_detection(dut: SimHandleBase):
    cocotb.log.setLevel("INFO")

    i3c_controller = create_default_controller(dut)
    clock = Clock(dut.clk_i, 2, units="ns")
    cocotb.start_soon(clock.start())

    await setup(dut)
    await reset_n(dut.clk_i, dut.rst_ni, cycles=5)

    dut.enable_i.value = 1

    # Basic target reset
    cocotb.log.info("Performing basic target reset test with no configuration")

    e_terminate = cocotb.triggers.Event()
    t_detect_target_reset = cocotb.start_soon(
        count_high_cycles(dut.clk_i, dut.target_reset_detect_o, e_terminate)
    )
    await i3c_controller.target_reset()

    await ClockCycles(dut.clk_i, 32)
    e_terminate.set()
    await RisingEdge(dut.clk_i)

    num_resets = t_detect_target_reset.result()
    cocotb.log.info(f"Resets detected: {num_resets}")
    assert num_resets == 1

    e_terminate.clear()

    await ClockCycles(dut.clk_i, 10)
