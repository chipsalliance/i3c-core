# SPDX-License-Identifier: Apache-2.0

from math import ceil, log2

import cocotb
from cocotb.triggers import ClockCycles, ReadOnly


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
