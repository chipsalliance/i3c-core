# SPDX-License-Identifier: Apache-2.0

from random import randint

from bus2csr import bytes2int, dword2int, get_frontend_bus_if, int2dword
from hci import HCIBaseTestInterface
from utils import expect_with_timeout

from cocotb.handle import SimHandleBase
from cocotb.triggers import RisingEdge


# TODO: Merge `tti_queues.py` with `hci_queues.py` by creating a common class
class TTIQueuesTestInterface(HCIBaseTestInterface):
    def __init__(self, dut: SimHandleBase) -> None:
        super().__init__(dut, "tti")

    async def setup(self):
        # Set queue's ready to 0 (hold accepting the data)
        self.dut.hci_cmd_rready_i.value = 0
        self.dut.hci_tx_rready_i.value = 0
        self.dut.tti_tx_rready_i.value = 0
        self.dut.tti_tx_desc_rready_i.value = 0
        self.dut.hci_rx_wvalid_i.value = 0
        self.dut.hci_ibi_wvalid_i.value = 0
        self.dut.hci_resp_wvalid_i.value = 0
        self.dut.tti_rx_wvalid_i.value = 0
        self.dut.tti_rx_desc_wvalid_i.value = 0
        self.dut.tti_ibi_rready_i.value = 0
        self.dut.tti_rx_flush_i.value = 0
        self.dut.tti_tx_flush_i.value = 0
        self.dut.virtual_device_tx_i = 0

        await super()._setup(get_frontend_bus_if())

    async def reset(self):
        await self._reset()

    async def read_queue_size(self, queue: str):
        # Queue size offsets in appropriate registers
        off = {"rx_desc": 0, "tx_desc": 8, "rx": 16, "tx": 24, "ibi": 0}
        assert queue in off.keys()

        queue_size = bytes2int(await self.read_csr(self.reg_map.I3C_EC.TTI.QUEUE_SIZE.base_addr, 4))
        return 2 ** (((queue_size >> off[queue]) & 0x7) + 1)

    # Helper functions to fetch / put data to either side
    # of the queues
    async def put_rx_desc(self, data: int = None, timeout: int = 20, units: str = "us"):
        if not data:
            data = randint(1, 2**32 - 1)
        self.dut.tti_rx_desc_wdata_i.value = data
        self.dut.tti_rx_desc_wvalid_i.value = 1
        # In case ready is already set, assert valid at the next rising edge
        await RisingEdge(self.clk)
        await expect_with_timeout(self.dut.tti_rx_desc_wready_o, True, self.clk, timeout, units)
        self.dut.tti_rx_desc_wvalid_i.value = 0

    async def get_rx_desc(self) -> int:
        return dword2int(
            await self.read_csr(self.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4)
        )

    async def get_tx_desc(self, timeout: int = 20, units: str = "us") -> int:
        self.dut.tti_tx_desc_rready_i.value = 1
        await RisingEdge(self.clk)
        await expect_with_timeout(self.dut.tti_tx_desc_rvalid_o, True, self.clk, timeout, units)
        self.dut.tti_tx_desc_rready_i.value = 0
        return self.dut.tti_tx_desc_rdata_o.value.integer

    async def put_tx_desc(self, data: int = None) -> None:
        if not data:
            data = randint(1, 2**32 - 1)
        await self.write_csr(
            self.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(data), 4
        )

    async def get_tx_data(self, timeout: int = 20, units: str = "us") -> int:

        # The queue interface is actually 8-bit. Since the data width converter
        # operates on complete 32-bit words only there should be always 4 bytes
        # to be read.

        await RisingEdge(self.clk)
        self.dut.tti_tx_rready_i.value = 1

        word = 0
        for i in range(4):
            await RisingEdge(self.clk)
            await expect_with_timeout(self.dut.tti_tx_rvalid_o, True, self.clk, timeout, units)

            # Store byte (little-endian)
            word >>= 8
            word |= self.dut.tti_tx_rdata_o.value.integer << 24

        self.dut.tti_tx_rready_i.value = 0
        return word

    async def put_tx_data(self, data: int = None):
        if not data:
            data = randint(1, 2**32 - 1)
        await self.write_csr(self.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, int2dword(data), 4)

    async def put_rx_data(self, data: int = None, timeout: int = 20, units: str = "us"):
        if not data:
            data = randint(1, 2**32 - 1)

        # The queue interface is actually 8-bit. Assume that we are writing complete
        # 32-bit words. Repeat the write 4 times.
        for i in range(4):

            # Get byte (little endian)
            byte = data & 0xFF
            data >>= 8

            self.dut.tti_rx_wdata_i.value = byte
            self.dut.tti_rx_wvalid_i.value = 1
            # In case ready is already set, assert valid at the next rising edge
            await RisingEdge(self.clk)
            await expect_with_timeout(self.dut.tti_rx_wready_o, True, self.clk, timeout, units)
            self.dut.tti_rx_wvalid_i.value = 0

    async def get_rx_data(self) -> int:
        return dword2int(await self.read_csr(self.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, 4))

    async def put_ibi_data(self, ibi_data: int = None):
        if not ibi_data:
            ibi_data = randint(1, 2**32 - 1)
        await self.write_csr(self.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, int2dword(ibi_data), 4)
