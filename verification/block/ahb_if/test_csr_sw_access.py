# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.handle import SimHandleBase
from hci import PIO_ADDR

from ahb_if import AHBFIFOTestInterface, compare_values, int_to_ahb_data


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
    expected = int_to_ahb_data(PIO_ADDR, 4)

    read_value = await tb.read_csr(addr)
    compare_values(expected, read_value, addr)


@cocotb.test()
async def run_write_to_controller_device_addr(dut: SimHandleBase):
    """Run test to write & read from Controller Device Address."""

    tb = AHBFIFOTestInterface(dut)
    await tb.register_test_interfaces()

    # TODO: Remove hard-coded values
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

    # TODO: Remove hard-coded values
    addr = 0xC

    hc_cap = await tb.read_csr(addr)
    neg_hc_cap = list(map(lambda x: 0xFF - x, hc_cap))
    await tb.write_csr(addr, neg_hc_cap)
    resp = await tb.read_csr(addr)
    compare_values(hc_cap, resp, addr)


# TODO: Generated tests based on the CSR C Header (loaded with i.e. cppyy)
