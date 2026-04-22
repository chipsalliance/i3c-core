# SPDX-License-Identifier: Apache-2.0
import functools
import logging
from os import stat
import random
from math import ceil

from boot_controller import boot_init
from monitor import BusStateMonitor
from bus2csr import dword2int, int2dword
from hci import immediate_transfer_descriptor_direct, regular_transfer_descriptor_direct, ResponseDescriptor, ErrorStatus, address_assignment_descriptor
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

async def read_target_events(tb):

    reg = tb.reg_map.I3C_EC.TTI.CONTROL.base_addr
    ibi_en_field = tb.reg_map.I3C_EC.TTI.CONTROL.IBI_EN
    crr_en_field = tb.reg_map.I3C_EC.TTI.CONTROL.CRR_EN
    hj_en_field = tb.reg_map.I3C_EC.TTI.CONTROL.HJ_EN

    ibi_en = await tb.read_csr_field(reg, ibi_en_field, bus_idx=ACT_TARGET_IDX)
    crr_en = await tb.read_csr_field(reg, crr_en_field, bus_idx=ACT_TARGET_IDX)
    hj_en = await tb.read_csr_field(reg, hj_en_field, bus_idx=ACT_TARGET_IDX)

    return (ibi_en, crr_en, hj_en)

async def write_ccc(tb, ccc, immediate=None, payload=None, data_length=0, device_address=0x50, toc=True, rnw=False):
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
        await tb.put_tx_data(payload, tx_queue_depth=TX_QUEUE_DEPTH, tx_thld=TX_READY_THLD, bus_idx=1)

    await tb.put_command_desc(cmd_desc.to_int(), bus_idx=1)
    # Wait for response Descriptor when it's the last cmd descriptor
    if toc:
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

async def write_entdaa(tb, addr_helper, device_index=None):
    if device_index is None:
        device_index = random.getrandbits(5)
    await tb.put_dat_entry(device_index=device_index, dyn_addr=addr_helper.trgt_dyn_addr, static_addr=0x0, is_i2c=False, bus_idx=ACT_CONTROLLER_IDX)
    await tb.put_dat_entry(device_index=(device_index+1), dyn_addr=addr_helper.trgt_virt_dyn_addr, static_addr=0x0, is_i2c=False, bus_idx=ACT_CONTROLLER_IDX) # TODO: figure out the increment on the device index
    cmd_desc = address_assignment_descriptor(
        tid=random.getrandbits(3),
        cmd=CCC.BCAST.ENTDAA,
        device_index=device_index,
        device_count=2,
        wroc=True,
        toc=True
    )
    
    await tb.put_command_desc(cmd_desc.to_int(), bus_idx=ACT_CONTROLLER_IDX)
    # Wait for response Descriptor when it's the last cmd descriptor
    resp_desc = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
    await ClockCycles(tb.clk, 500) # 500 Cycles stop
    assert resp_desc.data_length == 0x0 # 0 targets left to assign -> we've assigned all addresses
    assert resp_desc.tid == cmd_desc.tid
    assert resp_desc.err_status == ErrorStatus(0) # SUCCESS



@cocotb.test()
async def test_controller_ccc_enec_disec_bcast(dut):

    command_enec = CCC.BCAST.ENEC
    command_disec = CCC.BCAST.DISEC

    _EVENT_TOGGLE_BYTE = 0b00001011
    immediate = random.getrandbits(1)

    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr


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

    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr

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

    tb, _, addr_helper = await test_setup(dut)
    #i3c_target.address = addr_helper.trgt_dyn_addr
    # TODO: enable cocotbext target for this test

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
    tb, i3c_target, addr_helper = await test_setup(dut, enable_target_dynamic_addr=False)
    i3c_target.address = addr_helper.trgt_dyn_addr
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


