# SPDX-License-Identifier: Apache-2.0

import logging

import cocotb
from cocotb.triggers import ClockCycles
from i3c_master import I3cMaster
from interface import I3CTopTestInterface


@cocotb.test()
async def test_i3c_target(dut):

    log = logging.getLogger("cocotb.tb")
    log.setLevel(logging.DEBUG)

    i3c_master = I3cMaster(
        sda_i=None,
        sda_o=dut.i3c_sda_i,
        scl_i=None,
        scl_o=dut.i3c_scl_i,
        debug_state_o=dut.debug_state,
        speed=12.5e6,
    )

    tb = I3CTopTestInterface(dut)
    await tb.setup()
    await ClockCycles(dut.hclk, 10)

    test_data = b"\xaa\xbb\xcc\xdd"

    await i3c_master.i3c_private_write(0x50, b"\x00" + test_data)

    await ClockCycles(dut.hclk, 10)

    cocotb.log.setLevel(logging.DEBUG)

    # dut.i3c_scl_i.value = 1
    # dut.i3c_sda_i.value = 1
