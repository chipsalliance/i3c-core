# SPDX-License-Identifier: Apache-2.0

from functools import partial
from typing import Any

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge
from cocotbext.i2c import I2cMaster
from utils import Sequence, split_into_dwords

import i2c


async def reset(dut):
    dut.rst_ni.value = 0
    await ClockCycles(dut.clk_i, 100)
    await FallingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await ClockCycles(dut.clk_i, 2)


async def write(master, addr, word):
    await master.write(addr, word)
    await master.send_stop()


def standby_ctrl(dut: Any) -> Any:
    return dut.xcontroller.xcontroller_standby


def MatchTTIResponseExact(byte_count: int, dut: Any) -> bool:
    return i2c.MatchTTIResponseExact(byte_count, dut.i3c)


def MatchOTAcqDataExact(value: int, dut: Any, mask: int = 0x3FF) -> bool:
    return i2c.MatchOTAcqDataExact(value, standby_ctrl(dut), mask)


def MatchTTIDataExact(value, dut, mask=0xFFFF_FFFF) -> bool:
    return i2c.MatchTTIDataExact(value, dut.i3c, mask)


async def test_write_sequence(
    dut: Any, master: I2cMaster, addr: int, data: bytes, timeout_cycles: int
):
    seq = Sequence(
        [partial(MatchTTIDataExact, dword, mask=mask) for dword, mask in split_into_dwords(data)]
    )
    seq += Sequence(partial(MatchTTIResponseExact, len(data)))

    dut.i3c.tti_rx_queue_wready.value = 1
    dut.i3c.tti_rx_desc_queue_wready.value = 1

    seq_task = cocotb.start_soon(seq.match(dut, dut.clk_i, timeout_cycles, trace=True))
    await write(master, addr, data)
    await seq_task

    print(seq_task.result())
    assert seq_task.result().matched


@cocotb.test()
async def run_test(dut):
    TARGET_ADDR = 0x18
    CLK_SPEED = 400e3

    master = I2cMaster(
        sda=dut.i3c_sda_i,
        sda_o=None,
        scl=dut.i3c_scl_i,
        scl_o=None,
        speed=CLK_SPEED,
    )

    # Start clock
    clock = Clock(dut.clk_i, 0.5 / 4, units="us")
    cocotb.start_soon(clock.start())

    # Reset

    # TODO: Patch i2c master to remove this hack
    # Without these settings scl,sda start low and start is never detected
    master.bus_active = True
    master._set_sda(1)
    master._set_scl(1)
    await ClockCycles(dut.clk_i, 5)

    await reset(dut)
    test_data = [
        bytes([0xA5]),  # Write single byte
        "WORD".encode("ascii"),  # Write exactly one DWORD (so one entry in RX FIFO)
        "hello".encode("ascii"),  # Write more than one DWORD, but not a multiple of DWORDs
        bytes([0x8B, 0xAD, 0xF0, 0x0D, 0xDE, 0xAD, 0xBE, 0xEF]),  # Write multiple of DWORDs
    ]

    for data in test_data:
        dut._log.info(f"Testing stimuli: {data}")
        await test_write_sequence(dut, master, TARGET_ADDR, data, 4000)
