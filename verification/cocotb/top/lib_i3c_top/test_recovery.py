# SPDX-License-Identifier: Apache-2.0

import logging
import random

from boot import boot_init
from bus2csr import bytes2int, dword2int, int2bytes, int2dword
from ccc import CCC
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_recovery_interface import I3cRecoveryInterface
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import ClockCycles, Combine, Event, Timer

STATIC_ADDR = 0x5A
VIRT_STATIC_ADDR = 0x5B
DYNAMIC_ADDR = 0x52
VIRT_DYNAMIC_ADDR = 0x53

ocp_magic_string_as_bytes = [
    0x4F,  # 'O'
    0x43,  # 'C'
    0x50,  # 'P'
    0x20,  # ' '
    0x52,  # 'R'
    0x45,  # 'E'
    0x43,  # 'C'
    0x56,  # 'V'
]


async def timeout_task(timeout):
    await Timer(timeout, "us")
    raise RuntimeError("Test timeout!")


async def initialize(dut, fclk=100.0, fbus=12.5, timeout=50):
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
        speed=fbus * 1e6,
    )

    i3c_target = I3CTarget(  # noqa
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_target_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_target_i,
        debug_state_o=None,
        speed=fbus * 1e6,
        address=0x23,
    )

    tb = I3CTopTestInterface(dut)
    await tb.setup(fclk)

    recovery = I3cRecoveryInterface(i3c_controller)

    # TODO: For now test with all timings set to 0.
    timings = {
        "T_R": 0,
        "T_F": 0,
        "T_HD_DAT": 0,
        "T_SU_DAT": 0,
    }

    for k, v in timings.items():
        dut._log.info(f"{k} = {v}")

    # Configure the top level
    await boot_init(tb, timings)

    # Set recovery indirect FIFO size and max transfer size (in 4B units)
    # Set low values to easy trigger pointer wrap in tests.
    fifo_size = 8
    xfer_size = 8
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_3.base_addr, int2dword(fifo_size), 4
    )
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_4.base_addr, int2dword(xfer_size), 4
    )

    # Enable the recovery mode
    status = 0x3
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, int2dword(status), 4
    )

    return i3c_controller, i3c_target, tb, recovery


@cocotb.test()
async def test_virtual_write(dut):
    """
    Tests CSR write(s) using the recovery protocol using the virtual address
    """

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut)

    # exit recovery mode
    status = 0x2
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, int2dword(status), 4
    )

    await ClockCycles(tb.clk, 50)
    # set regular device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])]
    )
    # set virtual device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )

    # Write to the RESET CSR (one word)
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.DEVICE_RESET, [0xAA, 0xBB, 0xCC]
    )

    # Wait & read the CSR from the AHB/AXI side
    await Timer(1, "us")

    status = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, 4)
    )
    dut._log.info(f"DEVICE_STATUS = 0x{status:08X}")
    data = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_RESET.base_addr, 4))
    dut._log.info(f"DEVICE_RESET = 0x{data:08X}")

    # read back device reset
    i3c_data, pec_ok = await recovery.command_read(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.DEVICE_RESET
    )

    # Check
    protocol_status = (status >> 8) & 0xFF
    assert protocol_status == 0
    assert data == 0xCCBBAA
    assert bytes2int(i3c_data) == 0xCCBBAA
    assert pec_ok

    # read GET_STATUS from main target
    interrupt_status_reg_addr = tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS.base_addr
    pending_interrupt_field = tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS.PENDING_INTERRUPT
    interrupt_status = bytes2int(await tb.read_csr(interrupt_status_reg_addr, 4))
    dut._log.info(f"Interrupt status from CSR: {interrupt_status}")

    # NOTE: The field INTERRUPT_STATUS.PENDING_INTERRUPT is not writable by
    # software and cocotb does not allow to set the underlying register directly.
    # So the only value that can be read back is 0.
    pending_interrupt_in = 0

    pending_interrupt = await tb.read_csr_field(interrupt_status_reg_addr, pending_interrupt_field)
    assert (
        pending_interrupt == pending_interrupt_in
    ), "Unexpected pending interrupt value read from CSR"

    responses = await i3c_controller.i3c_ccc_read(
        ccc=CCC.DIRECT.GETSTATUS, addr=DYNAMIC_ADDR, count=2
    )
    status = responses[0][1]
    pending_interrupt = int.from_bytes(status, byteorder="big", signed=False) & 0xF
    assert (
        pending_interrupt == pending_interrupt_in
    ), "Unexpected pending interrupt value received from GETSTATUS CCC"

    cocotb.log.info(f"GET STATUS = {status}")

    # Write to the FIFO_CTRL CSR (two words)
    # This write should not pass because the device is not set to recovery mode
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR,
        I3cRecoveryInterface.Command.INDIRECT_FIFO_CTRL,
        [0xAA, 0xBB, 0xCC, 0xDD, 0x11, 0x22],
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
    assert data0 != 0xDDCCBBAA
    assert data1 != 0x2211


