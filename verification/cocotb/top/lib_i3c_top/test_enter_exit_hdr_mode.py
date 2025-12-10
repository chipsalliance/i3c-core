# SPDX-License-Identifier: Apache-2.0

import logging
import random

from boot import boot_init
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import ClockCycles


VALID_I3C_ADDRESSES = (
    [i for i in range(0x03, 0x3E)]
    + [i for i in range(0x3F, 0x5E)]
    + [i for i in range(0x5F, 0x6E)]
    + [i for i in range(0x6F, 0x76)]
    + [i for i in range(0x77, 0x7A)]
    + [0x7B, 0x7D]
)

async def test_setup(dut, static_addr=0x5A, virtual_static_addr=0x5B, dynamic_addr=None, virtual_dynamic_addr=None):
    """
    Sets up controller, target models and top-level core interface
    """
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
    await boot_init(tb, static_addr=static_addr, virtual_static_addr=virtual_static_addr,
                    dynamic_addr=dynamic_addr, virtual_dynamic_addr=virtual_dynamic_addr)
    return i3c_controller, i3c_target, tb


@cocotb.test()
async def test_enter_exit_hdr_mode_write(dut):
    ENTHDR0 = 0x20
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)


    remaining_addrs = VALID_I3C_ADDRESSES.copy()
    remaining_addrs.remove(STATIC_ADDR)
    remaining_addrs.remove(VIRT_STATIC_ADDR)
    remaining_addrs.remove(DYNAMIC_ADDR)
    remaining_addrs.remove(VIRT_DYNAMIC_ADDR)
    # Send HDR-DDR write transaction
    for _ in range(random.randint(10, 15)):
        await i3c_controller.i3c_ccc_write(ENTHDR0, broadcast_data=[], stop=False, pull_scl_low=True)

        assert (
        int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0xA0
        )  # IdleHDR
        test_addr = random.choice(remaining_addrs)

        data_len = random.randint(1, 8) # HDR-DDR requires 16-bit words
        test_data = [random.randint(0, 0xFFFF) for _ in range(data_len)]
        accept_data = random.randint(0,1)
        i3c_target.address = test_addr if accept_data == 1 else 0
        cocotb.log.info(f"Sending HDR-DDR write to {hex(test_addr)} with data: {test_data}")
        test_data = await i3c_controller.send_hdr_ddr_write(
                addr=test_addr, data=test_data)
        assert (
            (test_data.nack == True and accept_data == 0) or
            (test_data.nack == False and accept_data == 1)
        )

        # Exit HDR mode
        await i3c_controller.send_hdr_exit()
        i3c_target.address = 0

        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle

        # Send GETSTATUS direct CCC (0x90) to verify target is responsive
        GETSTATUS = 0x90
        target_addr = DYNAMIC_ADDR
        status_data = await i3c_controller.i3c_ccc_read(
            ccc=GETSTATUS,
            addr=target_addr,
            count=2,
            stop=True
        )
        cocotb.log.info(f"GETSTATUS response from {hex(target_addr)}: {status_data}")
        assert int.from_bytes(status_data[0][1], 'big') == 0xC0, f"Expected status 0xC0, got {hex(int.from_bytes(status_data[0][1], 'big'))}"


@cocotb.test()
async def test_enter_restart_exit_hdr_mode_write(dut):
    ENTHDR0 = 0x20
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)


    remaining_addrs = VALID_I3C_ADDRESSES.copy()
    remaining_addrs.remove(STATIC_ADDR)
    remaining_addrs.remove(VIRT_STATIC_ADDR)
    remaining_addrs.remove(DYNAMIC_ADDR)
    remaining_addrs.remove(VIRT_DYNAMIC_ADDR)
    # Send HDR-DDR write transaction
    for _ in range(random.randint(10, 15)):
        await i3c_controller.i3c_ccc_write(ENTHDR0, broadcast_data=[], stop=False, pull_scl_low=True)

        assert (
        int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0xA0
        )  # IdleHDR
        transactions = random.randint(10, 15)
        for i in range(transactions):
            test_addr = random.choice(remaining_addrs)
            data_len = random.randint(1, 8) # HDR-DDR requires 16-bit words
            test_data = [random.randint(0, 0xFFFF) for _ in range(data_len)]
            accept_data = random.randint(0,1)
            i3c_target.address = test_addr if accept_data == 1 else 0
            cocotb.log.info(f"Sending HDR-DDR write to {hex(test_addr)} with data: {test_data}")
            test_data = await i3c_controller.send_hdr_ddr_write(
                    addr=test_addr, data=test_data)
            assert (
                (test_data.nack == True and accept_data == 0) or
                (test_data.nack == False and accept_data == 1)
            )

            if i != transactions-1:
                await i3c_controller.send_hdr_rstart()
            else:
                # Exit HDR mode
                await i3c_controller.send_hdr_exit()
            i3c_target.address = 0

        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle

        # Send GETSTATUS direct CCC (0x90) to verify target is responsive
        GETSTATUS = 0x90
        target_addr = DYNAMIC_ADDR
        status_data = await i3c_controller.i3c_ccc_read(
            ccc=GETSTATUS,
            addr=target_addr,
            count=2,
            stop=True
        )
        cocotb.log.info(f"GETSTATUS response from {hex(target_addr)}: {status_data}")
        assert int.from_bytes(status_data[0][1], 'big') == 0xC0, f"Expected status 0xC0, got {hex(int.from_bytes(status_data[0][1], 'big'))}"


