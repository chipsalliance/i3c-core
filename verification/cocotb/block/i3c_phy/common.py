import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

I3C_CLOCK_DIV = 8
CLOCK_PERIOD_NS = 10


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
