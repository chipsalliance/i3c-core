# SPDX-License-Identifier: Apache-2.0

from bus2csr import get_frontend_bus_if
from cocotb_helpers import reset_n
from reg_map import reg_map
from tti_monitor import TtiQueueMonitor
from i3c_bus_monitor import I3cBusMonitor
from te_error_monitor import TeErrorEventMonitor, HdrRecoveryMonitor, PostTe2DataIntegrityMonitor

import cocotb
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles


class I3CTopTestInterface:

    def __init__(self, dut: SimHandleBase) -> None:
        self.dut = dut
        self.bus_if_cls = get_frontend_bus_if()
        self.reg_map = reg_map

        self.busIf = self.bus_if_cls(dut)
        self.clk = self.busIf.clk
        self.rst_n = self.busIf.rst_n
        self.read_csr = self.busIf.read_csr
        self.write_csr = self.busIf.write_csr
        self.read_csr_field = self.busIf.read_csr_field
        self.write_csr_field = self.busIf.write_csr_field
        self.tti_monitor = None
        self.bus_monitor = None
        self.te_error_monitor = None
        self.hdr_recovery_monitor = None
        self.te2_integrity_monitor = None

    async def setup(self, fclk=500.0):

        # Limit the requested clock frequency if a limit is set via cocotb
        # plusargs
        fmin = cocotb.plusargs.get("MinSystemClockFrequency", None)
        if fmin is not None:
            fmin = float(fmin)
            if fclk < fmin:
                self.dut._log.warning(f"Enforcing min. system clock frequency of {fmin:.3f} MHz")
                fclk = fmin

        if hasattr(self.dut, "disable_id_filtering_i"):
            self.dut.disable_id_filtering_i.value = 1

        await self.busIf.register_test_interfaces(fclk)
        await ClockCycles(self.clk, 20)
        await reset_n(self.clk, self.rst_n, cycles=5)

        # Start TtiQueueMonitor for every test
        try:
            self.tti_monitor = TtiQueueMonitor(self.dut, self.clk)
            cocotb.start_soon(self.tti_monitor.run())
        except AttributeError:
            self.dut._log.warning("TtiQueueMonitor: required signals not found, skipping")
            self.tti_monitor = None

        # Start I3C Bus Monitor for every test
        try:
            self.bus_monitor = I3cBusMonitor(self.dut, self.clk)
            if self.bus_monitor.is_available():
                await self.bus_monitor.start()
            else:
                self.dut._log.warning("I3cBusMonitor: signals not available, skipping")
                self.bus_monitor = None
        except Exception as e:
            self.dut._log.warning(f"I3cBusMonitor: failed to start: {e}")
            self.bus_monitor = None

        # Start TE Error Monitors for every test
        try:
            self.te_error_monitor = TeErrorEventMonitor(self.dut, self.clk)
            cocotb.start_soon(self.te_error_monitor.run())
        except (AttributeError, Exception) as e:
            self.dut._log.warning(f"TeErrorEventMonitor: failed to start: {e}")
            self.te_error_monitor = None

        try:
            self.hdr_recovery_monitor = HdrRecoveryMonitor(self.dut)
            cocotb.start_soon(self.hdr_recovery_monitor.run())
        except (AttributeError, Exception) as e:
            self.dut._log.warning(f"HdrRecoveryMonitor: failed to start: {e}")
            self.hdr_recovery_monitor = None

        try:
            self.te2_integrity_monitor = PostTe2DataIntegrityMonitor(self.dut, self.clk)
            cocotb.start_soon(self.te2_integrity_monitor.run())
        except (AttributeError, Exception) as e:
            self.dut._log.warning(f"PostTe2DataIntegrityMonitor: failed to start: {e}")
            self.te2_integrity_monitor = None

    async def teardown(self):
        """End-of-test checks. Call at end of every @cocotb.test()."""
        if self.te_error_monitor:
            self.te_error_monitor.check()
        if self.te2_integrity_monitor:
            self.te2_integrity_monitor.check()
        if self.bus_monitor:
            self.bus_monitor.check()
