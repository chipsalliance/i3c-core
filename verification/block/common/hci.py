# SPDX-License-Identifier: Apache-2.0

from dataclasses import dataclass
from enum import IntEnum
from random import randint

from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, RisingEdge, Timer

from ahb_if import AHBFIFOTestInterface, ahb_data_to_int, int_to_ahb_data

# HCI queue port addresses
CMD_PORT = 0x100
RX_PORT = 0x108
TX_PORT = 0x108
RESP_PORT = 0x104
RESET_CONTROL = 0x10
QUEUE_THLD_CTRL = 0x110
DATA_BUFFER_THLD_CTRL = 0x114


@dataclass
class regular_transfer_descriptor:
    tid: int
    cmd: int
    cp: bool
    device_index: int
    short_read_err: int
    defining_byte_present: int
    mode: int
    rnw: bool
    wroc: bool
    toc: bool
    def_byte: int
    data_length: int

    def to_int(self):
        cmd_attr = 0  # Regular transfer identifier
        return (
            (self.data_length & 0xFFFF) << 48
            | (self.def_byte & 0xFF) << 32
            | (int(self.toc) & 0x1) << 31
            | (int(self.wroc) & 0x1) << 30
            | (int(self.rnw) & 0x1) << 29
            | (self.mode & 0x7) << 26
            | (self.defining_byte_present & 0x1) << 25
            | (self.short_read_err & 0x1) << 24
            | (self.device_index & 0x1F) << 16
            | (int(self.cp) & 0x1) << 15
            | (self.cmd & 0xFF) << 7
            | (self.tid & 0xF) << 3
            | (cmd_attr & 0x7)
        )


@dataclass
class immediate_transfer_descriptor:
    tid: int
    cmd: int
    cp: bool
    device_index: int
    byte_count: int
    mode: int
    rnw: bool
    wroc: bool
    toc: bool
    data: int

    def to_int(self):
        cmd_attr = 1  # Immediate transfer identifier
        return (
            (self.data & 0xFFFFFFFF) << 32
            | (int(self.toc) & 0x1) << 31
            | (int(self.wroc) & 0x1) << 30
            | (int(self.rnw) & 0x1) << 29
            | (self.mode & 0x7) << 26
            | (self.byte_count & 0x7) << 23
            | (self.device_index & 0x1F) << 16
            | (int(self.cp) & 0x1) << 15
            | (self.cmd & 0xFF) << 7
            | (self.tid & 0xF) << 3
            | (cmd_attr & 0x7)
        )


class ErrorStatus(IntEnum):
    SUCCESS = 0
    CRC = 1
    PARITY = 2
    FRAME = 3
    ADDRESS_HEADER = 4
    # Address was NACK'ed or Dynamic Address Assignment was NACK'ed
    NACK = 5
    # Receive overflow or transfer underflow error
    OVL = 6
    # Target returned fewer bytes than requested in DATA_LENGTH field
    # of a transfer command where short read was not permitted
    I3C_SHORT_READ = 7
    # Terminated by host controller due to internal error or Abort operation
    HC_ABORTED = 8
    # Transfer terminated by due to bus action
    # * for I2C transfers: I2C_WR_DATA_NACK
    # * for I3C transfers: BUS_ABORTED
    I2C_DATA_NACK_OR_I3C_BUS_ABORTED = 9
    # Command not supported by the Host Controller implementation
    NOT_SUPPORTED = 10
    # Transfer Type Specific Errors
    C = 12
    D = 13
    E = 14
    F = 15


@dataclass
class ResponseDescriptor:
    data_length: int
    tid: int
    err_status: ErrorStatus

    def from_int(self, word: int):
        self.data_length = word & 0xFFFF
        self.tid = (word >> 24) & 0xF
        self.err_status = ErrorStatus((word >> 28) & 0xF)

    def to_int(self):
        return (self.err_status & 0xF) << 28 | (self.tid & 0xF) << 24 | (self.data_length & 0xFFFF)


class HCIBaseTestInterface:
    def __init__(self, dut: SimHandleBase) -> None:
        self.dut = dut
        self.queue_names = ["cmd", "tx", "rx", "resp"]
        self.status_indicators = ["thld", "full", "empty", "apch_thld"]

    async def _setup(self):
        self.ahb_if = AHBFIFOTestInterface(self.dut)
        await self.ahb_if.register_test_interfaces()
        # Borrow CSR access methods
        self.read_csr = self.ahb_if.read_csr
        self.write_csr = self.ahb_if.write_csr

        await self._reset()

    async def _reset(self):
        self.dut.hreset_n.value = 0
        await ClockCycles(self.dut.hclk, 10)
        await RisingEdge(self.dut.hclk)
        await Timer(1, units="ns")
        self.dut.hreset_n.value = 1
        await RisingEdge(self.dut.hclk)

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
    async def get_response_desc(self) -> int:
        return ahb_data_to_int(await self.read_csr(RESP_PORT, 4))

    async def put_command_desc(self, desc: int = None) -> None:
        # If descriptor is not passed, utilize the default
        if not desc:
            desc = immediate_transfer_descriptor(0, 0, 0, 0, 1, 0, 0, 1, 1, 0xBEEF).to_int()

        cmd0 = int_to_ahb_data(desc & 0xFFFFFFFF)
        cmd1 = int_to_ahb_data((desc >> 32) & 0xFFFFFFFF)

        # Command is expected to be sent over 2 transfers
        await self.write_csr(CMD_PORT, cmd0, 4)
        await self.write_csr(CMD_PORT, cmd1, 4)

    async def put_tx_data(self, tx_data: int = None):
        if not tx_data:
            tx_data = randint(0, 2**32 - 1)
        await self.write_csr(TX_PORT, int_to_ahb_data(tx_data), 4)

    async def get_rx_data(self) -> int:
        return ahb_data_to_int(await self.read_csr(RX_PORT, 4))
