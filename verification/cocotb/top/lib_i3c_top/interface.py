# SPDX-License-Identifier: Apache-2.0

import os

from bus2csr import get_frontend_bus_if
from dissect.cstruct import cstruct
from hci import HCIBaseTestInterface

from cocotb.handle import SimHandleBase


class I3CTopTestInterface(HCIBaseTestInterface):
    def __init__(self, dut: SimHandleBase) -> None:
        super().__init__(dut, "hci")
        self.register_map = self.get_regs_map()

    async def setup(self):
        await self._setup(get_frontend_bus_if())

    async def reset(self):
        await self._reset()

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
