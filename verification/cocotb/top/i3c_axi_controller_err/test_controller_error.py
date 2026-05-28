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
from cocotb.triggers import ClockCycles, RisingEdge, Timer, Combine, Event, ReadOnly
from utils import format_ibi_data

ACT_TARGET_IDX = 2 # Port idx of actual target
ACT_CONTROLLER_IDX = 0 # Port idx of actual controller
TX_QUEUE_DEPTH = 64 # Depth of TX_QUEUE in dwords.
RX_QUEUE_DEPTH = 64 # Depth of RX_QUEUE in dwords.
TX_READY_THLD = 0x1 # tx ready threshold
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
        max_read_length=4096
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

async def write_ccc(tb, ccc, immediate=None, payload=None, data_length=0, device_address=0x50, toc=True, rnw=False, expect_error=None):
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
    if toc:
        resp_desc = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
        assert resp_desc.tid == cmd_desc.tid
        if not expect_error:
            assert resp_desc.err_status == ErrorStatus(0) # SUCCESS
        else:
            assert resp_desc.err_status == expect_error
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


async def write_i3c(tb, addr_helper, payload, target_len, i3c_target=None, immediate=None, device_address=0x50, toc=True, dat=None, device_index=None, expect_error=None, bus_idx=ACT_CONTROLLER_IDX):
    # Disable all target events
    if dat == None:
        dat = random.getrandbits(1)
        if device_index == None:
            device_index = random.getrandbits(5)
    if immediate == None:
        immediate = random.getrandbits(1)

    if dat:
        await tb.put_dat_entry(device_index=device_index, dyn_addr=addr_helper.trgt_dyn_addr, static_addr=addr_helper.trgt_static_addr, is_i2c=False, bus_idx=bus_idx)

    if immediate and len(payload) == 1:
        if dat:
            cmd_desc = immediate_transfer_descriptor(
                tid=random.getrandbits(3),
                cmd=0x0,
                cp=False,
                device_index=device_index,
                byte_count=target_len,
                mode=0,
                rnw=False,
                wroc=0x1,
                toc=toc,  
                data=payload[0]
        )
        else:
            cmd_desc = immediate_transfer_descriptor_direct(
                tid=random.getrandbits(3),
                i2c=False,
                cmd=0x0,
                cp=False,
                device_address=device_address,
                dtt=target_len,
                mode=0,
                rnw=False,
                wroc=0x1,
                toc=toc,  
                data=payload[0]
            )
        await tb.put_command_desc(cmd_desc.to_int(), bus_idx=bus_idx)
    else:
        if dat: 
            cmd_desc = regular_transfer_descriptor(
            tid=random.getrandbits(3),
            cmd=0x0,
            cp=0x0,
            device_index=device_index,
            short_read_err=0x0,
            defining_byte_present=0x0,
            mode=0x0,
            rnw=0x0,
            wroc=True,
            toc=toc,
            def_byte=0x0,
            data_length=target_len,
            )
        else:
            cmd_desc = regular_transfer_descriptor_direct(
            tid=random.getrandbits(3),
            i2c=0x0,
            cmd=0x0,
            cp=0x0,
            device_address=device_address,
            short_read_err=0x0,
            defining_byte_present=0x0,
            mode=0x0,
            rnw=0x0,
            wroc=True,
            toc=toc,
            def_byte=0x0,
            data_length=target_len,
            )
        queue_filled_event = Event()
        data_write = cocotb.start_soon(tb.put_tx_data(payload, ready_event=queue_filled_event, tx_thld=TX_READY_THLD, bus_idx=bus_idx))
        await queue_filled_event.wait()
        await tb.put_command_desc(cmd_desc.to_int(), bus_idx=bus_idx)
        await data_write

    # Wait for response Descriptor when it's the last cmd descriptor
    resp_desc = await tb.read_resp_desc(bus_idx=bus_idx)
    assert resp_desc.tid == cmd_desc.tid
    if not expect_error:
        assert resp_desc.err_status == ErrorStatus.SUCCESS
        assert resp_desc.data_length == target_len
    else:
        assert resp_desc.err_status == expect_error

    await ClockCycles(tb.clk, 100)

    if i3c_target is not None:
        received_len = i3c_target._mem.len
        
        actual_bytes = i3c_target._mem.read(received_len)
        i3c_target._mem.clear()
        
        expected_bytes = []
        for word in payload:
            expected_bytes.extend(word.to_bytes(4, byteorder='little'))
            
        if not expect_error:
            assert received_len == target_len, f"Expected {target_len} bytes, but VIP received {received_len}!"
            expected_bytes = list(expected_bytes[:target_len])
        else:
            tb.dut._log.info(f"Underflow check: Target successfully received {received_len} bytes before the abort.")
            expected_bytes = list(expected_bytes[:received_len])
            
        for i, (expected, actual) in enumerate(zip(expected_bytes, actual_bytes)):
            if expected != actual:
                tb.dut._log.error(f"Mismatch at byte {i}: Expected 0x{expected:02x} vs Received 0x{actual:02x}")
                
        assert expected_bytes == actual_bytes, "Data mismatch between TX payload and Target VIP Memory!"

