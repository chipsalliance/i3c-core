# SPDX-License-Identifier: Apache-2.0

"""
IBI multi-queue verification tests for I3C SDR Target.

Tests pre-queuing multiple IBI descriptors into the TTI IBI FIFO before any
are serviced, then exercising abort + successful delivery scenarios.

Covers:
- NACK + retry exhaustion with FW retry-counter reset recovery
- Partial data abort with auto-advance to next queued IBI
- Mixed abort types in a single sequence

Spec references: Sec 5.1.6.2 (IBI retry, partial abort, Bus Available timing)
"""

import logging
import random

from boot import boot_init
from bus2csr import dword2int, int2dword
from ccc import CCC
from i3c_controller_fixed import I3cControllerFixed as I3cController
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface
from utils import format_ibi_data, get_interrupt_status

import cocotb
from cocotb.result import SimTimeoutError
from cocotb.triggers import ClockCycles, RisingEdge, Timer, with_timeout
from common import timeout_task, log_seed

# =============================================================================
# Constants
# =============================================================================

TARGET_ADDRESS = 0x5A


# =============================================================================
# Shared helpers (mirroring test_ibi.py patterns)
# =============================================================================

async def test_setup(dut, fclk=333.0, fbus=12.5,
                     static_addr=TARGET_ADDRESS, timeout_us=500000):
    """Standard setup: controller + VIP target + DUT boot."""
    cocotb.log.setLevel(logging.INFO)
    log_seed(dut)
    cocotb.start_soon(timeout_task(timeout_us))

    i3c_controller = I3cController(
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_ctrl_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_ctrl_i,
        debug_state_o=None,
        speed=fbus * 1e6,
    )

    i3c_target = I3CTarget(
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_target_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_target_i,
        debug_state_o=None,
        speed=fbus * 1e6,
    )

    tb = I3CTopTestInterface(dut)
    await tb.setup(fclk)
    await boot_init(tb, fclk=fclk, static_addr=static_addr)

    return i3c_controller, i3c_target, tb


async def init_ibi(i3c_controller, tb, addr=TARGET_ADDRESS, retry_num=7):
    """Common IBI initialization: add target to controller, set retry, init timers."""
    target = i3c_controller.add_target(addr)
    target.set_bcr_fields(ibi_req_capable=True, ibi_payload=True)
    i3c_controller.enable_ibi(True)

    await set_ibi_retry_num(tb, retry_num)
    await set_ibi_enable(tb, True)

    # Broadcast CCC to initialize bus timers (STOP starts bus-available counting)
    await i3c_controller.i3c_ccc_write(ccc=CCC.BCAST.RSTDAA)

    return target


async def send_ibi(tb, mdb, data=None):
    """Queue an IBI descriptor + payload into TTI IBI_PORT."""
    if data is None:
        data = []
    ibi_words = format_ibi_data(mdb, data)
    for word in ibi_words:
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, int2dword(word), 4)


async def set_ibi_retry_num(tb, value):
    """Write TTI.CONTROL.IBI_RETRY_NUM field."""
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.CONTROL.base_addr,
        tb.reg_map.I3C_EC.TTI.CONTROL.IBI_RETRY_NUM,
        value,
    )


async def set_ibi_enable(tb, enable):
    """Write TTI.CONTROL.IBI_EN field."""
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.CONTROL.base_addr,
        tb.reg_map.I3C_EC.TTI.CONTROL.IBI_EN,
        1 if enable else 0,
    )


async def check_ibi_status(tb, expected, msg=""):
    """Read and assert LAST_IBI_STATUS from TTI.STATUS register."""
    status = await tb.read_csr_field(
        tb.reg_map.I3C_EC.TTI.STATUS.base_addr,
        tb.reg_map.I3C_EC.TTI.STATUS.LAST_IBI_STATUS,
    )
    assert status == expected, (
        f"LAST_IBI_STATUS mismatch{' (' + msg + ')' if msg else ''}: "
        f"expected {expected}, got {status}"
    )


async def verify_ibi_response(dut, response, addr, mdb, data):
    """Verify IBI response from controller matches expected addr+mdb+data."""
    expected = bytearray([addr, mdb] + (data or []))
    assert response == expected, (
        f"IBI data mismatch: "
        f"expected [{' '.join(f'0x{b:02X}' for b in expected)}], "
        f"got [{' '.join(f'0x{b:02X}' for b in response)}]"
    )


