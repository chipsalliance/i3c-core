# SPDX-License-Identifier: Apache-2.0
"""
Feature-grouped CCC tests for the I3CTargetFixed sim model.

Tests are organized by **scenario / feature** rather than per-CCC. Each
test randomizes the CCC under test (via the `SUPPORTED_CCCS` table in
`ccc_descriptors.py`) so that all supported CCCs are exercised in every
scenario across multiple seeds.

Scenarios (generalized -- pick a random CCC per seed):
  1. test_ccc_single_target           -- single-target read/write/bcast
  2. test_ccc_multi_target_ordering   -- DUT + sim, both orderings
  3. test_ccc_with_nack_targets       -- random NACK targets interleaved
  4. test_ccc_chained                 -- multiple CCCs in one frame
  5. test_ccc_runtime_update          -- read, mutate, re-read
  6. test_ccc_back_to_back_sequence   -- shuffled run of all reads
  7. test_ccc_then_private_read       -- no stale CCC after directed read
  8. test_ccc_broadcast_only_recovery -- broadcast w/o directed phase
  9. test_ccc_post_read_self_clear    -- GETSTATUS protocol-error self-clear

Bus-level frame-structure tests (CCC randomized where natural):
 10. test_ccc_abort_recovery_random         -- random scenario (single /
                                               multi-target / chained) ×
                                               target (sim / DUT) × abort
                                               position; DUT-safe positions
                                               only (Section 5.1.2.3.4)
 11. test_ccc_duplicate_address_multi_target -- same addr twice in frame
 12. test_ccc_unsupported_enthdr_from_sdr   -- HDR mode recovery
 13. test_ccc_enthdr0_then_reentry_after_exit

Spec references:
  - Section 5.1.9.2.1: Direct CCC framing (Sr+7E/W ends a Direct CCC)
  - Section 5.1.9.3.5: SETMWL/GETMWL
  - Section 5.1.9.3.6: SETMRL/GETMRL
  - Section 5.1.9.3.12: GETPID
  - Section 5.1.9.3.13: GETBCR
  - Section 5.1.9.3.14: GETDCR
  - Section 5.1.9.3.15: GETSTATUS (self-clear of bit[5])
  - Section 5.1.9.3.18: GETMXDS
  - Section 5.1.9.3.19: GETCAPS
  - Section 5.1.2.3.4: Early read termination at T-bit boundary
  - Figure 47: GETPID multi-target with Repeated START
"""

import logging
import random

from boot import boot_init
from ccc import CCC
from ccc_descriptors import (
    SUPPORTED_CCCS,
    READ_CCCS,
    WRITE_CCCS,
    BCAST_CCCS,
    do_ccc_read,
    do_ccc_read_multi,
    do_ccc_read_verify,
    do_ccc_write,
    do_ccc_bcast,
    descriptor_count,
    setup_descriptor_state,
    log_ccc_pick,
    pick_random_ccc,
    legal_abort_positions,
    abort_ccc_at_legal_position,
    abort_multi_target_at_position,
    abort_chained_at_position,
    recovery_wait,
    verify_set_via_get,
)
from i3c_controller_fixed import I3cControllerFixed as I3cController
from i3c_target_fixed import I3CTargetFixed as I3CTarget
from interface import I3CTopTestInterface

import cocotb

from common import (
    VALID_I3C_ADDRESSES, SIM_TARGET_ADDR, pick_random_addr, log_seed,
)


# =========================================================================
# Environment setup -- reused across all tests
# =========================================================================

async def setup_env(dut, *, dut_pid_hi=None, dut_pid_lo=None, sim_pid=None,
                    speed=None, sda_read_timeout_us=100):
    """Set up controller, sim target, DUT, and randomize identities.

    Returns (i3c_controller, i3c_target, tb, dut_addr, sim_target_addr,
             virt_addr, dut_pid_hi, dut_pid_lo).

    Per-CCC backing state on the sim target is randomized by each test via
    the descriptor's `setup()` callback, not here. This helper only wires
    up the bus and assigns dynamic addresses + DUT PID.
    """
    cocotb.log.setLevel(logging.DEBUG)
    log_seed(dut)

    if dut_pid_hi is None:
        dut_pid_hi = random.randint(0, 0x7FFF)
    if dut_pid_lo is None:
        dut_pid_lo = random.randint(0, 0xFFFFFFFF)
    if sim_pid is None:
        sim_pid = random.randint(0, 0xFFFFFFFFFFFF)
    sim_target_addr = SIM_TARGET_ADDR

    if speed is None:
        speed = random.uniform(1e6, 12.5e6)
    dut._log.info(
        f"Sim target address: 0x{sim_target_addr:02X}, "
        f"bus speed: {speed / 1e6:.2f} MHz"
    )

    i3c_controller = I3cController(
        sda_i=dut.bus_sda, sda_o=dut.sda_sim_ctrl_i,
        scl_i=dut.bus_scl, scl_o=dut.scl_sim_ctrl_i,
        debug_state_o=None, speed=speed,
    )

    i3c_target = I3CTarget(
        sda_i=dut.bus_sda, sda_o=dut.sda_sim_target_i,
        scl_i=dut.bus_scl, scl_o=dut.scl_sim_target_i,
        debug_state_o=None, speed=speed,
        address=sim_target_addr,
        pid=sim_pid,
        sda_read_timeout_us=sda_read_timeout_us,
    )

    dut.peripheral_reset_done_i.value = 0

    tb = I3CTopTestInterface(dut)
    await tb.setup()

    dut_addr = pick_random_addr(exclude=(sim_target_addr,))
    virt_addr = pick_random_addr(exclude=(sim_target_addr, dut_addr))
    await boot_init(tb, static_addr=dut_addr, virtual_static_addr=virt_addr)

    # Configure DUT PID via CSRs.
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

    return (i3c_controller, i3c_target, tb, dut_addr, sim_target_addr,
            virt_addr, dut_pid_hi, dut_pid_lo)

