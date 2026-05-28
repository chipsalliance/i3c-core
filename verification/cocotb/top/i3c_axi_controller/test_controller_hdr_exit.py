# SPDX-License-Identifier: Apache-2.0
import functools
import logging
import random
import os
from math import ceil

from boot_controller import boot_init
from monitor import BusStateMonitor
from bus2csr import dword2int, int2dword
from hci import immediate_transfer_descriptor_direct, regular_transfer_descriptor_direct, ResponseDescriptor, ErrorStatus, regular_transfer_descriptor, immediate_transfer_descriptor, address_assignment_descriptor, internal_control_descriptor
from ccc import CCC
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_target import I3CTarget
from cocotbext.i2c import I2cMemory

from controller_interface import I3CTopControllerTestInterface, I3CAddressHelper
from controller_interface import get_interrupt_status

import cocotb
from ctrl_common import *
from cocotb.triggers import ClockCycles, RisingEdge, Timer, Combine, Event
from cocotb.handle import Force, Release
from utils import format_ibi_data

ACT_TARGET_IDX = 2 # Port idx of actual target
ACT_CONTROLLER_IDX = 1 # Port idx of actual controller
TX_QUEUE_DEPTH = 64 # Depth of TX_QUEUE in dwords.
TX_READY_THLD = 0x1 # TX ready threshold
TX_START_THLD = 0x1 # TX start threshold

async def test_setup(dut, fclk=333.0, fbus=12.5, core_configs=None, enable_target_dynamic_addr=True):
    """
    Sets up controller, target models and top-level core interface
    according to the 'Expected Bus' architecture.
    """

    cocotb.log.setLevel(logging.INFO)
    logging.getLogger("cocotb.3").setLevel(logging.WARNING)
    dut._log.info(f"fclk = {fclk:.3f} MHz")
    dut._log.info(f"fbus = {fbus:.3f} MHz")

    tb = I3CTopControllerTestInterface(dut, num_busses=3)

    addr_helper = I3CAddressHelper(dut)
    dut._log.info("Generated random I3C addresses: ")
    addr_helper.print_addresses()

    # The target is listening to the I3C bus and will include assertions for the phy_sel_od_pp signal

    i3c_target = I3CTarget( 
        sda_i=dut.act_bus_sda_q2,
        sda_o=dut.exp_bus_sda,
        scl_i=dut.act_bus_scl_q2,
        scl_o=dut.exp_bus_scl,
        phy_sel_od_pp_i=dut.phy_sel_od_pp_o,
        debug_state_o=dut.debug_state_target_i,
        speed=fbus * 1e6,
    )

    await tb.setup(fclk)

    dut._log.info("Booting I3C Cores...")

    # Define configuration for each port
    # Port 0: Expected Target
    # Port 1: Actual Controller
    # Port 2: Actual Target
    if core_configs is None:
        if enable_target_dynamic_addr:
            core_configs = [
                {"idx": 0, "mode": 2, "static_addr": 0x0, "dyn_addr": 0x0, "virt_static_addr": 0x0, "virt_dyn_addr": 0x0}, # Mode 2 = EXP Target (UNUSED)
                {"idx": 1, "mode": 3, "static_addr": addr_helper.ctrl_static_addr, "dyn_addr": addr_helper.ctrl_dyn_addr, "virt_static_addr": 0x0, "virt_dyn_addr": 0x0}, # Mode 3 = ACT Controller
                {"idx": 2, "mode": 2, "static_addr": addr_helper.trgt_static_addr, "dyn_addr": addr_helper.trgt_dyn_addr, "virt_static_addr": addr_helper.trgt_virt_static_addr, "virt_dyn_addr": addr_helper.trgt_virt_dyn_addr}, # Mode 2 = ACT Target
            ]
        else:
            core_configs = [
                {"idx": 0, "mode": 2, "static_addr": 0x0, "dyn_addr": 0x0, "virt_static_addr": 0x0, "virt_dyn_addr": 0x0}, # Mode 2 = EXP Target (UNUSED)
                {"idx": 1, "mode": 3, "static_addr": addr_helper.ctrl_static_addr, "dyn_addr": addr_helper.ctrl_dyn_addr, "virt_static_addr": 0x0, "virt_dyn_addr": 0x0}, # Mode 3 = ACT Controller
                {"idx": 2, "mode": 2, "static_addr": addr_helper.trgt_static_addr, "dyn_addr": None, "virt_static_addr": addr_helper.trgt_virt_static_addr, "virt_dyn_addr": None}, # Mode 2 = ACT Target
            ]

    tasks = []
    for cfg in core_configs:
        t = cocotb.start_soon(
            boot_init(
                tb, 
                bus_idx=cfg["idx"], 
                mode=cfg["mode"], 
                static_addr=cfg["static_addr"],
                virtual_static_addr=cfg["virt_static_addr"],
                dynamic_addr=cfg["dyn_addr"],
                virtual_dynamic_addr=cfg["virt_dyn_addr"],
                verify=True
            )
        )
        tasks.append(t)

    await cocotb.triggers.Combine(*[t.join() for t in tasks])
    
    dut._log.info("All cores booted successfully.")
    return tb, i3c_target, addr_helper 

@cocotb.test()
async def test_controller_gen_hdr_exit_pattern(dut):

