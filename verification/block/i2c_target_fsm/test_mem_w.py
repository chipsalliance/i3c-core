# SPDX-License-Identifier: Apache-2.0

from functools import partial

import cocotb
from cocotb.clock import Clock
from cocotbext.i2c import I2cMaster
from utils import Sequence, SequenceFailed

from i2c import reset_controller


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


async def write(master: I2cMaster, addr: int, word: bytes):
    await master.write(addr, word)
    await master.send_stop()


def MatchWDataExact(value, dut):
    if dut.acq_fifo_wvalid_o.value:
        if dut.acq_fifo_wdata_o.value == value:
            return True
        raise SequenceFailed()
    return False


@cocotb.test()
async def run_test(dut):
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

    seq = Sequence(
        [
            partial(MatchWDataExact, 0x118),
            partial(MatchWDataExact, ord("h")),
            partial(MatchWDataExact, ord("e")),
            partial(MatchWDataExact, ord("l")),
            partial(MatchWDataExact, ord("l")),
            partial(MatchWDataExact, ord("o")),
            partial(MatchWDataExact, 0x2DE),
        ]
    )

    # Execute single I2C command test -----------------------------------------
    cocotb.start_soon(write(master, TARGET_ADDR, "hello".encode("ascii")))
    match_ = await seq.match(dut, dut.clk_i, 1000)

    assert match_.matched