# =========================================================================
# 1. Single-target CCC -- random read/write/bcast
# =========================================================================
@cocotb.test()
async def test_ccc_single_target(dut):
    """Random directed read, directed write, and broadcast write to sim target.

    For each kind we pick a random CCC from the descriptor table, set up
    target state, and verify protocol behavior:
      - Read:  ACK + value matches target state.
      - Write: ACK; for SETs we re-read via the matching GET to confirm
               the side-effect was applied.
      - Bcast: completes without error; for SET-bcasts we re-read via the
               matching GET to confirm the side-effect.
    """
    (i3c_controller, i3c_target, tb, dut_addr, sim_addr,
     _, _, _) = await setup_env(dut)

    # ----- Read -----
    rdesc = pick_random_ccc(kinds=["read"])
    log_ccc_pick(dut, "Read phase", rdesc)
    setup_descriptor_state(rdesc, i3c_target)
    await do_ccc_read_verify(i3c_controller, rdesc, sim_addr, i3c_target)

    # ----- Directed write -----
    wdesc = pick_random_ccc(kinds=["write"])
    log_ccc_pick(dut, "Directed write phase", wdesc)
    ok = await do_ccc_write(i3c_controller, wdesc, sim_addr, i3c_target)
    assert ok, f"{wdesc.name} should ACK at 0x{sim_addr:02X}"
    await verify_set_via_get(dut, i3c_controller, i3c_target, wdesc, sim_addr)

    # ----- Broadcast write -----
    bdesc = pick_random_ccc(kinds=["bcast_write"])
    log_ccc_pick(dut, "Broadcast phase", bdesc)
    await do_ccc_bcast(i3c_controller, bdesc, i3c_target)
    await verify_set_via_get(dut, i3c_controller, i3c_target, bdesc, sim_addr)

    await tb.teardown()


# =========================================================================
# 2. Multi-target ordering -- DUT + sim, both orderings
# =========================================================================
@cocotb.test()
async def test_ccc_multi_target_ordering(dut):
    """Random `dut_supported` read CCC sent to DUT+sim in both orderings.

    DUT is checked only for ACK + non-empty response (we do not configure
    DUT BCR/DCR/etc., so we can only value-verify GETPID for the DUT).
    Sim target response is fully verified via `desc.verify`.
    """
    (i3c_controller, i3c_target, tb, dut_addr, sim_addr,
     _, dut_pid_hi, dut_pid_lo) = await setup_env(dut)

    desc = pick_random_ccc(kinds=["read"], predicate=lambda d: d.dut_supported)
    log_ccc_pick(dut, "Multi-target", desc)
    setup_descriptor_state(desc, i3c_target)
    count = descriptor_count(desc, i3c_target)

    for label, addr_list in [
        ("Phase A: sim only",          [sim_addr]),
        ("Phase B: DUT then sim",      [dut_addr, sim_addr]),
        ("Phase C: sim then DUT",      [sim_addr, dut_addr]),
    ]:
        dut._log.info(f"--- {label} ---")
        responses = await do_ccc_read_multi(
            i3c_controller, desc, addr_list, i3c_target, count=count
        )
        assert len(responses) == len(addr_list), (
            f"{label}: expected {len(addr_list)} responses, got {len(responses)}"
        )
        for addr, (ack, data) in zip(addr_list, responses):
            assert ack, f"{label}: NACK from 0x{addr:02X}"
            if addr == sim_addr:
                desc.verify(i3c_target, data)
            else:
                # DUT response: only check that we got the expected count.
                # (DUT-specific verification for GETPID is below.)
                assert len(data) >= count, (
                    f"{label}: DUT returned {len(data)} bytes, expected {count}"
                )
                if desc.name == "GETPID":
                    expected_dut_pid = (dut_pid_hi << 33) | dut_pid_lo
                    pid_rx = int.from_bytes(data[0:6], byteorder="big")
                    assert pid_rx == expected_dut_pid, (
                        f"DUT GETPID: exp 0x{expected_dut_pid:012X} "
                        f"got 0x{pid_rx:012X}"
                    )

        # Re-run post_read_check after each phase if applicable, since the
        # sim target may have self-cleared state on each read.
        if desc.has_post_read_check and desc.post_read_check is not None:
            desc.post_read_check(i3c_target)

    await tb.teardown()


