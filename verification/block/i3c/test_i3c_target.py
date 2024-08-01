# SPDX-License-Identifier: Apache-2.0

import logging

import cocotb
from bus2csr import dword2int
from cocotb.triggers import ClockCycles
from cocotbext_i3c.i3c_controller import I3cController
from hci import TTI_INTERRUPT_STATUS, TTI_RX_DATA_PORT
from interface import I3CTopTestInterface


@cocotb.test()
async def test_i3c_target(dut):

    cocotb.log.setLevel(logging.DEBUG)

    i3c_controller = I3cController(
        sda_i=None,
        sda_o=dut.i3c_sda_i,
        scl_i=None,
        scl_o=dut.i3c_scl_i,
        debug_state_o=dut.debug_state,
        speed=12.5e6,
    )

    tb = I3CTopTestInterface(dut)
    await tb.setup()
    await ClockCycles(dut.hclk, 20)

    # Send Private Write on I3C
    test_data = [[0xAA, 0x00, 0xBB, 0xCC, 0xDD], [0xDE, 0xAD, 0xBA, 0xBE]]
    for test_vec in test_data:
        await i3c_controller.i3c_write(0x5A, test_vec)
        await ClockCycles(dut.hclk, 10)

    # Wait for an interrupt
    wait_irq = True
    timeout = 0
    # Number of clock cycles after which we should observe an interrupt
    TIMEOUT_THRESHOLD = 50
    while wait_irq:
        timeout += 1
        await ClockCycles(dut.hclk, 10)
        irq = dword2int(await tb.read_csr(TTI_INTERRUPT_STATUS, 4))
        if irq:
            wait_irq = False
            dut._log.debug(":::Interrupt was raised:::")
        if timeout > TIMEOUT_THRESHOLD:
            wait_irq = False
            dut._log.debug(":::Timeout cancelled polling:::")

    # Read data
    test_data_lin = test_data[0] + test_data[1]
    for i in range(len(test_data_lin)):
        r_data = dword2int(await tb.read_csr(TTI_RX_DATA_PORT, 4))
        dut._log.debug(f"Comparing input {test_data_lin[i]} and CSR value {r_data}")
        assert test_data_lin[i] == r_data