# //////////////////////////////////////////////////////////////
# //                          Setup                           //
# //////////////////////////////////////////////////////////////

    TX_QUEUE_DEPTH = 8
    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr


# //////////////////////////////////////////////////////////////
# // Send ICC to turn on CE2 error handling for regular NACKs //
# //////////////////////////////////////////////////////////////

    cmd_desc = internal_control_descriptor(tid=random.getrandbits(4), vip=False, mipi_cmd=0x5, mipi_rsvd=0x5, vendor_specific=0x0)
    dut._log.info("Sending Command Descriptor to activate CE2 error handling, by sending HDR Exit Pattern after NACK of Private read/write.")
    await tb.put_command_desc(cmd_desc.to_int(), bus_idx=ACT_CONTROLLER_IDX)

    await ClockCycles(tb.clk, 100)

# //////////////////////////////////////////////////////////////
# //         Send I3C private write to wrong address          //
# //////////////////////////////////////////////////////////////

    i3c_target_len = 3 # doesn't matter what it is 
    dut._log.info(f"I3C Target length is {i3c_target_len} bytes.")

    num_words = (i3c_target_len + 3) // 4
    # Setup

    data = [random.getrandbits(32) for _ in range(num_words)]
    # Masking the last word
    remainder = i3c_target_len % 4
    if remainder != 0:
        mask = (1 << (remainder * 8)) - 1
        data[-1] = data[-1] & mask

    unassigned_addr = addr_helper.get_unassigned_valid_address()
    dut._log.info(f"Starting I3C private write to address 0x{unassigned_addr:x} (expecting NACK)")
    await write_i3c(tb, addr_helper=addr_helper, payload=data, target_len=i3c_target_len, device_address=unassigned_addr, toc=True, expect_success=False, dat=False)


# //////////////////////////////////////////////////////////////
# //          Check if HDR Exit Pattern is detected           //
# //////////////////////////////////////////////////////////////

    try:
        irq_sig = tb.dut.irq_o[ACT_CONTROLLER_IDX]
    except (TypeError, IndexError):
        irq_sig = tb.dut.irq_o

    if irq_sig.value == 0:
        tb.dut._log.info("Waiting for interrupt indicating Transfer Error...")
        await RisingEdge(irq_sig)

    transfer_err_stat = await tb.read_csr_field(
        tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.base_addr, 
        tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.TRANSFER_ERR_STAT, 
        bus_idx=ACT_CONTROLLER_IDX
    )
    assert transfer_err_stat == 1, f"Expected PIO_INTR_STATUS.TRANSFER_ERR_STAT to be 1, got {transfer_err_stat}"
    tb.dut._log.info("Controller recorded the Transfer Error.")

    tb.dut._log.info("Waiting for the cocotbext i3c_target to see the HDR Exit pattern...")
    try:
        await cocotb.triggers.with_timeout(i3c_target.hdr_exit_detected.wait(), 1, 'us')
        tb.dut._log.info("Success! The cocotbext i3c_target confirmed the HDR Exit Pattern was driven on the bus.")
    except cocotb.result.SimTimeoutError:
        assert False, "Controller aborted, but the cocotbext i3c_target did NOT detect the HDR Exit Pattern on the bus!"

    i3c_target.hdr_exit_detected.clear()

    await ClockCycles(tb.clk, 100)

# //////////////////////////////////////////////////////////////
# //             Clear the HC_CONTROL.RESUME CSR              //
# //////////////////////////////////////////////////////////////

    hc_ctrl_addr = tb.reg_map.I3CBASE.HC_CONTROL.base_addr
    resume_field = tb.reg_map.I3CBASE.HC_CONTROL.RESUME

    # Read just the RESUME field
    resume_operation = await tb.read_csr_field(
        hc_ctrl_addr,
        resume_field,
        bus_idx=ACT_CONTROLLER_IDX
    )

    assert resume_operation == 1, f"HC_CONTROL.RESUME CSR Field is {hex(resume_operation)} after error condition, expected 1"
    
    dut._log.info("Clearing HC_CONTROL.RESUME to resume normal operation.")
    
    # The reg_map marks RESUME as 'woclr': 1 (Write-One-to-Clear). 
    # Write 1 directly to the field to clear the halt state.
    await tb.write_csr_field(
        hc_ctrl_addr,
        resume_field,
        1, 
        bus_idx=ACT_CONTROLLER_IDX
    )

    # Give the controller a few cycles to fully resume
    await ClockCycles(tb.clk, 20)


# //////////////////////////////////////////////////////////////
# //         Send I3C private write to valid address          //
# //////////////////////////////////////////////////////////////


    i3c_target_len = 9 # doesn't matter what it is 
    dut._log.info(f"I3C Target length is {i3c_target_len} bytes.")

    num_words = (i3c_target_len + 3) // 4
    # Setup

    data = [random.getrandbits(32) for _ in range(num_words)]
    # Masking the last word
    remainder = i3c_target_len % 4
    if remainder != 0:
        mask = (1 << (remainder * 8)) - 1
        data[-1] = data[-1] & mask

    dut._log.info(f"Starting correct I3C private write to address 0x{addr_helper.trgt_dyn_addr:x}")
    await write_i3c(tb, addr_helper=addr_helper, payload=data, target_len=i3c_target_len, device_address=addr_helper.trgt_dyn_addr, toc=True, expect_success=True)