# =========================================================================
# 3. NACK targets interleaved with valid sim
# =========================================================================
@cocotb.test()
async def test_ccc_with_nack_targets(dut):
    """Random read CCC with 1-5 dummy NACK addrs interleaved with sim target.

    Verifies the sim target maintains its CCC-pending state across an
    arbitrary number of NACKed positions in the directed phase.
    """
    (i3c_controller, i3c_target, tb, dut_addr, sim_addr,
     virt_addr, _, _) = await setup_env(dut)

    desc = pick_random_ccc(kinds=["read"])
    log_ccc_pick(dut, "NACK targets", desc)
    setup_descriptor_state(desc, i3c_target)
    count = descriptor_count(desc, i3c_target)

    excluded = {dut_addr, sim_addr, virt_addr}
    available = [a for a in VALID_I3C_ADDRESSES if a not in excluded]
    num_dummies = random.randint(1, 5)
    dummies = random.sample(available, num_dummies)

    addr_list = dummies + [sim_addr]
    random.shuffle(addr_list)
    dut._log.info(
        f"Address order: {['0x%02X' % a for a in addr_list]} "
        f"(sim=0x{sim_addr:02X}, dummies={['0x%02X' % a for a in dummies]})"
    )

    responses = await do_ccc_read_multi(
        i3c_controller, desc, addr_list, i3c_target, count=count
    )
    assert len(responses) == len(addr_list), (
        f"Expected {len(addr_list)} responses, got {len(responses)}"
    )

    for addr, (ack, data) in zip(addr_list, responses):
        if addr == sim_addr:
            assert ack, f"Sim target 0x{addr:02X} should ACK"
            desc.verify(i3c_target, data)
        else:
            assert not ack, f"Dummy 0x{addr:02X} should NACK, got ACK"

    if desc.has_post_read_check and desc.post_read_check is not None:
        desc.post_read_check(i3c_target)

    await tb.teardown()


# =========================================================================
# 4. CCC chaining -- 2-4 CCCs in one frame via Sr+7E/W
# =========================================================================
@cocotb.test()
async def test_ccc_chained(dut):
    """Chain 2-4 random read CCCs in a single frame via Sr + 7'h7E/W.

    Each chain entry can target sim or DUT. Sim responses are value-verified;
    DUT responses are checked for ACK + length (with GETPID also verified).
    """
    (i3c_controller, i3c_target, tb, dut_addr, sim_addr,
     _, dut_pid_hi, dut_pid_lo) = await setup_env(dut)

    chain_len = random.randint(2, 4)
    dut._log.info(f"Chain length: {chain_len}")

    # Pick a fresh random CCC for each chain entry; setup all of them on
    # the sim target so concurrent state for every CCC is consistent.
    chain = []
    for _ in range(chain_len):
        desc = pick_random_ccc(kinds=["read"])
        setup_descriptor_state(desc, i3c_target)
        # Mix of sim/DUT: prefer sim, but pick DUT 1/3 of the time when
        # the descriptor is dut_supported.
        if desc.dut_supported and random.random() < 1 / 3:
            target_addr = dut_addr
        else:
            target_addr = sim_addr
        count = descriptor_count(desc, i3c_target)
        chain.append((desc, target_addr, count))

    dut._log.info("Chain: " + ", ".join(
        f"{d.name}@0x{a:02X}({c}B)" for d, a, c in chain
    ))

    request = [(d.code, a, c) for d, a, c in chain]
    responses = await i3c_controller.i3c_ccc_read_chained(request)

    assert len(responses) == chain_len, (
        f"Expected {chain_len} responses, got {len(responses)}"
    )

    for (desc, addr, count), (ack, data) in zip(chain, responses):
        assert ack, f"NACK from 0x{addr:02X} on {desc.name}"
        if addr == sim_addr:
            desc.verify(i3c_target, data)
            if desc.has_post_read_check and desc.post_read_check is not None:
                desc.post_read_check(i3c_target)
        else:
            assert len(data) >= count, (
                f"{desc.name}@0x{addr:02X}: got {len(data)} bytes, "
                f"expected {count}"
            )
            if desc.name == "GETPID":
                expected_dut_pid = (dut_pid_hi << 33) | dut_pid_lo
                pid_rx = int.from_bytes(data[0:6], byteorder="big")
                assert pid_rx == expected_dut_pid, (
                    f"DUT GETPID in chain: exp 0x{expected_dut_pid:012X} "
                    f"got 0x{pid_rx:012X}"
                )

    await tb.teardown()


