# SPDX-License-Identifier: Apache-2.0
"""Shared constants and helpers for I3C Target cocotb tests."""

import random

import cocotb
from cocotb.triggers import Timer

from ccc import CCC

# Canonical I3C address list -- single source of truth
# 0x23 is excluded: it is hardcoded as the I3CTarget sim model address
# and selecting it for DUT addresses causes bus contention.
VALID_I3C_ADDRESSES = (
    [i for i in range(0x03, 0x23)]
    + [i for i in range(0x24, 0x3E)]
    + [i for i in range(0x3F, 0x5E)]
    + [i for i in range(0x5F, 0x6E)]
    + [i for i in range(0x6F, 0x76)]
    + [i for i in range(0x77, 0x7A)]
    + [0x7B, 0x7D]
)


async def timeout_task(timeout_us):
    """Generic test timeout. Raises TimeoutError after timeout_us microseconds."""
    await Timer(timeout_us, "us")
    raise TimeoutError(f"Test timeout after {timeout_us} us!")


def log_seed(dut):
    """Log the random seed for reproducibility."""
    seed = cocotb.plusargs.get("seed", None)
    dut._log.info(f"Random seed: {seed or 'unknown (set via RANDOM_SEED plusarg)'}")


# =============================================================================
# CCC helpers
#
# Generic wrappers around common CCC commands.  Each function takes an
# i3c_controller and target address(es) explicitly so they can be reused
# from any test file.
#
# GET helpers return the raw data bytes (bytearray) and assert ACK.
# SET helpers return True/False indicating whether the target ACKed.
# All helpers log the CCC name, address, and returned data.
# =============================================================================

# Valid event-enable bit patterns for ENEC / DISEC
ENEC_DISEC_PATTERNS = [0x01, 0x02, 0x08, 0x03, 0x09, 0x0A, 0x0B]


async def do_getstatus(i3c_controller, addr):
    """Send directed GETSTATUS.  Returns 2-byte status (bytearray)."""
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETSTATUS, addr=addr, count=2)
    ack, data = responses[0]
    assert ack, f"GETSTATUS NACK addr=0x{addr:02X}"
    cocotb.log.info(f"GETSTATUS addr=0x{addr:02X} -> {data.hex()}")
    return data


async def do_getbcr(i3c_controller, addr):
    """Send directed GETBCR.  Returns 1-byte BCR (bytearray)."""
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETBCR, addr=addr, count=1)
    ack, data = responses[0]
    assert ack, f"GETBCR NACK addr=0x{addr:02X}"
    cocotb.log.info(f"GETBCR addr=0x{addr:02X} -> {data.hex()}")
    return data


async def do_getdcr(i3c_controller, addr):
    """Send directed GETDCR.  Returns 1-byte DCR (bytearray)."""
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETDCR, addr=addr, count=1)
    ack, data = responses[0]
    assert ack, f"GETDCR NACK addr=0x{addr:02X}"
    cocotb.log.info(f"GETDCR addr=0x{addr:02X} -> {data.hex()}")
    return data


async def do_getmwl(i3c_controller, addr):
    """Send directed GETMWL.  Returns 2-byte MWL (bytearray)."""
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETMWL, addr=addr, count=2)
    ack, data = responses[0]
    assert ack, f"GETMWL NACK addr=0x{addr:02X}"
    cocotb.log.info(f"GETMWL addr=0x{addr:02X} -> {data.hex()}")
    return data


async def do_getmrl(i3c_controller, addr):
    """Send directed GETMRL.  Returns 3-byte MRL (bytearray)."""
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETMRL, addr=addr, count=3)
    ack, data = responses[0]
    assert ack, f"GETMRL NACK addr=0x{addr:02X}"
    cocotb.log.info(f"GETMRL addr=0x{addr:02X} -> {data.hex()}")
    return data


async def do_getpid(i3c_controller, addr):
    """Send directed GETPID.  Returns 6-byte PID (bytearray)."""
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETPID, addr=addr, count=6)
    ack, data = responses[0]
    assert ack, f"GETPID NACK addr=0x{addr:02X}"
    cocotb.log.info(f"GETPID addr=0x{addr:02X} -> {data.hex()}")
    return data


async def do_getcaps(i3c_controller, addr):
    """Send directed GETCAPS (no defining byte, 3 bytes).  Returns bytearray."""
    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETCAPS, addr=addr, count=3)
    ack, data = responses[0]
    assert ack, f"GETCAPS NACK addr=0x{addr:02X}"
    cocotb.log.info(f"GETCAPS addr=0x{addr:02X} -> {data.hex()}")
    return data


async def do_setmwl_direct(i3c_controller, addr, val=None):
    """Send directed SETMWL.  Returns True if ACKed, False otherwise."""
    if val is None:
        val = random.randint(0, 0xFFFF)
    acks = await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETMWL,
        directed_data=[(addr, [(val >> 8) & 0xFF, val & 0xFF])])
    ok = bool(acks and acks[0])
    cocotb.log.info(f"SETMWL direct addr=0x{addr:02X} val=0x{val:04X} ack={ok}")
    return ok


async def do_setmrl_direct(i3c_controller, addr, val=None, ibil=None):
    """Send directed SETMRL.  Returns True if ACKed, False otherwise."""
    if val is None:
        val = random.randint(0, 0xFFFF)
    if ibil is None:
        ibil = random.randint(0, 0xFF)
    acks = await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETMRL,
        directed_data=[(addr, [(val >> 8) & 0xFF, val & 0xFF, ibil])])
    ok = bool(acks and acks[0])
    cocotb.log.info(
        f"SETMRL direct addr=0x{addr:02X} mrl=0x{val:04X} "
        f"ibil=0x{ibil:02X} ack={ok}")
    return ok


