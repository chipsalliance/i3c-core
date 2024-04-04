# Copyright (c) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Edge, FallingEdge, RisingEdge

async def bus_watcher(dut):
    """
    This task just feeds I2C signals driven by the DUT to its monitor inputs.
    FIXME: Signals are updated at each clock edge which seems to be ok
    """

    while True:

        # Make the DUT see same signals it is outputting
        dut.sda_i = dut.sda_o.value
        dut.scl_i = dut.scl_o.value

        await Edge(dut.clk_i)

async def i2c_rx_handler(dut):
    """
    Handles data at the receive port of the FSM module
    """

    while True:

        await RisingEdge(dut.clk_i)

        if dut.rx_fifo_wvalid_o.value:
            data = int(dut.rx_fifo_wdata_o.value)
            print(f"RX: {data:08X}")

async def i2c_cmd(dut, data, sta_before=False, sto_after=False, read=False, cont=False, ack=True):
    """
    Issues a command to the FSM
    """

    await RisingEdge(dut.clk_i)

    dut.fmt_fifo_rvalid_i           = 1
    dut.fmt_byte_i                  = int(data)
    dut.fmt_flag_start_before_i     = int(sta_before)
    dut.fmt_flag_stop_after_i       = int(sto_after)
    dut.fmt_flag_read_bytes_i       = int(read)
    dut.fmt_flag_read_continue_i    = int(cont)
    dut.fmt_flag_nak_ok_i           = int(not ack)

    while True:

        await RisingEdge(dut.clk_i)

        if dut.fmt_fifo_rready_o.value:
            dut.fmt_fifo_rvalid_i = 0
            break


@cocotb.test()
async def run_test(dut):
    """
    The test
    """

    # Drive constant DUT inputs
    dut.host_enable_i       = 1
    dut.target_enable_i     = 0

    dut.thigh_i             = 10
    dut.tlow_i              = 10
    dut.t_r_i               = 1
    dut.t_f_i               = 1

    dut.tsu_sta_i           = 1
    dut.thd_sta_i           = 1
    dut.tsu_sto_i           = 1
    dut.tsu_dat_i           = 1
    dut.thd_dat_i           = 1

    dut.t_buf_i             = 1

    dut.stretch_timeout_i   = 0
    dut.timeout_enable_i    = 0

    # Non-host signals
    dut.host_timeout_i      = 0
    dut.host_nack_handler_timeout_en_i = 0
    dut.nack_timeout_en_i   = 0

    dut.target_address0_i   = 0
    dut.target_address1_i   = 0
    dut.target_mask0_i      = 0
    dut.target_mask1_i      = 0

    dut.tx_fifo_rvalid_i    = 0
    dut.tx_fifo_rdata_i     = 0

    # Command/TX fifo
    dut.fmt_fifo_depth_i    = 1
    dut.fmt_fifo_rvalid_i   = 0

    # Start clock
    clock = Clock(dut.clk_i, 0.5, units="us")
    cocotb.start_soon(clock.start())

    # Start I2C bus watcher
    cocotb.start_soon(bus_watcher(dut))

    # Start receive handler
    cocotb.start_soon(i2c_rx_handler(dut))

    # Reset
    dut.rst_ni = 0
    await ClockCycles(dut.clk_i, 2)
    await FallingEdge(dut.clk_i)
    dut.rst_ni = 1
    await ClockCycles(dut.clk_i, 2)

    # Write [0x01, 0x02, 0x03, 0x04] to device at 0xA0 (8-bit addr)
    # STA + addr
    await i2c_cmd(dut, 0xA0, sta_before=True)
    # Data
    await i2c_cmd(dut, 0x01)
    await i2c_cmd(dut, 0x02)
    await i2c_cmd(dut, 0x03)
    await i2c_cmd(dut, 0x04, sto_after=True)

    # Dummy
    await ClockCycles(dut.clk_i, 50)