# =========================================================================
# 5. Runtime update -- read, mutate target state, re-read
# =========================================================================
@cocotb.test()
async def test_ccc_runtime_update(dut):
    """Verify that runtime changes to target state are reflected in the next
    read of the same CCC.

    Picks a random read CCC that has a `mutate` hook, configures the sim
    target, reads, mutates, reads again. Verifies both reads see the
    correct (different) state.
    """
    (i3c_controller, i3c_target, tb, dut_addr, sim_addr,
     _, _, _) = await setup_env(dut)

    desc = pick_random_ccc(
        kinds=["read"], predicate=lambda d: d.mutate is not None
    )
    log_ccc_pick(dut, "Runtime update", desc)
    setup_descriptor_state(desc, i3c_target)

    dut._log.info("Initial read")
    await do_ccc_read_verify(i3c_controller, desc, sim_addr, i3c_target)

    dut._log.info(f"Mutating {desc.name} backing state")
    desc.mutate(i3c_target)

    dut._log.info("Post-mutate read")
    await do_ccc_read_verify(i3c_controller, desc, sim_addr, i3c_target)

    await tb.teardown()


# =========================================================================
# 6. Back-to-back read sequence -- shuffled run of all read CCCs
# =========================================================================
@cocotb.test()
async def test_ccc_back_to_back_sequence(dut):
    """Run all directed read CCCs back-to-back in random order.

    Verifies state isolation: each CCC must return its own configured
    value, not a stale response from a prior CCC.
    """
    (i3c_controller, i3c_target, tb, dut_addr, sim_addr,
     _, _, _) = await setup_env(dut)

    # Configure backing state for every read CCC up front.
    for desc in READ_CCCS:
        setup_descriptor_state(desc, i3c_target)

    sequence = list(READ_CCCS)
    random.shuffle(sequence)
    dut._log.info("Sequence: " + ", ".join(d.name for d in sequence))

    for desc in sequence:
        await do_ccc_read_verify(i3c_controller, desc, sim_addr, i3c_target)

    await tb.teardown()


# =========================================================================
# 7. Directed CCC then private read -- no stale CCC dispatch
# =========================================================================
@cocotb.test()
async def test_ccc_then_private_read(dut):
    """After a directed read CCC, a private read must return memory data,
    not a CCC replay (Section 5.1.9.2.1: Sr+7'h7E/W ends a Direct CCC)."""
    (i3c_controller, i3c_target, tb, dut_addr, sim_addr,
     _, _, _) = await setup_env(dut)

    desc = pick_random_ccc(kinds=["read"])
    log_ccc_pick(dut, "Then private read", desc)
    setup_descriptor_state(desc, i3c_target)

    # Pre-load distinguishable memory data for the private read.
    mem_len = 2
    mem_data = [random.randint(0, 0xFF) for _ in range(mem_len)]
    i3c_target._mem.write(mem_data, length=mem_len)
    dut._log.info(f"Memory: {['0x%02X' % b for b in mem_data]}")

    # Step 1: directed CCC.
    await do_ccc_read_verify(i3c_controller, desc, sim_addr, i3c_target)

    # Step 2: private read.  The Sr+7E/W inside i3c_read terminates any
    # prior Direct CCC context; the subsequent Sr+addr/R is private.
    resp = await i3c_controller.i3c_read(addr=sim_addr, count=mem_len)
    assert not resp.nack, f"Sim target 0x{sim_addr:02X} should ACK private read"

    read_data = list(resp.data)
    dut._log.info(f"Private read: {['0x%02X' % b for b in read_data]}")
    assert read_data == mem_data, (
        f"Private read returned wrong data: got {read_data}, "
        f"expected memory {mem_data}.  If it matches a prefix of {desc.name} "
        f"output, _pending_ccc was stale."
    )

    await tb.teardown()


# =========================================================================
# 8. Broadcast-only frame followed by recovery
# =========================================================================
@cocotb.test()
async def test_ccc_broadcast_only_recovery(dut):
    """Send a directed-CCC code with no directed phases (broadcast then STOP),
    then verify normal CCC traffic still works.

    Per spec 5.1.9.2.1 a CCC frame may end with STOP after the Command.
    """
    (i3c_controller, i3c_target, tb, dut_addr, sim_addr,
     _, _, _) = await setup_env(dut)

    # Step 1: pick a random read CCC and send it without any directed phase.
    desc1 = pick_random_ccc(kinds=["read"])
    log_ccc_pick(dut, "Broadcast-only", desc1)
    count = descriptor_count(desc1, i3c_target)
    responses = await i3c_controller.i3c_ccc_read(
        ccc=desc1.code, addr=[], count=count
    )
    assert len(responses) == 0, (
        f"Expected 0 responses for empty addr list, got {len(responses)}"
    )

    # Step 2: pick a (possibly different) random read CCC and verify
    # normal directed reads still work to the sim target.
    desc2 = pick_random_ccc(kinds=["read"])
    log_ccc_pick(dut, "Recovery", desc2)
    setup_descriptor_state(desc2, i3c_target)
    await do_ccc_read_verify(i3c_controller, desc2, sim_addr, i3c_target)

    await tb.teardown()


