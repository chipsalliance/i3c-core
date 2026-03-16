# SPDX-License-Identifier: Apache-2.0
"""
CCC tests for the I3CTargetFixed sim model.

Tests CCC handling across the sim target (I3CTargetFixed at 0x23) and the DUT
in various scenarios. Each CCC is verified for correct response format, data
content, and multi-target bus behavior.

Spec references:
  - Section 5.1.9.3.12: GETPID format and requirements
  - Section 5.1.9.3.13: GETBCR format
  - Section 5.1.9.3.14: GETDCR format
  - Section 5.1.9.3.15: GETSTATUS format (Table 27)
  - Section 5.1.9.3.5:  SETMWL/GETMWL format
  - Section 5.1.9.3.6:  SETMRL/GETMRL format
  - Section 5.1.9.3.19: GETCAPS format (Tables 35-38)
  - Section 5.1.9.3.18: GETMXDS format (Tables 30-32)
  - Section 5.1.4.1.1:  48-bit Provisioned ID structure
  - Figure 47: GETPID Format (multi-target with Repeated START)
"""

import logging
import random

from boot import boot_init, umbrella_stby_init
from ccc import CCC, RSTACT_DEF_BYTE
from i3c_controller_fixed import I3cControllerFixed as I3cController
from i3c_target_fixed import I3CTargetFixed as I3CTarget
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import ClockCycles, RisingEdge, ReadOnly

from common import VALID_I3C_ADDRESSES, log_seed

SIM_TARGET_ADDR = 0x23


def parse_pid(data):
    """Parse 6-byte GETPID response into PID fields."""
    pid_48 = int.from_bytes(data[0:6], byteorder="big", signed=False)
    manufacturer_id = (pid_48 >> 33) & 0x7FFF  # bits[47:33]
    type_selector = (pid_48 >> 32) & 0x1       # bit[32]
    vendor_value = pid_48 & 0xFFFFFFFF          # bits[31:0]
    return pid_48, manufacturer_id, type_selector, vendor_value


async def setup_env(dut, dut_pid_hi=None, dut_pid_lo=None, sim_pid=None,
                    sim_bcr=0x00, sim_dcr=0x00, sim_mwl=256, sim_mrl=256,
                    sim_ibi_payload=0, sim_getcaps=None, sim_getmxds=None):
    """
    Set up controller, I3CTargetFixed at 0x23, DUT, and configure properties.

    dut_pid_hi: 15-bit value for DUT's PID_HI register (bits[47:33])
    dut_pid_lo: 32-bit value for DUT's PID_LO register (bits[31:0])
    sim_pid: 48-bit PID for the sim target
    sim_bcr: 8-bit BCR for the sim target
    sim_dcr: 8-bit DCR for the sim target
    sim_mwl: 16-bit Max Write Length for the sim target
    sim_mrl: 16-bit Max Read Length for the sim target
    sim_ibi_payload: 8-bit Max IBI Payload Size for the sim target
    sim_getcaps: list of GETCAPS bytes for the sim target
    sim_getmxds: list of GETMXDS bytes for the sim target
    """
    cocotb.log.setLevel(logging.DEBUG)
    log_seed(dut)

    if dut_pid_hi is None:
        dut_pid_hi = random.randint(0, 0x7FFF)
    if dut_pid_lo is None:
        dut_pid_lo = random.randint(0, 0xFFFFFFFF)
    if sim_pid is None:
        sim_pid = random.randint(0, 0xFFFFFFFFFFFF)

    i3c_controller = I3cController(
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_ctrl_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_ctrl_i,
        debug_state_o=None,
        speed=12.5e6,
    )

    i3c_target = I3CTarget(
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_target_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_target_i,
        debug_state_o=None,
        speed=12.5e6,
        address=SIM_TARGET_ADDR,
        pid=sim_pid,
        bcr=sim_bcr,
        dcr=sim_dcr,
        max_write_length=sim_mwl,
        max_rd_length=sim_mrl,
        max_ibi_payload=sim_ibi_payload,
        getcaps_bytes=sim_getcaps,
        getmxds_bytes=sim_getmxds,
    )

    dut.peripheral_reset_done_i.value = 0

    tb = I3CTopTestInterface(dut)
    await tb.setup()
    await ClockCycles(tb.clk, 50)

    # Boot DUT with a random address (avoiding sim target address)
    dut_addr = random.choice(
        [a for a in VALID_I3C_ADDRESSES if a != SIM_TARGET_ADDR]
    )
    await boot_init(tb, static_addr=dut_addr)

    # Configure DUT PID via CSRs
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.PID_HI,
        dut_pid_hi,
    )
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.PID_LO,
        dut_pid_lo,
    )
    await ClockCycles(tb.clk, 50)

    return i3c_controller, i3c_target, tb, dut_addr