async def check_pending_interrupt(tb, expected):
    """Assert PENDING_IBI matches expected value."""
    actual = await tb.read_csr_field(
        tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS.base_addr,
        tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS.PENDING_IBI,
    )
    assert actual == expected, (
        f"PENDING_IBI mismatch: expected {expected}, got {actual}"
    )


async def expect_no_ibi(i3c_controller, timeout, units="us"):
    """Assert no IBI fires within the given timeout."""
    try:
        await with_timeout(i3c_controller.wait_for_ibi(), timeout, units)
        raise AssertionError(f"Unexpected IBI observed within {timeout}{units}")
    except SimTimeoutError:
        pass


async def reset_ibi_retry_counter(tb):
    """Write IBI_RETRY_CTR_RST singlepulse to reset the retry counter."""
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.IBI_RETRY_CTR_RST,
        1,
    )


# =============================================================================
# Test 1: NACK + retry exhaustion, FW resets counter, controller accepts
# =============================================================================

@cocotb.test()
async def test_ibi_multi_queue_nack_recovery(dut):
    """
    Pre-queue 3 IBIs, first gets NACKed and retries exhaust. FW resets the
    retry counter so the target retries the same IBI. Controller then accepts
    all 3 IBIs in order.

    Verifies:
    - Multiple IBIs can be pre-queued in the FIFO
    - NACK + retry exhaustion sets IbiFailureRetry (status=3)
    - descriptor_ibi stays in WriteMdb with original IBI data after exhaustion
    - FW IBI_RETRY_CTR_RST releases InhibitRetry and target retries the same IBI
    - All 3 pre-queued IBIs are delivered in FIFO order after recovery
    """
    i3c_controller, _, tb = await test_setup(dut)

    # retry_num=0: allows 1 attempt (cnt 0 <= 0), then exhausted (cnt 1 > 0)
    await init_ibi(i3c_controller, tb, retry_num=0)

    # Define 3 IBIs with varying payloads
    ibi_vectors = [
        (0xAA, [0x11, 0x22]),
        (0xBB, [0x33, 0x44, 0x55, 0x66]),
        (0xCC, [0x77]),
    ]

    # -----------------------------------------------------------------
    # Phase 1: Pre-queue all 3 IBIs before any are serviced
    # -----------------------------------------------------------------
    dut._log.info("Phase 1: Pre-queuing 3 IBIs")

    # Disable IBI acceptance so none fire while we queue
    i3c_controller.enable_ibi(False)

    for i, (mdb, data) in enumerate(ibi_vectors):
        dut._log.info(f"  Queuing IBI #{i}: MDB=0x{mdb:02X}, data={data}")
        await send_ibi(tb, mdb, data)

    await ClockCycles(tb.clk, 20)

    # Verify IBI is pending (descriptor_ibi picked up first descriptor)
    await check_pending_interrupt(tb, 1)

    # -----------------------------------------------------------------
    # Phase 2: Let DUT attempt IBI #0 -- controller NACKs it
    # -----------------------------------------------------------------
    dut._log.info("Phase 2: NACK IBI #0, exhaust retries")

    # Wait for NACK
    result = await i3c_controller.wait_for_ibi_event()
    assert result["ack"] is False, f"Expected NACK, got ACK"
    assert result["addr"] == TARGET_ADDRESS, (
        f"Expected addr 0x{TARGET_ADDRESS:02X}, got 0x{result['addr']:02X}")

    # After NACK: retry_cnt increments 0->1. retry_num=0, so 1 > 0 -> exhausted.
    # Target FSM: IbiReadAck -> WaitRestart -> (STOP) -> Idle
    # In Idle: ibi_pending=1, !ibi_can_retry -> IbiFailureRetry
    # Inhibit enters InhibitRetry, suppressing further attempts.
    await ClockCycles(tb.clk, 200)
    await check_ibi_status(tb, 3, "IbiFailureRetry after NACK")

    # IBI data is still in descriptor_ibi (WriteMdb), pending should remain
    await check_pending_interrupt(tb, 1)

    # -----------------------------------------------------------------
    # Phase 3: FW resets retry counter, controller accepts all IBIs
    # -----------------------------------------------------------------
    dut._log.info("Phase 3: FW resets retry counter, accepting all IBIs")

    # Re-enable controller acceptance BEFORE resetting counter to ensure
    # the retried IBI is accepted immediately
    i3c_controller.enable_ibi(True)

    # Reset retry counter: cnt=0 -> ibi_can_retry=true -> InhibitRetry releases
    # -> target FSM retries the SAME IBI #0 on next bus_available
    await reset_ibi_retry_counter(tb)

    # Accept IBI #0 (retried -- same MDB and data)
    mdb0, data0 = ibi_vectors[0]
    response = await with_timeout(i3c_controller.wait_for_ibi(), 20, "us")
    await verify_ibi_response(dut, response, TARGET_ADDRESS, mdb0, data0)
    await check_ibi_status(tb, 0, "IBI #0 success after retry reset")
    dut._log.info(f"  IBI #0 accepted: MDB=0x{mdb0:02X}")

    # Accept IBI #1 (auto-advanced from FIFO)
    mdb1, data1 = ibi_vectors[1]
    response = await with_timeout(i3c_controller.wait_for_ibi(), 20, "us")
    await verify_ibi_response(dut, response, TARGET_ADDRESS, mdb1, data1)
    await check_ibi_status(tb, 0, "IBI #1 success")
    dut._log.info(f"  IBI #1 accepted: MDB=0x{mdb1:02X}")

    # Accept IBI #2 (auto-advanced from FIFO)
    mdb2, data2 = ibi_vectors[2]
    response = await with_timeout(i3c_controller.wait_for_ibi(), 20, "us")
    await verify_ibi_response(dut, response, TARGET_ADDRESS, mdb2, data2)
    await check_ibi_status(tb, 0, "IBI #2 success")
    dut._log.info(f"  IBI #2 accepted: MDB=0x{mdb2:02X}")

    # -----------------------------------------------------------------
    # Phase 4: Sanity -- fresh IBI after full drain
    # -----------------------------------------------------------------
    dut._log.info("Phase 4: Sanity IBI after drain")

    await check_pending_interrupt(tb, 0)

    mdb_fresh = 0xDD
    data_fresh = [0x88, 0x99]
    await send_ibi(tb, mdb_fresh, data_fresh)
    response = await with_timeout(i3c_controller.wait_for_ibi(), 20, "us")
    await verify_ibi_response(dut, response, TARGET_ADDRESS, mdb_fresh, data_fresh)
    await check_ibi_status(tb, 0, "fresh IBI success")
    dut._log.info("  Fresh IBI accepted -- pipeline clean")

    await ClockCycles(tb.clk, 10)
    await tb.teardown()


