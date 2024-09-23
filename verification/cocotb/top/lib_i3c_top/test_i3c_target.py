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
async def test_i3c_target(dut):

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

    # Configure the top level
    await boot_init(tb)

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

    dut._log.info(test_data)
    dut._log.info(words_ref)

    # Read data
    words_out = []
    for i in range(len(words_ref)):
        r_data = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, 4))
        words_out.append(r_data)

    dut._log.debug(
        "Comparing input [{}] and CSR data [{}]".format(
            " ".join(["[ " + " ".join([f"0x{d:02X}" for d in s]) + " ]" for s in test_data]),
            " ".join([f"0x{d:08X}" for d in words_out]),
        )
    )
    assert words_out == words_ref