def verify_dut_pid(dut, data, expected_pid_hi, expected_pid_lo):
    """Verify DUT GETPID response. DUT bit[32] is always 0."""
    pid_rx, mfr_rx, type_rx, vendor_rx = parse_pid(data)
    # DUT PID_HI maps to bits[47:33], bit[32]=0 always
    expected_48 = (expected_pid_hi << 33) | expected_pid_lo
    dut._log.info(
        f"DUT PID: 0x{pid_rx:012X} "
        f"(mfr=0x{mfr_rx:04X} type={type_rx} vendor=0x{vendor_rx:08X})"
    )
    assert pid_rx == expected_48, (
        f"DUT PID mismatch: exp=0x{expected_48:012X} got=0x{pid_rx:012X}"
    )


def verify_sim_pid(dut, data, expected_pid):
    """Verify sim target GETPID response."""
    pid_rx, mfr_rx, type_rx, vendor_rx = parse_pid(data)
    dut._log.info(
        f"Sim PID: 0x{pid_rx:012X} "
        f"(mfr=0x{mfr_rx:04X} type={type_rx} vendor=0x{vendor_rx:08X})"
    )
    assert pid_rx == expected_pid, (
        f"Sim PID mismatch: exp=0x{expected_pid:012X} got=0x{pid_rx:012X}"
    )


# =========================================================================
# Test 1: GETPID single-target and multi-target ordering
# =========================================================================
@cocotb.test()
async def test_getpid_multi_target_ordering(dut):
    """
    Verify GETPID across single-target and multi-target directed CCC frames
    with different target ordering. Uses one environment for all phases.

    Spec: Section 5.1.9.3.12, Figure 47

    Phases:
      A) Single target: GETPID to sim target only
      B) Multi-target: DUT first, then sim target
      C) Multi-target: sim target first, then DUT
    """
    sim_pid = random.randint(0, 0xFFFFFFFFFFFF)
    dut_pid_hi = random.randint(0, 0x7FFF)
    dut_pid_lo = random.randint(0, 0xFFFFFFFF)

    i3c_controller, i3c_target, tb, dut_addr = await setup_env(
        dut, dut_pid_hi, dut_pid_lo, sim_pid=sim_pid
    )

    # --- Phase A: Single-target GETPID to sim target ---
    dut._log.info("=== Phase A: Single-target GETPID to sim target ===")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID, addr=SIM_TARGET_ADDR, count=6
    )
    await ClockCycles(tb.clk, 50)

    assert len(responses) == 1, f"Expected 1 response, got {len(responses)}"
    _, data = responses[0]
    verify_sim_pid(dut, data, sim_pid)

    # --- Phase B: Multi-target -- DUT first, then sim ---
    dut._log.info("=== Phase B: Multi-target DUT then sim ===")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID,
        addr=[dut_addr, SIM_TARGET_ADDR],
        count=6,
    )
    await ClockCycles(tb.clk, 50)

    assert len(responses) == 2, f"Expected 2 responses, got {len(responses)}"
    _, dut_data = responses[0]
    verify_dut_pid(dut, dut_data, dut_pid_hi, dut_pid_lo)
    _, sim_data = responses[1]
    verify_sim_pid(dut, sim_data, sim_pid)

    # --- Phase C: Multi-target -- sim first, then DUT ---
    dut._log.info("=== Phase C: Multi-target sim then DUT ===")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID,
        addr=[SIM_TARGET_ADDR, dut_addr],
        count=6,
    )
    await ClockCycles(tb.clk, 50)

    assert len(responses) == 2, f"Expected 2 responses, got {len(responses)}"
    _, sim_data = responses[0]
    verify_sim_pid(dut, sim_data, sim_pid)
    _, dut_data = responses[1]
    verify_dut_pid(dut, dut_data, dut_pid_hi, dut_pid_lo)

    await tb.teardown()