@cocotb.test()
async def test_virtual_write_alternating(dut):
    """
    Alternate between recovery CSR write and regular TTI private writes
    """

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut)

    # set regular device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])]
    )
    # set virtual device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )

    # Repeat the sequence twice. The second time with the recovery mode disabled
    for i in range(2):

        # ..........

        # Write to the RESET CSR (one word)
        data = [random.randint(0, 255) for i in range(3)]
        await recovery.command_write(
            VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.DEVICE_RESET, data
        )

        # Wait & read the CSR from the AHB/AXI side
        await Timer(1, "us")
        readback = dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_RESET.base_addr, 4)
        )
        assert readback == int.from_bytes(data, byteorder="little")

        # Clear device reset CSR
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_RESET.base_addr,
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_RESET.RESET_CTRL,
            0xFF,
        )

        # ..........

        # Do a private write
        data = [random.randint(0, 255) for i in range(3)]
        await i3c_controller.i3c_write(DYNAMIC_ADDR, data)

        # Wait and read data back
        await Timer(1, "us")
        desc = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4))
        desc = desc & 0xFFFF
        assert desc == len(data)

        readback = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, 4))
        assert readback == int.from_bytes(data, byteorder="little")

        # ..........

        # exit recovery mode
        await Timer(1, "us")
        status = 0x2
        await tb.write_csr(
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, int2dword(status), 4
        )
        await ClockCycles(tb.clk, 50)


@cocotb.test()
async def test_write(dut):
    """
    Tests CSR write(s) using the recovery protocol
    """

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut)

    # set regular device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])]
    )
    # set virtual device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )

    # Write to the RESET CSR (one word)
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.DEVICE_RESET, [0xAA, 0xBB, 0xCC, 0xDD]
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
    assert data == 0xCCBBAA  # 0xDD trimmed because this register is only 3 bytes

    # Write to the FIFO_CTRL CSR (two words)
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR,
        I3cRecoveryInterface.Command.INDIRECT_FIFO_CTRL,
        [0xAA, 0xBB, 0xCC, 0xDD, 0x11, 0x22],
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
    assert data1 == 0x2211