@cocotb.test()
async def test_controller_ccc_setdasa_direct(dut):

    tb, i3c_target, addr_helper = await test_setup(dut, enable_target_dynamic_addr=False)
    i3c_target.address = addr_helper.trgt_dyn_addr

    STATIC_ADDR = addr_helper.trgt_static_addr
    DYNAMIC_ADDR = addr_helper.trgt_dyn_addr
    VIRTUAL_STATIC_ADDR = addr_helper.trgt_virt_static_addr
    VIRTUAL_DYNAMIC_ADDR = addr_helper.trgt_virt_dyn_addr
    command_setdasa = CCC.DIRECT.SETDASA # SETDASA

    # Read target STATIC_ADDR and VIRTUAL_STATIC_ADDR 
    static_addr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.STATIC_ADDR,
        bus_idx=ACT_TARGET_IDX
    )
    assert static_addr == STATIC_ADDR, "Unexpected STATIC ADDRESS read from the target CSR"
    static_addr_en = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.STATIC_ADDR_VALID,
        bus_idx=ACT_TARGET_IDX
    )
    assert static_addr_en == 1, "STATIC ADDRESS is not set as valid"

    virt_static_addr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR,
        bus_idx=ACT_TARGET_IDX
    )
    assert virt_static_addr == VIRTUAL_STATIC_ADDR, "Unexpected VIRTUAL STATIC ADDRESS read from the target CSR"
    virt_static_addr_en = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR_VALID,
        bus_idx=ACT_TARGET_IDX
    )
    assert virt_static_addr_en == 1, "VIRTUAL STATIC ADDRESS is not set as valid"

    # Set dynamic address
    await write_setdasa(tb, dyn_addr=DYNAMIC_ADDR, static_addr=STATIC_ADDR, toc=True, device_index=0x5)
    await write_setdasa(tb, dyn_addr=VIRTUAL_DYNAMIC_ADDR, static_addr=VIRTUAL_STATIC_ADDR, toc=True, device_index=0x7)

    # Check that dynamic address was set correctly
    dynamic_addr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR,
        bus_idx=ACT_TARGET_IDX
    )
    assert dynamic_addr == DYNAMIC_ADDR, "Unexpected DYNAMIC ADDRESS read from the target CSR"
    dynamic_addr_en = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID,
        bus_idx=ACT_TARGET_IDX
    )
    assert dynamic_addr_en == 1, "DYNAMIC ADDRESS is not set as valid"

    virt_dynamic_addr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR,
        bus_idx=ACT_TARGET_IDX
    )
    assert virt_dynamic_addr == VIRTUAL_DYNAMIC_ADDR, "Unexpected VIRTUAL DYNAMIC ADDRESS read from the target CSR"
    virt_dynamic_addr_en = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID,
        bus_idx=ACT_TARGET_IDX
    )
    assert virt_dynamic_addr_en == 1, "VIRTUAL DYNAMIC ADDRESS is not set as valid"

@cocotb.test()
async def test_controller_ccc_entdaa(dut):

    tb, i3c_target, addr_helper = await test_setup(dut, enable_target_dynamic_addr=False)
    i3c_target.address = addr_helper.trgt_dyn_addr


# //////////////////////////////////////////////////////////////
# //   Read the characteristic registers of the target and    //
# //                      virtual target                      //
# //////////////////////////////////////////////////////////////

    dut._log.info("Reading Target Characteristics...")
    
    # Actual Target
    target_dcr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.DCR,
        bus_idx=ACT_TARGET_IDX
    )
    target_pid_hi = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.PID_HI,
        bus_idx=ACT_TARGET_IDX
    )
    target_pid_lo = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.PID_LO,
        bus_idx=ACT_TARGET_IDX
    )
    target_bcr_var = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.BCR_VAR,
        bus_idx=ACT_TARGET_IDX
    )
    target_bcr_fixed = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.BCR_FIXED,
        bus_idx=ACT_TARGET_IDX
    )
    target_pid = (target_pid_hi << 33) | target_pid_lo
    target_bcr = (target_bcr_fixed << 5) | target_bcr_var

    dut._log.info(f"Target PID: {target_pid:#014x}, DCR: {target_dcr:#04x}, BCR: {target_bcr:#04x}")

    # Virtual Target
    virt_target_dcr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_CHAR.DCR,
        bus_idx=ACT_TARGET_IDX
    )
    virt_target_pid_hi = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_CHAR.PID_HI,
        bus_idx=ACT_TARGET_IDX
    )
    virt_target_pid_lo = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_PID_LO.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_PID_LO.PID_LO,
        bus_idx=ACT_TARGET_IDX
    )
    virt_target_bcr_var = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_CHAR.BCR_VAR,
        bus_idx=ACT_TARGET_IDX
    )
    virt_target_bcr_fixed = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRTUAL_DEVICE_CHAR.BCR_FIXED,
        bus_idx=ACT_TARGET_IDX
    )
    
    virt_target_pid = (virt_target_pid_hi << 33) | virt_target_pid_lo
    virt_target_bcr = (virt_target_bcr_fixed << 5) | virt_target_bcr_var

    dut._log.info(f"Virtual Target PID: {virt_target_pid:#014x}, DCR: {virt_target_dcr:#04x}, BCR: {virt_target_bcr:#04x}")
    # -------------------------------------------------------------------------