# =========================================================================
# Test 2: GETPID with dummy NACKs and randomized target order
# =========================================================================
@cocotb.test()
async def test_getpid_with_nacks_and_random_order(dut):
    """
    Verify GETPID with non-existent (NACK) targets and randomized ordering.
    Exercises the sim target's CCC-pending state maintenance across
    multiple NON_APPLICABLE addresses in arbitrary positions.

    Phases:
      A) Fixed order: DUT + 1-5 random dummies + sim target
      B) Randomized order: shuffle [DUT, sim, dummy1, dummy2]
    """
    sim_pid = random.randint(0, 0xFFFFFFFFFFFF)
    dut_pid_hi = random.randint(0, 0x7FFF)
    dut_pid_lo = random.randint(0, 0xFFFFFFFF)

    i3c_controller, i3c_target, tb, dut_addr = await setup_env(
        dut, dut_pid_hi, dut_pid_lo, sim_pid=sim_pid
    )

    excluded = {dut_addr, SIM_TARGET_ADDR}
    available_dummies = [a for a in VALID_I3C_ADDRESSES if a not in excluded]

    # --- Phase A: Fixed order with dummy NACKs ---
    dut._log.info("=== Phase A: Fixed order with dummy NACKs ===")
    num_dummies = random.randint(1, 5)
    dummy_addrs = random.sample(available_dummies, num_dummies)
    dut._log.info(
        f"Address order: DUT=0x{dut_addr:02X}, "
        f"dummies={['0x%02X' % a for a in dummy_addrs]}, "
        f"sim=0x{SIM_TARGET_ADDR:02X}"
    )

    addr_list = [dut_addr] + dummy_addrs + [SIM_TARGET_ADDR]
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID,
        addr=addr_list,
        count=6,
    )
    await ClockCycles(tb.clk, 50)

    expected_count = 1 + num_dummies + 1
    assert len(responses) == expected_count, (
        f"Expected {expected_count} responses, got {len(responses)}"
    )

    dut_ack, dut_data = responses[0]
    assert dut_ack, "DUT should ACK GETPID"
    verify_dut_pid(dut, dut_data, dut_pid_hi, dut_pid_lo)

    for i, dummy_addr in enumerate(dummy_addrs):
        dummy_ack = responses[1 + i][0]
        dut._log.info(
            f"Dummy target 0x{dummy_addr:02X}: ACK={dummy_ack}"
        )
        assert not dummy_ack, (
            f"Dummy target 0x{dummy_addr:02X} should NACK, got ACK"
        )

    sim_ack, sim_data = responses[-1]
    assert sim_ack, "Sim target should ACK GETPID"
    verify_sim_pid(dut, sim_data, sim_pid)

    # --- Phase B: Randomized order ---
    dut._log.info("=== Phase B: Randomized target order ===")
    dummy_addrs_b = random.sample(available_dummies, 2)
    addr_list_b = [dut_addr, SIM_TARGET_ADDR] + dummy_addrs_b
    random.shuffle(addr_list_b)

    dut._log.info(
        f"Randomized order: {['0x%02X' % a for a in addr_list_b]}"
    )

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID,
        addr=addr_list_b,
        count=6,
    )
    await ClockCycles(tb.clk, 50)

    assert len(responses) == len(addr_list_b), (
        f"Expected {len(addr_list_b)} responses, got {len(responses)}"
    )

    for i, addr in enumerate(addr_list_b):
        ack, data = responses[i]
        if addr == dut_addr:
            assert ack, f"DUT at 0x{addr:02X} should ACK"
            verify_dut_pid(dut, data, dut_pid_hi, dut_pid_lo)
        elif addr == SIM_TARGET_ADDR:
            assert ack, f"Sim target at 0x{addr:02X} should ACK"
            verify_sim_pid(dut, data, sim_pid)
        else:
            dut._log.info(f"Dummy 0x{addr:02X}: ACK={ack}")
            assert not ack, (
                f"Dummy target 0x{addr:02X} should NACK, got ACK"
            )

    await tb.teardown()