@cocotb.test()
async def test_indirect_fifo_write(dut):
    """
    Tests indirect FIFO write operation
    """

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut)

    # set regular device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])]
    )
    # set virtual device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )

    async def get_fifo_ptrs():
        """
        Returns (empty, full, write index, read index)
        """
        sts = dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_0.base_addr, 4)
        )
        wrptr = dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_1.base_addr, 4)
        )
        rdptr = dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_2.base_addr, 4)
        )
        return bool(sts & 1), bool(sts & 2), wrptr, rdptr

    # Get indirect FIFO pointers
    empty0, full0, wrptr0, rdptr0 = await get_fifo_ptrs()

    # Write data to indirect FIFO through the recovery interface
    tx_data = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A]
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.INDIRECT_FIFO_DATA, tx_data
    )

    # Get indirect FIFO pointers
    empty1, full1, wrptr1, rdptr1 = await get_fifo_ptrs()

    # Wait & read data from the AHB/AXI side
    await Timer(1, "us")

    # Read data back
    count = (len(tx_data) + 3) // 4
    rx_words = []
    for i in range(count):

        # Read data
        res = await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr, 4)
        data = dword2int(res)
        dut._log.info(f"INDIRECT_FIFO_DATA = 0x{data:08X}")
        rx_words.append(data)

    # Get indirect FIFO pointers
    empty2, full2, wrptr2, rdptr2 = await get_fifo_ptrs()

    # Clear FIFO (pointers too)
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.INDIRECT_FIFO_CTRL, [0x00, 0x01, 0x00, 0x00]
    )

    # Get indirect FIFO pointers
    empty3, full3, wrptr3, rdptr3 = await get_fifo_ptrs()

    # Check data readback
    tx_words = []
    for i in range(count):
        word = 0
        for j in range(4):
            idx = 4 * i + j
            word >>= 8
            if idx < len(tx_data):
                word |= tx_data[idx] << 24
        tx_words.append(word)

    dut._log.info("TX words: " + " ".join([hex(w) for w in tx_words]))
    dut._log.info("RX words: " + " ".join([hex(w) for w in rx_words]))

    assert tx_words == rx_words

    # Check FIFO pointer progression
    assert (wrptr0, rdptr0) == (0, 0)
    assert (wrptr1, rdptr1) == (count, 0)
    assert (wrptr2, rdptr2) == (count, count)
    assert (wrptr3, rdptr3) == (0, 0)

    # Check empty/full progression
    assert (full0, empty0) == (False, True)
    assert (full1, empty1) == (False, False)
    assert (full2, empty2) == (False, True)
    assert (full3, empty3) == (False, True)


@cocotb.test()
async def test_write_pec(dut):
    """
    Tests recovery handler behavior upon receiving packet with incorrect PEC
    """

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut)

    # set regular device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])]
    )
    # set virtual device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )

    # Write to the RESET CSR
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.DEVICE_RESET, [0xEF, 0xBE, 0xAD, 0xDE]
    )

    # Wait, skip checks
    await Timer(1, "us")

    # Write to the RESET CSR again, deliberately malform PEC
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR,
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
    assert (
        data == 0xADBEEF
    )  # From previous write (0xDE trimmed because this register is only 3 bytes)

    # Wait
    await Timer(1, "us")


@cocotb.test()
async def test_read(dut):
    """
    Tests CSR read(s) using the recovery protocol
    """

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut)

    # set regular device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])]
    )
    # set virtual device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )

    # Write some data to PROT_CAP CSR
    def make_word(bs):
        return (bs[3] << 24) | (bs[2] << 16) | (bs[1] << 8) | bs[0]

    prot_cap = ocp_magic_string_as_bytes + [
        0x09,
        0x0A,
        0x0B,
        0x0C,
        0x0D,
        0x0E,
        0x0F,
        0xFF,
    ]

    # Disable recovery mode
    status = 0x2  # "Recovery Mode"
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, int2dword(status), 4
    )

    # write some random data to TTI queue and desc
    data_len = 4
    test_data = [random.randint(0, 255) for _ in range(data_len)]
    dut._log.info(
        "Generated data: [{}]".format(
            " ".join("".join(f"0x{d:02X}") + " " for d in test_data),
        )
    )
    # Write data to TTI TX FIFO
    for i in range(0, len(test_data), 4):
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, test_data[i : i + 4], 4)

    # Enable the recovery mode
    status = 0x3  # "Recovery Mode"
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, int2dword(status), 4
    )

    # Write the TX descriptor
    await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(data_len), 4)

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
    recovery_data, pec_ok = await recovery.command_read(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.PROT_CAP
    )

    # PROT_CAP read always returns 15 bytes
    assert len(recovery_data) == 15
    assert recovery_data == prot_cap[:15]
    assert pec_ok

    # Wait
    await Timer(1, "us")


