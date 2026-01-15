# run this in verification/cocotb: $make -C top/i3c_axi_controller all MODULE=test_configure_i3c_core
# SPDX-License-Identifier: Apache-2.0

import logging
from bus2csr import bytes2int, compare_values, int2dword
from controller_interface import I3CTopControllerTestInterface

import cocotb
from cocotb.triggers import Timer

async def timeout_task(timeout):
    await Timer(timeout, "us")
    raise RuntimeError("Test timeout!")

async def initialize(dut, fclk=333.0, timeout=50):
    cocotb.log.setLevel(logging.DEBUG)
    await cocotb.start(timeout_task(timeout))
    
    tb = I3CTopControllerTestInterface(dut, num_busses=3)
    await tb.setup(fclk)
    return tb

@cocotb.test()
async def test_ec_stdby_cr_enable_init(dut):
    """
    Writes to I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.STBY_CR_ENABLE_INIT
    using the multi-port interface.
    """
    tb = await initialize(dut)

    # 1. Define the Register and Field we want to access
    reg = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_CONTROL
    field = reg.STBY_CR_ENABLE_INIT 

    # 2. Define the test value (Enable Init = 1)
    write_val = 1
    
    # -------------------------------------------------------
    # TARGETING PORT 0 (Default - Expected Target)
    # -------------------------------------------------------
    dut._log.info("Writing STBY_CR_ENABLE_INIT to Port 0 (Default)...")
    
    await tb.write_csr_field(reg.base_addr, field, write_val, bus_idx=0)
    
    # Verify the read back
    read_val = await tb.read_csr_field(reg.base_addr, field, bus_idx=0)
    
    assert read_val == write_val, \
        f"[Port 0] Mismatch! Expected {write_val}, got {read_val}"
    
    dut._log.info("[Port 0] Write verified successfully.")

    # -------------------------------------------------------
    # TARGETING PORT 1 (Actual Controller)
    # -------------------------------------------------------
    dut._log.info("Writing STBY_CR_ENABLE_INIT to Port 1 (Actual Controller)...")

    # We must explicitly pass bus_idx=1 to target the second AXI port
    await tb.write_csr_field(reg.base_addr, field, write_val, bus_idx=1)

    read_val_p1 = await tb.read_csr_field(reg.base_addr, field, bus_idx=1)

    assert read_val_p1 == write_val, \
        f"[Port 1] Mismatch! Expected {write_val}, got {read_val_p1}"

    dut._log.info("[Port 1] Write verified successfully.")

    # -------------------------------------------------------
    # TARGETING PORT 2 (Actual Target)
    # -------------------------------------------------------
    dut._log.info("Writing STBY_CR_ENABLE_INIT = 0 to Port 2...")
    
    await tb.write_csr_field(reg.base_addr, field, 0, bus_idx=2)
    read_val_p2 = await tb.read_csr_field(reg.base_addr, field, bus_idx=2)
    
    assert read_val_p2 == 0, \
        f"[Port 2] Mismatch! Expected 0, got {read_val_p2}"

    dut._log.info("[Port 2] Write verified successfully.")

@cocotb.test()
async def test_configure_target_and_controller(dut):
    """
    Writes to I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.STBY_CR_ENABLE_INIT
    using the multi-port interface.
    """
    tb = await initialize(dut)

    # 1. Define the Register and Field we want to access
    reg = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_CONTROL
    field = reg.STBY_CR_ENABLE_INIT 
    
    # These values are obtained from configuration.sv (line 82: stby_cr_enable_init)
    target_conf_value = 2
    controller_conf_value = 3
    # -------------------------------------------------------
    # TARGETING PORT 0 (Default - Expected Target)
    # -------------------------------------------------------
    dut._log.info("Writing STBY_CR_ENABLE_INIT to Port 0 (Default)...")
    
    await tb.write_csr_field(reg.base_addr, field, target_conf_value, bus_idx=0)
    
    # Verify the read back
    read_val = await tb.read_csr_field(reg.base_addr, field, bus_idx=0)
    
    assert read_val == target_conf_value, \
        f"[Port 0] Mismatch! Expected {target_conf_value}, got {read_val}"
    
    dut._log.info("[Port 0] Write verified successfully.")

    # -------------------------------------------------------
    # TARGETING PORT 1 (Actual Controller)
    # -------------------------------------------------------
    dut._log.info("Writing STBY_CR_ENABLE_INIT to Port 1 (Actual Controller)...")

    # We must explicitly pass bus_idx=1 to target the second AXI port
    await tb.write_csr_field(reg.base_addr, field, controller_conf_value, bus_idx=1)

    read_val_p1 = await tb.read_csr_field(reg.base_addr, field, bus_idx=1)

    assert read_val_p1 == controller_conf_value, \
        f"[Port 1] Mismatch! Expected {controller_conf_value}, got {read_val_p1}"

    dut._log.info("[Port 1] Write verified successfully.")

    # -------------------------------------------------------
    # TARGETING PORT 2 (Actual Target)
    # -------------------------------------------------------
    dut._log.info("Writing STBY_CR_ENABLE_INIT to Port 2...")
    
    await tb.write_csr_field(reg.base_addr, field, target_conf_value, bus_idx=2)
    read_val_p2 = await tb.read_csr_field(reg.base_addr, field, bus_idx=2)
    
    assert read_val_p2 == target_conf_value, \
        f"[Port 2] Mismatch! Expected {target_conf_value}, got {read_val_p2}"

    dut._log.info("[Port 2] Write verified successfully.")