# =========================================================================
# Test 3: GETPID across warm and cold resets
# =========================================================================
async def do_pattern_reset(dut, tb, i3c_controller, expect_escalation=False):
    """Send Target Reset Pattern and handle the reset handshake."""
    dut._log.info(
        f"Initiating Target Reset Pattern "
        f"(expect_escalation={expect_escalation})"
    )
    await i3c_controller.send_target_reset_pattern()

    assert dut.peripheral_reset_o == (not expect_escalation), (
        f"peripheral_reset_o mismatch: expected {not expect_escalation}, "
        f"got {int(dut.peripheral_reset_o)}"
    )
    await RisingEdge(tb.clk)

    # Signal that peripheral reset is finished
    dut.peripheral_reset_done_i.value = not expect_escalation
    await RisingEdge(tb.clk)

    await ReadOnly()
    assert dut.peripheral_reset_o == 0, (
        f"peripheral_reset_o not deasserted after reset done"
    )

    await RisingEdge(tb.clk)
    dut.peripheral_reset_done_i.value = 0


@cocotb.test()
async def test_getpid_across_resets(dut):
    """
    Verify PID stability across warm and cold resets.

    Sequence:
      (a) Initial GETPID on sim target + DUT
      (b) Warm reset: RSTACT 0x01 broadcast + Target Reset Pattern + re-boot
      (c) GETPID again -- verify PIDs unchanged
      (d) Cold reset: RSTACT 0x02 broadcast + Target Reset Pattern + re-boot
      (e) GETPID again -- verify PIDs unchanged

    Spec: Sections 5.1.9.3.12, 5.1.9.3.26, 5.1.11
    """
    sim_pid = random.randint(0, 0xFFFFFFFFFFFF)
    dut_pid_hi = random.randint(0, 0x7FFF)
    dut_pid_lo = random.randint(0, 0xFFFFFFFF)

    i3c_controller, i3c_target, tb, dut_addr = await setup_env(
        dut, dut_pid_hi, dut_pid_lo, sim_pid=sim_pid
    )

    # (a) Initial GETPID
    dut._log.info("=== Phase A: Initial GETPID ===")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID,
        addr=[dut_addr, SIM_TARGET_ADDR],
        count=6,
    )
    await ClockCycles(tb.clk, 50)
    assert len(responses) == 2
    verify_dut_pid(dut, responses[0][1], dut_pid_hi, dut_pid_lo)
    verify_sim_pid(dut, responses[1][1], sim_pid)

    # (b) Warm reset: RSTACT 0x01 (peripheral reset) + Target Reset Pattern
    dut._log.info("=== Phase B: Warm reset (RSTACT 0x01) ===")
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.BCAST.RSTACT,
        defining_byte=RSTACT_DEF_BYTE.PERIPHERAL_RESET,
        stop=True,
    )
    await ClockCycles(tb.clk, 50)
    await do_pattern_reset(dut, tb, i3c_controller)
    await ClockCycles(tb.clk, 100)

    # Re-boot DUT after peripheral reset
    await boot_init(tb, static_addr=dut_addr)

    # Re-configure DUT PID (may have been preserved, but set explicitly)
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.PID_HI,
        dut_pid_hi,
    )
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.PID_LO,
        dut_pid_lo,
    )
    await ClockCycles(tb.clk, 50)

    # (c) GETPID after warm reset
    dut._log.info("=== Phase C: GETPID after warm reset ===")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID,
        addr=[dut_addr, SIM_TARGET_ADDR],
        count=6,
    )
    await ClockCycles(tb.clk, 50)
    assert len(responses) == 2
    verify_dut_pid(dut, responses[0][1], dut_pid_hi, dut_pid_lo)
    verify_sim_pid(dut, responses[1][1], sim_pid)

    # (d) Cold reset: RSTACT 0x02 (whole target reset) + Target Reset Pattern
    dut._log.info("=== Phase D: Cold reset (RSTACT 0x02) ===")
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.BCAST.RSTACT,
        defining_byte=RSTACT_DEF_BYTE.TARGET_RESET,
        stop=True,
    )
    await ClockCycles(tb.clk, 50)
    await do_pattern_reset(dut, tb, i3c_controller)
    await ClockCycles(tb.clk, 100)

    # Re-boot DUT after whole target reset
    await boot_init(tb, static_addr=dut_addr)

    # Re-configure DUT PID
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.PID_HI,
        dut_pid_hi,
    )
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.PID_LO,
        dut_pid_lo,
    )
    await ClockCycles(tb.clk, 50)

    # (e) GETPID after cold reset
    dut._log.info("=== Phase E: GETPID after cold reset ===")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID,
        addr=[dut_addr, SIM_TARGET_ADDR],
        count=6,
    )
    await ClockCycles(tb.clk, 50)
    assert len(responses) == 2
    verify_dut_pid(dut, responses[0][1], dut_pid_hi, dut_pid_lo)
    verify_sim_pid(dut, responses[1][1], sim_pid)

    await tb.teardown()


