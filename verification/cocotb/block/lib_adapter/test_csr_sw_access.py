# SPDX-License-Identifier: Apache-2.0

#######################################################################
# Tests common for bus <-> CSR adapter modules (includes AXI and AHB) #
#######################################################################


from bus2csr import (
    FrontBusTestInterface,
    compare_values,
    get_frontend_bus_if,
    int2bytes,
    int2dword,
)
from hci import (
    DAT_SECTION_OFFSET_RESET,
    DATA_BUFFER_THLD_CTRL_RESET,
    DCT_ADDR,
    DCT_SECTION_OFFSET_RESET,
    HC_CONTROL_RESET,
    INT_CTRL_CMDS_EN_RESET,
    PIO_ADDR,
    QUEUE_SIZE_RESET,
    QUEUE_THLD_CTRL_RESET,
    HCI_VERSION_v1_2_VALUE,
)
from utils import mask_bits, rand_bits, rand_bits32

import cocotb
from cocotb.handle import SimHandleBase


# Disable AXI ID filtering to let the CSR requests pass through
def disable_id_filtering(dut):
    if hasattr(dut, "disable_id_filtering_i"):
        dut.disable_id_filtering_i.value = 1
    if hasattr(dut, "priv_ids_i"):
        dut.priv_ids_i.value = [0] * len(dut.priv_ids_i)


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
async def test_read_hci_version_csr(dut: SimHandleBase):
    """Run test to read HCI version register."""
    disable_id_filtering(dut)
    tb = get_frontend_bus_if()(dut)
    await tb.register_test_interfaces()

    expected_hci_version_value = HCI_VERSION_v1_2_VALUE
    await read_csr_and_verify(
        tb, tb.reg_map.I3CBASE.HCI_VERSION.base_addr, expected_hci_version_value
    )


@cocotb.test()
async def test_read_pio_section_offset(dut: SimHandleBase):
    """Run test to read PIO section offset register."""
    disable_id_filtering(dut)
    tb = get_frontend_bus_if()(dut)
    await tb.register_test_interfaces()

    await read_csr_and_verify(tb, tb.reg_map.I3CBASE.PIO_SECTION_OFFSET.base_addr, PIO_ADDR)


@cocotb.test()
async def test_write_to_controller_device_addr(dut: SimHandleBase):
    """Run test to write & read from Controller Device Address."""
    disable_id_filtering(dut)
    tb = get_frontend_bus_if()(dut)
    await tb.register_test_interfaces()

    new_dynamic_address = rand_bits(7) << 16  # [22:16]
    new_dynamic_address_valid = 1 << 31  # [31:31]
    wdata = new_dynamic_address | new_dynamic_address_valid

    await write_csr_and_verify(tb, tb.reg_map.I3CBASE.CONTROLLER_DEVICE_ADDR.base_addr, wdata)


@cocotb.test()
async def test_write_should_not_affect_ro_csr(dut: SimHandleBase):
    """Run test to write to RO HC Capabilities."""
    disable_id_filtering(dut)
    tb = get_frontend_bus_if()(dut)
    await tb.register_test_interfaces()

    addr = tb.reg_map.I3CBASE.HC_CAPABILITIES.base_addr

    hc_cap = await tb.read_csr(addr)
    neg_hc_cap = list(map(lambda x: 0xFF - x, hc_cap))
    await tb.write_csr(addr, neg_hc_cap)
    resp = await tb.read_csr(addr)
    compare_values(hc_cap, resp, addr)


@cocotb.test()
async def test_sequence_csr_read(dut: SimHandleBase):
    disable_id_filtering(dut)
    tb = get_frontend_bus_if()(dut)
    await tb.register_test_interfaces()

    # TODO: Compare with generated register values from `reg_map.py`
    # name: (addr, reset_value)
    non_zero_csr_seq = {
        "HC_CONTROL": (tb.reg_map.I3CBASE.HC_CONTROL.base_addr, HC_CONTROL_RESET),
        "DAT_SECTION_OFFSET": (
            tb.reg_map.I3CBASE.DAT_SECTION_OFFSET.base_addr,
            DAT_SECTION_OFFSET_RESET,
        ),
        "DCT_SECTION_OFFSET": (
            tb.reg_map.I3CBASE.DCT_SECTION_OFFSET.base_addr,
            DCT_SECTION_OFFSET_RESET,
        ),
        "INT_CTRL_CMDS_EN": (tb.reg_map.I3CBASE.INT_CTRL_CMDS_EN.base_addr, INT_CTRL_CMDS_EN_RESET),
        "QUEUE_THLD_CTRL": (tb.reg_map.PIOCONTROL.QUEUE_THLD_CTRL.base_addr, QUEUE_THLD_CTRL_RESET),
        "DATA_BUFFER_THLD_CTRL": (
            tb.reg_map.PIOCONTROL.DATA_BUFFER_THLD_CTRL.base_addr,
            DATA_BUFFER_THLD_CTRL_RESET,
        ),
        "QUEUE_SIZE": (tb.reg_map.PIOCONTROL.QUEUE_SIZE.base_addr, QUEUE_SIZE_RESET),
    }

    for name in non_zero_csr_seq.keys():
        addr, value = non_zero_csr_seq[name]
        try:
            await read_csr_and_verify(tb, addr, value)
        except Exception as e:
            raise Exception(f"{name} register verification failed:\n{e}")


@cocotb.test()
async def test_sequence_csr_write(dut: SimHandleBase):
    disable_id_filtering(dut)
    tb = get_frontend_bus_if()(dut)
    await tb.register_test_interfaces()

    # TODO: Compare with generated register values from `reg_map.py`
    # name: (addr, value)
    rw_csr_seq = {
        "CONTROLLER_DEVICE_ADDR": (
            tb.reg_map.I3CBASE.CONTROLLER_DEVICE_ADDR.base_addr,
            rand_bits32() & ((mask_bits(1) << 31) | (mask_bits(7) << 16)),
        ),
        "RESET_CONTROL": (tb.reg_map.I3CBASE.RESET_CONTROL.base_addr, rand_bits32() & mask_bits(6)),
        "DCT_SECTION_OFFSET": (
            tb.reg_map.I3CBASE.DCT_SECTION_OFFSET.base_addr,
            (rand_bits32() & (mask_bits(5) << 19)) | (mask_bits(7) << 12) | DCT_ADDR,
        ),
        "QUEUE_THLD_CTRL": (tb.reg_map.PIOCONTROL.QUEUE_THLD_CTRL.base_addr, rand_bits32()),
        "PIO_INTR_STATUS_ENABLE": (
            tb.reg_map.PIOCONTROL.PIO_INTR_STATUS_ENABLE.base_addr,
            rand_bits32() & ((mask_bits(1) << 9) | mask_bits(6)),
        ),
        "PIO_INTR_SIGNAL_ENABLE": (
            tb.reg_map.PIOCONTROL.PIO_INTR_SIGNAL_ENABLE.base_addr,
            rand_bits32() & ((mask_bits(1) << 9) | mask_bits(6)),
        ),
        "PIO_CONTROL": (tb.reg_map.PIOCONTROL.PIO_CONTROL.base_addr, rand_bits32() & mask_bits(3)),
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
