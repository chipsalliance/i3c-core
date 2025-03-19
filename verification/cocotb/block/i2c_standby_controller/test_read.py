# SPDX-License-Identifier: Apache-2.0

from functools import partial
from itertools import repeat
from typing import Any

import i2c
from cocotbext.i2c import I2cMaster
from hci import TxFifo
from utils import Sequence, SequenceFailed, split_into_dwords

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge


async def reset(dut):
    dut.rst_ni.value = 0
    await ClockCycles(dut.clk_i, 100)
    await FallingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await ClockCycles(dut.clk_i, 2)
    dut.i2c_standby_en_i.value = 1

    dut.rx_desc_queue_full_i.value = 0
    dut.rx_desc_queue_ready_thld_i.value = 0
    dut.rx_desc_queue_ready_thld_trig_i.value = 0
    dut.rx_desc_queue_empty_i.value = 0
    dut.rx_desc_queue_wready_i.value = 0

    dut.tx_desc_queue_full_i.value = 0
    dut.tx_desc_queue_ready_thld_i.value = 0
    dut.tx_desc_queue_ready_thld_trig_i.value = 0
    dut.tx_desc_queue_empty_i.value = 0
    dut.tx_desc_queue_rvalid_i.value = 0
    dut.tx_desc_queue_rdata_i.value = 0

    dut.rx_queue_full_i.value = 0
    dut.rx_queue_start_thld_i.value = 0
    dut.rx_queue_start_thld_trig_i.value = 0
    dut.rx_queue_ready_thld_i.value = 0
    dut.rx_queue_ready_thld_trig_i.value = 0
    dut.rx_queue_empty_i.value = 0
    dut.rx_queue_wready_i.value = 0

    dut.tx_queue_full_i.value = 0
    dut.tx_queue_start_thld_i.value = 0
    dut.tx_queue_start_thld_trig_i.value = 0
    dut.tx_queue_ready_thld_i.value = 0
    dut.tx_queue_ready_thld_trig_i.value = 0
    dut.tx_queue_empty_i.value = 0
    dut.tx_queue_rvalid_i.value = 0
    dut.tx_queue_rdata_i.value = 0

    dut.phy_en_i.value = 0
    dut.phy_mux_select_i.value = 0
    dut.i2c_active_en_i.value = 0
    dut.i3c_active_en_i.value = 0
    dut.i3c_standby_en_i.value = 0
    dut.t_hd_dat_i.value = 0
    dut.t_r_i.value = 0
    dut.t_bus_free_i.value = 0
    dut.t_bus_idle_i.value = 0
    dut.t_bus_available_i.value = 0
    dut.pid_i.value = 0
    dut.bcr_i.value = 0
    dut.dcr_i.value = 0
    dut.target_sta_addr_i.value = 0
    dut.target_sta_addr_valid_i.value = 0
    dut.target_dyn_addr_i.value = 0
    dut.target_dyn_addr_valid_i.value = 0
    dut.target_ibi_addr_i.value = 0
    dut.target_ibi_addr_valid_i.value = 0
    dut.target_hot_join_addr_i.value = 0
    dut.daa_unique_response_i.value = 0

async def read(master: I2cMaster, addr: int, count: int) -> bytearray:
    data = await master.read(addr, count)
    await master.send_stop()
    return data


def standby_ctrl(dut: Any) -> Any:
    return dut


def CheckNoStretch(dut: Any) -> bool:
    if standby_ctrl(dut).controller_standby_i2c.xi2c_target_fsm.state_q.value in [0x17, 0x18, 0x19, 0x1A]:
        raise SequenceFailed()
    return True


def MatchOTAcqDataExact(value, dut, mask=0x3FF):
    return i2c.MatchOTAcqDataExact(value, standby_ctrl(dut), mask)


async def test_read_sequence(
    dut: Any, master: I2cMaster, addr: int, data: bytes, timeout_cycles: int
):
    tx_fifo_data = [dword for dword, _ in split_into_dwords(data)]

    tx_fifo = TxFifo(
        clk=dut.clk_i,
        data_port=dut.tx_queue_rdata_i,
        valid_port=dut.tx_queue_rvalid_i,
        ready_port=dut.tx_queue_rready_o,
        content=tx_fifo_data,
        name="tti_tx_fifo",
    )

    cmd_fifo = TxFifo(
        clk=dut.clk_i,
        data_port=dut.tx_desc_queue_rdata_i,
        valid_port=dut.tx_desc_queue_rvalid_i,
        ready_port=dut.tx_desc_queue_rready_o,
        content=[len(data) << 16],
        name="tti_tx_desc_fifo",
    )

    # 1. Expect command and first data word to be popped, either at once or
    #    command first and then data
    # 2. Expect the remaining data words to be popped too
    # 3. Expect STOP signal from ACQ FIFO
    # Preface each predicate with a check that ensures we are not stretching the clock
    seq_pop_simultaneously = Sequence(TxFifo.MatchPopMany(cmd_fifo, tx_fifo))
    seq_pop_separately = Sequence([cmd_fifo.MatchPop, tx_fifo.MatchPop])
    seq_pop_tail = Sequence((len(tx_fifo_data) - 1) * [tx_fifo.MatchPop])
    seq = (seq_pop_simultaneously | seq_pop_separately) + seq_pop_tail
    seq = seq + Sequence(partial(MatchOTAcqDataExact, 0x200, mask=0x300))
    seq = Sequence(repeat(CheckNoStretch)) & seq

    seq_task = cocotb.start_soon(
        seq.match(dut, dut.clk_i, timeout_cycles, noexcept=False, trace=True)
    )
    rd_data = await read(master, addr, len(data))

    assert bytes(rd_data) == data

    await seq_task
    dut._log.info(seq_task.result())
    assert seq_task.result().matched


def str_to_dword(s):
    def ord_or_null(idx):
        return ord(s[idx]) if idx < len(s) else 0

    return (
        (ord_or_null(3) << 24)
        | (ord_or_null(2) << 16)
        | (ord_or_null(1) << 8)
        | (ord_or_null(0) << 0)
    )


@cocotb.test()
async def test_read(dut):
    TARGET_ADDR = 0x18
    CLK_SPEED = 400e3

    master = I2cMaster(
        sda=dut.ctrl_sda_o,
        sda_o=dut.ctrl_sda_i,
        scl=dut.ctrl_scl_i,
        scl_o=None,
        speed=CLK_SPEED,
    )

    # Start clock
    clock = Clock(dut.clk_i, 0.5 / 4, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    master.bus_active = True
    master._set_sda(1)
    master._set_scl(1)
    await ClockCycles(dut.clk_i, 5)

    await reset(dut)

    test_data = [
        bytes([0xA5]),  # Read single byte
        "WORD".encode("ascii"),  # Write exactly one DWORD (so one entry in RX FIFO)
        "hello".encode("ascii"),  # Write more than one DWORD, but not a multiple of DWORDs
        bytes([0x8B, 0xAD, 0xF0, 0x0D, 0xDE, 0xAD, 0xBE, 0xEF]),  # Write multiple of DWORDs
    ]

    for data in test_data:
        dut._log.info(f"Testing stimuli: {data}")
        await test_read_sequence(dut, master, TARGET_ADDR, data, 4000)