# =========================================================================
# Test 4: GETPID vendor-fixed vs random type selector
# =========================================================================
@cocotb.test()
async def test_getpid_vendor_fixed_vs_random(dut):
    """
    Verify PID type selector (bit[32]) and manufacturer ID stability.

    Uses a single test environment. First configures sim target with
    bit[32]=0 (vendor fixed), verifies manufacturer ID and vendor value
    across multiple reads. Then updates the PID to bit[32]=1 (random mode)
    and verifies bits[47:33] still match the configured value (spec
    5.1.4.1.1: bits[47:33] shall not be randomized).
    """
    sim_mfr_id = random.randint(0, 0x7FFF)
    sim_vendor_val = random.randint(0, 0xFFFFFFFF)
    # Start with vendor fixed mode (bit[32]=0)
    sim_pid_fixed = (sim_mfr_id << 33) | (0 << 32) | sim_vendor_val

    dut_pid_hi = random.randint(0, 0x7FFF)
    dut_pid_lo = random.randint(0, 0xFFFFFFFF)

    i3c_controller, i3c_target, tb, dut_addr = await setup_env(
        dut, dut_pid_hi, dut_pid_lo, sim_pid=sim_pid_fixed
    )

    # --- Vendor Fixed mode (bit[32]=0) ---
    dut._log.info(
        f"Vendor Fixed mode: mfr=0x{sim_mfr_id:04X} "
        f"vendor=0x{sim_vendor_val:08X}"
    )

    for iteration in range(3):
        responses = await i3c_controller.i3c_ccc_read(
            ccc=CCC.DIRECT.GETPID, addr=SIM_TARGET_ADDR, count=6
        )
        await ClockCycles(tb.clk, 50)

        _, data = responses[0]
        pid_rx, mfr_rx, type_rx, vendor_rx = parse_pid(data)

        assert type_rx == 0, (
            f"Iter {iteration}: type selector should be 0 (vendor fixed), "
            f"got {type_rx}"
        )
        assert mfr_rx == sim_mfr_id, (
            f"Iter {iteration}: manufacturer ID mismatch: "
            f"exp=0x{sim_mfr_id:04X} got=0x{mfr_rx:04X}"
        )
        assert vendor_rx == sim_vendor_val, (
            f"Iter {iteration}: vendor value mismatch: "
            f"exp=0x{sim_vendor_val:08X} got=0x{vendor_rx:08X}"
        )

    # --- Random mode (bit[32]=1) ---
    # Update the sim target PID in-place (same manufacturer ID, new value)
    sim_random_val = random.randint(0, 0xFFFFFFFF)
    sim_pid_random = (sim_mfr_id << 33) | (1 << 32) | sim_random_val
    i3c_target.pid = sim_pid_random

    dut._log.info(
        f"Random mode: mfr=0x{sim_mfr_id:04X} "
        f"random=0x{sim_random_val:08X}"
    )

    for iteration in range(3):
        responses = await i3c_controller.i3c_ccc_read(
            ccc=CCC.DIRECT.GETPID, addr=SIM_TARGET_ADDR, count=6
        )
        await ClockCycles(tb.clk, 50)

        _, data = responses[0]
        pid_rx, mfr_rx, type_rx, vendor_rx = parse_pid(data)

        assert type_rx == 1, (
            f"Iter {iteration}: type selector should be 1 (random), "
            f"got {type_rx}"
        )
        # Spec 5.1.4.1.1: bits[47:33] shall not be randomized
        assert mfr_rx == sim_mfr_id, (
            f"Iter {iteration}: manufacturer ID changed! "
            f"Spec 5.1.4.1.1: bits[47:33] shall not be randomized. "
            f"exp=0x{sim_mfr_id:04X} got=0x{mfr_rx:04X}"
        )
        assert vendor_rx == sim_random_val, (
            f"Iter {iteration}: random value mismatch: "
            f"exp=0x{sim_random_val:08X} got=0x{vendor_rx:08X}"
        )

    await tb.teardown()


