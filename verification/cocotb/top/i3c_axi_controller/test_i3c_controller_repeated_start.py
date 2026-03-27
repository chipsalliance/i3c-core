# SPDX-License-Identifier: Apache-2.0
import functools
import logging
import random
from math import ceil

from boot_controller import boot_init
from monitor import BusStateMonitor
from bus2csr import dword2int, int2dword
from hci import immediate_transfer_descriptor_direct, regular_transfer_descriptor_direct
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

async def test_setup(dut, fclk=333.0, fbus=12.5, core_configs=None):
    """
    Sets up controller, target models and top-level core interface
    according to the 'Expected Bus' architecture.
    """

    cocotb.log.setLevel(logging.INFO)
    logging.getLogger("cocotb.3").setLevel(logging.WARNING)
    dut._log.info(f"fclk = {fclk:.3f} MHz")
    dut._log.info(f"fbus = {fbus:.3f} MHz")

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


@cocotb.test()
async def test_i3c_private_write_repeated_start(dut):
    """
    Tests multiple I3C Private Write transfers chained together using Repeated Starts.
    
    Logic:
    - Generates 'num_transfers' distinct write commands.
    - Sets TOC=0 (False) for all transfers except the last one (TOC=1).
    - This forces the controller to generate: [Start] -> [Write 1] -> [Sr] -> [Write 2] -> ... -> [Stop]
    - Verifies that the Target received the continuous stream of data correctly.
    """
    # Setup
    tb, _, addr_helper = await test_setup(dut)
    #i3c_target.address = addr_helper.trgt_dyn_addr
    # TODO: enable cocotbext target for this test
    dut.areset_n[0].value = 0
    dut._log.info("Reset unused i3c core.")

    TX_QUEUE_DEPTH = tb.tx_queue_depth

    # Configuration
    num_transfers = 5
    min_len = 1
    max_len = 20 # for now keep it relatively small TODO: increase this
    
    all_cmd_descs = []
    complete_expected_data = []

    dut._log.info(f"Generating {num_transfers} chained transfers...")
    
    queue_filled_event = Event()
    for i in range(num_transfers):
        is_last = (i == num_transfers - 1)
        
        target_len = random.randint(min_len, max_len)
        num_words = (target_len + 3) // 4
        current_data = [random.getrandbits(32) for _ in range(num_words)]
        
        remainder = target_len % 4
        if remainder != 0:
            mask = (1 << (remainder * 8)) - 1
            current_data[-1] = current_data[-1] & mask
            
        complete_expected_data.extend(current_data)
        
        cmd_desc = regular_transfer_descriptor_direct(
            tid=i+1,                 # Incrementing TID for debug clarity
            i2c=0x0,
            cmd=0x0,
            cp=0x0,
            device_address=addr_helper.trgt_dyn_addr,
            short_read_err=0x0,
            defining_byte_present=0x0,
            mode=0x0,
            rnw=0x0,
            wroc=random.getrandbits(1) | is_last,
            toc=is_last,
            def_byte=0x0,
            data_length=target_len,
        )
        all_cmd_descs.append(cmd_desc)
        dut._log.info(f"Transfer {i}: Len={target_len}, TOC={is_last}")


        dut._log.info("Filling TX Queue...")
        await tb.put_tx_data(current_data, ready_event=queue_filled_event, tx_queue_depth=TX_QUEUE_DEPTH, tx_thld=TX_READY_THLD, bus_idx=1)
        dut._log.info("Data sent. Sending Command Descriptor.")

        await tb.put_command_desc(cmd_desc.to_int(), bus_idx=1)

        # Read Resp descriptor
        if cmd_desc.wroc:
            dut._log.info("Waiting for Response Descriptor...")
            resp_desc = await tb.read_resp_desc(bus_idx=1)
            dut._log.info(
                f"Received Response Descriptor with TID: {resp_desc.tid}, Data length: {resp_desc.data_length}, Error Status: {resp_desc.err_status}"
            )
            assert resp_desc.data_length == target_len
            assert resp_desc.tid == cmd_desc.tid


    # Read RX descriptor
    dut._log.info("Reading TTI RX Data Queue...")
    recv_data = await tb.read_rx_queue(len(complete_expected_data), bus_idx=ACT_TARGET_IDX)

    actual_val = recv_data
    expected_val = complete_expected_data
    # Compare
 
    
    for i, (expected, actual) in enumerate(zip(expected_val, actual_val)):
        if expected != actual:
            dut._log.error(f"Mismatch at word {i}: Expected {expected:x} vs Received {actual:x}")
    assert expected_val == actual_val

