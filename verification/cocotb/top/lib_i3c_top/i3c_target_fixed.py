# SPDX-License-Identifier: Apache-2.0
"""
Fixed I3C Target with CCC Support, Premature STOP Resilience, and SDA Read Timer

This module extends the I3CTarget from cocotbext-i3c to handle Common Command
Codes (CCCs). The base I3CTarget ignores all CCCs -- it receives the CCC byte
but then waits for Sr/P without responding. This subclass overrides
handle_message() and wait_header() to:
  - Respond to directed CCC reads (currently GETPID; more to come)
  - NACK unsupported directed CCCs per spec 5.1.9.2.2
  - Track pending CCC state across Repeated STARTs within a frame
  - Reject CCCs that are prohibited in HDR mode per spec Table 62

Additionally, this subclass overrides send_bit() and send_byte() to handle
premature STOP during target-driven data phases. Per spec 5.1.9.2.1:
  "If the Controller invalidly terminates the data associated with a CCC
   prematurely, then the Target shall use best efforts to handle the
   termination and ascertain the proper course of action."

The base I3CTarget hangs forever if STOP arrives mid-byte during a directed
read response because send_bit() awaits FallingEdge(scl_i) which never comes
after STOP. This subclass races each SCL-edge await against STOP detection
(SDA rising while SCL is high) with a timeout fallback for bus-idle.

SDA Read Detector Timer (spec S5.1.2.3 Note):
  "A Target should have an SDA Read detector that determines if the SCL
   clock has not changed for 100 us or more, so that it can abandon the
   read by switching SDA to High-Z and waiting for Repeated START or STOP."

During target-driven data phases (private read, CCC directed read), the
SCL-edge await uses the SDA read timer (default 100us) instead of the short
premature-STOP timeout.  On expiry, the target releases SDA to Hi-Z and
waits for Sr or STOP before returning.

Usage:
    Instead of:
        from cocotbext_i3c.i3c_target import I3CTarget
    Use:
        from i3c_target_fixed import I3CTargetFixed as I3CTarget

    The constructor accepts additional keyword arguments for device properties:
        pid                -- 48-bit Provisioned ID (default 0x000000000000)
        sda_read_timeout_us -- SDA read timer threshold in microseconds
                               (default 100, per spec S5.1.2.3 Note)
"""

import logging

from cocotb.triggers import (
    FallingEdge,
    First,
    ReadOnly,
    RisingEdge,
    Timer,
)

from cocotbext_i3c.i3c_target import I3CTarget, I3cHeader
from cocotbext_i3c.common import (
    I3C_RSVD_BYTE,
    I3cState,
)

from ccc import CCC


class BusAbortError(Exception):
    """Raised when SCL stops toggling (premature STOP or bus abort).

    The base I3CTarget awaits FallingEdge/RisingEdge(scl_i) which hang
    forever if the controller issues STOP mid-byte. This exception is
    raised by the per-edge timeout helpers and caught by send_byte() to
    cleanly return I3cState.STOP.
    """


class SdaReadTimerExpired(Exception):
    """Raised when SCL has not toggled for >= sda_read_timeout during a read.

    Per I3C spec S5.1.2.3 Note:
      "A Target should have an SDA Read detector that determines if the
       SCL clock has not changed for 100 us or more, so that it can
       abandon the read by switching SDA to High-Z and waiting for
       Repeated START or STOP."

    When caught, the target releases SDA and waits for Sr or STOP.
    """