# =========================================================================
# 9. Post-read self-clear -- GETSTATUS protocol-error bit[5]
# =========================================================================
@cocotb.test()
async def test_ccc_post_read_self_clear(dut):
    """For CCCs whose reads have self-clearing semantics (GETSTATUS bit[5]),
    verify the bit reads 1 once and 0 on subsequent reads.

    Spec 5.1.9.3.15: protocol error self-clears after a single GETSTATUS.
    """
    (i3c_controller, i3c_target, tb, dut_addr, sim_addr,
     _, _, _) = await setup_env(dut)

    candidates = [d for d in READ_CCCS if d.has_post_read_check]
    assert candidates, "No CCC with post_read_check in SUPPORTED_CCCS"
    desc = random.choice(candidates)
    log_ccc_pick(dut, "Post-read self-clear", desc)

    # Currently only GETSTATUS hits this path; the verification logic
    # below is GETSTATUS-specific because that's the only self-clearing
    # behavior in the I3C spec we model.
    assert desc.name == "GETSTATUS", (
        f"Unexpected post-read CCC {desc.name}; extend this test if a "
        f"new self-clearing CCC is added"
    )

    # Force protocol_error=True and verify it reads 1 then self-clears.
    i3c_target.protocol_error = True
    i3c_target.vendor_status = random.randint(0, 0xFF)
    i3c_target.activity_mode = random.randint(0, 3)
    i3c_target.pending_interrupt = random.randint(0, 0xF)

    _, data = await do_ccc_read(i3c_controller, desc, sim_addr, i3c_target)
    assert (data[1] >> 5) & 0x1 == 1, "protocol_error should be set"

    _, data = await do_ccc_read(i3c_controller, desc, sim_addr, i3c_target)
    assert (data[1] >> 5) & 0x1 == 0, "protocol_error should self-clear"

    await tb.teardown()


# =========================================================================
# Bus-level frame-structure tests
# =========================================================================

# Number of abort-recovery iterations.
NUM_STOP_ITERATIONS = 5


# =========================================================================
# 10. Random abort-recovery: scenario × target × position
# =========================================================================
@cocotb.test()
async def test_ccc_abort_recovery_random(dut):
    """Random abort-and-recover stress over scenario shape, target, position.

    Each iteration randomizes:
      - scenario shape  in {single, multi_target, chained}
      - abort target    in {sim_target, dut} (DUT only for `dut_supported`)
      - abort position  drawn from `legal_abort_positions(desc, target)`,
                        which only emits DUT-safe positions:
                        setup_broadcast / setup_ccc (raw STOP) and
                        data_sr (Sr+STOP at T-bit boundary, Section 5.1.2.3.4).

    For `multi_target` and `chained`, prior CCC entries in the frame run
    cleanly; the abort is injected on the *last* entry within the same
    bus-control window.

    Recovery is verified after every iteration by:
      - a value-checked read CCC to the sim target, and
      - a value-checked GETPID to the DUT.
    """
    (i3c_controller, i3c_target, tb, dut_addr, sim_addr,
     _, dut_pid_hi, dut_pid_lo) = await setup_env(dut)

    expected_dut_pid = (dut_pid_hi << 33) | dut_pid_lo

    # Baseline GETPID to establish a clean DUT start state.
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID, addr=dut_addr, count=6
    )
    _, data = responses[0]
    pid_rx = int.from_bytes(data[0:6], byteorder="big")
    assert pid_rx == expected_dut_pid, (
        f"Baseline GETPID: exp 0x{expected_dut_pid:012X} got 0x{pid_rx:012X}"
    )

    scenario_shapes = ["single", "multi_target", "chained"]

    for i in range(NUM_STOP_ITERATIONS):
        shape = random.choice(scenario_shapes)
        target_kind = random.choice(["sim", "dut"])

        if target_kind == "dut":
            desc = pick_random_ccc(
                kinds=["read"], predicate=lambda d: d.dut_supported
            )
            abort_addr = dut_addr
        else:
            desc = pick_random_ccc(kinds=["read"])
            abort_addr = sim_addr

        setup_descriptor_state(desc, i3c_target)
        positions = legal_abort_positions(desc, i3c_target)
        abort_type, param, descn = random.choice(positions)

        cocotb.log.info(
            f"--- Iter {i}: shape={shape} target={target_kind} "
            f"ccc={desc.name} abort=[{abort_type}] {descn} ---"
        )

        if shape == "single":
            await abort_ccc_at_legal_position(
                i3c_controller, desc, abort_addr, abort_type, param
            )

        elif shape == "multi_target":
            other = sim_addr if abort_addr == dut_addr else dut_addr
            await abort_multi_target_at_position(
                i3c_controller, desc, [other],
                abort_addr, abort_type, param,
                target=i3c_target,
            )

        else:  # "chained"
            chain_len = random.randint(2, 3)
            prefix = []
            for _j in range(chain_len - 1):
                pdesc = pick_random_ccc(kinds=["read"])
                setup_descriptor_state(pdesc, i3c_target)
                if pdesc.dut_supported and random.random() < 1 / 3:
                    paddr = dut_addr
                else:
                    paddr = sim_addr
                prefix.append(
                    (pdesc, paddr, descriptor_count(pdesc, i3c_target))
                )
            await abort_chained_at_position(
                i3c_controller, prefix,
                desc, abort_addr, abort_type, param,
            )

        await recovery_wait(i3c_controller)

        # Recovery 1: sim target answers a value-verified read CCC.
        rec_desc = pick_random_ccc(kinds=["read"])
        setup_descriptor_state(rec_desc, i3c_target)
        await do_ccc_read_verify(
            i3c_controller, rec_desc, sim_addr, i3c_target
        )

        # Recovery 2: DUT GETPID is value-correct.
        responses = await i3c_controller.i3c_ccc_read(
            ccc=CCC.DIRECT.GETPID, addr=dut_addr, count=6
        )
        ack, data = responses[0]
        assert ack, f"Iter {i}: DUT NACK on recovery GETPID"
        pid_rx = int.from_bytes(data[0:6], byteorder="big")
        assert pid_rx == expected_dut_pid, (
            f"Iter {i}: recovery GETPID: exp 0x{expected_dut_pid:012X} "
            f"got 0x{pid_rx:012X}"
        )

    await tb.teardown()


