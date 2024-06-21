# SPDX-License-Identifier: Apache-2.0

from dataclasses import dataclass
from enum import IntEnum
from random import randint

from bus2csr import FrontBusTestInterface, dword2int, int2dword
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, RisingEdge, Timer

# TODO: obtain numbers from RDL description

# DAT and DCT tables
PIO_ADDR = 0x80
EC_ADDR = 0x100
DAT_ADDR = 0x400
DCT_ADDR = 0x800

# Default register values
HCI_VERSION_v1_2_VALUE = 0x120

# Base registers
HCI_VERSION = 0x0
HC_CONTROL = 0x4 * 1
CONTROLLER_DEVICE_ADDR = 0x4 * 2
HC_CAPABILITIES = 0x4 * 3
RESET_CONTROL = 0x4 * 4
DAT_SECTION_OFFSET = 0x4 * 12
DCT_SECTION_OFFSET = 0x4 * 13
PIO_SECTION_OFFSET = 0x4 * 15
INT_CTRL_CMDS_EN = 0x4 * 19

# PIO registers
CMD_PORT = PIO_ADDR
RESP_PORT = PIO_ADDR + 0x04 * 1
RX_PORT = PIO_ADDR + 0x04 * 2
TX_PORT = PIO_ADDR + 0x04 * 2
QUEUE_THLD_CTRL = PIO_ADDR + 0x04 * 4
DATA_BUFFER_THLD_CTRL = PIO_ADDR + 0x04 * 5
QUEUE_SIZE = PIO_ADDR + 0x04 * 6
ALT_QUEUE_SIZE = PIO_ADDR + 0x04 * 7
PIO_INTR_STATUS_ENABLE = PIO_ADDR + 0x4 * 9
PIO_INTR_SIGNAL_ENABLE = PIO_ADDR + 0x4 * 10
PIO_CONTROL = PIO_ADDR + 0x4 * 12

# Reset values
HC_CONTROL_RESET = 0x1 << 6
DAT_SECTION_OFFSET_RESET = 0x7F << 12 | DAT_ADDR
DCT_SECTION_OFFSET_RESET = 0x7F << 12 | DCT_ADDR
INT_CTRL_CMDS_EN_RESET = 0x35 << 1 | 0x1
QUEUE_THLD_CTRL_RESET = 0x1 << 24 | 0x1 << 16 | 0x1 << 8 | 0x1
DATA_BUFFER_THLD_CTRL_RESET = 0x1 << 24 | 0x1 << 16 | 0x1 << 8 | 0x1
QUEUE_SIZE_RESET = 0x5 << 24 | 0x5 << 16 | 0x40 << 8 | 0x40


# TTI Registers
TTI_ADDR = EC_ADDR + 0xC0
EXTCAP_HEADER = TTI_ADDR + 0x4 * 0
TTI_CONTROL = TTI_ADDR + 0x4 * 1
TTI_STATUS = TTI_ADDR + 0x4 * 2
TTI_INTERRUPT_STATUS = TTI_ADDR + 0x4 * 3
TTI_INTERRUPT_ENABLE = TTI_ADDR + 0x4 * 4
TTI_INTERRUPT_FORCE = TTI_ADDR + 0x4 * 5
TTI_RX_DESCRIPTOR_QUEUE_PORT = TTI_ADDR + 0x4 * 6
TTI_RX_DATA_PORT = TTI_ADDR + 0x4 * 7
TTI_TX_DESCRIPTOR_QUEUE_PORT = TTI_ADDR + 0x4 * 8
TTI_TX_DATA_PORT = TTI_ADDR + 0x4 * 9
TTI_QUEUE_SIZE = TTI_ADDR + 0x4 * 10
TTI_QUEUE_THRESHOLD_CONTROL = TTI_ADDR + 0x4 * 11


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


