# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.triggers import RisingEdge


class BusMonitor:
    def __init__(self, dut):
        signals = [
            "t_r_i",
            "t_f_i",
            "t_hd_dat_i",
            "scl_negedge_i",
            "scl_posedge_i",
            "scl_stable_low_i",
            "scl_stable_high_i",
            "sda_negedge_i",
            "sda_posedge_i",
            "sda_stable_low_i",
            "sda_stable_high_i",
            "bus_start_det_i",
            "bus_stop_det_i",
        ]
        self.log = dut._log
        self.clk = dut.clk_i
        self.dut = dut

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

    async def report_negedge(self, signal, signal_negedge, t_f):
        """
        Coroutine to detect SCL negedge while ensuring it is stable transition
        """
        last_scl = signal.value
        while True:
            signal_negedge.value = 0  # Always LOW until SCL negedge
            if (
                (last_scl)
                and (not signal.value)
                and (await self.is_signal_stable(signal, 0, t_f.value))
            ):
                signal_negedge.value = 1
            last_scl = signal.value
            await RisingEdge(self.clk)

    async def report_posedge(self, signal, signal_posedge, t_r):
        """
        Coroutine to detect SCL posedge while ensuring it is stable transition
        """
        last_scl = signal.value
        while True:
            signal_posedge.value = 0  # Always LOW until SCL posedge
            if (
                (not last_scl)
                and (signal.value)
                and (await self.is_signal_stable(signal, 1, t_r.value))
            ):
                signal_posedge.value = 1
            last_scl = signal.value
            await RisingEdge(self.clk)

    async def report_stable_low(self, signal, signal_stable_low, t_f):
        """
        Coroutine to detect SCL LOW state while ensuring it is stable signal
        """
        last_scl = signal.value
        while True:
            if not signal.value:
                # If previous SCL was HIGH, ensure it is stable LOW now
                if last_scl:
                    if await self.is_signal_stable(signal, 0, t_f.value):
                        signal_stable_low.value = 1
                    else:
                        signal_stable_low.value = 0
            else:  # SCL is HIGH
                signal_stable_low.value = 0
            last_scl = signal.value
            await RisingEdge(self.clk)

    async def report_stable_high(self, signal, signal_stable_high, t_r):
        """
        Coroutine to detect SCL HIGH state while ensuring it is stable signal
        """
        last_scl = signal.value
        while True:
            if signal.value:
                # If previous SCL was LOW, ensure it is stable HIGH now
                if not last_scl:
                    if await self.is_signal_stable(signal, 1, t_r.value):
                        signal_stable_high.value = 1
                    else:
                        signal_stable_high.value = 0
            else:  # SCL is LOW
                signal_stable_high.value = 0
            last_scl = signal.value
            await RisingEdge(self.clk)

    async def report_bus_start_condition(
        self, start_det, sda_negedge, scl_negedge, scl_stable_high
    ):
        """
        Coroutine to detect the bus START condition
        """
        while True:
            if (
                (sda_negedge.value and not scl_negedge.value)
                and scl_stable_high.value
                and (await self.is_signal_stable(self.dut.scl_i, 1, self.t_hd_dat))
            ):
                start_det.value = 1
            else:
                start_det.value = 0

    async def report_bus_stop_condition(self, stop_det, sda_posedge, scl_posedge, scl_stable_high):
        """
        Coroutine to detect the bus START condition
        """
        while True:
            if (
                (sda_posedge.value and not scl_posedge.value)
                and scl_stable_high.value
                and (await self.is_signal_stable(self.dut.scl_i, 1, self.t_hd_dat))
            ):
                stop_det.value = 1
            else:
                stop_det.value = 0

    def start(self):
        """
        Run simulated model of crucial bus monitor detectors:
        - SCL negedge
        - SCL posedge
        - SCL stable LOW
        - SCL stable HIGH
        - SDA negedge
        - SDA posedge
        - SDA stable LOW
        - SDA stable HIGH
        - Bus START condition
        - Bus STOP condition

        Bus events are reported after ensuring that they are in stable state.
        """
        # SCL
        try:
            cocotb.start_soon(self.report_negedge(self.dut.scl_i, self.scl_negedge, self.t_r))
        except AttributeError:
            self.log.debug(
                "SCL stable HIGH detector not spawned, DUT does not contain `t_r_i` or `scl_posedge` ports"
            )
        try:
            cocotb.start_soon(self.report_posedge(self.dut.scl_i, self.scl_posedge, self.t_f))
        except AttributeError:
            self.log.debug(
                "SCL stable LOW detector not spawned, DUT does not contain `t_f_i` or `scl_negedge` ports"
            )
        try:
            cocotb.start_soon(self.report_stable_low(self.dut.scl_i, self.scl_stable_low, self.t_r))
        except AttributeError:
            self.log.debug(
                "SCL posedge detector not spawned, DUT does not contain `t_r_i` or `scl_posedge` ports"
            )
        try:
            cocotb.start_soon(
                self.report_stable_high(self.dut.scl_i, self.scl_stable_high, self.t_f)
            )
        except AttributeError:
            self.log.debug(
                "SCL negedge detector not spawned, DUT does not contain `t_f_i` or `scl_negedge` ports"
            )

        # SDA
        try:
            cocotb.start_soon(self.report_negedge(self.dut.sda_i, self.sda_negedge, self.t_r))
        except AttributeError:
            self.log.debug(
                "SDA stable HIGH detector not spawned, DUT does not contain `t_r_i` or `sda_posedge` ports"
            )
        try:
            cocotb.start_soon(self.report_posedge(self.dut.sda_i, self.sda_posedge, self.t_f))
        except AttributeError:
            self.log.debug(
                "SDA stable LOW detector not spawned, DUT does not contain `t_f_i` or `sda_negedge` ports"
            )
        try:
            cocotb.start_soon(self.report_stable_low(self.dut.sda_i, self.sda_stable_low, self.t_r))
        except AttributeError:
            self.log.debug(
                "SDA posedge detector not spawned, DUT does not contain `t_r_i` or `sda_posedge` ports"
            )
        try:
            cocotb.start_soon(
                self.report_stable_high(self.dut.sda_i, self.sda_stable_high, self.t_f)
            )
        except AttributeError:
            self.log.debug(
                "SDA negedge detector not spawned, DUT does not contain `t_f_i` or `sda_negedge` ports"
            )

        # Bus conditions
        try:
            cocotb.start_soon(
                self.report_bus_start_condition(
                    self.start_det, self.sda_negedge, self.scl_negedge, self.scl_stable_high
                )
            )
        except AttributeError:
            self.log.debug(
                "Bus START condition detector not spawned, DUT does not contain one of the following ports: "
                "bus_start_det_i, sda_negedge_i, scl_negedge_i, scl_stable_high_i"
            )
        try:
            cocotb.start_soon(
                self.report_bus_stop_condition(
                    self.stop_det, self.sda_posedge, self.scl_posedge, self.scl_stable_high
                )
            )
        except AttributeError:
            self.log.debug(
                "Bus STOP condition detector not spawned, DUT does not contain one of the following ports: "
                "bus_stop_det_i, sda_posedge_i, scl_posedge_i, scl_stable_high_i"
            )