@cocotb.test()
async def test_read_short(dut):
    """
    Tests CSR read(s) using the recovery protocol. Read less data than the
    register contains
    """

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut)

    # set regular device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])]
    )
    # set virtual device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )

    # Write some data to PROT_CAP CSR
    def make_word(bs):
        return (bs[3] << 24) | (bs[2] << 16) | (bs[1] << 8) | bs[0]

    prot_cap = ocp_magic_string_as_bytes + [random.randint(0, 255) for i in range(8)]

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

    # Issue the recovery mode PROT_CAP read command
    data = [I3cRecoveryInterface.Command.PROT_CAP]
    data.append(recovery.pec_calc.checksum(bytes([VIRT_DYNAMIC_ADDR << 1] + data)))
    await i3c_controller.i3c_write(VIRT_DYNAMIC_ADDR, data, stop=False)

    # Read the PROT_CAP register using private read of fixed length which is
    # shorter than the register content + length + PEC
    data = await i3c_controller.i3c_read(VIRT_DYNAMIC_ADDR, 4)

    # Wait
    await Timer(2, "us")

    # Read PROT_CAP again, this time using the correct length
    recovery_data, pec_ok = await recovery.command_read(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.PROT_CAP
    )

    # PROT_CAP read always returns 15 bytes
    assert recovery_data is not None
    assert len(recovery_data) == 15
    assert recovery_data == prot_cap[:15]
    assert pec_ok

    # Wait
    await Timer(1, "us")


@cocotb.test()
async def test_read_long(dut):
    """
    Tests CSR read(s) using the recovery protocol. Read more data than the
    register contains
    """

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut, timeout=100)

    # set regular device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])]
    )
    # set virtual device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )

    # Write some data to PROT_CAP CSR
    def make_word(bs):
        return (bs[3] << 24) | (bs[2] << 16) | (bs[1] << 8) | bs[0]

    prot_cap = ocp_magic_string_as_bytes + [random.randint(0, 255) for i in range(8)]

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

    # Issue the recovery mode PROT_CAP read command
    data = [I3cRecoveryInterface.Command.PROT_CAP]
    data.append(recovery.pec_calc.checksum(bytes([VIRT_DYNAMIC_ADDR << 1] + data)))
    await i3c_controller.i3c_write(VIRT_DYNAMIC_ADDR, data, stop=False)

    # Read the PROT_CAP register using private read of fixed length which is
    # shorter than the register content + length + PEC
    data = await i3c_controller.i3c_read(VIRT_DYNAMIC_ADDR, 20)

    # Wait
    await Timer(1, "us")

    # Read PROT_CAP again, this time using the correct length
    recovery_data, pec_ok = await recovery.command_read(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.PROT_CAP
    )

    # PROT_CAP read always returns 15 bytes
    assert recovery_data is not None
    assert len(recovery_data) == 15
    assert recovery_data == prot_cap[:15]
    assert pec_ok

    # Test DEVICE_ID register
    device_id = [random.randint(0, 255) for _ in range(24)]
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_0.base_addr,
        int2dword(make_word(device_id[0:4])),
        4,
    )
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_1.base_addr,
        int2dword(make_word(device_id[4:8])),
        4,
    )
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_2.base_addr,
        int2dword(make_word(device_id[8:12])),
        4,
    )
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_3.base_addr,
        int2dword(make_word(device_id[12:16])),
        4,
    )
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_4.base_addr,
        int2dword(make_word(device_id[16:20])),
        4,
    )
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_5.base_addr,
        int2dword(make_word(device_id[20:24])),
        4,
    )

    # Wait
    await Timer(1, "us")

    # Issue the recovery mode DEVICE_ID read command
    data = [I3cRecoveryInterface.Command.DEVICE_ID]
    data.append(recovery.pec_calc.checksum(bytes([VIRT_DYNAMIC_ADDR << 1] + data)))
    await i3c_controller.i3c_write(VIRT_DYNAMIC_ADDR, data, stop=False)

    # Read the DEVICE_ID register using private read of fixed length which is
    # shorter than the register content + length + PEC
    data = await i3c_controller.i3c_read(VIRT_DYNAMIC_ADDR, 20)

    # Wait
    await Timer(1, "us")

    # Read PROT_CAP again, this time using the correct length
    recovery_data, pec_ok = await recovery.command_read(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.DEVICE_ID
    )

    # PROT_CAP read always returns 15 bytes
    assert recovery_data is not None
    assert len(recovery_data) == 24
    assert recovery_data == device_id[:24]
    assert pec_ok

    # Wait
    await Timer(1, "us")


