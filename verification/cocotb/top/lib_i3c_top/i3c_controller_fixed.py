# SPDX-License-Identifier: Apache-2.0
"""
Fixed I3C Controller

This module provides extensions to the I3cController from cocotbext-i3c that add
arbitration-aware IBI handling, chaining, and stress testing.

Key Features:
    - Arbitration-aware write_addr_header: detects IBI during S->0x7E phase
      per I3C spec Sec.5.1.2.2.1 and handles it inline
    - Automatic IBI retry in i3c_write/i3c_read/i3c_ccc_write/i3c_ccc_read
    - One-shot IBI chaining knobs: CCC, Private Write, skip_data, max_data
    - Unified _handle_ibi_inline replaces both background _handle_ibi and
      the former handle_ibi_manual
    - Target reset pattern stress testing methods

Usage:
    Instead of:
        from cocotbext_i3c.i3c_controller import I3cController

    Use:
        from i3c_controller_fixed import I3cControllerFixed as I3cController
"""

import cocotb
from typing import Iterable, Optional

from cocotbext_i3c.i3c_controller import I3cController, I3cXferMode
from cocotbext_i3c.common import I3C_RSVD_BYTE, I3cPRResp, I3cPWResp, I3cState
from cocotb.triggers import Event, FallingEdge, Timer, NextTimeStep

# Sentinel raised when write_addr_header detects an IBI during the 0x7E phase
class IbiArbitrationEvent(Exception):
    pass

# Max retries when IBI keeps firing during transfer Start->0x7E
_MAX_IBI_RETRIES = 10


