# SPDX-License-Identifier: Apache-2.0

import logging
import random

from bus2csr import dword2int, int2dword
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import ClockCycles, Combine, Event, RisingEdge, Timer

STATIC_ADDR = 0x5A
VIRT_STATIC_ADDR = 0x5B
DYNAMIC_ADDR = 0x52
VIRT_DYNAMIC_ADDR = 0x53


async def write_to_indirect_fifo(tb, data=None, format="bytes"):
    """
    Issues a write command to the target
    """
    assert format in ["bytes", "dwords"]
    if not data:
        raise ValueError("Data to write to Indirect FIFO must not be 'None'")

    xfer = []
    if format == "bytes":
        dword = 0
        for i, d in enumerate(data):
            dword = dword | (d << (8 * (i % 4)))
            if (not ((i + 1) % 4) and i) or (i == len(data) - 1):
                xfer.append(dword)
                dword = 0
    else:
        xfer.extend(data)

    # Do the I3C write transfer using the controller functionality
    for d in xfer:
        tb.dut._log.info(f"Writing data to TTI TX Data Queue: 0x{d:08X}")
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, int2dword(d))


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

    tb = I3CTopTestInterface(dut)
    await tb.setup()

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

    # Enable bypass
    enable_bypass = 1
    await tb.write_csr(
        tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_CFG.base_addr, int2dword(enable_bypass), 4
    )

    return tb


@cocotb.test()
async def test_indirect_fifo_write(dut):
    """
    Tests indirect FIFO write operation
    """

    # Initialize
    tb = await initialize(dut)

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

    fifo_size = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_3.base_addr, 4)
    )

    # Get indirect FIFO pointers
    empty0, full0, wrptr0, rdptr0 = await get_fifo_ptrs()

    # Write data to indirect FIFO through the recovery interface
    tx_data_len = random.randint(2, 256)
    tx_data = [random.randint(2, 255) for _ in range(tx_data_len)]
    await write_to_indirect_fifo(tb, tx_data)

    # Get indirect FIFO pointers
    empty1, full1, wrptr1, rdptr1 = await get_fifo_ptrs()

    # Read data back
    count = (tx_data_len + 3) // 4
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
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_REG_W1C_ACCESS.base_addr,
        tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_REG_W1C_ACCESS.INDIRECT_FIFO_CTRL_RESET,
        1,
    )

    # Clear FIFO reset
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_CTRL_0.base_addr,
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_CTRL_0.RESET,
        1,
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

    dut._log.info("TX data: " + " ".join([hex(w) for w in tx_words]))
    dut._log.info("Indirect FIFO: " + " ".join([hex(w) for w in rx_words]))

    assert tx_words == rx_words

    # Pointers wrap around when they reach maximum value so they'll be equal to 0
    top_ptr = count if (fifo_size > count) else 0

    # Check FIFO pointer progression
    assert (wrptr0, rdptr0) == (0, 0)
    assert (wrptr1, rdptr1) == (top_ptr, 0)
    assert (wrptr2, rdptr2) == (top_ptr, top_ptr)
    assert (wrptr3, rdptr3) == (0, 0)

    # If top pointer is equal to 0, then FIFO should be full after write
    fifo_full_at_top = (top_ptr == 0)

    # Check empty/full progression
    assert (full0, empty0) == (False, True)
    assert (full1, empty1) == (fifo_full_at_top, False)
    assert (full2, empty2) == (False, True)
    assert (full3, empty3) == (False, True)


