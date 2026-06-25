# SPDX-License-Identifier: Apache-2.0
#
# Read/Write tests for DEVICE_RESET, RECOVERY_STATUS, DEVICE_STATUS from
# both AXI (SW/CSR) and I3C (OCP Recovery protocol) sides.
#
# Per OCP Recovery v1.1 spec Section 9 and src/rdl/secure_firmware_recovery_interface.rdl:
#   - DEVICE_RESET    : R/W from both AXI and I3C (3 bytes from I3C side)
#                       AXI RESET_CTRL[7:0] field is woclr (write-1-to-clear).
#                       I3C writes go through HW path (we=true), bypassing woclr.
#   - RECOVERY_STATUS : R/W from AXI, READ-ONLY from I3C (2 bytes)
#   - DEVICE_STATUS   : R/W from AXI, READ-ONLY from I3C (7 bytes spanning
#                       DEVICE_STATUS_0 and DEVICE_STATUS_1)
#                       AXI DEVICE_STATUS_0.PROT_ERROR[15:8] field is rclr
#                       (clears on read from SW side).
#
# I3C writes to RECOVERY_STATUS / DEVICE_STATUS must be rejected by the
# recovery target with PROT_ERROR = 0x1 (Unsupported/Write to RO Command)
# and the underlying register value must remain unchanged.

import logging

from boot import boot_init
from bus2csr import dword2int, int2dword
from ccc import CCC
from i3c_controller_fixed import I3cControllerFixed as I3cController
from i3c_recovery_interface_fixed import I3cRecoveryInterfaceFixed as I3cRecoveryInterface
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface

import cocotb

from common import timeout_task, log_seed


STATIC_ADDR = 0x5A
VIRT_STATIC_ADDR = 0x5B
DYNAMIC_ADDR = 0x52
VIRT_DYNAMIC_ADDR = 0x53


# -----------------------------------------------------------------------------
# Common setup
# -----------------------------------------------------------------------------
async def initialize(dut, fclk=333.0, fbus=12.5, timeout=50):
    """Common init: clocks, bus model, recovery iface, dynamic-address assign,
    and enter Recovery Mode so recovery-only commands are accepted."""

    cocotb.log.setLevel(logging.DEBUG)
    log_seed(dut)
    await cocotb.start(timeout_task(timeout))

    i3c_controller = I3cController(
        sda_i=dut.bus_sda, sda_o=dut.sda_sim_ctrl_i,
        scl_i=dut.bus_scl, scl_o=dut.scl_sim_ctrl_i,
        debug_state_o=None, speed=fbus * 1e6,
    )
    _ = I3CTarget(  # bystander target on the bus (not used by these tests)
        sda_i=dut.bus_sda, sda_o=dut.sda_sim_target_i,
        scl_i=dut.bus_scl, scl_o=dut.scl_sim_target_i,
        debug_state_o=None, speed=fbus * 1e6, address=0x23,
    )

    dut.peripheral_reset_done_i.value = 0
    tb = I3CTopTestInterface(dut)
    await tb.setup(fclk)

    recovery = I3cRecoveryInterface(i3c_controller)

    timings = {"T_R": 0, "T_F": 0, "T_HD_DAT": 0, "T_SU_DAT": 0}
    await boot_init(tb, timings, fclk=fclk,
                    static_addr=STATIC_ADDR, virtual_static_addr=VIRT_STATIC_ADDR,
                    dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)

    # Assign dynamic addresses (recovery uses the virtual target).
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])]
    )
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )

    # Enter Recovery Mode (DEV_STATUS = 0x3) so recovery commands are dispatched.
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, int2dword(0x3), 4
    )

    return i3c_controller, recovery, tb


# -----------------------------------------------------------------------------
# Field pack/unpack helpers (LSB-first per OCP recovery byte ordering)
# -----------------------------------------------------------------------------
def device_reset_pack(reset_ctrl, forced_recovery, if_ctrl):
    """3 bytes: [RESET_CTRL, FORCED_RECOVERY, IF_CTRL]"""
    return [reset_ctrl & 0xFF, forced_recovery & 0xFF, if_ctrl & 0xFF]


def device_reset_word(reset_ctrl, forced_recovery, if_ctrl):
    """32-bit AXI view: {8'h0, IF_CTRL, FORCED_RECOVERY, RESET_CTRL}"""
    return ((if_ctrl & 0xFF) << 16) | ((forced_recovery & 0xFF) << 8) | (reset_ctrl & 0xFF)


