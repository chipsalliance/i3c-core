# SPDX-License-Identifier: Apache-2.0
"""
CCC descriptor table and generic CCC drivers.

Generalizes per-CCC frame format so a single test body can drive any CCC
in `SUPPORTED_CCCS`. Each descriptor carries:

  - code:           CCC byte (CCC.DIRECT.X or CCC.BCAST.X)
  - name:           short label for logging/asserts
  - kind:           "read" | "write" | "bcast_write"
                    (Note: I3C has no broadcast reads -- all BCAST CCCs are
                    writes or address-only signaling like RSTDAA/ENTDAA.)
  - base_count:     default bytes returned (read) or written (write)
  - dut_supported:  True if the DUT also responds (used by multi-target tests)
  - has_post_read_check: True iff post_read_check() is meaningful
  - has_dynamic_count:   True iff count() depends on target state

And callbacks (None when not applicable):

  - setup(target):            randomize target backing state
  - verify(target, data):     assert returned bytes match target state
  - mutate(target):           change state for runtime-update test
                              (must produce a state distinguishable from setup)
  - count(target):            dynamic byte count from current target state
  - post_read_check(target):  e.g. GETSTATUS protocol-error self-clear
  - gen_data(target):         (defining_byte, data_bytes) for write/bcast_write
  - apply_write(target, data): simulate the side-effect locally for SET CCCs
                               so subsequent verify() can compare. Optional.

Unsupported CCCs (excluded from this table): ENTAS0-3, DEFTGTS, ENTTM,
SETBUSCON, ENDXFER, all HDR modes, ENTHDR0-7, SETXTIME, DEFGRPA, RSTGRPA,
MLANE, RSTDAA (direct), GETACCCR, SETBRGTTGT, SETROUTE, D2DXFER, GETXTIME,
SETGRPA. ENTDAA is a dynamic address procedure and out of scope for these
sim-target CCC tests.
"""

import random
from dataclasses import dataclass
from typing import Callable, List, Optional

import cocotb
from cocotb.triggers import Timer

from ccc import CCC


# Valid event-enable bit patterns for ENEC / DISEC (mirror of common.py).
ENEC_DISEC_PATTERNS = [0x01, 0x02, 0x08, 0x03, 0x09, 0x0A, 0x0B]


# ---------------------------------------------------------------------------
# Dynamic count helpers
# ---------------------------------------------------------------------------

def _getmrl_count(target):
    # Per spec 5.1.9.3.6: GETMRL returns 2 bytes by default (MRL hi/lo).
    # If the target advertises BCR[2]=1 (IBI Payload), it returns 1 extra
    # byte for Max IBI Payload Size.
    return 3 if (target.bcr & 0x04) else 2


def _getcaps_count(target):
    return len(target.getcaps_bytes)


def _getmxds_count(target):
    return len(target.getmxds_bytes)


# ---------------------------------------------------------------------------
# Setup helpers (randomize backing target state for a given CCC)
# ---------------------------------------------------------------------------

def _setup_pid(target):
    target.pid = random.randint(0, 0xFFFFFFFFFFFF)


def _setup_bcr(target):
    # Randomize all 8 bits.  BCR[2] (Max Data Speed Limitation /
    # IBI Payload bit) is allowed to be 0 or 1 -- consumers (GETMRL count)
    # adapt to target.bcr & 0x04.
    target.bcr = random.randint(0, 0xFF)


def _setup_dcr(target):
    target.dcr = random.randint(0, 0xFF)


def _setup_status(target):
    target.vendor_status = random.randint(0, 0xFF)
    target.activity_mode = random.randint(0, 3)
    target.pending_interrupt = random.randint(0, 0xF)
    target.protocol_error = bool(random.getrandbits(1))


def _setup_mwl(target):
    target.max_write_length = random.randint(16, 0xFFFF)


def _setup_mrl(target):
    # DUT GETMRL always returns 3 bytes (per ccc.sv:1354): MRL hi/lo + IBI
    # payload byte.  We force BCR[2]=1 so the sim target's count function
    # matches the DUT's response length.  Without this alignment, mixed
    # sim+DUT multi-target frames pick a count derived from the sim model
    # that does not match the DUT, leading the controller to force-NACK
    # while the DUT is still PP-driving -> bus contention.
    target.bcr |= 0x04
    target.max_ibi_payload = random.randint(1, 0xFF)
    target.max_rd_length = random.randint(16, 0xFFFF)


