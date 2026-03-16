# SPDX-License-Identifier: Apache-2.0
"""
Fixed I3C Target with CCC Support

This module extends the I3CTarget from cocotbext-i3c to handle Common Command
Codes (CCCs). The base I3CTarget ignores all CCCs -- it receives the CCC byte
but then waits for Sr/P without responding. This subclass overrides
handle_message() and wait_header() to:
  - Respond to directed CCC reads (GETPID, GETBCR, GETDCR, GETSTATUS, etc.)
  - Track pending CCC state across Repeated STARTs within a frame

Usage:
    Instead of:
        from cocotbext_i3c.i3c_target import I3CTarget
    Use:
        from i3c_target_fixed import I3CTargetFixed as I3CTarget

    The constructor accepts additional keyword arguments for device properties:
        pid              -- 48-bit Provisioned ID (default 0x000000000000)
        bcr              -- 8-bit Bus Characteristics Register (default 0x00)
        dcr              -- 8-bit Device Characteristics Register (default 0x00)
        max_write_length -- 16-bit Max Write Length (default 256)
        max_read_length  -- 16-bit Max Read Length (default 256)
        max_ibi_payload  -- 8-bit Max IBI Payload Size (default 0, unlimited)
        getcaps_bytes    -- list of 2-4 GETCAPS bytes (default [0x00, 0x01])
        getmxds_bytes    -- list of 2 or 5 GETMXDS bytes (default [0x00, 0x00])
"""

import logging

from cocotbext_i3c.i3c_target import I3CTarget, I3cHeader
from cocotbext_i3c.common import (
    I3C_RSVD_BYTE,
    I3cState,
)

from ccc import CCC