async def read_i3c(tb, addr_helper, target_len, i3c_target=None, device_address=0x50, toc=True, dat=None, device_index=None, expected_error=None, bus_idx=ACT_CONTROLLER_IDX):
    if dat == None:
        dat = random.getrandbits(1)
        if device_index == None:
            device_index = random.getrandbits(5)

    if dat:
        await tb.put_dat_entry(device_index=device_index, dyn_addr=addr_helper.trgt_dyn_addr, static_addr=addr_helper.trgt_static_addr, is_i2c=False, bus_idx=bus_idx)
        cmd_desc = regular_transfer_descriptor(
            tid=random.getrandbits(3),
            cmd=0x0,
            cp=0x0,
            device_index=device_index,
            short_read_err=0x1,
            defining_byte_present=0x0,
            mode=0x0,
            rnw=0x1,
            wroc=True,
            toc=toc,
            def_byte=0x0,
            data_length=target_len,
        )
    else:
        cmd_desc = regular_transfer_descriptor_direct(
            tid=random.getrandbits(3),
            i2c=0x0,
            cmd=0x0,
            cp=0x0,
            device_address=device_address,
            short_read_err=0x1,
            defining_byte_present=0x0,
            mode=0x0,
            rnw=0x1,
            wroc=True,
            toc=toc,
            def_byte=0x0,
            data_length=target_len,
        )

    # //////////////////////////////////////////////////////////////
    # //               Load Data into Target VIP                  //
    # //////////////////////////////////////////////////////////////
    expected_bytes = [random.getrandbits(8) for _ in range(target_len)]
    
    if i3c_target is not None:
        i3c_target._mem.clear()
        i3c_target._mem.write(expected_bytes, target_len)
        tb.dut._log.info(f"Loaded {target_len} bytes into VIP memory for reading.")

    tb.dut._log.info("Sending Command Descriptor for I3C private read")
    await tb.put_command_desc(cmd_desc.to_int(), bus_idx=bus_idx)

    resp_desc = await tb.read_resp_desc(bus_idx=bus_idx)
    if expected_error is not None:
        assert resp_desc.tid == cmd_desc.tid
        assert resp_desc.err_status == expected_error, f"Expected {expected_error}, got {resp_desc.err_status}"
        return  # End execution here for error cases

    assert resp_desc.tid == cmd_desc.tid
    assert resp_desc.err_status == ErrorStatus.SUCCESS, f"Expected SUCCESS, got {resp_desc.err_status}"
    assert resp_desc.data_length == target_len

    tb.dut._log.info("Reading RX Queue...")
    num_words = (target_len + 3) // 4
    
    ctrl_rx_queue_addr = tb.reg_map.PIOCONTROL.RX_DATA_PORT.base_addr
    rx_data_words = await tb.read_rx_queue(num_words, bus_idx=bus_idx, rx_port_addr=ctrl_rx_queue_addr)

    actual_bytes = []
    for word in rx_data_words:
        actual_bytes.extend(word.to_bytes(4, byteorder='little'))
        
    actual_bytes = list(actual_bytes[:target_len])
    
    for i, (expected, actual) in enumerate(zip(expected_bytes, actual_bytes)):
        if expected != actual:
            tb.dut._log.error(f"Mismatch at byte {i}: Expected 0x{expected:02x} vs Received 0x{actual:02x}")
            
    assert expected_bytes == actual_bytes, "RX Data mismatch!"
    tb.dut._log.info("Finished reading and verifying RX Queue.")


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
    await write_ccc(tb, CCC.BCAST.ENEC, data_length=1, payload=[_EVENT_TOGGLE_BYTE], device_address=addr_helper.trgt_dyn_addr, toc=True, immediate=False, rnw=True, expect_error=ErrorStatus.ADDRESS_HEADER)

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
    await write_ccc(tb, CCC.BCAST.ENEC, data_length=1, payload=[_EVENT_TOGGLE_BYTE], device_address=addr_helper.trgt_dyn_addr, toc=True, immediate=False, rnw=True)
    dut._log.info("Done Sending ENEC")

    # Wait for ENEC to be sent on the bus
    await ClockCycles(tb.clk, 5000)

    transfer_err_stat = await tb.read_csr_field(
            tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.base_addr, 
            tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.TRANSFER_ERR_STAT, 
            bus_idx=ACT_CONTROLLER_IDX
        )
        
    assert transfer_err_stat == 0, "Unexpected Error Occured"

@cocotb.test()
async def test_controller_tx_queue_underflow(dut):

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
# //                Produce TX Queue Underflow                //
# //////////////////////////////////////////////////////////////

    i3c_target_len = random.randint(1, TX_QUEUE_DEPTH * 4 * 2)
    dut._log.info(f"I3C Target length is {i3c_target_len} bytes.")
    actual_len = random.randint(0, i3c_target_len-4) # there needs to be at least one DWORD difference in length to hit the TX Queue underflow condition
    dut._log.info(f"Writing 0x{actual_len:x} bytes to the i3c target to provoke TX Queue Underflow error.")

    num_words = (actual_len + 3) // 4
    # Setup

    data = [random.getrandbits(32) for _ in range(num_words)]
    # Masking the last word
    remainder = actual_len % 4
    if remainder != 0:
        mask = (1 << (remainder * 8)) - 1
        data[-1] = data[-1] & mask


    tb.dut._log.info("Starting I3C private write")
    await write_i3c(tb, addr_helper=addr_helper, payload=data, target_len=i3c_target_len, device_address=addr_helper.trgt_dyn_addr, toc=True, device_index=device_index, expect_error=ErrorStatus.OVL, immediate=False, bus_idx=ACT_CONTROLLER_IDX)


# //////////////////////////////////////////////////////////////
# //                       Handle Error                       //
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


# //////////////////////////////////////////////////////////////
# //                        I3C Write                         //
# //////////////////////////////////////////////////////////////

    i3c_target_len = random.randint(4, TX_QUEUE_DEPTH * 4 * 2)
    dut._log.info(f"I3C Target length is {i3c_target_len} bytes.")

    num_words = (i3c_target_len + 3) // 4
    # Setup

    data = [random.getrandbits(32) for _ in range(num_words)]
    # Masking the last word
    remainder = i3c_target_len % 4
    if remainder != 0:
        mask = (1 << (remainder * 8)) - 1
        data[-1] = data[-1] & mask


    tb.dut._log.info("Starting I3C private write")
    await write_i3c(tb, addr_helper=addr_helper, payload=data, target_len=i3c_target_len, device_address=addr_helper.trgt_dyn_addr, toc=True, device_index=device_index, bus_idx=ACT_CONTROLLER_IDX)