@cocotb.test()
async def test_read(dut):
    """
    Tests CSR read(s) using the recovery protocol
    """

    # Initialize
    tb = await initialize(dut)

    # Write some data to PROT_CAP CSR
    prot_cap = [
        0x2050434F,  # 'OCP '
        0x56434552,  # 'RECV'
        0x0C0B0A09,
        0xFF0F0E0D,
    ]

    # Disable recovery mode
    status = 0x2  # "Device Error"
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
        int2dword(prot_cap[2]),
        4,
    )
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.PROT_CAP_3.base_addr,
        int2dword(prot_cap[3]),
        4,
    )

    # Read the PROT_CAP register
    recovery_data = [
        dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.PROT_CAP_0.base_addr, 4)),
        dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.PROT_CAP_1.base_addr, 4)),
        dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.PROT_CAP_2.base_addr, 4)),
        dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.PROT_CAP_3.base_addr, 4)),
    ]

    # PROT_CAP_3 register is only 24 bits
    prot_cap[-1] = prot_cap[-1] & 0xFFFFFF

    dut._log.info("Received data: " + " ".join([hex(w) for w in recovery_data]))
    dut._log.info("Expected data: " + " ".join([hex(w) for w in prot_cap]))
    assert recovery_data == prot_cap

    # Test DEVICE_ID register
    device_id = [random.randint(0, 2**32 - 1) for _ in range(6)]
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_0.base_addr,
        int2dword(device_id[0]),
        4,
    )
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_1.base_addr,
        int2dword(device_id[1]),
        4,
    )
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_2.base_addr,
        int2dword(device_id[2]),
        4,
    )
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_3.base_addr,
        int2dword(device_id[3]),
        4,
    )
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_4.base_addr,
        int2dword(device_id[4]),
        4,
    )
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_5.base_addr,
        int2dword(device_id[5]),
        4,
    )

    # Read the DEVICE_ID register
    recovery_data = [
        dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_0.base_addr, 4)),
        dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_1.base_addr, 4)),
        dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_2.base_addr, 4)),
        dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_3.base_addr, 4)),
        dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_4.base_addr, 4)),
        dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_ID_5.base_addr, 4)),
    ]

    dut._log.info("Received data: " + " ".join([hex(w) for w in recovery_data]))
    dut._log.info("Expected data: " + " ".join([hex(w) for w in device_id]))
    assert recovery_data == device_id

    # Ensure there is access to rest of basic registers
    hw_status = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.HW_STATUS.base_addr, 4))
    assert hw_status == 0x0

    device_status = [
        dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, 4)),
        dword2int(await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_1.base_addr, 4)),
    ]
    assert device_status == [0x3, 0x0]  # DEVICE_STATUS_0 was earlier set to 0x3


@cocotb.test()
async def test_payload_available(dut):
    """
    Tests if payload_available gets asserted/deasserted correctly when data
    chunks are written to the INDIRECT_FIFO_DATA CSR.
    """
    # Initialize
    tb = await initialize(dut, timeout=50)

    payload_size = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_4.base_addr, 4)
    ) * 4  # Multiply by 4 to get bytes from dwords

    payload_available = dut.xi3c_wrapper.recovery_payload_available_o

    # Check if payload available is deasserted
    assert not bool(
        payload_available.value
    ), "Upon initialization payload_available should be deasserted"

    # Generate random data payload. Write the payload to INDIRECT_FIFO_DATA
    payload_data = [random.randint(0, 0xFF) for i in range(payload_size)]
    await write_to_indirect_fifo(tb, payload_data)

    # Indicate that payload transfer is finished
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_CFG.base_addr,
        tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_CFG.REC_PAYLOAD_DONE,
        1,
    )
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_CFG.base_addr,
        tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_CFG.REC_PAYLOAD_DONE,
        0,
    )

    # Check if payload_available is asserted
    assert bool(
        payload_available.value
    ), "After reception of a complete write packet targeting INDIRECT_FIFO_DATA payload_available should be asserted"

    # Read data from the indirect FIFO from the AXI side. payload_available should
    # get deasserted only when the FIFO gets empty.
    for i in range(payload_size // 4):

        # Check the signal
        assert bool(
            payload_available.value
        ), "FIFO payload_available should not be deasserted until the indirect FIFO is not empty"

        # Read & wait
        await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr, 4)

    # Wait for payload_available to propagate after reading whole transfer data
    await RisingEdge(tb.clk)

    # Check if payload available is deasserted
    assert not bool(
        payload_available.value
    ), "After reading INDIRECT_FIFO_DATA over AHB/AXI payload_available should be deasserted"


