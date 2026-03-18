# SPDX-License-Identifier: Apache-2.0
"""
CCC tests for the I3CTargetFixed sim model.

Tests directed read CCCs across the sim target (I3CTargetFixed) and the DUT
in various scenarios: single-target, multi-target with Repeated START, with
dummy NACKs, and randomized target order. Both sim target and DUT addresses
are randomized.

Spec references:
  - Section 5.1.9.3.12: GETPID format and requirements
  - Section 5.1.4.1.1: 48-bit Provisioned ID structure
  - Figure 47: GETPID Format (multi-target with Repeated START)
"""

import logging
import random

from boot import boot_init
from ccc import CCC
from i3c_controller_fixed import I3cControllerFixed as I3cController
from i3c_target_fixed import I3CTargetFixed as I3CTarget
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import ClockCycles

from common import VALID_I3C_ADDRESSES, pick_random_addr, log_seed


def parse_pid(data):
    """Parse 6-byte GETPID response into PID fields."""
    pid_48 = int.from_bytes(data[0:6], byteorder="big", signed=False)
    manufacturer_id = (pid_48 >> 33) & 0x7FFF  # bits[47:33]
    type_selector = (pid_48 >> 32) & 0x1       # bit[32]
    vendor_value = pid_48 & 0xFFFFFFFF          # bits[31:0]
    return pid_48, manufacturer_id, type_selector, vendor_value


async def setup_env(dut, dut_pid_hi, dut_pid_lo, sim_pid,
                    sim_target_addr=None, speed=None):
    """
    Set up controller, I3CTargetFixed, DUT, and configure PIDs.

    dut_pid_hi: 15-bit value for DUT's PID_HI register (bits[47:33])
    dut_pid_lo: 32-bit value for DUT's PID_LO register (bits[31:0])
    sim_pid: 48-bit PID for the sim target
    sim_target_addr: address for the sim target (randomized if None)
    speed: I3C bus clock frequency in Hz (randomized 1-12.5 MHz if None)
    """
    cocotb.log.setLevel(logging.DEBUG)
    log_seed(dut)

    # Pick sim target address: use provided value or randomize
    if sim_target_addr is None:
        sim_target_addr = pick_random_addr()

    # Pick bus speed: use provided value or randomize
    if speed is None:
        speed = random.uniform(1e6, 12.5e6)
    dut._log.info(
        f"Sim target address: 0x{sim_target_addr:02X}, "
        f"bus speed: {speed / 1e6:.2f} MHz"
    )

    i3c_controller = I3cController(
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_ctrl_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_ctrl_i,
        debug_state_o=None,
        speed=speed,
    )

    i3c_target = I3CTarget(
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_target_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_target_i,
        debug_state_o=None,
        speed=speed,
        address=sim_target_addr,
        pid=sim_pid,
    )

    dut.peripheral_reset_done_i.value = 0

    tb = I3CTopTestInterface(dut)
    await tb.setup()
    await ClockCycles(tb.clk, 50)

    # Boot DUT with random addresses (avoiding sim target address)
    dut_addr = pick_random_addr(exclude=(sim_target_addr,))
    virt_addr = pick_random_addr(exclude=(sim_target_addr, dut_addr))
    await boot_init(tb, static_addr=dut_addr, virtual_static_addr=virt_addr)

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

    return i3c_controller, i3c_target, tb, dut_addr, sim_target_addr, virt_addr


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

    i3c_controller, i3c_target, tb, dut_addr, sim_target_addr, _ = await setup_env(
        dut, dut_pid_hi, dut_pid_lo, sim_pid=sim_pid
    )

    # --- Phase A: Single-target GETPID to sim target ---
    dut._log.info("=== Phase A: Single-target GETPID to sim target ===")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID, addr=sim_target_addr, count=6
    )
    await ClockCycles(tb.clk, 50)

    assert len(responses) == 1, f"Expected 1 response, got {len(responses)}"
    _, data = responses[0]
    verify_sim_pid(dut, data, sim_pid)

    # --- Phase B: Multi-target -- DUT first, then sim ---
    dut._log.info("=== Phase B: Multi-target DUT then sim ===")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID,
        addr=[dut_addr, sim_target_addr],
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
        addr=[sim_target_addr, dut_addr],
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

    i3c_controller, i3c_target, tb, dut_addr, sim_target_addr, virt_addr = await setup_env(
        dut, dut_pid_hi, dut_pid_lo, sim_pid=sim_pid
    )

    excluded = {dut_addr, sim_target_addr, virt_addr}
    available_dummies = [a for a in VALID_I3C_ADDRESSES if a not in excluded]

    # --- Phase A: Fixed order with dummy NACKs ---
    dut._log.info("=== Phase A: Fixed order with dummy NACKs ===")
    num_dummies = random.randint(1, 5)
    dummy_addrs = random.sample(available_dummies, num_dummies)
    dut._log.info(
        f"Address order: DUT=0x{dut_addr:02X}, "
        f"dummies={['0x%02X' % a for a in dummy_addrs]}, "
        f"sim=0x{sim_target_addr:02X}"
    )

    addr_list = [dut_addr] + dummy_addrs + [sim_target_addr]
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
    addr_list_b = [dut_addr, sim_target_addr] + dummy_addrs_b
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
        elif addr == sim_target_addr:
            assert ack, f"Sim target at 0x{addr:02X} should ACK"
            verify_sim_pid(dut, data, sim_pid)
        else:
            dut._log.info(f"Dummy 0x{addr:02X}: ACK={ack}")
            assert not ack, (
                f"Dummy target 0x{addr:02X} should NACK, got ACK"
            )

    await tb.teardown()