@cocotb.test()
async def test_controller_rx_queue_overflow(dut):

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
# //                Produce RX Queue Overflow                 //
# //////////////////////////////////////////////////////////////

    i3c_target_len = random.randint(((RX_QUEUE_DEPTH + 1) * 4), RX_QUEUE_DEPTH * 4 * 2) # one DWORD is internaly buffered. So the total capacity is in fact RX_QUEUE_DEPTH + 1 DWORDs
    dut._log.info(f"I3C Target length is {i3c_target_len} bytes.")

    tb.dut._log.info("Starting I3C private read")
    await read_i3c(tb, addr_helper=addr_helper, target_len=i3c_target_len, i3c_target=i3c_target, device_address=addr_helper.trgt_dyn_addr, toc=True, dat=None, device_index=device_index, expected_error=ErrorStatus.OVL)
    dut._log.info("Finished I3C private read")

# //////////////////////////////////////////////////////////////
# //                       Handle Error                       //
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

    tb.dut._log.info("Flushing RX FIFO...")
    await tb.write_csr_field(
        tb.reg_map.I3CBASE.RESET_CONTROL.base_addr,
        tb.reg_map.I3CBASE.RESET_CONTROL.RX_FIFO_RST,
        1,
        bus_idx=ACT_CONTROLLER_IDX
    )

    # Give the hardware a few clock cycles to complete the synchronous reset
    await ClockCycles(tb.clk, 20)
    
    dut._log.info("Clearing HC_CONTROL.RESUME and PIO_INTR_STATUS.TRANSFER_ERR_STAT to resume normal operation.")
    
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
    await ClockCycles(tb.clk, 2000)


# //////////////////////////////////////////////////////////////
# //                        I3C Read                          //
# //////////////////////////////////////////////////////////////

    i3c_target_len = random.randint(1, RX_QUEUE_DEPTH * 4)
    dut._log.info(f"I3C Target length is {i3c_target_len} bytes.")

    tb.dut._log.info("Starting I3C private read")
    await read_i3c(tb, addr_helper=addr_helper, target_len=i3c_target_len, i3c_target=i3c_target, device_address=addr_helper.trgt_dyn_addr, toc=True, dat=None, device_index=device_index)
    dut._log.info("Finished I3C private read")

@cocotb.test()
async def test_controller_error_short_ccc_ce0(dut):

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
    dut._log.info("Starting SETDASA")
    await write_setdasa(tb, dyn_addr=DYNAMIC_ADDR, static_addr=STATIC_ADDR, toc=True, device_index=device_index)
    dut._log.info("Finished SETDASA")

# //////////////////////////////////////////////////////////////
# //      GETPID  CCC (Short PID + Controller recovers)       //
# //////////////////////////////////////////////////////////////
    
    # 1. Inject the error and enable recovery on the next attempt
    i3c_target.errors.ce0_getpid = True
    i3c_target.errors.controller_recovery_enable = True

    tb.dut._log.info("Sending GETPID CCC (Expecting CE0 controller recovery)")
    await write_ccc(
        tb, 
        CCC.DIRECT.GETPID, 
        data_length=6, 
        device_address=addr_helper.trgt_dyn_addr, 
        toc=True, 
        immediate=False, 
        rnw=True, 
        expect_error=None # If target autorecovers we don't expect an error
    )
    tb.dut._log.info("Controller successfully recovered and read the full PID.")

# //////////////////////////////////////////////////////////////
# //   GETPID  CCC (Short PID + Controller doesn't recover)   //
# //////////////////////////////////////////////////////////////
    
    # 1. Re-enable the error but DISABLE recovery (it will fail permanently)
    i3c_target.errors.clear_all()
    i3c_target.errors.ce0_getpid = True
    i3c_target.errors.controller_recovery_enable = False

    tb.dut._log.info("Sending GETPID CCC (Expecting CE0 Short Read Error)")
    await write_ccc(
        tb, 
        CCC.DIRECT.GETPID, 
        data_length=6, 
        device_address=addr_helper.trgt_dyn_addr, 
        toc=True, 
        immediate=False, 
        rnw=True, 
        expect_error=ErrorStatus.I3C_SHORT_READ
    )

    # --- Handle the Error ---
    hc_ctrl_addr = tb.reg_map.I3CBASE.HC_CONTROL.base_addr
    resume_field = tb.reg_map.I3CBASE.HC_CONTROL.RESUME

    transfer_err_stat = 0
    for _ in range(100):
        transfer_err_stat = await tb.read_csr_field(
            tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.base_addr, 
            tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.TRANSFER_ERR_STAT, 
            bus_idx=ACT_CONTROLLER_IDX
        )
        if transfer_err_stat == 1:
            break 
        await ClockCycles(tb.clk, 10) 

    assert transfer_err_stat == 1, "Timed out waiting for TRANSFER_ERR_STAT to become 1!"
    await tb.write_csr_field(hc_ctrl_addr, resume_field, 1, bus_idx=ACT_CONTROLLER_IDX)
    await tb.write_csr_field(
        tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.base_addr,
        tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.TRANSFER_ERR_STAT,
        1,
        bus_idx=ACT_CONTROLLER_IDX
    )

    await ClockCycles(tb.clk, 2000)


# //////////////////////////////////////////////////////////////
# //                  GETPID without errors                   //
# //////////////////////////////////////////////////////////////


    # Clear all error states from the VIP so it behaves normally again
    i3c_target.errors.clear_all()

    tb.dut._log.info("Sending GETPID CCC (Expecting no Error)")
    await write_ccc(
        tb, 
        CCC.DIRECT.GETPID, 
        data_length=6, 
        device_address=addr_helper.trgt_dyn_addr, 
        toc=True, 
        immediate=False, 
        rnw=True, 
        expect_error=None
    )

