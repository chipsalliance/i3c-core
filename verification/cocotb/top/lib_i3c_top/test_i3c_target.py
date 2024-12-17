# SPDX-License-Identifier: Apache-2.0

import logging

from boot import boot_init
from bus2csr import dword2int, int2dword
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import ClockCycles, Timer


async def timeout_task(timeout_us=5):
    """
    A generic task for handling test timeout. Waits a fixed amount of
    simulation time and then throws an exception.
    """
    await Timer(timeout_us, "us")
    raise TimeoutError("Timeout!")


async def test_setup(dut):
    """
    Sets up controller, target models and top-level core interface
    """

    cocotb.log.setLevel(logging.INFO)
    cocotb.start_soon(timeout_task(20))

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

    # Configure the top level
    await boot_init(tb)

    return i3c_controller, i3c_target, tb


# @cocotb.test()
async def test_i3c_target_write(dut):

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut)

    # Send Private Write on I3C
    test_data = [[0xAA, 0x00, 0xBB, 0xCC, 0xDD], [0xDE, 0xAD, 0xBA, 0xBE]]
    for test_vec in test_data:
        await i3c_controller.i3c_write(0x5A, test_vec)
        await ClockCycles(tb.clk, 10)

    # Wait for an interrupt
    wait_irq = True
    timeout = 0
    # Number of clock cycles after which we should observe an interrupt
    TIMEOUT_THRESHOLD = 50
    while wait_irq:
        timeout += 1
        await ClockCycles(tb.clk, 10)
        irq = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS.base_addr, 4))
        if irq:
            wait_irq = False
            dut._log.debug(":::Interrupt was raised:::")
        if timeout > TIMEOUT_THRESHOLD:
            wait_irq = False
            dut._log.debug(":::Timeout cancelled polling:::")

    # Convert bytes to 32-bit words
    words_ref = []
    for xfer in test_data:

        # Pad
        pad_len = ((len(xfer) + 3) // 4 * 4) - len(xfer)
        xfer_pad = xfer + [0 for i in range(pad_len)]

        # Convert to 32-bit little-endian words
        for i in range(len(xfer_pad) // 4):
            word = (
                (xfer_pad[4 * i + 3] << 24)
                | (xfer_pad[4 * i + 2] << 16)
                | (xfer_pad[4 * i + 1] << 8)
                | (xfer_pad[4 * i + 0])
            )
            words_ref.append(word)

    # Read data
    words_out = []

    for i in range(len(words_ref)):
        r_data = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, 4))
        words_out.append(r_data)

    # Compare
    dut._log.info(
        "Comparing input [{}] and CSR data [{}]".format(
            " ".join(["[ " + " ".join([f"0x{d:02X}" for d in s]) + " ]" for s in test_data]),
            " ".join([f"0x{d:08X}" for d in words_out]),
        )
    )
    assert words_out == words_ref

    # Dummy wait
    await ClockCycles(tb.clk, 10)


@cocotb.test()
async def test_i3c_target_read(dut):

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut)

    # Write data to TTI TX FIFO
    test_data = [0xDDCCBBAA, 0x9988FFEE, 0x55667788]
    for word in test_data:
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, int2dword(word), 4)

    # Write the TX descriptor
    descriptor = 0xC
    await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(descriptor), 4)

    # Issue a private read
    bytes_out = await i3c_controller.i3c_read(0x5A, len(test_data) * 4)
    bytes_out = list(bytes_out)

    # Convert reference data into bytes (little-endian)
    bytes_ref = []
    for word in test_data:
        bytes_ref.append(word & 0xFF)
        bytes_ref.append((word >> 8) & 0xFF)
        bytes_ref.append((word >> 16) & 0xFF)
        bytes_ref.append((word >> 24) & 0xFF)

    # Compare
    dut._log.info(
        "Comparing input [{}] and CSR data [{}]".format(
            " ".join([f"0x{d:02X}" for d in bytes_out]),
            " ".join([f"0x{d:02X}" for d in bytes_ref]),
        )
    )
    assert bytes_out == bytes_ref

    # Dummy wait
    await ClockCycles(tb.clk, 10)


# @cocotb.test()
async def test_i3c_target_ibi(dut):

    # Target address
    addr = 0x5A

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut)

    target = i3c_controller.add_target(addr)
    target.set_bcr_fields(ibi_req_capable=True, ibi_payload=True)

    # Write MDB to Target's IBI queue
    mdb = 0xAA
    await tb.write_csr(tb.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, int2dword(mdb), 4)

    # Wait for the IBI to be serviced, check data
    data = await i3c_controller.wait_for_ibi()
    expected = bytearray([addr, mdb])
    assert data == expected

    # Dummy wait
    await ClockCycles(tb.clk, 10)
