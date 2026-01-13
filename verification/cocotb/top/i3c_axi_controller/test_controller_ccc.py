# SPDX-License-Identifier: Apache-2.0
import functools
import logging
import random
from math import ceil

from boot_controller import boot_init
from monitor import BusStateMonitor
from bus2csr import dword2int, int2dword
from hci import immediate_transfer_descriptor_direct, regular_transfer_descriptor_direct, ResponseDescriptor, ErrorStatus
from ccc import CCC
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_target import I3CTarget

from controller_interface import I3CTopControllerTestInterface, I3CAddressHelper
from controller_interface import get_interrupt_status

import cocotb
from cocotb.triggers import ClockCycles, RisingEdge, Timer, Combine, Event

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
    return tb, addr_helper 

async def read_target_events(tb):

    reg = tb.reg_map.I3C_EC.TTI.CONTROL.base_addr
    ibi_en_field = tb.reg_map.I3C_EC.TTI.CONTROL.IBI_EN
    crr_en_field = tb.reg_map.I3C_EC.TTI.CONTROL.CRR_EN
    hj_en_field = tb.reg_map.I3C_EC.TTI.CONTROL.HJ_EN

    ibi_en = await tb.read_csr_field(reg, ibi_en_field, bus_idx=ACT_TARGET_IDX)
    crr_en = await tb.read_csr_field(reg, crr_en_field, bus_idx=ACT_TARGET_IDX)
    hj_en = await tb.read_csr_field(reg, hj_en_field, bus_idx=ACT_TARGET_IDX)

    return (ibi_en, crr_en, hj_en)

async def write_ccc(tb, ccc, immediate=None, payload=None, data_length=0, device_address=0x50, toc=True):
    # Disable all target events
    no_payload = False
    if immediate == None:
        immediate = random.getrandbits(1)
    if payload == None:
        no_payload = True
        payload = [0]
    if immediate or no_payload: # no payload CCCs are always immediate transfers
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
        rnw=0x0,
        wroc=toc,
        toc=toc,
        def_byte=0x0,
        data_length=data_length,
        )
        await tb.put_tx_data(payload, tx_queue_depth=TX_QUEUE_DEPTH, tx_thld=TX_READY_THLD, bus_idx=1)

    await tb.put_command_desc(cmd_desc.to_int(), bus_idx=1)
    # Wait for response Descriptor when it's the last cmd descriptor
    if toc:
        resp_desc = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
        #assert resp_desc.data_length == len(payload)
        assert resp_desc.tid == cmd_desc.tid
        assert resp_desc.err_status == ErrorStatus(0) # SUCCESS
        await ClockCycles(tb.clk, 500) # 500 Cycles stop


@cocotb.test()
async def test_controller_ccc_enec_disec_bcast(dut):

    command_enec = CCC.BCAST.ENEC
    command_disec = CCC.BCAST.DISEC

    _EVENT_TOGGLE_BYTE = 0b00001011
    immediate = random.getrandbits(1)

    tb, addr_helper = await test_setup(dut)


    # Read default values
    event_en = await read_target_events(tb)
    if event_en != (1,0,1):
        dut._log.error(f"Mismatch for default value: Expected: {(1,0,1)} vs Received {event_en}")
    assert event_en == (1, 0, 1)

    # Disable all target events
    await write_ccc(tb, command_disec, payload=[_EVENT_TOGGLE_BYTE], data_length=1)

    # Read disabled values
    event_en = await read_target_events(tb)
    if event_en != (0,0,0):
        dut._log.error(f"Mismatch for disabled value: Expected: {(0,0,0)} vs Received {event_en}")
    assert event_en == (0, 0, 0)

    # Enable all target events
    await write_ccc(tb, command_enec, payload=[_EVENT_TOGGLE_BYTE], data_length=1)

    # Read enabled values
    event_en = await read_target_events(tb)
    if event_en != (1,1,1):
        dut._log.error(f"Mismatch for enabled value: Expected: {(1,1,1)} vs Received {event_en}")
    assert event_en == (1, 1, 1)

@cocotb.test()
async def test_controller_ccc_enec_disec_direct_one_target(dut):

    command_enec = CCC.DIRECT.ENEC # Direct version of ENEC
    command_disec = CCC.DIRECT.DISEC # Direct version of DISEC

    _EVENT_TOGGLE_BYTE = 0b00001011

    tb, addr_helper = await test_setup(dut)

    # Read default values
    event_en = await read_target_events(tb)
    if event_en != (1,0,1):
        dut._log.error(f"Mismatch for default value: Expected: {(1,0,1)} vs Received {event_en}")
    assert event_en == (1, 0, 1)

    # Disable all target events
    await write_ccc(tb, command_disec, payload=[_EVENT_TOGGLE_BYTE], device_address=addr_helper.trgt_dyn_addr)

    # Read disabled values
    event_en = await read_target_events(tb)
    if event_en != (0,0,0):
        dut._log.error(f"Mismatch for disabled value: Expected: {(0,0,0)} vs Received {event_en}")
    assert event_en == (0, 0, 0)

    # Enable all target events
    await write_ccc(tb, command_enec, payload=[_EVENT_TOGGLE_BYTE], device_address=addr_helper.trgt_dyn_addr)

    # Read enabled values
    event_en = await read_target_events(tb)
    if event_en != (1,1,1):
        dut._log.error(f"Mismatch for enabled value: Expected: {(1,1,1)} vs Received {event_en}")
    assert event_en == (1, 1, 1)