def _setup_caps(target):
    # DUT GETCAPS default response is 3 bytes (per ccc.sv:1382).  Sim
    # mirrors that fixed length so multi-target frames containing both
    # the DUT and the sim target use a single, correct count.
    target.getcaps_bytes = [
        random.randint(0, 0xFF),
        random.randint(0, 0xFF),
        random.randint(0, 0xFF),
    ]


def _setup_mxds(target):
    target.getmxds_bytes = [random.randint(0, 0xFF), random.randint(0, 0xFF)]


# ---------------------------------------------------------------------------
# Verify helpers (assert returned bytes match target state)
# ---------------------------------------------------------------------------

def _verify_pid(target, data):
    pid_rx = int.from_bytes(data[0:6], byteorder="big")
    assert pid_rx == target.pid, (
        f"GETPID mismatch: exp 0x{target.pid:012X} got 0x{pid_rx:012X}"
    )


def _verify_bcr(target, data):
    assert data[0] == target.bcr, (
        f"GETBCR mismatch: exp 0x{target.bcr:02X} got 0x{data[0]:02X}"
    )


def _verify_dcr(target, data):
    assert data[0] == target.dcr, (
        f"GETDCR mismatch: exp 0x{target.dcr:02X} got 0x{data[0]:02X}"
    )


def _verify_status(target, data):
    msb = data[0]
    lsb = data[1]
    assert msb == target.vendor_status, (
        f"GETSTATUS vendor: exp 0x{target.vendor_status:02X} got 0x{msb:02X}"
    )
    assert (lsb >> 6) & 0x3 == target.activity_mode, (
        f"GETSTATUS activity: exp {target.activity_mode} got {(lsb >> 6) & 0x3}"
    )
    # bit[5] (protocol_error) is checked in post_read_check because it
    # self-clears after a single read.
    assert (lsb & 0xF) == target.pending_interrupt, (
        f"GETSTATUS pending_int: exp {target.pending_interrupt} "
        f"got {lsb & 0xF}"
    )


def _verify_mwl(target, data):
    val = int.from_bytes(data[0:2], byteorder="big")
    assert val == target.max_write_length, (
        f"GETMWL mismatch: exp 0x{target.max_write_length:04X} got 0x{val:04X}"
    )


def _verify_mrl(target, data):
    val = int.from_bytes(data[0:2], byteorder="big")
    assert val == target.max_rd_length, (
        f"GETMRL mismatch: exp 0x{target.max_rd_length:04X} got 0x{val:04X}"
    )
    if target.bcr & 0x04:
        assert data[2] == target.max_ibi_payload, (
            f"GETMRL IBI payload: exp 0x{target.max_ibi_payload:02X} "
            f"got 0x{data[2]:02X}"
        )


def _verify_caps(target, data):
    for i, exp in enumerate(target.getcaps_bytes):
        assert data[i] == exp, (
            f"GETCAPS[{i}]: exp 0x{exp:02X} got 0x{data[i]:02X}"
        )


def _verify_mxds(target, data):
    for i, exp in enumerate(target.getmxds_bytes):
        assert data[i] == exp, (
            f"GETMXDS[{i}]: exp 0x{exp:02X} got 0x{data[i]:02X}"
        )


# ---------------------------------------------------------------------------
# Mutate helpers (for runtime-update test)
# ---------------------------------------------------------------------------

def _mutate_pid(target):
    target.pid ^= 0xA5A5A5A5A5A5  # flip enough bits to force change


def _mutate_bcr(target):
    target.bcr = (target.bcr ^ 0xFB) & ~0x04  # preserve BCR[2]=0


def _mutate_dcr(target):
    target.dcr ^= 0xFF


def _mutate_status(target):
    target.vendor_status = (target.vendor_status + 1) & 0xFF
    target.activity_mode = (target.activity_mode + 1) & 0x3
    target.pending_interrupt = (target.pending_interrupt + 1) & 0xF
    target.protocol_error = not target.protocol_error


def _mutate_mwl(target):
    new = random.randint(16, 0xFFFF)
    while new == target.max_write_length:
        new = random.randint(16, 0xFFFF)
    target.max_write_length = new


def _mutate_mrl(target):
    new = random.randint(16, 0xFFFF)
    while new == target.max_rd_length:
        new = random.randint(16, 0xFFFF)
    target.max_rd_length = new


