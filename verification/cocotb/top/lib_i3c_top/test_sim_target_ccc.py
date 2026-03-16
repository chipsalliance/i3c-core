# SPDX-License-Identifier: Apache-2.0
"""
GETPID CCC tests for the I3CTargetFixed sim model.

Tests the GETPID CCC (0x8D) across the sim target (I3CTargetFixed at 0x23)
and the DUT in various scenarios: single-target, multi-target with Repeated
START, with dummy NACKs, across resets, PID type selector modes, and
randomized target order.

Spec references:
  - Section 5.1.9.3.12: GETPID format and requirements
  - Section 5.1.4.1.1: 48-bit Provisioned ID structure
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


async def setup_env(dut, dut_pid_hi, dut_pid_lo, sim_pid):
    """
    Set up controller, I3CTargetFixed at 0x23, DUT, and configure PIDs.

    dut_pid_hi: 15-bit value for DUT's PID_HI register (bits[47:33])
    dut_pid_lo: 32-bit value for DUT's PID_LO register (bits[31:0])
    sim_pid: 48-bit PID for the sim target
    """
    cocotb.log.setLevel(logging.DEBUG)
    log_seed(dut)

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
