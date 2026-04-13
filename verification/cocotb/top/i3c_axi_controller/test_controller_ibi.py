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

def pack_expected_ibi(mdb: int, payload_bytes: list) -> list:
    """
    Packs an MDB byte and a list of 8-bit payload bytes into a list of 32-bit DWORDs,
    where the MDB occupies the LSB of the first DWORD.
    """
    # 1. Prepend the MDB to the raw bytes
    packed_bytes = bytearray([mdb]) + bytearray(payload_bytes)
    
    # 2. Pad the end with zeros to ensure the total length is a multiple of 4 (DWORD aligned)
    while len(packed_bytes) % 4 != 0:
        packed_bytes.append(0x00)
        
    # 3. Chunk the bytes into 32-bit integers (little-endian)
    packed_dwords = []
    for i in range(0, len(packed_bytes), 4):
        dword = int.from_bytes(packed_bytes[i:i+4], byteorder='little')
        packed_dwords.append(dword)
        
    return packed_dwords

@cocotb.test()
async def test_controller_ibi_accepted(dut):

# //////////////////////////////////////////////////////////////
# //                          Setup                           //
# //////////////////////////////////////////////////////////////

    TX_QUEUE_DEPTH = 8
    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr
    device_index = random.getrandbits(5)


# //////////////////////////////////////////////////////////////
# //                 Internal Control Command                 //
# //////////////////////////////////////////////////////////////

    cmd_desc = internal_control_descriptor(tid=random.getrandbits(4), vip=False, mipi_cmd=0x2, mipi_rsvd=0x1, vendor_specific=0x0)
    dut._log.info("Sending Command Descriptor to activate I3C Broadcast Header")
    await tb.put_command_desc(cmd_desc.to_int(), bus_idx=ACT_CONTROLLER_IDX)


# //////////////////////////////////////////////////////////////
# //                 Send IBI Desc to Target                  //
# //////////////////////////////////////////////////////////////
    mdb = 0xAA
    payload_length = random.randrange(11) # TODO: once we have the internal buffer limit as a define use this as a bound for now the max is 3 DWORDs
    ibi_payload = [random.getrandbits(8) for _ in range(payload_length)]
    ibi_data = format_ibi_data(mdb, ibi_payload)
    dut._log.info(f"Sending IBI to the target with mdb: {mdb:x} and ibi_payload: {[hex(x) for x in ibi_payload]}")
    for word in ibi_data:
        await tb.write_csr(addr=tb.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, data=int2dword(word), bus_idx=ACT_TARGET_IDX)

    await ClockCycles(tb.clk, 1000)

# //////////////////////////////////////////////////////////////
# //         I3C Private Write (will get interrupted)         //
# //////////////////////////////////////////////////////////////

    i3c_target_len = 3 # doesn't matter what it is since it will get interrupted either way
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
    await write_i3c(tb, addr_helper=addr_helper, payload=data, target_len=i3c_target_len, device_address=addr_helper.trgt_dyn_addr, toc=True, device_index=device_index, expect_success=False)

    await check_ibi(tb, exp_payload=pack_expected_ibi(mdb, ibi_payload), target_dyn_address=addr_helper.trgt_dyn_addr)

@cocotb.test()
async def test_controller_ibi_rejected(dut):

# //////////////////////////////////////////////////////////////
# //                          Setup                           //
# //////////////////////////////////////////////////////////////

    TX_QUEUE_DEPTH = 8
    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr
    device_index = random.getrandbits(5)


# //////////////////////////////////////////////////////////////
# //                 Internal Control Command                 //
# //////////////////////////////////////////////////////////////

    cmd_desc = internal_control_descriptor(tid=random.getrandbits(4), vip=False, mipi_cmd=0x2, mipi_rsvd=0x1, vendor_specific=0x0)
    dut._log.info("Sending Command Descriptor to activate I3C Broadcast Header")
    await tb.put_command_desc(cmd_desc.to_int(), bus_idx=ACT_CONTROLLER_IDX)


# //////////////////////////////////////////////////////////////
# //                 Send IBI Desc to Target                  //
# //////////////////////////////////////////////////////////////
    mdb = 0xAA
    # Try to overflow the internal IBI Data Buffer in flow_active
    payload_length = random.randrange(12, 20) # TODO: once we have the internal buffer limit as a define use this as a bound
    ibi_payload = [random.getrandbits(8) for _ in range(payload_length)]
    ibi_data = format_ibi_data(mdb, ibi_payload)
    dut._log.info(f"Sending IBI to the target with mdb: {mdb:x} and ibi_payload: {[hex(x) for x in ibi_payload]}")
    for word in ibi_data:
        await tb.write_csr(addr=tb.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, data=int2dword(word), bus_idx=ACT_TARGET_IDX)

    await ClockCycles(tb.clk, 1000)

# //////////////////////////////////////////////////////////////
# //         I3C Private Write (will get interrupted)         //
# //////////////////////////////////////////////////////////////

    i3c_target_len = 3 # doesn't matter what it is since it will get interrupted either way
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
    await write_i3c(tb, addr_helper=addr_helper, payload=data, target_len=i3c_target_len, device_address=addr_helper.trgt_dyn_addr, toc=True, device_index=device_index, expect_success=False)

    await check_ibi(tb, exp_payload=pack_expected_ibi(mdb, ibi_payload), target_dyn_address=addr_helper.trgt_dyn_addr, expect_err=True)
