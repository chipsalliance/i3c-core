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
from common import *
from cocotb.triggers import ClockCycles, RisingEdge, Timer, Combine, Event
from utils import format_ibi_data

ACT_TARGET_IDX = 2 # Port idx of actual target
ACT_CONTROLLER_IDX = 0 # Port idx of actual controller
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

    tb = I3CTopControllerTestInterface(dut, num_busses=1)

    addr_helper = I3CAddressHelper(dut)
    dut._log.info("Generated random I3C addresses: ")
    addr_helper.print_addresses()

    # The target is listening to the I3C bus and will include assertions for the phy_sel_od_pp signal

    i3c_target = I3CTarget( 
        sda_i=dut.sda_o,
        sda_o=dut.sda_i,
        scl_i=dut.scl_o,
        scl_o=dut.scl_i,
        phy_sel_od_pp_i=dut.sel_od_pp_o,
        debug_state_o=dut.debug_state_target_i,
        speed=fbus * 1e6,
        #address=addr_helper.trgt_static_addr
    )

    await tb.setup(fclk)

    dut._log.info("Booting I3C Controller...")

    cfg = {"idx": 0, "mode": 3, "static_addr": addr_helper.ctrl_static_addr, "dyn_addr": addr_helper.ctrl_dyn_addr, "virt_static_addr": 0x0, "virt_dyn_addr": 0x0} # Controller
            

    boot = cocotb.start_soon(
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

    await boot
    
    dut._log.info("All cores booted successfully.")
    return tb, i3c_target, addr_helper 

async def write_ccc(tb, ccc, immediate=None, payload=None, data_length=0, device_address=0x50, toc=True, rnw=False, expect_error=False):
    # Disable all target events
    no_payload = False
    if immediate == None:
        immediate = random.getrandbits(1)
    if payload == None:
        no_payload = True
        payload = [0]
    if immediate or (no_payload and not rnw): 
        cmd_desc = immediate_transfer_descriptor_direct(
            tid=random.getrandbits(3),
            i2c=False,
            cmd=ccc,
            cp=True,
            device_address=device_address,
            dtt=data_length,
            mode=0,
            rnw=False,
            wroc=toc,
            toc=toc,  
            data=payload[0]
        )
    else:
        cmd_desc = regular_transfer_descriptor_direct(
        tid=random.getrandbits(3),
        i2c=0x0,
        cmd=ccc,
        cp=0x1,
        device_address=device_address,
        short_read_err=0x0,
        defining_byte_present=0x0,
        mode=0x0,
        rnw=int(rnw),
        wroc=toc,
        toc=toc,
        def_byte=0x0,
        data_length=data_length,
        )
        await tb.put_tx_data(payload, tx_queue_depth=TX_QUEUE_DEPTH, tx_thld=TX_READY_THLD, bus_idx=ACT_CONTROLLER_IDX)

    await tb.put_command_desc(cmd_desc.to_int(), bus_idx=ACT_CONTROLLER_IDX)
    # Wait for response Descriptor when it's the last cmd descriptor
    if toc and not expect_error:
        resp_desc = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
        #assert resp_desc.data_length == len(payload)
        assert resp_desc.tid == cmd_desc.tid
        assert resp_desc.err_status == ErrorStatus(0) # SUCCESS
        await ClockCycles(tb.clk, 500) # 500 Cycles stop

async def write_setdasa(tb, dyn_addr, static_addr, toc=True, device_index=None):
    await tb.put_dat_entry(device_index=device_index, dyn_addr=dyn_addr, static_addr=static_addr, is_i2c=False, bus_idx=ACT_CONTROLLER_IDX)
    cmd_desc = address_assignment_descriptor(
        tid=random.getrandbits(3),
        cmd=CCC.DIRECT.SETDASA,
        device_index=device_index,
        device_count=1,
        wroc=True,
        toc=toc
    )
    
    await tb.put_command_desc(cmd_desc.to_int(), bus_idx=ACT_CONTROLLER_IDX)
    # Wait for response Descriptor when it's the last cmd descriptor
    if toc:
        resp_desc = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
        #assert resp_desc.data_length == len(payload)
        assert resp_desc.tid == cmd_desc.tid
        assert resp_desc.err_status == ErrorStatus(0) # SUCCESS
        await ClockCycles(tb.clk, 500) # 500 Cycles stop

@cocotb.test()
async def test_controller_error_nack_on_bcast(dut):

# //////////////////////////////////////////////////////////////
# //                          Setup                           //
# //////////////////////////////////////////////////////////////

    tb, i3c_target, addr_helper = await test_setup(dut)
    device_index = random.getrandbits(5)
    DYNAMIC_ADDR = addr_helper.trgt_dyn_addr
    STATIC_ADDR = addr_helper.trgt_static_addr


# //////////////////////////////////////////////////////////////
# //                        SETDASA CCC                       //
# //////////////////////////////////////////////////////////////

    i3c_target.address = STATIC_ADDR
    dut._log.info("Starting SETDASA" )
    await write_setdasa(tb, dyn_addr=DYNAMIC_ADDR, static_addr=STATIC_ADDR, toc=True, device_index=device_index)
    dut._log.info("Finished SETDASA" )

# //////////////////////////////////////////////////////////////
# //       ENEC CCC (NACK on BCAST Header by target)          //
# //////////////////////////////////////////////////////////////

    i3c_target.errors.nack_bcast = True

    dut._log.info("Writing ENEC CCC and expecting the target to NACK I3C BCAST Header")
    _EVENT_TOGGLE_BYTE = 0b00001011
    await write_ccc(tb, CCC.BCAST.ENEC, data_length=1, payload=[_EVENT_TOGGLE_BYTE], device_address=addr_helper.trgt_dyn_addr, toc=True, immediate=False, rnw=True, expect_error=True)

# //////////////////////////////////////////////////////////////
# //            Check if HDR Exit Pattern is sent             //
# //////////////////////////////////////////////////////////////
    tb.dut._log.info("Polling for PIO_INTR_STATUS.TRANSFER_ERR_STAT...")
    
    transfer_err_stat = 0
    timeout_loops = 100
    
    # Poll the CSR instead of relying on the shared irq_o line
    for _ in range(timeout_loops):
        transfer_err_stat = await tb.read_csr_field(
            tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.base_addr, 
            tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.TRANSFER_ERR_STAT, 
            bus_idx=ACT_CONTROLLER_IDX
        )
        
        if transfer_err_stat == 1:
            break # We found the error, break out of the waiting loop!
            
        # Yield to the simulator to let time pass before checking again
        await ClockCycles(tb.clk, 10) 

    assert transfer_err_stat == 1, "Timed out waiting for PIO_INTR_STATUS.TRANSFER_ERR_STAT to become 1!"
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
    
    dut._log.info("Clearing HC_CONTROL.RESUME and PIO_INTR_STATUS.TRANSFER_ERR_STAT to resume normal operation.")
    
    # The reg_map marks RESUME as 'woclr': 1 (Write-One-to-Clear). 
    # Write 1 directly to the field to clear the halt state.
    await tb.write_csr_field(
        hc_ctrl_addr,
        resume_field,
        1, 
        bus_idx=ACT_CONTROLLER_IDX
    )

    await tb.write_csr_field(
        tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.base_addr,
        tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.TRANSFER_ERR_STAT,
        1,
        bus_idx=ACT_CONTROLLER_IDX
    )

    # Give the controller a few cycles to fully resume
    await ClockCycles(tb.clk, 20)

    i3c_target.errors.clear_all()


# //////////////////////////////////////////////////////////////
# //                        ENEC CCC                          //
# //////////////////////////////////////////////////////////////

    dut._log.info("Writing ENEC CCC")
    await write_ccc(tb, CCC.BCAST.ENEC, data_length=1, payload=[_EVENT_TOGGLE_BYTE], device_address=addr_helper.trgt_dyn_addr, toc=True, immediate=False, rnw=True, expect_error=True)
    dut._log.info("Done Sending ENEC")

    # Wait for ENEC to be sent on the bus
    await ClockCycles(tb.clk, 5000)

    transfer_err_stat = await tb.read_csr_field(
            tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.base_addr, 
            tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.TRANSFER_ERR_STAT, 
            bus_idx=ACT_CONTROLLER_IDX
        )
        
    assert transfer_err_stat == 0, "Unexpected Error Occured"

