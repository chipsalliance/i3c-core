# SPDX-License-Identifier: Apache-2.0

from cocotb.handle import SimHandleBase
from hci import HCIBaseTestInterface


class I3CTopTestInterface(HCIBaseTestInterface):
    def __init__(self, dut: SimHandleBase) -> None:
        super().__init__(dut)

    async def setup(self):
        await self._setup()

    async def reset(self):
        await self._reset()
