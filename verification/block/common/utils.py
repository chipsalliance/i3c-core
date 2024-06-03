# SPDX-License-Identifier: Apache-2.0

from math import ceil, log2
from random import randint

import cocotb
from cocotb.triggers import ClockCycles, ReadOnly, RisingEdge, with_timeout


def get_current_time_ns():
    return cocotb.utils.get_sim_time("ns")


async def check_delayed(clock, signal, expected, delay):
    await ClockCycles(clock, delay)
    await ReadOnly()
    time_ns = get_current_time_ns()
    signal._log.debug(f"Comparing {signal._name} ({signal.value} vs {expected})")
    assert (
        int(signal.value) == expected
    ), f"Incorrect value of signal {signal._name} at {time_ns} ns ({signal.value} vs {expected})"


def clog2(val: int):
    return ceil(log2(val))


async def expect_with_timeout(signal, expected, clk, timeout: int = 2, units: str = "ms"):
    async def wait_cond():
        while signal.value != expected:
            await RisingEdge(clk)

    # Apply timeout
    await with_timeout(wait_cond(), timeout, units)


def rand_bits(width):
    return randint(1, 2 ** (width - 1) - 1)


def rand_bits32():
    return rand_bits(32)


def mask_bits(width):
    return 2**width - 1
