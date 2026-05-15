# SPDX-License-Identifier: Apache-2.0

import logging
import random

from bus2csr import dword2int, int2dword
from interface import I3CTopTestInterface

import cocotb
from cocotb_helpers import reset_n
from common import timeout_task, log_seed

TRANSACTION_COUNT = 1024


async def initialize(dut, fclk=333.0, timeout=50):
    """
    Common test initialization routine
    """

    cocotb.log.setLevel(logging.DEBUG)
    log_seed(dut)

    # Start the background timeout task
    await cocotb.start(timeout_task(timeout))

    tb = I3CTopTestInterface(dut)
    await tb.setup(fclk)
    return tb


async def test_read(tb, reg):
    # try reading empty fifo multiple times
    for _ in range(TRANSACTION_COUNT):
        data = dword2int(
            await tb.read_csr(reg, 4)
        )
        # we should not stall and the data should be read as zero
        assert data == 0, f"Expected zero from empty FIFO read, got 0x{data:08X}"


@cocotb.test()
async def test_empty_rx_desc_read(dut):
    tb = await initialize(dut)
    await test_read(tb, tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr)

    await tb.teardown()


@cocotb.test()
async def test_empty_rx_data_read(dut):
    tb = await initialize(dut)
    await test_read(tb, tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr)

    await tb.teardown()


@cocotb.test()
async def test_empty_indirect_fifo_read(dut):
    tb = await initialize(dut)
    await test_read(tb, tb.reg_map.I3C_EC.SECFWRECOVERYIF.INDIRECT_FIFO_DATA.base_addr)

    await tb.teardown()

@cocotb.test()
async def test_full_tx_desc_write(dut):
    tb = await initialize(dut)
    QSIZE = tb.reg_map.I3C_EC.TTI.QUEUE_SIZE
    QDEPTH = tb.reg_map.I3C_EC.TTI.DESC_QUEUE_DEPTH
    QSTAT = tb.reg_map.I3C_EC.TTI.QUEUE_STATUS
    MAX_DEPTH = 2 ** (await tb.read_csr_field(QSIZE.base_addr, QSIZE.TX_DESC_BUFFER_SIZE) + 1)

    for i in range(TRANSACTION_COUNT):
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(random.randint(0, 0xffffffff)), 4)
        if i < MAX_DEPTH:
            depth = await tb.read_csr_field(QDEPTH.base_addr, QDEPTH.TX_DESC_QUEUE_DEPTH)
            assert i + 1 == depth, "Transaction did not increase queue depth"

    # Bus must not stall — verify it's still responsive
    data = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.EXTCAP_HEADER.base_addr, 4))
    assert data == 0x40C4, f"Bus stalled: TTI EXTCAP_HEADER read returned 0x{data:X} after {TRANSACTION_COUNT} TX_DESC writes"

    assert await tb.read_csr_field(QSTAT.base_addr, QSTAT.TX_DESC_QUEUE_FULL) == 1, "Queue is not full"

    await reset_n(tb.clk, tb.rst_n, cycles=5)
    await tb.teardown()

@cocotb.test()
async def test_full_tx_data_write(dut):
    tb = await initialize(dut)
    QSIZE = tb.reg_map.I3C_EC.TTI.QUEUE_SIZE
    QDEPTH = tb.reg_map.I3C_EC.TTI.DATA_QUEUE_DEPTH
    QSTAT = tb.reg_map.I3C_EC.TTI.QUEUE_STATUS
    MAX_DEPTH = 2 ** (await tb.read_csr_field(QSIZE.base_addr, QSIZE.TX_DATA_BUFFER_SIZE) + 1)

    for i in range(TRANSACTION_COUNT):
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, int2dword(random.randint(0, 0xffffffff)), 4)
        if i <= MAX_DEPTH+1 and i > 0:
            depth = await tb.read_csr_field(QDEPTH.base_addr, QDEPTH.TX_DATA_QUEUE_DEPTH)
            assert i == depth + 1, "Transaction did not increase queue depth"

    # Bus must not stall — verify it's still responsive
    data = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.EXTCAP_HEADER.base_addr, 4))
    assert data == 0x40C4, f"Bus stalled: TTI EXTCAP_HEADER read returned 0x{data:X} after {TRANSACTION_COUNT} TX_DESC writes"

    assert await tb.read_csr_field(QSTAT.base_addr, QSTAT.TX_DATA_QUEUE_FULL) == 1, "Queue is not full"

    await reset_n(tb.clk, tb.rst_n, cycles=5)
    await tb.teardown()

@cocotb.test()
async def test_full_ibi_write(dut):
    tb = await initialize(dut)
    QSIZE = tb.reg_map.I3C_EC.TTI.IBI_QUEUE_SIZE
    QDEPTH = tb.reg_map.I3C_EC.TTI.IBI_QUEUE_DEPTH
    QSTAT = tb.reg_map.I3C_EC.TTI.QUEUE_STATUS
    MAX_DEPTH = 2 ** (await tb.read_csr_field(QSIZE.base_addr, QSIZE.IBI_QUEUE_SIZE) + 1)

    for i in range(TRANSACTION_COUNT):
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, int2dword(random.randint(0, 0xffffffff)), 4)
        if i < MAX_DEPTH:
            depth = await tb.read_csr_field(QDEPTH.base_addr, QDEPTH.IBI_QUEUE_DEPTH)
            assert i + 1 == depth, "Transaction did not increase queue depth"

    # Bus must not stall — verify it's still responsive
    data = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.EXTCAP_HEADER.base_addr, 4))
    assert data == 0x40C4, f"Bus stalled: TTI EXTCAP_HEADER read returned 0x{data:X} after {TRANSACTION_COUNT} TX_DESC writes"

    assert await tb.read_csr_field(QSTAT.base_addr, QSTAT.IBI_QUEUE_FULL) == 1, "Queue is not full"

    await reset_n(tb.clk, tb.rst_n, cycles=5)
    await tb.teardown()
