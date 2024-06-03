# SPDX-License-Identifier: Apache-2.0

from random import randint

from cocotb.handle import SimHandleBase
from cocotb.triggers import RisingEdge
from hci import ErrorStatus, HCIBaseTestInterface, ResponseDescriptor
from utils import expect_with_timeout

from ahb_if import ahb_data_to_int


class HCIQueuesTestInterface(HCIBaseTestInterface):
    def __init__(self, dut: SimHandleBase) -> None:
        super().__init__(dut)

    async def setup(self):
        await self._setup()

        # Set queue's ready to 0 (hold accepting the data)
        self.dut.cmd_fifo_rready_i.value = 0
        self.dut.tx_fifo_rready_i.value = 0

    async def reset(self):
        await self._reset()

    async def read_queue_size(self, queue: str):
        # Queue size offsets in appropriate registers
        off = {"rx": 16, "tx": 24, "cmd": 0, "resp": 0}
        QUEUE_SIZE = 0x118
        ALT_QUEUE_SIZE = 0x11C
        queue_size = ahb_data_to_int(await self.read_csr(QUEUE_SIZE, 4))
        if queue in ["rx", "tx"]:
            return 2 ** (((queue_size >> off[queue]) & 0x7) + 1)
        if queue == "cmd":
            return (queue_size >> off[queue]) & 0xFF
        # Size of the response queue
        alt_queue_size = ahb_data_to_int(await self.read_csr(ALT_QUEUE_SIZE, 4))
        cr_size = queue_size & 0xFF
        alt_resp_size = alt_queue_size & 0xFF
        alt_resp_en = (alt_queue_size >> 24) & 0x1
        return alt_resp_size if alt_resp_en else cr_size

    def get_empty(self, queue: str):
        return getattr(self.dut, f"{queue}_fifo_empty_o").value

    def get_full(self, queue: str):
        return getattr(self.dut, f"{queue}_fifo_full_o").value

    def get_thld(self, queue: str):
        return getattr(self.dut, f"{queue}_fifo_thld_o").value

    def get_apch_thld(self, queue: str):
        return getattr(self.dut, f"{queue}_fifo_apch_thld_o").value

    # Helper functions to fetch / put data to either side
    # of the queues
    async def put_response_desc(self, resp: int = None, timeout: int = 2, units: str = "ms"):
        if not resp:
            resp = ResponseDescriptor(4, 42, ErrorStatus.SUCCESS).to_int()
        self.dut.resp_fifo_wdata_i.value = resp
        self.dut.resp_fifo_wvalid_i.value = 1
        # In case ready is already set, assert valid at the next rising edge
        await RisingEdge(self.dut.hclk)
        await expect_with_timeout(self.dut.resp_fifo_wready_o, True, self.dut.hclk, timeout, units)
        self.dut.resp_fifo_wvalid_i.value = 0

    async def get_command_desc(self, timeout: int = 2, units: str = "ms") -> int:
        self.dut.cmd_fifo_rready_i.value = 1
        await expect_with_timeout(self.dut.cmd_fifo_rvalid_o, True, self.dut.hclk, timeout, units)
        self.dut.cmd_fifo_rready_i.value = 0
        return self.dut.cmd_fifo_rdata_o.value.integer

    async def get_tx_data(self, timeout: int = 2, units: str = "ms") -> int:
        self.dut.tx_fifo_rready_i.value = 1
        await expect_with_timeout(self.dut.tx_fifo_rvalid_o, True, self.dut.hclk, timeout, units)
        self.dut.tx_fifo_rready_i.value = 0
        return self.dut.tx_fifo_rdata_o.value.integer

    async def put_rx_data(self, rx_data: int = None, timeout: int = 2, units: str = "ms"):
        if not rx_data:
            rx_data = randint(0, 2**32 - 1)
        self.dut.rx_fifo_wdata_i.value = rx_data
        self.dut.rx_fifo_wvalid_i.value = 1
        # In case ready is already set, assert valid at the next rising edge
        await RisingEdge(self.dut.hclk)
        await expect_with_timeout(self.dut.rx_fifo_wready_o, True, self.dut.hclk, timeout, units)
        self.dut.rx_fifo_wvalid_i.value = 0
