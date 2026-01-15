import functools
import logging
import random
from math import ceil

from boot import boot_init
from bus2csr import dword2int, int2dword
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_target import I3CTarget

# Assuming I3CTopControllerTestInterface is available from your previous context
# or is the updated version of I3CTopTestInterface
from controller_interface import I3CTopControllerTestInterface
from utils import format_ibi_data, get_interrupt_status

import cocotb
from cocotb.triggers import ClockCycles, RisingEdge, Timer, Combine

class BusStateMonitor:
    def __init__(self, clk, signal, log, name="Monitor"):
        """
        clk:    The clock signal handle (e.g., dut.clk)
        signal: The bus_state signal handle (e.g., dut.exp_bus_state)
        log:    The cocotb logger
        name:   Name for debug logging
        """
        self.clk = clk
        self.signal = signal
        self.log = log
        self.name = name
        self.queue = [] # This is where we store the history
        self._coro = None

    def start(self):
        """Starts the monitoring coroutine."""
        if self._coro is None:
            self._coro = cocotb.start_soon(self._monitor())

    async def _monitor(self):
        # Capture initial state
        prev_val = self.signal.value
        self.queue.append(int(prev_val))
        
        self.log.info(f"[{self.name}] Started. Initial state: {prev_val}")

        while True:
            await RisingEdge(self.clk)
            
            # Read current value
            curr_val = self.signal.value
            
            # Check for change
            if curr_val != prev_val:
                self.log.debug(f"[{self.name}] State change: {prev_val} -> {curr_val}")
                self.queue.append(int(curr_val))
                prev_val = curr_val
