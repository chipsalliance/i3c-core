# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.triggers import RisingEdge


class BusMonitor:
    def __init__(self, dut):
        signals = [
            "t_r_i",
            "t_f_i",
            "scl_negedge_i",
            "scl_posedge_i",
            "scl_stable_low_i",
            "scl_stable_high_i",
        ]
        self.log = dut._log
        self.clk = dut.clk_i
        self.scl = dut.scl_i

        for name in signals:
            if hasattr(dut, name):
                setattr(self, name[:-2], getattr(dut, name))

    async def is_signal_stable(self, signal, value, stable_cycles):
        """
        Ensure that the signal is in stable state for given number of clock cycles
        """
        for _ in range(stable_cycles):
            if signal != value:
                return False
            await RisingEdge(self.clk)
        return True

    async def report_scl_negedge(self):
        """
        Coroutine to detect SCL negedge while ensuring it is stable transition
        """
        try:
            last_scl = self.scl.value
            while True:
                self.scl_negedge.value = 0  # Always LOW until SCL negedge
                if (
                    (last_scl)
                    and (not self.scl.value)
                    and (await self.is_signal_stable(self.scl, 0, self.t_f.value))
                ):
                    self.scl_negedge.value = 1
                last_scl = self.scl.value
                await RisingEdge(self.clk)
        except AttributeError:
            self.log.debug(
                "SCL negedge detector not spawned, DUT does not contain `t_f_i` or `scl_negedge` ports"
            )

    async def report_scl_posedge(self):
        """
        Coroutine to detect SCL posedge while ensuring it is stable transition
        """
        try:
            last_scl = self.scl.value
            while True:
                self.scl_posedge.value = 0  # Always LOW until SCL posedge
                if (
                    (not last_scl)
                    and (self.scl.value)
                    and (await self.is_signal_stable(self.scl, 1, self.t_r.value))
                ):
                    self.scl_posedge.value = 1
                last_scl = self.scl.value
                await RisingEdge(self.clk)
        except AttributeError:
            self.log.debug(
                "SCL posedge detector not spawned, DUT does not contain `t_r_i` or `scl_posedge` ports"
            )

    async def report_scl_stable_low(self):
        """
        Coroutine to detect SCL LOW state while ensuring it is stable signal
        """
        try:
            last_scl = self.scl.value
            while True:
                if not self.scl.value:
                    # If previous SCL was HIGH, ensure it is stable LOW now
                    if last_scl:
                        if await self.is_signal_stable(self.scl, 0, self.t_f.value):
                            self.scl_stable_low.value = 1
                        else:
                            self.scl_stable_low.value = 0
                else:  # SCL is HIGH
                    self.scl_stable_low.value = 0
                last_scl = self.scl.value
                await RisingEdge(self.clk)
        except AttributeError:
            self.log.debug(
                "SCL stable LOW detector not spawned, DUT does not contain `t_f_i` or `scl_negedge` ports"
            )

    async def report_scl_stable_high(self):
        """
        Coroutine to detect SCL HIGH state while ensuring it is stable signal
        """
        try:
            last_scl = self.scl.value
            while True:
                if self.scl.value:
                    # If previous SCL was LOW, ensure it is stable HIGH now
                    if not last_scl:
                        if await self.is_signal_stable(self.scl, 1, self.t_r.value):
                            self.scl_stable_high.value = 1
                        else:
                            self.scl_stable_high.value = 0
                else:  # SCL is LOW
                    self.scl_stable_high.value = 0
                last_scl = self.scl.value
                await RisingEdge(self.clk)
        except AttributeError:
            self.log.debug(
                "SCL stable HIGH detector not spawned, DUT does not contain `t_r_i` or `scl_posedge` ports"
            )

    def start(self):
        """
        Run simulated model of crucial bus monitor detectors:
        - SCL negedge
        - SCL posedge
        - SCL stable LOW
        - SCL stable HIGH

        Bus events are reported after ensuring that they are in stable state.
        """
        cocotb.start_soon(self.report_scl_negedge())
        cocotb.start_soon(self.report_scl_posedge())
        cocotb.start_soon(self.report_scl_stable_low())
        cocotb.start_soon(self.report_scl_stable_high())
