# SPDX-License-Identifier: Apache-2.0

"""
Continuous TE error monitors for I3C SDR Target verification.

Three monitors that run passively for every test:
  1. TeErrorEventMonitor   — tracks TE0–TE5 + framing error pulses from RTL
  2. HdrRecoveryMonitor    — verifies no FIFO writes during HDR error mode
  3. PostTe2DataIntegrityMonitor — verifies no FIFO writes after TE2 until recovery

Started automatically by I3CTopTestInterface.setup(); raises immediately
on violation to fail the test.
"""

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, First


# FSM state constants (from i3c_target_fsm.sv primary_state_e)
FSM_STATE_IDLE = 0
FSM_STATE_IN_HDR_MODE = 19


class TeErrorEventMonitor:
    """Watches te0_err..te5_err + framing_err RTL signals on every clock edge.

    On any error pulse:
      - Logs the error type, simulation time, and FSM state
      - Increments per-type error counter
      - If the error type is NOT in the expected set, raises an AssertionError

    Tests that intentionally inject errors must call expect_error(n) first.
    Tests that do not inject errors leave the expected set empty, so any
    spurious TE error pulse will immediately fail the test.
    """

    _I3C = "xi3c_wrapper.i3c"
    _FSM = ("xi3c_wrapper.i3c.xcontroller.xcontroller_standby"
            ".xcontroller_standby_i3c.xi3c_target_fsm")

    TE_NAMES = {0: "TE0", 1: "TE1", 2: "TE2", 3: "TE3", 4: "TE4", 5: "TE5", 6: "FRAMING"}

    def __init__(self, dut, clk):
        self.dut = dut
        self._clk = clk
        self.error_counts = {n: 0 for n in range(7)}  # 0-5 = TE0-TE5, 6 = FRAMING
        self._running = False
        self._prev_te_vals = [0] * 7  # Track previous values for edge detection
        self._expected_types = set()  # Error types the test expects to see
        self._unexpected_errors = []  # Accumulated unexpected errors for check()

        i3c = getattr(dut, "xi3c_wrapper").i3c
        self._te_signals = [
            i3c.te0_err,
            i3c.te1_err,
            i3c.te2_err,
            i3c.te3_err,
            i3c.te4_err,
            i3c.te5_err,
            i3c.framing_err,
        ]

        fsm = (getattr(dut, "xi3c_wrapper").i3c
               .xcontroller.xcontroller_standby
               .xcontroller_standby_i3c.xi3c_target_fsm)
        self._state_d = fsm.state_d

    def expect_error(self, *error_types):
        """Declare which TE error types this test expects to see.

        Call before injecting errors. E.g.: monitor.expect_error(0, 2)
        to allow TE0 and TE2.  Any error type NOT in this set will cause
        an immediate test failure.
        """
        for n in error_types:
            self._expected_types.add(n)

    def clear_expectations(self):
        """Clear all expected error types (revert to fail-on-any-error)."""
        self._expected_types.clear()

    def check(self):
        """Call at end of test. Raises if any unexpected errors were recorded.

        Because cocotb may silently swallow exceptions from start_soon tasks,
        this provides a reliable second line of defence.
        """
        if self._unexpected_errors:
            msgs = "\n  ".join(self._unexpected_errors)
            raise AssertionError(
                f"TeErrorEventMonitor: {len(self._unexpected_errors)} "
                f"unexpected error(s):\n  {msgs}"
            )

    async def run(self):
        self._running = True
        while True:
            await RisingEdge(self._clk)
            for n, sig in enumerate(self._te_signals):
                try:
                    val = int(sig.value)
                except ValueError:
                    val = 0
                # Only count rising edges (0->1 transitions)
                if val and not self._prev_te_vals[n]:
                    fsm_state = int(self._state_d.value)
                    time_ns = cocotb.utils.get_sim_time('ns')
                    self.error_counts[n] += 1
                    self.dut._log.info(
                        f"TeErrorEventMonitor: {self.TE_NAMES[n]} error pulse "
                        f"@ {time_ns}ns, FSM state={fsm_state}, "
                        f"total {self.TE_NAMES[n]} count={self.error_counts[n]}"
                    )
                    # Fail if this error type was not expected
                    if n not in self._expected_types:
                        msg = (
                            f"TeErrorEventMonitor: UNEXPECTED {self.TE_NAMES[n]} "
                            f"error @ {time_ns}ns (FSM state={fsm_state}). "
                            f"Test did not call expect_error({n}). "
                            f"Expected types: {sorted(self._expected_types) or 'none'}"
                        )
                        self.dut._log.error(msg)
                        self._unexpected_errors.append(msg)
                        raise AssertionError(msg)
                self._prev_te_vals[n] = val

    def reset_counts(self):
        """Reset all error counters to zero."""
        for n in self.error_counts:
            self.error_counts[n] = 0


