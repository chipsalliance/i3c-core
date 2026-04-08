# SPDX-License-Identifier: Apache-2.0
import functools
import logging
import random
import os
from math import ceil

from boot_controller import boot_init
from monitor import BusStateMonitor
from bus2csr import dword2int, int2dword
from hci import immediate_transfer_descriptor_direct, regular_transfer_descriptor_direct, ResponseDescriptor, ErrorStatus, immediate_transfer_descriptor, regular_transfer_descriptor
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_target import I3CTarget
from cocotbext.i2c import I2cMemory

from controller_interface import I3CTopControllerTestInterface, I3CAddressHelper
from controller_interface import get_interrupt_status

import cocotb
from cocotb.triggers import ClockCycles, RisingEdge, Timer, Combine, Event

TX_READY_THLD = 0x1 # TX ready threshold
TX_START_THLD = 0x1 # TX start threshold

async def test_setup(dut, fclk=333.0, fbus=12.5):
    """
    Sets up controller, target models and top-level core interface
    according to the 'Expected Bus' architecture.
    """

    cocotb.log.setLevel(logging.INFO)
    logging.getLogger("cocotb.3").setLevel(logging.WARNING)
    dut._log.info(f"fclk = {fclk:.3f} MHz")
    dut._log.info(f"fbus = {fbus:.3f} MHz")

    addr_helper = I3CAddressHelper(dut)
    dut._log.info("Generated random I3C addresses: ")
    addr_helper.print_addresses()

    i2c_mem = I2cMemory(sda=dut.sda_o,  sda_o=dut.sda_i, scl=dut.scl_o, scl_o=dut.scl_i, addr=addr_helper.trgt_static_addr, size=256)

    # 2. Instantiate the Multi-Port Test Interface
    tb = I3CTopControllerTestInterface(dut, num_busses=1)
    
    # 3. Setup the DUT (Clock, Reset)
    #    Note: Uses the start_soon/join fix for resets
    await tb.setup(fclk)

    dut._log.info("Booting I3C Cores...")

    # Define configuration for each port
    # Port 0: Expected Target
    # Port 1: Actual Controller
    # Port 2: Actual Target
    core_configs = [
        {"idx": 0, "mode": 2, "addr": 0x50}, # Mode 2 = Target
        {"idx": 1, "mode": 3, "addr": 0x5B}, # Mode 3 = Controller
        {"idx": 2, "mode": 2, "addr": 0x50}, # Mode 2 = Target
    ]

    await boot_init(
                tb, 
                bus_idx=0, 
                mode=3, 
                static_addr=0x5B,
                verify=True
            )

    
    dut._log.info("I3C Controller booted successfully.")
    return i2c_mem, addr_helper, tb    

async def write_i2c(tb, addr_helper, payload, target_len, immediate=None, device_address=0x50, toc=True, dat=None, device_index=None):
    # Disable all target events
    if dat == None:
        dat = random.getrandbits(1)
    if immediate == None:
        immediate = random.getrandbits(1)

    if dat:
        await tb.put_dat_entry(device_index=device_index, dyn_addr=addr_helper.trgt_dyn_addr, static_addr=addr_helper.trgt_static_addr, is_i2c=True, bus_idx=0)
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
                i2c=True,
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
        await tb.put_command_desc(cmd_desc.to_int(), bus_idx=0)
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
            i2c=0x1,
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
        data_write = cocotb.start_soon(tb.put_tx_data(payload, ready_event=queue_filled_event, tx_thld=TX_READY_THLD, bus_idx=0))
        await queue_filled_event.wait()
        await tb.put_command_desc(cmd_desc.to_int(), bus_idx=0)
        await data_write

    # Wait for response Descriptor when it's the last cmd descriptor
    resp_desc = await tb.read_resp_desc(bus_idx=0)
    assert resp_desc.err_status == ErrorStatus.SUCCESS
    assert resp_desc.data_length == target_len
    assert resp_desc.tid == cmd_desc.tid

