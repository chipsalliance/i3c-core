# SPDX-License-Identifier: Apache-2.0

import logging
import os
import random

from boot import boot_init
from bus2csr import compare_values, dword2int, int2bytes, int2dword
from ccc import CCC
from cocotb_helpers import reset_n
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_recovery_interface import I3cRecoveryInterface
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface
from utils import Access, draw_axi_priv_ids, get_axi_ids_seq

import cocotb
from cocotb.result import SimTimeoutError
from cocotb.triggers import ClockCycles, Combine, Event, Join, RisingEdge, Timer


async def write_to_indirect_fifo(tb, data=None, awid=None, format="bytes", timeout=1, units="us"):
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
        await tb.write_csr(
            tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr,
            int2dword(d),
            awid=awid,
            timeout=timeout,
            units=units,
        )


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
    tx_data = [random.randint(2, 2**32 - 1) for _ in range(fifo_size)]
    await write_to_indirect_fifo(tb, tx_data, format="dwords")

    # Get indirect FIFO pointers
    empty1, full1, wrptr1, rdptr1 = await get_fifo_ptrs()

    # Read data back
    rx_words = []
    for _ in range(fifo_size):

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
    dut._log.info("TX data: " + " ".join([hex(w) for w in tx_data]))
    dut._log.info("Indirect FIFO: " + " ".join([hex(w) for w in rx_words]))

    assert tx_data == rx_words

    # Check FIFO pointer progression
    assert (wrptr0, rdptr0) == (0, 0)
    assert (wrptr1, rdptr1) == (0, 0)
    assert (wrptr2, rdptr2) == (0, 0)
    assert (wrptr3, rdptr3) == (0, 0)

    # Check empty/full progression
    assert (full0, empty0) == (False, True)
    assert (full1, empty1) == (True, False)
    assert (full2, empty2) == (False, True)
    assert (full3, empty3) == (False, True)


@cocotb.test()
async def test_indirect_fifo_overflow(dut):
    """
    Tests whether access is properly rejected on Indirect FIFO overflow
    """
    tb = await initialize(dut)

    fifo_size = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_3.base_addr, 4)
    )
    dut._log.info(f"Indirect FIFO Size is {fifo_size}")

    # Fill the Indirect FIFO
    tx_data = [random.randint(2, 2**32 - 1) for _ in range(fifo_size)]
    await write_to_indirect_fifo(tb, tx_data, format="dwords")

    # Cause the Indirect FIFO to overflow
    try:
        await write_to_indirect_fifo(
            tb, [random.randint(2, 2**32 - 1)], format="dwords", timeout=100, units="ns"
        )
    except SimTimeoutError:
        assert False, "Write to full Indirect FIFO was rejected while it should be ignored"


@cocotb.test()
async def test_indirect_fifo_underflow(dut):
    """
    Tests whether access is properly rejected on Indirect FIFO underflow
    """
    tb = await initialize(dut)

    # Cause the Indirect FIFO to underflow
    d = 0
    try:
        d = dword2int(await tb.read_csr(
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr,
            4,
            timeout=100,
            units="ns",
        ))
    except SimTimeoutError:
        assert False, "Read from empty Indirect FIFO was rejected while it should return 0"
    else:
        assert d == 0, "Read from empty Indirect FIFO did not return 0"


@cocotb.test()
async def test_read(dut):
    """
    Tests CSR read(s) using the recovery protocol
    """
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
    hw_status = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.HW_STATUS.base_addr, 4)
    )
    assert hw_status == 0x0

    device_status = [
        dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, 4)
        ),
        dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_1.base_addr, 4)
        ),
    ]
    assert device_status == [0x3, 0x0]  # DEVICE_STATUS_0 was earlier set to 0x3


@cocotb.test()
async def test_payload_available(dut):
    """
    Tests if payload_available gets asserted/deasserted correctly when data
    chunks are written to the INDIRECT_FIFO_DATA CSR.
    """
    tb = await initialize(dut, timeout=50)

    payload_size = (
        dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_4.base_addr, 4)
        )
        * 4
    )  # Multiply by 4 to get bytes from dwords

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
async def test_i3c_bus_traffic_during_loopback(dut):
    tb = await initialize(dut, timeout=500)

    rtl_target_addr = 0x5A
    sim_target_addr = 0x23  # Arbitrary

    fbus = 12.5
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
        address=sim_target_addr,
    )
    payload_available = dut.xi3c_wrapper.recovery_payload_available_o

    run_target_bus_traffic = Event()

    async def target_bus_traffic(addr, run_condition):
        await run_condition.wait()
        while run_condition.is_set():
            # Send data to simulated target
            await i3c_controller.i3c_write(addr, [random.randint(0, 255)])

    fifo_size = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_4.base_addr, 4)
    )

    for addr in [sim_target_addr, rtl_target_addr]:
        # Random delay to start transfer in the middle of I3C transaction

        for _ in range(10):  # Arbitrary number of repetitions
            payload_data = [random.randint(0, 2**32 - 1) for _ in range(fifo_size)]
            delay_cycles = random.randint(1, 1000)
            dut._log.info(f"Randomized delay is {delay_cycles} clock cycles")

            # Start I3C traffic
            bus_traffic = cocotb.start_soon(target_bus_traffic(addr, run_target_bus_traffic))
            run_target_bus_traffic.set()

            # Wait for random number of cycles and start write to Indirect FIFO via bypass
            await ClockCycles(tb.clk, delay_cycles)
            write_fifo = cocotb.start_soon(
                write_to_indirect_fifo(tb, payload_data, format="dwords")
            )

            # Wait until payload is available
            while (not payload_available.value):
                dut._log.info("Waiting for payload_available wire to assert...")
                await ClockCycles(tb.clk, delay_cycles)

            # Wait for random number of cycles and start read from Indirect FIFO via bypass
            payload_received = []
            for _ in range(fifo_size):
                d = dword2int(
                    await tb.read_csr(
                        tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr, 4
                    )
                )
                payload_received.append(d)

            # Payload write/read to I3C Core finished so disable I3C bus traffic generator
            await Join(write_fifo)
            run_target_bus_traffic.clear()
            await Join(bus_traffic)

            dut._log.info("Received data: " + " ".join([hex(w) for w in payload_received]))
            dut._log.info("Expected data: " + " ".join([hex(w) for w in payload_data]))
            assert (
                payload_data == payload_received
            ), "Reiceved payload data does not match sent data!"


