# SPDX-License-Identifier: Apache-2.0

from math import ceil, log2
from random import randint

from cocotb.runner import check_results_file, get_runner
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, with_timeout


async def toggle(clk, signal, cycles=1):
    await ClockCycles(clk, cycles)
    signal.value = 0 if (int(signal.value)) else 1


async def cycle(clk, signal):
    """
    TODO: Rename to pulse
    """
    await toggle(clk, signal)
    await toggle(clk, signal)


async def _reset(clk, rst, cycles=1, active_low=False):
    rst.value = 0 if active_low else 1
    await ClockCycles(clk, cycles)
    await FallingEdge(clk)
    rst.value = 1 if active_low else 0


async def reset(clk, rst, cycles=1):
    await _reset(clk, rst, cycles, active_low=False)


async def reset_n(clk, rst, cycles=1):
    await _reset(clk, rst, cycles, active_low=True)


async def timeout(clk, signal, exp_val, timeout_threshold):
    """
    TODO: this function duplicates functionality of expect_with_timeout,
    but is used, so we will have to refactor tests before dropping it
    """
    timeout = 0
    while signal.value != exp_val:
        timeout += 1
        await RisingEdge(clk)
        if timeout > timeout_threshold:
            raise TimeoutError(f"timeout {signal.name}")


async def expect_with_timeout(signal, expected, clk, timeout: int = 2, units: str = "ms"):
    async def wait_cond():
        while signal.value != expected:
            await RisingEdge(clk)

    await with_timeout(wait_cond(), timeout, units)


def clog2(val: int):
    return ceil(log2(val))


def rand_bits(width):
    return randint(1, 2 ** (width - 1) - 1)


def rand_bits32():
    return rand_bits(32)


def mask_bits(width):
    return 2**width - 1


def run_test(toplevel, test_module, verilog_sources):
    build_dir = "sim_build"
    runner = get_runner("icarus")
    runner.build(
        verilog_sources=verilog_sources,
        hdl_toplevel=toplevel,
        timescale=("1ns", "1ps"),
        build_dir=build_dir,
        waves=True,
    )
    results_xml = runner.test(
        hdl_toplevel=toplevel,
        test_module=test_module,
        waves=True,
    )
    check_results_file(results_xml)