# =========================================================================
# 12. Duplicate target address in multi-target frame
# =========================================================================
@cocotb.test()
async def test_ccc_duplicate_address_multi_target(dut):
    """Send a random directed read CCC with the same target address twice.

    Spec 5.1.9.3.12: directed CCC may address any combination of targets;
    repeating the same address is permitted.
    """
    (i3c_controller, i3c_target, tb, dut_addr, sim_addr,
     _, dut_pid_hi, dut_pid_lo) = await setup_env(dut)

    desc = pick_random_ccc(
        kinds=["read"], predicate=lambda d: d.dut_supported
    )
    log_ccc_pick(dut, "Duplicate address", desc)
    setup_descriptor_state(desc, i3c_target)
    count = descriptor_count(desc, i3c_target)

    # --- Phase A: DUT addr repeated (only verify ACK + length, plus
    #              GETPID-specific value if applicable) ---
    dut._log.info(f"=== Phase A: {desc.name} with DUT addr repeated ===")
    responses = await do_ccc_read_multi(
        i3c_controller, desc, [dut_addr, dut_addr], i3c_target, count=count
    )
    assert len(responses) == 2
    expected_dut_pid = (dut_pid_hi << 33) | dut_pid_lo
    for idx, (ack, data) in enumerate(responses):
        assert ack, f"Phase A: DUT NACK on occurrence {idx}"
        assert len(data) >= count, (
            f"Phase A occ {idx}: got {len(data)} bytes, expected {count}"
        )
        if desc.name == "GETPID":
            pid_rx = int.from_bytes(data[0:6], byteorder="big")
            assert pid_rx == expected_dut_pid, (
                f"Phase A occ {idx}: DUT PID mismatch"
            )

    # --- Phase B: sim addr repeated -- value-verify both occurrences ---
    dut._log.info(f"=== Phase B: {desc.name} with sim addr repeated ===")
    responses = await do_ccc_read_multi(
        i3c_controller, desc, [sim_addr, sim_addr], i3c_target, count=count
    )
    assert len(responses) == 2
    for idx, (ack, data) in enumerate(responses):
        assert ack, f"Phase B: sim NACK on occurrence {idx}"
        # NOTE: post_read_check would be triggered on each read; for
        # GETSTATUS protocol_error self-clear, occurrence 1 reads 0 even
        # if occurrence 0 read 1.  Re-running verify with the (already
        # mutated) target state is correct because the sim model also
        # cleared its bit, and our verify excludes bit[5].
        desc.verify(i3c_target, data)
        if desc.has_post_read_check and desc.post_read_check is not None:
            desc.post_read_check(i3c_target)

    # Sanity: single-target reads still work after duplicate-addr frames.
    await do_ccc_read_verify(i3c_controller, desc, sim_addr, i3c_target)

    await tb.teardown()