@cocotb.test()
async def test_recovery_flow(dut):
    """
    Test firmware image transfer
    """
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
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_CTRL_1.IMAGE_SIZE,
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
        payload_available = dut.xi3c_wrapper.recovery_payload_available_o

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
                full = await tb.read_csr_field(
                    tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_0.base_addr,
                    tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_0.FULL,
                )
                if full:
                    logger.info("Indirect FIFO full, reading data...")
                    break
                else:
                    logger.info("Indirect FIFO not empty, proceed...")

                if payload_available.value:
                    logger.info("Payload available wire asserted, reading data...")
                    break

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


def csr_access_test_data(tb, rd_acc=Access.Priv, wr_acc=Access.Priv):
    test_data = []
    for reg_name in tb.reg_map.I3C_EC.SECFWRECOVERYIF:
        if reg_name in ["start_addr", "INDIRECT_FIFO_DATA"]:
            continue
        reg = getattr(tb.reg_map.I3C_EC.SECFWRECOVERYIF, reg_name)
        addr = reg.base_addr
        wdata = random.randint(0, 2**32 - 1)
        exp_rd = 0
        for f_name in reg:
            if f_name in ["base_addr", "offset"]:
                continue
            f = getattr(reg, f_name)
            if f.sw == "r" or ((wr_acc == Access.Unpriv) and (rd_acc == Access.Priv)):
                data = (f.reset << f.low) & f.mask
            elif f.woclr or f.hwclr:
                data = 0
            else:
                data = wdata & f.mask
            # The reset value of 'INDIRECT_FIFO_STATUS_3' is 0 but it's set
            # by 'recovery_executor' to 'IndirectFifoDepth' parameter
            if reg_name == "INDIRECT_FIFO_STATUS_3" and f_name == "FIFO_SIZE":
                data = 0x40

            if rd_acc == Access.Unpriv:
                data = 0x0

            exp_rd |= data
        test_data.append([reg_name, addr, wdata, exp_rd])
    return test_data