@cocotb.test()
async def test_virtual_read(dut):
    """
    Tests CSR read(s) using the recovery protocol
    """

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut, timeout=500)

    # set regular device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])]
    )
    # set virtual device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )

    # Recovery commands to test
    commands = [
        ("Y", "A", I3cRecoveryInterface.Command.PROT_CAP),
        ("Y", "A", I3cRecoveryInterface.Command.DEVICE_ID),
        ("Y", "A", I3cRecoveryInterface.Command.DEVICE_STATUS),
        ("N", "A", I3cRecoveryInterface.Command.DEVICE_RESET),
        ("Y", "A", I3cRecoveryInterface.Command.RECOVERY_CTRL),
        ("N", "A", I3cRecoveryInterface.Command.RECOVERY_STATUS),
        ("N", "R", I3cRecoveryInterface.Command.HW_STATUS),
        ("N", "R", I3cRecoveryInterface.Command.INDIRECT_CTRL),
        ("N", "R", I3cRecoveryInterface.Command.INDIRECT_STATUS),
        ("N", "R", I3cRecoveryInterface.Command.INDIRECT_DATA),
        ("N", "R", I3cRecoveryInterface.Command.VENDOR),
        ("N", "R", I3cRecoveryInterface.Command.INDIRECT_FIFO_CTRL),
        ("N", "R", I3cRecoveryInterface.Command.INDIRECT_FIFO_STATUS),
        ("N", "R", I3cRecoveryInterface.Command.INDIRECT_FIFO_DATA),
    ]

    result = True

    # Test each command in recovery mode enabled and disabled. Recovery is
    # initially enabled.
    for recovery_mode in [True, False]:
        for req, scope, cmd in commands:

            # Do the command
            dut._log.info(f"Command 0x{cmd:02X}")
            data, pec_ok = await recovery.command_read(VIRT_DYNAMIC_ADDR, cmd)

            is_nack = data == None and pec_ok == None
            pec_ok  = bool(pec_ok)

            if is_nack:
                dut._log.info("NACK")
            else:
                dut._log.info(f"ACK, pec_ok={pec_ok}")

            # In recovery mode
            if recovery_mode:
                if is_nack:
                    dut._log.error("Scope R recovery command NACKed")
                    result = False
            # Not in recovery mode
            else:
                if scope == "A" and is_nack:
                    dut._log.error("Scope A recovery command NACKed")
                    result = False
                elif scope == "R" and not is_nack:
                    dut._log.error("Scope R recovery command ACKed")
                    result = False

            # Check PEC
            if not is_nack and not pec_ok:
                dut._log.error("PEC error!")
                result = False

        # Disable recovery mode
        status = 0x2  # "Recovery Mode"
        await tb.write_csr(
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, int2dword(status), 4
        )

    assert result

    # Wait
    await Timer(1, "us")