def recovery_status_pack(dev_rec_status, rec_img_index, vendor_specific_status):
    """2 bytes: [{REC_IMG_INDEX[3:0],DEV_REC_STATUS[3:0]}, VENDOR_SPECIFIC_STATUS]"""
    byte0 = ((rec_img_index & 0xF) << 4) | (dev_rec_status & 0xF)
    byte1 = vendor_specific_status & 0xFF
    return [byte0, byte1]


def recovery_status_word(dev_rec_status, rec_img_index, vendor_specific_status):
    """32-bit AXI view of RECOVERY_STATUS register."""
    return ((vendor_specific_status & 0xFF) << 8) \
        | ((rec_img_index & 0xF) << 4) \
        | (dev_rec_status & 0xF)


def device_status_pack(dev_status, prot_error, rec_reason_code,
                       heartbeat, vendor_status_length):
    """7 bytes per OCP DEVICE_STATUS read layout."""
    return [
        dev_status & 0xFF,
        prot_error & 0xFF,
        rec_reason_code & 0xFF,
        (rec_reason_code >> 8) & 0xFF,
        heartbeat & 0xFF,
        (heartbeat >> 8) & 0xFF,
        vendor_status_length & 0xFF,
    ]


def device_status_0_word(dev_status, prot_error, rec_reason_code):
    """DEVICE_STATUS_0 AXI 32-bit view."""
    return ((rec_reason_code & 0xFFFF) << 16) \
        | ((prot_error & 0xFF) << 8) \
        | (dev_status & 0xFF)


# -----------------------------------------------------------------------------
# I3C-side helpers
# -----------------------------------------------------------------------------
async def i3c_recovery_read_bytes(recovery, command, exp_len):
    """Issue an I3C recovery read and return the data bytes (PEC checked).
    NOTE: command_read returns (None, None) on NACK/abort, so handle that
    explicitly before referencing data/pec_ok in any assertion message."""
    res = await recovery.command_read(VIRT_DYNAMIC_ADDR, command)
    assert res is not None, f"command_read for cmd {command} returned None"
    data, pec_ok = res
    assert data is not None and pec_ok is not None, \
        f"I3C recovery read for cmd {command} failed (NACK/abort)"
    assert pec_ok, f"PEC check failed for cmd {command}, data={[hex(b) for b in data]}"
    assert len(data) == exp_len, \
        f"cmd {command} returned {len(data)} bytes, expected {exp_len}"
    return data


async def check_no_protocol_error(tb):
    """Read DEVICE_STATUS_0 and assert PROT_ERROR field is zero."""
    val = dword2int(await tb.read_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, 4))
    pe = (val >> 8) & 0xFF
    assert pe == 0, f"Unexpected PROT_ERROR=0x{pe:02X} (DEVICE_STATUS_0=0x{val:08X})"


async def expect_protocol_error(tb, expected):
    """Read DEVICE_STATUS_0 and assert PROT_ERROR matches; clear PROT_ERROR
    while preserving DEV_STATUS and REC_REASON_CODE for follow-on checks.
    NOTE: PROT_ERROR is sw rclr - the read itself clears it; we then rewrite
    the surrounding fields back so they survive the clear path."""
    val = dword2int(await tb.read_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, 4))
    pe = (val >> 8) & 0xFF
    assert pe == expected, \
        f"Expected PROT_ERROR=0x{expected:02X}, got 0x{pe:02X} (full=0x{val:08X})"
    # Rewrite preserving DEV_STATUS[7:0] and REC_REASON_CODE[31:16];
    # PROT_ERROR[15:8] forced to 0 (already cleared by the rclr-read above).
    preserved = val & 0xFFFF00FF
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr,
        int2dword(preserved), 4)


# =============================================================================
# DEVICE_RESET tests (writable from BOTH sides)
# =============================================================================

@cocotb.test()
async def test_device_reset_axi_write_axi_read(dut):
    """AXI write -> AXI read of DEVICE_RESET.
    NOTE: RESET_CTRL[7:0] is sw-onwrite=woclr, so AXI-written bits read back
    as their cleared form (start at 0, write 1 -> bit cleared to 0)."""
    _, _, tb = await initialize(dut)

    addr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_RESET.base_addr
    wdata = device_reset_word(reset_ctrl=0xAA, forced_recovery=0x0F, if_ctrl=0x01)
    await tb.write_csr(addr, int2dword(wdata), 4)
    rdata = dword2int(await tb.read_csr(addr, 4))

    # RESET_CTRL is woclr from SW side: 0 -> write 0xAA -> bits stay/clear to 0.
    expected = device_reset_word(reset_ctrl=0x00, forced_recovery=0x0F, if_ctrl=0x01)
    assert rdata == expected, \
        f"AXI->AXI DEVICE_RESET: expected 0x{expected:08X}, got 0x{rdata:08X}"

    await check_no_protocol_error(tb)
    await tb.teardown()


