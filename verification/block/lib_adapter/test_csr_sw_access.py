# SPDX-License-Identifier: Apache-2.0

#######################################################################
# Tests common for bus <-> CSR adapter modules (includes AXI and AHB) #
#######################################################################


import cocotb
from bus2csr import (
    FrontBusTestInterface,
    compare_values,
    get_frontend_bus_if,
    int2bytes,
    int2dword,
)
from cocotb.handle import SimHandleBase
from hci import (
    CONTROLLER_DEVICE_ADDR,
    DAT_SECTION_OFFSET,
    DAT_SECTION_OFFSET_RESET,
    DATA_BUFFER_THLD_CTRL,
    DATA_BUFFER_THLD_CTRL_RESET,
    DCT_ADDR,
    DCT_SECTION_OFFSET,
    DCT_SECTION_OFFSET_RESET,
    HC_CAPABILITIES,
    HC_CONTROL,
    HC_CONTROL_RESET,
    HCI_VERSION,
    INT_CTRL_CMDS_EN,
    INT_CTRL_CMDS_EN_RESET,
    PIO_ADDR,
    PIO_CONTROL,
    PIO_INTR_SIGNAL_ENABLE,
    PIO_INTR_STATUS_ENABLE,
    PIO_SECTION_OFFSET,
    QUEUE_SIZE,
    QUEUE_SIZE_RESET,
    QUEUE_THLD_CTRL,
    QUEUE_THLD_CTRL_RESET,
    RESET_CONTROL,
    HCI_VERSION_v1_2_VALUE,
)
from utils import mask_bits, rand_bits, rand_bits32


async def read_csr_and_verify(
    testIf: FrontBusTestInterface,
    addr: int,
    expected_value: int,
    size: int = 4,
    timeout: int = 1,
    units: str = "us",
):
    """
    Perform a read to the CSR at `addr` and validate it against `expected_value`.
    """
    expected = int2bytes(expected_value, size)
    read_value = await testIf.read_csr(addr, size=size, timeout=timeout, units=units)
    compare_values(expected, read_value, addr)


async def write_csr_and_verify(
    testIf: FrontBusTestInterface,
    addr: int,
    value: int,
    size: int = 4,
    timeout: int = 1,
    units: str = "us",
):
    """
    Perform a write to the CSR at `addr` and validate it by a read of the same CSR
    and compare the written vs received value.
    """
    wdata = int2bytes(value, size)
    await testIf.write_csr(addr, wdata, size, timeout=timeout, units=units)
    await read_csr_and_verify(testIf, addr, value, size=size, timeout=timeout, units=units)


# Common test cases for frontend adapters:
@cocotb.test()
async def run_read_hci_version_csr(dut: SimHandleBase):
    """Run test to read HCI version register."""

    tb = get_frontend_bus_if()(dut)
    await tb.register_test_interfaces()

    expected_hci_version_value = HCI_VERSION_v1_2_VALUE
    await read_csr_and_verify(tb, HCI_VERSION, expected_hci_version_value)


@cocotb.test()
async def run_read_pio_section_offset(dut: SimHandleBase):
    """Run test to read PIO section offset register."""

    tb = get_frontend_bus_if()(dut)
    await tb.register_test_interfaces()

    await read_csr_and_verify(tb, PIO_SECTION_OFFSET, PIO_ADDR)


@cocotb.test()
async def run_write_to_controller_device_addr(dut: SimHandleBase):
    """Run test to write & read from Controller Device Address."""

    tb = get_frontend_bus_if()(dut)
    await tb.register_test_interfaces()

    new_dynamic_address = rand_bits(7) << 16  # [22:16]
    new_dynamic_address_valid = 1 << 31  # [31:31]
    wdata = new_dynamic_address | new_dynamic_address_valid

    await write_csr_and_verify(tb, CONTROLLER_DEVICE_ADDR, wdata)


@cocotb.test()
async def run_write_should_not_affect_ro_csr(dut: SimHandleBase):
    """Run test to write to RO HC Capabilities."""

    tb = get_frontend_bus_if()(dut)
    await tb.register_test_interfaces()

    addr = HC_CAPABILITIES

    hc_cap = await tb.read_csr(addr)
    neg_hc_cap = list(map(lambda x: 0xFF - x, hc_cap))
    await tb.write_csr(addr, neg_hc_cap)
    resp = await tb.read_csr(addr)
    compare_values(hc_cap, resp, addr)


@cocotb.test()
async def run_sequence_csr_read(dut: SimHandleBase):
    tb = get_frontend_bus_if()(dut)
    await tb.register_test_interfaces()

    # name: (addr, reset_value)
    non_zero_csr_seq = {
        "HC_CONTROL": (HC_CONTROL, HC_CONTROL_RESET),
        "DAT_SECTION_OFFSET": (DAT_SECTION_OFFSET, DAT_SECTION_OFFSET_RESET),
        "DCT_SECTION_OFFSET": (DCT_SECTION_OFFSET, DCT_SECTION_OFFSET_RESET),
        "INT_CTRL_CMDS_EN": (INT_CTRL_CMDS_EN, INT_CTRL_CMDS_EN_RESET),
        "QUEUE_THLD_CTRL": (QUEUE_THLD_CTRL, QUEUE_THLD_CTRL_RESET),
        "DATA_BUFFER_THLD_CTRL": (DATA_BUFFER_THLD_CTRL, DATA_BUFFER_THLD_CTRL_RESET),
        "QUEUE_SIZE": (QUEUE_SIZE, QUEUE_SIZE_RESET),
    }

    for name in non_zero_csr_seq.keys():
        addr, value = non_zero_csr_seq[name]
        try:
            await read_csr_and_verify(tb, addr, value)
        except Exception as e:
            raise Exception(f"{name} register verification failed:\n{e}")


@cocotb.test()
async def run_sequence_csr_write(dut: SimHandleBase):
    tb = get_frontend_bus_if()(dut)
    await tb.register_test_interfaces()

    # name: (addr, value)
    rw_csr_seq = {
        "CONTROLLER_DEVICE_ADDR": (
            CONTROLLER_DEVICE_ADDR,
            rand_bits32() & ((mask_bits(1) << 31) | (mask_bits(7) << 16)),
        ),
        "RESET_CONTROL": (RESET_CONTROL, rand_bits32() & mask_bits(6)),
        "DCT_SECTION_OFFSET": (
            DCT_SECTION_OFFSET,
            (rand_bits32() & (mask_bits(5) << 19)) | (mask_bits(7) << 12) | DCT_ADDR,
        ),
        "QUEUE_THLD_CTRL": (QUEUE_THLD_CTRL, rand_bits32()),
        "PIO_INTR_STATUS_ENABLE": (
            PIO_INTR_STATUS_ENABLE,
            rand_bits32() & ((mask_bits(1) << 9) | mask_bits(6)),
        ),
        "PIO_INTR_SIGNAL_ENABLE": (
            PIO_INTR_SIGNAL_ENABLE,
            rand_bits32() & ((mask_bits(1) << 9) | mask_bits(6)),
        ),
        "PIO_CONTROL": (PIO_CONTROL, rand_bits32() & mask_bits(3)),
    }

    # Write the new values to the RW registers
    for name in rw_csr_seq.keys():
        addr, value = rw_csr_seq[name]
        await tb.write_csr(addr, int2dword(value), 4)

    # Verify the new values have been stored correctly
    for name in rw_csr_seq.keys():
        addr, value = rw_csr_seq[name]
        try:
            await read_csr_and_verify(tb, addr, value)
        except Exception as e:
            raise Exception(f"{name} register verification failed:\n{e}")