@cocotb.test(timeout_time=20000, timeout_unit='us')
async def test_i3c_private_read_repeated_start(dut):
    """
    Tests multiple I3C Private Read transfers chained together using Repeated Starts.
    
    Logic:
    - Generates 'num_transfers' distinct read commands.
    - Sets TOC=0 (False) for all transfers except the last one (TOC=1).
    - This forces the controller to generate: [Start] -> [Read 1] -> [Sr] -> [Read 2] -> ... -> [Stop]
    - Feeds all data into the TTI TX FIFO concurrently to avoid deadlocks.
    - Verifies that the Controller received the continuous stream of data correctly.
    """
    # Setup
    tb, _, addr_helper = await test_setup(dut)
    #i3c_target.address = addr_helper.trgt_dyn_addr
    # TODO: enable cocotbext target for this test
    dut.areset_n[0].value = 0
    dut._log.info("Reset unused i3c core.")

    RX_QUEUE_DEPTH = 64

    # Configuration
    num_transfers = 5
    min_len = 1
    max_len = 20 # Keep it short for simulation runtime
    
    all_cmd_descs = []
    complete_expected_data = []

    dut._log.info(f"Generating {num_transfers} chained transfers...")
    
    for i in range(num_transfers):
        is_last = (i == num_transfers - 1)
        
        target_len = random.randint(min_len, max_len)
        num_words = (target_len + 3) // 4
        current_data = [random.getrandbits(32) for _ in range(num_words)]
        
        remainder = target_len % 4
        if remainder != 0:
            mask = (1 << (remainder * 8)) - 1
            current_data[-1] = current_data[-1] & mask
            
        complete_expected_data.extend(current_data)
        
        cmd_desc = regular_transfer_descriptor_direct(
            tid=i+1,                 # Incrementing TID for debug clarity
            i2c=0x0,
            cmd=0x0,
            cp=0x0,
            device_address=addr_helper.trgt_dyn_addr,
            short_read_err=0x1,
            defining_byte_present=0x0,
            mode=0x0,
            rnw=0x1,
            wroc=random.getrandbits(1) | is_last,
            toc=is_last,
            def_byte=0x0,
            data_length=target_len,
        )
        all_cmd_descs.append(cmd_desc)
        dut._log.info(f"Transfer {i}: Len={target_len}, TOC={is_last}")

        dut._log.info("Filling TTI TX Queue...")
        await tb.put_tx_tti_data(current_data, target_len, bus_idx=2)
        dut._log.info("Data sent. Sending Command Descriptor.")
        await tb.put_command_desc(cmd_desc.to_int(), bus_idx=1)

        
        # Read Resp descriptor
        if cmd_desc.wroc:
            dut._log.info("Waiting for Response Descriptor.")
            resp_desc = await tb.read_resp_desc(bus_idx=1)
            dut._log.info(
                f"Received Response Descriptor with TID: {resp_desc.tid}, Data length: {resp_desc.data_length}, Error Status: {resp_desc.err_status}"
            )
            assert resp_desc.data_length == target_len
            assert resp_desc.tid == cmd_desc.tid

    # Read RX descriptor
    dut._log.info("Reading RX Data Queue...")
    ctrl_rx_queue_addr = tb.reg_map.PIOCONTROL.RX_DATA_PORT.base_addr
    recv_data = await tb.read_rx_queue(len(complete_expected_data), bus_idx=ACT_CONTROLLER_IDX, rx_port_addr=ctrl_rx_queue_addr)

    actual_val = recv_data
    expected_val = complete_expected_data
    # Compare
    for i, (expected, actual) in enumerate(zip(expected_val, actual_val)):
        if expected != actual:
            dut._log.error(f"Mismatch at word {i}: Expected {expected:x} vs Received {actual:x}")
    assert expected_val == actual_val

