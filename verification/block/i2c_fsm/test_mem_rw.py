# Copyright (c) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Edge, FallingEdge, RisingEdge

from cocotbext.i2c import I2cMemory

async def i2c_cmd(dut, data, sta_before=False, sto_after=False, read=False, cont=False, ack=True):
    """
    Issues a command to the FSM. Returns (ack, data) tuple
    """

    await RisingEdge(dut.clk_i)

    dut.fmt_fifo_rvalid_i.value           = 1
    dut.fmt_byte_i.value                  = int(data)
    dut.fmt_flag_start_before_i.value     = int(sta_before)
    dut.fmt_flag_stop_after_i.value       = int(sto_after)
    dut.fmt_flag_read_bytes_i.value       = int(read)
    dut.fmt_flag_read_continue_i.value    = int(cont)
    dut.fmt_flag_nak_ok_i.value           = int(not ack)

    resp_ack = True
    resp_dat = []

    # Issue the command
    while True:

        await RisingEdge(dut.clk_i)

        if dut.rx_fifo_wvalid_o.value:
            resp_dat.append(int(dut.rx_fifo_wdata_o.value))

        if dut.event_nak_o.value:
            resp_ack = False

        if dut.fmt_fifo_rready_o.value:
            dut.fmt_fifo_rvalid_i.value = 0
            break

    return resp_ack, resp_dat

async def i2c_mem_write(dut, i2c_addr, mem_addr, mem_data):
    """
    Issues an I2C memory write sequence. Checks for ACKs
    """

    # STA + device addr
    ack, res = await i2c_cmd(dut, i2c_addr << 1, sta_before=True)
    assert ack

    # Mem addr
    ack, res = await i2c_cmd(dut, mem_addr)
    assert ack

    # Mem data
    for data in mem_data[:-1]:
        ack, res = await i2c_cmd(dut, data)
        assert ack

    # Last mem data + STO
    ack, res = await i2c_cmd(dut, mem_data[-1], sto_after=True)
    assert ack

async def i2c_mem_read(dut, i2c_addr, mem_addr, length=1):
    """
    Issues an I2C memory read sequence. Checks for ACKs
    """

    # STA + device addr
    ack, res = await i2c_cmd(dut, i2c_addr << 1, sta_before=True)
    assert ack

    # Mem addr
    ack, res = await i2c_cmd(dut, mem_addr)
    assert ack

    # RSTA
    ack, res = await i2c_cmd(dut, (i2c_addr << 1) | 1, sta_before=True)
    assert ack

    # Read
    ack, res = await i2c_cmd(dut, length, read=True, sto_after=True)
    assert ack

    return res

@cocotb.test()
async def run_test(dut):
    """
    The test
    """

    # I2C target
    i2c_target = I2cMemory(
        sda=dut.sda_o,
        sda_o=dut.sda_i,
        scl=dut.scl_o,
        scl_o=dut.scl_i
    )

    # Drive constant DUT inputs
    dut.host_enable_i.value       = 1
    dut.target_enable_i.value     = 0

    dut.thigh_i.value             = 10
    dut.tlow_i.value              = 10
    dut.t_r_i.value               = 1
    dut.t_f_i.value               = 1

    dut.tsu_sta_i.value           = 1
    dut.thd_sta_i.value           = 1
    dut.tsu_sto_i.value           = 1
    dut.tsu_dat_i.value           = 1
    dut.thd_dat_i.value           = 1

    dut.t_buf_i.value             = 1

    dut.stretch_timeout_i.value   = 0
    dut.timeout_enable_i.value    = 0

    # Non-host signals
    dut.host_timeout_i.value      = 0
    dut.host_nack_handler_timeout_en_i.value = 0
    dut.nack_timeout_en_i.value   = 0

    dut.target_address0_i.value   = 0
    dut.target_address1_i.value   = 0
    dut.target_mask0_i.value      = 0
    dut.target_mask1_i.value      = 0

    dut.tx_fifo_rvalid_i.value    = 0
    dut.tx_fifo_rdata_i.value     = 0

    # Command/TX fifo
    dut.fmt_fifo_depth_i.value    = 1
    dut.fmt_fifo_rvalid_i.value   = 0

    # Start clock
    clock = Clock(dut.clk_i, 0.5, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_ni.value = 0
    await ClockCycles(dut.clk_i, 2)
    await FallingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await ClockCycles(dut.clk_i, 2)

    ## Test ##

    payload = [0xCA, 0xFE, 0xBA, 0xCA, 0xDE, 0xAD, 0xBE, 0xEF]

    # I2C memory write
    await i2c_mem_write(dut, 0x50, 0x10, payload)

    # Wait
    await ClockCycles(dut.clk_i, 100)

    # I2C memory read
    received = await i2c_mem_read(dut, 0x50, 0x10, len(payload))
    assert payload == received

    # Dummy
    await ClockCycles(dut.clk_i, 100)