@cocotb.test()
async def test_device_reset_axi_write_i3c_read(dut):
    """AXI write -> I3C read of DEVICE_RESET (3 bytes)."""
    _, recovery, tb = await initialize(dut)

    addr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_RESET.base_addr
    # Use RESET_CTRL=0 so AXI woclr does not interfere.
    rc, fr, ic = 0x00, 0xE0, 0x55
    await tb.write_csr(addr, int2dword(device_reset_word(rc, fr, ic)), 4)

    data = await i3c_recovery_read_bytes(
        recovery, I3cRecoveryInterface.Command.DEVICE_RESET, 3)
    expected = device_reset_pack(rc, fr, ic)
    assert data == expected, \
        f"AXI->I3C DEVICE_RESET bytes mismatch: expected {expected}, got {data}"

    await check_no_protocol_error(tb)
    await tb.teardown()


@cocotb.test()
async def test_device_reset_i3c_write_axi_read(dut):
    """I3C write -> AXI read of DEVICE_RESET.
    I3C writes go through HW path (we=true), bypassing the SW woclr."""
    _, recovery, tb = await initialize(dut)

    addr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_RESET.base_addr
    rc, fr, ic = 0xAA, 0xBB, 0xCC
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.DEVICE_RESET,
        device_reset_pack(rc, fr, ic))

    rdata = dword2int(await tb.read_csr(addr, 4))
    expected = device_reset_word(rc, fr, ic)
    assert rdata == expected, \
        f"I3C->AXI DEVICE_RESET: expected 0x{expected:08X}, got 0x{rdata:08X}"

    await check_no_protocol_error(tb)
    await tb.teardown()


@cocotb.test()
async def test_device_reset_i3c_write_i3c_read(dut):
    """I3C write -> I3C read of DEVICE_RESET (round-trip via recovery protocol)."""
    _, recovery, tb = await initialize(dut)

    rc, fr, ic = 0x12, 0x34, 0x56
    wdata = device_reset_pack(rc, fr, ic)
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.DEVICE_RESET, wdata)

    rdata = await i3c_recovery_read_bytes(
        recovery, I3cRecoveryInterface.Command.DEVICE_RESET, 3)
    assert rdata == wdata, \
        f"I3C->I3C DEVICE_RESET bytes mismatch: expected {wdata}, got {rdata}"

    await check_no_protocol_error(tb)
    await tb.teardown()


# =============================================================================
# RECOVERY_STATUS tests (R/W from AXI, READ-ONLY from I3C per OCP spec)
# =============================================================================

@cocotb.test()
async def test_recovery_status_axi_write_axi_read(dut):
    """AXI write -> AXI read of RECOVERY_STATUS."""
    _, _, tb = await initialize(dut)

    addr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_STATUS.base_addr
    drs, idx, vss = 0x1, 0x5, 0xA5
    await tb.write_csr(addr, int2dword(recovery_status_word(drs, idx, vss)), 4)
    rdata = dword2int(await tb.read_csr(addr, 4))

    expected = recovery_status_word(drs, idx, vss)
    assert rdata == expected, \
        f"AXI->AXI RECOVERY_STATUS: expected 0x{expected:08X}, got 0x{rdata:08X}"

    await check_no_protocol_error(tb)
    await tb.teardown()


@cocotb.test()
async def test_recovery_status_axi_write_i3c_read(dut):
    """AXI write -> I3C read of RECOVERY_STATUS (2 bytes)."""
    _, recovery, tb = await initialize(dut)

    addr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_STATUS.base_addr
    drs, idx, vss = 0x2, 0xA, 0x5C
    await tb.write_csr(addr, int2dword(recovery_status_word(drs, idx, vss)), 4)

    data = await i3c_recovery_read_bytes(
        recovery, I3cRecoveryInterface.Command.RECOVERY_STATUS, 2)
    expected = recovery_status_pack(drs, idx, vss)
    assert data == expected, \
        f"AXI->I3C RECOVERY_STATUS bytes mismatch: expected {expected}, got {data}"

    await check_no_protocol_error(tb)
    await tb.teardown()


