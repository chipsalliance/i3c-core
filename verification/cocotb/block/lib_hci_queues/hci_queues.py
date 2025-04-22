# SPDX-License-Identifier: Apache-2.0

from random import randint

from bus2csr import bytes2int, get_frontend_bus_if
from hci import ErrorStatus, HCIBaseTestInterface, ResponseDescriptor
from utils import expect_with_timeout, mask_bits

from cocotb.handle import SimHandleBase
from cocotb.triggers import RisingEdge


class HCIQueuesTestInterface(HCIBaseTestInterface):
    def __init__(self, dut: SimHandleBase) -> None:
        super().__init__(dut, "hci")

    async def setup(self):
        # Set queue's ready to 0 (hold accepting the data)
        self.dut.hci_cmd_rready_i.value = 0
        self.dut.hci_tx_rready_i.value = 0
        self.dut.hci_rx_wvalid_i.value = 0
        self.dut.hci_ibi_wvalid_i.value = 0
        self.dut.hci_resp_wvalid_i = 0

        if hasattr(self.dut, "disable_id_filtering_i"):
            self.dut.disable_id_filtering_i.value = 1

        await super()._setup(get_frontend_bus_if())

    async def reset(self):
        await self._reset()

    async def read_queue_size(self, queue: str):
        # Queue size offsets in appropriate registers
        off = {"rx": 16, "tx": 24, "cmd": 0, "resp": 0, "ibi": 8}
        queue_size = bytes2int(await self.read_csr(self.reg_map.PIOCONTROL.QUEUE_SIZE.base_addr, 4))
        if queue in ["rx", "tx"]:
            return 2 ** (((queue_size >> off[queue]) & 0x7) + 1)
        if queue in ["cmd", "ibi"]:
            return (queue_size >> off[queue]) & mask_bits(8)
        # Size of the response queue
        alt_queue_size = bytes2int(await self.read_csr(self.reg_map.PIOCONTROL.ALT_QUEUE_SIZE.base_addr, 4))
        cr_size = queue_size & mask_bits(8)
        alt_resp_size = alt_queue_size & mask_bits(8)
        alt_resp_en = (alt_queue_size >> 24) & 0x1
        return alt_resp_size if alt_resp_en else cr_size

    # Helper functions to fetch / put data to either side
    # of the queues
    async def put_response_desc(self, resp: int = None, timeout: int = 20, units: str = "us"):
        if not resp:
            resp = ResponseDescriptor(4, 42, ErrorStatus.SUCCESS).to_int()
        self.dut.hci_resp_wdata_i.value = resp
        self.dut.hci_resp_wvalid_i.value = 1
        # In case ready is already set, assert valid at the next rising edge
        await RisingEdge(self.clk)
        await expect_with_timeout(self.dut.hci_resp_wready_o, True, self.clk, timeout, units)
        self.dut.hci_resp_wvalid_i.value = 0

    async def get_command_desc(self, timeout: int = 20, units: str = "us") -> int:
        self.dut.hci_cmd_rready_i.value = 1
        await RisingEdge(self.clk)
        await expect_with_timeout(self.dut.hci_cmd_rvalid_o, True, self.clk, timeout, units)
        self.dut.hci_cmd_rready_i.value = 0
        return self.dut.hci_cmd_rdata_o.value.integer

    async def get_tx_data(self, timeout: int = 20, units: str = "us") -> int:
        self.dut.hci_tx_rready_i.value = 1
        await RisingEdge(self.clk)
        await expect_with_timeout(self.dut.hci_tx_rvalid_o, True, self.clk, timeout, units)
        self.dut.hci_tx_rready_i.value = 0
        return self.dut.hci_tx_rdata_o.value.integer

    async def put_rx_data(self, rx_data: int = None, timeout: int = 20, units: str = "us"):
        if not rx_data:
            rx_data = randint(0, 2**32 - 1)
        self.dut.hci_rx_wdata_i.value = rx_data
        self.dut.hci_rx_wvalid_i.value = 1
        # In case ready is already set, assert valid at the next rising edge
        await RisingEdge(self.clk)
        await expect_with_timeout(self.dut.hci_rx_wready_o, True, self.clk, timeout, units)
        self.dut.hci_rx_wvalid_i.value = 0

    async def put_ibi_data(self, ibi_data: int = None, timeout: int = 2, units: str = "ms"):
        if not ibi_data:
            ibi_data = randint(0, 2**32 - 1)
        self.dut.hci_ibi_wdata_i.value = ibi_data
        self.dut.hci_ibi_wvalid_i.value = 1
        # In case ready is already set, assert valid at the next rising edge
        await RisingEdge(self.clk)
        await expect_with_timeout(self.dut.hci_ibi_wready_o, True, self.clk, timeout, units)
        self.dut.hci_ibi_wvalid_i.value = 0
