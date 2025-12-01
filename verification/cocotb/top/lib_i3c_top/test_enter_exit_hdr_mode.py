# SPDX-License-Identifier: Apache-2.0

import logging
import random

from boot import boot_init
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_enter_exit_hdr_mode(dut):
    ENTHDR0 = 0x20
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
    await ClockCycles(tb.clk, 50)
    await boot_init(tb, static_addr=0x50)


    # Send HDR-DDR write transaction
    reserved_addrs = {0x00, 0x01, 0x02, 0x7E, 0x7F}
    legal_addrs = [addr for addr in range(0x08, 0x78) if addr not in reserved_addrs]
    for i in range(5):
        await i3c_controller.i3c_ccc_write(ENTHDR0, broadcast_data=[])
        i3c_target.set_hdr_mode(True)

        assert (
        int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
        == 0xA0
    )  # IdleHDR
        test_addr = random.choice(legal_addrs)

        data_len = random.randint(1, 8)
        test_data = [random.randint(0, 0xFF) for _ in range(data_len)]
        cocotb.log.info(f"Sending HDR-DDR write to {hex(test_addr)} with data: {test_data}")
        await i3c_controller.send_hdr_ddr_write(addr=test_addr, data=test_data)

        # Exit HDR mode
        await i3c_controller.send_hdr_exit()
        i3c_target.set_hdr_mode(False)

        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle

        # Send GETSTATUS direct CCC (0x90) to verify target is responsive
        GETSTATUS = 0x90
        target_addr = 0x50
        status_data = await i3c_controller.i3c_ccc_read(
            ccc=GETSTATUS,
            addr=target_addr,
            count=2,
            stop=True
        )
        cocotb.log.info(f"GETSTATUS response from {hex(target_addr)}: {status_data}")
        assert int.from_bytes(status_data[0][1], 'big') == 0xC0, f"Expected status 0xC0, got {hex(int.from_bytes(status_data[0][1], 'big'))}"
