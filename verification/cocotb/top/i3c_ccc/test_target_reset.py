# SPDX-License-Identifier: Apache-2.0

import logging

from boot import boot_init
from bus2csr import dword2int
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_target_reset(dut):
    RSTACT_BCAST = 0x2A
    RSTACT_PERIPHERAL_RESET = 0x1
    cocotb.log.setLevel(logging.DEBUG)

    i3c_controller = I3cController(
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_ctrl_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_ctrl_i,
        debug_state_o=None,
        speed=12.5e6,
    )

    i3c_target = I3CTarget(  # noqa
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_target_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_target_i,
        debug_state_o=None,
        speed=12.5e6,
    )

    tb = I3CTopTestInterface(dut)
    await tb.setup()
    await ClockCycles(dut.hclk, 50)
    await boot_init(tb)

    await i3c_controller.i3c_ccc_write(
        RSTACT_BCAST, defining_byte=RSTACT_PERIPHERAL_RESET, broadcast_data=[]
    )

    rst_action = dword2int(
        await tb.read_csr(
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_CCC_CONFIG_RSTACT_PARAMS.base_addr,
            1,
            timeout=100,
        )
    )
    assert rst_action == RSTACT_PERIPHERAL_RESET
