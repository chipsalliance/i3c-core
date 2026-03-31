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
from cocotb.triggers import ClockCycles, Timer

from common import VALID_I3C_ADDRESSES, pick_random_addr, log_seed, do_getpid, do_getbcr


def parse_pid(data):
    """Parse 6-byte GETPID response into PID fields."""
    pid_48 = int.from_bytes(data[0:6], byteorder="big", signed=False)
    manufacturer_id = (pid_48 >> 33) & 0x7FFF  # bits[47:33]
    type_selector = (pid_48 >> 32) & 0x1       # bit[32]
    vendor_value = pid_48 & 0xFFFFFFFF          # bits[31:0]
    return pid_48, manufacturer_id, type_selector, vendor_value


async def setup_env(dut, dut_pid_hi, dut_pid_lo, sim_pid,
                    sim_target_addr=None, speed=None,
                    sim_bcr=0x00, sim_dcr=0x00,
                    sda_read_timeout_us=100):
    """
    Set up controller, I3CTargetFixed, DUT, and configure PIDs.

    dut_pid_hi: 15-bit value for DUT's PID_HI register (bits[47:33])
    dut_pid_lo: 32-bit value for DUT's PID_LO register (bits[31:0])
    sim_pid: 48-bit PID for the sim target
    sim_target_addr: address for the sim target (randomized if None)
    speed: I3C bus clock frequency in Hz (randomized 1-12.5 MHz if None)
    sim_bcr: 8-bit BCR value for the sim target
    sim_dcr: 8-bit DCR value for the sim target
    sda_read_timeout_us: SDA read detector timeout in microseconds
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
        bcr=sim_bcr,
        dcr=sim_dcr,
        sda_read_timeout_us=sda_read_timeout_us,
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


# Number of abort-recovery iterations for premature STOP test.
NUM_STOP_ITERATIONS = 5

# ---------------------------------------------------------------------------
# Legal abort position definitions for a GETPID directed read frame.
#
# GETPID directed read frame structure (from START):
#   [S] 7E/W (8b, ctrl OD)  ACK (1b, target OD)
#   CCC_GETPID (8b, ctrl PP)  T-bit (1b, ctrl PP)
#   [Sr] ADDR/R (8b, ctrl OD)  ACK (1b, target OD)
#   [DATA: byte_N (8b, target PP)  T-bit (1b, target PP)] x 6 bytes
#
# Per Section 5.1.2 (lines 3202-3210), STOP is "tolerated" when the
# Controller controls SDA or SDA is Open-Drain.  Section 5.1.2.3.4
# defines early termination of reads at T-bit boundaries.
#
# Each entry: (abort_type, param, description)
#   abort_type  "setup_broadcast" : STOP after broadcast 7E/W + ACK
#               "setup_ccc"       : STOP after CCC byte + T-bit
#               "data"            : STOP after *param* complete data
#                                   bytes (each = 8 data + 1 T-bit)
#
# IMPORTANT: Data-phase positions (abort_type="data") are only safe
# for the sim target (OD driver).  For the DUT, a raw STOP during
# data-phase PP driving triggers the push-pull STOP detection bug.
# However, the spec-defined read termination at T-bit boundaries uses
# Repeated START (Sr), not STOP (Section 5.1.2.3.4).  Sr avoids PP
# contention because the controller drives SDA HIGH first:
#   - If DUT drives SDA=0: bus=0, DUT matches, no contention
#   - If DUT drives SDA=1: bus=1, then controller pulls LOW -> Sr detected
# So data-phase T-bit boundaries use "data_sr" (Sr then STOP).
# Position 0 (after directed ACK) uses raw STOP since the target is
# still transitioning from OD to PP.
# ---------------------------------------------------------------------------

# Full set: usable for sim target (OD) aborts -- raw STOP everywhere
LEGAL_ABORT_POSITIONS_ALL = [
    ("setup_broadcast", None, "after broadcast 7E/W ACK (ctrl OD)"),
    ("setup_ccc",       None, "after CCC GETPID + T-bit (ctrl PP)"),
    ("data",            0,    "after directed ACK (OD/PP boundary)"),
    ("data",            1,    "after data byte 0 T-bit boundary"),
    ("data",            2,    "after data byte 1 T-bit boundary"),
    ("data",            3,    "after data byte 2 T-bit boundary"),
    ("data",            4,    "after data byte 3 T-bit boundary"),
    ("data",            5,    "after data byte 4 T-bit boundary"),
]

# DUT-safe set: setup phases use raw STOP (controller/OD bus control).
# Data-phase T-bit boundaries use Sr+STOP (spec Section 5.1.2.3.4).
LEGAL_ABORT_POSITIONS_DUT = [
    ("setup_broadcast", None, "after broadcast 7E/W ACK (ctrl OD)"),
    ("setup_ccc",       None, "after CCC GETPID + T-bit (ctrl PP)"),
    ("data_sr",         1,    "Sr after data byte 0 T-bit (spec 5.1.2.3.4)"),
    ("data_sr",         2,    "Sr after data byte 1 T-bit (spec 5.1.2.3.4)"),
    ("data_sr",         3,    "Sr after data byte 2 T-bit (spec 5.1.2.3.4)"),
    ("data_sr",         4,    "Sr after data byte 3 T-bit (spec 5.1.2.3.4)"),
    ("data_sr",         5,    "Sr after data byte 4 T-bit (spec 5.1.2.3.4)"),
]



async def abort_getpid_at_legal_position(ctrl, addr, abort_type, param):
    """Execute partial GETPID frame with abort at a spec-legal position.

    Builds the GETPID directed read frame incrementally and issues the
    appropriate termination at the requested legal position.

    Abort types:
        "setup_broadcast": STOP after broadcast 7E/W + ACK
        "setup_ccc":       STOP after CCC byte + T-bit
        "data":            Raw STOP after *param* complete data bytes
                           (suitable for OD sim target, not for DUT PP)
        "data_sr":         Repeated START + STOP after *param* complete
                           data bytes.  Per Section 5.1.2.3.4, Sr is the
                           spec-defined way to terminate a read at a T-bit
                           boundary.  Sr avoids PP contention because the
                           controller drives SDA HIGH first (safe in
                           wired-AND), unlike STOP which drives SDA LOW
                           first (contention when DUT drives HIGH).

    Args:
        ctrl:       I3C controller handle.
        addr:       Target address for the directed read.
        abort_type: One of the types listed above.
        param:      For "data"/"data_sr": number of complete data bytes
                    to clock before abort (1..5 = after that many
                    byte+T-bit groups).  Ignored for setup types.

    Returns:
        True if the directed address phase was reached and ACKed,
        False if the directed address was NACKed,
        None if the abort was in a setup phase (no directed ACK).
    """
    await ctrl.take_bus_control()
    await ctrl.send_start()
    await ctrl.write_addr_header(0x7E)

    if abort_type == "setup_broadcast":
        await ctrl.send_stop()
        ctrl.give_bus_control()
        return None

    await ctrl.send_byte_tbit(CCC.DIRECT.GETPID)

    if abort_type == "setup_ccc":
        await ctrl.send_stop()
        ctrl.give_bus_control()
        return None

    # "data" or "data_sr": complete the directed address, then read bytes
    await ctrl.send_start()
    ack = await ctrl.write_addr_header(addr, read=True)
    if not ack:
        await ctrl.send_stop()
        ctrl.give_bus_control()
        return False

    if abort_type == "data_sr":
        # Spec 5.1.2.3.4: Early Read Termination at T-bit boundary.
        # recv_byte_t_bit(stop=True) calls tbit_eod(request_end=True)
        # which issues Repeated START *during* the T-bit SCL HIGH
        # period -- inside the ~40ns Hi-Z window where the target has
        # released SDA per spec.  This is the defined abort mechanism.
        for _ in range(param - 1):
            await ctrl.recv_byte_t_bit(stop=False)
        await ctrl.recv_byte_t_bit(stop=True)
        await ctrl.send_stop()
    else:
        for _ in range(param):
            await ctrl.recv_byte_t_bit(stop=False)
        await ctrl.send_stop()

    ctrl.give_bus_control()
    return True



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
    data = await do_getpid(i3c_controller, sim_target_addr)
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


# =========================================================================
# Test 3: GETPID then private read -- verify _pending_ccc is cleared
# =========================================================================
@cocotb.test()
async def test_getpid_then_private_read_no_stale_ccc(dut):
    """
    Verify that a private read after a Direct CCC does NOT replay the CCC
    response. Per spec 5.1.9.2.1, Sr + 7'h7E/W ends a Direct CCC. The
    subsequent Sr + addr/R is a private read, not a directed CCC phase.

    Scenario (Gap #5 / Gap #1):
      1) Send Direct GETPID to sim target -> get 6-byte PID (correct)
      2) Send private read to sim target (S + 7'h7E/W + Sr + addr/R)
      3) Verify response is from target memory, NOT a GETPID replay

    If _pending_ccc is stale, step 2 incorrectly dispatches to the CCC
    handler and returns PID bytes instead of memory data.
    """
    sim_pid = random.randint(0, 0xFFFFFFFFFFFF)
    dut_pid_hi = random.randint(0, 0x7FFF)
    dut_pid_lo = random.randint(0, 0xFFFFFFFF)

    i3c_controller, i3c_target, tb, dut_addr, sim_target_addr, _ = await setup_env(
        dut, dut_pid_hi, dut_pid_lo, sim_pid=sim_pid
    )

    # Pre-load known data into sim target memory so private read has
    # something distinguishable from PID bytes.
    mem_data = [random.randint(0, 0xFF) for _ in range(2)]
    i3c_target._mem.write(mem_data, length=len(mem_data))
    dut._log.info(
        f"Pre-loaded sim target memory: {['0x%02X' % b for b in mem_data]}"
    )

    # --- Step 1: Direct GETPID to sim target ---
    dut._log.info("=== Step 1: Direct GETPID to sim target ===")
    pid_data = await do_getpid(i3c_controller, sim_target_addr)
    verify_sim_pid(dut, pid_data, sim_pid)
    dut._log.info(f"GETPID OK: PID=0x{sim_pid:012X}")

    # --- Step 2: Private read to sim target ---
    # i3c_read sends: S + 7'h7E/W + Sr + addr/R + [data] + P
    # The S + 7'h7E/W portion ends the previous Direct CCC context.
    # The Sr + addr/R is a private read -- NOT a CCC directed phase.
    dut._log.info("=== Step 2: Private read to sim target ===")
    resp = await i3c_controller.i3c_read(
        addr=sim_target_addr, count=len(mem_data)
    )
    await ClockCycles(tb.clk, 50)

    assert not resp.nack, (
        f"Sim target at 0x{sim_target_addr:02X} should ACK private read"
    )

    read_data = list(resp.data)
    dut._log.info(
        f"Private read data: {['0x%02X' % b for b in read_data]}"
    )

    # The key assertion: private read must return memory data, not PID.
    # If _pending_ccc was stale, the sim target would have sent PID bytes.
    pid_bytes = [(sim_pid >> (40 - 8 * i)) & 0xFF for i in range(6)]
    assert read_data == mem_data, (
        f"Private read returned wrong data: got {read_data}, "
        f"expected memory {mem_data}. "
        f"If got PID prefix {pid_bytes[:len(mem_data)]}, "
        f"_pending_ccc was stale (Gap #5 bug)."
    )

    await tb.teardown()


# =========================================================================
# Test 4: CCC broadcast with no directed phases (Gap #2)
# =========================================================================
@cocotb.test()
async def test_ccc_broadcast_no_directed_phase(dut):
    """
    Verify that sending a directed CCC broadcast with no directed phases
    (STOP immediately after the CCC code) does not leave the DUT or sim
    target in a broken state. A normal CCC afterward should succeed.

    Per spec 5.1.9.2.1, a CCC frame may end with STOP after the Command.

    Scenario (Gap #2):
      1) Send S + 7'h7E/W + GETPID + P (no directed phases)
      2) Send normal GETPID to both DUT and sim target
      3) Verify both respond correctly
    """
    sim_pid = random.randint(0, 0xFFFFFFFFFFFF)
    dut_pid_hi = random.randint(0, 0x7FFF)
    dut_pid_lo = random.randint(0, 0xFFFFFFFF)

    i3c_controller, i3c_target, tb, dut_addr, sim_target_addr, _ = await setup_env(
        dut, dut_pid_hi, dut_pid_lo, sim_pid=sim_pid
    )

    # --- Step 1: CCC broadcast with no directed phases ---
    dut._log.info("=== Step 1: GETPID broadcast-only (no directed phase) ===")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID, addr=[], count=6
    )
    await ClockCycles(tb.clk, 50)
    assert len(responses) == 0, (
        f"Expected 0 responses for empty addr list, got {len(responses)}"
    )

    # --- Step 2: Normal GETPID to both targets ---
    dut._log.info("=== Step 2: Normal GETPID to verify recovery ===")
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
    dut._log.info("Both targets responded correctly after broadcast-only CCC")

    await tb.teardown()


# =========================================================================
# Test 5: CCC chaining -- two CCCs in one frame (Gap #7 / Gap #7b)
# =========================================================================
@cocotb.test()
async def test_ccc_chain_two_cccs_in_one_frame(dut):
    """
    Verify CCC chaining via Sr+7'h7E/W in two phases:

    Phase A (Gap #7): Both CCCs directed at the sim target.
      GETPID -> Sr+7'h7E/W -> GETBCR, both to sim target.
      Verify PID then BCR.

    Phase B (Gap #7b): First CCC to DUT, second to sim target.
      GETPID to DUT -> Sr+7'h7E/W -> GETBCR to sim target.
      Exercises _pending_ccc update when sim target sees the broadcast
      but is not addressed in the first directed phase.

    Spec: 5.1.9.2.1 -- Sr + 7'h7E/W ends a Direct CCC and starts a new one.
    """
    sim_pid = random.randint(0, 0xFFFFFFFFFFFF)
    sim_bcr = random.randint(0, 0xFF)
    dut_pid_hi = random.randint(0, 0x7FFF)
    dut_pid_lo = random.randint(0, 0xFFFFFFFF)

    i3c_controller, i3c_target, tb, dut_addr, sim_target_addr, _ = await setup_env(
        dut, dut_pid_hi, dut_pid_lo, sim_pid=sim_pid, sim_bcr=sim_bcr
    )

    # --- Phase A: Both CCCs to sim target ---
    dut._log.info(
        f"=== Phase A: GETPID + GETBCR both to sim "
        f"(0x{sim_target_addr:02X}) ==="
    )
    responses_a = await i3c_controller.i3c_ccc_read_chained([
        (CCC.DIRECT.GETPID, sim_target_addr, 6),
        (CCC.DIRECT.GETBCR, sim_target_addr, 1),
    ])

    (ack1, pid_data) = responses_a[0]
    assert ack1, "Sim target should ACK GETPID"
    verify_sim_pid(dut, pid_data, sim_pid)

    (ack2, bcr_data_a) = responses_a[1]
    assert ack2, "Sim target should ACK GETBCR"
    assert bcr_data_a[0] == sim_bcr, (
        f"Phase A GETBCR mismatch: exp 0x{sim_bcr:02X}, "
        f"got 0x{bcr_data_a[0]:02X}"
    )
    dut._log.info(
        f"Phase A OK: PID=0x{sim_pid:012X}, BCR=0x{sim_bcr:02X}"
    )

    # --- Phase B: GETPID to DUT, then GETBCR to sim ---
    dut._log.info(
        f"=== Phase B: GETPID to DUT (0x{dut_addr:02X}), "
        f"GETBCR to sim (0x{sim_target_addr:02X}) ==="
    )
    responses_b = await i3c_controller.i3c_ccc_read_chained([
        (CCC.DIRECT.GETPID, dut_addr, 6),
        (CCC.DIRECT.GETBCR, sim_target_addr, 1),
    ])

    (ack3, dut_pid_data) = responses_b[0]
    assert ack3, "DUT should ACK GETPID"
    verify_dut_pid(dut, dut_pid_data, dut_pid_hi, dut_pid_lo)

    (ack4, bcr_data_b) = responses_b[1]
    assert ack4, "Sim target should ACK GETBCR"
    assert bcr_data_b[0] == sim_bcr, (
        f"Phase B GETBCR mismatch: exp 0x{sim_bcr:02X}, "
        f"got 0x{bcr_data_b[0]:02X}"
    )
    dut._log.info(
        f"Phase B OK: DUT PID verified, Sim BCR=0x{sim_bcr:02X}"
    )

    await tb.teardown()


# =========================================================================
# Test 6: Premature STOP at spec-legal positions during GETPID (DUT)
# =========================================================================
@cocotb.test()
async def test_getpid_mid_byte_abort_dut_recovery(dut):
    """STOP at spec-legal positions within a GETPID directed read to the DUT.

    Per Section 5.1.2 (lines 3202-3210), STOP is "tolerated" when the
    Controller controls SDA or SDA is Open-Drain.

    This test exercises DUT-safe abort positions:
      - setup_broadcast: STOP after broadcast 7E/W + ACK (ctrl OD)
      - setup_ccc:       STOP after CCC byte + T-bit (ctrl PP)
      - data_sr N:       Sr + STOP after N complete byte+T-bit groups

    Data-phase T-bit boundaries use Repeated START (Sr) followed by STOP,
    per the spec-defined read early termination mechanism (Section
    5.1.2.3.4).  Sr avoids PP contention because the controller drives
    SDA HIGH first (safe in wired-AND), unlike a raw STOP which drives
    SDA LOW first and contends when the DUT drives HIGH.

    Each position is tested once, then the remaining iterations (up to
    NUM_STOP_ITERATIONS) pick random legal positions for extra coverage.
    Recovery is verified with GETPID to both sim target and DUT.
    """
    sim_pid = random.randint(0, 0xFFFFFFFFFFFF)
    dut_pid_hi = random.randint(0, 0x7FFF)
    dut_pid_lo = random.randint(0, 0xFFFFFFFF)

    i3c_controller, i3c_target, tb, dut_addr, sim_target_addr, _ = await setup_env(
        dut, dut_pid_hi, dut_pid_lo, sim_pid=sim_pid
    )

    expected_dut_pid = (dut_pid_hi << 33) | dut_pid_lo
    expected_sim_pid = sim_pid

    # Build iteration schedule: cover all DUT-safe positions, then extras.
    # Setup phases use raw STOP; data-phase T-bit boundaries use Sr+STOP
    # per spec Section 5.1.2.3.4 (avoids PP contention).
    positions = list(LEGAL_ABORT_POSITIONS_DUT)
    n_extra = max(0, NUM_STOP_ITERATIONS - len(positions))
    for _ in range(n_extra):
        positions.append(random.choice(LEGAL_ABORT_POSITIONS_DUT))

    for i, (abort_type, param, desc) in enumerate(positions):
        cocotb.log.info(
            f"--- Iteration {i}: DUT abort [{abort_type}] {desc} ---"
        )

        # Baseline GETPID to DUT before each abort
        data = await do_getpid(i3c_controller, dut_addr)
        pid_48 = int.from_bytes(data[0:6], byteorder="big", signed=False)
        assert pid_48 == expected_dut_pid, (
            f"Iteration {i} baseline GETPID failed: "
            f"got 0x{pid_48:012X}, expected 0x{expected_dut_pid:012X}"
        )

        # Execute the abort at the legal position
        result = await abort_getpid_at_legal_position(
            i3c_controller, dut_addr, abort_type, param
        )

        if abort_type in ("data", "data_sr"):
            assert result is True, (
                f"Iteration {i}: DUT NACKed directed GETPID"
            )

        # Recovery: wait, then verify both targets respond correctly
        RECOVERY_SCL_PERIODS = 50
        MIN_RECOVERY_NS = 10_000
        scl_period_ns = int(1e9 / i3c_controller.speed)
        recovery_ns = max(MIN_RECOVERY_NS,
                          RECOVERY_SCL_PERIODS * scl_period_ns)
        await Timer(recovery_ns, units='ns')

        sim_data = await do_getpid(i3c_controller, sim_target_addr)
        sim_pid_val = int.from_bytes(sim_data[0:6], byteorder="big",
                                     signed=False)
        assert sim_pid_val == expected_sim_pid, (
            f"Iteration {i} sim target recovery GETPID mismatch: "
            f"got 0x{sim_pid_val:012X}, expected 0x{expected_sim_pid:012X}"
        )

        dut_data = await do_getpid(i3c_controller, dut_addr)
        dut_pid_val = int.from_bytes(dut_data[0:6], byteorder="big",
                                     signed=False)
        assert dut_pid_val == expected_dut_pid, (
            f"Iteration {i} DUT recovery GETPID mismatch: "
            f"got 0x{dut_pid_val:012X}, expected 0x{expected_dut_pid:012X}"
        )

        cocotb.log.info(f"--- Iteration {i}: PASSED ---")

    await tb.teardown()


# =========================================================================
# Test 7: Unsupported ENTHDR entry from SDR mode
# =========================================================================
@cocotb.test()
async def test_sim_target_unsupported_enthdr_from_sdr(dut):
    """
    Verify sim target and DUT handle an unsupported ENTHDR variant from SDR
    mode without hanging or corrupting state.

    A random unsupported ENTHDR (1/2/4/5/6/7) is selected each run; more
    seeds cover all variants. The target must set hdr_mode=True, wait for
    HDR exit, and cleanly return to SDR.

    Flow:
      1. Send randomly chosen unsupported ENTHDRx broadcast from SDR mode
      2. Send HDR exit pattern
      3. Verify sim target still ACKs GETBCR
      4. Verify DUT still ACKs GETPID
    """
    dut_pid_hi = random.getrandbits(15)
    dut_pid_lo = random.getrandbits(32)
    sim_pid = random.getrandbits(48)
    sim_bcr = random.randint(0, 0xFF)

    i3c_controller, i3c_target, tb, dut_addr, sim_target_addr, _ = await setup_env(
        dut, dut_pid_hi, dut_pid_lo, sim_pid=sim_pid, sim_bcr=sim_bcr,
    )

    # Unsupported ENTHDR variants: everything except ENTHDR0 and ENTHDR3
    # which have explicit DDR/BT handlers.
    unsupported_enthdr = [
        CCC.BCAST.ENTHDR1, CCC.BCAST.ENTHDR2,
        CCC.BCAST.ENTHDR4, CCC.BCAST.ENTHDR5,
        CCC.BCAST.ENTHDR6, CCC.BCAST.ENTHDR7,
    ]

    hdr_code = random.choice(unsupported_enthdr)
    dut._log.info(
        f"=== Testing unsupported ENTHDR 0x{hdr_code:02X} from SDR mode ==="
    )

    await i3c_controller.i3c_ccc_write(
        ccc=hdr_code, broadcast_data=[], stop=False, pull_scl_low=True,
    )

    await i3c_controller.send_hdr_exit()

    # Verify sim target recovery
    bcr_data = await do_getbcr(i3c_controller, sim_target_addr)
    assert bcr_data[0] == sim_bcr, (
        f"After ENTHDR 0x{hdr_code:02X}: sim target BCR mismatch: "
        f"expected 0x{sim_bcr:02X}, got 0x{bcr_data[0]:02X}"
    )

    # Verify DUT recovery
    pid_data = await do_getpid(i3c_controller, dut_addr)
    verify_dut_pid(dut, pid_data, dut_pid_hi, dut_pid_lo)

    dut._log.info(
        f"Both targets recovered after unsupported ENTHDR 0x{hdr_code:02X}"
    )

    await tb.teardown()


# =========================================================================
# Test 8: ENTHDR0 re-entry after HDR exit
# =========================================================================
@cocotb.test()
async def test_sim_target_enthdr0_then_reentry_after_exit(dut):
    """
    Verify sim target and DUT correctly re-enter SDR after ENTHDR0 + HDR
    exit, then handle another ENTHDR cycle without state corruption.

    Validates that hdr_mode is properly cleared on HDR exit and that the
    prohibited-CCC check does not spuriously block a fresh ENTHDR entry
    from SDR mode.

    Flow:
      1. ENTHDR0 (enter HDR-DDR) -> HDR exit -> verify both targets
      2. ENTHDR0 again -> HDR exit -> verify both targets
      3. Unsupported ENTHDR1 -> HDR exit -> verify both targets
    """
    dut_pid_hi = random.getrandbits(15)
    dut_pid_lo = random.getrandbits(32)
    sim_pid = random.getrandbits(48)
    sim_bcr = random.randint(0, 0xFF)

    i3c_controller, i3c_target, tb, dut_addr, sim_target_addr, _ = await setup_env(
        dut, dut_pid_hi, dut_pid_lo, sim_pid=sim_pid, sim_bcr=sim_bcr,
    )

    phases = [
        ("ENTHDR0 first",       CCC.BCAST.ENTHDR0),
        ("ENTHDR0 second",      CCC.BCAST.ENTHDR0),
        ("ENTHDR1 unsupported", CCC.BCAST.ENTHDR1),
    ]

    for phase_name, hdr_code in phases:
        dut._log.info(f"=== Phase: {phase_name} (0x{hdr_code:02X}) ===")

        await i3c_controller.i3c_ccc_write(
            ccc=hdr_code, broadcast_data=[], stop=False, pull_scl_low=True,
        )

        await i3c_controller.send_hdr_exit()

        # Verify sim target is back in SDR and responsive
        bcr_data = await do_getbcr(i3c_controller, sim_target_addr)
        assert bcr_data[0] == sim_bcr, (
            f"Phase '{phase_name}': sim target BCR mismatch: "
            f"expected 0x{sim_bcr:02X}, got 0x{bcr_data[0]:02X}"
        )

        # Verify DUT is back in SDR and responsive
        pid_data = await do_getpid(i3c_controller, dut_addr)
        verify_dut_pid(dut, pid_data, dut_pid_hi, dut_pid_lo)

        dut._log.info(f"Phase '{phase_name}': both targets recovered OK")

    await tb.teardown()


# =========================================================================
# Test 9: Premature STOP at spec-legal positions during GETPID (sim target)
# =========================================================================
@cocotb.test()
async def test_getpid_premature_stop(dut):
    """STOP at spec-legal positions within a GETPID directed read to sim target.

    Per Section 5.1.2 (lines 3202-3210), STOP is "tolerated" when the
    Controller controls SDA or SDA is Open-Drain.  Section 5.1.2.3.4
    defines early read termination at T-bit boundaries.

    This test exercises all legal abort positions targeting the sim target:
      - setup_broadcast: STOP after broadcast 7E/W + ACK (ctrl OD)
      - setup_ccc:       STOP after CCC byte + T-bit (ctrl PP)
      - data byte 0:     STOP right after directed ACK (OD boundary)
      - data byte N:     STOP after N complete byte+T-bit groups

    Each position is tested once, then the remaining iterations (up to
    NUM_STOP_ITERATIONS) pick random legal positions for extra coverage.
    Recovery is verified with GETPID to both sim target and DUT.

    Without the send_bit/send_byte overrides in I3CTargetFixed, the sim
    target hangs because the base class awaits FallingEdge(scl_i) which
    never arrives after STOP.
    """
    dut_pid_hi = random.getrandbits(15)
    dut_pid_lo = random.getrandbits(32)
    sim_pid = random.getrandbits(48)

    # Use a shorter SDA read timer (5us) so abort recovery stays brief.
    # This test exercises abort/recovery behavior, not timer duration.
    i3c_controller, i3c_target, tb, dut_addr, sim_target_addr, _ = await setup_env(
        dut, dut_pid_hi, dut_pid_lo, sim_pid=sim_pid,
        sda_read_timeout_us=5,
    )

    expected_dut_pid = (dut_pid_hi << 33) | dut_pid_lo
    expected_sim_pid = sim_pid

    # Build iteration schedule: cover all positions, then random extras.
    # Sim target uses OD, so all positions including data-phase are safe.
    positions = list(LEGAL_ABORT_POSITIONS_ALL)
    n_extra = max(0, NUM_STOP_ITERATIONS - len(positions))
    for _ in range(n_extra):
        positions.append(random.choice(LEGAL_ABORT_POSITIONS_ALL))

    for i, (abort_type, param, desc) in enumerate(positions):
        cocotb.log.info(
            f"--- Iteration {i}: sim abort [{abort_type}] {desc} ---"
        )

        # Baseline GETPID to sim target before each abort
        data = await do_getpid(i3c_controller, sim_target_addr)
        pid_48 = int.from_bytes(data[0:6], byteorder="big", signed=False)
        assert pid_48 == expected_sim_pid, (
            f"Iteration {i} baseline GETPID failed: "
            f"got 0x{pid_48:012X}, expected 0x{expected_sim_pid:012X}"
        )

        # Execute the abort at the legal position
        result = await abort_getpid_at_legal_position(
            i3c_controller, sim_target_addr, abort_type, param
        )

        if abort_type in ("data", "data_sr"):
            assert result is True, (
                f"Iteration {i}: sim target NACKed directed GETPID"
            )

        # Recovery: wait, then verify both targets respond correctly
        RECOVERY_SCL_PERIODS = 50
        MIN_RECOVERY_NS = 10_000
        scl_period_ns = int(1e9 / i3c_controller.speed)
        recovery_ns = max(MIN_RECOVERY_NS,
                          RECOVERY_SCL_PERIODS * scl_period_ns)
        await Timer(recovery_ns, units='ns')

        sim_data = await do_getpid(i3c_controller, sim_target_addr)
        sim_pid_val = int.from_bytes(sim_data[0:6], byteorder="big",
                                     signed=False)
        assert sim_pid_val == expected_sim_pid, (
            f"Iteration {i} sim target recovery GETPID mismatch: "
            f"got 0x{sim_pid_val:012X}, expected 0x{expected_sim_pid:012X}"
        )

        dut_data = await do_getpid(i3c_controller, dut_addr)
        dut_pid_val = int.from_bytes(dut_data[0:6], byteorder="big",
                                     signed=False)
        assert dut_pid_val == expected_dut_pid, (
            f"Iteration {i} DUT recovery GETPID mismatch: "
            f"got 0x{dut_pid_val:012X}, expected 0x{expected_dut_pid:012X}"
        )

        cocotb.log.info(f"--- Iteration {i}: PASSED ---")

    await tb.teardown()

# =========================================================================
# Test 10: Duplicate address in multi-target directed CCC frame
# =========================================================================
@cocotb.test()
async def test_getpid_duplicate_address_multi_target(dut):
    """
    Issue directed GETPID with the same target address appearing twice
    in a single multi-target CCC frame. The target must respond correctly
    both times, returning identical PID data.

    Two sub-tests:
      A) DUT address repeated:   addr=[dut, dut]
      B) Sim target address repeated: addr=[sim, sim]

    This exercises the target's ability to re-enter the directed CCC
    read phase for the same address after responding once and seeing
    a Repeated START instead of a STOP.

    Spec: Section 5.1.9.3.12 -- directed CCC may address any combination
    of targets; the spec does not prohibit addressing the same target
    multiple times.
    """
    sim_pid = random.randint(0, 0xFFFFFFFFFFFF)
    dut_pid_hi = random.randint(0, 0x7FFF)
    dut_pid_lo = random.randint(0, 0xFFFFFFFF)

    i3c_controller, i3c_target, tb, dut_addr, sim_target_addr, _ = await setup_env(
        dut, dut_pid_hi, dut_pid_lo, sim_pid=sim_pid
    )

    # --- Phase A: DUT address repeated twice in one frame ---
    dut._log.info("=== Phase A: GETPID with DUT addr repeated ===")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID,
        addr=[dut_addr, dut_addr],
        count=6,
    )
    await ClockCycles(tb.clk, 50)

    assert len(responses) == 2, f"Expected 2 responses, got {len(responses)}"
    for idx, (ack, data) in enumerate(responses):
        assert ack, f"Phase A: DUT NACK on occurrence {idx}"
        verify_dut_pid(dut, data, dut_pid_hi, dut_pid_lo)
        dut._log.info(f"Phase A occurrence {idx}: DUT PID OK")

    # --- Phase B: Sim target address repeated twice in one frame ---
    dut._log.info("=== Phase B: GETPID with sim target addr repeated ===")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID,
        addr=[sim_target_addr, sim_target_addr],
        count=6,
    )
    await ClockCycles(tb.clk, 50)

    assert len(responses) == 2, f"Expected 2 responses, got {len(responses)}"
    for idx, (ack, data) in enumerate(responses):
        assert ack, f"Phase B: sim target NACK on occurrence {idx}"
        verify_sim_pid(dut, data, sim_pid)
        dut._log.info(f"Phase B occurrence {idx}: sim PID OK")

    # Sanity: single-target reads still work after duplicate-addr frames
    dut._log.info("=== Sanity: single-target reads after duplicate frames ===")
    data = await do_getpid(i3c_controller, dut_addr)
    verify_dut_pid(dut, data, dut_pid_hi, dut_pid_lo)

    data = await do_getpid(i3c_controller, sim_target_addr)
    verify_sim_pid(dut, data, sim_pid)

    await tb.teardown()
