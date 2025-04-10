# SPDX-License-Identifier: Apache-2.0
from axi_utils import AxiIdWidth, initialize_dut
from bus2csr import compare_values, int2bytes, int2dword
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
from utils import (
    Access,
    draw_axi_priv_ids,
    get_axi_ids_seq,
    mask_bits,
    rand_bits,
    rand_bits32,
)

import cocotb


async def read_hci_version_csr(dut, disable_id_filtering=False, priv_ids=None, tid=0):
    """Run test to read HCI version register."""
    tb = await initialize_dut(dut, disable_id_filtering, priv_ids)

    addr = tb.reg_map.I3CBASE.HCI_VERSION.base_addr
    expected_hci_version_value = int2bytes(HCI_VERSION_v1_2_VALUE)
    resp = await tb.read_csr(addr, arid=tid)

    if tid not in priv_ids and not disable_id_filtering:
        expected_hci_version_value = int2bytes(0)

    compare_values(expected_hci_version_value, resp, addr)


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_read_hci_version_csr_id_filter_off(dut):
    await read_hci_version_csr(dut, True, draw_axi_priv_ids(), rand_bits(AxiIdWidth))


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_read_hci_version_csr_id_filter_on_priv(dut):
    priv_ids = draw_axi_priv_ids()
    await read_hci_version_csr(dut, False, priv_ids, get_axi_ids_seq(priv_ids, 1, Access.Priv)[0])


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_read_hci_version_csr_id_filter_on_non_priv(dut):
    priv_ids = draw_axi_priv_ids()
    await read_hci_version_csr(dut, False, priv_ids, get_axi_ids_seq(priv_ids, 1, Access.Unpriv)[0])


async def read_pio_section_offset(dut, disable_id_filtering=False, priv_ids=None, tid=0):
    """Run test to read PIO section offset register."""

    tb = await initialize_dut(dut, disable_id_filtering, priv_ids)

    addr = tb.reg_map.I3CBASE.PIO_SECTION_OFFSET.base_addr
    expected = int2bytes(PIO_ADDR)
    resp = await tb.read_csr(addr, arid=tid)

    if tid not in priv_ids and not disable_id_filtering:
        expected = int2bytes(0)

    compare_values(expected, resp, addr)


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_read_pio_section_offset_filter_off(dut):
    await read_pio_section_offset(dut, True, draw_axi_priv_ids(), rand_bits(AxiIdWidth))


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_read_pio_section_offset_filter_on_priv(dut):
    priv_ids = draw_axi_priv_ids()
    tid = get_axi_ids_seq(priv_ids, 1, Access.Priv)[0]
    await read_pio_section_offset(dut, False, priv_ids, tid)


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_read_pio_section_offset_filter_on_non_priv(dut):
    priv_ids = draw_axi_priv_ids()
    tid = get_axi_ids_seq(priv_ids, 1, Access.Unpriv)[0]
    await read_pio_section_offset(dut, False, priv_ids, tid)


async def write_to_controller_device_addr(dut, disable_id_filtering=False, priv_ids=None, tid=0):
    """Run test to write & read from Controller Device Address."""

    tb = await initialize_dut(dut, disable_id_filtering, priv_ids)

    addr = tb.reg_map.I3CBASE.CONTROLLER_DEVICE_ADDR.base_addr
    new_dynamic_address = rand_bits(7) << 16  # [22:16]
    new_dynamic_address_valid = 1 << 31  # [31:31]
    wdata = int2bytes(new_dynamic_address | new_dynamic_address_valid)

    await tb.write_csr(addr, wdata, awid=tid)
    resp = await tb.read_csr(addr, arid=tid)

    if tid not in priv_ids and not disable_id_filtering:
        wdata = int2bytes(0)

    compare_values(wdata, resp, addr)


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_write_to_controller_device_addr_filter_off(dut):
    await write_to_controller_device_addr(dut, True, draw_axi_priv_ids(), rand_bits(AxiIdWidth))


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_write_to_controller_device_addr_filter_on_priv(dut):
    priv_ids = draw_axi_priv_ids()
    tid = get_axi_ids_seq(priv_ids, 1, Access.Priv)[0]
    await write_to_controller_device_addr(dut, False, priv_ids, tid)


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_write_to_controller_device_addr_filter_on_non_priv(dut):
    priv_ids = draw_axi_priv_ids()
    tid = get_axi_ids_seq(priv_ids, 1, Access.Unpriv)[0]
    await write_to_controller_device_addr(dut, False, priv_ids, tid)


