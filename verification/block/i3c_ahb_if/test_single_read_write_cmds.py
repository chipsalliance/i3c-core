# SPDX-License-Identifier: Apache-2.0

from ctypes import Array
from random import randint, randrange
from typing import List, Tuple

import cocotb  # type: ignore
from cocotb.clock import Clock  # type: ignore
from cocotb.handle import SimHandle, SimHandleBase  # type: ignore
from cocotb.triggers import ClockCycles, RisingEdge, Timer  # type: ignore
from cocotb_AHB.AHB_common.InterconnectInterface import (  # type: ignore
    InterconnectWrapper,
)
from cocotb_AHB.drivers.DutSubordinate import DUTSubordinate  # type: ignore
from cocotb_AHB.drivers.SimSimpleManager import SimSimpleManager  # type: ignore
from cocotb_AHB.interconnect.SimInterconnect import SimInterconnect  # type: ignore


class WriteCmd:
    """
    Describes a write command for the AHB interface.

    Parameters
    ----------
    address : int
        CSR address in bytes
    value : List[int]
        List of bytes to be written under `address`.
    mask : List[bool]
        Data mask expressed as a list of booleans.
    """

    def __init__(self, address: int, value: List[int], mask: List[bool]):
        self.address = address
        self.value = value
        self.mask = mask

    def to_tuple(self):
        return (self.address, self.value, self.mask)


def gen_rand_seq(start: int = 0, end: int = 0x4000, size: int = 4):
    """
    Generate a random sequence of the CSRs in address space [start, end)
    with a random data to be written into them.

    Parameters
    ----------
    start : int
        Start of the address range expressed in bytes.
    end : int
        End of the address range expressed in bytes.
    size : int
        Size of a singular CSR expressed in bytes.

    Returns
    -------
    [WriteCmd]
        A list of WriteCmd which denotes an order for the CSR writes to be executed.
    """
    seq = [
        WriteCmd(
            randrange(0, 0x4000, 4),
            [randint(0, 255) for _ in range(4)],
            [bool(randint(0, 1)) for _ in range(4)],
        )
        for _ in range(0x1000)
    ]
    return seq


async def setup_dut(dut: SimHandle, clk_period: Tuple[int, str]) -> None:
    """
    Setup clock & reset the unit
    """
    await cocotb.start(Clock(dut.hclk_i, *clk_period).start())
    dut.hreset_n_i.value = 0
    await ClockCycles(dut.hclk_i, 10)
    await RisingEdge(dut.hclk_i)
    await Timer(1, units="ns")
    dut.hreset_n_i.value = 1
    await ClockCycles(dut.hclk_i, 1)


def printable(data: List[int]):
    """
    Converts a list of ints into singular int value.
    """
    assert len(data) == 4
    return int("".join(map(str, data)))


class AHBFIFOTestInterface:
    """
    This interface initializes appropriate cocotb AHB models and provides abstractions for
    common functionalities, such as read / write to CSR.
    """

    def __init__(self, dut: SimHandleBase):
        self.dut = dut

        # FIFO AHB Frontend
        self.AHBSubordinate = DUTSubordinate(dut, bus_width=32)

        # Simulated AHB in control of dispatching commands
        self.AHBManager = SimSimpleManager(bus_width=32)

        # Cocotb-ahb-specific construct for simulation purposes
        self.interconnect = SimInterconnect()

        # Cocotb-ahb-specific construct for simulation purposes
        self.wrapper = InterconnectWrapper()

    async def register_test_interfaces(self):
        # Clocks & resets
        # self.AHBSubordinate.register_clock(self.dut.hclk_i).register_reset(self.dut.hreset_n_i, True)
        self.AHBManager.register_clock(self.dut.hclk_i).register_reset(self.dut.hreset_n_i, True)
        self.interconnect.register_clock(self.dut.hclk_i).register_reset(self.dut.hreset_n_i, True)
        self.wrapper.register_clock(self.dut.hclk_i).register_reset(self.dut.hreset_n_i, True)
        # Interconnect setup
        self.interconnect.register_subordinate(self.AHBSubordinate)
        self.interconnect.register_manager(self.AHBManager)
        # Handled address space
        self.interconnect.register_manager_subordinate_addr(self.AHBManager, self.AHBSubordinate, 0x0, 0x4000)
        self.wrapper.register_interconnect(self.interconnect)

        await cocotb.start(self.AHBManager.start())
        await cocotb.start(self.wrapper.start())
        await cocotb.start(setup_dut(self.dut, (10, "ns")))

    # Send a read request & await the response
    async def read_csr(self, addr: int) -> int:
        self.AHBManager.read(addr, 4)
        # TODO: Make await dependent on clock cycles; throw error with timeouts
        await self.AHBManager.transfer_done()
        read = self.AHBManager.get_rsp(addr, 4)
        print(f"read0: {read}")
        self.AHBManager.write(addr, 4, [0xd, 0xe, 0xa, 0xd], [0xf, 0xf, 0xf, 0xf])
        await self.AHBManager.transfer_done()  # what a silly way
        self.AHBManager.read(addr, 4)
        await self.AHBManager.transfer_done()
        read = self.AHBManager.get_rsp(addr, 4)
        print(f"read1: {read}")
        return read

    # Send a write request & await transfer to finish
    async def write_csr(self, addr: int, data: int, strb: Array[bool] = [1, 1, 1, 1]) -> None:
        self.AHBManager.write(addr, len(strb), data, strb)
        # TODO: Make await dependent on clock cycles
        await self.AHBManager.transfer_done()


def compare_values(before: List[int], expected: List[int], after: List[int], addr: int):
    print(f"Before {before}")
    print(f"Expected {expected}")
    print(f"After {after}")
    assert all(
        [expected[i] == after[i] for i in range(len(expected))]
    ), f"Word at {addr:#x} differs. Expected: {printable(expected)} Got: {printable(after)}"


@cocotb.test()
async def run_read_hci_version_csr(dut: SimHandleBase):
    """Run test to read HCI version register."""

    tb = AHBFIFOTestInterface(dut)
    await tb.register_test_interfaces()

    addr = 0x0
    expected = [0x1, 0x2, 0x0]

    read_value = await tb.read_csr(addr)
    for cmd in tb.AHBManager.commands:
        print(cmd, '\n')
    compare_values(None, expected, read_value, addr)


@cocotb.test()
async def run_test(dut: SimHandleBase):
    """Run test for mixed random read / write CSR commands."""

    tb = AHBFIFOTestInterface(dut)
    await tb.register_test_interfaces()

    # Reference each CSR in the address space in a random order
    # and a random value for write.
    test_sequence = gen_rand_seq()

    for cmd in test_sequence:
        addr, val, strb = cmd.to_tuple()
        value_before_write = await tb.read_csr(addr)
        await tb.write_csr(addr, val, strb)
        value_after_write = await tb.read_csr(addr)
        compare_values(value_before_write, val, value_after_write, addr)

    # TODO: Compare the whole address space (in case adjacent bytes have been overwritten)
