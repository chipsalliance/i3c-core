# SPDX-License-Identifier: Apache-2.0
"""
I3C SDR Bus Monitor -- continuous protocol-level verification of the I3C Target DUT.

Monitors the I3C bus signals (SDA, SCL) along with the DUT's per-device output-enable
and OD/PP mode signals to verify that the Target Device behaves correctly according to
the I3C v1.1 specification.

Checks performed (with spec section references):
  1. OD/PP truth table integrity             -- bus_tx_flow truth table
  2. Address phase uses Open Drain            -- S5.1.2.2.1
  3. No target arbitration after Repeated Sr  -- S5.1.2.2.4
  4. ACK/NACK bit is Open Drain               -- S5.1.2.2.4, S5.1.2.3.1
  5. Write-ACK handoff (target releases SDA)  -- S5.1.2.3.1, tSCO (Table 87)
  6. IBI-ACK handoff (target takes SDA in PP) -- S5.1.2.3.2
  7. Read data bytes in Push-Pull             -- S5.1.2.3
  8. T-bit end: target releases to Hi-Z       -- S5.1.2.3.4, tSCO, Figs 150-151
  9. T-bit continue: target releases to Hi-Z  -- S5.1.2.3.4, tSCO, Fig 152
 10. Bus contention detection                 -- general safety
 11. Target silent on non-matching address     -- S5.1.2
 12. IBI only after START, not after Sr        -- S5.1.6.2
 13. Read T-bit in Push-Pull mode             -- S5.1.2.3
 14. ENTDAA PID/BCR/DCR in Open Drain mode    -- S5.1.4.2
 15. ENTDAA DA handoff (DCR->DA, tSCO)        -- S5.1.2.5.4, Fig 23
 16. ENTDAA DA+PAR contention check           -- S5.1.4.2 step 9

Started automatically by I3CTopTestInterface.setup(); raises on violation.
"""

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer, First, Edge
from enum import IntEnum, auto


class BusPhase(IntEnum):
    """Protocol phase tracking for the I3C SDR bus."""
    IDLE = auto()
    START = auto()           # S or Sr detected, about to clock address
    ADDR_BITS = auto()       # Clocking 7-bit address + RnW
    ADDR_ACK = auto()        # 9th bit: ACK/NACK
    WRITE_DATA = auto()      # Controller writing data bytes (8 data + T-parity)
    WRITE_TBIT = auto()      # 9th bit of controller write (parity / T-bit)
    READ_DATA = auto()       # Target returning read data bytes in PP
    READ_TBIT = auto()       # 9th bit of target read (end-of-data / T-bit)
    IBI_ADDR_BITS = auto()   # IBI: target driving address in OD
    IBI_ADDR_ACK = auto()    # IBI: controller ACK/NACK
    IBI_MDB = auto()         # IBI: mandatory data byte in PP
    IBI_DATA = auto()        # IBI: additional data bytes in PP
    IBI_DATA_TBIT = auto()   # IBI: T-bit for additional data
    CCC_BYTE = auto()        # CCC command byte (controller write)
    CCC_TBIT = auto()        # CCC T-bit
    ENTDAA = auto()          # Dynamic address assignment
    HDR_MODE = auto()        # Bus in HDR mode -- suspend SDR checking