# =========================================================================
# Test 5: GETBCR + GETDCR -- identity CCCs with runtime update
# =========================================================================
@cocotb.test()
async def test_sim_target_get_identity(dut):
    """
    Verify GETBCR and GETDCR return configured values for the sim target,
    including runtime updates and multi-target directed frames.

    Spec: Sections 5.1.9.3.13 (GETBCR), 5.1.9.3.14 (GETDCR)
    """
    sim_bcr = random.randint(0, 0xFF)
    sim_dcr = random.randint(0, 0xFF)
    i3c_controller, i3c_target, tb, dut_addr = await setup_env(
        dut, sim_bcr=sim_bcr, sim_dcr=sim_dcr
    )

    # --- GETBCR: single-target ---
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=SIM_TARGET_ADDR, count=1
    )
    await ClockCycles(tb.clk, 50)
    ack, data = responses[0]
    assert ack, "Sim target should ACK GETBCR"
    dut._log.info(f"GETBCR: 0x{data[0]:02X} (exp 0x{sim_bcr:02X})")
    assert data[0] == sim_bcr, (
        f"BCR mismatch: exp=0x{sim_bcr:02X} got=0x{data[0]:02X}"
    )

    # --- GETDCR: single-target ---
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETDCR, addr=SIM_TARGET_ADDR, count=1
    )
    await ClockCycles(tb.clk, 50)
    ack, data = responses[0]
    assert ack, "Sim target should ACK GETDCR"
    dut._log.info(f"GETDCR: 0x{data[0]:02X} (exp 0x{sim_dcr:02X})")
    assert data[0] == sim_dcr, (
        f"DCR mismatch: exp=0x{sim_dcr:02X} got=0x{data[0]:02X}"
    )

    # --- GETBCR: multi-target (DUT + sim) ---
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=[dut_addr, SIM_TARGET_ADDR], count=1,
    )
    await ClockCycles(tb.clk, 50)
    assert len(responses) == 2
    assert responses[1][1][0] == sim_bcr, "Multi-target BCR mismatch"

    # --- Runtime update: change BCR and DCR, re-read ---
    new_bcr = sim_bcr ^ 0xFF  # flip all bits
    new_dcr = sim_dcr ^ 0xFF
    i3c_target.bcr = new_bcr
    i3c_target.dcr = new_dcr

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=SIM_TARGET_ADDR, count=1
    )
    await ClockCycles(tb.clk, 50)
    assert responses[0][1][0] == new_bcr, (
        f"Updated BCR: exp=0x{new_bcr:02X} got=0x{responses[0][1][0]:02X}"
    )

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETDCR, addr=SIM_TARGET_ADDR, count=1
    )
    await ClockCycles(tb.clk, 50)
    assert responses[0][1][0] == new_dcr, (
        f"Updated DCR: exp=0x{new_dcr:02X} got=0x{responses[0][1][0]:02X}"
    )

    await tb.teardown()