async def read_i2c(tb, addr_helper, target_mem_addr, target_len, device_address=0x50, toc=True, dat=None, device_index=None):
    # Tell the I2C memory where we want to read from using a private write
    if dat == None:
        dat = random.getrandbits(1)
    tb.dut._log.info("Starting I2C private write to write internal register address")
    await write_i2c(tb, addr_helper=addr_helper, payload=[target_mem_addr], target_len=1, device_address=device_address, toc=True, device_index=device_index)
    tb.dut._log.info("Finished I2C private write")
    
    if dat:
        await tb.put_dat_entry(device_index=device_index, dyn_addr=addr_helper.trgt_dyn_addr, static_addr=addr_helper.trgt_static_addr, is_i2c=True, bus_idx=0)
        cmd_desc = regular_transfer_descriptor(
        tid=random.getrandbits(3),
        cmd=0x0,
        cp=0x0,
        device_index=device_index,
        short_read_err=0x0,
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
        i2c=0x1,
        cmd=0x0,
        cp=0x0,
        device_address=device_address,
        short_read_err=0x0,
        defining_byte_present=0x0,
        mode=0x0,
        rnw=0x1,
        wroc=True,
        toc=toc,
        def_byte=0x0,
        data_length=target_len,
        )

    tb.dut._log.info("Sending Command Descriptor for I2C private read")
    await tb.put_command_desc(cmd_desc.to_int(), bus_idx=0)

    # Wait for response Descriptor when it's the last cmd descriptor
    resp_desc = await tb.read_resp_desc(bus_idx=0)
    tb.dut._log.info("Finished I2C private read")
    assert resp_desc.err_status == ErrorStatus.SUCCESS
    assert resp_desc.data_length == target_len
    assert resp_desc.tid == cmd_desc.tid

    # Read RX queue
    tb.dut._log.info("Starting to read the RX Queue.")
    ctrl_rx_queue_addr = tb.reg_map.PIOCONTROL.RX_DATA_PORT.base_addr
    recv_data = await tb.read_rx_queue((target_len + 3) // 4, bus_idx=0, rx_port_addr=ctrl_rx_queue_addr)
    tb.dut._log.info("Finished reading RX Queue.")
    return recv_data

@cocotb.test(timeout_time=2000000, timeout_unit='us')
async def test_i2c_private_write(dut):
    TX_QUEUE_DEPTH = 8
    target_len = random.randint(2, TX_QUEUE_DEPTH * 4 * 2) # Total bytes to send over the bus (1 addr + 11 payload)
    payload_len = target_len - 1
    dut._log.info(f"Target length is {target_len} bytes ({payload_len} bytes of actual payload).")
    device_index = random.getrandbits(5)
    
    target_mem_addr = 0x00

    expected_payload_bytes = os.urandom(payload_len)

    raw_tx_bytes = bytes([target_mem_addr]) + expected_payload_bytes

    padding_len = (4 - (len(raw_tx_bytes) % 4)) % 4
    padded_tx_bytes = raw_tx_bytes + bytes(padding_len)

    # 4. Convert to 32-bit little-endian words for the write_i2c driver
    data_words = [
        int.from_bytes(padded_tx_bytes[i:i+4], byteorder='little') 
        for i in range(0, len(padded_tx_bytes), 4)
    ]

    # Setup
    i2c_mem, addr_helper, tb = await test_setup(dut)

    dut._log.info("Starting I2C private write")
    await write_i2c(tb, addr_helper=addr_helper, payload=data_words, target_len=target_len, immediate=False, device_address=addr_helper.trgt_static_addr, device_index=device_index)
    dut._log.info("Finished I2C private write")

    await ClockCycles(tb.clk, 500) # Such that test doesn't finish immediately before we have a nice stop condition in the waveform

    # Read Target RX data directly from the VIP memory
    # We only read the payload_len (11 bytes) because the VIP consumed the address byte
    recv_data = i2c_mem.read_mem(target_mem_addr, payload_len)
    
    dut._log.info(f"Expected payload (hex): {expected_payload_bytes.hex()}")
    dut._log.info(f"Received payload (hex): {recv_data.hex()}")

    assert expected_payload_bytes == recv_data, "Data mismatch between sent payload and VIP memory!"

@cocotb.test()
async def test_i2c_private_read(dut):
    TX_QUEUE_DEPTH = 8
    target_len = random.randint(4, TX_QUEUE_DEPTH * 4 * 2)
    dut._log.info(f"Target length is {target_len} bytes.")
    device_index = random.getrandbits(5)
    
    target_mem_addr = 0x00

    expected_payload_bytes = os.urandom(target_len)

    # Setup
    i2c_mem, addr_helper, tb = await test_setup(dut)

    dut._log.info(f"Writing {target_len} bytes to I2C memory at address {target_mem_addr:x}")
    i2c_mem.write_mem(target_mem_addr, expected_payload_bytes)

    recv_data_raw = await read_i2c(tb, addr_helper=addr_helper, target_mem_addr=target_mem_addr, target_len=target_len, device_address=addr_helper.trgt_static_addr, device_index=device_index)

    # Convert data for comparison
    recv_data_padded = b''.join(word.to_bytes(4, byteorder='little') for word in recv_data_raw)
    recv_data = recv_data_padded[:target_len]

    await ClockCycles(tb.clk, 500) # Such that test doesn't finish immediately before we have a nice stop condition in the waveform

    
    dut._log.info(f"Expected payload (hex): {expected_payload_bytes.hex()}")
    dut._log.info(f"Received payload (hex): {recv_data.hex()}")

    assert expected_payload_bytes == recv_data, "Data mismatch between read payload and VIP memory!"