@cocotb.test()
async def test_enter_exit_hdr_mode_read(dut):
    ENTHDR0 = 0x20
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)


    remaining_addrs = VALID_I3C_ADDRESSES.copy()
    remaining_addrs.remove(STATIC_ADDR)
    remaining_addrs.remove(VIRT_STATIC_ADDR)
    remaining_addrs.remove(DYNAMIC_ADDR)
    remaining_addrs.remove(VIRT_DYNAMIC_ADDR)
    # Send HDR-DDR write transaction
    for _ in range(random.randint(10, 15)):
        await i3c_controller.i3c_ccc_write(ENTHDR0, broadcast_data=[], stop=False, pull_scl_low=True)

        assert (
        int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0xA0
        )  # IdleHDR
        test_addr = random.choice(remaining_addrs)

        data_len = random.randint(1, 8) # HDR-DDR requires 16-bit words
        exp_data = [random.randint(0, 0xFFFF) for _ in range(data_len)]
        accept_data = random.randint(0,1)
        i3c_target.address = test_addr if accept_data == 1 else 0
        i3c_target._mem.clear()
        i3c_target._mem.write(
            [byte for word in exp_data for byte in word.to_bytes(2, "big")],
            2 * data_len
        )
        cocotb.log.info(f"Sending HDR-DDR write to {hex(test_addr)} with length: {data_len}")
        test_data = await i3c_controller.send_hdr_ddr_read(addr=test_addr)
        assert (
            (test_data.nack == True and accept_data == 0) or
            (test_data.nack == False and accept_data == 1)
        )

        # Exit HDR mode
        await i3c_controller.send_hdr_exit()
        i3c_target.address = 0

        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle

        # Send GETSTATUS direct CCC (0x90) to verify target is responsive
        GETSTATUS = 0x90
        target_addr = DYNAMIC_ADDR
        status_data = await i3c_controller.i3c_ccc_read(
            ccc=GETSTATUS,
            addr=target_addr,
            count=2,
            stop=True
        )
        cocotb.log.info(f"GETSTATUS response from {hex(target_addr)}: {status_data}")
        assert int.from_bytes(status_data[0][1], 'big') == 0xC0, f"Expected status 0xC0, got {hex(int.from_bytes(status_data[0][1], 'big'))}"


@cocotb.test()
async def test_enter_restart_exit_hdr_mode_read(dut):
    ENTHDR0 = 0x20
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)


    remaining_addrs = VALID_I3C_ADDRESSES.copy()
    remaining_addrs.remove(STATIC_ADDR)
    remaining_addrs.remove(VIRT_STATIC_ADDR)
    remaining_addrs.remove(DYNAMIC_ADDR)
    remaining_addrs.remove(VIRT_DYNAMIC_ADDR)
    # Send HDR-DDR write transaction
    for _ in range(random.randint(10, 15)):
        await i3c_controller.i3c_ccc_write(ENTHDR0, broadcast_data=[], stop=False, pull_scl_low=True)

        assert (
        int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0xA0
        )  # IdleHDR
        transactions = random.randint(10, 15)
        for i in range(transactions):
            test_addr = random.choice(remaining_addrs)
            data_len = random.randint(1, 8) # HDR-DDR requires 16-bit words
            exp_data = [random.randint(0, 0xFFFF) for _ in range(data_len)]
            accept_data = random.randint(0,1)
            i3c_target.address = test_addr if accept_data == 1 else 0
            i3c_target._mem.clear()
            i3c_target._mem.write(
                [byte for word in exp_data for byte in word.to_bytes(2, "big")],
                2 * data_len
            )
            cocotb.log.info(f"Sending HDR-DDR read to {hex(test_addr)} with length: {data_len}")
            test_data = await i3c_controller.send_hdr_ddr_read(addr=test_addr)
            assert (
                (test_data.nack == True and accept_data == 0) or
                (test_data.nack == False and accept_data == 1)
            )

            if i != transactions-1:
                await i3c_controller.send_hdr_rstart()
            else:
                # Exit HDR mode
                await i3c_controller.send_hdr_exit()
            i3c_target.address = 0

        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle

        # Send GETSTATUS direct CCC (0x90) to verify target is responsive
        GETSTATUS = 0x90
        target_addr = DYNAMIC_ADDR
        status_data = await i3c_controller.i3c_ccc_read(
            ccc=GETSTATUS,
            addr=target_addr,
            count=2,
            stop=True
        )
        cocotb.log.info(f"GETSTATUS response from {hex(target_addr)}: {status_data}")
        assert int.from_bytes(status_data[0][1], 'big') == 0xC0, f"Expected status 0xC0, got {hex(int.from_bytes(status_data[0][1], 'big'))}"
