# SPDX-License-Identifier: Apache-2.0

import logging
import random

from bus2csr import compare_values, int2dword
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import Timer


async def timeout_task(timeout):
    await Timer(timeout, "us")
    raise RuntimeError("Test timeout!")


async def initialize(dut, fclk=100.0, timeout=50):
    """
    Common test initialization routine
    """

    cocotb.log.setLevel(logging.DEBUG)

    # Start the background timeout task
    await cocotb.start(timeout_task(timeout))

    tb = I3CTopTestInterface(dut)
    await tb.setup(fclk)
    return tb


def rand_reg_val(reg):
    wdata = random.randint(0, 2**32 - 1)
    exp_rd = 0
    for f_name in reg:
        if f_name in ["base_addr", "offset"]:
            continue
        f = getattr(reg, f_name)
        reset = 0 if "reset" not in f else f.reset
        if f.sw == "r":
            data = (reset << f.low) & f.mask
        elif any([f.woclr, f.hwclr, f.sw == "w"]):
            data = 0
        else:
            data = wdata & f.mask
        exp_rd |= data
    return wdata, exp_rd


def csr_access_test_data(reg_if, skip_regs=[]):
    """
    reg_if: dict
        Sub-dictionary of `common.reg_map`. Contains a collection of registers.
        Each register contains a collection of register fields.
    skip_regs: list
        Names of the registers to be excluded from generated test data.

    Takes a dictionary of registers and prepares CSR read-write test data.
    Draws a random 32-bit word and deduces expected read from the register based on
    register field descriptions.

    Will expect to read `0` if register is set to clear on write or contains `hwclr` property.

    Will expect to read `reset` value (`0` if `reset` is not specified) if a register is read-only
    by software.

    Otherwise, will expect to read respective sub-word with account for field mask.

    NOTE: Limitation of this function is that it will only prepare test data for the registers
          at the depth `1` of the `reg_if`.
          Will skip registers that are contained within the additional regfiles of the `reg_if`.
    """
    skip_regs = skip_regs.copy()
    skip_regs.extend(["start_addr"])
    test_data = []
    for reg_name in reg_if:
        # Do not consider embedded register structures for now
        if reg_name in skip_regs or "base_addr" not in getattr(reg_if, reg_name):
            continue
        reg = getattr(reg_if, reg_name)
        test_data.append([reg_name, reg.base_addr, *rand_reg_val(reg)])
    return test_data


async def run_basic_csr_access(tb, reg_if, exceptions=[]):
    test_data = csr_access_test_data(reg_if, skip_regs=exceptions)

    for _, addr, wdata, exp_rd in test_data:
        await tb.write_csr(addr, int2dword(wdata), 4)
        rd_data = await tb.read_csr(addr)
        compare_values(int2dword(exp_rd), rd_data, addr)


@cocotb.test()
async def test_dat_csr_access(dut):
    tb = await initialize(dut)
    await run_basic_csr_access(tb, tb.reg_map.DAT)


@cocotb.test()
async def test_dct_csr_access(dut):
    exceptions = [
        "DCT_MEMORY",  # Out-of-use
    ]
    tb = await initialize(dut)
    await run_basic_csr_access(tb, tb.reg_map.DCT, exceptions)


@cocotb.test()
async def test_base_csr_access(dut):
    exceptions = [
        "RESET_CONTROL",
    ]
    tb = await initialize(dut)
    await run_basic_csr_access(tb, tb.reg_map.I3CBASE, exceptions)


@cocotb.test()
async def test_pio_csr_access(dut):
    exceptions = [
        "RESPONSE_PORT",
        "TX_DATA_PORT",
        "RX_DATA_PORT",
        "IBI_PORT",
        "QUEUE_THLD_CTRL",
    ]
    tb = await initialize(dut)
    await run_basic_csr_access(tb, tb.reg_map.PIOCONTROL, exceptions)


@cocotb.test()
async def test_ec_sec_fw_rec_csr_access(dut):
    exceptions = [
        "INDIRECT_FIFO_CTRL_0",
        "INDIRECT_FIFO_DATA",  # Viable only in recovery mode
    ]
    tb = await initialize(dut)
    await run_basic_csr_access(tb, tb.reg_map.I3C_EC.SECFWRECOVERYIF, exceptions)


@cocotb.test()
async def test_ec_stdby_ctrl_mode_csr_access(dut):
    unhandled = [
        "STBY_CR_STATUS",
        "STBY_CR_INTR_FORCE",
        "STBY_CR_CCC_CONFIG_GETCAPS",
        "__RSVD_3",
    ]
    exceptions = [
        "STBY_CR_CONTROL",
        "STBY_CR_INTR_STATUS",
        "STBY_CR_INTR_SIGNAL_ENABLE",
        "STBY_CR_CCC_CONFIG_RSTACT_PARAMS",
    ]
    exceptions.extend(unhandled)
    tb = await initialize(dut)
    await run_basic_csr_access(tb, tb.reg_map.I3C_EC.STDBYCTRLMODE, exceptions)

    # Standby Controller Mode CSRs that are not supported or are reserved
    # should not be updated with writes and should return `0` upon read
    for reg_name in unhandled:
        reg = getattr(tb.reg_map.I3C_EC.STDBYCTRLMODE, reg_name)
        addr = reg.base_addr
        exp_rd = 0

        await tb.write_csr(addr, int2dword(rand_reg_val(reg)[0]), 4)
        rd_data = await tb.read_csr(addr)
        compare_values(int2dword(exp_rd), rd_data, addr)


@cocotb.test()
async def test_ec_tti_csr_access(dut):
    exceptions = [
        "RESET_CONTROL",
        "RX_DESC_QUEUE_PORT",
        "RX_DATA_PORT",
        "QUEUE_THLD_CTRL",
    ]
    tb = await initialize(dut)
    await run_basic_csr_access(tb, tb.reg_map.I3C_EC.TTI, exceptions)


@cocotb.test()
async def test_ec_soc_mgmt_csr_access(dut):
    exceptions = ["REC_INTF_REG_W1C_ACCESS"]
    tb = await initialize(dut)
    await run_basic_csr_access(tb, tb.reg_map.I3C_EC.SOCMGMTIF, exceptions)


@cocotb.test()
async def test_ec_contrl_config_csr_access(dut):
    tb = await initialize(dut)
    await run_basic_csr_access(tb, tb.reg_map.I3C_EC.CTRLCFG)


@cocotb.test()
async def test_ec_csr_access(dut):
    tb = await initialize(dut)
    await run_basic_csr_access(tb, tb.reg_map.I3C_EC)
