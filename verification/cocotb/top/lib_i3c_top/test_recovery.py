# SPDX-License-Identifier: Apache-2.0

import logging
import random

from boot import boot_init
from bus2csr import dword2int, int2dword
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_recovery_interface import I3cRecoveryInterface
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import Timer


async def timeout_task(timeout):
    await Timer(timeout, "us")
    raise RuntimeError("Test timeout!")


async def initialize(dut, timeout=50):
    """
    Common test initialization routine
    """

    cocotb.log.setLevel(logging.DEBUG)

    # Start the background timeout task
    await cocotb.start(timeout_task(timeout))

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
        address=0x23,
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


@cocotb.test(skip=False)
async def test_recovery_read(dut):
    """
    Tests CSR read(s) using the recovery protocol
    """

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut)

    # Write some data to PROT_CAP CSR
    def make_word(bs):
        return (bs[3] << 24) | (bs[2] << 16) | (bs[1] << 8) | bs[0]

    prot_cap = [
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
        0x09,
        0x0A,
        0x0B,
        0x0C,
        0x0D,
        0x0E,
        0x0F,
        0xFF,
    ]

    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.PROT_CAP_0.base_addr,
        int2dword(make_word(prot_cap[0:4])),
        4,
    )
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.PROT_CAP_1.base_addr,
        int2dword(make_word(prot_cap[4:8])),
        4,
    )
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.PROT_CAP_2.base_addr,
        int2dword(make_word(prot_cap[8:12])),
        4,
    )
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.PROT_CAP_3.base_addr,
        int2dword(make_word(prot_cap[12:16])),
        4,
    )

    # Wait
    await Timer(1, "us")

    # Read the PROT_CAP register
    recovery_data, pec_ok = await recovery.command_read(0x5A, I3cRecoveryInterface.Command.PROT_CAP)

    # PROT_CAP read always returns 15 bytes
    assert len(recovery_data) == 15
    assert recovery_data == prot_cap[:15]
    assert pec_ok

    # Wait
    await Timer(2, "us")


@cocotb.test()
async def test_recovery_payload_available(dut):
    """
    Tests if payload_available gets asserted/deasserted correctly when data
    chunks are written to INDIRECT_FIFO_DATA CSR.
    """

    payload_size = 16  # Bytes

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut, timeout=50)
    payload_available = dut.xi3c_wrapper.recovery_payload_available_o

    # Check if payload available is deasserted
    assert not bool(
        payload_available.value
    ), "Upon initialization payload_available should be deasserted"

    # Generate random data payload. Write the payload to INDIRECT_FIFO_DATA
    payload_data = [random.randint(0, 0xFF) for i in range(payload_size)]
    await recovery.command_write(
        0x5A, I3cRecoveryInterface.Command.INDIRECT_FIFO_DATA, payload_data
    )

    # Wait
    await Timer(1, "us")

    # Check if payload_available is asserted
    assert bool(
        payload_available.value
    ), "After reception of a complete write packet targeting INDIRECT_FIFO_DATA payload_available should be asserted"

    # Wait
    await Timer(1, "us")

    # Read INDIRECT_FIFO_DATA. This should deassert payload_available
    await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr, 4)

    # Wait
    await Timer(1, "us")

    # Check if payload available is deasserted
    assert not bool(
        payload_available.value
    ), "After reading INDIRECT_FIFO_DATA over AHB/AXI payload_available should be deasserted"

    # Wait
    await Timer(2, "us")


@cocotb.test()
async def test_recovery_image_activated(dut):

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut)
    image_activated = dut.xi3c_wrapper.recovery_image_activated_o

    # Check if image_activated is deasserted
    assert not bool(
        image_activated.value
    ), "Upon initialization image_activated should be deasserted"

    # Write 0xF to byte 2 of RECOVERY_CTRL
    await recovery.command_write(0x5A, I3cRecoveryInterface.Command.RECOVERY_CTRL, [0x0, 0x0, 0xF])

    # Wait
    await Timer(1, "us")

    # Check if image_activated is asserted
    assert bool(
        image_activated.value
    ), "Upon writing 0xF to RECOVERY_CTRL byte 2 image_activated should be asserted"

    # Write 0xFF to byte 2 of RECOVERY_CTRL from the HCI side
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_CTRL.base_addr, int2dword(0xFF << 16), 4
    )

    # Wait
    await Timer(1, "us")

    # Check if image_activated is deasserted
    assert not bool(
        image_activated.value
    ), "Upon writing 0xFF to RECOVERY_CTRL byte 2 image_activated should be deasserted"

    # Wait
    await Timer(1, "us")