# //////////////////////////////////////////////////////////////
# //             Start Dynamic Address Assignment             //
# //////////////////////////////////////////////////////////////


    dut._log.info("Starting DAA")
    await write_entdaa(tb, addr_helper=addr_helper, device_index=0x0)
    dut._log.info("Finished DAA")


# //////////////////////////////////////////////////////////////
# //       Check that dynamic address was set correctly       //
# //////////////////////////////////////////////////////////////

    dynamic_addr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR,
        bus_idx=ACT_TARGET_IDX
    )
    assert dynamic_addr == addr_helper.trgt_dyn_addr, "Unexpected DYNAMIC ADDRESS read from the target CSR"
    dynamic_addr_en = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID,
        bus_idx=ACT_TARGET_IDX
    )
    assert dynamic_addr_en == 1, "DYNAMIC ADDRESS is not set as valid"

    virt_dynamic_addr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR,
        bus_idx=ACT_TARGET_IDX
    )
    assert virt_dynamic_addr == addr_helper.trgt_virt_dyn_addr, "Unexpected VIRTUAL DYNAMIC ADDRESS read from the target CSR"
    virt_dynamic_addr_en = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID,
        bus_idx=ACT_TARGET_IDX
    )
    assert virt_dynamic_addr_en == 1, "VIRTUAL DYNAMIC ADDRESS is not set as valid"


