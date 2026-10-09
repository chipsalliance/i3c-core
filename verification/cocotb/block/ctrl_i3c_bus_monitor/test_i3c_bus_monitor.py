# SPDX-License-Identifier: Apache-2.0

from cocotb_helpers import reset_n
from cocotbext_i3c.i3c_controller import I3cController

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, RisingEdge, Timer


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
    dut.is_in_hdr_err_mode_i.value = 0
    dut.hdr_timeout_en_i.value = 0
    # A zero threshold would assert the ungated timeout comparator at reset.
    dut.t_hdr_timeout_i.value = 30000
    await ClockCycles(dut.clk_i, 10)


async def count_high_cycles(clk, sig, e_terminate, *, rising_edges=False):
    """
    Count asserted cycles, or rising edges when a detection spans multiple cycles.
    """
    num_det = 0
    previous = 0
    while not e_terminate.is_set():
        await RisingEdge(clk)
        await ReadOnly()
        assert sig.value.is_resolvable, f"{sig._name} contains X/Z"
        value = int(sig.value)
        if value and (not rising_edges or not previous):
            num_det += 1
        previous = value
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
async def test_bus_monitor_hdr_exit(dut: SimHandleBase):
    """
    Test bus monitor:
        - Check if hdr exit condition is detected
        - If the controller is in the HDR mode we should detect HDR exit condition
    """
    cocotb.log.setLevel("INFO")
    clk = dut.clk_i
    rst_n = dut.rst_ni
    i3c_controller = create_default_controller(dut)

    clock = Clock(clk, 2, units="ns")
    cocotb.start_soon(clock.start())

    await setup(dut)
    await reset_n(clk, rst_n, cycles=5)

    for phase_ns in (0.25, 1.25):
        for in_hdr in (0, 1):
            await FallingEdge(clk)
            dut.enable_i.value = 1
            dut.is_in_hdr_mode_i.value = in_hdr
            e_terminate = cocotb.triggers.Event()
            t_detect_hdr_exit = cocotb.start_soon(
                count_high_cycles(clk, dut.hdr_exit_detect_o, e_terminate, rising_edges=True)
            )
            t_detect_pattern = cocotb.start_soon(
                count_high_cycles(clk, dut.xi3c_monitor.hdr_exit_pattern_detect, e_terminate, rising_edges=True)
            )
            # Keep the BFM's 40 ns transitions away from the 2 ns sampling-clock edges.
            await Timer(phase_ns, units="ns")
            await i3c_controller.send_hdr_exit()
            await ClockCycles(clk, 10)
            e_terminate.set()
            num_detects = await t_detect_hdr_exit
            num_patterns = await t_detect_pattern
            cocotb.log.info(f"HDR exit: phase={phase_ns}ns, in_hdr={in_hdr}, output_events={num_detects}, pattern_events={num_patterns}")
            assert num_detects == in_hdr, "Expected no SDR exit and exactly one HDR exit"
            assert num_patterns == in_hdr, "Exit must come from the pattern detector"
            assert int(dut.xi3c_monitor.hdr_timeout_reached.value) == 0, "Timeout masked pattern detection"


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
    num_resets = await t_detect_target_reset
    cocotb.log.info(f"Resets detected: {num_resets}")
    assert num_resets == 1

    e_terminate.clear()

    await ClockCycles(dut.clk_i, 10)