# //////////////////////////////////////////////////////////////
# //                     Private Write                        //
# //////////////////////////////////////////////////////////////

    i3c_target_len = random.randint(4, TX_QUEUE_DEPTH * 4)
    dut._log.info(f"I3C Target length is {i3c_target_len} bytes.")

    num_words = (i3c_target_len + 3) // 4
    data = [random.getrandbits(32) for _ in range(num_words)]
    remainder = i3c_target_len % 4
    if remainder != 0:
        mask = (1 << (remainder * 8)) - 1
        data[-1] = data[-1] & mask

    tb.dut._log.info("Starting successful I3C private write to verify bus recovery")
    await write_i3c(
        tb, 
        addr_helper=addr_helper, 
        payload=data, 
        target_len=i3c_target_len, 
        device_address=addr_helper.trgt_dyn_addr, 
        toc=True, 
        device_index=device_index, 
        bus_idx=ACT_CONTROLLER_IDX
    )
    tb.dut._log.info("Private write successful! Test complete.")

@cocotb.test()
async def test_hc_abort(dut):

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
    dut._log.info("Starting SETDASA")
    await write_setdasa(tb, dyn_addr=DYNAMIC_ADDR, static_addr=STATIC_ADDR, toc=True, device_index=device_index)
    dut._log.info("Finished SETDASA")


# //////////////////////////////////////////////////////////////
# //                Set PIO_CONTROL.RS to 1'b0                //
# //////////////////////////////////////////////////////////////

    tb.dut._log.info("Disabling PIO queue processing (RS=0) to buffer descriptors")
    await tb.write_csr_field(
        tb.reg_map.PIOCONTROL.PIO_CONTROL.base_addr,
        tb.reg_map.PIOCONTROL.PIO_CONTROL.RS,
        0,
        bus_idx=ACT_CONTROLLER_IDX
    )


# //////////////////////////////////////////////////////////////
# //              Enqueue 2 Private Write CMD Desc            //
# //////////////////////////////////////////////////////////////

    i3c_target_len_1 = 16 
    i3c_target_len_2 = 32

    # Payload 1
    num_words_1 = (i3c_target_len_1 + 3) // 4
    data_1 = [random.getrandbits(32) for _ in range(num_words_1)]
    cmd_desc_1 = regular_transfer_descriptor_direct(
        tid=1, i2c=0x0, cmd=0x0, cp=0x0, device_address=DYNAMIC_ADDR,
        short_read_err=0x0, defining_byte_present=0x0, mode=0x0,
        rnw=0x0, wroc=True, toc=True, def_byte=0x0, data_length=i3c_target_len_1
    )

    # Payload 2
    num_words_2 = (i3c_target_len_2 + 3) // 4
    data_2 = [random.getrandbits(32) for _ in range(num_words_2)]
    cmd_desc_2 = regular_transfer_descriptor_direct(
        tid=2, i2c=0x0, cmd=0x0, cp=0x0, device_address=DYNAMIC_ADDR,
        short_read_err=0x0, defining_byte_present=0x0, mode=0x0,
        rnw=0x0, wroc=True, toc=True, def_byte=0x0, data_length=i3c_target_len_2
    )

    tb.dut._log.info("Pushing Descriptor 1 to TX/CMD queues")
    await tb.put_tx_data(data_1, tx_queue_depth=TX_QUEUE_DEPTH, tx_thld=TX_READY_THLD, bus_idx=ACT_CONTROLLER_IDX)
    await tb.put_command_desc(cmd_desc_1.to_int(), bus_idx=ACT_CONTROLLER_IDX)

    tb.dut._log.info("Pushing Descriptor 2 to TX/CMD queues")
    await tb.put_tx_data(data_2, tx_queue_depth=TX_QUEUE_DEPTH, tx_thld=TX_READY_THLD, bus_idx=ACT_CONTROLLER_IDX)
    await tb.put_command_desc(cmd_desc_2.to_int(), bus_idx=ACT_CONTROLLER_IDX)


# //////////////////////////////////////////////////////////////
# //      Set PIO_CONTROL.RS to 1'b1 to start operation       //
# //////////////////////////////////////////////////////////////

    tb.dut._log.info("Enabling PIO queue processing (RS=1) to start transactions")
    await tb.write_csr_field(
        tb.reg_map.PIOCONTROL.PIO_CONTROL.base_addr,
        tb.reg_map.PIOCONTROL.PIO_CONTROL.RS,
        1,
        bus_idx=ACT_CONTROLLER_IDX
    )

    # Give the hardware a moment to pull the first descriptor and begin driving the bus
    await ClockCycles(tb.clk, 1000)


# //////////////////////////////////////////////////////////////
# //Set HC_CONTROL.ABORT to 1'b1 to abort current transaction //
# //////////////////////////////////////////////////////////////

    tb.dut._log.info("Triggering abort via HC_CONTROL.ABORT = 1")
    await tb.write_csr_field(
        tb.reg_map.I3CBASE.HC_CONTROL.base_addr,
        tb.reg_map.I3CBASE.HC_CONTROL.ABORT,
        1,
        bus_idx=ACT_CONTROLLER_IDX
    )

    await ClockCycles(tb.clk, 500)