# //////////////////////////////////////////////////////////////
# //          Check that the DCT entries are correct          //
# //////////////////////////////////////////////////////////////

    # -------------------------------------------------------------------------
    dct_table_index = await tb.read_csr_field(
        tb.reg_map.I3CBASE.DCT_SECTION_OFFSET.base_addr,
        tb.reg_map.I3CBASE.DCT_SECTION_OFFSET.TABLE_INDEX,
        bus_idx=ACT_CONTROLLER_IDX
    )
    
    # Based on the reg_map, each entry is 128-bits / 16-bytes
    dct_base_addr = tb.reg_map.DCT.DCT_MEMORY.base_addr
    entry_size_bytes = 16 

    actual_target_found = False
    virt_target_found = False

    for i in range(2):
        entry_addr = dct_base_addr + ((dct_table_index + i) * entry_size_bytes)
        
        dword0_obj = await tb.read_csr(entry_addr + 0x0, bus_idx=ACT_CONTROLLER_IDX)
        dword1_obj = await tb.read_csr(entry_addr + 0x4, bus_idx=ACT_CONTROLLER_IDX)
        dword2_obj = await tb.read_csr(entry_addr + 0x8, bus_idx=ACT_CONTROLLER_IDX)
        dword3_obj = await tb.read_csr(entry_addr + 0xC, bus_idx=ACT_CONTROLLER_IDX)
        
        dword0 = dword2int(dword0_obj)
        dword1 = dword2int(dword1_obj)
        dword2 = dword2int(dword2_obj)
        dword3 = dword2int(dword3_obj)
        
        entry_pid_hi   = dword0                   # Bits [31:0] of the 128-bit entry
        entry_pid_lo   = dword1 & 0xFFFF          # Bits [47:32] (Lower 16 bits of DWORD 1)
        entry_dcr      = dword2 & 0xFF            # Bits [71:64] (Lower 8 bits of DWORD 2)
        entry_bcr      = (dword2 >> 8) & 0xFF     # Bits [79:72] (Next 8 bits of DWORD 2)
        entry_dyn_addr = (dword3 & 0xFF) >> 1            # Bits [103:96] (7 bits of DWORD 3, LSB is parity bit)
        
        # Reconstruct the 48-bit PID to compare safely against the STBY_CR reading
        entry_pid = (entry_pid_lo << 32) | entry_pid_hi
        
        dut._log.info(
            f"DCT Entry {i} (Index {dct_table_index + i}) at address 0x{entry_addr:x}: "
            f"PID={entry_pid:#014x}, DCR={entry_dcr:#04x}, "
            f"BCR={entry_bcr:#04x}, DYN_ADDR={entry_dyn_addr:#04x}"
        )
        
        if entry_dyn_addr == addr_helper.trgt_dyn_addr:
            dut._log.info("-> Matching Actual Target properties")
            assert entry_pid == target_pid, f"Actual Target PID mismatch: expected {target_pid:#014x}, got {entry_pid:#014x}"
            assert entry_dcr == target_dcr, f"Actual Target DCR mismatch: expected {target_dcr:#04x}, got {entry_dcr:#04x}"
            assert entry_bcr == target_bcr, f"Actual Target BCR mismatch: expected {target_bcr:#04x}, got {entry_bcr:#04x}"
            actual_target_found = True
            
        elif entry_dyn_addr == addr_helper.trgt_virt_dyn_addr:
            dut._log.info("-> Matching Virtual Target properties")
            assert entry_pid == virt_target_pid, f"Virtual Target PID mismatch: expected {virt_target_pid:#014x}, got {entry_pid:#014x}"
            assert entry_dcr == virt_target_dcr, f"Virtual Target DCR mismatch: expected {virt_target_dcr:#04x}, got {entry_dcr:#04x}"
            assert entry_bcr == virt_target_bcr, f"Virtual Target BCR mismatch: expected {virt_target_bcr:#04x}, got {entry_bcr:#04x}"
            virt_target_found = True
            
        else:
            assert False, f"Unexpected DYNAMIC ADDRESS in DCT entry {i}: {entry_dyn_addr:x}"
    
    assert actual_target_found, "Actual target dynamic address was never found in the DCT!"
    assert virt_target_found, "Virtual target dynamic address was never found in the DCT!"
    # -------------------------------------------------------------------------


@cocotb.test()
async def test_controller_ccc_rstdaa(dut):

    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr

    DYNAMIC_ADDR = addr_helper.trgt_dyn_addr
    VIRTUAL_DYNAMIC_ADDR = addr_helper.trgt_virt_dyn_addr

    # Read target DYNAMIC_ADDR and VIRTUAL_DYNAMIC_ADDR
    dynamic_addr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR,
        bus_idx=ACT_TARGET_IDX
    )
    assert dynamic_addr == DYNAMIC_ADDR, "Unexpected DYNAMIC ADDRESS read from the target CSR"
    dynamic_addr_en = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID,
        bus_idx=ACT_TARGET_IDX
    )
    assert dynamic_addr_en == 1, "DYNAMIC ADDRESS is not set as valid"

    virt_dynamic_addr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR,
        bus_idx=ACT_TARGET_IDX
    )
    assert virt_dynamic_addr == VIRTUAL_DYNAMIC_ADDR, "Unexpected VIRTUAL DYNAMIC ADDRESS read from the target CSR"
    virt_dynamic_addr_en = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID,
        bus_idx=ACT_TARGET_IDX
    )
    assert virt_dynamic_addr_en == 1, "VIRTUAL DYNAMIC ADDRESS is not set as valid"


    # Set dynamic address
    dut._log.info("Sending RSTDAA CCC.")
    await write_ccc(tb, CCC.BCAST.RSTDAA)
    dut._log.info("Finished sending RSTDAA CCC")

    # Check that dynamic address was reset correctly
    dynamic_addr_en = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID,
        bus_idx=ACT_TARGET_IDX
    )
    assert dynamic_addr_en == 0, "DYNAMIC ADDRESS is not reset correctly (should be invalid)"

    virt_dynamic_addr_en = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID,
        bus_idx=ACT_TARGET_IDX
    )
    assert virt_dynamic_addr_en == 0, "VIRTUAL DYNAMIC ADDRESS is not reset correctly (should be invalid)"