async def do_enec_direct(i3c_controller, addr, pattern=None):
    """Send directed ENEC.  Returns True if ACKed, False otherwise."""
    if pattern is None:
        pattern = random.choice(ENEC_DISEC_PATTERNS)
    acks = await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.ENEC, directed_data=[(addr, [pattern])])
    ok = bool(acks and acks[0])
    cocotb.log.info(f"ENEC direct addr=0x{addr:02X} pattern=0x{pattern:02X} ack={ok}")
    return ok


async def do_disec_direct(i3c_controller, addr, pattern=None):
    """Send directed DISEC.  Returns True if ACKed, False otherwise."""
    if pattern is None:
        pattern = random.choice(ENEC_DISEC_PATTERNS)
    acks = await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.DISEC, directed_data=[(addr, [pattern])])
    ok = bool(acks and acks[0])
    cocotb.log.info(
        f"DISEC direct addr=0x{addr:02X} pattern=0x{pattern:02X} ack={ok}")
    return ok


async def do_rstact_direct(i3c_controller, addr, defining_byte=None):
    """Send directed RSTACT.  Returns True if ACKed, False otherwise."""
    if defining_byte is None:
        defining_byte = random.choice([0x00, 0x01, 0x02])
    acks = await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.RSTACT, defining_byte=defining_byte,
        directed_data=[(addr, [])], stop=True)
    ok = bool(acks and acks[0])
    cocotb.log.info(
        f"RSTACT direct addr=0x{addr:02X} db=0x{defining_byte:02X} ack={ok}")
    return ok


async def do_setmwl_bcast(i3c_controller, val=None):
    """Send broadcast SETMWL.  Returns True (broadcast has no per-target ACK)."""
    if val is None:
        val = random.randint(0, 0xFFFF)
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.BCAST.SETMWL,
        broadcast_data=[(val >> 8) & 0xFF, val & 0xFF])
    cocotb.log.info(f"SETMWL bcast val=0x{val:04X}")
    return True


async def do_setmrl_bcast(i3c_controller, val=None, ibil=None):
    """Send broadcast SETMRL.  Returns True (broadcast has no per-target ACK)."""
    if val is None:
        val = random.randint(0, 0xFFFF)
    if ibil is None:
        ibil = random.randint(0, 0xFF)
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.BCAST.SETMRL,
        broadcast_data=[(val >> 8) & 0xFF, val & 0xFF, ibil])
    cocotb.log.info(f"SETMRL bcast mrl=0x{val:04X} ibil=0x{ibil:02X}")
    return True


async def do_enec_bcast(i3c_controller, pattern=None):
    """Send broadcast ENEC.  Returns True (broadcast has no per-target ACK)."""
    if pattern is None:
        pattern = random.choice(ENEC_DISEC_PATTERNS)
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.BCAST.ENEC, broadcast_data=[pattern])
    cocotb.log.info(f"ENEC bcast pattern=0x{pattern:02X}")
    return True


async def do_disec_bcast(i3c_controller, pattern=None):
    """Send broadcast DISEC.  Returns True (broadcast has no per-target ACK)."""
    if pattern is None:
        pattern = random.choice(ENEC_DISEC_PATTERNS)
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.BCAST.DISEC, broadcast_data=[pattern])
    cocotb.log.info(f"DISEC bcast pattern=0x{pattern:02X}")
    return True


def build_ccc_stress_table(i3c_controller, targets):
    """Build a weighted CCC command table for stress testing.

    Returns a list of zero-argument coroutine functions.  Each picks a random
    target from *targets* (for directed CCCs) and sends one CCC.
    SET CCCs appear twice for higher weight (more race opportunity).
    """
    get_table = [
        lambda c=i3c_controller, t=targets: do_getstatus(c, random.choice(t)),
        lambda c=i3c_controller, t=targets: do_getbcr(c, random.choice(t)),
        lambda c=i3c_controller, t=targets: do_getdcr(c, random.choice(t)),
        lambda c=i3c_controller, t=targets: do_getmwl(c, random.choice(t)),
        lambda c=i3c_controller, t=targets: do_getmrl(c, random.choice(t)),
        lambda c=i3c_controller, t=targets: do_getpid(c, random.choice(t)),
        lambda c=i3c_controller, t=targets: do_getcaps(c, random.choice(t)),
    ]

    set_directed = [
        lambda c=i3c_controller, t=targets: do_setmwl_direct(c, random.choice(t)),
        lambda c=i3c_controller, t=targets: do_setmrl_direct(c, random.choice(t)),
        lambda c=i3c_controller, t=targets: do_enec_direct(c, random.choice(t)),
        lambda c=i3c_controller, t=targets: do_disec_direct(c, random.choice(t)),
        lambda c=i3c_controller, t=targets: do_rstact_direct(c, random.choice(t)),
    ]

    set_bcast = [
        lambda c=i3c_controller: do_setmwl_bcast(c),
        lambda c=i3c_controller: do_setmrl_bcast(c),
        lambda c=i3c_controller: do_enec_bcast(c),
        lambda c=i3c_controller: do_disec_bcast(c),
    ]

    return get_table + set_directed * 2 + set_bcast * 2