@cocotb.test()
async def test_recovery_status_i3c_write_rejected_axi_read(dut):
    """I3C write attempt to RECOVERY_STATUS must be rejected (RO per OCP spec).
    Verify: (a) PROT_ERROR=0x1 is reported, (b) AXI readback unchanged."""
    _, recovery, tb = await initialize(dut)

    addr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_STATUS.base_addr
    # Pre-load via AXI so we have a known baseline.
    base_drs, base_idx, base_vss = 0x3, 0x7, 0x11
    await tb.write_csr(addr, int2dword(recovery_status_word(base_drs, base_idx, base_vss)), 4)
    baseline = dword2int(await tb.read_csr(addr, 4))

    # Attempt I3C write (illegal); device should reject with PROT_ERROR=0x1.
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.RECOVERY_STATUS,
        recovery_status_pack(0xC, 0x3, 0xEE))

    rdata = dword2int(await tb.read_csr(addr, 4))
    assert rdata == baseline, \
        f"RECOVERY_STATUS changed after rejected I3C write: " \
        f"baseline=0x{baseline:08X}, got 0x{rdata:08X}"
    await expect_protocol_error(tb, 0x1)
    await tb.teardown()


@cocotb.test()
async def test_recovery_status_i3c_write_rejected_i3c_read(dut):
    """I3C write attempt to RECOVERY_STATUS rejected; verify via I3C read."""
    _, recovery, tb = await initialize(dut)

    addr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_STATUS.base_addr
    base_drs, base_idx, base_vss = 0x3, 0x4, 0x99
    await tb.write_csr(addr, int2dword(recovery_status_word(base_drs, base_idx, base_vss)), 4)
    expected_bytes = recovery_status_pack(base_drs, base_idx, base_vss)

    # Attempt I3C write (illegal).
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.RECOVERY_STATUS,
        recovery_status_pack(0xF, 0xF, 0xFF))

    # Clear the protocol-error flag set by the rejected write before re-reading.
    await expect_protocol_error(tb, 0x1)

    data = await i3c_recovery_read_bytes(
        recovery, I3cRecoveryInterface.Command.RECOVERY_STATUS, 2)
    assert data == expected_bytes, \
        f"RECOVERY_STATUS bytes changed after rejected I3C write: " \
        f"expected {expected_bytes}, got {data}"
    await tb.teardown()


# =============================================================================
# DEVICE_STATUS tests (R/W from AXI, READ-ONLY from I3C per OCP spec)
# =============================================================================

@cocotb.test()
async def test_device_status_axi_write_axi_read(dut):
    """AXI write -> AXI read of DEVICE_STATUS_0 and DEVICE_STATUS_1.
    NOTE: DEVICE_STATUS_0.PROT_ERROR is rclr from SW; a single read returns
    the written value but subsequent SW reads return 0 for that field."""
    _, _, tb = await initialize(dut)

    s0 = tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr
    s1 = tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_1.base_addr

    dev_status = 0x3            # stay in Recovery Mode
    prot_err = 0x00             # keep clean; rclr is exercised in rejected tests
    rec_reason = 0x1234
    heartbeat = 0x5678
    vsl = 0x00                  # vendor status length

    await tb.write_csr(s0, int2dword(device_status_0_word(dev_status, prot_err, rec_reason)), 4)
    # DEVICE_STATUS_1: HEARTBEAT[15:0], VENDOR_STATUS_LENGTH[24:16]
    s1_word = ((vsl & 0xFF) << 16) | (heartbeat & 0xFFFF)
    await tb.write_csr(s1, int2dword(s1_word), 4)

    r0 = dword2int(await tb.read_csr(s0, 4))
    r1 = dword2int(await tb.read_csr(s1, 4))

    exp0 = device_status_0_word(dev_status, prot_err, rec_reason)
    assert r0 == exp0, \
        f"AXI->AXI DEVICE_STATUS_0: expected 0x{exp0:08X}, got 0x{r0:08X}"
    # Mask to fields we wrote (low 25 bits cover HEARTBEAT + VENDOR_STATUS_LENGTH).
    assert (r1 & 0x01FFFFFF) == (s1_word & 0x01FFFFFF), \
        f"AXI->AXI DEVICE_STATUS_1: expected 0x{s1_word:08X}, got 0x{r1:08X}"

    await tb.teardown()