# =========================================================================
# 13. Unsupported ENTHDR variant from SDR mode
# =========================================================================
@cocotb.test()
async def test_ccc_unsupported_enthdr_from_sdr(dut):
    """Send a randomly-chosen unsupported ENTHDR variant, exit HDR, verify
    sim and DUT recover.

    Recovery is verified using a randomly-picked read CCC for the sim
    target (value-verified) and GETPID for the DUT.
    """
    (i3c_controller, i3c_target, tb, dut_addr, sim_addr,
     _, dut_pid_hi, dut_pid_lo) = await setup_env(dut)

    # Unsupported ENTHDRs (excluding ENTHDR0/ENTHDR3 which have explicit
    # DDR/BT handlers).
    unsupported_enthdr = [
        CCC.BCAST.ENTHDR1, CCC.BCAST.ENTHDR2,
        CCC.BCAST.ENTHDR4, CCC.BCAST.ENTHDR5,
        CCC.BCAST.ENTHDR6, CCC.BCAST.ENTHDR7,
    ]
    hdr_code = random.choice(unsupported_enthdr)
    dut._log.info(
        f"=== Unsupported ENTHDR 0x{hdr_code:02X} from SDR ==="
    )

    # Pick a random recovery CCC and configure sim target state for it.
    recovery = pick_random_ccc(kinds=["read"])
    log_ccc_pick(dut, "Recovery", recovery)
    setup_descriptor_state(recovery, i3c_target)

    await i3c_controller.i3c_ccc_write(
        ccc=hdr_code, broadcast_data=[], stop=False, pull_scl_low=True,
    )
    await i3c_controller.send_hdr_exit()

    # Sim recovery -- value-verified.
    await do_ccc_read_verify(i3c_controller, recovery, sim_addr, i3c_target)

    # DUT recovery -- GETPID value-verified.
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID, addr=dut_addr, count=6
    )
    _, data = responses[0]
    expected_dut_pid = (dut_pid_hi << 33) | dut_pid_lo
    pid_rx = int.from_bytes(data[0:6], byteorder="big")
    assert pid_rx == expected_dut_pid, (
        f"DUT recovery GETPID: exp 0x{expected_dut_pid:012X} got 0x{pid_rx:012X}"
    )

    await tb.teardown()


# =========================================================================
# 14. ENTHDR0 re-entry after HDR exit
# =========================================================================
@cocotb.test()
async def test_ccc_enthdr0_then_reentry_after_exit(dut):
    """Verify SDR re-entry after ENTHDR0 + HDR exit, then handle another
    ENTHDR cycle without state corruption.

    Recovery is verified via a randomly picked read CCC for the sim
    target plus GETPID for the DUT.
    """
    (i3c_controller, i3c_target, tb, dut_addr, sim_addr,
     _, dut_pid_hi, dut_pid_lo) = await setup_env(dut)

    recovery = pick_random_ccc(kinds=["read"])
    log_ccc_pick(dut, "Recovery", recovery)
    setup_descriptor_state(recovery, i3c_target)

    expected_dut_pid = (dut_pid_hi << 33) | dut_pid_lo

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

        # Sim recovery.
        await do_ccc_read_verify(
            i3c_controller, recovery, sim_addr, i3c_target
        )

        # DUT recovery via GETPID.
        responses = await i3c_controller.i3c_ccc_read(
            ccc=CCC.DIRECT.GETPID, addr=dut_addr, count=6
        )
        _, data = responses[0]
        pid_rx = int.from_bytes(data[0:6], byteorder="big")
        assert pid_rx == expected_dut_pid, (
            f"Phase '{phase_name}' DUT GETPID: "
            f"exp 0x{expected_dut_pid:012X} got 0x{pid_rx:012X}"
        )
        dut._log.info(f"Phase '{phase_name}': both targets recovered OK")

        # Re-randomize sim target backing state for the next phase if
        # the recovery CCC has self-clearing semantics, so the next read
        # observes a fresh value.
        if recovery.has_post_read_check:
            setup_descriptor_state(recovery, i3c_target)

    await tb.teardown()


# =========================================================================
# 15. Directed Write CCC terminated without addressing any Target
# =========================================================================
@cocotb.test()
async def test_ccc_directed_write_no_target(dut):
    """Directed write CCC terminated without addressing any Target.

    Per I3C Basic v1.1.1 Section 5.1.9.2.1: 'Although not a normal use,
    the Controller may terminate a Direct CCC Command without addressing
    any Target.' This test issues a directed write CCC code (optionally
    followed by its defining byte) and immediately STOPs, skipping the
    directed phase entirely (driven by passing an empty `directed_data`
    list to `i3c_ccc_write`). Recovery is verified by issuing normal
    CCC reads to both sim target and DUT.

    Note: STOP mid-data on a CCC Write is *not* exercised here -- the
    spec classifies that as 'invalid premature termination' (5.1.9.2.1)
    with implementation-defined Target behavior, and the Write T-bit is
    parity only (5.1.2.3.3), so there is no spec-defined data-phase
    abort handshake analogous to the Read case (5.1.2.3.4).
    """
    (i3c_controller, i3c_target, tb, dut_addr, sim_addr,
     _, dut_pid_hi, dut_pid_lo) = await setup_env(dut)

    desc = pick_random_ccc(kinds=["write"])
    log_ccc_pick(dut, "Directed write no-target", desc)
    defining_byte, _ = desc.gen_data(i3c_target)

    # Abort points: STOP after CCC+T (always); STOP after DB+T (only if
    # the CCC has a defining byte).
    abort_points = [(None, "after CCC + T")]
    if defining_byte is not None:
        abort_points.append((defining_byte, "after defining byte + T"))

    expected_dut_pid = (dut_pid_hi << 33) | dut_pid_lo

    for db, descn in abort_points:
        cocotb.log.info(f"--- No-target abort: {descn} ---")

        kwargs = {"directed_data": []}
        if db is not None:
            kwargs["defining_byte"] = db
        await i3c_controller.i3c_ccc_write(ccc=desc.code, **kwargs)

        await recovery_wait(i3c_controller)

        # Recovery: sim target read works.
        sim_responses = await i3c_controller.i3c_ccc_read(
            ccc=CCC.DIRECT.GETPID, addr=sim_addr, count=6
        )
        ack, _ = sim_responses[0]
        assert ack, f"Sim NACK after no-target abort {descn}"

        # Recovery: DUT GETPID is value-correct.
        responses = await i3c_controller.i3c_ccc_read(
            ccc=CCC.DIRECT.GETPID, addr=dut_addr, count=6
        )
        ack, data = responses[0]
        assert ack, f"DUT NACK after no-target abort {descn}"
        pid_rx = int.from_bytes(data[0:6], byteorder="big")
        assert pid_rx == expected_dut_pid, (
            f"DUT recovery GETPID after no-target {descn}: "
            f"exp 0x{expected_dut_pid:012X} got 0x{pid_rx:012X}"
        )

    await tb.teardown()