# //////////////////////////////////////////////////////////////
# //               Read  HC_ABORTED err status                //
# //////////////////////////////////////////////////////////////

    tb.dut._log.info("Polling for PIO_INTR_STATUS.TRANSFER_ABORT_STAT...")
    abort_stat = 0
    for _ in range(150):
        abort_stat = await tb.read_csr_field(
            tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.base_addr, 
            tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.TRANSFER_ABORT_STAT, 
            bus_idx=ACT_CONTROLLER_IDX
        )
        if abort_stat == 1:
            break 
        await ClockCycles(tb.clk, 10) 

    assert abort_stat == 1, "Timed out waiting for TRANSFER_ABORT_STAT to become 1!"
    tb.dut._log.info("Controller recorded the Abort Interrupt.")

    # Read the Response Descriptor for the aborted transaction (TID 1)
    resp_desc_1 = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
    assert resp_desc_1.tid == cmd_desc_1.tid, f"Expected TID {cmd_desc_1.tid}, got {resp_desc_1.tid}"
    assert resp_desc_1.err_status == ErrorStatus.HC_ABORTED, f"Expected HC_ABORTED, got {resp_desc_1.err_status}"
    tb.dut._log.info("Successfully read ABORTED status from response descriptor 1")


# //////////////////////////////////////////////////////////////
# //  Set HC_CONTROL.ABORT and PIO_CONTROL.ABORT to 1'b0 to   //
# //                     resume operation                     //
# //////////////////////////////////////////////////////////////

    tb.dut._log.info("Clearing ABORT flags and resuming operation...")
    
    # Clear HC_CONTROL.ABORT
    await tb.write_csr_field(
        tb.reg_map.I3CBASE.HC_CONTROL.base_addr,
        tb.reg_map.I3CBASE.HC_CONTROL.ABORT,
        0,
        bus_idx=ACT_CONTROLLER_IDX
    )
    
    # Clear PIO_CONTROL.ABORT
    await tb.write_csr_field(
        tb.reg_map.PIOCONTROL.PIO_CONTROL.base_addr,
        tb.reg_map.PIOCONTROL.PIO_CONTROL.ABORT,
        0,
        bus_idx=ACT_CONTROLLER_IDX
    )
    
    # W1C the TRANSFER_ABORT_STAT interrupt flag
    await tb.write_csr_field(
        tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.base_addr,
        tb.reg_map.PIOCONTROL.PIO_INTR_STATUS.TRANSFER_ABORT_STAT,
        1,
        bus_idx=ACT_CONTROLLER_IDX
    )

    hc_ctrl_addr = tb.reg_map.I3CBASE.HC_CONTROL.base_addr
    resume_field = tb.reg_map.I3CBASE.HC_CONTROL.RESUME

    await tb.write_csr_field(
        hc_ctrl_addr,
        resume_field,
        1, 
        bus_idx=ACT_CONTROLLER_IDX
    )

    tb.dut._log.info("Flushing TX FIFO...")
    await tb.write_csr_field(
        tb.reg_map.I3CBASE.RESET_CONTROL.base_addr,
        tb.reg_map.I3CBASE.RESET_CONTROL.TX_FIFO_RST,
        1,
        bus_idx=ACT_CONTROLLER_IDX
    )


    # Allow the controller time to un-halt and process the 2nd queued descriptor
    await ClockCycles(tb.clk, 100)


# //////////////////////////////////////////////////////////////
# //        2nd private write should perform successfully     //
# //////////////////////////////////////////////////////////////

    tb.dut._log.info("Pushing Data 2 to TX queue")
    await tb.put_tx_data(data_2, tx_queue_depth=TX_QUEUE_DEPTH, tx_thld=TX_READY_THLD, bus_idx=ACT_CONTROLLER_IDX)

    tb.dut._log.info("Waiting for completion of the 2nd Private Write...")
    
    # Wait for the response descriptor for the second command
    resp_desc_2 = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
    
    assert resp_desc_2.tid == cmd_desc_2.tid, f"Expected TID {cmd_desc_2.tid}, got {resp_desc_2.tid}"
    assert resp_desc_2.err_status == ErrorStatus.SUCCESS, f"Expected SUCCESS for cmd 2, got {resp_desc_2.err_status}"
    assert resp_desc_2.data_length == i3c_target_len_2, f"Expected length {i3c_target_len_2}, got {resp_desc_2.data_length}"
    
    await ClockCycles(tb.clk, 100)

    # Verify data arrived successfully at the target
    received_len = i3c_target._mem.len
    actual_bytes = i3c_target._mem.read(received_len)
    
    expected_bytes = []
    for word in data_2:
        expected_bytes.extend(word.to_bytes(4, byteorder='little'))
    
    # Target may hold garbage from the aborted transfer; we only care that the final `i3c_target_len_2` bytes match cmd 2
    # So we slice the expected bytes to length and compare to the END of the target's buffer
    expected_bytes = list(expected_bytes[:i3c_target_len_2])
    actual_bytes = actual_bytes[-i3c_target_len_2:]
    
    for i, (expected, actual) in enumerate(zip(expected_bytes, actual_bytes)):
        if expected != actual:
            tb.dut._log.error(f"Mismatch at byte {i}: Expected 0x{expected:02x} vs Received 0x{actual:02x}")
            
    assert expected_bytes == actual_bytes, "Data mismatch on the 2nd Private Write!"
    
    tb.dut._log.info("2nd Private Write performed successfully after resume. Test complete.")

@cocotb.test()
async def test_cmd_seq_timeout_no_halt(dut):

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
    dut._log.info("Starting SETDASA")
    await write_setdasa(tb, dyn_addr=DYNAMIC_ADDR, static_addr=STATIC_ADDR, toc=True, device_index=device_index)
    dut._log.info("Finished SETDASA")

