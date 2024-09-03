# SPDX-License-Identifier: Apache-2.0

import os
import cocotb
from cocotb.triggers import ClockCycles
from cocotb_helpers import reset_n
from bus2csr import get_frontend_bus_if, AXITestInterface, AHBTestInterface
from dissect.cstruct import cstruct
from cocotb.handle import SimHandleBase
from cocotb.clock import Clock

class I3CTopTestInterface:

    def __init__(self, dut: SimHandleBase) -> None:
        self.dut = dut
        self.bus_if_cls = get_frontend_bus_if()
        self.register_map = self.get_regs_map()

        self.busIf = self.bus_if_cls(dut)
        self.clk = self.busIf.clk
        self.rst_n = self.busIf.rst_n
        self.read_csr = self.busIf.read_csr
        self.write_csr = self.busIf.write_csr


    async def setup(self):
        clock = Clock(self.clk, 2, units="ns")
        cocotb.start_soon(clock.start())

        await ClockCycles(self.clk, 20)
        await reset_n(self.clk, self.rst_n, cycles=5)

    def get_regs_map(self):
        """
        Load
            #define REG value
        into a dictionary
        """
        i3c_root_dir = os.environ.get("I3C_ROOT_DIR")
        reg_f = i3c_root_dir + "/sw/I3CCSR_registers.h"
        text = []
        with open(reg_f) as f:
            for line in f:
                if line.startswith("#define"):
                    text.append(line)

        defs_str = "".join(text)
        c = cstruct()
        c.load(defs_str)
        return c.consts
