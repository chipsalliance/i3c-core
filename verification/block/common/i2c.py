# SPDX-License-Identifier: Apache-2.0

from typing import Any

from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, with_timeout
from utils import SequenceFailed

I3C_PHY_DELAY = 2


async def i2c_cmd(
    dut,
    data,
    sta_before=False,
    sto_after=False,
    read=False,
    cont=False,
    ack=True,
    timeout: int = 2,
    units: str = "ms",
):
    """
    Issues a command to the FSM. Returns (ack, data) tuple
    """

    async def issue_command():
        resp_ack = True
        while True:
            await RisingEdge(dut.clk_i)

            if dut.rx_fifo_wvalid_o.value:
                resp_dat.append(int(dut.rx_fifo_wdata_o.value))

            if dut.event_nak_o.value:
                resp_ack = False

            if dut.fmt_fifo_rready_o.value:
                dut.fmt_fifo_rvalid_i.value = 0
                break
        return resp_ack

    await RisingEdge(dut.clk_i)

    dut.fmt_fifo_rvalid_i.value = 1
    dut.fmt_byte_i.value = int(data)
    dut.fmt_flag_start_before_i.value = int(sta_before)
    dut.fmt_flag_stop_after_i.value = int(sto_after)
    dut.fmt_flag_read_bytes_i.value = int(read)
    dut.fmt_flag_read_continue_i.value = int(cont)
    dut.fmt_flag_nak_ok_i.value = int(not ack)

    resp_ack = True
    resp_dat = []

    # Issue the command
    resp_ack = await with_timeout(issue_command(), timeout, units)

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


async def reset_controller(dut):
    dut.rst_ni.value = 0
    await ClockCycles(dut.clk_i, 100)
    await FallingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await ClockCycles(dut.clk_i, 2)


def init_i2c_controller_ports(dut):
    # Drive constant DUT inputs
    dut.host_enable_i.value = 1

    # TODO: Calculate timing values compatible with specification:
    #       https://opentitan.org/book/hw/ip/i2c/doc/programmers_guide.html
    dut.thigh_i.value = 10
    dut.tlow_i.value = 10
    dut.t_r_i.value = 1
    dut.t_f_i.value = 1

    dut.tsu_sta_i.value = 1
    dut.thd_sta_i.value = 1
    dut.tsu_sto_i.value = 1
    dut.tsu_dat_i.value = 1
    dut.thd_dat_i.value = 1

    dut.t_buf_i.value = 1

    dut.stretch_timeout_i.value = 0
    dut.timeout_enable_i.value = 0

    # Non-host signals
    dut.host_nack_handler_timeout_en_i.value = 0

    # Command/TX fifo
    dut.fmt_fifo_depth_i.value = 1
    dut.fmt_fifo_rvalid_i.value = 0


def init_i2c_target_ports(dut, address):
    # Timing
    dut.t_r_i.value = 1
    dut.tsu_dat_i.value = 1
    dut.thd_dat_i.value = 1
    dut.host_timeout_i.value = 0
    dut.nack_timeout_i.value = 0
    dut.nack_timeout_en_i.value = 0

    # Addressing
    dut.target_address0_i.value = address
    dut.target_mask0_i.value = 0x7F
    dut.target_address1_i.value = address
    dut.target_mask1_i.value = 0x7F

    # Others / unused
    dut.target_enable_i.value = 1


def MatchOTAcqDataExact(value: int, dut: Any, mask: int = 0x3FF) -> bool:
    """Sequence predicate: Match data in ACQ queue"""
    breakpoint()
    if dut.xcontroller_standby_i2c.acq_fifo_valid_int.value:
        if (
            dut.xcontroller_standby.xcontroller_standby_i2c.acq_fifo_wdata_int.value & mask
            == value & mask
        ):
            return True
        raise SequenceFailed()
    return False


def MatchTTIDataExact(value: int, dut: Any, mask: int = 0xFFFF_FFFF) -> bool:
    """Sequence predicate: Match data in TTI RX queue"""
    if dut.tti_rx_queue_wvalid.value:
        if (dut.tti_rx_queue_wdata.value & mask) == (
            value & mask
        ) and dut.tti_rx_queue_wready.value:
            return True
        raise SequenceFailed()
    return False


def MatchTTIResponseExact(byte_count: int, dut: Any) -> bool:
    """Sequence predicate: Match byte count in TTI response queue"""
    if dut.tti_rx_desc_queue_wvalid.value:
        if (
            dut.tti_rx_desc_queue_wdata.value & 0xFFFF0000
        ) >> 16 == byte_count and dut.tti_rx_desc_queue_wready.value:
            return True
        raise SequenceFailed()
    return False