# =========================================================================
# 14. SETMRL / GETMRL with sim BCR[2]=0 -- spec 2-byte frame (sim-only)
# =========================================================================
# Exercises the MIPI I3C Basic v1.1.1 §5.1.9.3.6 (Fig.39 / Fig.40) 2-byte
# SET/GET MRL frame against a sim target whose BCR[2]=0 (no IBI payload
# byte appended).  Sim-target only -- the DUT today hardwires 3 bytes for
# both directions regardless of BCR[2] (see bug-{set,get}mrl-length-
# ignores-bcr2.md), so addressing the DUT in the same frame would cause
# bus contention.  This test is the standing companion to the BCR[2]=1
# coverage that runs under random pickers via _setup_mrl in this file,
# and to the DUT-only 3-byte coverage in test_ccc.py::test_ccc_{getmrl,
# setmrl_*}.  Once the RTL is fixed, this test should remain (the spec
# 2-byte path is legitimate coverage on its own).
@cocotb.test()
async def test_ccc_mrl_bcr2_zero_sim_only(dut):
    """Spec 2-byte SETMRL/GETMRL frame against a BCR[2]=0 sim target."""
    (i3c_controller, i3c_target, tb, dut_addr, sim_addr,
     _, _, _) = await setup_env(dut)

    i3c_target.bcr &= ~0x04
    assert (i3c_target.bcr & 0x04) == 0, (
        f"sim BCR[2] must be 0 for this test, got bcr=0x{i3c_target.bcr:02X}"
    )
    i3c_target.max_rd_length = random.randint(16, 0xFFFF)

    dut._log.info(
        f"sim BCR=0x{i3c_target.bcr:02X} max_rd_length=0x{i3c_target.max_rd_length:04X}"
    )

    dut._log.info("--- GETMRL (initial, expect 2-byte response) ---")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETMRL, addr=sim_addr, count=2,
    )
    ack, data = responses[0]
    assert ack, f"sim NACKed initial GETMRL @0x{sim_addr:02X}"
    assert len(data) == 2, (
        f"GETMRL returned {len(data)} bytes, expected 2 (BCR[2]=0)"
    )
    rx = (data[0] << 8) | data[1]
    assert rx == i3c_target.max_rd_length, (
        f"GETMRL value mismatch: got 0x{rx:04X} "
        f"expected 0x{i3c_target.max_rd_length:04X}"
    )

    dut._log.info("--- SETMRL (2-byte directed frame) ---")
    new_mrl = random.randint(16, 0xFFFF)
    while new_mrl == i3c_target.max_rd_length:
        new_mrl = random.randint(16, 0xFFFF)
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETMRL,
        directed_data=[(sim_addr, [(new_mrl >> 8) & 0xFF, new_mrl & 0xFF])],
    )

    dut._log.info("--- GETMRL (post-SET, verify round-trip) ---")
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETMRL, addr=sim_addr, count=2,
    )
    ack, data = responses[0]
    assert ack, f"sim NACKed post-SET GETMRL @0x{sim_addr:02X}"
    assert len(data) == 2, (
        f"post-SET GETMRL returned {len(data)} bytes, expected 2"
    )
    rx = (data[0] << 8) | data[1]
    assert rx == new_mrl, (
        f"SETMRL did not take effect: got 0x{rx:04X} expected 0x{new_mrl:04X}"
    )
    assert i3c_target.max_rd_length == new_mrl, (
        f"sim target.max_rd_length not updated by SETMRL: "
        f"target=0x{i3c_target.max_rd_length:04X} expected 0x{new_mrl:04X}"
    )

    await tb.teardown()