@cocotb.test()
async def test_virtual_read_alternating(dut):
    """
    Alternate between recovery mode reads and TTI reads
    """

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut)

    # set regular device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])]
    )
    # set virtual device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )

    def make_word(bs):
        return (bs[3] << 24) | (bs[2] << 16) | (bs[1] << 8) | bs[0]

    # Repeat the sequence twice. The second time with the recovery mode disabled
    for i in range(2):

        # ..........

        # Write some data to PROT_CAP CSR
        prot_cap = ocp_magic_string_as_bytes + [random.randint(0, 255) for i in range(8)]

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

        # Wait, read the PROT_CAP register
        await Timer(1, "us")
        recovery_data, pec_ok = await recovery.command_read(
            VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.PROT_CAP
        )

        # PROT_CAP read always returns 15 bytes
        assert len(recovery_data) == 15
        assert recovery_data == prot_cap[:15]
        assert pec_ok

        # ..........

        # Write data to TTI TX queue
        data = [random.randint(0, 255) for i in range(3)]
        await tb.write_csr(
            tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr,
            int2dword(int.from_bytes(data, byteorder="little")),
            4,
        )

        # Write the TX descriptor
        await tb.write_csr(
            tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(len(data)), 4
        )

        # Wait and do a private read
        await Timer(1, "us")
        readback = await i3c_controller.i3c_read(DYNAMIC_ADDR, len(data))
        assert data == list(readback)

        # ..........

        # Disable recovery mode
        await Timer(1, "us")
        status = 0x2  # "Recovery Mode"
        await tb.write_csr(
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, int2dword(status), 4
        )


@cocotb.test()
async def test_payload_available(dut):
    """
    Tests if payload_available gets asserted/deasserted correctly when data
    chunks are written to INDIRECT_FIFO_DATA CSR.
    """

    payload_size = 16  # Bytes

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut, timeout=50)

    # set regular device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])]
    )
    # set virtual device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )

    payload_available = dut.xi3c_wrapper.recovery_payload_available_o

    # Check if payload available is deasserted
    assert not bool(
        payload_available.value
    ), "Upon initialization payload_available should be deasserted"

    # Generate random data payload. Write the payload to INDIRECT_FIFO_DATA
    payload_data = [random.randint(0, 0xFF) for i in range(payload_size)]
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.INDIRECT_FIFO_DATA, payload_data
    )

    # Wait
    await Timer(1, "us")

    # Check if payload_available is asserted
    assert bool(
        payload_available.value
    ), "After reception of a complete write packet targeting INDIRECT_FIFO_DATA payload_available should be asserted"

    # Wait
    await Timer(100, "ns")

    # Read INDIRECT_FIFO_DATA. This should deassert payload_available
    await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr, 4)

    # Wait
    await Timer(100, "ns")

    # Check if payload available is deasserted
    assert not bool(
        payload_available.value
    ), "After reading INDIRECT_FIFO_DATA over AHB/AXI payload_available should be deasserted"

    # Wait
    await Timer(1, "us")


@cocotb.test()
async def test_image_activated(dut):

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut)

    # set regular device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])]
    )
    # set virtual device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )

    image_activated = dut.xi3c_wrapper.recovery_image_activated_o

    # Check if image_activated is deasserted
    assert not bool(
        image_activated.value
    ), "Upon initialization image_activated should be deasserted"

    # Write 0xF to byte 2 of RECOVERY_CTRL
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.RECOVERY_CTRL, [0x0, 0x0, 0xF]
    )

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
    await Timer(100, "ns")

    # Check if image_activated is deasserted
    assert not bool(
        image_activated.value
    ), "Upon writing 0xFF to RECOVERY_CTRL byte 2 image_activated should be deasserted"

    # Wait
    await Timer(1, "us")


