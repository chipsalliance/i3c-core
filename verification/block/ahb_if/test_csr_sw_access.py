# SPDX-License-Identifier: Apache-2.0

from math import log2
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
            randrange(0, 0x4000, size),
            [randint(0, 255) for _ in range(size)],
            [bool(randint(0, 1)) for _ in range(size)],
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
    return int("".join(map(str, data)))


class AHBFIFOTestInterface:
    """
    This interface initializes appropriate cocotb AHB models and provides abstractions for
    common functionalities, such as read / write to CSR.
    """

    def __init__(self, dut: SimHandleBase, data_width=64):
        self.dut = dut
        self.data_width = data_width
        self.data_byte_width = data_width // 8

        # FIFO AHB Frontend
        self.AHBSubordinate = DUTSubordinate(dut, bus_width=data_width)

        # Simulated AHB in control of dispatching commands
        self.AHBManager = SimSimpleManager(bus_width=data_width)

        # Cocotb-ahb-specific construct for simulation purposes
        self.interconnect = SimInterconnect()

        # Cocotb-ahb-specific construct for simulation purposes
        self.wrapper = InterconnectWrapper()

    async def register_test_interfaces(self):
        # Clocks & resets
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

    async def read_csr(self, addr: int) -> List[int]:
        """Send a read request & await the response."""
        self.AHBManager.read(addr, self.data_byte_width)
        # TODO: Make await dependent on clock cycles; throw error with timeouts
        await self.AHBManager.transfer_done()
        read = self.AHBManager.get_rsp(addr, self.data_byte_width)
        return read

    async def write_csr(self, addr: int, data: List[int], size: int) -> None:
        """Send a write request & await transfer to finish."""
        # Write strobe is not supported by DUT's AHB-Lite; enable all bytes
        strb = [1 for _ in range(size)]
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


def int_to_ahb_data(value: int, byte_width=4) -> List[int]:
    assert (log2(value) <= byte_width * 8)
    return [(value >> (b * 8)) & 0xff for b in range(byte_width)]


@cocotb.test()
async def run_read_hci_version_csr(dut: SimHandleBase):
    """Run test to read HCI version register."""

    tb = AHBFIFOTestInterface(dut)
    await tb.register_test_interfaces()

    addr = 0x0
    expected = int_to_ahb_data(0x120, 4)

    read_value = await tb.read_csr(addr)
    compare_values(None, expected, read_value, addr)


@cocotb.test()
async def run_read_pio_section_offset(dut: SimHandleBase):
    """Run test to read PIO section offset register."""

    tb = AHBFIFOTestInterface(dut)
    await tb.register_test_interfaces()

    addr = 0x3c
    expected = int_to_ahb_data(0x100, 4)

    read_value = await tb.read_csr(addr)
    compare_values(None, expected, read_value, addr)


@cocotb.test()
async def run_write_to_controller_device_addr(dut: SimHandleBase):
    """Run test to write to Controller Device Address."""

    tb = AHBFIFOTestInterface(dut)
    await tb.register_test_interfaces()

    addr = 0x8
    new_dynamic_address = 0x42 << 16  # [22:16]
    new_dynamic_address_valid = 1 << 31  # [31:31]
    wdata = int_to_ahb_data(new_dynamic_address | new_dynamic_address_valid, 4)

    _ = await tb.write_csr(addr, wdata, 4)
    # Read the CSR to validate the data
    resp = await tb.read_csr(addr)
    compare_values(None, wdata, resp, addr)


# @cocotb.test()
# async def run_test(dut: SimHandleBase):
#     """Run test for mixed random read / write CSR commands."""

#     tb = AHBFIFOTestInterface(dut)
#     await tb.register_test_interfaces()

#     # Reference each CSR in the address space in a random order
#     # and a random value for write.
#     test_sequence = gen_rand_seq(size=tb.data_byte_width)

#     for cmd in test_sequence:
#         addr, val, strb = cmd.to_tuple()
#         value_before_write = await tb.read_csr(addr)
#         await tb.write_csr(addr, val)
#         value_after_write = await tb.read_csr(addr)
#         compare_values(value_before_write, val, value_after_write, addr)

#     # TODO: Compare the whole address space (in case adjacent bytes have been overwritten)