@cocotb.test()
async def test_controller_ccc_setnewda(dut):

    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr

    DYNAMIC_ADDR = addr_helper.trgt_dyn_addr
    VIRTUAL_DYNAMIC_ADDR = addr_helper.trgt_virt_dyn_addr

    # Read target DYNAMIC_ADDR and VIRTUAL_DYNAMIC_ADDR
    dynamic_addr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR,
        bus_idx=ACT_TARGET_IDX
    )
    assert dynamic_addr == DYNAMIC_ADDR, "Unexpected DYNAMIC ADDRESS read from the target CSR"
    dynamic_addr_en = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID,
        bus_idx=ACT_TARGET_IDX
    )
    assert dynamic_addr_en == 1, "DYNAMIC ADDRESS is not set as valid"

    virt_dynamic_addr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR,
        bus_idx=ACT_TARGET_IDX
    )
    assert virt_dynamic_addr == VIRTUAL_DYNAMIC_ADDR, "Unexpected VIRTUAL DYNAMIC ADDRESS read from the target CSR"
    virt_dynamic_addr_en = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID,
        bus_idx=ACT_TARGET_IDX
    )
    assert virt_dynamic_addr_en == 1, "VIRTUAL DYNAMIC ADDRESS is not set as valid"

    # Generate New Dynamic Addresses
    NEW_DYN_ADDR = addr_helper.get_unassigned_valid_address()
    NEW_VIRT_DYN_ADDR = addr_helper.get_unassigned_valid_address()

    dut._log.info(f"Assigning new dynamic address: 0x{NEW_DYN_ADDR:x} and new virtual dynamic address: 0x{NEW_VIRT_DYN_ADDR:x}")

    # Set new dynamic address
    dut._log.info("Sending SETNEWDA CCCs.")
    await write_ccc(tb, CCC.DIRECT.SETNEWDA, payload=[NEW_DYN_ADDR << 1], device_address=addr_helper.trgt_dyn_addr, toc=False)
    await write_ccc(tb, CCC.DIRECT.SETNEWDA, payload=[NEW_VIRT_DYN_ADDR << 1], device_address=addr_helper.trgt_virt_dyn_addr, toc=True)
    dut._log.info("Finished sending SETNEWDA CCCs")

    # Read new target DYNAMIC_ADDR and VIRTUAL_DYNAMIC_ADDR
    new_dynamic_addr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR,
        bus_idx=ACT_TARGET_IDX
    )
    assert new_dynamic_addr == NEW_DYN_ADDR, "Unexpected New DYNAMIC ADDRESS read from the target CSR"
    new_dynamic_addr_en = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID,
        bus_idx=ACT_TARGET_IDX
    )
    assert new_dynamic_addr_en == 1, "New DYNAMIC ADDRESS is not set as valid"

    new_virt_dynamic_addr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR,
        bus_idx=ACT_TARGET_IDX
    )
    assert new_virt_dynamic_addr == NEW_VIRT_DYN_ADDR, "Unexpected New VIRTUAL DYNAMIC ADDRESS read from the target CSR"
    new_virt_dynamic_addr_en = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID,
        bus_idx=ACT_TARGET_IDX
    )
    assert new_virt_dynamic_addr_en == 1, "New VIRTUAL DYNAMIC ADDRESS is not set as valid"