@cocotb.test()
async def test_recovery_flow(dut):
    """
    Test firmware image transfer
    """

    # Initialize
    i3c_controller, i3c_target, tb, recovery = await initialize(dut, timeout=100000)

    # set regular device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])]
    )
    # set virtual device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )

    # Generate random firmware image data
    image_size = 128
    image_bytes = [random.randint(0, 255) for i in range(image_size)]

    image_words = []
    for i in range(image_size // 4):
        image_words.append(
            (image_bytes[4 * i + 3] << 24)
            | (image_bytes[4 * i + 2] << 16)
            | (image_bytes[4 * i + 1] << 8)
            | image_bytes[4 * i + 0]
        )

    bfm_done = Event()
    dev_done = Event()

    # BFM-side agent
    async def bfm_agent():
        logger = dut._log.getChild("bfm_agent")
        delay = 1

        rx_data, pec_ok = await recovery.command_read(
            VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.PROT_CAP
        )
        assert pec_ok
        rx_data, pec_ok = await recovery.command_read(
            VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.DEVICE_ID
        )
        assert pec_ok
        rx_data, pec_ok = await recovery.command_read(
            VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.HW_STATUS
        )
        assert pec_ok
        # wait for recovery to start
        while True:
            rx_data, pec_ok = await recovery.command_read(
                VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.DEVICE_STATUS
            )
            assert pec_ok
            if rx_data[0] == 0x3:
                break
        rx_data, pec_ok = await recovery.command_read(
            VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.RECOVERY_STATUS
        )
        assert pec_ok
        # # Read INDIRECT_FIFO_STATUS
        # rx_data, pec_ok = await recovery.command_read(VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.INDIRECT_FIFO_STATUS)
        # assert pec_ok
        # xfer_size = bytes2int(rx_data[16:19])
        # logger.info(f"xfer_size: {xfer_size} (words)")

        data = [0, 0, 0]
        await recovery.command_write(
            VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.RECOVERY_CTRL, data
        )
        data = [0, 1, 4, 0, 0, 0]
        await recovery.command_write(
            VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.INDIRECT_FIFO_CTRL, data
        )

        wrptr = dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_1.base_addr, 4)
        )
        rdptr = dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_2.base_addr, 4)
        )

        assert (wrptr, rdptr) == (0, 0)

        # Clear FIFO reset
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_CTRL_0.base_addr,
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_CTRL_0.RESET,
            0xFF,
        )

        # Send firmware chunks
        xfer_size = 4
        for data_ptr in range(0, image_size, xfer_size * 4):

            # Write data
            logger.info(f"Sending {xfer_size*4} bytes...")
            chunk = image_bytes[data_ptr : data_ptr + xfer_size * 4]
            await recovery.command_write(
                VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.INDIRECT_FIFO_DATA, chunk
            )
            logger.info(f"Firmware chunk {data_ptr//(xfer_size*4)} sent.")

            # Poll indirect FIFO status
            while True:
                rx_data, pec_ok = await recovery.command_read(
                    VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.INDIRECT_FIFO_STATUS
                )
                assert pec_ok
                empty = rx_data[0] & 1

                if empty:
                    logger.info("FIFO empty, proceeding")
                    break
                else:
                    logger.info("FIFO not empty")

                await Timer(delay, "us")

        logger.info(f"Firmware image sent")
        bfm_done.set()

    # AXI-side agent
    async def dev_agent(buffer):
        logger = dut._log.getChild("dev_agent")
        interval = 25

        # Read INDIRECT_FIFO_STATUS
        xfer_size = dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_4.base_addr, 4)
        )
        logger.info(f"xfer_size: {xfer_size} (words)")

        xfer_size = 4
        # Receive the firmware image
        for data_ptr in range(0, image_size, xfer_size * 4):

            # Poll INDIRECT_FIFO_STATUS
            while True:
                status = dword2int(
                    await tb.read_csr(
                        tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_0.base_addr, 4
                    )
                )
                empty = status & 1

                if not empty:
                    logger.info("FIFO not empty, proceeding")
                    break
                else:
                    logger.info("FIFO empty")

                await Timer(10, "us")

            # Wait before reading the data so that the BFM has to poll
            await Timer(interval, "us")

            # Read data
            logger.info(f"Reading {xfer_size*4} bytes...")
            for i in range(xfer_size):
                data = dword2int(
                    await tb.read_csr(
                        tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr, 4
                    )
                )
                buffer.append(data)

            logger.info(f"Firmware chunk {data_ptr//(xfer_size*4)} received.")

        logger.info(f"Firmware image received")
        dev_done.set()

    # Start agents
    xferd_words = []

    cocotb.start_soon(bfm_agent())
    cocotb.start_soon(dev_agent(xferd_words))

    # Wait
    await Combine(bfm_done.wait(), dev_done.wait())
    await Timer(1, "us")

    # Check
    assert image_words == xferd_words
