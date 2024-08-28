# SPDX-License-Identifier: Apache-2.0

from random import randint

from bus2csr import bytes2int, dword2int, get_frontend_bus_if, int2dword
from hci import (
    TTI_IBI_PORT,
    TTI_QUEUE_SIZE,
    TTI_RX_DATA_PORT,
    TTI_RX_DESCRIPTOR_QUEUE_PORT,
    TTI_TX_DATA_PORT,
    TTI_TX_DESCRIPTOR_QUEUE_PORT,
    HCIBaseTestInterface,
)
from utils import expect_with_timeout

from cocotb.handle import SimHandleBase
from cocotb.triggers import RisingEdge


# TODO: Merge `tti_queues.py` with `hci_queues.py` by creating a common class
class TTIQueuesTestInterface(HCIBaseTestInterface):
    def __init__(self, dut: SimHandleBase) -> None:
        super().__init__(dut, "tti")

    async def setup(self):
        await super()._setup(get_frontend_bus_if())

        # Set queue's ready to 0 (hold accepting the data)
        self.dut.tti_tx_desc_queue_rready_i.value = 0
        self.dut.tti_tx_queue_rready_i.value = 0

    async def reset(self):
        await self._reset()

    async def read_queue_size(self, queue: str):
        # Queue size offsets in appropriate registers
        off = {"rx_desc": 0, "tx_desc": 8, "rx": 16, "tx": 24, "ibi": 0}
        assert queue in off.keys()

        queue_size = bytes2int(await self.read_csr(TTI_QUEUE_SIZE, 4))
        return 2 ** (((queue_size >> off[queue]) & 0x7) + 1)

    # Helper functions to fetch / put data to either side
    # of the queues
    async def put_rx_desc(self, data: int = None, timeout: int = 20, units: str = "us"):
        if not data:
            data = randint(1, 2**32 - 1)
        self.dut.tti_rx_desc_queue_wdata_i.value = data
        self.dut.tti_rx_desc_queue_wvalid_i.value = 1
        # In case ready is already set, assert valid at the next rising edge
        await RisingEdge(self.clk)
        await expect_with_timeout(
            self.dut.tti_rx_desc_queue_wready_o, True, self.clk, timeout, units
        )
        self.dut.tti_rx_desc_queue_wvalid_i.value = 0

    async def get_rx_desc(self) -> int:
        return dword2int(await self.read_csr(TTI_RX_DESCRIPTOR_QUEUE_PORT, 4))

    async def get_tx_desc(self, timeout: int = 20, units: str = "us") -> int:
        self.dut.tti_tx_desc_queue_rready_i.value = 1
        await RisingEdge(self.clk)
        await expect_with_timeout(
            self.dut.tti_tx_desc_queue_rvalid_o, True, self.clk, timeout, units
        )
        self.dut.tti_tx_desc_queue_rready_i.value = 0
        return self.dut.tti_tx_desc_queue_rdata_o.value.integer

    async def put_tx_desc(self, data: int = None) -> None:
        if not data:
            data = randint(1, 2**32 - 1)
        await self.write_csr(TTI_TX_DESCRIPTOR_QUEUE_PORT, int2dword(data), 4)

    async def get_tx_data(self, timeout: int = 20, units: str = "us") -> int:
        self.dut.tti_tx_queue_rready_i.value = 1
        await RisingEdge(self.clk)
        await expect_with_timeout(self.dut.tti_tx_queue_rvalid_o, True, self.clk, timeout, units)
        self.dut.tti_tx_queue_rready_i.value = 0
        return self.dut.tti_tx_queue_rdata_o.value.integer

    async def put_tx_data(self, data: int = None):
        if not data:
            data = randint(1, 2**32 - 1)
        await self.write_csr(TTI_TX_DATA_PORT, int2dword(data), 4)

    async def put_rx_data(self, data: int = None, timeout: int = 20, units: str = "us"):
        if not data:
            data = randint(1, 2**32 - 1)
        self.dut.tti_rx_queue_wdata_i.value = data
        self.dut.tti_rx_queue_wvalid_i.value = 1
        # In case ready is already set, assert valid at the next rising edge
        await RisingEdge(self.clk)
        await expect_with_timeout(self.dut.tti_rx_queue_wready_o, True, self.clk, timeout, units)
        self.dut.tti_rx_queue_wvalid_i.value = 0

    async def get_rx_data(self) -> int:
        return dword2int(await self.read_csr(TTI_RX_DATA_PORT, 4))

    async def put_ibi_data(self, ibi_data: int = None):
        if not ibi_data:
            ibi_data = randint(1, 2**32 - 1)
        await self.write_csr(TTI_IBI_PORT, int2dword(ibi_data), 4)
