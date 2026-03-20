# SPDX-License-Identifier: Apache-2.0
"""
Premature STOP tests for I3CTargetFixed sim target during CCC directed reads.

Verifies that the sim target recovers cleanly when the controller issues STOP
at arbitrary points during a directed read CCC (GETPID).  Without the
send_bit/send_byte overrides in I3CTargetFixed, the sim target hangs because
the base class awaits FallingEdge(scl_i) which never arrives after STOP.

Spec reference:
  Section 5.1.9.2.1: "If the Controller invalidly terminates the data
  associated with a CCC prematurely, then the Target shall use best efforts
  to handle the termination and ascertain the proper course of action."

Test flow (per iteration):
  1. Baseline GETPID -- confirm sim target is functional
  2. Begin a new GETPID directed read
  3. Clock a random number of bits (0 .. 53), then issue STOP
  4. Wait for sim target to recover via per-edge timeout
  5. Full GETPID -- confirm sim target returned to idle and responds correctly
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

from common import VALID_I3C_ADDRESSES, pick_random_addr, log_seed, do_getpid

# Fixed sim target PID for all tests (recognizable in waveform debug)
SIM_PID = 0xABCD_1234_5678
# DUT PID fields
DUT_PID_HI = 0x0123  # bits[47:33]
DUT_PID_LO = 0xDEADBEEF  # bits[31:0]

# Number of abort-recovery iterations per test invocation.
# Each iteration picks a fresh random abort point (0..53 bits).
NUM_ITERATIONS = 5


async def setup_env(dut, speed=None):
    """Boot DUT, create controller + sim target, return all handles."""
    cocotb.log.setLevel(logging.DEBUG)
    log_seed(dut)

    sim_target_addr = pick_random_addr()
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
        pid=SIM_PID,
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
        DUT_PID_HI,
    )
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.PID_LO,
        DUT_PID_LO,
    )
    await ClockCycles(tb.clk, 50)

    return i3c_controller, i3c_target, tb, dut_addr, sim_target_addr


async def begin_getpid_directed_read(ctrl, addr):
    """Start a GETPID directed read: broadcast phase + address phase.

    Sends: S + 7'h7E/W + GETPID + Sr + addr/R
    Does NOT read any data bytes -- caller controls how many bits to
    clock before aborting.

    Returns True if the target ACKed the directed address phase.
    """
    await ctrl.take_bus_control()
    await ctrl.send_start()
    await ctrl.write_addr_header(0x7E)
    await ctrl.send_byte_tbit(CCC.DIRECT.GETPID)
    await ctrl.send_start()
    ack = await ctrl.write_addr_header(addr, read=True)
    return ack


async def abort_at_bit_offset(ctrl, abort_at):
    """Clock *abort_at* bits of the GETPID response, then send STOP.

    Uses recv_byte_t_bit for complete 9-bit groups (8 data + T-bit)
    and recv_bit for any remaining bits, then issues STOP.

    Args:
        ctrl:     I3C controller handle.
        abort_at: Number of bits to clock before STOP (0 = immediately
                  after ACK, 53 = last possible bit of a 6-byte response).
    """
    full_bytes = abort_at // 9
    remaining_bits = abort_at % 9
    for _ in range(full_bytes):
        await ctrl.recv_byte_t_bit(stop=False)
    for _ in range(remaining_bits):
        await ctrl.recv_bit()
    await ctrl.send_stop()


async def verify_recovery(ctrl, sim_addr, expected_sim_pid,
                          dut_addr, expected_dut_pid):
    """Verify both the sim target and DUT recover after a premature STOP.

    Waits for the sim target's per-edge timeout to fire (~20 SCL
    periods), then performs GETPID to both the sim target and DUT
    and checks their PIDs.
    """
    ctrl.give_bus_control()
    # Wait for per-edge timeout + margin (50 SCL periods, 10us floor)
    RECOVERY_SCL_PERIODS = 50
    MIN_RECOVERY_NS = 10_000
    scl_period_ns = int(1e9 / ctrl.speed)
    recovery_ns = max(MIN_RECOVERY_NS,
                      RECOVERY_SCL_PERIODS * scl_period_ns)
    await Timer(recovery_ns, units='ns')

    # Check sim target recovery
    sim_data = await do_getpid(ctrl, sim_addr)
    sim_pid = int.from_bytes(sim_data[0:6], byteorder="big", signed=False)
    assert sim_pid == expected_sim_pid, (
        f"Sim target recovery GETPID mismatch: got 0x{sim_pid:012X}, "
        f"expected 0x{expected_sim_pid:012X}"
    )
    cocotb.log.info(f"Sim target recovery GETPID OK: 0x{sim_pid:012X}")

    # Check DUT recovery
    dut_data = await do_getpid(ctrl, dut_addr)
    dut_pid = int.from_bytes(dut_data[0:6], byteorder="big", signed=False)
    assert dut_pid == expected_dut_pid, (
        f"DUT recovery GETPID mismatch: got 0x{dut_pid:012X}, "
        f"expected 0x{expected_dut_pid:012X}"
    )
    cocotb.log.info(f"DUT recovery GETPID OK: 0x{dut_pid:012X}")


async def do_abort_iteration(ctrl, sim_addr, dut_addr, expected_dut_pid,
                             iteration, abort_at):
    """Run one abort-recovery iteration.

    1. Baseline GETPID (sanity check before abort)
    2. Begin GETPID, clock abort_at bits, STOP
    3. Verify recovery with GETPID to both sim target and DUT
    """
    cocotb.log.info(
        f"--- Iteration {iteration}: abort at bit {abort_at} "
        f"(byte {abort_at // 9}, bit-in-byte {abort_at % 9}) ---"
    )

    # Baseline
    data = await do_getpid(ctrl, sim_addr)
    pid_48 = int.from_bytes(data[0:6], byteorder="big", signed=False)
    assert pid_48 == SIM_PID, (
        f"Iteration {iteration} baseline GETPID failed: "
        f"got 0x{pid_48:012X}, expected 0x{SIM_PID:012X}"
    )

    # Abort
    ack = await begin_getpid_directed_read(ctrl, sim_addr)
    assert ack, f"Iteration {iteration}: sim target NACKed directed GETPID"
    await abort_at_bit_offset(ctrl, abort_at)

    # Recovery -- check both sim target and DUT
    await verify_recovery(ctrl, sim_addr, SIM_PID,
                          dut_addr, expected_dut_pid)
    cocotb.log.info(f"--- Iteration {iteration}: PASSED ---")


@cocotb.test()
async def test_getpid_premature_stop(dut):
    """STOP at random bit offsets within a GETPID directed read response.

    Runs NUM_ITERATIONS rounds. Each round picks a random abort point
    in the range [0, 53] (6 bytes x 9 bits/byte on the wire), issues
    STOP at that point, and verifies the sim target recovers cleanly.

    Abort point semantics:
      0      = immediately after target ACK (before any data bits)
      1..7   = mid-byte within byte 0
      8      = after 8 data bits (T-bit phase of byte 0)
      9      = after byte 0 + T-bit (byte boundary)
      10..17 = mid-byte within byte 1
      ...
      53     = last bit before final T-bit of byte 5
    """
    ctrl, target, tb, dut_addr, sim_addr = await setup_env(dut)

    # DUT PID: PID_HI maps to bits[47:33], bit[32]=0, PID_LO = bits[31:0]
    expected_dut_pid = (DUT_PID_HI << 33) | DUT_PID_LO

    # 6-byte GETPID = 54 bits on wire (8 data + 1 T-bit per byte)
    max_bits = 6 * 9

    for i in range(NUM_ITERATIONS):
        abort_at = random.randint(0, max_bits - 1)
        await do_abort_iteration(ctrl, sim_addr, dut_addr,
                                 expected_dut_pid, i, abort_at)
