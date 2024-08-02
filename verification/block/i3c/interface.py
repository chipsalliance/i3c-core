# SPDX-License-Identifier: Apache-2.0

from bus2csr import AHBTestInterface
from cocotb.handle import SimHandleBase
from hci import HCIBaseTestInterface


class I3CTopTestInterface(HCIBaseTestInterface):
    def __init__(self, dut: SimHandleBase) -> None:
        super().__init__(dut, "hci")

    async def setup(self):
        await self._setup(AHBTestInterface)

    async def reset(self):
        await self._reset()
