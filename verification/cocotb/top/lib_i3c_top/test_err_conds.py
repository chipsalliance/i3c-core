# SPDX-License-Identifier: Apache-2.0

import logging
import random

from boot import boot_init
from bus2csr import bytes2int
from ccc import CCC
from cocotbext_i3c.common import I3cTargetResetAction
from cocotbext_i3c.i3c_controller import I3cController
from interface import I3CTopTestInterface
from math import ceil

import cocotb
from cocotb.triggers import ClockCycles, Timer
from cocotb.regression import TestFactory

TGT_ADR = 0x5A

VALID_I3C_ADDRESSES = (
    [i for i in range(0x03, 0x3E)]
    + [i for i in range(0x3F, 0x5E)]
    + [i for i in range(0x5F, 0x6E)]
    + [i for i in range(0x6F, 0x76)]
    + [i for i in range(0x77, 0x7A)]
    + [0x7B, 0x7D]
)

FCLK = 500.0 #MHz, default value for all tests

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

    # We don't need target BFM in this test
    dut.sda_sim_target_i = 1
    dut.scl_sim_target_i = 1
    i3c_target = None

    dut.peripheral_reset_done_i.value = 0

    tb = I3CTopTestInterface(dut)
    await tb.setup(FCLK)
    await ClockCycles(tb.clk, 50)
    await boot_init(tb, static_addr=static_addr, virtual_static_addr=virtual_static_addr,
                    dynamic_addr=dynamic_addr, virtual_dynamic_addr=virtual_dynamic_addr)
    return i3c_controller, i3c_target, tb


@cocotb.test()
async def test_TE0_HDR_exit(dut):

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    ADDRs = [random.choice([STATIC_ADDR, DYNAMIC_ADDR]), random.choice([VIRT_STATIC_ADDR, VIRT_DYNAMIC_ADDR])]

    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    idle_time_in_cycles = ceil(60000 / (1000 / FCLK))
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.SOCMGMTIF.T_IDLE_REG.base_addr,
        tb.reg_map.I3C_EC.SOCMGMTIF.T_IDLE_REG.T_IDLE,
        idle_time_in_cycles
    )

    incorrect_addrs = [
        (0x3E, True), (0x5E, True), (0x6E, True), (0x76, True), (0x7A, True),
        (0x7C, True), (0x7F, True), (0x7E, False)
    ]

    for _ in range(random.randint(10, 15)):
        addr, write = random.choice(incorrect_addrs)
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle
        await i3c_controller.take_bus_control()
        await i3c_controller.send_start()
        ack = await i3c_controller.write_addr_header(addr, read=not write)
        await i3c_controller.send_stop()
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0xa2
        )  # WaitHDRExitOrIdle
        await i3c_controller.send_hdr_exit()
        i3c_controller.give_bus_control()
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle


@cocotb.test()
async def test_TE0_idle_exit(dut):

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    ADDRs = [random.choice([STATIC_ADDR, DYNAMIC_ADDR]), random.choice([VIRT_STATIC_ADDR, VIRT_DYNAMIC_ADDR])]

    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    idle_time_in_cycles = ceil(60000 / (1000 / FCLK))
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.SOCMGMTIF.T_IDLE_REG.base_addr,
        tb.reg_map.I3C_EC.SOCMGMTIF.T_IDLE_REG.T_IDLE,
        idle_time_in_cycles
    )

    incorrect_addrs = [
        (0x3E, True), (0x5E, True), (0x6E, True), (0x76, True), (0x7A, True),
        (0x7C, True), (0x7F, True), (0x7E, False)
    ]

    for _ in range(2):
        addr, write = random.choice(incorrect_addrs)
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle
        await i3c_controller.take_bus_control()
        await i3c_controller.send_start()
        ack = await i3c_controller.write_addr_header(addr, read=not write)
        await i3c_controller.send_stop()
        i3c_controller.give_bus_control()
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0xa2
        )  # WaitHDRExitOrIdle
        await Timer(60, "us")
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle


