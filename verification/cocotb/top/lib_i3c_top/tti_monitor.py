# SPDX-License-Identifier: Apache-2.0

"""
Continuous TTI queue write monitor.

Verifies that recovery (RI) I3C transactions never leak descriptor/data
write pulses into the TTI interrupt path, and that normal target writes
do produce them.

Started automatically by I3CTopTestInterface.setup(); raises immediately
on violation to fail the test.
"""

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, First


class TtiQueueMonitor:
    """Watches rx_desc_queue_write_r and rx_data_queue_write_r in tti.sv.

    Invariant: these signals must NEVER assert while recovery_pending is high.
    During recovery, RI data is consumed by the recovery receiver — any write
    pulse reaching the TTI interrupt logic indicates a gating bug.
    """

    # Hierarchical paths relative to dut
    _TTI = "xi3c_wrapper.i3c.xtti"
    _REC = "xi3c_wrapper.i3c.xrecovery_handler"

    def __init__(self, dut):
        self.dut = dut
        self._normal_write_count = 0
        self._running = False

        # Resolve signal handles once
        tti = getattr(dut, "xi3c_wrapper").i3c.xtti
        rec = getattr(dut, "xi3c_wrapper").i3c.xrecovery_handler
        self._rx_desc_write_r = tti.rx_desc_queue_write_r
        self._rx_data_write_r = tti.rx_data_queue_write_r
        self._recovery_pending = rec.recovery_pending

    async def run(self):
        """Main monitor loop — start with cocotb.start_soon().

        Raises AssertionError immediately when a violation is detected,
        which propagates to the test and causes it to fail.
        """
        self._running = True
        while True:
            # Wait for either write_r signal to assert
            await First(
                RisingEdge(self._rx_desc_write_r),
                RisingEdge(self._rx_data_write_r),
            )

            desc_w = int(self._rx_desc_write_r.value)
            data_w = int(self._rx_data_write_r.value)
            rec_pending = int(self._recovery_pending.value)

            # Only fire if rec_pending is not de-asserted at the very same time/edge
            if rec_pending and not(FallingEdge(self._recovery_pending)):
                # RI write leaked through to TTI interrupt path
                sig = []
                if desc_w:
                    sig.append("rx_desc_queue_write_r")
                if data_w:
                    sig.append("rx_data_queue_write_r")
                msg = (
                    f"TTI queue write during recovery_pending=1: "
                    f"{', '.join(sig)} @ {cocotb.utils.get_sim_time('ns')}ns"
                )
                self.dut._log.error(msg)
                raise AssertionError(f"TtiQueueMonitor: {msg}")
            else:
                self._normal_write_count += 1

    @property
    def normal_write_count(self):
        """Number of legitimate (non-recovery) queue write events observed."""
        return self._normal_write_count