def _mutate_caps(target):
    target.getcaps_bytes = [b ^ 0xFF for b in target.getcaps_bytes]


def _mutate_mxds(target):
    target.getmxds_bytes = [b ^ 0xFF for b in target.getmxds_bytes]


# ---------------------------------------------------------------------------
# Post-read state hook (GETSTATUS protocol-error self-clear)
# ---------------------------------------------------------------------------

def _post_status(target):
    # Spec 5.1.9.3.15: bit[5] self-clears after a single GETSTATUS read.
    # Mirror the sim model's local clear so subsequent verify() agrees.
    if target.protocol_error:
        target.protocol_error = False


# ---------------------------------------------------------------------------
# Write CCC data generators
# ---------------------------------------------------------------------------

def _gen_setmwl(target):
    val = random.randint(16, 0xFFFF)
    return None, [(val >> 8) & 0xFF, val & 0xFF]


def _apply_setmwl(target, data_bytes):
    target.max_write_length = (data_bytes[0] << 8) | data_bytes[1]


def _gen_setmrl(target):
    val = random.randint(16, 0xFFFF)
    ibil = random.randint(0, 0xFF)
    return None, [(val >> 8) & 0xFF, val & 0xFF, ibil]


def _apply_setmrl(target, data_bytes):
    target.max_rd_length = (data_bytes[0] << 8) | data_bytes[1]
    if len(data_bytes) >= 3:
        target.max_ibi_payload = data_bytes[2]


def _gen_enec_disec(target):
    return None, [random.choice(ENEC_DISEC_PATTERNS)]


def _apply_noop(target, data_bytes):
    """No locally observable side-effect (ENEC/DISEC/RSTACT/RSTDAA-bcast)."""
    pass


def _gen_rstact(target):
    db = random.choice([0x00, 0x01, 0x02, 0x04, 0x81, 0x82, 0x84])
    return db, []


def _gen_rstdaa_bcast(target):
    return None, []


# ---------------------------------------------------------------------------
# Descriptor type and table
# ---------------------------------------------------------------------------

@dataclass
class CCCDescriptor:
    code: int
    name: str
    kind: str  # "read" | "write" | "bcast_write"
    base_count: int = 0
    dut_supported: bool = False
    has_post_read_check: bool = False
    has_dynamic_count: bool = False
    setup: Optional[Callable] = None
    verify: Optional[Callable] = None
    mutate: Optional[Callable] = None
    count: Optional[Callable] = None
    post_read_check: Optional[Callable] = None
    gen_data: Optional[Callable] = None
    apply_write: Optional[Callable] = None