@cocotb.test()
async def test_TE1_HDR_exit(dut):

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    ADDRs = [random.choice([STATIC_ADDR, DYNAMIC_ADDR]), random.choice([VIRT_STATIC_ADDR, VIRT_DYNAMIC_ADDR])]

    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    idle_time_in_cycles = ceil(60000 / (1000 / FCLK))
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.SOCMGMTIF.T_IDLE_REG.base_addr,
        tb.reg_map.I3C_EC.SOCMGMTIF.T_IDLE_REG.T_IDLE,
        idle_time_in_cycles
    )

    for _ in range(random.randint(10, 15)):
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle
        await i3c_controller.take_bus_control()
        await i3c_controller.send_start()
        ack = await i3c_controller.write_addr_header(0x7E, read=False)
        await i3c_controller.send_byte_tbit(random.randint(0, 0xFF), True)
        await i3c_controller.send_stop()
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0xa2
        )  # WaitHDRExitOrIdle
        await i3c_controller.send_hdr_exit()
        i3c_controller.give_bus_control()
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle


@cocotb.test()
async def test_TE1_idle_exit(dut):

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    ADDRs = [random.choice([STATIC_ADDR, DYNAMIC_ADDR]), random.choice([VIRT_STATIC_ADDR, VIRT_DYNAMIC_ADDR])]

    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    idle_time_in_cycles = ceil(60000 / (1000 / FCLK))
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.SOCMGMTIF.T_IDLE_REG.base_addr,
        tb.reg_map.I3C_EC.SOCMGMTIF.T_IDLE_REG.T_IDLE,
        idle_time_in_cycles
    )

    for _ in range(2):
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle
        await i3c_controller.take_bus_control()
        await i3c_controller.send_start()
        ack = await i3c_controller.write_addr_header(0x7E, read=False)
        await i3c_controller.send_byte_tbit(random.randint(0, 0xFF), True)
        await i3c_controller.send_stop()
        i3c_controller.give_bus_control()
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0xa2
        )  # WaitHDRExitOrIdle
        await Timer(60, "us")
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle


@cocotb.test()
async def test_TE5_read_on_write(dut):

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    COMMANDs = [0x87, 0x88, 0x89, 0x8A, 0x80, 0x81, 0x98]

    for _ in range(2):
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle
        await i3c_controller.take_bus_control()
        await i3c_controller.send_start()
        ack = await i3c_controller.write_addr_header(0x7E, read=False)
        command = random.choice(COMMANDs)
        await i3c_controller.send_byte_tbit(command, False)
        await i3c_controller.send_start()
        ack = await i3c_controller.write_addr_header(DYNAMIC_ADDR, read=True)
        assert ack == False
        await i3c_controller.send_stop()
        i3c_controller.give_bus_control()
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xccc.state_d.value)
            == 1
        )  # WaitCCC


@cocotb.test()
async def test_TE5_write_on_read(dut):

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, i3c_target, tb = await test_setup(dut, STATIC_ADDR, VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    await ClockCycles(tb.clk, 50)

    COMMANDs = [0x8B, 0x8C, 0x8D, 0x8E, 0x8F, 0x90, 0x95]

    for _ in range(random.randint(10, 15)):
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle
        await i3c_controller.take_bus_control()
        await i3c_controller.send_start()
        ack = await i3c_controller.write_addr_header(0x7E, read=False)
        command = random.choice(COMMANDs)
        await i3c_controller.send_byte_tbit(command, False)
        await i3c_controller.send_start()
        ack = await i3c_controller.write_addr_header(DYNAMIC_ADDR, read=False)
        assert ack == False
        await i3c_controller.send_stop()
        i3c_controller.give_bus_control()
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xi3c_target_fsm.state_d.value)
            == 0
        )  # Idle
        assert (
            int(dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.xcontroller_standby_i3c.xccc.state_d.value)
            == 1
        )  # WaitCCC