class I3CTargetFixed(I3CTarget):
    """I3CTarget with CCC command handling."""

    # Single set of all directed CCCs this target supports.
    # Any directed CCC not in this set will be NACKed per spec 5.1.9.2.2:
    # "If the Target detects an unsupported Direct CCC, then the Target
    #  shall generate NACK after its own matched Address"
    SUPPORTED_DIRECTED_CCCS = {
        # Directed Read (GET) CCCs
        CCC.DIRECT.GETPID,
        CCC.DIRECT.GETBCR,
        CCC.DIRECT.GETDCR,
        CCC.DIRECT.GETSTATUS,
        CCC.DIRECT.GETMWL,
        CCC.DIRECT.GETMRL,
        CCC.DIRECT.GETCAPS,
        CCC.DIRECT.GETMXDS,
        # Directed Write (SET) CCCs
        CCC.DIRECT.ENEC,
        CCC.DIRECT.DISEC,
        CCC.DIRECT.SETMWL,
        CCC.DIRECT.SETMRL,
        CCC.DIRECT.SETNEWDA,
        CCC.DIRECT.SETDASA,
        # Directed Read/Write CCCs
        CCC.DIRECT.RSTACT,
    }

    # HDR entry CCCs
    HDR_CCCS = {
        CCC.BCAST.ENTHDR0, CCC.BCAST.ENTHDR1, CCC.BCAST.ENTHDR2,
        CCC.BCAST.ENTHDR3, CCC.BCAST.ENTHDR4, CCC.BCAST.ENTHDR5,
        CCC.BCAST.ENTHDR6, CCC.BCAST.ENTHDR7,
    }

    # CCCs NOT permitted in any HDR mode (spec Table 62, section 5.2.1.2).
    # Broadcast CCCs prohibited in HDR:
    #   RSTDAA(0x06), ENTDAA(0x07), ENTTM(0x0B), ENTHDR0-7(0x20-0x27),
    #   SETAASA(0x29)
    HDR_PROHIBITED_BCAST_CCCS = {
        CCC.BCAST.RSTDAA,
        CCC.BCAST.ENTDAA,
        CCC.BCAST.ENTTM,
        CCC.BCAST.ENTHDR0, CCC.BCAST.ENTHDR1, CCC.BCAST.ENTHDR2,
        CCC.BCAST.ENTHDR3, CCC.BCAST.ENTHDR4, CCC.BCAST.ENTHDR5,
        CCC.BCAST.ENTHDR6, CCC.BCAST.ENTHDR7,
        CCC.BCAST.SETAASA,
    }

    # Directed CCCs prohibited in HDR:
    #   RSTDAA(0x86), SETDASA(0x87), SETNEWDA(0x88), GETPID(0x8D),
    #   GETACCCR(0x91)
    HDR_PROHIBITED_DIRECT_CCCS = {
        CCC.DIRECT.RSTDAA,
        CCC.DIRECT.SETDASA,
        CCC.DIRECT.SETNEWDA,
        CCC.DIRECT.GETPID,
        CCC.DIRECT.GETACCCR,
    }

    # Combined set for quick lookup
    HDR_PROHIBITED_CCCS = HDR_PROHIBITED_BCAST_CCCS | HDR_PROHIBITED_DIRECT_CCCS

    def __init__(
        self,
        sda_i,
        sda_o,
        scl_i,
        scl_o,
        debug_state_o=None,
        debug_detected_header_o=None,
        timings=None,
        speed=12.5e6,
        address=None,
        max_read_length=2,
        pid=0x000000000000,
        bcr=0x00,
        dcr=0x00,
        sda_read_timeout_us=100,
        *args,
        **kwargs,
    ):
        super().__init__(
            sda_i=sda_i,
            sda_o=sda_o,
            scl_i=scl_i,
            scl_o=scl_o,
            debug_state_o=debug_state_o,
            debug_detected_header_o=debug_detected_header_o,
            timings=timings,
            speed=speed,
            address=address,
            max_read_length=max_read_length,
            *args,
            **kwargs,
        )

        self._pid = pid & 0xFFFFFFFFFFFF
        self._bcr = bcr & 0xFF
        self._dcr = dcr & 0xFF

        # CCC state tracking
        self._pending_ccc = None

        # Per-edge timeout for premature STOP detection.
        # If SCL doesn't toggle within this many ns, we assume the
        # controller stopped clocking (STOP or bus abort).
        # 20 SCL periods with a 5us floor covers all bus speeds.
        scl_period_ns = int(1.0 / self.speed * 1e9)
        self._edge_timeout_ns = max(5000, scl_period_ns * 20)

        # SDA Read Detector Timer (spec S5.1.2.3 Note).
        # During target-driven reads, if SCL does not toggle for this
        # duration, the target abandons the read (releases SDA to Hi-Z)
        # and waits for Sr or STOP.
        if sda_read_timeout_us <= 0:
            raise ValueError(
                f"sda_read_timeout_us must be > 0, got {sda_read_timeout_us}"
            )
        self._sda_read_timeout_ns = int(sda_read_timeout_us * 1000)

        # Flag: True when the target is driving SDA during a read transfer.
        # Controls which timeout/exception is used in edge helpers.
        self._in_read_transfer = False

        self.log.info(
            f"TARGET_FIXED:::CCC-capable target at addr="
            f"{hex(address) if address else 'None'}, "
            f"PID=0x{pid:012X}, BCR=0x{bcr:02X}, DCR=0x{dcr:02X}, "
            f"sda_read_timeout={sda_read_timeout_us}us"
        )

    @property
    def pid(self):
        return self._pid

    @pid.setter
    def pid(self, value):
        self._pid = value & 0xFFFFFFFFFFFF

    def _is_ccc_prohibited_in_hdr(self, ccc_value):
        """Check if a CCC is prohibited in HDR mode per spec Table 62.

        Returns True if self.hdr_mode is active and ccc_value is in the
        HDR_PROHIBITED_CCCS set. Logs an error when a prohibited CCC
        is detected.
        """
        if not self.hdr_mode:
            return False
        if ccc_value in self.HDR_PROHIBITED_CCCS:
            self.log.error(
                f"TARGET_FIXED:::CCC 0x{ccc_value:02X} is prohibited in "
                f"HDR mode (spec Table 62, section 5.2.1.2)"
            )
            return True
        return False

    async def handle_read(self):
        """Override: private read with SDA read timer active.

        Wraps the base class handle_read() with the _in_read_transfer
        flag so that the SDA read timer (spec S5.1.2.3 Note) is used
        for SCL-edge timeouts during target-driven data phases.
        """
        self._in_read_transfer = True
        try:
            return await super().handle_read()
        finally:
            self._in_read_transfer = False

    # -----------------------------------------------------------------
    # Premature STOP resilience -- per-edge timeout
    # SDA Read Detector Timer -- spec S5.1.2.3 Note
    # -----------------------------------------------------------------
    # The base I3CTarget's send_bit() awaits FallingEdge(scl_i) which
    # hangs forever if the controller issues STOP mid-byte (no more SCL
    # toggles).  We override send_bit() and send_byte() to race every
    # SCL-edge await against a Timer.  If the timer fires first (SCL
    # didn't toggle), we raise an exception.
    #
    # During target-driven read phases (_in_read_transfer == True), the
    # SDA read timer (100us default) supersedes the short edge timeout
    # and raises SdaReadTimerExpired.  Outside reads, the short timeout
    # raises BusAbortError for premature STOP detection.
    # -----------------------------------------------------------------

    async def _await_falling_scl(self):
        """FallingEdge(scl_i) with timeout.

        During reads: uses SDA read timer, raises SdaReadTimerExpired.
        Outside reads: uses edge timeout, raises BusAbortError.
        """
        if self._in_read_transfer:
            timeout_ns = self._sda_read_timeout_ns
        else:
            timeout_ns = self._edge_timeout_ns

        await First(
            FallingEdge(self.scl_i),
            Timer(timeout_ns, units='ns'),
        )
        if self.scl:
            if self._in_read_transfer:
                raise SdaReadTimerExpired(
                    f"SCL did not fall within {timeout_ns}ns "
                    f"(SDA read timer, spec S5.1.2.3)"
                )
            raise BusAbortError("SCL did not fall within timeout")

    async def _await_rising_scl(self):
        """RisingEdge(scl_i) with timeout.

        During reads: uses SDA read timer, raises SdaReadTimerExpired.
        Outside reads: uses edge timeout, raises BusAbortError.
        """
        if self._in_read_transfer:
            timeout_ns = self._sda_read_timeout_ns
        else:
            timeout_ns = self._edge_timeout_ns

        await First(
            RisingEdge(self.scl_i),
            Timer(timeout_ns, units='ns'),
        )
        if not self.scl:
            if self._in_read_transfer:
                raise SdaReadTimerExpired(
                    f"SCL did not rise within {timeout_ns}ns "
                    f"(SDA read timer, spec S5.1.2.3)"
                )
            raise BusAbortError("SCL did not rise within timeout")

    async def send_bit(self, bit: bool):
        """Override: send one bit with per-edge abort detection.

        Raises BusAbortError if SCL stops toggling (premature STOP).
        """
        if self.scl:
            await self._await_falling_scl()
        self.sda = bool(bit)
        await self._await_falling_scl()
        self.sda = 1

    async def send_byte(self, byte: int, terminate: bool):
        """Override: send one byte + T-bit with abort detection.

        If BusAbortError is raised by send_bit() or edge helpers,
        we release SDA and return I3cState.STOP.

        If SdaReadTimerExpired is raised (spec S5.1.2.3 Note), we
        release SDA to Hi-Z and wait for Sr or STOP before returning.
        """
        try:
            for i in range(8):
                await self.send_bit(byte & (1 << 7 - i))

            self.state = I3cState.TBIT_RD
            if self.scl:
                await self._await_falling_scl()

            # Drive T-bit: 0 = more data, 1 = last byte
            self.sda = not terminate
            await self._await_rising_scl()
            self.sda = 1

            # Wait for Sr or P if this was the last byte
            next_state = None
            if terminate:
                if await self.check_stop():
                    next_state = I3cState.STOP
                elif await self.check_start(repeated=True):
                    next_state = I3cState.RS

            return next_state

        except SdaReadTimerExpired:
            # Spec S5.1.2.3 Note: abandon read, release SDA to Hi-Z,
            # then wait for Repeated START or STOP.
            self.sda = 1
            self.log.info(
                "TARGET_FIXED:::SDA read timer expired -- "
                "releasing SDA to Hi-Z and waiting for Sr or STOP "
                "(spec S5.1.2.3 Note)"
            )
            # If STOP already occurred before the timer expired, the bus
            # is idle (SDA=1, SCL=1).  Detect this immediately instead
            # of blocking in _await_bus_condition() for an Sr/STOP that
            # will never come.
            await ReadOnly()
            if self.sda and self.scl:
                self.log.info(
                    "TARGET_FIXED:::Bus already idle (STOP occurred "
                    "before timer expiry) -- returning STOP"
                )
                self.state = I3cState.STOP
                return I3cState.STOP
            next_state = await self._await_bus_condition()
            self.state = next_state
            return next_state

        except BusAbortError:
            self.sda = 1
            self.state = I3cState.STOP
            self.log.info(
                "TARGET_FIXED:::Bus abort in send_byte -- "
                "premature STOP assumed"
            )
            return I3cState.STOP

    async def wait_header(self):
        """Override to allow directed CCC phases after broadcast.

        The base class asserts that self.header must be RESERVED, READ, or
        WRITE when our address is seen. But after a CCC broadcast phase,
        header is reset to NONE before the directed phase arrives. This
        override relaxes that constraint when a CCC is pending.
        """
        self.state = I3cState.ADDR
        addr_header = await self.recv(bits_num=8)
        addr, is_read = addr_header >> 1, addr_header & 0x1

        self.log.info(
            f"TARGET_FIXED:::Address: {hex(addr)} RnW: {is_read} "
            f"(pending_ccc=0x{self._pending_ccc:02X})"
            if self._pending_ccc is not None
            else f"TARGET_FIXED:::Address: {hex(addr)} RnW: {is_read}"
        )

        if addr == I3C_RSVD_BYTE:
            await self.ack()
            self.header = I3cHeader.RESERVED
        elif addr == self.address:
            # NACK unsupported directed CCCs per spec 5.1.9.2.2
            if (
                self._pending_ccc is not None
                and self._pending_ccc not in self.SUPPORTED_DIRECTED_CCCS
            ):
                self.log.info(
                    f"TARGET_FIXED:::NACKing unsupported directed CCC "
                    f"0x{self._pending_ccc:02X}"
                )
                self.header = I3cHeader.NON_APPLICABLE
            # NACK directed CCCs prohibited in HDR mode (spec Table 62)
            elif (
                self._pending_ccc is not None
                and self._is_ccc_prohibited_in_hdr(self._pending_ccc)
            ):
                self.log.info(
                    f"TARGET_FIXED:::NACKing HDR-prohibited directed CCC "
                    f"0x{self._pending_ccc:02X}"
                )
                self.header = I3cHeader.NON_APPLICABLE
            else:
                await self.ack()
                self.header = I3cHeader.READ if is_read else I3cHeader.WRITE
        else:
            self.header = I3cHeader.NON_APPLICABLE

    async def handle_message(self):
        """Override to intercept CCC commands and respond to directed reads.

        Flow for a directed CCC read (e.g., GETPID):
          1. Controller sends S + 0x7E/W + CCC byte
          2. This method stores the CCC as _pending_ccc, waits for Sr
          3. On the next handle_message() call (after Sr), wait_header()
             sees our address with R/W bit
          4. If _pending_ccc is a directed read CCC, we respond with data
        """
        await self.wait_header()

        match self.header:
            case I3cHeader.RESERVED:
                # New broadcast phase (Sr + 7'h7E/W) ends any prior Direct
                # CCC per spec 5.1.9.2.1.  Clear stale state so a subsequent
                # private transfer is not misinterpreted as a directed CCC.
                self._pending_ccc = None

                # Broadcast phase: receive CCC byte
                self.state = I3cState.CCC
                ccc_value, next_state = await self.recv_ccc()

                if next_state == I3cState.CCC_DATA:
                    if self._is_ccc_prohibited_in_hdr(ccc_value):
                        # CCC is prohibited in HDR mode (spec Table 62).
                        # Must check BEFORE HDR_CCCS since ENTHDRx are
                        # both in HDR_CCCS and HDR_PROHIBITED_CCCS.
                        self.log.info(
                            f"TARGET_FIXED:::Ignoring HDR-prohibited "
                            f"broadcast CCC 0x{ccc_value:02X}"
                        )
                        next_state = await self._await_bus_condition()
                        self.header = I3cHeader.NONE
                    elif ccc_value in self.HDR_CCCS:
                        # HDR entry
                        self.hdr_mode = True
                        if ccc_value == CCC.BCAST.ENTHDR0:
                            self.hdr_ddr = True
                            next_state = I3cState.HDR_DDR_HEADER
                        elif ccc_value == CCC.BCAST.ENTHDR3:
                            self.hdr_bt = True
                            next_state = I3cState.HDR_BT_HEADER
                        else:
                            # Unsupported HDR mode (ENTHDR1/2/4/5/6/7).
                            # Enter HDR but wait for exit since we have
                            # no handler for this sub-mode.
                            self.log.info(
                                f"TARGET_FIXED:::Unsupported HDR entry "
                                f"CCC 0x{ccc_value:02X} -- waiting for "
                                f"HDR exit"
                            )
                            next_state = await self._await_bus_condition()
                            self.header = I3cHeader.NONE
                    else:
                        # Store CCC for directed phase
                        self._pending_ccc = ccc_value
                        self.log.info(
                            f"TARGET_FIXED:::Received CCC "
                            f"0x{ccc_value:02X}, waiting for Sr/P"
                        )
                        # Wait for Sr or P (defining bytes / broadcast data
                        # are passively ignored on the bus)
                        next_state = await self._await_bus_condition()
                        self.header = I3cHeader.NONE
                else:
                    # Sr/P arrived before CCC byte was fully received
                    self.header = I3cHeader.NONE

            case I3cHeader.READ:
                if (
                    self._pending_ccc is not None
                    and self._pending_ccc in self.SUPPORTED_DIRECTED_CCCS
                ):
                    next_state = await self._handle_directed_read_ccc()
                else:
                    next_state = await self.handle_read()

            case I3cHeader.WRITE:
                next_state = await self.handle_write()

            case I3cHeader.NON_APPLICABLE:
                next_state = await self._await_bus_condition()
                self.header = I3cHeader.NONE

            case _:
                raise Exception(
                    f"TARGET_FIXED:::Unexpected header: {self.header}"
                )

        # Clear pending CCC on STOP (end of frame)
        if next_state == I3cState.STOP:
            self._pending_ccc = None

        return next_state

    async def _await_bus_condition(self):
        """Wait for the next START or STOP condition on the bus."""
        next_state = None
        while not next_state:
            next_state = await self.check_start_or_stop()
        return next_state

    async def _send_ccc_response(self, data_bytes):
        """Send a multi-byte CCC response with T-bit framing.

        Each byte is sent via the overridden send_byte() which has
        per-edge abort detection and SDA read timer support.

        The SDA read timer (spec S5.1.2.3 Note) is active during CCC
        directed reads because the target drives SDA in these phases.

        Args:
            data_bytes: Iterable of int bytes to transmit (MSB first).

        Returns:
            The next I3cState (RS or STOP) from the bus.
        """
        data_bytes = list(data_bytes)
        self._in_read_transfer = True

        try:
            for i, byte in enumerate(data_bytes):
                is_last = i == len(data_bytes) - 1
                self.state = I3cState.DATA_RD
                next_state = await self.send_byte(byte, terminate=is_last)
                if next_state is not None:
                    return next_state

            self.log.error(
                "TARGET_FIXED:::CCC response: unexpected end of send loop"
            )
            return I3cState.STOP
        finally:
            self._in_read_transfer = False

    async def _handle_directed_read_ccc(self):
        """Dispatch directed read CCC to the appropriate handler."""
        ccc = self._pending_ccc

        if ccc == CCC.DIRECT.GETPID:
            return await self._send_getpid()
        elif ccc == CCC.DIRECT.GETBCR:
            return await self._send_getbcr()
        elif ccc == CCC.DIRECT.GETDCR:
            return await self._send_getdcr()
        else:
            self.log.error(
                f"TARGET_FIXED:::Unhandled directed read CCC: 0x{ccc:02X}"
            )
            return await self._await_bus_condition()

    async def _send_getpid(self):
        """Send 6-byte GETPID response (MSB first).

        Per spec Section 5.1.9.3.12:
        The 48-bit Provisioned ID is transmitted as 6 bytes, MSB first.
        Each byte is followed by a T-bit.
        """
        pid_bytes = [
            (self._pid >> (40 - 8 * i)) & 0xFF for i in range(6)
        ]
        self.log.info(
            f"TARGET_FIXED:::GETPID response: PID=0x{self._pid:012X} "
            f"bytes={['0x%02X' % b for b in pid_bytes]}"
        )
        return await self._send_ccc_response(pid_bytes)

    async def _send_getbcr(self):
        """Send 1-byte GETBCR response.

        Per spec Section 5.1.9.3.13:
        The BCR is a single byte describing Target capabilities.
        """
        self.log.info(
            f"TARGET_FIXED:::GETBCR response: BCR=0x{self._bcr:02X}"
        )
        return await self._send_ccc_response([self._bcr])

    async def _send_getdcr(self):
        """Send 1-byte GETDCR response.

        Per spec Section 5.1.9.3.14:
        The DCR is a single byte identifying the Target device type.
        """
        self.log.info(
            f"TARGET_FIXED:::GETDCR response: DCR=0x{self._dcr:02X}"
        )
        return await self._send_ccc_response([self._dcr])