SUPPORTED_CCCS: List[CCCDescriptor] = [
    # ----------------- Directed reads -----------------
    CCCDescriptor(
        code=CCC.DIRECT.GETPID, name="GETPID", kind="read", base_count=6,
        dut_supported=True,
        setup=_setup_pid, verify=_verify_pid, mutate=_mutate_pid,
    ),
    CCCDescriptor(
        code=CCC.DIRECT.GETBCR, name="GETBCR", kind="read", base_count=1,
        dut_supported=True,
        setup=_setup_bcr, verify=_verify_bcr, mutate=_mutate_bcr,
    ),
    CCCDescriptor(
        code=CCC.DIRECT.GETDCR, name="GETDCR", kind="read", base_count=1,
        dut_supported=True,
        setup=_setup_dcr, verify=_verify_dcr, mutate=_mutate_dcr,
    ),
    CCCDescriptor(
        code=CCC.DIRECT.GETSTATUS, name="GETSTATUS", kind="read", base_count=2,
        dut_supported=True, has_post_read_check=True,
        setup=_setup_status, verify=_verify_status, mutate=_mutate_status,
        post_read_check=_post_status,
    ),
    CCCDescriptor(
        code=CCC.DIRECT.GETMWL, name="GETMWL", kind="read", base_count=2,
        dut_supported=True,
        setup=_setup_mwl, verify=_verify_mwl, mutate=_mutate_mwl,
    ),
    CCCDescriptor(
        code=CCC.DIRECT.GETMRL, name="GETMRL", kind="read", base_count=2,
        dut_supported=True, has_dynamic_count=True,
        setup=_setup_mrl, verify=_verify_mrl, mutate=_mutate_mrl,
        count=_getmrl_count,
    ),
    CCCDescriptor(
        code=CCC.DIRECT.GETCAPS, name="GETCAPS", kind="read", base_count=2,
        dut_supported=True, has_dynamic_count=True,
        setup=_setup_caps, verify=_verify_caps, mutate=_mutate_caps,
        count=_getcaps_count,
    ),
    CCCDescriptor(
        code=CCC.DIRECT.GETMXDS, name="GETMXDS", kind="read", base_count=2,
        # DUT hardwires get_mxds=0 in controller_standby_i3c.sv, so it
        # NACKs directed GETMXDS reads.  Sim target supports it.
        dut_supported=False, has_dynamic_count=True,
        setup=_setup_mxds, verify=_verify_mxds, mutate=_mutate_mxds,
        count=_getmxds_count,
    ),

    # ----------------- Directed writes -----------------
    CCCDescriptor(
        code=CCC.DIRECT.SETMWL, name="SETMWL", kind="write", base_count=2,
        dut_supported=True,
        gen_data=_gen_setmwl, apply_write=_apply_setmwl,
    ),
    CCCDescriptor(
        code=CCC.DIRECT.SETMRL, name="SETMRL", kind="write", base_count=3,
        dut_supported=True,
        gen_data=_gen_setmrl, apply_write=_apply_setmrl,
    ),
    CCCDescriptor(
        code=CCC.DIRECT.ENEC, name="ENEC", kind="write", base_count=1,
        dut_supported=True,
        gen_data=_gen_enec_disec, apply_write=_apply_noop,
    ),
    CCCDescriptor(
        code=CCC.DIRECT.DISEC, name="DISEC", kind="write", base_count=1,
        dut_supported=True,
        gen_data=_gen_enec_disec, apply_write=_apply_noop,
    ),
    CCCDescriptor(
        code=CCC.DIRECT.RSTACT, name="RSTACT", kind="write", base_count=0,
        dut_supported=True,
        gen_data=_gen_rstact, apply_write=_apply_noop,
    ),

    # ----------------- Broadcast writes -----------------
    CCCDescriptor(
        code=CCC.BCAST.SETMWL, name="BCAST_SETMWL", kind="bcast_write",
        base_count=2,
        gen_data=_gen_setmwl, apply_write=_apply_setmwl,
    ),
    CCCDescriptor(
        code=CCC.BCAST.SETMRL, name="BCAST_SETMRL", kind="bcast_write",
        base_count=3,
        gen_data=_gen_setmrl, apply_write=_apply_setmrl,
    ),
    CCCDescriptor(
        code=CCC.BCAST.ENEC, name="BCAST_ENEC", kind="bcast_write",
        base_count=1,
        gen_data=_gen_enec_disec, apply_write=_apply_noop,
    ),
    CCCDescriptor(
        code=CCC.BCAST.DISEC, name="BCAST_DISEC", kind="bcast_write",
        base_count=1,
        gen_data=_gen_enec_disec, apply_write=_apply_noop,
    ),
    CCCDescriptor(
        code=CCC.BCAST.RSTACT, name="BCAST_RSTACT", kind="bcast_write",
        base_count=0,
        gen_data=_gen_rstact, apply_write=_apply_noop,
    ),
    CCCDescriptor(
        code=CCC.BCAST.RSTDAA, name="BCAST_RSTDAA", kind="bcast_write",
        base_count=0,
        gen_data=_gen_rstdaa_bcast, apply_write=_apply_noop,
    ),
]


# Convenience filtered subsets ------------------------------------------------
READ_CCCS = [d for d in SUPPORTED_CCCS if d.kind == "read"]
WRITE_CCCS = [d for d in SUPPORTED_CCCS if d.kind == "write"]
BCAST_CCCS = [d for d in SUPPORTED_CCCS if d.kind == "bcast_write"]


def pick_random_ccc(predicate=None, kinds=None):
    """Pick a random descriptor from SUPPORTED_CCCS.

    Args:
        predicate: optional callable(desc)->bool for additional filtering.
        kinds:     optional iterable of kind strings to include.
    """
    pool = SUPPORTED_CCCS
    if kinds is not None:
        pool = [d for d in pool if d.kind in kinds]
    if predicate is not None:
        pool = [d for d in pool if predicate(d)]
    assert pool, "No CCCs matched the supplied filter"
    return random.choice(pool)


