# SPDX-License-Identifier: Apache-2.0

import logging

from boot import boot_init
from bus2csr import dword2int, int2dword
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_target import I3CTarget
from cocotbext_i3c.i3c_recovery_interface import I3cRecoveryInterface
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import Timer


async def timeout():
    await Timer(50, "us")
    raise RuntimeError("Test timeout!")


async def initialize(dut):
    """
    Common test initialization routine
    """

    cocotb.log.setLevel(logging.DEBUG)

    # Start the background timeout task
    await cocotb.start(timeout())

    # Initialize interfaces
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

    recovery = I3cRecoveryInterface(i3c_controller)

    # Configure the top level
    await boot_init(tb)

    # Enable the recovery mode
    status = 0x3  # "Recovery Mode"
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, int2dword(status), 4
    )

    return i3c_controller, i3c_target, tb, recovery


@cocotb.test()
async def test_recovery_write(dut):
    """
    Tests CSR write(s) using the recovery protocol
    """

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut)

    # Write to the RESET CSR (one word)
    await recovery.command_write(
        0x5A, I3cRecoveryInterface.Command.DEVICE_RESET, [0xAA, 0xBB, 0xCC, 0xDD]
    )

    # Wait & read the CSR from the AHB/AXI side
    await Timer(1, "us")

    status = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, 4)
    )
    dut._log.info(f"DEVICE_STATUS = 0x{status:08X}")
    data = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_RESET.base_addr, 4))
    dut._log.info(f"DEVICE_RESET = 0x{data:08X}")

    # Check
    protocol_status = (status >> 8) & 0xFF
    assert protocol_status == 0
    assert data == 0xDDCCBBAA

    # Write to the FIFO_CTRL CSR (two words)
    await recovery.command_write(
        0x5A,
        I3cRecoveryInterface.Command.INDIRECT_FIFO_CTRL,
        [0xAA, 0xBB, 0xCC, 0xDD, 0x11, 0x22, 0x33, 0x44],
    )

    # Wait & read the CSR from the AHB/AXI side
    await Timer(1, "us")

    status = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, 4)
    )
    dut._log.info(f"DEVICE_STATUS = 0x{status:08X}")
    data0 = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_CTRL_0.base_addr, 4)
    )
    dut._log.info(f"INDIRECT_FIFO_CTRL_0 = 0x{data0:08X}")
    data1 = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_CTRL_1.base_addr, 4)
    )
    dut._log.info(f"INDIRECT_FIFO_CTRL_1 = 0x{data1:08X}")

    # Check
    protocol_status = (status >> 8) & 0xFF
    assert protocol_status == 0
    assert data0 == 0xDDCCBBAA
    assert data1 == 0x44332211


@cocotb.test()
async def test_recovery_write_pec(dut):
    """
    Tests recovery handler behavior upon receiving packet with incorrect PEC
    """

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut)

    # Write to the RESET CSR
    await recovery.command_write(
        0x5A, I3cRecoveryInterface.Command.DEVICE_RESET, [0xEF, 0xBE, 0xAD, 0xDE]
    )

    # Wait, skip checks
    await Timer(1, "us")

    # Write to the RESET CSR again, deliberately malform PEC
    await recovery.command_write(
        0x5A,
        I3cRecoveryInterface.Command.DEVICE_RESET,
        [0xBA, 0xBA, 0xFE, 0xCA],
        force_pec_error=True,
    )

    # Wait & read the CSR from the AHB/AXI side
    await Timer(1, "us")

    status = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, 4)
    )
    dut._log.info(f"DEVICE_STATUS = 0x{status:08X}")
    data = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_RESET.base_addr, 4))
    dut._log.info(f"DEVICE_RESET = 0x{data:08X}")

    # Check
    protocol_status = (status >> 8) & 0xFF
    assert protocol_status == 0x04  # PEC error
    assert data == 0xDEADBEEF  # From previous write


@cocotb.test()
async def test_recovery_read(dut):
    """
    Tests CSR read(s) using the recovery protocol
    """

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut)

    # Write data to PROT_CAP CSR
    await tb.write_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.PROT_CAP_0.base_addr, int2dword(0x04030201), 4)
    await tb.write_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.PROT_CAP_1.base_addr, int2dword(0x08070605), 4)
    await tb.write_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.PROT_CAP_2.base_addr, int2dword(0x0C0B0A09), 4)
    await tb.write_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.PROT_CAP_3.base_addr, int2dword(0xFF0F0E0D), 4)

    # Wait
    await Timer(1, "us")

    # Read the PROT_CAP register
    await recovery.command_read(0x5A, I3cRecoveryInterface.Command.PROT_CAP)

    # Wait
    await Timer(2, "us")