class I3cBusMonitor:
    """
    Continuous protocol-level I3C bus monitor.

    Watches bus_scl, bus_sda, and per-device DUT signals (i3c_sda_o, i3c_sda_oe,
    i3c_sel_od_pp) to verify the I3C Target complies with the specification.
    """

    I3C_BROADCAST_ADDR = 0x7E

    # tSCO max: Clock in to Data Out for Target (Table 86 §6.2)
    # The Target must change SDA within tSCO of the SCL edge.
    TSCO_MAX_NS = 12

    # Direct GET CCC codes and their expected byte counts
    _GET_CCC_BYTE_COUNTS = {
        0x8B: 2,   # GETMWL
        0x8C: 3,   # GETMRL
        0x8D: 6,   # GETPID
        0x8E: 1,   # GETBCR
        0x8F: 1,   # GETDCR
        0x90: 2,   # GETSTATUS
        0x95: None, # GETCAPS — depends on defining byte
        0x9A: 1,   # RSTACT read
    }

    # Direct SET CCC codes that modify DUT CSRs
    _SET_CCC_CODES = {0x89, 0x8A, 0x80, 0x81}  # SETMWL, SETMRL, ENEC, DISEC

    # Address-changing CCC codes
    _ADDR_CCC_CODES = {
        0x06,  # RSTDAA (broadcast)
        0x29,  # SETAASA (broadcast)
        0x87,  # SETDASA (direct)
        0x88,  # SETNEWDA (direct)
    }

    def __init__(self, dut, log=None):
        self.dut = dut
        self.log = log or dut._log
        self._running = False
        self._task = None

        # Violation tracking
        self.violations = []
        self.violation_count = 0
        self._suppressed_checks = set()  # Check IDs to suppress (e.g. "BUS_CONTENTION")

        # Statistics
        self.stats = {
            'scl_edges': 0,
            'starts_detected': 0,
            'stops_detected': 0,
            'addr_phases': 0,
            'read_bytes': 0,
            'write_bytes': 0,
            'ibi_requests': 0,
            'od_samples': 0,
            'pp_samples': 0,
            'contention_checks': 0,
        }

        # Protocol state
        self._phase = BusPhase.IDLE
        self._bit_count = 0
        self._addr_accum = 0
        self._rnw = 0
        self._is_broadcast = False
        self._is_addressed_to_dut = False
        self._is_addr_virt = False
        self._is_ibi = False
        self._is_repeated_start = False
        self._dut_dynamic_addr = None   # Will be set after DAA
        self._virt_dynamic_addr = None  # Virtual target address
        self._data_accum = 0
        self._byte_in_msg = 0         # Which byte in the current message
        self._is_ccc = False
        self._ccc_code = 0
        self._is_entdaa = False
        self._prev_scl = 1
        self._prev_sda = 1
        self._bus_active = False       # True between START and STOP

        # --- Check 5: Write-ACK handoff (S5.1.2.3.1) ---
        # Scheduled tSCO after the ACK's SCL rising edge
        self._handoff_check_time = None  # sim time (ns) to fire check
        self._handoff_addr = 0           # address for violation message
        self._handoff_check_id = "WRITE_ACK_HANDOFF"  # violation tag
        self._handoff_spec_ref = "S5.1.2.3.1 step 2"  # spec citation

        # --- Check 6: IBI ACK takeover (S5.1.2.3.2) ---
        # After IBI ACK, Target must drive SDA Low in PP within tSCO
        self._ibi_takeover_check_time = None  # sim time (ns) to fire check
        self._ibi_takeover_addr = 0            # address for violation message

        # --- ENTDAA (S5.1.4.2) ---
        self._entdaa_bit_count = 0

        # --- M1: CCC Response Data Monitor state ---
        self._active_ccc_code = None   # CCC code that persists across Sr
        self._ccc_defining_byte = None # Defining byte for CCCs that use one
        self._ccc_direct_addr = None   # Target addr in direct CCC phase
        self._ccc_read_bytes = []      # Accumulated read bytes during direct GET
        self._in_ccc_read_phase = False # True when reading GET CCC response data
        # Snapshot of expected GET CCC response bytes, captured at the moment
        # the read data phase begins (after the directed-read header is ACKed).
        # Required to avoid races vs. concurrent FW (AXI) writes to the same
        # CSRs while the design is shifting the response onto the bus.
        self._ccc_read_expected = None

        # --- M2: Address Tracking Monitor state ---
        self._ccc_write_bytes = []     # Data bytes captured during CCC write phase
        self._in_ccc_write_phase = False # True when writing direct CCC data

        # --- M4: Abort Recovery Monitor state ---
        self._ccc_was_aborted = False   # Set when CCC terminated abnormally
        self._abort_count = 0           # Total CCC aborts observed

        # Resolve signal handles
        self._resolve_signals()

    def _resolve_signals(self):
        """Resolve DUT signal paths."""
        try:
            self.bus_sda = self.dut.bus_sda
            self.bus_scl = self.dut.bus_scl

            # DUT (device 2) signals exposed at wrapper level
            self.i3c_sda_o = self.dut.i3c_sda_o
            self.i3c_sda_oe = self.dut.i3c_sda_oe
            self.i3c_sel_od_pp = self.dut.i3c_sel_od_pp

            # Clock for sampling
            if hasattr(self.dut, 'aclk'):
                self.clk = self.dut.aclk
            elif hasattr(self.dut, 'hclk'):
                self.clk = self.dut.hclk
            else:
                self.clk = None

            self._available = True
            self.log.info("I3cBusMonitor: Signals resolved successfully")
        except AttributeError as e:
            self._available = False
            self.log.warning(f"I3cBusMonitor: Cannot resolve signals: {e}")

    def is_available(self):
        return self._available

    def set_dut_dynamic_addr(self, addr):
        """Set the DUT's dynamic address so the monitor can track addressing."""
        self._dut_dynamic_addr = addr
        self.log.info(f"I3cBusMonitor: DUT dynamic address set to 0x{addr:02X}")

    def set_virt_dynamic_addr(self, addr):
        """Set the virtual target's dynamic address for CCC monitor tracking."""
        self._virt_dynamic_addr = addr
        self.log.info(f"I3cBusMonitor: Virtual target dynamic address set to 0x{addr:02X}")

    async def start(self):
        if not self._available:
            self.log.warning("I3cBusMonitor: Cannot start -- signals unavailable")
            return
        if self._running:
            return
        self._running = True
        self._task = cocotb.start_soon(self._monitor_loop())
        self.log.info("I3cBusMonitor: Started")

    def stop(self):
        self._running = False
        if self._task:
            self._task.kill()
            self._task = None

    def _record_violation(self, check_id, message):
        """Record a violation and raise immediately to fail the test.

        If check_id is in _suppressed_checks, the violation is logged as a
        warning but not recorded and no exception is raised. This allows
        tests to intentionally violate bus protocol (e.g. STOP during
        target-driven read) without triggering the monitor.
        """
        time_ns = cocotb.utils.get_sim_time('ns')
        full_msg = f"[{check_id}] @{time_ns}ns phase={self._phase.name}: {message}"
        if check_id in self._suppressed_checks:
            self.log.warning(f"I3cBusMonitor SUPPRESSED: {full_msg}")
            return
        self.violations.append(full_msg)
        self.violation_count += 1
        self.log.error(f"I3cBusMonitor VIOLATION: {full_msg}")
        raise AssertionError(full_msg)

    def suppress_check(self, check_id):
        """Suppress a specific check ID. Use for intentional protocol violations."""
        self._suppressed_checks.add(check_id)

    def unsuppress_check(self, check_id):
        """Re-enable a previously suppressed check ID."""
        self._suppressed_checks.discard(check_id)

    def check(self):
        """End-of-test check: assert no violations were recorded.

        Call at end of test as a safety net. The primary mechanism is the
        immediate AssertionError in _record_violation, but this catches any
        edge case where a violation was logged but the exception was swallowed.
        """
        if self.violations:
            msg = (
                f"I3cBusMonitor: {self.violation_count} violation(s) detected:\n"
                + "\n".join(f"  {v}" for v in self.violations)
            )
            raise AssertionError(msg)

    def _get_dut_sda_oe(self):
        """Read DUT sda output enable, returns None on X/Z."""
        try:
            return int(self.i3c_sda_oe.value)
        except ValueError:
            return None

    def _get_dut_sel_od_pp(self):
        """Read DUT OD/PP mode, returns None on X/Z."""
        try:
            return int(self.i3c_sel_od_pp.value)
        except ValueError:
            return None

    def _get_dut_sda_o(self):
        """Read DUT SDA output data, returns None on X/Z."""
        try:
            return int(self.i3c_sda_o.value)
        except ValueError:
            return None

    def _dut_is_driving(self):
        """Return True if DUT has output-enable asserted."""
        oe = self._get_dut_sda_oe()
        return oe == 1

    def _dut_is_pp(self):
        """Return True if DUT is in Push-Pull mode."""
        pp = self._get_dut_sel_od_pp()
        return pp == 1

    def _dut_is_od(self):
        """Return True if DUT is in Open-Drain mode."""
        pp = self._get_dut_sel_od_pp()
        return pp == 0

    def _check_od_pp_truth_table(self):
        """
        Check 1: Verify the OD/PP truth table is respected.

        OD mode (sel_od_pp=0):
          sda_o=0 --> sda_oe=1 (driving low)
          sda_o=1 --> sda_oe=0 (hi-z, releasing)
        PP mode (sel_od_pp=1):
          sda_oe always = 1 (always driving)
        """
        sel = self._get_dut_sel_od_pp()
        oe = self._get_dut_sda_oe()
        sda = self._get_dut_sda_o()
        if sel is None or oe is None or sda is None:
            return  # X/Z during reset

        if sel == 0:  # Open Drain
            self.stats['od_samples'] += 1
            expected_oe = 1 if sda == 0 else 0
            if oe != expected_oe:
                self._record_violation(
                    "OD_PP_TABLE",
                    f"OD mode: sda_o={sda} expects sda_oe={expected_oe}, got {oe}"
                )
        else:  # Push-Pull
            self.stats['pp_samples'] += 1
            if oe != 1:
                self._record_violation(
                    "OD_PP_TABLE",
                    f"PP mode: sda_oe must be 1, got {oe} (sda_o={sda})"
                )

    def _check_contention(self):
        """
        Check 10: Bus contention -- DUT must not actively drive SDA high in PP
        while the bus reads low (another device pulling it low in OD).

        In OD mode, contention is safe (wired-AND). In PP mode, if DUT drives
        high but bus is low, a physical bus would see contention.

        Skipped during IDLE phase: DUT may be transitioning modes between
        transfers and there is no active bus transaction to contend with.
        """
        self.stats['contention_checks'] += 1
        if self._phase == BusPhase.IDLE:
            return
        if not self._dut_is_driving():
            return

        if self._dut_is_pp():
            sda_o = self._get_dut_sda_o()
            try:
                bus_sda = int(self.bus_sda.value)
            except ValueError:
                return

            # PP driving high while bus is low => contention
            if sda_o == 1 and bus_sda == 0:
                self._record_violation(
                    "BUS_CONTENTION",
                    f"DUT PP-driving SDA=1 but bus_sda=0 -- bus contention!"
                )

    def _check_target_silent_nonmatching(self):
        """
        Check 11: Target shall not transmit on the Bus in response
        to a non-matching Address (S5.1.2).
        """
        if self._phase in (BusPhase.WRITE_DATA, BusPhase.WRITE_TBIT,
                           BusPhase.READ_DATA, BusPhase.READ_TBIT):
            if not self._is_addressed_to_dut and not self._is_broadcast:
                if self._dut_is_driving():
                    self._record_violation(
                        "TARGET_SILENT",
                        f"DUT driving SDA during non-matching address phase "
                        f"(addr=0x{self._addr_accum:02X})"
                    )

    # --------------------------------------------------------------
    # Phase-specific checks on SCL edges
    # --------------------------------------------------------------

    def _on_scl_rising(self, bus_sda):
        """Called on every SCL rising edge."""
        self.stats['scl_edges'] += 1

        # Always check truth table and contention
        self._check_od_pp_truth_table()
        self._check_contention()

        if self._phase == BusPhase.ADDR_BITS:
            self._on_addr_bit_rise(bus_sda)
        elif self._phase == BusPhase.ADDR_ACK:
            self._on_addr_ack_rise(bus_sda)
        elif self._phase == BusPhase.IBI_ADDR_BITS:
            self._on_addr_bit_rise(bus_sda)
        elif self._phase == BusPhase.IBI_ADDR_ACK:
            self._on_ibi_ack_rise(bus_sda)
        elif self._phase == BusPhase.WRITE_DATA:
            # Accumulate write data for CCC tracking
            self._data_accum = (self._data_accum << 1) | bus_sda
        elif self._phase == BusPhase.WRITE_TBIT:
            pass  # Controller drives parity
        elif self._phase == BusPhase.READ_DATA:
            self._on_read_data_rise()
            # Accumulate read data for CCC tracking
            self._data_accum = (self._data_accum << 1) | bus_sda
        elif self._phase == BusPhase.READ_TBIT:
            self._on_read_tbit_rise(bus_sda)
        elif self._phase == BusPhase.IBI_MDB:
            self._on_read_data_rise()
        elif self._phase == BusPhase.IBI_DATA:
            self._on_read_data_rise()
        elif self._phase == BusPhase.IBI_DATA_TBIT:
            self._on_read_tbit_rise(bus_sda)
        elif self._phase == BusPhase.CCC_BYTE:
            self._data_accum = (self._data_accum << 1) | bus_sda
        elif self._phase == BusPhase.CCC_TBIT:
            pass
        elif self._phase == BusPhase.ENTDAA:
            self._on_entdaa_rise(bus_sda)

    def _on_scl_falling(self, bus_sda):
        """Called on every SCL falling edge."""
        self._check_od_pp_truth_table()

        if self._phase == BusPhase.ADDR_BITS:
            self._on_addr_bit_fall()
        elif self._phase == BusPhase.ADDR_ACK:
            self._on_addr_ack_fall(bus_sda)
        elif self._phase == BusPhase.IBI_ADDR_BITS:
            self._on_addr_bit_fall()
        elif self._phase == BusPhase.IBI_ADDR_ACK:
            self._on_ibi_ack_fall(bus_sda)
        elif self._phase == BusPhase.WRITE_DATA:
            self._on_write_data_fall()
        elif self._phase == BusPhase.WRITE_TBIT:
            self._on_write_tbit_fall()
        elif self._phase == BusPhase.READ_DATA:
            self._on_read_data_fall()
        elif self._phase == BusPhase.READ_TBIT:
            self._on_read_tbit_fall(bus_sda)
        elif self._phase == BusPhase.IBI_MDB:
            self._on_ibi_mdb_fall()
        elif self._phase == BusPhase.IBI_DATA:
            self._on_ibi_data_fall()
        elif self._phase == BusPhase.IBI_DATA_TBIT:
            self._on_ibi_data_tbit_fall(bus_sda)
        elif self._phase == BusPhase.CCC_BYTE:
            self._on_ccc_byte_fall()
        elif self._phase == BusPhase.CCC_TBIT:
            self._on_ccc_tbit_fall()
        elif self._phase == BusPhase.ENTDAA:
            self._on_entdaa_fall()

        self._check_target_silent_nonmatching()

    # --------------------------------------------------------------
    # Address phase
    # --------------------------------------------------------------

    def _enter_addr_phase(self, is_repeated_start):
        """Start clocking an address header."""
        self._is_repeated_start = is_repeated_start
        self._bit_count = 0
        self._addr_accum = 0
        self._rnw = 0
        self._is_broadcast = False
        self._is_addressed_to_dut = False
        self._is_addr_virt = False
        self._is_ibi = False
        self._dut_drove_addr = False
        self._byte_in_msg = 0
        self._data_accum = 0

        # Preserve _active_ccc_code across Sr boundaries for direct CCC tracking.
        # Only clear _is_ccc — it will be re-evaluated after the address phase.
        self._is_ccc = False

        # IBI: target-initiated START (not Sr) can be an IBI attempt
        # We'll detect this during address bits based on DUT driving behavior
        self._phase = BusPhase.ADDR_BITS
        self.stats['addr_phases'] += 1

    def _on_addr_bit_rise(self, bus_sda):
        """Sample address bit on SCL rising edge."""
        if self._bit_count < 7:
            # Accumulate address bits
            self._addr_accum = (self._addr_accum << 1) | bus_sda

            # Track if DUT is driving during address bits (for IBI detection)
            if not self._is_repeated_start and self._dut_is_driving():
                self._dut_drove_addr = True

            # Check 2: Address phase must use Open Drain (S5.1.2.2.1)
            # After a START (not Sr), the address is arbitrable --> OD required
            # After Sr, controller drives PP but target should NOT drive at all
            if not self._is_repeated_start:
                # Arbitrable header after START: DUT should use OD if driving
                if self._dut_is_driving() and self._dut_is_pp():
                    self._record_violation(
                        "ADDR_OD",
                        f"DUT using PP during arbitrable address bit[{self._bit_count}] "
                        f"after START (S5.1.2.2.1)"
                    )
            else:
                # Check 3: After Repeated START, Target shall NOT drive address
                # (S5.1.2.2.4)
                if self._dut_is_driving():
                    # Exception: if it's an IBI request... but IBI is only after
                    # START not Sr, so driving here is always wrong
                    self._record_violation(
                        "NO_ARB_AFTER_SR",
                        f"DUT driving SDA during address after Repeated START "
                        f"bit[{self._bit_count}] (S5.1.2.2.4)"
                    )

        elif self._bit_count == 7:
            # RnW bit
            self._rnw = bus_sda

        self._bit_count += 1

    def _on_addr_bit_fall(self):
        """After 8 bits (7 addr + RnW), move to ACK phase."""
        if self._bit_count >= 8:
            addr = self._addr_accum
            self._is_broadcast = (addr == self.I3C_BROADCAST_ADDR)
            self._is_addressed_to_dut = (
                (self._dut_dynamic_addr is not None and
                 addr == self._dut_dynamic_addr) or
                (self._virt_dynamic_addr is not None and
                 addr == self._virt_dynamic_addr)
            )
            self._is_addr_virt = (
                self._virt_dynamic_addr is not None and
                addr == self._virt_dynamic_addr
            )

            # Detect IBI: target-initiated, addr matches DUT, RnW=1,
            # not after Sr, AND DUT was driving address bits (distinguishes
            # IBI from controller-initiated private read)
            if (not self._is_repeated_start and
                    self._is_addressed_to_dut and self._rnw == 1 and
                    self._dut_drove_addr):
                self._is_ibi = True
                self.stats['ibi_requests'] += 1
                self._phase = BusPhase.IBI_ADDR_ACK
            else:
                self._phase = BusPhase.ADDR_ACK

    def _on_addr_ack_rise(self, bus_sda):
        """
        Check 4: ACK/NACK bit -- always Open Drain (S5.1.2.2.4).
        Target drives ACK low in OD; NACK = passive (not driving).

        Check 5 scheduling: If write-ACK, schedule a handoff check at tSCO
        after this rising edge (S5.1.2.3.1 step 2).
        """
        if self._is_addressed_to_dut or self._is_broadcast:
            if self._dut_is_driving() and self._dut_is_pp():
                self._record_violation(
                    "ACK_OD",
                    f"DUT using PP during ACK/NACK (must be OD) "
                    f"addr=0x{self._addr_accum:02X} (S5.1.2.2.4)"
                )

        # Check 5: Schedule write-ACK handoff verification at tSCO.
        # Per S5.1.2.3.1 step 2: "After the I3C Target sees the rising edge
        # of SCL, it releases the SDA line to High-Z." The release must
        # occur within tSCO (max 12 ns, Table 86 §6.2).
        if (self._is_addressed_to_dut or self._is_broadcast) and self._rnw == 0:
            if bus_sda == 0:  # ACK (Target is driving SDA low)
                self._handoff_check_time = (
                    cocotb.utils.get_sim_time('ns') + self.TSCO_MAX_NS
                )
                self._handoff_addr = self._addr_accum

    def _on_addr_ack_fall(self, bus_sda):
        """
        After ACK, determine next phase based on address and RnW.
        """
        acked = (bus_sda == 0)

        if not acked:
            # NACKed -- target goes idle until next START/Sr
            self._phase = BusPhase.IDLE
            return

        if self._is_broadcast and self._rnw == 0:
            # Broadcast write --> expecting CCC command byte
            self._phase = BusPhase.CCC_BYTE
            self._bit_count = 0
            self._data_accum = 0
            self._byte_in_msg = 0
            # Clear any previous CCC context on new broadcast
            self._active_ccc_code = None
            self._ccc_defining_byte = None
            self._ccc_read_bytes = []
            self._ccc_write_bytes = []
            self._in_ccc_read_phase = False
            self._ccc_read_expected = None
            self._in_ccc_write_phase = False
            return

        if self._is_addressed_to_dut or self._is_broadcast:
            # ENTDAA: Sr + 7'h7E/R ACK -> enter DAA data phase (S5.1.4.2)
            if self._is_entdaa and self._is_broadcast and self._rnw == 1:
                self._phase = BusPhase.ENTDAA
                self._entdaa_bit_count = 0
                self.log.debug("I3cBusMonitor: Entering ENTDAA data phase")
                return

            if self._rnw == 0:
                # Check if this is a direct CCC write phase (Sr + target_addr/W)
                if self._active_ccc_code is not None and self._is_repeated_start:
                    self._in_ccc_write_phase = True
                    self._ccc_write_bytes = []
                    self._ccc_direct_addr = self._addr_accum
                # Private write to DUT (or direct CCC write)
                self._phase = BusPhase.WRITE_DATA
                self._bit_count = 0
                self._data_accum = 0
            else:
                # Check if this is a direct CCC read phase (Sr + target_addr/R)
                if self._active_ccc_code is not None and self._is_repeated_start:
                    self._in_ccc_read_phase = True
                    self._ccc_read_bytes = []
                    self._ccc_direct_addr = self._addr_accum
                    # Snapshot expected response now (before the design starts
                    # serializing data onto the bus), so the comparison at STOP
                    # is immune to FW writes that race the CCC.
                    self._ccc_read_expected = self._compute_expected_ccc_read(
                        self._active_ccc_code
                    )
                # Private read from DUT -- target will transmit in PP
                self._phase = BusPhase.READ_DATA
                self._bit_count = 0
                self._data_accum = 0
        else:
            # Not addressed to DUT -- go idle, DUT should be silent
            self._phase = BusPhase.IDLE

    # --------------------------------------------------------------
    # Write data (Controller --> Target)
    # --------------------------------------------------------------

    def _on_write_data_fall(self):
        """Count write data bits. DUT should NOT drive during controller writes."""
        self._bit_count += 1
        if self._bit_count >= 8:
            self._phase = BusPhase.WRITE_TBIT
            self._bit_count = 0

    def _on_write_tbit_fall(self):
        """After T-bit (parity), capture byte for CCC tracking, then next byte."""
        self.stats['write_bytes'] += 1
        # Capture complete write byte for CCC SET tracking
        if self._in_ccc_write_phase:
            self._ccc_write_bytes.append(self._data_accum & 0xFF)
        self._byte_in_msg += 1
        self._phase = BusPhase.WRITE_DATA
        self._bit_count = 0
        self._data_accum = 0

    # --------------------------------------------------------------
    # Read data (Target --> Controller)
    # --------------------------------------------------------------

    def _on_read_data_rise(self):
        """
        Check 7: During read data, Target should be in PP mode (S5.1.2.3).
        """
        if self._is_addressed_to_dut:
            if self._dut_is_driving() and self._dut_is_od():
                self._record_violation(
                    "READ_PP",
                    f"DUT driving read data in OD mode -- must use PP (S5.1.2.3)"
                )

    def _on_read_data_fall(self):
        """Count read data bits."""
        self._bit_count += 1
        if self._bit_count >= 8:
            self._phase = BusPhase.READ_TBIT
            self._bit_count = 0

    def _on_read_tbit_rise(self, bus_sda):
        """
        Check 8/9: T-bit behavior on SCL rising edge (S5.1.2.3.4).
        Check 13: T-bit must be driven in PP mode (S5.1.2.3).

        After the rising edge, the Target shall release SDA to Hi-Z within
        tSCO (max 12ns, Table 87 S6.2):
        - T-bit=0 (end): Target sets SDA low on falling, releases on rising
        - T-bit=1 (continue): Target sets SDA high on falling, releases on rising

        Both cases shown in Figures 150, 151, 152 with tSCO annotated.
        """
        if self._is_addressed_to_dut:
            # Check 13: T-bit must be PP (same as read data)
            if self._dut_is_driving() and self._dut_is_od():
                self._record_violation(
                    "READ_TBIT_PP",
                    f"DUT driving read T-bit in OD mode -- must use PP "
                    f"(S5.1.2.3, S5.1.2.3.4)"
                )

            # Check 8/9: Schedule tSCO release check.
            # Target must release SDA to Hi-Z within tSCO after this rising edge.
            self._handoff_check_time = (
                cocotb.utils.get_sim_time('ns') + self.TSCO_MAX_NS
            )
            self._handoff_addr = self._addr_accum
            self._handoff_check_id = "READ_TBIT_RELEASE"
            self._handoff_spec_ref = "S5.1.2.3.4, Figs 150-152"

    def _on_read_tbit_fall(self, bus_sda):
        """
        After T-bit, check that the Target has properly released SDA.

        Check 8: T-bit=0 (end) -- Target released to Hi-Z, controller takes over
        Check 9: T-bit=1 (continue) -- Target released, checks if controller aborted

        At this falling edge, the DUT should be back in OD mode after releasing.
        """
        self.stats['read_bytes'] += 1
        # Capture complete read byte for CCC GET tracking
        if self._in_ccc_read_phase:
            self._ccc_read_bytes.append(self._data_accum & 0xFF)
        self._byte_in_msg += 1

        # After T-bit, if SDA went low during SCL high, controller aborted (Repeated START)
        # Otherwise, Target continues with next byte.
        # Either way, we transition appropriately.

        # The actual phase transition is handled by START/STOP detection.
        # If no START/STOP happened, we continue reading.
        self._phase = BusPhase.READ_DATA
        self._bit_count = 0
        self._data_accum = 0

    # --------------------------------------------------------------
    # ENTDAA data phase (S5.1.4.2)
    # 64 bits PID/BCR/DCR (Target drives OD) +
    # 8 bits DA+PAR (Controller drives OD) +
    # 1 bit ACK/NACK (Target drives OD)
    # --------------------------------------------------------------

    def _on_entdaa_rise(self, bus_sda):
        """ENTDAA bit sampling on SCL rising edge.

        Checks:
        - Bits 0-63 (PID/BCR/DCR): DUT must drive in OD mode (S5.1.4.2).
        - At bit 63 (last DCR bit): schedule tSCO check for Target release
          before Controller starts driving DA[6] at bit 64 (S5.1.2.5.4).
        - Bits 64-71 (DA+PAR): DUT must NOT drive (Controller phase).

        Per Figure 25 the ACK/NACK at bit 72 is explicitly "without Handoff"
        so no tSCO check is applied there.
        """
        bc = self._entdaa_bit_count

        if bc < 64:
            # PID/BCR/DCR phase: Target drives in Open Drain (S5.1.4.2)
            if self._dut_is_driving() and self._dut_is_pp():
                self._record_violation(
                    "ENTDAA_OD",
                    f"DUT driving ENTDAA PID/BCR/DCR bit[{bc}] in PP mode "
                    f"-- must use OD (S5.1.4.2)"
                )

            if bc == 63:
                # Last DCR bit sampled -- Target must release within tSCO
                # so Controller can drive DA[6] at bit 64 (S5.1.2.5.4, Figure 23)
                self._handoff_check_time = cocotb.utils.get_sim_time('ns') + self.TSCO_MAX_NS
                self._handoff_addr = self.I3C_BROADCAST_ADDR
                self._handoff_check_id = "ENTDAA_DA_HANDOFF"
                self._handoff_spec_ref = "S5.1.4.2 step 9, S5.1.2.5.4"

        elif 64 <= bc < 72:
            # DA + PAR phase: Controller drives, Target must not drive
            if self._dut_is_driving():
                self._record_violation(
                    "ENTDAA_DA_HANDOFF",
                    f"DUT driving SDA during ENTDAA DA assignment "
                    f"bit[{bc - 64}] -- Controller drives DA+PAR, "
                    f"Target must release (S5.1.4.2 step 9)"
                )

    def _on_entdaa_fall(self):
        """ENTDAA bit counting on SCL falling edge."""
        self._entdaa_bit_count += 1
        if self._entdaa_bit_count >= 73:
            # Round complete (ACK/NACK received)
            # Phase will be reset by Sr/P detection
            self.log.debug("I3cBusMonitor: ENTDAA round complete (73 bits)")
            self._phase = BusPhase.IDLE

    # --------------------------------------------------------------
    # IBI phases
    # --------------------------------------------------------------

    def _on_ibi_ack_rise(self, bus_sda):
        """
        Check 4b: IBI ACK/NACK bit -- always Open Drain (S5.1.6.2).
        Controller drives ACK low in OD; NACK = passive (not driving).

        Check 6 scheduling: If ACKed (SDA=0), schedule a tSCO handoff check
        for the Target->PP transition to MDB (S5.1.2.3.2).
        """
        # OD mode check: DUT should not be driving PP during IBI ACK/NACK
        if self._dut_is_driving() and self._dut_is_pp():
            self._record_violation(
                "IBI_ACK_OD",
                f"DUT using PP during IBI ACK/NACK (must be OD) (S5.1.6.2)"
            )

        # Schedule IBI-ACK takeover check: if ACKed, Target must drive
        # SDA Low in PP within tSCO to send MDB (S5.1.2.3.2 step 2)
        acked = (bus_sda == 0)
        if acked:
            self._ibi_takeover_check_time = (
                cocotb.utils.get_sim_time('ns') + self.TSCO_MAX_NS
            )
            self._ibi_takeover_addr = self._addr_accum

    def _on_ibi_ack_fall(self, bus_sda):
        """
        After IBI ACK/NACK on SCL falling.

        Check 6: IBI ACK handoff -- if Controller ACKed (SDA=0), Target shall
        take over SDA in PP to send MDB (S5.1.2.3.2).
        """
        acked = (bus_sda == 0)
        if acked:
            self._phase = BusPhase.IBI_MDB
            self._bit_count = 0
            self._data_accum = 0
        else:
            # NACKed -- Target should stop driving
            self._phase = BusPhase.IDLE

    def _on_ibi_mdb_fall(self):
        """Count MDB bits. After 8 bits, move to T-bit for additional data."""
        self._bit_count += 1
        if self._bit_count >= 8:
            # MDB complete; now T-bit decides if more data follows
            self._phase = BusPhase.IBI_DATA_TBIT
            self._bit_count = 0

    def _on_ibi_data_fall(self):
        """Count additional IBI data bits."""
        self._bit_count += 1
        if self._bit_count >= 8:
            self._phase = BusPhase.IBI_DATA_TBIT
            self._bit_count = 0

    def _on_ibi_data_tbit_fall(self, bus_sda):
        """After IBI data T-bit, continue or end."""
        self.stats['read_bytes'] += 1
        # If T-bit=0, Target ends. If T-bit=1, continue.
        # Phase transition handled by START/STOP detection.
        self._phase = BusPhase.IBI_DATA
        self._bit_count = 0

    # --------------------------------------------------------------
    # CCC phases
    # --------------------------------------------------------------

    def _on_ccc_byte_fall(self):
        """Count CCC byte bits."""
        self._bit_count += 1
        if self._bit_count >= 8:
            self._phase = BusPhase.CCC_TBIT
            self._bit_count = 0

    def _on_ccc_tbit_fall(self):
        """After CCC T-bit, check for ENTHDR/ENTDAA, track CCC code, and await next byte or Sr/P."""
        if self._byte_in_msg == 0:
            # First CCC byte is the command code
            self._ccc_code = self._data_accum & 0xFF
            self._active_ccc_code = self._ccc_code
            self._ccc_defining_byte = None

            # ENTDAA (0x07): enter DAA mode on next Sr+7E/R
            if self._ccc_code == 0x07:
                self._is_entdaa = True
                self.log.debug("I3cBusMonitor: ENTDAA CCC detected")

            # ENTHDR0-ENTHDR7 (0x20-0x27): bus enters HDR mode after this frame
            if 0x20 <= self._ccc_code <= 0x27:
                self.log.debug(
                    f"I3cBusMonitor: ENTHDR CCC 0x{self._ccc_code:02X} detected, "
                    f"entering HDR_MODE"
                )
                self._phase = BusPhase.HDR_MODE
                self._bus_active = False
                self._active_ccc_code = None
                return
        elif self._byte_in_msg == 1 and self._active_ccc_code is not None:
            # Second byte may be a defining byte (for RSTACT, GETCAPS, etc.)
            self._ccc_defining_byte = self._data_accum & 0xFF

        self._byte_in_msg += 1
        self._phase = BusPhase.CCC_BYTE
        self._bit_count = 0
        self._data_accum = 0

    # --------------------------------------------------------------
    # CCC Completion Checks (M1, M2, M3, M4)
    # --------------------------------------------------------------

    def _get_ccc_signal_path(self):
        """Return the CCC module's hierarchical path in the DUT."""
        try:
            return self.dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xccc
        except AttributeError:
            return None

    def _get_config_path(self):
        """Return the configuration module's hierarchical path."""
        try:
            return self.dut.xi3c_wrapper.i3c.xcontroller.xconfiguration
        except AttributeError:
            return None

    def _read_sig_int(self, sig, width=None):
        """Read a signal value as int, return None on X/Z."""
        try:
            return int(sig.value)
        except (ValueError, AttributeError):
            return None

    def _is_virt_target(self):
        """Check if the direct CCC target is the virtual target."""
        return (self._ccc_direct_addr is not None and
                self._virt_dynamic_addr is not None and
                self._ccc_direct_addr == self._virt_dynamic_addr)

    def _get_expected_ccc_read_count(self):
        """Return expected byte count for the active GET CCC, or None."""
        if self._active_ccc_code is None:
            return None
        count = self._GET_CCC_BYTE_COUNTS.get(self._active_ccc_code)
        if count is not None:
            return count
        # GETCAPS byte count depends on defining byte
        if self._active_ccc_code == 0x95:
            if self._ccc_defining_byte in (None, 0x00):
                return 3
            elif self._ccc_defining_byte == 0x93:
                return 1
            else:
                return None  # Unknown defining byte — skip check
        return None

    def _check_ccc_completion(self):
        """On STOP, verify CCC response/CSR consistency."""
        if self._active_ccc_code is None:
            return

        ccc = self._active_ccc_code

        # M1: Check GET CCC response data
        if self._in_ccc_read_phase and self._ccc_read_bytes:
            self._check_get_ccc_response(ccc)

        # M3: Check SET CCC CSR consistency
        if self._in_ccc_write_phase and self._ccc_write_bytes:
            self._check_set_ccc_csr(ccc)

        # M2: Check address CCC CSR consistency
        if ccc in self._ADDR_CCC_CODES:
            self._check_addr_ccc_csr(ccc)

    def _compute_expected_ccc_read(self, ccc):
        """Compute the expected GET CCC response bytes from current DUT CSRs.

        Returns a list of expected bytes (possibly empty / containing None
        if signals cannot be resolved), or None if the CCC has no checker.
        Intended to be called at the moment the directed-read phase begins
        so the result is immune to later concurrent FW CSR writes.
        """
        ccc_mod = self._get_ccc_signal_path()
        if ccc_mod is None:
            return None

        is_virt = self._is_virt_target()
        expected = []

        try:
            if ccc == 0x8E:  # GETBCR
                if is_virt:
                    expected = [self._read_sig_int(ccc_mod.virtual_get_bcr_i)]
                else:
                    expected = [self._read_sig_int(ccc_mod.get_bcr_i)]

            elif ccc == 0x8F:  # GETDCR
                if is_virt:
                    expected = [self._read_sig_int(ccc_mod.virtual_get_dcr_i)]
                else:
                    expected = [self._read_sig_int(ccc_mod.get_dcr_i)]

            elif ccc == 0x90:  # GETSTATUS
                status = self._read_sig_int(ccc_mod.get_status_fmt1_i)
                if status is not None:
                    byte0 = (status >> 8) & 0xFF
                    byte1 = status & 0xFF
                    if is_virt:
                        # Activity state = 3, PENDING_INTERRUPT = 0
                        byte1 = (0b11 << 6) | (byte1 & 0x20) | 0
                    expected = [byte0, byte1]

            elif ccc == 0x8B:  # GETMWL
                mwl = self._read_sig_int(ccc_mod.get_mwl_i)
                if mwl is not None:
                    expected = [(mwl >> 8) & 0xFF, mwl & 0xFF]

            elif ccc == 0x8C:  # GETMRL
                mrl = self._read_sig_int(ccc_mod.get_mrl_i)
                if mrl is not None:
                    ibil_byte = 0x00 if is_virt else self._read_sig_int(ccc_mod.get_ibil_i)
                    if ibil_byte is None:
                        ibil_byte = 0
                    expected = [(mrl >> 8) & 0xFF, mrl & 0xFF, ibil_byte]

            elif ccc == 0x8D:  # GETPID
                if is_virt:
                    pid = self._read_sig_int(ccc_mod.virtual_get_pid_i)
                else:
                    pid = self._read_sig_int(ccc_mod.get_pid_i)
                if pid is not None:
                    expected = [(pid >> (40 - 8*i)) & 0xFF for i in range(6)]

            elif ccc == 0x95:  # GETCAPS
                db = self._ccc_defining_byte
                if db in (None, 0x00):
                    # 3 bytes: capabilities
                    byte2 = 0x00 if is_virt else 0x48
                    expected = [0x00, 0x01, byte2]
                elif db == 0x93:
                    expected = [0x35]

        except Exception:
            return None  # Signal access failure -- skip check

        return expected

    def _check_get_ccc_response(self, ccc):
        """M1: Verify GET CCC response data matches DUT CSR values.

        Uses the expected-bytes snapshot captured at the start of the read
        phase to avoid false mismatches when FW concurrently writes the
        backing CSR while the design is shifting bytes onto the bus.
        """
        got = self._ccc_read_bytes
        expected = self._ccc_read_expected
        # Fallback: if for any reason no snapshot was taken (e.g. read phase
        # entry was missed), compute now -- this preserves prior behavior.
        if expected is None:
            expected = self._compute_expected_ccc_read(ccc)

        if not expected or None in expected:
            return  # Can't determine expected -- skip

        # Compare only the bytes we received (may be truncated by abort)
        for i, (g, e) in enumerate(zip(got, expected)):
            if g != e:
                self._record_violation(
                    "CCC_RESPONSE_DATA",
                    f"CCC 0x{ccc:02X} byte[{i}]: got 0x{g:02X}, "
                    f"expected 0x{e:02X} (virt={self._is_virt_target()}, "
                    f"db={self._ccc_defining_byte})"
                )

    def _check_set_ccc_csr(self, ccc):
        """M3: After SET CCC, verify DUT CSR matches written data."""
        config = self._get_config_path()
        if config is None:
            return

        data = self._ccc_write_bytes

        try:
            if ccc == 0x89 and len(data) >= 2:  # SETMWL (direct)
                csr_val = self._read_sig_int(config.get_mwl_o)
                if csr_val is not None:
                    written = (data[0] << 8) | data[1]
                    if csr_val != written:
                        self._record_violation(
                            "SET_CSR_CONSISTENCY",
                            f"SETMWL: CSR=0x{csr_val:04X}, "
                            f"written=0x{written:04X}"
                        )

            elif ccc == 0x8A and len(data) >= 2:  # SETMRL (direct)
                csr_val = self._read_sig_int(config.get_mrl_o)
                if csr_val is not None:
                    written = (data[0] << 8) | data[1]
                    if csr_val != written:
                        self._record_violation(
                            "SET_CSR_CONSISTENCY",
                            f"SETMRL: CSR=0x{csr_val:04X}, "
                            f"written=0x{written:04X}"
                        )

        except Exception:
            return  # Signal access failure — skip check

    def _check_addr_ccc_csr(self, ccc):
        """M2: Log address CCC completion for debug visibility.

        NOTE: Address CSR verification is intentionally deferred to the test
        level. The monitor lacks context about expected address assignments
        (e.g., which addresses were requested via SETDASA/SETNEWDA). Tests
        should read DAT entries directly to verify CSR consistency.
        """
        if ccc == 0x06:  # RSTDAA
            self.log.debug("I3cBusMonitor: RSTDAA completed")
        elif ccc == 0x29:  # SETAASA
            self.log.debug("I3cBusMonitor: SETAASA completed")
        elif ccc == 0x87:  # SETDASA
            data = self._ccc_write_bytes
            if data:
                self.log.debug(
                    f"I3cBusMonitor: SETDASA to 0x{self._ccc_direct_addr:02X} "
                    f"data={[hex(b) for b in data]}"
                )
        elif ccc == 0x88:  # SETNEWDA
            data = self._ccc_write_bytes
            if data:
                self.log.debug(
                    f"I3cBusMonitor: SETNEWDA to 0x{self._ccc_direct_addr:02X} "
                    f"data={[hex(b) for b in data]}"
                )

    # --------------------------------------------------------------
    # START / STOP detection
    # --------------------------------------------------------------

    def _on_start_detected(self):
        """SDA falling while SCL high --> START or Repeated START."""
        is_sr = self._bus_active
        self._bus_active = True
        self._handoff_check_time = None  # Clear pending handoff check
        self._ibi_takeover_check_time = None  # Clear pending IBI takeover check

        if is_sr:
            self.log.debug(f"I3cBusMonitor: Repeated START detected, was in {self._phase.name}")
            # M4: Detect Sr abort during CCC read phase
            if self._in_ccc_read_phase and self._phase in (BusPhase.READ_DATA, BusPhase.READ_TBIT):
                expected = self._get_expected_ccc_read_count()
                if expected is not None and len(self._ccc_read_bytes) < expected:
                    self._ccc_was_aborted = True
                    self._abort_count += 1
                    self.log.debug(
                        f"I3cBusMonitor: CCC 0x{self._active_ccc_code:02X} Sr-aborted "
                        f"after {len(self._ccc_read_bytes)}/{expected} bytes"
                    )
                self._in_ccc_read_phase = False
                self._ccc_read_expected = None
        else:
            self.log.debug(f"I3cBusMonitor: START detected")
            self.stats['starts_detected'] += 1
            # New START clears CCC context entirely
            self._active_ccc_code = None
            self._ccc_defining_byte = None
            self._in_ccc_read_phase = False
            self._ccc_read_expected = None
            self._in_ccc_write_phase = False

        self._enter_addr_phase(is_repeated_start=is_sr)

    def _on_stop_detected(self):
        """SDA rising while SCL high --> STOP."""
        self.log.debug(f"I3cBusMonitor: STOP detected")
        self.stats['stops_detected'] += 1
        self._handoff_check_time = None  # Clear pending handoff check
        self._ibi_takeover_check_time = None  # Clear pending IBI takeover check

        # M1/M2/M3: Check CCC completion on STOP
        self._check_ccc_completion()

        self._bus_active = False
        self._phase = BusPhase.IDLE
        self._is_ccc = False
        self._is_entdaa = False
        self._active_ccc_code = None
        self._ccc_defining_byte = None
        self._in_ccc_read_phase = False
        self._ccc_read_expected = None
        self._in_ccc_write_phase = False

    # --------------------------------------------------------------
    # Main monitoring loop
    # --------------------------------------------------------------

    async def _monitor_loop(self):
        """
        Edge-driven monitor loop.

        Samples bus_scl and bus_sda on the system clock and detects edges.
        This avoids missing glitches and aligns with how the DUT sees the bus.
        """
        while self._running:
            await RisingEdge(self.clk)

            try:
                scl = int(self.bus_scl.value)
                sda = int(self.bus_sda.value)
            except ValueError:
                continue  # X/Z during reset

            scl_rose = (scl == 1 and self._prev_scl == 0)
            scl_fell = (scl == 0 and self._prev_scl == 1)
            sda_fell = (sda == 0 and self._prev_sda == 1)
            sda_rose = (sda == 1 and self._prev_sda == 0)

            # START condition: SDA falls while SCL is high
            if sda_fell and scl == 1 and self._prev_scl == 1:
                if self._phase == BusPhase.HDR_MODE:
                    pass  # Ignore START-like patterns during HDR
                else:
                    self._on_start_detected()

            # STOP condition: SDA rises while SCL is high
            elif sda_rose and scl == 1 and self._prev_scl == 1:
                if self._phase == BusPhase.HDR_MODE:
                    # HDR Exit Pattern ends with STOP -- return to SDR IDLE
                    self.log.debug("I3cBusMonitor: STOP during HDR_MODE, returning to SDR IDLE")
                    self._phase = BusPhase.IDLE
                    self._bus_active = False
                    self._is_ccc = False
                    self._is_entdaa = False
                else:
                    self._on_stop_detected()

            # SCL rising edge
            elif scl_rose:
                if self._phase != BusPhase.HDR_MODE:
                    self._on_scl_rising(sda)

            # SCL falling edge
            elif scl_fell:
                if self._phase != BusPhase.HDR_MODE:
                    self._on_scl_falling(sda)

            self._prev_scl = scl
            self._prev_sda = sda

            # Handoff tSCO deadline check (generic for write-ACK and ENTDAA)
            # Fires tSCO (max 12 ns) after the relevant SCL rising edge.
            # By this time the Target must have released SDA to Hi-Z.
            if self._handoff_check_time is not None:
                now_ns = cocotb.utils.get_sim_time('ns')
                if now_ns >= self._handoff_check_time:
                    if self._dut_is_driving():
                        self._record_violation(
                            self._handoff_check_id,
                            f"DUT still driving SDA (sda_oe=1) "
                            f"{self.TSCO_MAX_NS}ns after SCL rising edge "
                            f"-- Target must release SDA to Hi-Z within "
                            f"tSCO (max {self.TSCO_MAX_NS}ns, Table 86 "
                            f"S6.2, {self._handoff_spec_ref}) "
                            f"addr=0x{self._handoff_addr:02X}"
                        )
                    self._handoff_check_time = None

            # IBI ACK takeover check (S5.1.2.3.2 step 2)
            # After IBI ACK, Target must drive SDA Low in PP within tSCO.
            if self._ibi_takeover_check_time is not None:
                now_ns = cocotb.utils.get_sim_time('ns')
                if now_ns >= self._ibi_takeover_check_time:
                    if not (self._dut_is_driving() and self._dut_is_pp()):
                        self._record_violation(
                            "IBI_ACK_HANDOFF",
                            f"DUT not driving SDA in PP "
                            f"{self.TSCO_MAX_NS}ns after ACK rising edge "
                            f"-- Target must take over SDA in Push-Pull "
                            f"within tSCO (max {self.TSCO_MAX_NS}ns, "
                            f"Table 87 S6.2, S5.1.2.3.2) "
                            f"addr=0x{self._ibi_takeover_addr:02X}"
                        )
                    self._ibi_takeover_check_time = None

    def report(self):
        """Print monitoring summary."""
        self.log.info("=" * 72)
        self.log.info("I3C Bus Monitor Report")
        self.log.info("=" * 72)
        self.log.info(f"  SCL edges observed:      {self.stats['scl_edges']}")
        self.log.info(f"  STARTs detected:         {self.stats['starts_detected']}")
        self.log.info(f"  STOPs detected:          {self.stats['stops_detected']}")
        self.log.info(f"  Address phases:          {self.stats['addr_phases']}")
        self.log.info(f"  Write bytes:             {self.stats['write_bytes']}")
        self.log.info(f"  Read bytes:              {self.stats['read_bytes']}")
        self.log.info(f"  IBI requests:            {self.stats['ibi_requests']}")
        self.log.info(f"  OD mode samples:         {self.stats['od_samples']}")
        self.log.info(f"  PP mode samples:         {self.stats['pp_samples']}")
        self.log.info(f"  Contention checks:       {self.stats['contention_checks']}")
        self.log.info(f"  CCC aborts detected:     {self._abort_count}")
        self.log.info(f"  Total violations:        {self.violation_count}")
        if self.violations:
            self.log.error("  VIOLATIONS:")
            for v in self.violations:
                self.log.error(f"    {v}")
        else:
            self.log.info("  OK: No violations detected")
        self.log.info("=" * 72)