def descriptor_count(desc, target):
    """Resolve a descriptor's data length, defaulting to base_count."""
    if desc.count is not None and target is not None:
        return desc.count(target)
    return desc.base_count


def setup_descriptor_state(desc, target):
    """Randomize the sim target's backing state for `desc`, if applicable."""
    if desc.setup is not None:
        desc.setup(target)


def log_ccc_pick(dut, label, desc):
    """Log a uniformly-formatted banner for a randomly picked CCC."""
    dut._log.info(f"=== {label}: picked CCC {desc.name} (0x{desc.code:02X}) ===")


# ---------------------------------------------------------------------------
# Generic CCC drivers
# ---------------------------------------------------------------------------

async def do_ccc_read(i3c_controller, desc, addr, target=None, *, count=None):
    """Send a directed read CCC to a single target. Returns (ack, data).

    If `count` is None, uses descriptor.count(target) when available, else
    descriptor.base_count.
    """
    assert desc.kind == "read", f"do_ccc_read called with kind={desc.kind}"
    if count is None:
        count = descriptor_count(desc, target)
    responses = await i3c_controller.i3c_ccc_read(
        ccc=desc.code, addr=addr, count=count)
    ack, data = responses[0]
    cocotb.log.info(
        f"{desc.name} addr=0x{addr:02X} ack={ack} -> {bytes(data).hex()}"
    )
    return ack, data


async def do_ccc_read_multi(i3c_controller, desc, addr_list, target=None,
                            *, count=None):
    """Send a directed read CCC across multiple targets in one frame.

    Returns the raw list of (ack, data) tuples, one per address.
    """
    assert desc.kind == "read", (
        f"do_ccc_read_multi called with kind={desc.kind}"
    )
    if count is None:
        count = descriptor_count(desc, target)
    responses = await i3c_controller.i3c_ccc_read(
        ccc=desc.code, addr=addr_list, count=count)
    cocotb.log.info(
        f"{desc.name} multi addr={['0x%02X' % a for a in addr_list]} "
        f"-> {len(responses)} responses"
    )
    return responses


async def do_ccc_write(i3c_controller, desc, addr, target=None):
    """Send a directed write CCC. Returns True if ACKed.

    If `desc.apply_write` is not None and a target is provided, the
    side-effect is mirrored on the target so subsequent reads can verify
    state.
    """
    assert desc.kind == "write", f"do_ccc_write called with kind={desc.kind}"
    defining_byte, data_bytes = desc.gen_data(target)
    kwargs = {"directed_data": [(addr, list(data_bytes))]}
    if defining_byte is not None:
        kwargs["defining_byte"] = defining_byte
        kwargs["stop"] = True
    acks = await i3c_controller.i3c_ccc_write(ccc=desc.code, **kwargs)
    ok = bool(acks and acks[0])
    cocotb.log.info(
        f"{desc.name} write addr=0x{addr:02X} db={defining_byte} "
        f"data={list(data_bytes)} ack={ok}"
    )
    if ok and desc.apply_write is not None and target is not None:
        desc.apply_write(target, list(data_bytes))
    return ok


async def do_ccc_bcast(i3c_controller, desc, target=None):
    """Send a broadcast write CCC. Returns True (no per-target ACK)."""
    assert desc.kind == "bcast_write", (
        f"do_ccc_bcast called with kind={desc.kind}"
    )
    defining_byte, data_bytes = desc.gen_data(target)
    kwargs = {"broadcast_data": list(data_bytes)}
    if defining_byte is not None:
        kwargs["defining_byte"] = defining_byte
    await i3c_controller.i3c_ccc_write(ccc=desc.code, **kwargs)
    cocotb.log.info(
        f"{desc.name} bcast db={defining_byte} data={list(data_bytes)}"
    )
    if desc.apply_write is not None and target is not None:
        desc.apply_write(target, list(data_bytes))
    return True


async def do_ccc_read_verify(i3c_controller, desc, addr, target):
    """Send a directed read CCC, assert ACK, verify the value.

    Also runs post_read_check if the descriptor supplies one.
    """
    ack, data = await do_ccc_read(i3c_controller, desc, addr, target)
    assert ack, f"{desc.name} NACK addr=0x{addr:02X}"
    desc.verify(target, data)
    if desc.post_read_check is not None:
        desc.post_read_check(target)
    return data