@cocotb.test(
    skip=(
        "FrontendBusInterface" not in cocotb.plusargs
        or cocotb.plusargs["FrontendBusInterface"] != "AXI"
    )
)
async def test_axi_filtering(dut):
    """
    Verifies AXI ID filtering in Secure Firmware Recovery registers access.
    """

    # Initialize
    tb = await initialize(dut)
    cocotb.start_soon(tb.busIf.write_access_monitor())
    cocotb.start_soon(tb.busIf.read_access_monitor())
    priv_ids = draw_axi_priv_ids()
    dut.disable_id_filtering_i.value = 0
    dut.priv_ids_i.value = priv_ids

    #########################################################################
    # Verify privileged & unprivileged registers access                     #
    #########################################################################
    acc_pairs = [(x, y) for x in [Access.Priv, Access.Unpriv] for y in [Access.Priv, Access.Unpriv]]
    for rd_acc, wr_acc in acc_pairs:
        sfr_seq = csr_access_test_data(tb, rd_acc, wr_acc)

        for _, addr, wdata, exp_rd in sfr_seq:
            awid = get_axi_ids_seq(priv_ids, 1, wr_acc)[0]
            arid = get_axi_ids_seq(priv_ids, 1, rd_acc)[0]
            await tb.write_csr(addr, int2dword(wdata), 4, awid=awid)
            resp = await tb.read_csr(addr, arid=arid)
            compare_values(int2bytes(exp_rd), resp, addr)

        # Skip the indirect fifo data check as it will cause a read from an empty FIFO
        if wr_acc == Access.Unpriv:
            continue

        # Writes to `INDIRECT_FIFO_DATA` are executed through the I3C
        await tb.write_csr(
            tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_STATUS_3.base_addr,
            int2dword(2),
            4,
            awid=awid,
        )
        addr = tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr
        # Burst ID cannot be 0
        awid = get_axi_ids_seq(priv_ids, 1, wr_acc)[0]
        while awid == 0:
            awid = get_axi_ids_seq(priv_ids, 1, wr_acc)[0]
        payload_data = [random.randint(0, 2**32 - 1) for _ in range(2)]
        await write_to_indirect_fifo(tb, payload_data, format="dwords", awid=awid)

        # Indicate that payload transfer is finished
        for done in [1, 0]:
            await tb.write_csr_field(
                tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_CFG.base_addr,
                tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_CFG.REC_PAYLOAD_DONE,
                done,
                awid=awid,
            )

        resp = await tb.read_csr(addr, arid=get_axi_ids_seq(priv_ids, 1, rd_acc)[0])
        exp_rd = 0 if rd_acc == Access.Unpriv or wr_acc == Access.Unpriv else payload_data[0]
        compare_values(int2bytes(exp_rd), resp, addr)

        await reset_n(dut.aclk, dut.areset_n, 2)

    #########################################################################
    # Verify registers access with unprivileged IDs & configuration changes #
    #########################################################################

    async def disable_random():
        while True:
            filter_off = int(dut.disable_id_filtering_i.value)
            if abs(random.random()) < 0.1:
                dut.disable_id_filtering_i.value = not filter_off
            await RisingEdge(dut.aclk)

    async def priv_id_swap_random():
        while True:
            if abs(random.random()) < 0.2:
                dut.priv_ids_i.value = draw_axi_priv_ids()
            await RisingEdge(dut.aclk)

    cocotb.start_soon(disable_random())
    cocotb.start_soon(priv_id_swap_random())

    sfr_seq = csr_access_test_data(tb)

    for _, addr, wdata, _ in sfr_seq:
        awid = get_axi_ids_seq(priv_ids, 1, Access.Mixed)[0]
        arid = get_axi_ids_seq(priv_ids, 1, Access.Mixed)[0]
        await tb.write_csr(addr, int2dword(wdata), 4, awid=awid)
        _ = await tb.read_csr(addr, arid=arid)


async def init_i3c_recovery(dut, timeout=50):
    fbus = 12.5

    tb = await initialize(dut, timeout)

    # Initialize I3C interfaces
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

    recovery = I3cRecoveryInterface(i3c_controller)

    # TODO: For now test with all timings set to 0.
    timings = {"T_R": 0, "T_F": 0, "T_HD_DAT": 0, "T_SU_DAT": 0}
    STATIC_ADDR = 0x5A
    VIRT_STATIC_ADDR = 0x5B
    DYNAMIC_ADDR = 0x52
    VIRT_DYNAMIC_ADDR = 0x53

    for k, v in timings.items():
        dut._log.info(f"{k} = {v}")

    # Configure the top level
    await boot_init(tb, timings)
    # Set regular device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])]
    )
    # Set virtual device dynamic address
    await i3c_controller.i3c_ccc_write(
        ccc=CCC.DIRECT.SETDASA, directed_data=[(VIRT_STATIC_ADDR, [VIRT_DYNAMIC_ADDR << 1])]
    )
    # Write to the RESET CSR (one word)
    await recovery.command_write(
        VIRT_DYNAMIC_ADDR, I3cRecoveryInterface.Command.DEVICE_RESET, [0xAA, 0xBB, 0xCC, 0xDD]
    )

    return tb


async def test_ocp_csr_access(dut, enable_bypass):
    # Perform the recovery protocol to obtain access to CSRs
    if not enable_bypass:
        tb = await init_i3c_recovery(dut)
    # CSRs should be available without executing the protocol
    else:
        tb = await initialize(dut)

    reg_test_data = csr_access_test_data(tb)

    # Enable/disable bypass
    await tb.write_csr(
        tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_CFG.base_addr, int2dword(enable_bypass), 4
    )

    for name, addr, wdata, exp_rd in reg_test_data:
        if name == "DEVICE_RESET":
            exp_rd &= 0xFFFFFF00  # 1st byte is W1C
        elif name == "INDIRECT_FIFO_CTRL_0":
            exp_rd &= 0xFFFF00FF  # 2nd byte is W1C
        elif name == "RECOVERY_CTRL":
            exp_rd &= 0xFF00FFFF  # 3rd byte is W1C

        await tb.write_csr(addr, int2dword(wdata), 4)
        rd_data = await tb.read_csr(addr)
        compare_values(int2dword(exp_rd), rd_data, addr)

    # Test additional bypass register
    exp_data = random.randint(1, 2**32 - 1)
    await tb.write_csr(
        tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_REG_W1C_ACCESS.base_addr, int2dword(exp_data), 4
    )

    rd_data = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.SOCMGMTIF.REC_INTF_REG_W1C_ACCESS.base_addr)
    )
    assert rd_data == 0, "W1C bypass register should not store written values"


@cocotb.test()
async def test_ocp_csr_access_bypass_enabled(dut):
    await test_ocp_csr_access(dut, True)


@cocotb.test()
async def test_ocp_csr_access_bypass_disabled(dut):
    await test_ocp_csr_access(dut, False)