@cocotb.test()
async def test_controller_ccc_getpid(dut):

    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr

    target_pid_hi = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.PID_HI,
        bus_idx=ACT_TARGET_IDX
    )
    target_pid_lo = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.PID_LO,
        bus_idx=ACT_TARGET_IDX
    )
    target_pid = (target_pid_hi << 33) | target_pid_lo

    dut._log.info(f"Target PID: {target_pid:#014x}")

    await write_ccc(tb, CCC.DIRECT.GETPID, data_length=6, device_address=addr_helper.trgt_dyn_addr, toc=True, immediate=False, rnw=True)

    # Read RX queue
    dut._log.info("Reading PID from the RX Queue")
    ctrl_rx_queue_addr = tb.reg_map.PIOCONTROL.RX_DATA_PORT.base_addr
    # PID is 6 bytes, which means we have to read 2 DWORDs
    recv_data = await tb.read_rx_queue(2, bus_idx=ACT_CONTROLLER_IDX, rx_port_addr=ctrl_rx_queue_addr)
    dut._log.info("Finished reading RX Queue.")
    b0 = recv_data[0].to_bytes(4, 'little')
    b1 = recv_data[1].to_bytes(4, 'little')
    total_bytes = b0 + b1[0:2]
    received_pid = int.from_bytes(total_bytes, 'big')

    dut._log.info(f"Received PID: {received_pid:#014x}")

    assert received_pid == target_pid, f"PID Mismatch! Expected {target_pid:x}, but got {received_pid:x}"

@cocotb.test()
async def test_controller_ccc_getbcr(dut):

    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr

    target_bcr_var = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.BCR_VAR,
        bus_idx=ACT_TARGET_IDX
    )
    target_bcr_fixed = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.BCR_FIXED,
        bus_idx=ACT_TARGET_IDX
    )
    target_bcr = (target_bcr_fixed << 5) | target_bcr_var

    dut._log.info(f"BCR: {target_bcr:#04x}")

    await write_ccc(tb, CCC.DIRECT.GETBCR, data_length=1, device_address=addr_helper.trgt_dyn_addr, toc=True, immediate=False, rnw=True)

    # Read RX queue
    dut._log.info("Reading BCR from the RX Queue")
    ctrl_rx_queue_addr = tb.reg_map.PIOCONTROL.RX_DATA_PORT.base_addr
    # PID is 6 bytes, which means we have to read 2 DWORDs
    recv_data = await tb.read_rx_queue(1, bus_idx=ACT_CONTROLLER_IDX, rx_port_addr=ctrl_rx_queue_addr)
    dut._log.info("Finished reading RX Queue.")
    received_bcr = recv_data[0] & 0xFF

    dut._log.info(f"Received BCR: {received_bcr:x}")

    assert received_bcr == target_bcr, f"BCR Mismatch! Expected {target_bcr:x}, but got {received_bcr:x}"

@cocotb.test()
async def test_controller_ccc_getdcr(dut):

    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr

    target_dcr = await tb.read_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.DCR,
        bus_idx=ACT_TARGET_IDX
    )


    dut._log.info(f"DCR: {target_dcr:#04x}")

    await write_ccc(tb, CCC.DIRECT.GETDCR, data_length=1, device_address=addr_helper.trgt_dyn_addr, toc=True, immediate=False, rnw=True)

    # Read RX queue
    dut._log.info("Reading DCR from the RX Queue")
    ctrl_rx_queue_addr = tb.reg_map.PIOCONTROL.RX_DATA_PORT.base_addr
    # PID is 6 bytes, which means we have to read 2 DWORDs
    recv_data = await tb.read_rx_queue(1, bus_idx=ACT_CONTROLLER_IDX, rx_port_addr=ctrl_rx_queue_addr)
    dut._log.info("Finished reading RX Queue.")
    received_dcr = recv_data[0] & 0xFF

    dut._log.info(f"Received DCR: {received_dcr:x}")

    assert received_dcr == target_dcr, f"DCR Mismatch! Expected {target_dcr:x}, but got {received_dcr:x}"


