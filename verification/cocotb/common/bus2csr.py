# SPDX-License-Identifier: Apache-2.0

from enum import IntEnum
from functools import reduce
from importlib import import_module
from math import log2
from random import choice, randint
from typing import List, Tuple

# AHB
from cocotb_AHB.AHB_common.InterconnectInterface import InterconnectWrapper
from cocotb_AHB.drivers.DutSubordinate import DUTSubordinate
from cocotb_AHB.drivers.SimSimpleManager import SimSimpleManager
from cocotb_AHB.interconnect.SimInterconnect import SimInterconnect

# AXI
from cocotbext.axi import AxiBus, AxiMaster, AxiResp
from reg_map import reg_map

# Cocotb
import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, RisingEdge, Timer, with_timeout


# Helpers
async def setup_dut(clk, rst_n, clk_period: Tuple[int, str]) -> None:
    """
    Setup clock & reset the unit
    """
    await cocotb.start(Clock(clk, *clk_period).start())
    rst_n.value = 0
    await ClockCycles(clk, 10)
    await RisingEdge(clk)
    await Timer(1, units="ns")
    rst_n.value = 1
    await ClockCycles(clk, 1)


def int2bytes(value: int, byte_width=4) -> List[int]:
    assert value == 0 or (
        log2(value) <= byte_width * 8
    ), f"Requested int: {value:#x} exceeds {byte_width:#x} bytes."
    return [(value >> (b * 8)) & 0xFF for b in range(byte_width)]


def bytes2int(data: List[int], byte_width=4) -> int:
    return reduce(lambda acc, bi: acc + (bi[0] << (bi[1] * 8)), zip(data, range(byte_width)), 0)


def int2dword(value: int) -> List[int]:
    return int2bytes(value, 4)


def dword2int(data: List[int]) -> int:
    return bytes2int(data, 4)


def compare_values(expected: List[int], actual: List[int], addr: int):
    assert all([expected[i] == actual[i] for i in range(len(expected))]), (
        f"Word at {addr:#x} differs. "
        f"Expected: {bytes2int(expected):#x} "
        f"Got: {bytes2int(actual):#x} "
    )


# Generic bus2csr test interface
class FrontBusTestInterface:
    def __init__(self, dut: SimHandleBase, clk, rst_n, data_width) -> None:
        self.data_width = data_width
        self.data_byte_width = data_width // 8
        self.dut = dut
        self.clk = clk
        self.rst_n = rst_n
        self.reg_map = reg_map

    async def register_test_interfaces(self, fclk=500.0):
        tclk = int(1e6 / fclk + 0.5)
        await cocotb.start(setup_dut(self.clk, self.rst_n, (tclk, "ps")))

    async def read_csr(
        self, addr: int, size: int = 4, timeout: int = 1, units: str = "us"
    ) -> List[int]:
        """Send a read request & await the response."""
        raise NotImplementedError

    async def write_csr(
        self, addr: int, data: List[int], size: int = 4, timeout: int = 1, units: str = "us"
    ) -> None:
        """Send a write request & await transfer to finish."""
        raise NotImplementedError

    async def write_csr_field(self, reg_addr, field, data) -> None:
        """Read -> modify -> write CSR"""
        value = bytes2int(await self.read_csr(reg_addr))
        value = value & ~field.mask
        value = value | (data << field.low)
        await self.write_csr(reg_addr, int2bytes(value))

    async def read_csr_field(self, reg_addr, field) -> int:
        """Read -> modify -> write CSR"""
        value = bytes2int(await self.read_csr(reg_addr))
        value = value & field.mask
        value = value >> field.low
        return value


# Generic ahb2csr test interface
class AHBTestInterface(FrontBusTestInterface):
    """
    This interface initializes appropriate cocotb AHB models and provides abstractions for
    common functionalities, such as read / write to CSR.
    """

    def __init__(self, dut: SimHandleBase, data_width=64):
        super().__init__(dut, dut.hclk, dut.hreset_n, data_width)
        # FIFO AHB Frontend
        self.AHBSubordinate = DUTSubordinate(dut, bus_width=data_width)

        # Simulated AHB in control of dispatching commands
        self.AHBManager = SimSimpleManager(bus_width=data_width)

        # Cocotb-ahb-specific construct for simulation purposes
        self.interconnect = SimInterconnect()

        # Cocotb-ahb-specific construct for simulation purposes
        self.wrapper = InterconnectWrapper()

    async def register_test_interfaces(self, *args, **kw):
        # Clocks & resets
        self.AHBManager.register_clock(self.clk).register_reset(self.rst_n, True)
        self.interconnect.register_clock(self.clk).register_reset(self.rst_n, True)
        self.wrapper.register_clock(self.clk).register_reset(self.rst_n, True)

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

        await super().register_test_interfaces(*args, **kw)

    async def read_csr(
        self, addr: int, size: int = 4, timeout: int = 1, units: str = "us"
    ) -> List[int]:
        """Send a read request & await the response for 'timeout' in 'units'."""
        self.AHBManager.read(addr, size)
        await with_timeout(self.AHBManager.transfer_done(), timeout, units)
        read = self.AHBManager.get_rsp(addr, self.data_byte_width)
        return read

    async def write_csr(
        self, addr: int, data: List[int], size: int = 4, timeout: int = 1, units: str = "us"
    ) -> None:
        """Send a write request & await transfer to finish for 'timeout' in 'units'."""
        data_len = len(data)
        # Extend bytes to size if there's less than that
        if data_len <= size:
            data = data + [0 for _ in range(size - data_len)]
        # Write strobe is not supported by DUT's AHB-Lite; enable all bytes
        strb = [1 for _ in range(size)]
        self.AHBManager.write(addr, len(strb), data, strb)
        await with_timeout(self.AHBManager.transfer_done(), timeout, units)