@dataclass
class dat_entry:
    static_addr: int
    ibi_payload: int
    ibi_reject: int
    crr_reject: int
    ts: int
    ring_id: int
    dynamic_addr: int
    dev_nack_retry_cnt: int
    device: int
    autocmd_mask: int
    autocmd_value: int
    autocmd_mode: int
    autocmd_hdr_code: int

    def to_int(self):
        return (
            (self.autocmd_hdr_code & 0xFF) << 51
            | (self.autocmd_mode & 0x7) << 48
            | (self.autocmd_value & 0xFF) << 40
            | (self.autocmd_mask & 0xFF) << 32
            | (self.device & 0x1) << 31
            | (self.dev_nack_retry_cnt & 0x3) << 29
            | (self.ring_id & 0x7) << 26
            | (self.dynamic_addr & 0xFF) << 16
            | (self.ts & 0x1) << 15
            | (self.crr_reject & 0x1) << 14
            | (self.ibi_reject & 0x1) << 13
            | (self.ibi_payload & 0x1) << 12
            | self.static_addr & 0x7F
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

    async def _setup(self, busIfType: FrontBusTestInterface):
        self.busIf = busIfType(self.dut)
        self.clk = self.busIf.clk
        self.rst_n = self.busIf.rst_n
        await self.busIf.register_test_interfaces()
        # Borrow CSR access methods
        self.read_csr = self.busIf.read_csr
        self.write_csr = self.busIf.write_csr

        await self._reset()

    async def _reset(self):
        self.rst_n.value = 0
        await ClockCycles(self.clk, 10)
        await RisingEdge(self.clk)
        await Timer(1, units="ns")
        self.rst_n.value = 1
        await RisingEdge(self.clk)

    def get_empty(self, queue: str):
        return getattr(self.dut, f"{queue}_queue_empty_o").value

    def get_full(self, queue: str):
        return getattr(self.dut, f"{queue}_queue_full_o").value

    def get_thld(self, queue: str):
        return getattr(self.dut, f"{queue}_queue_thld_o").value

    def get_thld_status(self, queue: str):
        if queue in ["cmd", "tx", "tti_tx_desc", "tti_tx"]:
            trig = "below"
        elif queue in ["resp", "rx", "tti_rx_desc", "tti_rx"]:
            trig = "above"
        else:
            self.dut._log.error(f"Queue {queue} not supported")

        return getattr(self.dut, f"{queue}_queue_{trig}_thld_o").value

    # Helper functions to fetch / put data to either side
    # of the queues
    async def get_response_desc(self) -> int:
        return dword2int(await self.read_csr(RESP_PORT, 4))

    async def put_command_desc(self, desc: int = None) -> None:
        # If descriptor is not passed, utilize the default
        if not desc:
            desc = immediate_transfer_descriptor(0, 0, 0, 0, 1, 0, 0, 1, 1, 0xBEEF).to_int()

        cmd0 = int2dword(desc & 0xFFFFFFFF)
        cmd1 = int2dword((desc >> 32) & 0xFFFFFFFF)

        # Command is expected to be sent over 2 transfers
        await self.write_csr(CMD_PORT, cmd0, 4)
        await self.write_csr(CMD_PORT, cmd1, 4)

    async def put_tx_data(self, tx_data: int = None):
        if not tx_data:
            tx_data = randint(0, 2**32 - 1)
        await self.write_csr(TX_PORT, int2dword(tx_data), 4)

    async def get_rx_data(self) -> int:
        return dword2int(await self.read_csr(RX_PORT, 4))

    async def write_dat_entry(self, index, entry):
        if isinstance(entry, dat_entry):
            entry = entry.to_int()
        elif not isinstance(entry, int):
            self.dut._log.error("DAT entry must be either `integer` or `dat_entry` type")

        self.dut._log.debug(f"Writing {hex(entry)} to DAT entry {index}")
        await self.write_csr(DAT_ADDR + index * 8, int2dword(entry & 0xFFFFFFFF), 4)
        await self.write_csr(DAT_ADDR + index * 8 + 4, int2dword((entry >> 32) & 0xFFFFFFFF), 4)
