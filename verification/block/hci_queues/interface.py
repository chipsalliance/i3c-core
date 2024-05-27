# SPDX-License-Identifier: Apache-2.0

from random import randint

from cocotb.handle import SimHandleBase
from cocotb.triggers import RisingEdge
from hci import ErrorStatus, HCIBaseTestInterface, ResponseDescriptor

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
            return (queue_size >> off[queue]) & 0x7F
        elif queue == "cmd":
            return 2 ** (((queue_size >> off[queue]) & 0x7F) + 1)
        # Size of the response queue
        alt_queue_size = ahb_data_to_int(await self.read_csr(ALT_QUEUE_SIZE, 4))
        cr_size = queue_size & 0x7F
        alt_resp_size = alt_queue_size & 0x7F
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
    async def put_response_desc(self, resp: int = None):
        if not resp:
            resp = ResponseDescriptor(4, 42, ErrorStatus.SUCCESS).to_int()
        self.dut.resp_fifo_wdata_i.value = resp
        self.dut.resp_fifo_wvalid_i.value = 1
        while True:
            await RisingEdge(self.dut.hclk)
            if self.dut.resp_fifo_wready_o.value:
                break
        self.dut.resp_fifo_wvalid_i.value = 0

    async def get_command_desc(self) -> int:
        self.dut.cmd_fifo_rready_i.value = 1
        while not self.dut.cmd_fifo_rvalid_o.value:
            await RisingEdge(self.dut.hclk)
        self.dut.cmd_fifo_rready_i.value = 0
        return self.dut.cmd_fifo_rdata_o.value.integer

    async def get_tx_data(self) -> int:
        self.dut.tx_fifo_rready_i.value = 1
        while not self.dut.tx_fifo_rvalid_o.value:
            await RisingEdge(self.dut.hclk)
        self.dut.tx_fifo_rready_i.value = 0
        return self.dut.tx_fifo_rdata_o.value.integer

    async def put_rx_data(self, rx_data: int = None):
        if not rx_data:
            rx_data = randint(0, 2**32 - 1)
        self.dut.rx_fifo_wdata_i.value = rx_data
        self.dut.rx_fifo_wvalid_i.value = 1
        while True:
            await RisingEdge(self.dut.hclk)
            if self.dut.rx_fifo_wready_o.value:
                break
        self.dut.rx_fifo_wvalid_i.value = 0