class I3cControllerFixed(I3cController):
    """
    Extended I3cController with arbitration-aware IBI handling.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # IBI result state
        self.last_ibi_result = None
        self.ibi_nack_count = 0
        self._ibi_event = Event()
        # One-shot IBI chaining knobs (consumed after next IBI)
        self._ibi_chain_ccc = None
        self._ibi_chain_ccc_data = None
        self._ibi_chain_ccc_addr = None
        self._ibi_chain_write_addr = None
        self._ibi_chain_write_data = None
        self._ibi_skip_data = False
        self._ibi_max_data = None

    # =========================================================================
    # IBI CHAINING CONFIGURATION KNOBS (one-shot, consumed after next IBI)
    # =========================================================================

    def set_ibi_chain_ccc(self, ccc, ccc_data=None, ccc_addr=None):
        """Configure: after next IBI ACK/NACK, chain Sr->CCC before STOP."""
        assert self._ibi_chain_write_addr is None, \
            "Cannot set CCC chain while write chain is active"
        self._ibi_chain_ccc = ccc
        self._ibi_chain_ccc_data = ccc_data
        self._ibi_chain_ccc_addr = ccc_addr

    def set_ibi_chain_write(self, addr, data):
        """Configure: after next IBI ACK/NACK, chain Sr->Private Write before STOP."""
        assert self._ibi_chain_ccc is None, \
            "Cannot set write chain while CCC chain is active"
        self._ibi_chain_write_addr = addr
        self._ibi_chain_write_data = data

    def set_ibi_skip_data(self, skip=True):
        """Configure: after next IBI ACK, skip MDB/data read (BCR[2]=0 test)."""
        self._ibi_skip_data = skip

    def set_ibi_max_data(self, max_len):
        """Configure: limit IBI data bytes after MDB (truncation test)."""
        self._ibi_max_data = max_len

    def clear_ibi_chain(self):
        """Clear all one-shot chaining configuration."""
        self._ibi_chain_ccc = None
        self._ibi_chain_ccc_data = None
        self._ibi_chain_ccc_addr = None
        self._ibi_chain_write_addr = None
        self._ibi_chain_write_data = None
        self._ibi_skip_data = False
        self._ibi_max_data = None

    def _consume_ibi_chain(self):
        """Snapshot and clear the one-shot knobs. Returns a dict."""
        chain = {
            "ccc": self._ibi_chain_ccc,
            "ccc_data": self._ibi_chain_ccc_data,
            "ccc_addr": self._ibi_chain_ccc_addr,
            "write_addr": self._ibi_chain_write_addr,
            "write_data": self._ibi_chain_write_data,
            "skip_data": self._ibi_skip_data,
            "max_data": self._ibi_max_data,
        }
        self.clear_ibi_chain()
        return chain

    # =========================================================================
    # IBI RESULT API
    # =========================================================================

    def reset_ibi_state(self):
        """Reset IBI tracking state. Call before starting a new IBI test sequence."""
        self.last_ibi_result = None
        self.ibi_nack_count = 0
        self._ibi_event.clear()

    async def wait_for_ibi_event(self, timeout=None, units="us"):
        """Wait for any IBI event (ACK or NACK). Returns the full result dict.

        Args:
            timeout: Optional timeout value. If None, waits indefinitely.
            units: Time units for timeout (default: "us")

        Returns:
            dict with keys: addr, data (bytearray), ack (bool),
            ccc_response, chain_write_ack
        """
        if timeout is not None:
            from cocotb.triggers import with_timeout
            await with_timeout(self._ibi_event.wait(), timeout, units)
        else:
            await self._ibi_event.wait()
        self._ibi_event.clear()
        return self.last_ibi_result

    # =========================================================================
    # ARBITRATION-AWARE BIT / BYTE DRIVER
    # =========================================================================

    async def send_bit_arb(self, b: bool) -> tuple:
        """Drive a bit in open-drain and read back the bus value.

        Per I3C spec Sec.5.1.2.2.1: if the device drives Hi-Z (1) but reads
        Low (0), another device is driving -> arbitration lost.

        Returns:
            (arb_ok, bus_value): arb_ok is False if we lost arbitration.
        """
        self.scl = 0
        await self._hold_data()
        self.sda = bool(b)
        await self.remaining_tlow
        # Sample bus before raising SCL (same timing as recv_bit)
        bus_val = bool(self.sda) if self.sda_i is not None else bool(b)
        self.scl = 1
        await self.tdig_h
        self.hold_data = True
        # Arb lost when we released (drove 1) but bus is low (0)
        arb_ok = not (b and not bus_val)
        return (arb_ok, bus_val)

    async def send_byte_arb(self, b: int) -> tuple:
        """Drive a byte with per-bit arbitration check.

        On first arbitration loss, stops driving and switches to reading
        remaining bits so the bus stays synchronized.

        Returns:
            (arb_ok, bus_byte): arb_ok is False if arbitration was lost.
            bus_byte contains the actual byte seen on the bus.
        """
        self._state = I3cState.ADDR
        bus_byte = 0
        arb_ok = True
        for i in range(8):
            bit_val = bool(b & (1 << (7 - i)))
            if arb_ok:
                ok, bus_bit = await self.send_bit_arb(bit_val)
                if not ok:
                    arb_ok = False
                    self.log_info(f"Arbitration lost at bit {i}: "
                                  f"drove {int(bit_val)}, bus={int(bus_bit)}")
            else:
                # Lost arbitration — just read remaining bits
                bus_bit = await self.recv_bit()
            bus_byte = (bus_byte << 1) | int(bus_bit)
        return (arb_ok, bus_byte)

    # =========================================================================
    # UNIFIED IBI HANDLER
    # =========================================================================

    # Directed GET CCCs — read from target. All other directed CCCs are SET (write).
    _DIRECTED_GET_CCCS = frozenset({
        0x8B, 0x8C, 0x8D, 0x8E, 0x8F,  # GETMWL, GETMRL, GETPID, GETBCR, GETDCR
        0x90, 0x91,                       # GETSTATUS, GETACCCR
        0x94, 0x95,                       # GETMXDS, GETCAPS
        0x99,                              # GETXTIME
    })

    async def _handle_ibi_inline(self, ibi_addr_byte: int, send_stop: bool = True) -> dict:
        """Unified IBI handler used by both arbitration detection and background monitor.

        Args:
            ibi_addr_byte: The address byte already received from the bus
                           (8 bits: addr[7:1] + RnW[0]).
            send_stop: If True, send STOP after IBI handling (or chain+STOP).
                       If False, skip STOP — caller will issue Sr to continue.
                       Chain actions are still executed if configured.

        Returns:
            dict with keys: addr, data (bytearray), ack (bool),
            ccc_response, chain_write_ack
        """
        chain = self._consume_ibi_chain()

        ack = not self.nack_ibis.is_set()
        addr = ibi_addr_byte >> 1
        max_data = chain["max_data"] if chain["max_data"] is not None else self.max_ibi_data_len

        result = {"addr": addr, "data": bytearray(), "ack": ack,
                  "ccc_response": None, "chain_write_ack": None}

        # Send ACK/NACK
        self._state = I3cState.ACK
        # ACK = drive SDA low, NACK = release SDA (high)
        await self.send_bit(not ack)

        if ack:
            self.log_info(f"ACK-ed an IBI from 0x{addr:02X}")
        else:
            self.log_info(f"NACK-ed an IBI from 0x{addr:02X}")

        # Read IBI data if ACKed and not skipping
        if ack and not chain["skip_data"]:
            target_idx = self.get_target_idx_by_addr(addr)
            if target_idx is not None:
                target = self.targets[target_idx]
                mdb_enabled = target.bcr & (1 << 2)
                if mdb_enabled:
                    await self.recv_until_eod_tbit(
                        result["data"], max_data + 1
                    )

        # Execute chained action (chains always include their own STOP)
        if chain["ccc"] is not None:
            await self._execute_chain_ccc(chain, result)
        elif chain["write_addr"] is not None:
            await self._execute_chain_write(chain, result)
        elif send_stop:
            await self.send_stop()

        # Update result tracking state
        self.last_ibi_result = result
        if ack:
            self.got_ibi.set(bytearray([addr]) + result["data"])
        else:
            self.ibi_nack_count += 1
        self._ibi_event.set()

        return result

    async def _execute_chain_ccc(self, chain, result):
        """Execute Sr->CCC chain after IBI handling."""
        await self.send_start()
        # Use base class send_byte for 0x7E after Sr (not arbitrable)
        await I3cController.write_addr_header(self, I3C_RSVD_BYTE)
        await self.send_byte_tbit(chain["ccc"])
        if chain["ccc_data"] is not None:
            if chain["ccc_addr"] is not None:
                is_read = chain["ccc"] in self._DIRECTED_GET_CCCS
                await self.send_start()
                await I3cController.write_addr_header(
                    self, chain["ccc_addr"], read=is_read
                )
                if is_read:
                    resp_data = bytearray()
                    await self.recv_until_eod_tbit(
                        resp_data, len(chain["ccc_data"])
                    )
                    result["ccc_response"] = resp_data
                else:
                    for byte in chain["ccc_data"]:
                        await self.send_byte_tbit(byte)
            else:
                for byte in chain["ccc_data"]:
                    await self.send_byte_tbit(byte)
        await self.send_stop()

    async def _execute_chain_write(self, chain, result):
        """Execute Sr->Private Write chain after IBI handling."""
        await self.send_start()
        await I3cController.write_addr_header(self, I3C_RSVD_BYTE)
        await self.send_start()
        write_ack = await I3cController.write_addr_header(
            self, chain["write_addr"]
        )
        result["chain_write_ack"] = write_ack
        if write_ack and chain["write_data"]:
            for byte in chain["write_data"]:
                await self.send_byte_tbit(byte)
        await self.send_stop()

    # =========================================================================
    # ARBITRATION-AWARE WRITE_ADDR_HEADER
    # =========================================================================

    async def write_addr_header(self, addr: int, read: bool = False) -> bool:
        """Override: detect IBI arbitration during the 0x7E address header.

        Per Sec.5.1.2.2.1, the address header after a Start (not Sr) is arbitrable.
        Only the 0x7E reserved byte phase can collide with a target IBI. Address
        headers after Repeated Start are push-pull and not arbitrable (Sec.5.1.2.2.4).

        When an IBI is detected during 0x7E:
        1. The IBI address byte is already captured from the bus
        2. _handle_ibi_inline processes the IBI
        3. IbiArbitrationEvent is raised so the caller can retry
        """
        if addr == I3C_RSVD_BYTE and not read:
            expected_byte = (addr << 1) | (1 if read else 0)
            arb_ok, bus_byte = await self.send_byte_arb(expected_byte)

            if not arb_ok:
                # Bus byte is the IBI target's addr+RnW — handle the IBI
                self.log_info(f"IBI detected during 0x7E: bus_byte=0x{bus_byte:02X}")

                # Handle IBI without STOP — caller will retry with Sr
                # so the DUT sees a Repeated Start and won't re-arbitrate
                await self._handle_ibi_inline(bus_byte, send_stop=False)
                raise IbiArbitrationEvent()

            # No arbitration conflict — receive ACK from target
            self._state = I3cState.ACK
            nack = await self.recv_addr_ack()
            if nack:
                self.log_info("Address Header:::Got NACK")
            else:
                self.log_info("Address Header:::Got ACK")
            return not nack
        else:
            # Non-0x7E or read — not arbitrable, use base class
            return await I3cController.write_addr_header(self, addr, read)

    # =========================================================================
    # OVERRIDE _run TO USE UNIFIED HANDLER
    # =========================================================================

    async def _run(self) -> None:
        """Background monitor: detect target-initiated IBIs and handle them."""
        while True:
            self.monitor_idle.set()
            if not self.monitor_enable.is_set():
                await self.monitor_enable.wait()
            self.monitor_idle.clear()

            next_state = await self.check_start()

            if next_state == I3cState.START:
                # Read the address byte from the target
                addr_byte = 0
                self._state = I3cState.DATA_RD
                for _ in range(8):
                    addr_byte = (addr_byte << 1) | await self.recv_bit()
                await self._handle_ibi_inline(addr_byte)

            await NextTimeStep()

    # =========================================================================
    # TRANSFER METHODS WITH IBI RETRY
    # =========================================================================

    async def i3c_write(
        self,
        addr: int,
        data: Iterable[int],
        stop: bool = True,
        mode: I3cXferMode = I3cXferMode.PRIVATE,
        inject_tbit_err: bool = False,
        send_rsvd: bool = True,
    ) -> I3cPWResp:
        """I3C Private Write with automatic IBI retry during S->0x7E."""
        await self.take_bus_control()
        self.log_info(f"I3C: Write data ({mode.name}) {data} @ {hex(addr)}")

        for _retry in range(_MAX_IBI_RETRIES):
            try:
                if send_rsvd:
                    await self.send_start()
                    await self.write_addr_header(I3C_RSVD_BYTE)
                    await self.send_start()
                else:
                    await self.send_start()

                ack = await self.write_addr_header(addr)
                if ack:
                    for i, d in enumerate(data):
                        match mode:
                            case I3cXferMode.PRIVATE:
                                await self.send_byte_tbit(d, inject_tbit_err)
                            case I3cXferMode.LEGACY_I2C:
                                await self.send_byte(d)
                        self.log_info(f"I3C: wrote byte {hex(d)}, idx={i}")

                if stop:
                    await self.send_stop()

                self.give_bus_control()
                return I3cPWResp(not ack, len(data))

            except IbiArbitrationEvent:
                self.log_info(f"I3C Write: IBI handled, retrying ({_retry + 1})")
                continue

        self.give_bus_control()
        raise RuntimeError(f"i3c_write: exceeded {_MAX_IBI_RETRIES} IBI retries")

    async def i3c_read(
        self,
        addr: int,
        count: int,
        stop: bool = True,
        mode: I3cXferMode = I3cXferMode.PRIVATE,
        send_rsvd: bool = True,
    ) -> I3cPRResp:
        """I3C Private Read with automatic IBI retry during S->0x7E."""
        await self.take_bus_control()
        data = bytearray()
        self.log_info(f"I3C: Read data ({mode.name}) @ {hex(addr)}")

        for _retry in range(_MAX_IBI_RETRIES):
            try:
                if send_rsvd:
                    await self.send_start()
                    await self.write_addr_header(I3C_RSVD_BYTE)
                await self.send_start()
                ack = await self.write_addr_header(addr, read=True)
                if ack:
                    match mode:
                        case I3cXferMode.PRIVATE:
                            await self.recv_until_eod_tbit(data, count)
                        case I3cXferMode.LEGACY_I2C:
                            for i in range(count):
                                send_ack = not (i == count - 1)
                                data.append(await self.recv_byte(send_ack))
                if stop:
                    await self.send_stop()

                self.give_bus_control()
                return I3cPRResp(not ack, data)

            except IbiArbitrationEvent:
                data.clear()
                self.log_info(f"I3C Read: IBI handled, retrying ({_retry + 1})")
                continue

        self.give_bus_control()
        raise RuntimeError(f"i3c_read: exceeded {_MAX_IBI_RETRIES} IBI retries")

    async def i3c_ccc_write(
        self,
        ccc: int,
        broadcast_data: Optional[Iterable[int]] = None,
        directed_data: Optional[Iterable[tuple[int, Iterable[int]]]] = None,
        defining_byte: Optional[int] = None,
        stop: bool = True,
        pull_scl_low: bool = False,
    ) -> Iterable[bool]:
        """Issue CCC Write with automatic IBI retry during S->0x7E."""
        await self.take_bus_control()
        is_broadcast = ccc <= 0x7F

        log_data = broadcast_data if is_broadcast else directed_data
        if is_broadcast:
            self.log_info(f"I3C: CCC {hex(ccc)} WR (Broadcast): {log_data}")
        else:
            self.log_info(f"I3C: CCC {hex(ccc)} WR (Directed): {log_data}")

        for _retry in range(_MAX_IBI_RETRIES):
            try:
                acks = []
                await self.send_start()
                await self.write_addr_header(I3C_RSVD_BYTE)
                await self.send_byte_tbit(ccc)
                if defining_byte is not None:
                    await self.send_byte_tbit(defining_byte)

                if is_broadcast:
                    if broadcast_data is not None:
                        for byte in broadcast_data:
                            await self.send_byte_tbit(byte)
                else:
                    assert directed_data is not None
                    for a, d in directed_data:
                        await self.send_start()
                        acks.append(await self.write_addr_header(a))
                        for byte in d:
                            await self.send_byte_tbit(byte)

                if stop:
                    await self.send_stop()
                if pull_scl_low:
                    self.scl = 0
                    await self._hold_data()

                self.give_bus_control()
                return acks

            except IbiArbitrationEvent:
                self.log_info(f"I3C CCC Write: IBI handled, retrying ({_retry + 1})")
                continue

        self.give_bus_control()
        raise RuntimeError(f"i3c_ccc_write: exceeded {_MAX_IBI_RETRIES} IBI retries")

    async def i3c_ccc_read(
        self,
        ccc: int,
        addr,
        count: int,
        defining_byte: Optional[int] = None,
        stop: bool = True,
    ) -> Iterable[tuple]:
        """Issue directed CCC Read with automatic IBI retry during S->0x7E."""
        if isinstance(addr, int):
            addr = [addr]

        await self.take_bus_control()
        astr = " ".join([hex(a) for a in addr])
        self.log_info(f"I3C: CCC {hex(ccc)} RD (Directed @ {astr})")

        for _retry in range(_MAX_IBI_RETRIES):
            try:
                responses = []
                await self.send_start()
                await self.write_addr_header(I3C_RSVD_BYTE)
                await self.send_byte_tbit(ccc)
                if defining_byte is not None:
                    await self.send_byte_tbit(defining_byte)
                for i, a in enumerate(addr):
                    is_last = (i == len(addr) - 1)
                    await self.send_start()
                    ack = await self.write_addr_header(a, read=True)
                    rd_data = bytearray()
                    await self.recv_until_eod_tbit(
                        rd_data, count, stop=is_last and stop
                    )
                    responses.append((ack, rd_data))

                if stop:
                    await self.send_stop()

                self.give_bus_control()
                return responses

            except IbiArbitrationEvent:
                self.log_info(f"I3C CCC Read: IBI handled, retrying ({_retry + 1})")
                continue

        self.give_bus_control()
        raise RuntimeError(f"i3c_ccc_read: exceeded {_MAX_IBI_RETRIES} IBI retries")

    async def i3c_ccc_read_chained(
        self,
        commands: list,
    ) -> list:
        """Issue multiple directed CCC Reads in a single bus frame.

        Each element of *commands* is a (ccc, addr, count) tuple describing
        one directed CCC read.  All CCCs are executed within a single
        take_bus_control / give_bus_control window with no STOP between them
        (only Sr + 7E/W transitions).  STOP is sent after the last CCC.

        Bus sequence for two commands::

            S + 7E/W + ccc1 + Sr + addr1/R + [count1 bytes]
            Sr + 7E/W + ccc2 + Sr + addr2/R + [count2 bytes] + P

        Returns a list of (ack, bytearray) tuples, one per command.
        """
        desc = ", ".join(f"{hex(c)}@{hex(a)}x{n}" for c, a, n in commands)
        self.log_info(f"I3C: CCC RD chained [{desc}]")

        await self.take_bus_control()

        for _retry in range(_MAX_IBI_RETRIES):
            try:
                responses = []
                for idx, (ccc, addr, count) in enumerate(commands):
                    is_last = (idx == len(commands) - 1)
                    await self.send_start()
                    await self.write_addr_header(I3C_RSVD_BYTE)
                    await self.send_byte_tbit(ccc)
                    await self.send_start()
                    ack = await self.write_addr_header(addr, read=True)
                    rd_data = bytearray()
                    if ack:
                        await self.recv_until_eod_tbit(
                            rd_data, count, stop=False
                        )
                    responses.append((ack, rd_data))

                await self.send_stop()
                self.give_bus_control()
                return responses

            except IbiArbitrationEvent:
                self.log_info(
                    f"I3C CCC Read chained: IBI handled, retrying ({_retry + 1})"
                )
                continue

        self.give_bus_control()
        raise RuntimeError(
            f"i3c_ccc_read_chained: exceeded {_MAX_IBI_RETRIES} IBI retries"
        )

    # =========================================================================
    # TARGET RESET PATTERN STRESS TEST METHODS
    # =========================================================================

    async def send_target_reset_pattern_stress(
        self,
        num_transitions: int = 14,
        tdig_h_ns: Optional[float] = None,
        t_start_hold_ns: Optional[float] = None,
        t_stop_hold_ns: Optional[float] = None,
    ) -> None:
        """
        Send a target reset pattern with configurable parameters for stress testing.

        Per I3C spec (5.1.11.3):
        1. 14 SDA transitions while SCL is kept Low
        2. Repeated START
        3. STOP

        Args:
            num_transitions: Number of SDA transitions (14 for valid pattern)
            tdig_h_ns: Override timing for SDA transitions in nanoseconds.
                       If None, uses the controller's default tdig_h.
            t_start_hold_ns: Override hold time for START condition in nanoseconds.
                             If None, uses tdig_h_ns or controller default.
            t_stop_hold_ns: Override hold time for STOP condition in nanoseconds.
                            If None, uses tdig_h_ns or controller default.
        """
        await self.take_bus_control()
        self._state = I3cState.TARGET_RESET

        # Use custom timing or fall back to controller's tdig_h
        if tdig_h_ns is not None:
            wait_time = Timer(tdig_h_ns, "ns")
        else:
            wait_time = self.tdig_h

        t_start = Timer(t_start_hold_ns, "ns") if t_start_hold_ns else wait_time
        t_stop = Timer(t_stop_hold_ns, "ns") if t_stop_hold_ns else wait_time

        self.log_info(f"Sending target reset pattern with {num_transitions} SDA transitions")

        # Start with SDA high, SCL low
        sda = 1
        self.sda = sda
        self.scl = 0
        await wait_time

        # Generate SDA transitions while SCL is low
        for _ in range(num_transitions):
            sda = 0 if sda else 1
            self.sda = sda
            await wait_time

        # Raise SCL and keep it high through START and STOP
        await wait_time
        self.scl = 1
        await wait_time

        # Send Repeated START (SDA falling while SCL high)
        self.sda = 0
        await t_start

        # Send STOP (SDA rising while SCL high)
        self.sda = 1
        await t_stop

        self.log_info("Target reset pattern complete")
        self.give_bus_control()

    async def send_target_reset_pattern_with_scl_glitch(
        self,
        glitch_at_transition: int = 7,
        tdig_h_ns: Optional[float] = None,
    ) -> None:
        """
        Send target reset pattern with SCL glitch during SDA transitions.
        
        This should reset the transition counter and prevent reset detection.

        Args:
            glitch_at_transition: Which SDA transition to glitch SCL at (0-indexed)
            tdig_h_ns: Override timing in nanoseconds. If None, uses controller default.
        """
        await self.take_bus_control()
        self._state = I3cState.TARGET_RESET

        if tdig_h_ns is not None:
            wait_time = Timer(tdig_h_ns, "ns")
            half_wait = Timer(tdig_h_ns / 2, "ns")
        else:
            wait_time = self.tdig_h
            half_wait = Timer(self.timings.tdig_h / 2, "ns")

        self.log_info(f"Sending pattern with SCL glitch at transition {glitch_at_transition}")

        sda = 1
        self.sda = sda
        self.scl = 0
        await wait_time

        for i in range(14):
            sda = 0 if sda else 1
            self.sda = sda
            await wait_time

            # Inject SCL glitch
            if i == glitch_at_transition:
                self.scl = 1
                await half_wait
                self.scl = 0
                await half_wait

        # Complete pattern normally
        await wait_time
        self.scl = 1
        await wait_time

        self.sda = 0
        await wait_time

        self.sda = 1
        await wait_time

        self.give_bus_control()

    async def send_target_reset_pattern_with_sda_stable_low(
        self,
        tdig_h_ns: Optional[float] = None,
    ) -> None:
        """
        Send 14 SDA transitions, but then SDA goes stable low before SCL rises.
        
        This should cause FSM to return to AwaitPattern (abort).

        Args:
            tdig_h_ns: Override timing in nanoseconds. If None, uses controller default.
        """
        await self.take_bus_control()
        self._state = I3cState.TARGET_RESET

        if tdig_h_ns is not None:
            wait_time = Timer(tdig_h_ns, "ns")
        else:
            wait_time = self.tdig_h

        self.log_info("Sending pattern with SDA stable low during AwaitSCL")

        sda = 1
        self.sda = sda
        self.scl = 0
        await wait_time

        for _ in range(14):
            sda = 0 if sda else 1
            self.sda = sda
            await wait_time

        # SDA should be high after 14 toggles, but force it low
        self.sda = 0
        await wait_time
        await wait_time

        # Now raise SCL - but FSM should have aborted
        self.scl = 1
        await wait_time

        # Try to complete pattern anyway
        self.sda = 0
        await wait_time
        self.sda = 1
        await wait_time

        self.give_bus_control()

    async def send_target_reset_pattern_with_scl_drop_await_sr(
        self,
        tdig_h_ns: Optional[float] = None,
    ) -> None:
        """
        Send valid 14 transitions, SCL rises, but then drops before START.
        
        This tests the AwaitSr abort condition when SCL goes stable low.

        Args:
            tdig_h_ns: Override timing in nanoseconds. If None, uses controller default.
        """
        await self.take_bus_control()
        self._state = I3cState.TARGET_RESET

        if tdig_h_ns is not None:
            wait_time = Timer(tdig_h_ns, "ns")
            half_wait = Timer(tdig_h_ns / 2, "ns")
        else:
            wait_time = self.tdig_h
            half_wait = Timer(self.timings.tdig_h / 2, "ns")

        self.log_info("Sending pattern with SCL drop during AwaitSr")

        sda = 1
        self.sda = sda
        self.scl = 0
        await wait_time

        for _ in range(14):
            sda = 0 if sda else 1
            self.sda = sda
            await wait_time

        await wait_time
        self.scl = 1
        await half_wait

        # Drop SCL before START - this should abort AwaitSr
        self.scl = 0
        await wait_time

        # FSM should have aborted, attempt to complete anyway
        self.scl = 1
        await wait_time
        self.sda = 0
        await wait_time
        self.sda = 1
        await wait_time

        self.give_bus_control()

    async def send_target_reset_pattern_with_scl_drop_await_p(
        self,
        tdig_h_ns: Optional[float] = None,
        t_start_hold_ns: Optional[float] = None,
    ) -> None:
        """
        Complete valid pattern through START, but SCL drops before STOP.
        
        This tests the AwaitP abort condition when SCL goes stable low.
        NOTE: SCL must drop BEFORE SDA rises, because STOP is detected on SDA rising edge.

        Args:
            tdig_h_ns: Override timing in nanoseconds. If None, uses controller default.
            t_start_hold_ns: Override START hold time. If None, uses tdig_h_ns or default.
        """
        await self.take_bus_control()
        self._state = I3cState.TARGET_RESET

        if tdig_h_ns is not None:
            wait_time = Timer(tdig_h_ns, "ns")
        else:
            wait_time = self.tdig_h

        t_start = Timer(t_start_hold_ns, "ns") if t_start_hold_ns else wait_time

        self.log_info("Sending pattern with SCL drop during AwaitP")

        sda = 1
        self.sda = sda
        self.scl = 0
        await wait_time

        for _ in range(14):
            sda = 0 if sda else 1
            self.sda = sda
            await wait_time

        await wait_time
        self.scl = 1
        await wait_time

        # Valid START - SDA falls while SCL high
        self.sda = 0
        await t_start

        # Now in AwaitP, drop SCL BEFORE raising SDA
        self.scl = 0
        await wait_time

        # Now raise SDA (but SCL is low, so no STOP detected)
        self.sda = 1
        await wait_time

        # Return to idle
        self.scl = 1
        await wait_time

        self.give_bus_control()

    # =========================================================================
    # TE0/TE1 ERROR INJECTION METHODS
    # =========================================================================

    async def send_te0_error(self) -> None:
        """
        Trigger a TE0 error by sending START followed by 0x7E/R.

        Per I3C spec Sec.5.1.10.1.1, receipt of 7'h7E/R (broadcast address with
        read bit) after a dynamic address has been assigned is an Error Type
        TE0. The target enters HDR error mode (deaf) until it detects the HDR
        Exit Pattern or the optional 60µs timeout (Sec.5.1.10.1.9).

        After calling this method the controller still holds bus control.
        The caller must release the bus (e.g., send_hdr_exit + give_bus_control,
        or send_stop + give_bus_control) when done.
        """
        await self.take_bus_control()
        await self.send_start()
        await self.write_addr_header(I3C_RSVD_BYTE, read=True)

    async def send_te1_error(self, ccc: int = 0x20) -> None:
        """
        Trigger a TE1 error by sending a CCC with bad T-bit parity.

        Per I3C spec Sec.5.1.10.1.2, if the target detects a parity error during
        a CCC code it cannot know whether the bus has changed to HDR mode.
        The target enters HDR error mode (deaf) until it detects the HDR Exit
        Pattern or the optional 60µs timeout (Sec.5.1.10.1.9).

        Args:
            ccc: CCC command code to send with bad parity (default: ENTHDR0 0x20).

        After calling this method the controller still holds bus control.
        The caller must release the bus when done.
        """
        await self.take_bus_control()
        await self.send_start()
        await self.write_addr_header(I3C_RSVD_BYTE)
        await self.send_byte_tbit(ccc, inject_tbit_err=True)

    async def send_te2_error(self, ccc: int, defining_byte: int = None,
                            corrupt_defining_byte: bool = True) -> None:
        """
        Trigger a TE2 error by sending a CCC with bad T-bit parity on the
        defining byte or data byte.

        Per I3C spec Sec.5.1.10.1.3, a parity error on a CCC defining byte
        or data byte is a TE2 error.

        Args:
            ccc: CCC command code (sent with correct T-bit parity).
            defining_byte: If provided, sent after the CCC byte.
            corrupt_defining_byte: If True and defining_byte is provided,
                inject bad T-bit parity on the defining byte. If False,
                the defining byte gets correct parity (caller must send
                a data byte with bad parity separately).

        After calling this method the controller still holds bus control.
        The caller must send STOP and give_bus_control().
        """
        await self.take_bus_control()
        await self.send_start()
        await self.write_addr_header(I3C_RSVD_BYTE)
        await self.send_byte_tbit(ccc, inject_tbit_err=False)
        if defining_byte is not None:
            await self.send_byte_tbit(defining_byte,
                                      inject_tbit_err=corrupt_defining_byte)

    # =========================================================================
    # ENTDAA CONTROLLER SEQUENCE
    # =========================================================================

    @staticmethod
    def _odd_parity(addr: int) -> int:
        """Compute odd parity over 7-bit address for ENTDAA address byte."""
        p = 1
        for i in range(7):
            p ^= (addr >> i) & 1
        return p

    async def i3c_entdaa(
        self,
        addrs_to_assign: list,
        inject_te3_parity: bool = False,
        inject_te4_invalid_rsvd: bool = False,
        stop_after_n_targets: int = None,
    ) -> list:
        """
        Execute ENTDAA from the controller side.

        Protocol:
          S + 7E/W + ACK -> 0x07 + T-bit
          For each target:
            Sr + 7E/R + ACK
            Read 64 bits (PID+BCR+DCR) via recv_bit_od
            Send address byte (addr<<1 | odd_parity) via send_byte
            Target ACKs
          P (STOP)

        Args:
            addrs_to_assign: List of 7-bit addresses to assign to targets.
            inject_te3_parity: Flip parity bit on address byte (TE3 error).
            inject_te4_invalid_rsvd: Send 7E/W instead of 7E/R after Sr (TE4).
            stop_after_n_targets: Issue STOP after N targets (early termination).

        Returns:
            List of dicts: {pid, bcr, dcr, addr, ack} per target slot.
        """
        await self.take_bus_control()
        results = []

        # Phase 1: S + 7E/W + ACK + ENTDAA CCC (0x07) + T-bit
        await self.send_start()
        await self.write_addr_header(I3C_RSVD_BYTE)
        await self.send_byte_tbit(0x07)

        targets_done = 0
        for addr in addrs_to_assign:
            if stop_after_n_targets is not None and targets_done >= stop_after_n_targets:
                break

            # Phase 2: Sr + 7E/R (or 7E/W for TE4 injection)
            await self.send_start()
            if inject_te4_invalid_rsvd:
                ack = await self.write_addr_header(I3C_RSVD_BYTE, read=False)
            else:
                ack = await self.write_addr_header(I3C_RSVD_BYTE, read=True)

            if not ack:
                # NACK — no more targets to assign (or TE4 error)
                results.append({"pid": None, "bcr": None, "dcr": None,
                                "addr": addr, "ack": False})
                break

            # Phase 3: Read 64 bits of device ID (PID[48] + BCR[8] + DCR[8])
            id_bits = 0
            for bit_idx in range(64):
                bit_val = await self.recv_bit_od()
                id_bits = (id_bits << 1) | int(bit_val)

            # Parse: PID = bits[63:16], BCR = bits[15:8], DCR = bits[7:0]
            pid = (id_bits >> 16) & 0xFFFFFFFFFFFF
            bcr = (id_bits >> 8) & 0xFF
            dcr = id_bits & 0xFF

            # Phase 4: Send address byte with parity
            parity = self._odd_parity(addr)
            if inject_te3_parity:
                parity ^= 1  # Flip parity to cause TE3
            addr_byte = (addr << 1) | parity

            nack = await self.send_byte(addr_byte)
            target_acked = not nack

            results.append({"pid": pid, "bcr": bcr, "dcr": dcr,
                            "addr": addr, "ack": target_acked})
            targets_done += 1

        # Phase 5: STOP
        await self.send_stop()
        self.give_bus_control()
        return results

    # =========================================================================
    # BUS STATE CONTROL METHODS
    # =========================================================================

    async def set_bus_idle(self) -> None:
        """
        Set bus to idle state (both SDA and SCL high).
        
        Useful for initializing bus state before stress tests.
        """
        self.sda = 1
        self.scl = 1
        await self.tdig_h

    async def recv_addr_ack(self) -> bool:
        self.scl = 0
        self.sda = 1
        # We don't hold the data here, because it's on the target to pull it down
        # after the required amount of time
        await self.tdig_l
        if self.sda_i is None:
            b = False
        else:
            b = bool(self.sda)
        
        # Take over driving in case of an ACK by target
        if b == False:
            self.sda = 0
        self.scl = 1
        await self.tdig_h
        self.hold_data = False

        return b

    async def send_byte(self, b: int, addr: bool = False) -> bool:
        self._state = I3cState.ADDR if addr else I3cState.DATA_WR
        for i in range(8):
            await self.send_bit(b & (1 << 7 - i))
        self._state = I3cState.ACK
        if addr and not(b & 1):
            return await self.recv_addr_ack()
        else:
            return await self.recv_bit_od()