# //////////////////////////////////////////////////////////////
# //      Set HC_CONTROL.HALT_ON_CMD_SEQ_TIMEOUT to 1'b0      //
# //////////////////////////////////////////////////////////////

    hc_ctrl_addr = tb.reg_map.I3CBASE.HC_CONTROL.base_addr
    halt_field = tb.reg_map.I3CBASE.HC_CONTROL.HALT_ON_CMD_SEQ_TIMEOUT

    dut._log.info("Setting HALT_ON_CMD_SEQ_TIMEOUT to 0 (Auto-Resume Enabled)")
    await tb.write_csr_field(hc_ctrl_addr, halt_field, 0, bus_idx=ACT_CONTROLLER_IDX)

# //////////////////////////////////////////////////////////////
# //               Private I3C Write (TOC=1'b0)               //
# //////////////////////////////////////////////////////////////

    i3c_target_len = random.randint(1, TX_QUEUE_DEPTH)
    dut._log.info(f"I3C Target length is {i3c_target_len} bytes.")

    num_words = (i3c_target_len + 3) // 4
    # Setup

    data = [random.getrandbits(32) for _ in range(num_words)]
    # Masking the last word
    remainder = i3c_target_len % 4
    if remainder != 0:
        mask = (1 << (remainder * 8)) - 1
        data[-1] = data[-1] & mask


    tb.dut._log.info("Starting I3C private write")
    await write_i3c(tb, addr_helper=addr_helper, payload=data, target_len=i3c_target_len, device_address=addr_helper.trgt_dyn_addr, toc=False, device_index=device_index, bus_idx=ACT_CONTROLLER_IDX)
    i3c_target._mem.clear()
    
    dut._log.info("Command 1 completed successfully.")

# //////////////////////////////////////////////////////////////
# //     Poll INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT and     //
# //              INTR_STATUS.HC_SEQ_CANCEL_STAT              //
# //////////////////////////////////////////////////////////////

    intr_status_addr = tb.reg_map.I3CBASE.INTR_STATUS.base_addr
    timeout_field = tb.reg_map.I3CBASE.INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT
    cancel_field = tb.reg_map.I3CBASE.INTR_STATUS.HC_SEQ_CANCEL_STAT

    timeout_stat = 0
    cancel_stat = 0
    
    dut._log.info("Polling for CMD SEQ Timeout & HC_SEQ_CANCEL Interrupt...")
    for _ in range(150):
        timeout_stat = await tb.read_csr_field(intr_status_addr, timeout_field, bus_idx=ACT_CONTROLLER_IDX)
        cancel_stat = await tb.read_csr_field(intr_status_addr, cancel_field, bus_idx=ACT_CONTROLLER_IDX)
        if timeout_stat == 1 and cancel_stat == 1:
            break
        await ClockCycles(tb.clk, 10)

    assert timeout_stat == 1, "Timed out waiting for HC_ERR_CMD_SEQ_TIMEOUT_STAT!"
    assert cancel_stat == 1, "Timed out waiting for HC_SEQ_CANCEL_STAT!"

    # Verify that the hardware did NOT halt itself
    resume_val = await tb.read_csr_field(hc_ctrl_addr, tb.reg_map.I3CBASE.HC_CONTROL.RESUME, bus_idx=ACT_CONTROLLER_IDX)
    assert resume_val == 0, "Hardware halted unexpectedly when HALT_ON_CMD_SEQ_TIMEOUT=0!"

# //////////////////////////////////////////////////////////////
# //               Private I3C Write (TOC=1'b1)               //
# //////////////////////////////////////////////////////////////

    payload_2 = [0x55667788]
    i3c_target_len_2 = 4
    
    dut._log.info("Sending next Private I3C Write with TOC=1 to verify auto-resume")
    await write_i3c(
        tb, addr_helper=addr_helper, payload=payload_2, target_len=i3c_target_len_2, 
        i3c_target=i3c_target, device_address=DYNAMIC_ADDR, toc=True, dat=False, 
        expect_error=None, bus_idx=ACT_CONTROLLER_IDX
    )
    i3c_target._mem.clear()
    
    dut._log.info("Command 2 processed successfully. Auto-resume verified.")

# //////////////////////////////////////////////////////////////
# //                    Resolve Interrupt                     //
# //////////////////////////////////////////////////////////////

    dut._log.info("Clearing Timeout Interrupts")
    await tb.write_csr_field(intr_status_addr, timeout_field, 1, bus_idx=ACT_CONTROLLER_IDX)
    await tb.write_csr_field(intr_status_addr, cancel_field, 1, bus_idx=ACT_CONTROLLER_IDX)
        
    await ClockCycles(tb.clk, 50)


@cocotb.test()
async def test_cmd_seq_timeout_halt(dut):

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
    dut._log.info("Starting SETDASA")
    await write_setdasa(tb, dyn_addr=DYNAMIC_ADDR, static_addr=STATIC_ADDR, toc=True, device_index=device_index)
    dut._log.info("Finished SETDASA")

# //////////////////////////////////////////////////////////////
# //      Set HC_CONTROL.HALT_ON_CMD_SEQ_TIMEOUT to 1'b1      //
# //////////////////////////////////////////////////////////////

    hc_ctrl_addr = tb.reg_map.I3CBASE.HC_CONTROL.base_addr
    halt_field = tb.reg_map.I3CBASE.HC_CONTROL.HALT_ON_CMD_SEQ_TIMEOUT

    dut._log.info("Setting HALT_ON_CMD_SEQ_TIMEOUT to 1 (Halt Enabled)")
    await tb.write_csr_field(hc_ctrl_addr, halt_field, 1, bus_idx=ACT_CONTROLLER_IDX)

# //////////////////////////////////////////////////////////////
# //               Private I3C Write (TOC=1'b0)               //
# //////////////////////////////////////////////////////////////

    payload_1 = [0xDEADBEEF]
    i3c_target_len_1 = 4
    
    dut._log.info("Sending Private I3C Write with TOC=0")
    await write_i3c(
        tb, addr_helper=addr_helper, payload=payload_1, target_len=i3c_target_len_1, 
        i3c_target=i3c_target, device_address=DYNAMIC_ADDR, toc=False, dat=False, 
        expect_error=None, bus_idx=ACT_CONTROLLER_IDX
    )
    
    dut._log.info("Command 1 completed successfully.")

