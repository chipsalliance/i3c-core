# SPDX-License-Identifier: Apache-2.0
"""
Fixed I3C Target with CCC Support

This module extends the I3CTarget from cocotbext-i3c to handle Common Command
Codes (CCCs). The base I3CTarget ignores all CCCs -- it receives the CCC byte
but then waits for Sr/P without responding. This subclass overrides
handle_message() and wait_header() to:
  - Respond to directed CCC reads (GETPID)
  - Track pending CCC state across Repeated STARTs within a frame

Usage:
    Instead of:
        from cocotbext_i3c.i3c_target import I3CTarget
    Use:
        from i3c_target_fixed import I3CTargetFixed as I3CTarget

    The constructor accepts additional keyword arguments for device properties:
        pid  -- 48-bit Provisioned ID (default 0x000000000000)
"""

import logging

from cocotbext_i3c.i3c_target import I3CTarget, I3cHeader
from cocotbext_i3c.common import (
    I3C_RSVD_BYTE,
    I3cState,
)


class I3CTargetFixed(I3CTarget):
    """I3CTarget with CCC command handling."""

    # Directed CCC codes (read)
    CCC_GETPID = 0x8D

    # Sets of CCC codes by type
    DIRECTED_READ_CCCS = {CCC_GETPID}
    DIRECTED_NACK_CCCS = set()

    # HDR entry CCCs (handled by base class)
    HDR_CCCS = {0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27}

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

        # CCC state tracking
        self._pending_ccc = None

        self.log.info(
            f"TARGET_FIXED:::CCC-capable target at addr="
            f"{hex(address) if address else 'None'}, "
            f"PID=0x{pid:012X}"
        )

    @property
    def pid(self):
        return self._pid

    @pid.setter
    def pid(self, value):
        self._pid = value & 0xFFFFFFFFFFFF

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
            # Check if this directed CCC should be NACKed
            if (
                self._pending_ccc is not None
                and self._pending_ccc in self.DIRECTED_NACK_CCCS
            ):
                self.log.info(
                    f"TARGET_FIXED:::NACKing directed CCC "
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
                # Broadcast phase: receive CCC byte
                self.state = I3cState.CCC
                ccc_value, next_state = await self.recv_ccc()

                if next_state == I3cState.CCC_DATA:
                    if ccc_value in self.HDR_CCCS:
                        # HDR entry -- delegate to base class HDR handling
                        self.hdr_mode = True
                        if ccc_value == 0x20:
                            self.hdr_ddr = True
                            next_state = I3cState.HDR_DDR_HEADER
                        elif ccc_value == 0x23:
                            self.hdr_bt = True
                            next_state = I3cState.HDR_BT_HEADER
                    else:
                        # Store CCC for directed phase
                        self._pending_ccc = ccc_value
                        self.log.info(
                            f"TARGET_FIXED:::Received CCC "
                            f"0x{ccc_value:02X}, waiting for Sr/P"
                        )
                        # Wait for Sr or P (defining bytes / broadcast data
                        # are passively ignored on the bus)
                        next_state = None
                        while not next_state:
                            next_state = await self.check_start_or_stop()
                        self.header = I3cHeader.NONE
                else:
                    # Sr/P arrived before CCC byte was fully received
                    self.header = I3cHeader.NONE

            case I3cHeader.READ:
                if (
                    self._pending_ccc is not None
                    and self._pending_ccc in self.DIRECTED_READ_CCCS
                ):
                    next_state = await self._handle_directed_read_ccc()
                else:
                    next_state = await self.handle_read()

            case I3cHeader.WRITE:
                next_state = await self.handle_write()

            case I3cHeader.NON_APPLICABLE:
                next_state = None
                while not next_state:
                    next_state = await self.check_start_or_stop()
                self.header = I3cHeader.NONE

            case _:
                raise Exception(
                    f"TARGET_FIXED:::Unexpected header: {self.header}"
                )

        # Clear pending CCC on STOP (end of frame)
        if next_state == I3cState.STOP:
            self._pending_ccc = None

        return next_state

    async def _handle_directed_read_ccc(self):
        """Dispatch directed read CCC to the appropriate handler."""
        ccc = self._pending_ccc

        if ccc == self.CCC_GETPID:
            return await self._send_getpid()
        else:
            self.log.error(
                f"TARGET_FIXED:::Unhandled directed read CCC: 0x{ccc:02X}"
            )
            next_state = None
            while not next_state:
                next_state = await self.check_start_or_stop()
            return next_state

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

        for i, byte in enumerate(pid_bytes):
            is_last = i == 5
            self.state = I3cState.DATA_RD
            next_state = await self.send_byte(byte, terminate=is_last)
            if next_state is not None:
                return next_state

        # Should not reach here -- send_byte with terminate=True returns
        # a next_state (RS or STOP)
        self.log.error("TARGET_FIXED:::GETPID: unexpected end of send loop")
        return I3cState.STOP