# Generic axi2csr test interface
class AXITestInterface(FrontBusTestInterface):
    """
    This interface initializes appropriate cocotb AXI models and provides abstractions for
    common functionalities, such as read / write to CSR.
    """

    def __init__(self, dut: SimHandleBase, data_width=32):
        super().__init__(dut, dut.aclk, dut.areset_n, data_width)

        # Initialize AXI bus
        axi_bus = AxiBus.from_entity(self.dut)
        self.axi_m = AxiMaster(axi_bus, self.clk, self.rst_n, reset_active_level=False)

    async def register_test_interfaces(self, *args, **kw):
        await super().register_test_interfaces(*args, **kw)
        # TODO: Investigate if there's a neater solution
        # wait before issuing any transactions:
        # workaround for cocotbext-axi issuing transactions during reset
        await ClockCycles(self.clk, 10)

    async def read_csr(
        self,
        addr: int,
        size: int = 4,
        arid: int = None,
        timeout: int = 1,
        units: str = "us",
        ret_data_only=True,
    ) -> List[int]:
        """Send a read request & await the response."""
        resp = await with_timeout(self.axi_m.read(addr, size, arid=arid), timeout, units)
        if ret_data_only:
            return resp.data
        return resp

    async def write_csr(
        self,
        addr: int,
        data: List[int],
        size: int = 4,
        awid: int = None,
        timeout: int = 1,
        units: str = "us",
    ) -> None:
        """Send a write request & await transfer to finish."""
        # assert not bytes(data)
        return await with_timeout(self.axi_m.write(addr, bytes(data), awid=awid), timeout, units)

    def _report_response(self, got, expected, is_read=False):
        op = "read" if is_read else "write"
        name = ["OKAY", "EXOKAY", "SLVERR", "DECERR"]
        return (
            f"{hex(expected)} != {hex(got)}."
            f" Anticipated {op} response: {name[expected]} got: {name[got]}."
        )

    async def read_access_monitor(self):
        """
        Ensures the AXI read response is set appropriately to
        current filtering configuration and transaction ID.
        """
        await RisingEdge(self.dut.areset_n)

        while True:
            while not (self.dut.arvalid.value and self.dut.arready.value):
                await RisingEdge(self.dut.aclk)
            priv_ids = self.dut.priv_ids_i.value
            filter_off = self.dut.disable_id_filtering_i.value

            while not (self.dut.rvalid.value and self.dut.rready.value):
                await RisingEdge(self.dut.aclk)
            rid = self.dut.rid.value
            rresp = self.dut.rresp.value
            if filter_off or rid in priv_ids:
                assert rresp == AxiResp.OKAY, self._report_response(rresp, AxiResp.OKAY, True)
            else:
                assert rresp == AxiResp.SLVERR, self._report_response(rresp, AxiResp.SLVERR, True)
                assert self.dut.rdata.value == 0

            await RisingEdge(self.dut.aclk)

    async def write_access_monitor(self):
        """
        Ensures the AXI write response is set appropriately to
        current filtering configuration and transaction ID.
        """
        await RisingEdge(self.dut.areset_n)

        while True:
            while not (self.dut.awvalid.value and self.dut.awready.value):
                await RisingEdge(self.dut.aclk)
            priv_ids = self.dut.priv_ids_i.value
            filter_off = self.dut.disable_id_filtering_i.value

            while not (self.dut.bvalid.value and self.dut.bready.value):
                await RisingEdge(self.dut.aclk)
            bid = self.dut.bid.value
            bresp = self.dut.bresp.value

            if filter_off or bid in priv_ids:
                assert bresp == AxiResp.OKAY, self._report_response(bresp, AxiResp.OKAY)
            else:
                assert bresp == AxiResp.SLVERR, self._report_response(bresp, AxiResp.SLVERR)

            await RisingEdge(self.dut.aclk)


def get_frontend_bus_if():
    """
    This function returns one of the defined `FrontBusTestInterface`.
    """
    frontend_bus_name = cocotb.plusargs["FrontendBusInterface"]
    assert frontend_bus_name in ["AXI", "AHB"]
    cls_name = frontend_bus_name + "TestInterface"
    try:
        cls = getattr(import_module("bus2csr"), cls_name)
    except ModuleNotFoundError:
        raise ModuleNotFoundError(
            f"Frontend bus '{frontend_bus_name}' is supported but its interface '{cls_name}' can not be found"
        ) from None

    return cls
