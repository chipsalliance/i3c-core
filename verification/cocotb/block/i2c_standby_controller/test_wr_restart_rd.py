# SPDX-License-Identifier: Apache-2.0

from functools import partial
from itertools import repeat
from typing import Any

import colorama
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


async def read(master: I2cMaster, addr: int, count: int) -> bytearray:
    data = await master.read(addr, count)
    await master.send_stop()
    return data


def standby_ctrl(dut: Any) -> Any:
    return dut.i3c.xcontroller.xcontroller_standby


def CheckNoStretch(dut: Any) -> bool:
    if standby_ctrl(dut).i2c_fsm.state_q.value in [0x17, 0x18, 0x19, 0x1A]:
        raise SequenceFailed()
    return True


def MatchOTAcqDataExact(value, dut, mask=0x3FF) -> bool:
    return i2c.MatchOTAcqDataExact(value, standby_ctrl(dut), mask)


def MatchTTIResponseExact(byte_count: int, dut: Any) -> bool:
    return i2c.MatchTTIResponseExact(byte_count, dut.i3c)


def MatchTTIDataExact(value, dut, mask=0xFFFF_FFFF) -> bool:
    return i2c.MatchTTIDataExact(value, dut.i3c, mask)


def prepare_rx_fifo(dut: any) -> None:
    dut.i3c.tti_rx_fifo_wready.value = 1
    dut.i3c.tti_response_fifo_wready.value = 1


async def test_write_restart_read_sequence(
    dut: Any,
    master: I2cMaster,
    addr: int,
    request_data: bytes,
    response_data: bytes,
    timeout_cycles: int,
):
    tx_fifo_data = [dword for dword, _ in split_into_dwords(response_data)]

    tx_fifo = TxFifo(
        clk=dut.clk_i,
        data_port=dut.i3c.tti_tx_fifo_rdata,
        valid_port=dut.i3c.tti_tx_fifo_rvalid,
        ready_port=dut.i3c.tti_tx_fifo_rready,
        content=tx_fifo_data,
        name="tx_fifo",
    )

    cmd_fifo = TxFifo(
        clk=dut.clk_i,
        data_port=dut.i3c.tti_cmd_fifo_rdata,
        valid_port=dut.i3c.tti_cmd_fifo_rvalid,
        ready_port=dut.i3c.tti_cmd_fifo_rready,
        content=[len(response_data) << 16],
        name="cmd_fifo",
    )

    async def master_write_read():
        await master.write(addr, request_data)
        return await read(master, addr, len(response_data))

    # RX (request) sequences
    rx_tti_seq = Sequence(
        [
            partial(MatchTTIDataExact, dword, mask=mask)
            for dword, mask in split_into_dwords(request_data)
        ]
    )
    rx_tti_seq += Sequence(partial(MatchTTIResponseExact, len(request_data)))

    rx_fsm_seq = Sequence(partial(MatchOTAcqDataExact, 0x100, mask=0x301))
    rx_fsm_seq += Sequence(partial(MatchOTAcqDataExact, b, mask=0x300) for b in request_data)
    rx_fsm_seq += Sequence(partial(MatchOTAcqDataExact, 0x300, mask=0x300))
    rx_fsm_seq = Sequence(repeat(CheckNoStretch)) & rx_fsm_seq

    prepare_rx_fifo(dut)

    # TX (response) sequences
    tx_tti_seq_pop_simultaneously = Sequence(TxFifo.MatchPopMany(cmd_fifo, tx_fifo))
    tx_tti_seq_pop_separately = Sequence([cmd_fifo.MatchPop, tx_fifo.MatchPop])
    tx_tti_seq_pop_tail = Sequence((len(tx_fifo_data) - 1) * [tx_fifo.MatchPop])
    tx_tti_seq = (tx_tti_seq_pop_simultaneously | tx_tti_seq_pop_separately) + tx_tti_seq_pop_tail

    tx_fsm_seq = Sequence(
        [
            partial(MatchOTAcqDataExact, 0x101, mask=0x301),
            partial(MatchOTAcqDataExact, 0x200, mask=0x300),
        ]
    )
    tx_fsm_seq = Sequence(repeat(CheckNoStretch)) & tx_fsm_seq

    # Fire up the master
    i2c_transaction_task = cocotb.start_soon(master_write_read())

    # Receive and check request
    rx_tti_task = cocotb.start_soon(
        rx_tti_seq.match(dut, dut.clk_i, timeout_cycles, noexcept=False, trace=True)
    )
    rx_fsm_task = cocotb.start_soon(
        rx_fsm_seq.match(dut, dut.clk_i, timeout_cycles, noexcept=False, trace=True)
    )

    for task in (rx_tti_task, rx_fsm_task):
        await task
    assert rx_tti_task.result().matched
    assert rx_fsm_task.result().matched

    dut._log.info(f"{colorama.Fore.GREEN}<== Request received successfully{colorama.Fore.RESET}")

    # Emit and check response
    tx_tti_task = cocotb.start_soon(
        tx_tti_seq.match(dut, dut.clk_i, timeout_cycles, noexcept=False, trace=True)
    )
    tx_fsm_task = cocotb.start_soon(
        tx_fsm_seq.match(dut, dut.clk_i, timeout_cycles, noexcept=False, trace=True)
    )

    for task in (tx_tti_task, tx_fsm_task, i2c_transaction_task):
        await task
    assert bytes(i2c_transaction_task.result()) == response_data
    assert tx_tti_task.result().matched
    assert tx_fsm_task.result().matched

    dut._log.info(f"{colorama.Fore.GREEN}==> Response emitted suuccessfully{colorama.Fore.RESET}")

    dut.i3c.tti_rx_fifo_wready.value = 0
    dut.i3c.tti_response_fifo_wready.value = 0
    dut.i3c.tti_tx_fifo_rvalid.value = 0
    dut.i3c.tti_cmd_fifo_rvalid.value = 0


@cocotb.test()
async def test_wr_restart_rd(dut):
    TARGET_ADDR = 12
    CLK_SPEED = 400000

    master = I2cMaster(
        sda=dut.i3c.xi3c_muxed_phy.mux_phy_sda,
        sda_o=dut.i3c_sda_i,
        scl=dut.i3c.xi3c_muxed_phy.mux_phy_scl,
        scl_o=dut.i3c_scl_i,
        speed=CLK_SPEED,
    )

    # Start clock
    clock = Clock(dut.clk_i, 0.5 / 4, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    await reset(dut)

    test_data = [
        (bytes([0]), bytes([1])),
        ("Cool".encode(), "Nice".encode()),
        ("hello".encode(), "world".encode()),
        (bytes([0x8B, 0xAD, 0xF0, 0x0D, 0xDE, 0xAD, 0xBE, 0xEF]), bytes([0x60])),
        ("meowmeowmeow".encode(), "i'll bite you!".encode()),
        (bytes([0xFF, 0x00]), bytes([0xFE, 0xED])),
    ]

    for request, response in test_data:
        dut._log.info(f"Testing stimuli: {(request, response)}")
        await test_write_restart_read_sequence(dut, master, TARGET_ADDR, request, response, 6000)
        await ClockCycles(dut.clk_i, 100)

    # for request, response in test_data:
    #    await master.write(TARGET_ADDR, request)
    #    await read(master, TARGET_ADDR, len(response))