# =============================================================================
# Test 2: Partial abort on first IBI, remaining IBIs auto-advance from FIFO
# =============================================================================

@cocotb.test()
async def test_ibi_multi_queue_partial_then_continue(dut):
    """
    Pre-queue 3 IBIs, controller truncates first IBI (partial read), then
    the remaining 2 IBIs auto-advance from the FIFO without FW intervention.

    Verifies:
    - Partial abort triggers descriptor_ibi Flush -> Idle auto-advance
    - Next queued IBI descriptor is picked up from FIFO automatically
    - Target does NOT repeat the partially-aborted IBI (Sec 5.1.6.2 item 1.a)
    - All remaining IBIs are delivered with correct data
    """
    i3c_controller, _, tb = await test_setup(dut)
    await init_ibi(i3c_controller, tb)

    # IBI #0 has 6 bytes payload (will be truncated to 2)
    # IBI #1 and #2 have smaller payloads
    ibi_vectors = [
        (0xA1, [0x10, 0x20, 0x30, 0x40, 0x50, 0x60]),
        (0xB2, [0x70, 0x80]),
        (0xC3, [0x90, 0xA0, 0xB0]),
    ]

    # -----------------------------------------------------------------
    # Phase 1: Pre-queue all 3 IBIs
    # -----------------------------------------------------------------
    dut._log.info("Phase 1: Pre-queuing 3 IBIs")
    for i, (mdb, data) in enumerate(ibi_vectors):
        dut._log.info(f"  Queuing IBI #{i}: MDB=0x{mdb:02X}, len={len(data)}")
        await send_ibi(tb, mdb, data)

    await ClockCycles(tb.clk, 10)

    # -----------------------------------------------------------------
    # Phase 2: Truncate IBI #0 (controller reads MDB + 2 data bytes only)
    # -----------------------------------------------------------------
    dut._log.info("Phase 2: Partial read on IBI #0")

    i3c_controller.set_max_ibi_data_len(2)

    mdb0, data0 = ibi_vectors[0]
    response = await with_timeout(i3c_controller.wait_for_ibi(), 20, "us")

    # Controller should have received only MDB + first 2 data bytes
    expected_truncated = bytearray([TARGET_ADDRESS, mdb0] + data0[:2])
    assert response == expected_truncated, (
        f"Truncated IBI mismatch: expected {expected_truncated.hex()}, "
        f"got {response.hex()}")
    dut._log.info(f"  IBI #0 truncated: got {len(response)-2} data bytes (expected 2)")

    # Status should be IbiFailurePartialData (2)
    await ClockCycles(tb.clk, 50)
    await check_ibi_status(tb, 2, "IBI #0 partial abort")

    # Target must NOT repeat the aborted IBI (Sec 5.1.6.2)
    await expect_no_ibi(i3c_controller, 2)

    # -----------------------------------------------------------------
    # Phase 3: Accept remaining IBIs (auto-advanced from FIFO)
    # -----------------------------------------------------------------
    dut._log.info("Phase 3: Accept remaining IBIs (auto-advance)")

    # Restore unlimited data length
    i3c_controller.set_max_ibi_data_len(65536)

    # IBI #1 should fire automatically after descriptor_ibi flushed IBI #0
    mdb1, data1 = ibi_vectors[1]
    response = await with_timeout(i3c_controller.wait_for_ibi(), 20, "us")
    await verify_ibi_response(dut, response, TARGET_ADDRESS, mdb1, data1)
    await check_ibi_status(tb, 0, "IBI #1 success (auto-advanced)")
    dut._log.info(f"  IBI #1 accepted: MDB=0x{mdb1:02X}")

    # IBI #2 should fire automatically
    mdb2, data2 = ibi_vectors[2]
    response = await with_timeout(i3c_controller.wait_for_ibi(), 20, "us")
    await verify_ibi_response(dut, response, TARGET_ADDRESS, mdb2, data2)
    await check_ibi_status(tb, 0, "IBI #2 success (auto-advanced)")
    dut._log.info(f"  IBI #2 accepted: MDB=0x{mdb2:02X}")

    # Pipeline should be drained
    await ClockCycles(tb.clk, 50)
    await check_pending_interrupt(tb, 0)
    dut._log.info("  All IBIs drained, FIFO empty")

    await ClockCycles(tb.clk, 10)
    await tb.teardown()


