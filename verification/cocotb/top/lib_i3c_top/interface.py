# SPDX-License-Identifier: Apache-2.0

from bus2csr import get_frontend_bus_if
from cocotb_helpers import reset_n
from reg_map import reg_map

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles


class I3CTopTestInterface:

    def __init__(self, dut: SimHandleBase) -> None:
        self.dut = dut
        self.bus_if_cls = get_frontend_bus_if()
        self.reg_map = reg_map

        self.busIf = self.bus_if_cls(dut)
        self.clk = self.busIf.clk
        self.rst_n = self.busIf.rst_n
        self.read_csr = self.busIf.read_csr
        self.write_csr = self.busIf.write_csr
        self.read_csr_field = self.busIf.read_csr_field
        self.write_csr_field = self.busIf.write_csr_field

    async def setup(self, fclk=500.0):

        # Limit the requested clock frequency if a limit is set via cocotb
        # plusargs
        fmin = cocotb.plusargs.get("MinSystemClockFrequency", None)
        if fmin is not None:
            fmin = float(fmin)
            if fclk < fmin:
                self.dut._log.warning(f"Enforcing min. system clock frequency of {fmin:.3f} MHz")
                fclk = fmin

        await self.busIf.register_test_interfaces(fclk)
        await ClockCycles(self.clk, 20)
        await reset_n(self.clk, self.rst_n, cycles=5)