# //////////////////////////////////////////////////////////////
# //     Poll INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT and     //
# //              INTR_STATUS.HC_SEQ_CANCEL_STAT              //
# //////////////////////////////////////////////////////////////

    intr_status_addr = tb.reg_map.I3CBASE.INTR_STATUS.base_addr
    timeout_field = tb.reg_map.I3CBASE.INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT
    cancel_field = tb.reg_map.I3CBASE.INTR_STATUS.HC_SEQ_CANCEL_STAT

    timeout_stat = 0
    cancel_stat = 0
    
    dut._log.info("Polling for SCL Stall Timeout Interrupt...")
    for _ in range(150):
        timeout_stat = await tb.read_csr_field(intr_status_addr, timeout_field, bus_idx=ACT_CONTROLLER_IDX)
        cancel_stat = await tb.read_csr_field(intr_status_addr, cancel_field, bus_idx=ACT_CONTROLLER_IDX)
        if timeout_stat == 1 and cancel_stat == 1:
            break
        await ClockCycles(tb.clk, 10)

    assert timeout_stat == 1, "Timed out waiting for HC_ERR_CMD_SEQ_TIMEOUT_STAT!"
    assert cancel_stat == 1, "Timed out waiting for HC_SEQ_CANCEL_STAT!"

    # Verify that the hardware halted itself
    resume_val = await tb.read_csr_field(hc_ctrl_addr, tb.reg_map.I3CBASE.HC_CONTROL.RESUME, bus_idx=ACT_CONTROLLER_IDX)
    assert resume_val == 1, "Hardware did NOT halt despite HALT_ON_CMD_SEQ_TIMEOUT=1!"

# //////////////////////////////////////////////////////////////
# //                    Resume Operation                      //
# //////////////////////////////////////////////////////////////

    dut._log.info("Clearing Interrupts and Resuming Operation")
    await tb.write_csr_field(intr_status_addr, timeout_field, 1, bus_idx=ACT_CONTROLLER_IDX)
    await tb.write_csr_field(intr_status_addr, cancel_field, 1, bus_idx=ACT_CONTROLLER_IDX)
    
    # Write 1 to RESUME (woclr) to un-halt the queue
    await tb.write_csr_field(hc_ctrl_addr, tb.reg_map.I3CBASE.HC_CONTROL.RESUME, 1, bus_idx=ACT_CONTROLLER_IDX)
    
    await ClockCycles(tb.clk, 100)

# //////////////////////////////////////////////////////////////
# //               Private I3C Write (TOC=1'b1)               //
# //////////////////////////////////////////////////////////////

    payload_2 = [0xCAFEBABE]
    i3c_target_len_2 = 4
    
    dut._log.info("Sending next Private I3C Write with TOC=1 to verify manual resume")
    await write_i3c(
        tb, addr_helper=addr_helper, payload=payload_2, target_len=i3c_target_len_2, 
        i3c_target=i3c_target, device_address=DYNAMIC_ADDR, toc=True, dat=False, 
        expect_error=None, bus_idx=ACT_CONTROLLER_IDX
    )
    
    dut._log.info("Command 2 processed successfully. Manual resume verified.")


@cocotb.test()
async def test_interrupt_routing_and_masking(dut):
    """
    Systematically verifies the STATUS_ENABLE, SIGNAL_ENABLE, FORCE, 
    and W1C clearing logic for every interrupt without relying on I3C bus traffic.
    """
    tb, _, _ = await test_setup(dut)
    bus_idx = ACT_CONTROLLER_IDX

    dut._log.info("Starting Systematic Interrupt Routing Test")

    all_interrupts = [
        # GLOBAL INTERRUPTS (I3CBASE)
        (tb.reg_map.I3CBASE, "INTR", "HC_INTERNAL_ERR"),
        (tb.reg_map.I3CBASE, "INTR", "HC_SEQ_CANCEL"),
        (tb.reg_map.I3CBASE, "INTR", "HC_WARN_CMD_SEQ_STALL"),
        (tb.reg_map.I3CBASE, "INTR", "HC_ERR_CMD_SEQ_TIMEOUT"),
        (tb.reg_map.I3CBASE, "INTR", "SCHED_CMD_MISSED_TICK"),
        
        # ALL PIO INTERRUPTS (PIOCONTROL) - Including Level-Sensitive
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "TX_THLD"),
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "RX_THLD"),
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "IBI_STATUS_THLD"),
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "CMD_QUEUE_READY"),
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "RESP_READY"),
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "TRANSFER_ABORT"),
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "TRANSFER_ERR")
    ]

    interrupts_to_test = [
        # GLOBAL INTERRUPTS (I3CBASE)
        (tb.reg_map.I3CBASE, "INTR", "HC_INTERNAL_ERR"),
        (tb.reg_map.I3CBASE, "INTR", "HC_SEQ_CANCEL"),
        (tb.reg_map.I3CBASE, "INTR", "HC_WARN_CMD_SEQ_STALL"),
        (tb.reg_map.I3CBASE, "INTR", "HC_ERR_CMD_SEQ_TIMEOUT"),
        (tb.reg_map.I3CBASE, "INTR", "SCHED_CMD_MISSED_TICK"),
        
        # PIO INTERRUPTS (PIOCONTROL)
        # NOTE: Threshold and Ready states are Read-Only. 
        # They cannot be tested in a W1C loop. We only test the sticky PIO Error/Abort events here.
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "TRANSFER_ABORT"),
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "TRANSFER_ERR")
    ]

    try:
        irq_sig = dut.irq_o[bus_idx]
    except (TypeError, IndexError):
        irq_sig = dut.irq_o