@cocotb.test()
async def test_controller_ccc_enec_disec_direct_multiple_targets(dut):

    command_enec = CCC.DIRECT.ENEC # Direct version of ENEC
    command_disec = CCC.DIRECT.DISEC # Direct version of DISEC
    num_targets = random.randrange(1,5) # Random targets between 1 and 5
    dut._log.info(f"Number of targets is: {num_targets}")

    _EVENT_TOGGLE_BYTE = 0b00001011
    immediate = random.getrandbits(1)

    tb, addr_helper = await test_setup(dut)

    # Read default values
    event_en = await read_target_events(tb)
    if event_en != (1,0,1):
        dut._log.error(f"Mismatch for default value: Expected: {(1,0,1)} vs Received {event_en}")
    assert event_en == (1, 0, 1)

    # Disable all target events
    # For now we send the same CCC to the same address multiple times to test the Direct frame format for multiple targets (Figure 31 I3C Basic Spec)
    for i in range(num_targets):
        await write_ccc(tb, command_disec, payload=[_EVENT_TOGGLE_BYTE], device_address=addr_helper.trgt_dyn_addr, toc=(i==num_targets-1))

    # Read disabled values
    event_en = await read_target_events(tb)
    if event_en != (0,0,0):
        dut._log.error(f"Mismatch for disabled value: Expected: {(0,0,0)} vs Received {event_en}")
    assert event_en == (0, 0, 0)

    # Enable all target events
    for i in range(num_targets):
        await write_ccc(tb, command_enec, payload=[_EVENT_TOGGLE_BYTE], device_address=addr_helper.trgt_dyn_addr, toc=(i==num_targets-1))

    # Read enabled values
    event_en = await read_target_events(tb)
    if event_en != (1,1,1):
        dut._log.error(f"Mismatch for enabled value: Expected: {(1,1,1)} vs Received {event_en}")
    assert event_en == (1, 1, 1)



@cocotb.test()
async def test_controller_ccc_setaasa(dut):

    I3C_BCAST_SETAASA = CCC.BCAST.SETAASA
    # Note that we initialize the I3C target without a DYNAMIC ADDRESS. If we set a DYNAMIC ADDR during initialisation the I3C target will keep the dynamic address and not the STATIC ADDR.
    tb, addr_helper = await test_setup(dut, enable_target_dynamic_addr=False)
    STATIC_ADDR = addr_helper.trgt_static_addr

    VIRT_STATIC_ADDR = addr_helper.trgt_virt_static_addr

    dynamic_address_reg_addr = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr
    dynamic_address_reg_value = tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR
    dynamic_address_reg_valid = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID
    )
    virtual_dynamic_address_reg_addr = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr
    )
    virtual_dynamic_address_reg_value = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR
    )
    virtual_dynamic_address_reg_valid = (
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID
    )

    # read static address
    target_static_address = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.STATIC_ADDR,
        bus_idx=ACT_TARGET_IDX
    )
    dut._log.info(f"Read back target STATIC ADDRESS: 0x{target_static_address:x}")

    dynamic_address_before_reset = await tb.read_csr_field(dynamic_address_reg_addr, dynamic_address_reg_value, bus_idx=ACT_TARGET_IDX)
    dut._log.info(f"Read back target DYNAMIC ADDRESS: 0x{dynamic_address_before_reset:x}")

    # reset Dynamic Address
    await write_ccc(tb, I3C_BCAST_SETAASA)

    # check if the address was reset
    dynamic_address = await tb.read_csr_field(dynamic_address_reg_addr, dynamic_address_reg_value, bus_idx=ACT_TARGET_IDX)
    dynamic_address_valid = await tb.read_csr_field(
        dynamic_address_reg_addr, dynamic_address_reg_valid, bus_idx=ACT_TARGET_IDX
    )
    assert dynamic_address == target_static_address, "Unexpected DYNAMIC ADDRESS read from the CSR"
    assert dynamic_address_valid == 1, "New DYNAMIC ADDRESS is not set as valid"

    virt_dynamic_address = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_value, bus_idx=ACT_TARGET_IDX
    )
    virt_dynamic_address_valid = await tb.read_csr_field(
        virtual_dynamic_address_reg_addr, virtual_dynamic_address_reg_valid, bus_idx=ACT_TARGET_IDX
    )
    assert virt_dynamic_address_valid == 1, "New VIRT DYNAMIC ADDRESS is not set as valid"
    assert virt_dynamic_address == VIRT_STATIC_ADDR, "Unexpected VIRT DYNAMIC ADDRESS read from the CSR"