@cocotb.test()
async def test_image_activated(dut):

    # Initialize
    tb = await initialize(dut)

    image_activated = dut.xi3c_wrapper.recovery_image_activated_o

    # Check if image_activated is deasserted
    assert not bool(
        image_activated.value
    ), "Upon initialization image_activated should be deasserted"

    # Write 0xF to byte 2 of RECOVERY_CTRL
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_REG_W1C_ACCESS.base_addr,
        tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_REG_W1C_ACCESS.RECOVERY_CTRL_ACTIVATE_REC_IMG,
        0xF,
    )
    await RisingEdge(tb.clk)

    # Check if image_activated is asserted
    assert bool(
        image_activated.value
    ), "Upon writing 0xF to RECOVERY_CTRL byte 2 image_activated should be asserted"

    # Write 0xFF to byte 2 of RECOVERY_CTRL from the HCI side
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_CTRL.base_addr,
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_CTRL.ACTIVATE_REC_IMG,
        0xFF,
    )

    # Check if image_activated is deasserted
    assert not bool(
        image_activated.value
    ), "Upon writing 0xFF to RECOVERY_CTRL byte 2 image_activated should be deasserted"


@cocotb.test()
async def test_recovery_flow(dut):
    """
    Test firmware image transfer
    """
    # Initialize
    tb = await initialize(dut, timeout=1000)

    # Generate random firmware image data
    image_size = random.randint(600, 2048)
    image_dwords = [random.randint(0, 2**32 - 1) for _ in range(image_size // 4)]

    mcu_done = Event()
    rot_done = Event()

    # Read max size of the data payload in each write
    max_xfer_size = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_4.base_addr, 4)
    )
    # Ensure max transfer size is set to 256 bytes by I3C Core (in dwords)
    assert max_xfer_size == 256 // 4

    # Caliptra MCU agent
    async def mcu_agent():
        logger = dut._log.getChild("mcu_agent")

        # Wait for core to enter recovery mode
        device_status = None
        while device_status != 3:
            device_status = await tb.read_csr_field(
                tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr,
                tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.DEV_STATUS,
            )

        # Ensure Caliptra ROM is awaiting recovery image
        recovery_status = None
        while recovery_status != 1:
            recovery_status = await tb.read_csr_field(
                tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_STATUS.base_addr,
                tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_STATUS.DEV_REC_STATUS,
            )

        # Ensure RECOVERY_CTRL is set to 0
        recovery_ctrl = dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_CTRL.base_addr, 4)
        )
        assert recovery_ctrl == 0

        # Write 0 to Indirect FIFO Control
        await tb.write_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_CTRL_0.base_addr, 0x0, 4)
        await tb.write_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_CTRL_1.base_addr, 0x0, 4)

        # Write 1 to Indirect FIFO Control Reset field
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_REG_W1C_ACCESS.base_addr,
            tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_REG_W1C_ACCESS.INDIRECT_FIFO_CTRL_RESET,
            0x1,
        )
        # Write image size to Indirect FIFO Control Image size field
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_CTRL_1.base_addr,
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_CTRL_1.IMAGE_SIZE_LSB,
            image_size,
        )
        # Clear Indirect FIFO Reset
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_CTRL_0.base_addr,
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_CTRL_0.RESET,
            0xFF,
        )

        # Send firmware chunks
        for data_ptr in range(0, image_size // 4, max_xfer_size):
            # Write data
            if (data_ptr + max_xfer_size) > image_size:
                end_ptr = -1
            else:
                end_ptr = data_ptr + max_xfer_size
            chunk = image_dwords[data_ptr:end_ptr]

            logger.info(f"Sending {len(chunk) * 4} bytes...")
            await write_to_indirect_fifo(tb, chunk, format="dwords")
            logger.info(f"Firmware chunk {data_ptr//(max_xfer_size)} sent.")

            if len(chunk) != max_xfer_size:
                # Enable payload_done wire
                await tb.write_csr_field(
                    tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_CFG.base_addr,
                    tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_CFG.REC_PAYLOAD_DONE,
                    1,
                )
                logger.info("Firmware image sent!")

            # Wait until data is read from Indirect FIFO
            while True:
                empty = await tb.read_csr_field(
                    tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_0.base_addr,
                    tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_0.EMPTY,
                )
                if empty:
                    logger.info("Indirect FIFO empty, proceed...")
                    break
                else:
                    logger.info("Indirect FIFO not empty, waiting for read...")

                # Indirect FIFO is not empty so wait arbitrary number of cycles for other side
                # to read data
                await ClockCycles(tb.clk, random.randint(5, 150))

        # Activate an image
        logger.info("Activating image...")
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_REG_W1C_ACCESS.base_addr,
            tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_REG_W1C_ACCESS.RECOVERY_CTRL_ACTIVATE_REC_IMG,
            0xF,
        )

        # Ensure an image is booting
        recovery_status = None
        while recovery_status != 2:
            recovery_status = await tb.read_csr_field(
                tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_STATUS.base_addr,
                tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_STATUS.DEV_REC_STATUS,
            )
        logger.info("Image activated and booting!")

        mcu_done.set()

    # Caliptra ROM (RoT) agent
    async def rot_agent(buffer):
        logger = dut._log.getChild("RoT_agent")

        # Set PROT_CAP to Flashless boot
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.PROT_CAP_2.base_addr,
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.PROT_CAP_2.AGENT_CAPS,
            (1 << 11),
        )

        # Write DEVICE_STATUS to enable Recovery Mode (0x3) and set Reason to FSB (0x12)
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr,
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.REC_REASON_CODE,
            0x12,
        )
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr,
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.DEV_STATUS,
            0x3,
        )

        # Write RECOVERY_STATUS to indicate "Awaiting recovery image"
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_STATUS.base_addr,
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_STATUS.DEV_REC_STATUS,
            0x1,
        )

        # Receive the firmware image
        for data_ptr in range(0, image_size // 4, max_xfer_size):
            # Wait for data in Indirect FIFO
            while True:
                empty = await tb.read_csr_field(
                    tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_0.base_addr,
                    tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_0.EMPTY,
                )
                if not empty:
                    logger.info("Indirect FIFO not empty, reading data...")
                    break
                else:
                    logger.info("Indirect FIFO empty, proceed...")

                # Indirect FIFO is empty so wait arbitrary number of cycles for other side
                # to write data
                await ClockCycles(tb.clk, random.randint(5, 150))

            # Read data
            dwords_left = min(max_xfer_size, image_size // 4 - data_ptr)
            logger.info(f"Reading {dwords_left*4} bytes...")
            for _ in range(dwords_left):
                data = dword2int(
                    await tb.read_csr(
                        tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr, 4
                    )
                )
                buffer.append(data)

            logger.info(f"data_ptr {data_ptr}")
            logger.info(f"Firmware chunk {data_ptr//(max_xfer_size)} received.")

        logger.info("Firmware image received!")
        activate_rec_img = None
        while activate_rec_img != 0xF:
            activate_rec_img = await tb.read_csr_field(
                tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_CTRL.base_addr,
                tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_CTRL.ACTIVATE_REC_IMG,
            )
        logger.info("Image activated!")

        # Write RECOVERY_STATUS to indicate "Booting recovery image"
        logger.info("Booting activated image...")
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_STATUS.base_addr,
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.RECOVERY_STATUS.DEV_REC_STATUS,
            0x2,
        )
        rot_done.set()

    # Start agents
    xferd_words = []

    cocotb.start_soon(mcu_agent())
    cocotb.start_soon(rot_agent(xferd_words))

    # Wait for Recovery Sequence to finish
    await Combine(mcu_done.wait(), rot_done.wait())

    # Check if generated image matches received image
    assert image_dwords == xferd_words