# //////////////////////////////////////////////////////////////
# //           Initialize STATUS and SIGNAL enable            //
# //////////////////////////////////////////////////////////////


    dut._log.info("Globally disabling all STATUS and SIGNAL enables to ensure a clean slate...")
    for block, reg_prefix, field_prefix in all_interrupts:
        status_reg = getattr(block, f"{reg_prefix}_STATUS")
        status_en_reg = getattr(block, f"{reg_prefix}_STATUS_ENABLE")
        signal_en_reg = getattr(block, f"{reg_prefix}_SIGNAL_ENABLE")

        status_field = getattr(status_reg, f"{field_prefix}_STAT")
        status_en_field = getattr(status_en_reg, f"{field_prefix}_STAT_EN")
        signal_en_field = getattr(signal_en_reg, f"{field_prefix}_SIGNAL_EN")

        # Force Enables to 0
        await tb.write_csr_field(status_en_reg.base_addr, status_en_field, 0, bus_idx=bus_idx)
        await tb.write_csr_field(signal_en_reg.base_addr, signal_en_field, 0, bus_idx=bus_idx)
        
        # W1C to clear any pending status flags from the boot/reset sequence
        await tb.write_csr_field(status_reg.base_addr, status_field, 1, bus_idx=bus_idx)

    await ClockCycles(tb.clk, 10)
    await ReadOnly()
    assert irq_sig.value == 0, "FATAL: irq_o pin is still high after globally masking all interrupts!"
    dut._log.info("Initialization complete. IRQ line is cleanly de-asserted.")

    for block, reg_prefix, field_prefix in interrupts_to_test:
        dut._log.info(f"--- Testing Interrupt: {field_prefix} ---")

        status_reg = getattr(block, f"{reg_prefix}_STATUS")
        status_en_reg = getattr(block, f"{reg_prefix}_STATUS_ENABLE")
        signal_en_reg = getattr(block, f"{reg_prefix}_SIGNAL_ENABLE")
        force_reg = getattr(block, f"{reg_prefix}_FORCE")

        status_field = getattr(status_reg, f"{field_prefix}_STAT")
        status_en_field = getattr(status_en_reg, f"{field_prefix}_STAT_EN")
        signal_en_field = getattr(signal_en_reg, f"{field_prefix}_SIGNAL_EN")
        force_field = getattr(force_reg, f"{field_prefix}_FORCE")

        # STEP 1: Verify Status Enable Masking (Event happens, but EN=0)
        # ------------------------------------------------------------------
        # Ensure enables are 0
        await tb.write_csr_field(status_en_reg.base_addr, status_en_field, 0, bus_idx=bus_idx)
        await tb.write_csr_field(signal_en_reg.base_addr, signal_en_field, 0, bus_idx=bus_idx)
        
        # Force the interrupt
        await tb.write_csr_field(force_reg.base_addr, force_field, 1, bus_idx=bus_idx)
        await ClockCycles(tb.clk, 2)
        
        # Check Status (Should be 0)
        stat_val = await tb.read_csr_field(status_reg.base_addr, status_field, bus_idx=bus_idx)
        assert stat_val == 0, f"{field_prefix}: STATUS bypassed STATUS_ENABLE mask!"

        # STEP 2: Verify Signal Enable Masking (Status logged, but PIN EN=0)
        # ------------------------------------------------------------------
        # Set STATUS_EN to 1 and force again
        await tb.write_csr_field(status_en_reg.base_addr, status_en_field, 1, bus_idx=bus_idx)
        await tb.write_csr_field(force_reg.base_addr, force_field, 1, bus_idx=bus_idx)
        await ClockCycles(tb.clk, 2)

        # Check Status (Should be 1 now)
        stat_val = await tb.read_csr_field(status_reg.base_addr, status_field, bus_idx=bus_idx)
        assert stat_val == 1, f"{field_prefix}: FORCE failed to set STATUS bit!"
        
        # Check physical pin (Should be 0 because SIGNAL_EN is 0)
        await ReadOnly()
        assert irq_sig.value == 0, f"{field_prefix}: Pin went high while SIGNAL_ENABLE was 0!"

        # STEP 3: Verify Physical Routing (SIGNAL_EN=1)
        # ------------------------------------------------------------------
        await tb.write_csr_field(signal_en_reg.base_addr, signal_en_field, 1, bus_idx=bus_idx)
        await ClockCycles(tb.clk, 2)
        
        await ReadOnly()
        assert irq_sig.value == 1, f"{field_prefix}: Physical irq_o pin failed to assert!"

        # STEP 4: Verify Write-1-to-Clear (W1C)
        # ------------------------------------------------------------------
        # Write 1 to the STATUS register to clear it
        await tb.write_csr_field(force_reg.base_addr, force_field, 0, bus_idx=bus_idx)
        await ClockCycles(tb.clk, 2)

        await tb.write_csr_field(status_reg.base_addr, status_field, 1, bus_idx=bus_idx)
        await ClockCycles(tb.clk, 2)

        stat_val = await tb.read_csr_field(status_reg.base_addr, status_field, bus_idx=bus_idx)
        assert stat_val == 0, f"{field_prefix}: W1C failed to clear the STATUS bit!"
        
        await ReadOnly()
        assert irq_sig.value == 0, f"{field_prefix}: irq_o pin failed to de-assert after W1C!"

        # Cleanup: Disable enables for the next loop iteration
        await tb.write_csr_field(status_en_reg.base_addr, status_en_field, 0, bus_idx=bus_idx)
        await tb.write_csr_field(signal_en_reg.base_addr, signal_en_field, 0, bus_idx=bus_idx)

    dut._log.info("SUCCESS: All interrupts routed, masked, and cleared correctly.")