# =========================================================================
# Test 6: GETSTATUS -- status format and protocol error self-clear
# =========================================================================
@cocotb.test()
async def test_getstatus_sim_target(dut):
    """
    Verify GETSTATUS returns correct 2-byte status for the sim target.
    Tests activity mode, pending interrupt, protocol error self-clear,
    and vendor status byte.

    Spec: Section 5.1.9.3.15, Table 27
      MSB [15:8] = Vendor Reserved
      LSB [7:6]  = Activity Mode
          [5]    = Protocol Error (self-clears on read)
          [4]    = Reserved
          [3:0]  = Pending Interrupt
    """
    i3c_controller, i3c_target, tb, dut_addr = await setup_env(dut)

    # (a) Default: all zeros
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETSTATUS, addr=SIM_TARGET_ADDR, count=2
    )
    await ClockCycles(tb.clk, 50)
    ack, data = responses[0]
    assert ack, "Should ACK GETSTATUS"
    status = int.from_bytes(data[0:2], byteorder="big")
    dut._log.info(f"GETSTATUS default: 0x{status:04X}")
    assert status == 0x0000, f"Default should be 0x0000, got 0x{status:04X}"

    # (b) Set activity_mode=3, pending_interrupt=5, vendor_status=0xAB
    i3c_target.activity_mode = 3
    i3c_target.pending_interrupt = 5
    i3c_target.vendor_status = 0xAB
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETSTATUS, addr=SIM_TARGET_ADDR, count=2
    )
    await ClockCycles(tb.clk, 50)
    data = responses[0][1]
    msb = data[0]
    lsb = data[1]
    assert msb == 0xAB, f"Vendor status exp=0xAB got=0x{msb:02X}"
    assert (lsb >> 6) & 0x3 == 3, f"Activity mode exp=3 got={(lsb >> 6) & 0x3}"
    assert lsb & 0xF == 5, f"Pending int exp=5 got={lsb & 0xF}"

    # (c) Protocol error: set, read (should be 1), read again (should self-clear)
    i3c_target.protocol_error = True
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETSTATUS, addr=SIM_TARGET_ADDR, count=2
    )
    await ClockCycles(tb.clk, 50)
    lsb = responses[0][1][1]
    assert (lsb >> 5) & 0x1 == 1, "Protocol error should be set"

    # Second read: should be cleared
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETSTATUS, addr=SIM_TARGET_ADDR, count=2
    )
    await ClockCycles(tb.clk, 50)
    lsb = responses[0][1][1]
    assert (lsb >> 5) & 0x1 == 0, "Protocol error should self-clear"

    await tb.teardown()