# =============================================================================
# Test 3: Mixed abort types -- partial auto-advance + NACK retry reset
# =============================================================================

@cocotb.test()
async def test_ibi_multi_queue_mixed_abort(dut):
    """
    Pre-queue 4 IBIs, exercise both abort types in sequence:
    - IBI #0: Partial abort (truncated read) -> auto-advance via Flush
    - IBI #1: Accept fully -> success
    - IBI #2: NACK + retry exhaust -> FW resets counter -> retry succeeds
    - IBI #3: Accept fully -> success (auto-advanced after IBI #2 completes)

    Verifies both abort paths work correctly in a single sequence with
    interleaved recovery mechanisms.
    """
    i3c_controller, _, tb = await test_setup(dut)

    # Start with retry_num=7 (infinite) for initial IBIs
    await init_ibi(i3c_controller, tb, retry_num=7)

    ibi_vectors = [
        (0xD0, [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]),  # 8 bytes, truncate
        (0xD1, [0x10, 0x20]),                                        # 2 bytes, accept
        (0xD2, [0x30, 0x40, 0x50]),                                  # 3 bytes, NACK
        (0xD3, [0x60]),                                              # 1 byte, accept
    ]

    # -----------------------------------------------------------------
    # Phase 1: Pre-queue all 4 IBIs
    # -----------------------------------------------------------------
    dut._log.info("Phase 1: Pre-queuing 4 IBIs")
    for i, (mdb, data) in enumerate(ibi_vectors):
        dut._log.info(f"  Queuing IBI #{i}: MDB=0x{mdb:02X}, len={len(data)}")
        await send_ibi(tb, mdb, data)

    await ClockCycles(tb.clk, 10)

    # -----------------------------------------------------------------
    # Phase 2: Partial abort on IBI #0
    # -----------------------------------------------------------------
    dut._log.info("Phase 2: Partial abort on IBI #0")

    i3c_controller.set_max_ibi_data_len(3)

    mdb0, data0 = ibi_vectors[0]
    response = await with_timeout(i3c_controller.wait_for_ibi(), 20, "us")
    expected_truncated = bytearray([TARGET_ADDRESS, mdb0] + data0[:3])
    assert response == expected_truncated, (
        f"Truncated IBI #0 mismatch: expected {expected_truncated.hex()}, "
        f"got {response.hex()}")
    await ClockCycles(tb.clk, 50)
    await check_ibi_status(tb, 2, "IBI #0 partial abort")
    dut._log.info(f"  IBI #0 partial: got {len(response)-2} data bytes")

    # Restore full data length for subsequent IBIs
    i3c_controller.set_max_ibi_data_len(65536)

    # -----------------------------------------------------------------
    # Phase 3: Accept IBI #1, then NACK IBI #2
    # The DUT fires IBIs back-to-back, so we must disable IBI acceptance
    # BEFORE IBI #1 completes. We use wait_for_ibi_event() to receive
    # IBI #1 while IBIs are still enabled, then immediately disable.
    # However, the bus turnaround is too fast for a SW-level disable to
    # take effect. Instead, we disable IBI acceptance before waiting for
    # IBI #1, then use the low-level event interface to see both:
    #   - IBI #1 arrives and is ACKed (because it was already in-flight)
    #   - IBI #2 arrives and is NACKed (because we disabled before it started)
    #
    # Actually, the simplest approach: accept IBI #1 with wait_for_ibi(),
    # which returns after the full IBI transaction completes and the
    # controller sends STOP. Then disable IBIs. The DUT needs
    # Bus Available (1us) before retrying, giving us time.
    # -----------------------------------------------------------------
    dut._log.info("Phase 3: Accept IBI #1, then NACK IBI #2")

    # Set retry_num=0 now -- doesn't affect IBI #1 which will succeed
    await set_ibi_retry_num(tb, 0)

    # Accept IBI #1 (auto-advanced from FIFO after Flush)
    mdb1, data1 = ibi_vectors[1]
    response = await with_timeout(i3c_controller.wait_for_ibi(), 20, "us")
    await verify_ibi_response(dut, response, TARGET_ADDRESS, mdb1, data1)
    dut._log.info(f"  IBI #1 accepted: MDB=0x{mdb1:02X}")

    # Disable IBI acceptance. The DUT needs Bus Available (1us at 12.5MHz)
    # before attempting IBI #2, so we have time to disable.
    i3c_controller.enable_ibi(False)
    i3c_controller.reset_ibi_state()

    # -----------------------------------------------------------------
    # Phase 4: NACK IBI #2, exhaust retries, FW resets, controller accepts
    # -----------------------------------------------------------------
    dut._log.info("Phase 4: NACK IBI #2, then FW retry reset")

    # Wait for IBI #2 NACK
    result = await i3c_controller.wait_for_ibi_event()
    assert result["ack"] is False, "Expected NACK for IBI #2"
    assert result["addr"] == TARGET_ADDRESS

    # Wait for retry exhaustion
    await ClockCycles(tb.clk, 200)
    await check_ibi_status(tb, 3, "IBI #2 IbiFailureRetry")
    dut._log.info("  IBI #2 NACKed, retries exhausted")

    # Re-enable acceptance and reset retry counter
    i3c_controller.enable_ibi(True)
    await reset_ibi_retry_counter(tb)

    # IBI #2 should now retry and succeed
    mdb2, data2 = ibi_vectors[2]
    response = await with_timeout(i3c_controller.wait_for_ibi(), 20, "us")
    await verify_ibi_response(dut, response, TARGET_ADDRESS, mdb2, data2)
    await check_ibi_status(tb, 0, "IBI #2 success after retry reset")
    dut._log.info(f"  IBI #2 accepted after retry reset: MDB=0x{mdb2:02X}")

    # -----------------------------------------------------------------
    # Phase 5: Accept IBI #3 (auto-advanced from FIFO)
    # -----------------------------------------------------------------
    dut._log.info("Phase 5: Accept IBI #3 (auto-advanced)")

    mdb3, data3 = ibi_vectors[3]
    response = await with_timeout(i3c_controller.wait_for_ibi(), 20, "us")
    await verify_ibi_response(dut, response, TARGET_ADDRESS, mdb3, data3)
    await check_ibi_status(tb, 0, "IBI #3 success")
    dut._log.info(f"  IBI #3 accepted: MDB=0x{mdb3:02X}")

    # Pipeline should be fully drained
    await ClockCycles(tb.clk, 50)
    await check_pending_interrupt(tb, 0)
    dut._log.info("  All 4 IBIs processed, pipeline clean")

    await ClockCycles(tb.clk, 10)
    await tb.teardown()