class I3CTargetFixed(I3CTarget):
    """I3CTarget with CCC command handling."""

    # Sets of CCC codes by type -- derived from the shared CCC dictionary
    DIRECTED_READ_CCCS = {
        CCC.DIRECT.GETPID,
        CCC.DIRECT.GETBCR,
        CCC.DIRECT.GETDCR,
        CCC.DIRECT.GETSTATUS,
        CCC.DIRECT.GETMWL,
        CCC.DIRECT.GETMRL,
        CCC.DIRECT.GETCAPS,
        CCC.DIRECT.GETMXDS,
    }
    DIRECTED_NACK_CCCS = set()

    # HDR entry CCCs (handled by base class)
    HDR_CCCS = {
        CCC.BCAST.ENTHDR0, CCC.BCAST.ENTHDR1, CCC.BCAST.ENTHDR2,
        CCC.BCAST.ENTHDR3, CCC.BCAST.ENTHDR4, CCC.BCAST.ENTHDR5,
        CCC.BCAST.ENTHDR6, CCC.BCAST.ENTHDR7,
    }

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
        max_write_length=256,
        max_rd_length=256,
        max_ibi_payload=0,
        getcaps_bytes=None,
        getmxds_bytes=None,
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

        # Device identity
        self._pid = pid & 0xFFFFFFFFFFFF
        self._bcr = bcr & 0xFF
        self._dcr = dcr & 0xFF

        # Max data lengths (spec 5.1.9.3.5 / 5.1.9.3.6)
        self._max_write_length = max_write_length & 0xFFFF
        self._max_rd_length = max_rd_length & 0xFFFF
        self._max_ibi_payload = max_ibi_payload & 0xFF

        # GETSTATUS state (spec 5.1.9.3.15, Table 27)
        self._vendor_status = 0x00       # bits[15:8]
        self._activity_mode = 0          # bits[7:6], 2-bit
        self._protocol_error = False     # bit[5], self-clears on read
        self._pending_interrupt = 0      # bits[3:0], 4-bit

        # GETCAPS response bytes (spec 5.1.9.3.19, Tables 35-38)
        # Default: HDR Mode 0 not supported, I3C Basic v1.1 (minor=1)
        self._getcaps_bytes = list(getcaps_bytes or [0x00, 0x01])

        # GETMXDS response bytes (spec 5.1.9.3.18, Tables 30-32)
        # Default: no speed limitations
        self._getmxds_bytes = list(getmxds_bytes or [0x00, 0x00])

        # CCC state tracking
        self._pending_ccc = None

        self.log.info(
            f"TARGET_FIXED:::CCC-capable target at addr="
            f"{hex(address) if address else 'None'}, "
            f"PID=0x{pid:012X} BCR=0x{bcr:02X} DCR=0x{dcr:02X}"
        )

    # -- Property getters/setters for device characteristics --

    @property
    def pid(self):
        return self._pid

    @pid.setter
    def pid(self, value):
        self._pid = value & 0xFFFFFFFFFFFF

    @property
    def bcr(self):
        return self._bcr

    @bcr.setter
    def bcr(self, value):
        self._bcr = value & 0xFF

    @property
    def dcr(self):
        return self._dcr

    @dcr.setter
    def dcr(self, value):
        self._dcr = value & 0xFF

    @property
    def max_write_length(self):
        return self._max_write_length

    @max_write_length.setter
    def max_write_length(self, value):
        self._max_write_length = value & 0xFFFF

    @property
    def max_rd_length(self):
        return self._max_rd_length

    @max_rd_length.setter
    def max_rd_length(self, value):
        self._max_rd_length = value & 0xFFFF

    @property
    def max_ibi_payload(self):
        return self._max_ibi_payload

    @max_ibi_payload.setter
    def max_ibi_payload(self, value):
        self._max_ibi_payload = value & 0xFF

    @property
    def activity_mode(self):
        return self._activity_mode

    @activity_mode.setter
    def activity_mode(self, value):
        self._activity_mode = value & 0x3

    @property
    def pending_interrupt(self):
        return self._pending_interrupt

    @pending_interrupt.setter
    def pending_interrupt(self, value):
        self._pending_interrupt = value & 0xF

    @property
    def protocol_error(self):
        return self._protocol_error

    @protocol_error.setter
    def protocol_error(self, value):
        self._protocol_error = bool(value)

    @property
    def vendor_status(self):
        return self._vendor_status

    @vendor_status.setter
    def vendor_status(self, value):
        self._vendor_status = value & 0xFF

    @property
    def getcaps_bytes(self):
        return list(self._getcaps_bytes)

    @getcaps_bytes.setter
    def getcaps_bytes(self, value):
        self._getcaps_bytes = list(value)

    @property
    def getmxds_bytes(self):
        return list(self._getmxds_bytes)

    @getmxds_bytes.setter
    def getmxds_bytes(self, value):
        self._getmxds_bytes = list(value)

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
                        next_state = await self._await_bus_condition()
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

        Each byte is sent via send_byte(); the last byte uses terminate=True
        so the controller knows this is the final byte.

        Args:
            data_bytes: Iterable of int bytes to transmit (MSB first).

        Returns:
            The next I3cState (RS or STOP) from the bus.
        """
        data_bytes = list(data_bytes)
        for i, byte in enumerate(data_bytes):
            is_last = i == len(data_bytes) - 1
            self.state = I3cState.DATA_RD
            next_state = await self.send_byte(byte, terminate=is_last)
            if next_state is not None:
                return next_state

        self.log.error("TARGET_FIXED:::CCC response: unexpected end of send loop")
        return I3cState.STOP

    async def _handle_directed_read_ccc(self):
        """Dispatch directed read CCC to the appropriate handler."""
        ccc = self._pending_ccc

        if ccc == CCC.DIRECT.GETPID:
            return await self._send_getpid()
        elif ccc == CCC.DIRECT.GETBCR:
            return await self._send_getbcr()
        elif ccc == CCC.DIRECT.GETDCR:
            return await self._send_getdcr()
        elif ccc == CCC.DIRECT.GETSTATUS:
            return await self._send_getstatus()
        elif ccc == CCC.DIRECT.GETMWL:
            return await self._send_getmwl()
        elif ccc == CCC.DIRECT.GETMRL:
            return await self._send_getmrl()
        elif ccc == CCC.DIRECT.GETCAPS:
            return await self._send_getcaps()
        elif ccc == CCC.DIRECT.GETMXDS:
            return await self._send_getmxds()
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
        The BCR value is transmitted in one byte, MSb first.
        """
        self.log.info(
            f"TARGET_FIXED:::GETBCR response: BCR=0x{self._bcr:02X}"
        )
        return await self._send_ccc_response([self._bcr])

    async def _send_getdcr(self):
        """Send 1-byte GETDCR response.

        Per spec Section 5.1.9.3.14:
        The DCR value is transmitted in one byte, MSb first.
        """
        self.log.info(
            f"TARGET_FIXED:::GETDCR response: DCR=0x{self._dcr:02X}"
        )
        return await self._send_ccc_response([self._dcr])

    async def _send_getstatus(self):
        """Send 2-byte GETSTATUS Format 1 response.

        Per spec Section 5.1.9.3.15, Table 27:
          MSB [15:8] = Vendor Reserved
          LSB [7:6]  = Activity Mode
              [5]    = Protocol Error (self-clears on read)
              [4]    = Reserved
              [3:0]  = Pending Interrupt
        """
        lsb = (
            ((self._activity_mode & 0x3) << 6)
            | ((1 if self._protocol_error else 0) << 5)
            | (self._pending_interrupt & 0xF)
        )
        msb = self._vendor_status & 0xFF
        self.log.info(
            f"TARGET_FIXED:::GETSTATUS response: "
            f"MSB=0x{msb:02X} LSB=0x{lsb:02X} "
            f"(activity={self._activity_mode} "
            f"proto_err={self._protocol_error} "
            f"pending_int={self._pending_interrupt})"
        )
        # Protocol error self-clears after successful read (spec Table 27)
        self._protocol_error = False
        return await self._send_ccc_response([msb, lsb])

    async def _send_getmwl(self):
        """Send 2-byte GETMWL response (MSB first).

        Per spec Section 5.1.9.3.5:
        The Max Write Length value is transmitted over two bytes,
        with the MSB transmitted first.
        """
        msb = (self._max_write_length >> 8) & 0xFF
        lsb = self._max_write_length & 0xFF
        self.log.info(
            f"TARGET_FIXED:::GETMWL response: "
            f"MWL=0x{self._max_write_length:04X}"
        )
        return await self._send_ccc_response([msb, lsb])

    async def _send_getmrl(self):
        """Send 2 or 3 byte GETMRL response (MSB first).

        Per spec Section 5.1.9.3.6:
        The Max Read Length value is transmitted over two bytes (MSB first).
        For devices with BCR bit 2 set, a third byte with IBI payload size
        is appended.
        """
        msb = (self._max_rd_length >> 8) & 0xFF
        lsb = self._max_rd_length & 0xFF
        resp = [msb, lsb]

        # BCR bit[2] = IBI payload support
        if self._bcr & (1 << 2):
            resp.append(self._max_ibi_payload & 0xFF)

        self.log.info(
            f"TARGET_FIXED:::GETMRL response: "
            f"MRL=0x{self._max_rd_length:04X} "
            f"ibi_payload={'0x%02X' % self._max_ibi_payload if self._bcr & (1 << 2) else 'N/A'}"
        )
        return await self._send_ccc_response(resp)

    async def _send_getcaps(self):
        """Send 2-4 byte GETCAPS Format 1 response.

        Per spec Section 5.1.9.3.19, Tables 35-38:
        GETCAP1: HDR mode support bitmap
        GETCAP2: HDR-DDR capabilities, Group Address, I3C Basic version
        GETCAP3: Optional features (MDB, HDR-BT CRC-32, GETSTATUS DB, etc.)
        GETCAP4: Reserved
        """
        resp = list(self._getcaps_bytes)
        self.log.info(
            f"TARGET_FIXED:::GETCAPS response: "
            f"bytes={['0x%02X' % b for b in resp]}"
        )
        return await self._send_ccc_response(resp)

    async def _send_getmxds(self):
        """Send 2 or 5 byte GETMXDS response.

        Per spec Section 5.1.9.3.18:
        Format 1 (2 bytes): maxWr, maxRd
        Format 2 (5 bytes): maxWr, maxRd, 3-byte maxRdTurn
        """
        resp = list(self._getmxds_bytes)
        self.log.info(
            f"TARGET_FIXED:::GETMXDS response: "
            f"bytes={['0x%02X' % b for b in resp]}"
        )
        return await self._send_ccc_response(resp)
