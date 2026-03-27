# SPDX-License-Identifier: Apache-2.0
import functools
import logging
import random
from math import ceil

from boot_controller import boot_init
from monitor import BusStateMonitor
from bus2csr import dword2int, int2dword
from hci import immediate_transfer_descriptor_direct, regular_transfer_descriptor_direct, ResponseDescriptor, ErrorStatus
from cocotbext_i3c.i3c_controller import I3cController

from controller_interface import I3CTopControllerTestInterface, I3CAddressHelper
from cocotbext_i3c.i3c_target import I3CTarget

from controller_interface import get_interrupt_status

import cocotb
from cocotb.triggers import ClockCycles, RisingEdge, Timer, Combine, Event

ACT_TARGET_IDX = 2 # Port idx of actual target
ACT_CONTROLLER_IDX = 1 # Port idx of actual controller
RX_READY_THLD = 0x1 # RX ready threshold
RX_STAT_THLD = 0x1 # RX start threshold

async def test_setup(dut, fclk=333.0, fbus=12.5, core_configs=None):
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
        core_configs = [
            {"idx": 0, "mode": 2, "static_addr": 0x0, "dyn_addr": 0x0, "virt_static_addr": 0x0, "virt_dyn_addr": 0x0}, # Mode 2 = EXP Target (UNUSED)
            {"idx": 1, "mode": 3, "static_addr": addr_helper.ctrl_static_addr, "dyn_addr": addr_helper.ctrl_dyn_addr, "virt_static_addr": 0x0, "virt_dyn_addr": 0x0}, # Mode 3 = ACT Controller
            {"idx": 2, "mode": 2, "static_addr": addr_helper.trgt_static_addr, "dyn_addr": addr_helper.trgt_dyn_addr, "virt_static_addr": addr_helper.trgt_virt_static_addr, "virt_dyn_addr": addr_helper.trgt_virt_dyn_addr}, # Mode 2 = ACT Target
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

@cocotb.test(timeout_time=20000, timeout_unit='us')
async def test_i3c_private_read_no_edge_case(dut):
    """
    Tests I3C Private Read transfers with randomized payload lengths (RX_STAT_THLD to RX_QUEUE_DEPTH) and randomized data.
    Checks if Controller reads the same data as the target writes
    """

    # Setup
    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr
    dut.areset_n[0].value = 0
    dut._log.info("Reset unused i3c core.")

    RX_QUEUE_DEPTH = 64

    target_len = random.randint(RX_STAT_THLD * 4, 20)
    dut._log.info(f"Data Length is {target_len} bytes")
    cmd_desc = regular_transfer_descriptor_direct(
        tid=0x1,
        i2c=0x0,
        cmd=0x0,
        cp=0x0,
        device_address=addr_helper.trgt_dyn_addr,
        short_read_err=0x0,
        defining_byte_present=0x0,
        mode=0x0,
        rnw=0x1,
        wroc=True,
        toc=True,
        def_byte=0x0,
        data_length=target_len,
    )

    num_words = (target_len + 3) // 4
    # Setup

    data = [random.getrandbits(32) for _ in range(num_words)]

    # Masking the last word
    remainder = target_len % 4
    if remainder != 0:
        mask = (1 << (remainder * 8)) - 1
        data[-1] = data[-1] & mask



    await tb.put_tx_tti_data(data, data_length=target_len, bus_idx=ACT_TARGET_IDX)
    dut._log.info("Filling TTI TX Queue...")

    await tb.put_command_desc(cmd_desc.to_int(), bus_idx=1)
    dut._log.info("Sent command descriptor.")

    resp_desc = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
    dut._log.info(
        f"Received Response Descriptor with TID: {resp_desc.tid}, Data length: {resp_desc.data_length}, Error Status: {resp_desc.err_status}"
    )
    assert resp_desc.data_length == cmd_desc.data_length
    assert resp_desc.tid == cmd_desc.tid
    assert resp_desc.err_status == ErrorStatus(0) # Success


    # Read RX queue
    ctrl_rx_queue_addr = tb.reg_map.PIOCONTROL.RX_DATA_PORT.base_addr
    recv_data = await tb.read_rx_queue(num_words, bus_idx=ACT_CONTROLLER_IDX, rx_port_addr=ctrl_rx_queue_addr)
    dut._log.info("Finished reading RX Queue.")

    actual_val = recv_data
    expected_val = data
    # Compare

    for i, (expected, actual) in enumerate(zip(expected_val, actual_val)):
        if expected != actual:
            dut._log.error(f"Mismatch at word {i}: Expected {expected:x} vs Received {actual:x}")
    assert expected_val == actual_val

@cocotb.test(timeout_time=20000, timeout_unit='us')
async def test_i3c_private_read_short_read(dut):
    """
    Tests I3C Private Read transfers with randomized payload lengths (RX_STAT_THLD to target_len) and randomized data.
    Checks if Controller reads the same data as the target writes and if it correctly asserts the Short Read Error
    """

    # Setup
    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr
    dut.areset_n[0].value = 0
    dut._log.info("Reset unused i3c core.")

    RX_QUEUE_DEPTH = 64

    target_len = random.randint(RX_STAT_THLD * 4 + 1, 20)
    dut._log.info(f"Data Length is {target_len} bytes")
    cmd_desc = regular_transfer_descriptor_direct(
        tid=0x1,
        i2c=0x0,
        cmd=0x0,
        cp=0x0,
        device_address=addr_helper.trgt_dyn_addr,
        short_read_err=0x1,
        defining_byte_present=0x0,
        mode=0x0,
        rnw=0x1,
        wroc=0x1,
        toc=True,
        def_byte=0x0,
        data_length=target_len,
    )

    target_data_len = random.randint(RX_STAT_THLD*4, target_len-1)
    num_words = (target_data_len + 3) // 4
    # Setup

    data = [random.getrandbits(32) for _ in range(num_words)]

    # Masking the last word
    remainder = target_data_len % 4
    if remainder != 0:
        mask = (1 << (remainder * 8)) - 1
        data[-1] = data[-1] & mask



    await tb.put_tx_tti_data(data, data_length=target_data_len, bus_idx=ACT_TARGET_IDX) # target sends less data than expected
    dut._log.info(f"Filling TTI TX Queue with {target_data_len} bytes...")

    await tb.put_command_desc(cmd_desc.to_int(), bus_idx=1)
    dut._log.info("Sent command descriptor.")

    # Read Resp descriptor
    if cmd_desc.wroc:
        resp_desc = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
        dut._log.info(
            f"Received Response Descriptor with TID: {resp_desc.tid}, Data length: {resp_desc.data_length}, Error Status: {resp_desc.err_status}"
        )
        assert resp_desc.data_length == target_data_len
        assert resp_desc.tid == cmd_desc.tid
        assert resp_desc.err_status == 7 # I3C_SHORT_READ

    # Read RX queue
    ctrl_rx_queue_addr = tb.reg_map.PIOCONTROL.RX_DATA_PORT.base_addr
    recv_data = await tb.read_rx_queue(num_words, bus_idx=ACT_CONTROLLER_IDX, rx_port_addr=ctrl_rx_queue_addr)
    dut._log.info("Finished reading RX Queue.")

    actual_val = recv_data
    expected_val = data
    # Compare
 
    
    for i, (expected, actual) in enumerate(zip(expected_val, actual_val)):
        if expected != actual:
            dut._log.error(f"Mismatch at word {i}: Expected {expected:x} vs Received {actual:x}")
    assert expected_val == actual_val