@cocotb.test()
async def test_device_status_axi_write_i3c_read(dut):
    """AXI write -> I3C read of DEVICE_STATUS (7 bytes spanning both regs)."""
    _, recovery, tb = await initialize(dut)

    s0 = tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr
    s1 = tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_1.base_addr

    dev_status = 0x3
    prot_err = 0x00
    rec_reason = 0xABCD
    heartbeat = 0x0F0E
    vsl = 0x00

    await tb.write_csr(s0, int2dword(device_status_0_word(dev_status, prot_err, rec_reason)), 4)
    s1_word = ((vsl & 0xFF) << 16) | (heartbeat & 0xFFFF)
    await tb.write_csr(s1, int2dword(s1_word), 4)

    data = await i3c_recovery_read_bytes(
        recovery, I3cRecoveryInterface.Command.DEVICE_STATUS, 7)
    expected = device_status_pack(dev_status, prot_err, rec_reason, heartbeat, vsl)
    assert data == expected, \
        f"AXI->I3C DEVICE_STATUS bytes mismatch: expected {expected}, got {data}"

    await tb.teardown()


@cocotb.test()
async def test_device_status_i3c_write_rejected_axi_read(dut):
    """I3C write attempt to DEVICE_STATUS must be rejected (RO per OCP spec).
    Verify: (a) PROT_ERROR=0x1 is reported, (b) AXI readback unchanged."""
    _, recovery, tb = await initialize(dut)

    s0 = tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr
    s1 = tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_1.base_addr

    # Set REC_REASON_CODE / HEARTBEAT to known values; DEV_STATUS=0x3 (Recovery).
    rec_reason = 0xDEAD
    heartbeat = 0x0BEE
    vsl = 0x00
    await tb.write_csr(s0, int2dword(device_status_0_word(0x3, 0x0, rec_reason)), 4)
    s1_word = ((vsl & 0xFF) << 16) | (heartbeat & 0xFFFF)
    await tb.write_csr(s1, int2dword(s1_word), 4)

    base_s0 = dword2int(await tb.read_csr(s0, 4))
    base_s1 = dword2int(await tb.read_csr(s1, 4))

    # Attempt I3C write with the correct length (7) to isolate "write to RO".
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.DEVICE_STATUS,
        [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])

    # PROT_ERROR is rclr from SW side, so the read here both checks and clears
    # it. expect_protocol_error then rewrites DEV_STATUS=0x3 (PROT_ERROR=0).
    await expect_protocol_error(tb, 0x1)

    # REC_REASON_CODE and DEV_STATUS must be unchanged (PROT_ERROR was rclr'd).
    r0 = dword2int(await tb.read_csr(s0, 4))
    r1 = dword2int(await tb.read_csr(s1, 4))
    assert (r0 & 0xFFFF0000) == (base_s0 & 0xFFFF0000), \
        f"REC_REASON_CODE changed after rejected I3C write: " \
        f"baseline=0x{base_s0:08X}, got 0x{r0:08X}"
    assert (r0 & 0xFF) == 0x3, \
        f"DEV_STATUS changed after rejected I3C write: got 0x{r0 & 0xFF:02X}"
    assert r1 == base_s1, \
        f"DEVICE_STATUS_1 changed after rejected I3C write: " \
        f"baseline=0x{base_s1:08X}, got 0x{r1:08X}"

    await tb.teardown()


@cocotb.test()
async def test_device_status_i3c_write_rejected_i3c_read(dut):
    """I3C write attempt to DEVICE_STATUS rejected; verify via I3C read."""
    _, recovery, tb = await initialize(dut)

    s0 = tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr
    s1 = tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_1.base_addr

    rec_reason = 0xBEEF
    heartbeat = 0x0ABC
    vsl = 0x00
    await tb.write_csr(s0, int2dword(device_status_0_word(0x3, 0x0, rec_reason)), 4)
    s1_word = ((vsl & 0xFF) << 16) | (heartbeat & 0xFFFF)
    await tb.write_csr(s1, int2dword(s1_word), 4)

    # Attempt I3C write (illegal).
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.DEVICE_STATUS,
        [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])

    # Confirm rejection via DEVICE_STATUS_0 (this read also clears PROT_ERROR).
    await expect_protocol_error(tb, 0x1)

    # I3C read DEVICE_STATUS: byte1 (PROT_ERROR) is now 0; rest unchanged.
    data = await i3c_recovery_read_bytes(
        recovery, I3cRecoveryInterface.Command.DEVICE_STATUS, 7)
    expected = device_status_pack(
        dev_status=0x3, prot_error=0x0, rec_reason_code=rec_reason,
        heartbeat=heartbeat, vendor_status_length=vsl)
    assert data == expected, \
        f"DEVICE_STATUS bytes changed after rejected I3C write: " \
        f"expected {expected}, got {data}"

    await tb.teardown()
