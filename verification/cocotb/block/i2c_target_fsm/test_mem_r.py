# SPDX-License-Identifier: Apache-2.0

from functools import partial
from typing import Any

from cocotbext.i2c import I2cMaster
from hci import TxFifo
from i2c import reset_controller
from utils import Sequence, SequenceFailed

import cocotb
from cocotb.clock import Clock


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
    dut.target_address1_i.value = 0
    dut.target_mask1_i.value = 0

    # FIFO mock
    dut.acq_fifo_depth_i = 0

    # Others / unused
    dut.target_enable_i.value = 1
    dut.tx_fifo_rvalid_i.value = 0
    dut.tx_fifo_rdata_i.value = 0


async def read(master: I2cMaster, addr: int, count: int) -> bytearray:
    data = await master.read(addr, count)
    await master.send_stop()
    return data


def MatchWAcqDataExact(value, dut, mask=0x3FF):
    if dut.acq_fifo_wvalid_o.value:
        if dut.acq_fifo_wdata_o.value & mask == value & mask:
            return True
        raise SequenceFailed()
    return False


async def test_read_sequence(dut: Any, address: int, master: I2cMaster, data: bytes):
    fifo = TxFifo(
        clk=dut.clk_i,
        data_port=dut.tx_fifo_rdata_i,
        valid_port=dut.tx_fifo_rvalid_i,
        ready_port=dut.tx_fifo_rready_o,
        content=data,
        name="tx_fifo",
    )

    seq = (
        Sequence(partial(MatchWAcqDataExact, 0x101 | (address << 1)))
        + Sequence(len(data) * [fifo.MatchPop])
        + Sequence(partial(MatchWAcqDataExact, 0x200, mask=0x300))
    )

    read_task = cocotb.start_soon(read(master, address, len(data)))
    match_ = await seq.match(dut, dut.clk_i, 1000)
    await read_task

    assert bytes(read_task.result()) == data
    assert match_.matched


@cocotb.test()
async def test_mem_r(dut):
    TARGET_ADDR = 12
    CLK_SPEED = 400000

    init_i2c_target_ports(dut, TARGET_ADDR)

    master = I2cMaster(
        sda=dut.sda_o, sda_o=dut.sda_i, scl=dut.scl_o, scl_o=dut.scl_i, speed=CLK_SPEED
    )

    # Start clock
    clock = Clock(dut.clk_i, 0.5, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    await reset_controller(dut)

    log = cocotb.logging.getLogger(f"cocotb.{dut._path}")
    log.info("RESET")

    await test_read_sequence(dut, TARGET_ADDR, master, "hello".encode("ascii"))
    await test_read_sequence(dut, TARGET_ADDR, master, "WORD".encode("ascii"))
