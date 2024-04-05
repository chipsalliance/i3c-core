import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ReadOnly

I3C_PHY_DELAY = 2
CLOCK_PERIOD_NS = 10


def get_current_time_ns():
    return cocotb.simulator.get_sim_time()[1] / 100


async def init_phy(clock, reset_n):
    cocotb.start_soon(Clock(clock, CLOCK_PERIOD_NS, "ns").start())

    await ClockCycles(clock, 10)
    reset_n.value = 1
    await ClockCycles(clock, 10)


async def check_delayed(clock, signal, expected, delay=I3C_PHY_DELAY):
    await ClockCycles(clock, delay)
    await ReadOnly()
    time_ns = get_current_time_ns()
    signal._log.debug(f"Comparing {signal._name} ({signal.value} vs {expected})")
    assert (
        int(signal.value) == expected
    ), f"Incorrect value of signal {signal._name} at {time_ns} ns ({signal.value} vs {expected})"
