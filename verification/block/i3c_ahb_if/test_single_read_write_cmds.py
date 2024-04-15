# SPDX-License-Identifier: Apache-2.0

from ctypes import Array
from typing import List, Tuple
from asyncio import wait_for, TimeoutError

import cocotb  # type: ignore
from cocotb.handle import SimHandle, SimHandleBase  # type: ignore
from cocotb.triggers import ClockCycles, RisingEdge, Timer  # type: ignore
from cocotb_AHB.AHB_common.InterconnectInterface import InterconnectWrapper  # type: ignore
from cocotb.clock import Clock  # type: ignore
from cocotb_AHB.drivers.DutSubordinate import DUTSubordinate  # type: ignore
from cocotb_AHB.drivers.SimSimpleManager import SimSimpleManager  # type: ignore
from cocotb_AHB.interconnect.SimInterconnect import SimInterconnect  # type: ignore
from random import randrange, randint


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


# class AHBFIFOTestInterface:
#     """
#     This interface initializes appropriate cocotb AHB models and provides abstractions for
#     common functionalities, such as read / write to CSR.
#     """

#     def __init__(self, dut: SimHandleBase):
#         self.dut = dut

#         # FIFO AHB Frontend
#         self.AHBSubordinate = DUTSubordinate(dut, bus_width=32)

#         # Simulated AHB in control of dispatching commands
#         self.AHBManager = SimSimpleManager(bus_width=32)

#         # Cocotb-ahb-specific construct for simulation purposes
#         self.interconnect = SimInterconnect()

#         # Cocotb-ahb-specific construct for simulation purposes
#         self.wrapper = InterconnectWrapper()

#     async def register_test_interfaces(self):
#         # Clocks & resets
#         # self.AHBSubordinate.register_clock(self.dut.hclk_i).register_reset(self.dut.hreset_n_i, True)
#         self.AHBManager.register_clock(self.dut.hclk_i).register_reset(self.dut.hreset_n_i, True)
#         self.interconnect.register_clock(self.dut.hclk_i).register_reset(self.dut.hreset_n_i, True)
#         self.wrapper.register_clock(self.dut.hclk_i).register_reset(self.dut.hreset_n_i, True)
#         # Interconnect setup
#         self.interconnect.register_subordinate(self.AHBSubordinate)
#         self.interconnect.register_manager(self.AHBManager)
#         # Handled address space
#         self.interconnect.register_manager_subordinate_addr(self.AHBManager, self.AHBSubordinate, 0x0, 0x4000)
#         self.wrapper.register_interconnect(self.interconnect)


# Send a read request & await the response
async def read_csr(manager, addr: int) -> int:
    manager.read(addr, 4)
    # TODO: Make await dependent on clock cycles
    try:
        await wait_for(manager.transfer_done(), timeout=5)
    except Exception:
        raise TimeoutError(f"read_csr @ {hex(addr)} unsuccessfull: Operation timeout exceeded.")
    return manager.get_rsp(addr, 4)


# Send a write request & await transfer to finish
async def write_csr(manager, addr: int, data: int, strb: Array[bool]) -> None:
    manager.write(addr, len(strb), data, strb)
    # TODO: Make await dependent on clock cycles
    try:
        await wait_for(manager.transfer_done(), timeout=5)
    except Exception:
        raise TimeoutError(f"write_csr {hex(data)} @ {hex(addr)} unsuccessfull: Operation timeout exceeded.")


def compare_values(before: List[int], expected: List[int], after: List[int], addr: int):
    assert all([expected[i] == after[i] for i in range(len(expected))]
               ), f"Word at {addr:#x} differs. Expected: {printable(expected)} Got: {printable(after)}"


@cocotb.test()
async def run_test(dut: SimHandleBase):
    """Run test for mixed read / write CSR commands."""

    # tb = AHBFIFOTestInterface(dut)
    # await tb.register_test_interfaces()

    # FIFO AHB Frontend
    AHBSubordinate = DUTSubordinate(dut, bus_width=32)

    # Simulated AHB in control of dispatching commands
    AHBManager = SimSimpleManager(bus_width=32)
    AHBManager.register_clock(dut.hclk_i).register_reset(dut.hreset_n_i, True)

    # Cocotb-ahb-specific construct for simulation purposes
    interconnect = SimInterconnect().register_subordinate(AHBSubordinate)
    interconnect.register_clock(dut.hclk_i).register_reset(dut.hreset_n_i, True)
    interconnect.register_manager(AHBManager)
    interconnect.register_manager_subordinate_addr(AHBManager, AHBSubordinate, 0x0, 0x4000)

    # Cocotb-ahb-specific construct for simulation purposes
    wrapper = InterconnectWrapper()
    wrapper.register_clock(dut.hclk_i).register_reset(dut.hreset_n_i, True)
    wrapper.register_interconnect(interconnect)

    await cocotb.start(AHBManager.start())
    await cocotb.start(wrapper.start())
    await cocotb.start(setup_dut(dut, (10, 'ns')))
    # Reference each CSR in the address space in a random order
    # and a random value for write.
    # test_sequence = gen_rand_seq()

    await ClockCycles(dut.hclk_i, 10000)._wait()

    # for cmd in test_sequence:
    #     addr, val, strb = cmd.to_tuple()

    #     value_before_write = await read_csr(AHBManager, addr)
    #     await write_csr(AHBManager, addr, val, strb)
    #     value_after_write = await read_csr(AHBManager, addr)

    #     compare_values(value_before_write, val, value_after_write)

    # TODO: Compare the whole address space (in case adjacent bytes have been overwritten)