# =========================================================================
# Test 7: All remaining GET CCCs -- MWL, MRL, CAPS, MXDS + sequence
# =========================================================================
@cocotb.test()
async def test_sim_target_get_all_cccs(dut):
    """
    Consolidates GETMWL, GETMRL (with/without IBI payload byte), GETCAPS,
    GETMXDS, and a full back-to-back sequence of all directed GET CCCs.

    Spec: Sections 5.1.9.3.5, 5.1.9.3.6, 5.1.9.3.19, 5.1.9.3.18
    """
    sim_pid = random.randint(0, 0xFFFFFFFFFFFF)
    sim_bcr = random.randint(0, 0xFB) & ~0x04  # clear bit[2] initially
    sim_dcr = random.randint(0, 0xFF)
    sim_mwl = random.randint(16, 0xFFFF)
    sim_mrl = random.randint(16, 0xFFFF)
    sim_caps = [0x01, 0x01]       # HDR-DDR, I3C Basic v1.1
    sim_mxds = [0x01, 0x02]       # maxWr=8MHz, maxRd=6MHz

    i3c_controller, i3c_target, tb, dut_addr = await setup_env(
        dut,
        sim_pid=sim_pid, sim_bcr=sim_bcr, sim_dcr=sim_dcr,
        sim_mwl=sim_mwl, sim_mrl=sim_mrl,
        sim_getcaps=sim_caps, sim_getmxds=sim_mxds,
    )

    # --- (a) GETMWL ---
    dut._log.info("=== GETMWL ===")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETMWL, addr=SIM_TARGET_ADDR, count=2
    )
    await ClockCycles(tb.clk, 50)
    ack, data = responses[0]
    assert ack, "Should ACK GETMWL"
    mwl_rx = int.from_bytes(data[0:2], byteorder="big")
    assert mwl_rx == sim_mwl, (
        f"MWL exp=0x{sim_mwl:04X} got=0x{mwl_rx:04X}"
    )

    # Runtime update
    new_mwl = random.randint(16, 0xFFFF)
    i3c_target.max_write_length = new_mwl
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETMWL, addr=SIM_TARGET_ADDR, count=2
    )
    await ClockCycles(tb.clk, 50)
    mwl_rx = int.from_bytes(responses[0][1][0:2], byteorder="big")
    assert mwl_rx == new_mwl, f"Updated MWL mismatch"

    # --- (b) GETMRL without IBI payload (BCR bit[2]=0) ---
    dut._log.info("=== GETMRL (no IBI) ===")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETMRL, addr=SIM_TARGET_ADDR, count=2
    )
    await ClockCycles(tb.clk, 50)
    ack, data = responses[0]
    assert ack, "Should ACK GETMRL"
    mrl_rx = int.from_bytes(data[0:2], byteorder="big")
    assert mrl_rx == sim_mrl, (
        f"MRL exp=0x{sim_mrl:04X} got=0x{mrl_rx:04X}"
    )

    # --- (c) GETMRL with IBI payload (BCR bit[2]=1) ---
    dut._log.info("=== GETMRL (with IBI payload) ===")
    ibi_payload = random.randint(1, 0xFF)
    i3c_target.bcr = sim_bcr | 0x04
    i3c_target.max_ibi_payload = ibi_payload
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETMRL, addr=SIM_TARGET_ADDR, count=3
    )
    await ClockCycles(tb.clk, 50)
    ack, data = responses[0]
    assert ack
    mrl_rx = int.from_bytes(data[0:2], byteorder="big")
    assert mrl_rx == sim_mrl, f"MRL mismatch with IBI"
    assert data[2] == ibi_payload, (
        f"IBI payload exp=0x{ibi_payload:02X} got=0x{data[2]:02X}"
    )
    # Restore BCR
    i3c_target.bcr = sim_bcr

    # --- (d) GETCAPS (2-byte, then update to 4-byte) ---
    dut._log.info("=== GETCAPS ===")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETCAPS, addr=SIM_TARGET_ADDR, count=2
    )
    await ClockCycles(tb.clk, 50)
    ack, data = responses[0]
    assert ack, "Should ACK GETCAPS"
    for i, exp in enumerate(sim_caps):
        assert data[i] == exp, (
            f"GETCAPS[{i}] exp=0x{exp:02X} got=0x{data[i]:02X}"
        )

    caps4 = [0x09, 0x41, 0x18, 0x00]
    i3c_target.getcaps_bytes = caps4
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETCAPS, addr=SIM_TARGET_ADDR, count=4
    )
    await ClockCycles(tb.clk, 50)
    for i, exp in enumerate(caps4):
        assert responses[0][1][i] == exp, f"GETCAPS4[{i}] mismatch"

    # --- (e) GETMXDS (2-byte Format 1, then 5-byte Format 2) ---
    dut._log.info("=== GETMXDS ===")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETMXDS, addr=SIM_TARGET_ADDR, count=2
    )
    await ClockCycles(tb.clk, 50)
    ack, data = responses[0]
    assert ack, "Should ACK GETMXDS"
    assert data[0] == sim_mxds[0] and data[1] == sim_mxds[1], "GETMXDS F1 mismatch"

    mxds5 = [0x03, 0x04, 0x00, 0x10, 0x00]
    i3c_target.getmxds_bytes = mxds5
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETMXDS, addr=SIM_TARGET_ADDR, count=5
    )
    await ClockCycles(tb.clk, 50)
    for i, exp in enumerate(mxds5):
        assert responses[0][1][i] == exp, f"GETMXDS5[{i}] mismatch"

    # --- (f) Back-to-back sequence: all CCCs in rapid succession ---
    dut._log.info("=== Back-to-back CCC sequence ===")
    # Restore original values for clean sequence
    i3c_target.getcaps_bytes = sim_caps
    i3c_target.getmxds_bytes = sim_mxds

    ccc_checks = [
        (CCC.DIRECT.GETPID, 6),
        (CCC.DIRECT.GETBCR, 1),
        (CCC.DIRECT.GETDCR, 1),
        (CCC.DIRECT.GETSTATUS, 2),
        (CCC.DIRECT.GETMWL, 2),
        (CCC.DIRECT.GETMRL, 2),
        (CCC.DIRECT.GETCAPS, 2),
        (CCC.DIRECT.GETMXDS, 2),
    ]
    for ccc_code, count in ccc_checks:
        responses = await i3c_controller.i3c_ccc_read(
            ccc=ccc_code, addr=SIM_TARGET_ADDR, count=count
        )
        await ClockCycles(tb.clk, 50)
        assert responses[0][0], f"CCC 0x{ccc_code:02X} should ACK"
        assert len(responses[0][1]) >= count, (
            f"CCC 0x{ccc_code:02X}: expected >= {count} bytes"
        )

    await tb.teardown()