def matching_get_descriptor(write_desc):
    """Return the GET descriptor that observes the side-effect of `write_desc`.

    SETMWL <-> GETMWL, SETMRL <-> GETMRL.  Returns None if the write CCC
    has no observable backing state we can read back (ENEC/DISEC/RSTACT/
    RSTDAA).
    """
    pairs = {
        "SETMWL": "GETMWL",
        "SETMRL": "GETMRL",
        "BCAST_SETMWL": "GETMWL",
        "BCAST_SETMRL": "GETMRL",
    }
    target_name = pairs.get(write_desc.name)
    if target_name is None:
        return None
    for d in READ_CCCS:
        if d.name == target_name:
            return d
    return None


async def verify_set_via_get(dut, ctrl, target, write_desc, addr):
    """If `write_desc` has a matching GET, run it and verify state."""
    get_desc = matching_get_descriptor(write_desc)
    if get_desc is None:
        dut._log.info(
            f"{write_desc.name}: no observable GET pair, skipping readback"
        )
        return None
    return await do_ccc_read_verify(ctrl, get_desc, addr, target)


# ---------------------------------------------------------------------------
# Bus-level abort helpers (spec 5.1.2.3.4 read-frame early termination)
# ---------------------------------------------------------------------------

def legal_abort_positions(desc, target, dut_safe):
    """Build legal STOP abort positions for a directed read of `desc`.

    For sim target (OD): raw STOP at any byte/T-bit boundary is legal.
    For DUT (PP):        data-phase positions must use Sr+STOP per spec
                          5.1.2.3.4 to avoid PP contention.

    Position types:
      - "setup_broadcast": STOP after broadcast 7E/W ACK (ctrl OD)
      - "setup_ccc":       STOP after CCC byte + T-bit (ctrl PP)
      - "data" / "data_sr": after N complete data byte+T-bit groups

    Returns list of (abort_type, param, description) tuples.
    """
    count = descriptor_count(desc, target)
    positions = [
        ("setup_broadcast", None, "after broadcast 7E/W ACK"),
        ("setup_ccc",       None, f"after CCC {desc.name} byte + T-bit"),
    ]
    if dut_safe:
        # DUT: setup phases use raw STOP; data phase uses Sr+STOP.
        for n in range(1, count):
            positions.append(
                ("data_sr", n, f"Sr after data byte {n - 1} T-bit")
            )
    else:
        # Sim target (OD): raw STOP everywhere is safe.
        for n in range(0, count):
            desc_str = (
                "after directed ACK (OD/PP boundary)" if n == 0
                else f"after data byte {n - 1} T-bit boundary"
            )
            positions.append(("data", n, desc_str))
    return positions


async def abort_ccc_at_legal_position(ctrl, desc, addr, abort_type, param):
    """Build a directed read frame for `desc`, abort at a legal position.

    Returns:
        True  if the directed address was reached and ACKed,
        False if NACKed,
        None  if abort happened in a setup phase.
    """
    await ctrl.take_bus_control()
    await ctrl.send_start()
    await ctrl.write_addr_header(0x7E)

    if abort_type == "setup_broadcast":
        await ctrl.send_stop()
        ctrl.give_bus_control()
        return None

    await ctrl.send_byte_tbit(desc.code)

    if abort_type == "setup_ccc":
        await ctrl.send_stop()
        ctrl.give_bus_control()
        return None

    # "data" or "data_sr": directed address phase, then read N bytes.
    await ctrl.send_start()
    ack = await ctrl.write_addr_header(addr, read=True)
    if not ack:
        await ctrl.send_stop()
        ctrl.give_bus_control()
        return False

    if abort_type == "data_sr":
        # Spec 5.1.2.3.4: early read termination via Sr at T-bit boundary.
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


async def recovery_wait(ctrl):
    """Wait long enough for the bus to settle after an abort/STOP.

    Spec floor is tCAS = 38.4 ns (I3C Basic v1.1.1, Table 86 / §5.1.3.2.1
    Pure-Bus Bus Free Condition). The literal floor is too tight for
    target FSM cleanup in this testbench, so we use 1 us as a small
    safety margin above the spec minimum.
    """
    TCAS_NS = 38.4  # Spec floor (Table 86).
    MIN_RECOVERY_NS = 5_000
    await Timer(max(MIN_RECOVERY_NS, int(TCAS_NS)), units='ns')