async def write_should_not_affect_ro_csr(dut, disable_id_filtering=False, priv_ids=None, tid=0):
    """Run test to write to RO HC Capabilities."""

    tb = await initialize_dut(dut, disable_id_filtering, priv_ids)

    addr = tb.reg_map.I3CBASE.HC_CAPABILITIES.base_addr

    hc_cap = await tb.read_csr(addr, arid=priv_ids[0])
    neg_hc_cap = list(map(lambda x: 0xFF - x, hc_cap))
    await tb.write_csr(addr, neg_hc_cap, awid=tid)
    resp = await tb.read_csr(addr, arid=tid)

    if tid not in priv_ids and not disable_id_filtering:
        hc_cap = int2bytes(0)

    compare_values(hc_cap, resp, addr)


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_write_should_not_affect_ro_csr_filter_off(dut):
    await write_should_not_affect_ro_csr(dut, True, draw_axi_priv_ids(), rand_bits(AxiIdWidth))


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_write_should_not_affect_ro_csr_filter_on_priv(dut):
    priv_ids = draw_axi_priv_ids()
    tid = get_axi_ids_seq(priv_ids, 1, Access.Priv)[0]
    await write_should_not_affect_ro_csr(dut, False, priv_ids, tid)


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_write_should_not_affect_ro_csr_filter_on_non_priv(dut):
    priv_ids = draw_axi_priv_ids()
    tid = get_axi_ids_seq(priv_ids, 1, Access.Unpriv)[0]
    await write_should_not_affect_ro_csr(dut, False, priv_ids, tid)


async def sequence_csr_read(dut, disable_id_filtering=False, priv_ids=None, tid=0):
    tb = await initialize_dut(dut, disable_id_filtering, priv_ids)

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
        resp = await tb.read_csr(addr, arid=tid)

        if tid not in priv_ids and not disable_id_filtering:
            value = 0

        compare_values(int2bytes(value), resp, addr)


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_sequence_csr_read_filter_off(dut):
    await sequence_csr_read(dut, True, draw_axi_priv_ids(), rand_bits(AxiIdWidth))


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_sequence_csr_read_filter_on_priv(dut):
    priv_ids = draw_axi_priv_ids()
    tid = get_axi_ids_seq(priv_ids, 1, Access.Priv)[0]
    await sequence_csr_read(dut, False, priv_ids, tid)


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_sequence_csr_read_filter_on_non_priv(dut):
    priv_ids = draw_axi_priv_ids()
    tid = get_axi_ids_seq(priv_ids, 1, Access.Unpriv)[0]
    await sequence_csr_read(dut, False, priv_ids, tid)


async def sequence_csr_write(dut, disable_id_filtering=False, priv_ids=None, tid=0):
    tb = await initialize_dut(dut, disable_id_filtering, priv_ids)

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
        await tb.write_csr(addr, int2dword(value), 4, awid=tid)

    # Verify the new values have been stored correctly
    for name in rw_csr_seq.keys():
        addr, value = rw_csr_seq[name]
        resp = await tb.read_csr(addr, arid=tid)

        if tid not in priv_ids and not disable_id_filtering:
            value = 0

        compare_values(int2bytes(value), resp, addr)


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_sequence_csr_write_filter_off(dut):
    await sequence_csr_write(dut, True, draw_axi_priv_ids(), rand_bits(AxiIdWidth))


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_sequence_csr_write_filter_on_priv(dut):
    priv_ids = draw_axi_priv_ids()
    tid = get_axi_ids_seq(priv_ids, 1, Access.Priv)[0]
    await sequence_csr_write(dut, False, priv_ids, tid)


@cocotb.test(skip=("ControllerSupport" not in cocotb.plusargs))
async def test_sequence_csr_write_filter_on_non_priv(dut):
    priv_ids = draw_axi_priv_ids()
    tid = get_axi_ids_seq(priv_ids, 1, Access.Unpriv)[0]
    await sequence_csr_write(dut, False, priv_ids, tid)
