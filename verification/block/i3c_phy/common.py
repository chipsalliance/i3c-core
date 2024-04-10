import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ReadOnly

I3C_CLOCK_DIV = 8
I3C_PHY_DELAY = 2
CLOCK_PERIOD_NS = 10


def get_current_time_ns():
    return cocotb.utils.get_sim_time("ns")


async def init_phy(dut):
    clock = dut.clk_i
    reset_n = dut.rst_ni
    cocotb.start_soon(Clock(clock, CLOCK_PERIOD_NS, "ns").start())

    # Mock pull up on I3C bus lines
    dut.scl_i.value = 1
    dut.sda_i.value = 1

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
