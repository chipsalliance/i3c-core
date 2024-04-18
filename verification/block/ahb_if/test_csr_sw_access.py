# SPDX-License-Identifier: Apache-2.0

from functools import reduce
from math import log2
from typing import List, Tuple

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandle, SimHandleBase
from cocotb.triggers import ClockCycles, RisingEdge, Timer
from cocotb_AHB.AHB_common.InterconnectInterface import InterconnectWrapper
from cocotb_AHB.drivers.DutSubordinate import DUTSubordinate
from cocotb_AHB.drivers.SimSimpleManager import SimSimpleManager
from cocotb_AHB.interconnect.SimInterconnect import SimInterconnect


async def setup_dut(dut: SimHandle, clk_period: Tuple[int, str]) -> None:
    """
    Setup clock & reset the unit
    """
    await cocotb.start(Clock(dut.hclk, *clk_period).start())
    dut.hreset_n.value = 0
    await ClockCycles(dut.hclk, 10)
    await RisingEdge(dut.hclk)
    await Timer(1, units="ns")
    dut.hreset_n.value = 1
    await ClockCycles(dut.hclk, 1)


def int_to_ahb_data(value: int, byte_width=4) -> List[int]:
    assert (
        log2(value) <= byte_width * 8
    ), f"Requested int: {value:#x} exceeds {byte_width:#x} bytes."
    return [(value >> (b * 8)) & 0xFF for b in range(byte_width)]


def ahb_data_to_int(data: List[int], byte_width=4) -> int:
    return reduce(lambda acc, bi: acc + (bi[0] << (bi[1] * 8)), zip(data, range(byte_width)), 0)


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
        self.AHBManager.register_clock(self.dut.hclk).register_reset(self.dut.hreset_n, True)
        self.interconnect.register_clock(self.dut.hclk).register_reset(self.dut.hreset_n, True)
        self.wrapper.register_clock(self.dut.hclk).register_reset(self.dut.hreset_n, True)
        # Interconnect setup
        self.interconnect.register_subordinate(self.AHBSubordinate)
        self.interconnect.register_manager(self.AHBManager)
        # Handled address space
        self.interconnect.register_manager_subordinate_addr(
            self.AHBManager, self.AHBSubordinate, 0x0, 0x4000
        )
        self.wrapper.register_interconnect(self.interconnect)

        await cocotb.start(self.AHBManager.start())
        await cocotb.start(self.wrapper.start())
        await cocotb.start(setup_dut(self.dut, (10, "ns")))

    async def read_csr(self, addr: int, size: int = 4) -> List[int]:
        """Send a read request & await the response."""
        self.AHBManager.read(addr, size)
        # TODO: Make await dependent on clock cycles; throw error with timeouts
        await self.AHBManager.transfer_done()
        read = self.AHBManager.get_rsp(addr, self.data_byte_width)
        return read

    async def write_csr(self, addr: int, data: List[int], size: int = 4) -> None:
        """Send a write request & await transfer to finish."""
        # Write strobe is not supported by DUT's AHB-Lite; enable all bytes
        strb = [1 for _ in range(size)]
        self.AHBManager.write(addr, len(strb), data, strb)
        # TODO: Make await dependent on clock cycles
        await self.AHBManager.transfer_done()


def compare_values(expected: List[int], actual: List[int], addr: int):
    assert all([expected[i] == actual[i] for i in range(len(expected))]), (
        f"Word at {addr:#x} differs. "
        f"Expected: {ahb_data_to_int(expected):#x} "
        f"Got: {ahb_data_to_int(actual):#x} "
    )


@cocotb.test()
async def run_read_hci_version_csr(dut: SimHandleBase):
    """Run test to read HCI version register."""

    tb = AHBFIFOTestInterface(dut)
    await tb.register_test_interfaces()

    addr = 0x0
    expected = int_to_ahb_data(0x120, 4)

    read_value = await tb.read_csr(addr)
    compare_values(expected, read_value, addr)


@cocotb.test()
async def run_read_pio_section_offset(dut: SimHandleBase):
    """Run test to read PIO section offset register."""

    tb = AHBFIFOTestInterface(dut)
    await tb.register_test_interfaces()

    addr = 0x3C
    expected = int_to_ahb_data(0x100, 4)

    read_value = await tb.read_csr(addr)
    compare_values(expected, read_value, addr)


@cocotb.test()
async def run_write_to_controller_device_addr(dut: SimHandleBase):
    """Run test to write & read from Controller Device Address."""

    tb = AHBFIFOTestInterface(dut)
    await tb.register_test_interfaces()

    addr = 0x8
    new_dynamic_address = 0x42 << 16  # [22:16]
    new_dynamic_address_valid = 1 << 31  # [31:31]
    wdata = int_to_ahb_data(new_dynamic_address | new_dynamic_address_valid, 4)

    await tb.write_csr(addr, wdata, 4)
    # Read the CSR to validate the data
    resp = await tb.read_csr(addr)
    compare_values(wdata, resp, addr)


@cocotb.test()
async def run_write_should_not_affect_ro_csr(dut: SimHandleBase):
    """Run test to write to RO HC Capabilities."""

    tb = AHBFIFOTestInterface(dut)
    await tb.register_test_interfaces()

    addr = 0xC

    hc_cap = await tb.read_csr(addr)
    neg_hc_cap = list(map(lambda x: 0xFF - x, hc_cap))
    await tb.write_csr(addr, neg_hc_cap)
    resp = await tb.read_csr(addr)
    compare_values(hc_cap, resp, addr)


# TODO: Generated tests based on the CSR C Header (loaded with i.e. cppyy)