class HdrRecoveryMonitor:
    """Watches in_hdr_err_mode_o — while asserted, no RX FIFO writes allowed.

    HDR error mode is entered on TE0 or TE1 errors. The target goes deaf
    until HDR Exit Pattern or 60us timeout. During this time, no data
    should reach the RX FIFO.
    """

    def __init__(self, dut):
        self.dut = dut
        self._running = False
        self.entry_count = 0
        self.recovery_count = 0

        ccc = (getattr(dut, "xi3c_wrapper").i3c
               .xcontroller.xcontroller_standby
               .xcontroller_standby_i3c.xccc)
        self._in_hdr_err_mode = ccc.in_hdr_err_mode_o

        tti = getattr(dut, "xi3c_wrapper").i3c.xtti
        self._rx_data_write = tti.rx_data_queue_write_r
        self._rx_desc_write = tti.rx_desc_queue_write_r

    async def run(self):
        self._running = True
        while True:
            # Wait for HDR error mode to assert
            await RisingEdge(self._in_hdr_err_mode)
            self.entry_count += 1
            entry_time = cocotb.utils.get_sim_time('ns')
            self.dut._log.info(
                f"HdrRecoveryMonitor: HDR error mode ENTERED @ {entry_time}ns "
                f"(entry #{self.entry_count})"
            )

            # While in HDR error mode, check for illegal FIFO writes
            while True:
                result = await First(
                    RisingEdge(self._rx_data_write),
                    RisingEdge(self._rx_desc_write),
                    FallingEdge(self._in_hdr_err_mode),
                )

                # Check if we exited HDR error mode
                try:
                    hdr_err = int(self._in_hdr_err_mode.value)
                except ValueError:
                    break
                if not hdr_err:
                    self.recovery_count += 1
                    exit_time = cocotb.utils.get_sim_time('ns')
                    self.dut._log.info(
                        f"HdrRecoveryMonitor: HDR error mode EXITED @ {exit_time}ns "
                        f"(duration={exit_time - entry_time}ns)"
                    )
                    break

                # Still in HDR error mode — check for illegal FIFO writes
                try:
                    data_w = int(self._rx_data_write.value)
                    desc_w = int(self._rx_desc_write.value)
                except ValueError:
                    continue
                if data_w or desc_w:
                    sigs = []
                    if data_w:
                        sigs.append("rx_data_queue_write_r")
                    if desc_w:
                        sigs.append("rx_desc_queue_write_r")
                    time_ns = cocotb.utils.get_sim_time('ns')
                    msg = (
                        f"HdrRecoveryMonitor: FIFO write during HDR error mode! "
                        f"{', '.join(sigs)} @ {time_ns}ns"
                    )
                    self.dut._log.error(msg)
                    raise AssertionError(msg)


class PostTe2DataIntegrityMonitor:
    """After TE2 error, monitors for FIFO data writes in the SAME transaction.

    TE2 (parity error on write data) should cause the target to discard
    the corrupted byte. FIFO data writes after TE2 and before the FSM
    returns to idle are protocol violations — they indicate corrupted data
    may have reached the queue.

    Uses clock-edge sampling (not RisingEdge on te2_err) to match RTL
    behavior: the te2_err_priv_wr signal can glitch for one delta cycle
    during the RxPWriteData->RxPWriteTbit FSM transition when the stale
    byte-done coincides with the new state_q.  All RTL consumers of
    te2_err are registered, so the glitch is harmless in hardware.
    Sampling at the clock edge filters these transient glitches.

    Raises AssertionError immediately on violation, and provides a check()
    method as a safety net for cases where cocotb swallows the exception.
    """

    def __init__(self, dut, clk):
        self.dut = dut
        self._clk = clk
        self._running = False
        self.violation_count = 0
        self._violations = []

        i3c = getattr(dut, "xi3c_wrapper").i3c
        self._te2_err = i3c.te2_err
        self._rx_data_write = i3c.xtti.rx_data_queue_write_r

        fsm = (i3c.xcontroller.xcontroller_standby
               .xcontroller_standby_i3c.xi3c_target_fsm)
        self._state_d = fsm.state_d

    async def run(self):
        self._running = True
        te2_prev = 0
        while True:
            await RisingEdge(self._clk)

            # Sample te2_err at clock edge (like RTL interrupt module)
            try:
                te2_curr = int(self._te2_err.value)
            except ValueError:
                te2_prev = 0
                continue

            if te2_curr and not te2_prev:
                # Registered rising edge detected — real TE2 event
                te2_time = cocotb.utils.get_sim_time('ns')
                self.dut._log.info(
                    f"PostTe2DataIntegrityMonitor: TE2 pulse @ {te2_time}ns, "
                    f"monitoring for FIFO writes until FSM idle"
                )

                # Wait for te2_err to deassert
                while True:
                    await RisingEdge(self._clk)
                    try:
                        if not int(self._te2_err.value):
                            break
                    except ValueError:
                        break

                # Monitor until FSM returns to idle
                while True:
                    await RisingEdge(self._clk)
                    try:
                        fsm_state = int(self._state_d.value)
                    except ValueError:
                        continue

                    if fsm_state == FSM_STATE_IDLE:
                        break

                    try:
                        data_w = int(self._rx_data_write.value)
                    except ValueError:
                        continue
                    if data_w:
                        self.violation_count += 1
                        time_ns = cocotb.utils.get_sim_time('ns')
                        msg = (
                            f"PostTe2DataIntegrityMonitor: FIFO data write after TE2 "
                            f"rx_data_queue_write_r=1 @ {time_ns}ns "
                            f"(TE2 was at {te2_time}ns, FSM state={fsm_state})"
                        )
                        self._violations.append(msg)
                        self.dut._log.error(msg)
                        raise AssertionError(msg)

                # Reset for next detection
                te2_prev = 0
                continue

            te2_prev = te2_curr

    def check(self):
        """End-of-test check: assert no post-TE2 FIFO writes were observed.

        Safety net in case cocotb swallowed the inline AssertionError.
        """
        if self._violations:
            msg = (
                f"PostTe2DataIntegrityMonitor: {self.violation_count} "
                f"violation(s) detected:\n  "
                + "\n  ".join(self._violations)
            )
            raise AssertionError(msg)
