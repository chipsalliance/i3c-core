# SPDX-License-Identifier: Apache-2.0
import functools
import logging
import random
from math import ceil

from boot_controller import boot_init
from monitor import BusStateMonitor
from bus2csr import dword2int, int2dword
from hci import immediate_transfer_descriptor_direct, regular_transfer_descriptor_direct, ResponseDescriptor, ErrorStatus, immediate_transfer_descriptor, regular_transfer_descriptor
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_target import I3CTarget

from controller_interface import I3CTopControllerTestInterface, I3CAddressHelper
from controller_interface import get_interrupt_status

import cocotb
from cocotb.triggers import ClockCycles, RisingEdge, Timer, Combine, Event

ACT_TARGET_IDX = 2 # Port idx of actual target
ACT_CONTROLLER_IDX = 1 # Port idx of actual controller
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
async def test_i3c_private_write_target_read(dut):
    # Setup
    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr
    dut.areset_n[0].value = 0
    dut._log.info("Reset unused i3c core.")

    cmd_desc = immediate_transfer_descriptor_direct(
            tid=0x1,
            i2c=False,
            cmd=0,
            cp=False,
            device_address=addr_helper.trgt_dyn_addr,
            dtt=4,      
            mode=0,
            rnw=False,
            wroc=False,
            toc=True,  
            data=random.getrandbits(32)
        )

    # Monitor
    """
    async def rx_agent():
        nonlocal recv_data

        # Enable RX descriptor interrupt
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.TTI.RX_DESC_THLD_STAT.base_addr,
            tb.reg_map.I3C_EC.TTI.RX_DESC_THLD_STAT.START_THLD,
            0,  # Try 0 first (often means '1 entry'), or 1.
            bus_idx=ACT_TARGET_IDX
        )

        await tb.write_csr_field(
            tb.reg_map.I3C_EC.TTI.INTERRUPT_ENABLE.base_addr,
            tb.reg_map.I3C_EC.TTI.INTERRUPT_ENABLE.RX_DESC_STAT_EN,
            1, 
            bus_idx=ACT_TARGET_IDX
        )

        for i, tx_data in enumerate(test_data):

            # Wait for the interrupt signal to go high
            irq = dut.irq_o[ACT_TARGET_IDX]
            while irq.value == 0:
                await RisingEdge(tb.clk)

            # Read & check interrupt status
            intrs = await get_interrupt_status(tb, ACT_TARGET_IDX)
            assert intrs["RX_DESC_STAT"] == 1

            # Read RX descriptor, the interrupt should go low
            data = dword2int(
                await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4, bus_idx=ACT_TARGET_IDX)
            )
            desc_len = data & 0xFFFF

            # Examine the descriptor
            assert len(tx_data) == desc_len, "Incorrect number of bytes in RX descriptor"
            remainder = desc_len % 4

            err_stat = data >> 28
            assert err_stat == 0, "Unexpected error detected"

            # Wait for the interrupt signal to go low
            irq = dut.irq_o[ACT_TARGET_IDX]
            while irq.value != 0:
                await RisingEdge(tb.clk)

            # Read & check interrupt status
            intrs = await get_interrupt_status(tb, ACT_TARGET_IDX)
            assert intrs["RX_DESC_STAT"] == 0

            # Read RX data
            data_len = ceil(desc_len / 4)
            rx_data = []
            for _ in range(data_len):
                data = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, 4, bus_idx=ACT_TARGET_IDX))
                for k in range(4):
                    rx_data.append((data >> (k * 8)) & 0xFF)

            # Remove entries that are outside of the data length
            if remainder:
                for k in range(4 - remainder):
                    rx_data.pop()

            recv_data.append(rx_data)

    """

    actual_write = cocotb.start_soon(tb.put_command_desc(cmd_desc.to_int(), bus_idx=1))

    await actual_write

    await ClockCycles(tb.clk, 4000)
    # Read RX descriptor
    recv_data = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, bus_idx=ACT_TARGET_IDX)
    )
    data_mask = (1 << (cmd_desc.dtt * 8)) - 1

    actual_val = recv_data & data_mask
    expected_val = cmd_desc.data & data_mask
    # Compare

    # Read Resp descriptor
    if cmd_desc.wroc:
        resp_desc = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
        dut._log.info(
            f"Received Response Descriptor with TID: {resp_desc.tid}, Data length: {resp_desc.data_length}, Error Status: {resp_desc.err_status}"
        )
        assert resp_desc.data_length == cmd_desc.dtt
        assert resp_desc.tid == cmd_desc.tid

    dut._log.info(
        f"Received data {actual_val:x}"
    )
    assert expected_val == actual_val


@cocotb.test()
async def test_i3c_private_write_target_read_resp_desc(dut):
    # Setup
    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr

    cmd_desc = immediate_transfer_descriptor_direct(
            tid=0x1,
            i2c=False,
            cmd=0,
            cp=False,
            device_address=addr_helper.trgt_dyn_addr,
            dtt=4,      
            mode=0,
            rnw=False,
            wroc=True,
            toc=True,  
            data=random.getrandbits(32)
        )
    dut.areset_n[0].value = 0
    dut._log.info("Reset unused i3c core.")


    actual_write = cocotb.start_soon(tb.put_command_desc(cmd_desc.to_int(), bus_idx=1))

    await actual_write

    await ClockCycles(tb.clk, 4000)
    # Read RX descriptor
    recv_data = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, bus_idx=ACT_TARGET_IDX)
    )
    data_mask = (1 << (cmd_desc.dtt * 8)) - 1

    # Read Resp descriptor
    resp_desc = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
    dut._log.info(
        f"Received Response Descriptor with TID: {resp_desc.tid}, Data length: {resp_desc.data_length}, Error Status: {resp_desc.err_status}"
    )
    assert resp_desc.data_length == cmd_desc.dtt
    assert resp_desc.tid == cmd_desc.tid
    actual_val = recv_data & data_mask
    expected_val = cmd_desc.data & data_mask
    # Compare
    dut._log.info(
        f"Received data {actual_val:x}"
    )
    assert expected_val == actual_val

@cocotb.test()
async def test_i3c_private_write_wrong_target_addr(dut):
    # Setup
    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr
    dut.areset_n[0].value = 0
    dut._log.info("Reset unused i3c core.")

    wrong_addr = addr_helper.get_unassigned_valid_address()

    cmd_desc = immediate_transfer_descriptor_direct(
            tid=0x1,
            i2c=False,
            cmd=0,
            cp=False,
            device_address=wrong_addr,
            dtt=4,      
            mode=0,
            rnw=False,
            wroc=True,
            toc=True,  
            data=random.getrandbits(32)
        )

    actual_write = cocotb.start_soon(tb.put_command_desc(cmd_desc.to_int(), bus_idx=1))

    await actual_write

    await ClockCycles(tb.clk, 4000)
   
    # Read Resp descriptor
    resp_desc = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
    dut._log.info(
        f"Received Response Descriptor with TID: {resp_desc.tid}, Data length: {resp_desc.data_length}, Error Status: {resp_desc.err_status}"
    )
    assert resp_desc.data_length == 0
    assert resp_desc.tid == cmd_desc.tid
    assert resp_desc.err_status == ErrorStatus(5) # NACK

@cocotb.test()
async def test_i3c_private_write_tx_queue_target_read(dut):
    """
    Tests I3C Private Write transfers with randomized payload lengths (1 byte to FIFO depth) and randomized data.
    Verifies data integrity and correct handling of non-word-aligned sizes by comparing
    the Controller's TX Queue input against the Target's RX Queue output with proper masking.
    """

    # Setup
    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr
    dut.areset_n[0].value = 0
    dut._log.info("Reset unused i3c core.")

    TX_QUEUE_DEPTH = tb.tx_queue_depth
    dut._log.info(f"TX_QUEUE_DEPTH is {TX_QUEUE_DEPTH}")

    target_len = random.randint(1, TX_QUEUE_DEPTH * 4) # cap the data length at 3x TX queue length such that the tests finish in a reasonable time
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
        rnw=0x0,
        wroc=random.getrandbits(1),
        toc=True,
        def_byte=0x0,
        data_length=target_len,
    )

    num_words = (target_len + 3) // 4

    data = [random.getrandbits(32) for _ in range(num_words)]

    # Masking the last word
    remainder = target_len % 4
    if remainder != 0:
        mask = (1 << (remainder * 8)) - 1
        data[-1] = data[-1] & mask

    data_write = cocotb.start_soon(tb.put_tx_data(data, bus_idx=1))
    await data_write

    actual_write = cocotb.start_soon(tb.put_command_desc(cmd_desc.to_int(), bus_idx=1))
    await actual_write

    await ClockCycles(tb.clk, (1000 + (300 * target_len)) * 2)

    # Read RX descriptor
    recv_data = await tb.read_rx_queue(num_words, bus_idx=ACT_TARGET_IDX)

    actual_val = recv_data
    expected_val = data

    # Read Resp descriptor
    if cmd_desc.wroc:
        resp_desc = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
        dut._log.info(
            f"Received Response Descriptor with TID: {resp_desc.tid}, Data length: {resp_desc.data_length}, Error Status: {resp_desc.err_status}"
        )
        assert resp_desc.data_length == cmd_desc.data_length
        assert resp_desc.tid == cmd_desc.tid

    # Compare
    for i, (expected, actual) in enumerate(zip(expected_val, actual_val)):
        if expected != actual:
            dut._log.error(f"Mismatch at word {i}: Expected {expected:x} vs Received {actual:x}")
    assert expected_val == actual_val

@cocotb.test()
async def test_i3c_private_write_tx_queue_target_read_fifo_full(dut):
    """
    Tests I3C Private Write transfers with randomized payload lengths (FIFO depth to 3x FIFO depth) and randomized data.
    Verifies data integrity and correct handling of non-word-aligned sizes by comparing
    the Controller's TX Queue input against the Target's RX Queue output with proper masking.
    """

    # Setup
    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr
    TX_QUEUE_DEPTH = tb.tx_queue_depth

    target_len = random.randint(TX_QUEUE_DEPTH * 4, TX_QUEUE_DEPTH * 4 * 3) # test larger than tx queue length
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
        rnw=0x0,
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

    queue_filled_event = Event()

    data_write = cocotb.start_soon(tb.put_tx_data(data, ready_event=queue_filled_event, tx_queue_depth=TX_QUEUE_DEPTH, tx_thld=TX_READY_THLD, bus_idx=1))
    dut._log.info("Filling TX Queue...")
    await queue_filled_event.wait() 
    dut._log.info("Queue Full. Sending Command Descriptor.")

    actual_write = cocotb.start_soon(tb.put_command_desc(cmd_desc.to_int(), bus_idx=1))
    await actual_write

    await data_write

    # Read Resp descriptor
    if cmd_desc.wroc:
        resp_desc = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
        dut._log.info(
            f"Received Response Descriptor with TID: {resp_desc.tid}, Data length: {resp_desc.data_length}, Error Status: {resp_desc.err_status}"
        )
        assert resp_desc.data_length == cmd_desc.data_length
        assert resp_desc.tid == cmd_desc.tid


    # Read RX descriptor
    recv_data = await tb.read_rx_queue(num_words, bus_idx=ACT_TARGET_IDX)

    actual_val = recv_data
    expected_val = data
    # Compare
 
    for i, (expected, actual) in enumerate(zip(expected_val, actual_val)):
        if expected != actual:
            dut._log.error(f"Mismatch at word {i}: Expected {expected:x} vs Received {actual:x}")
    assert expected_val == actual_val

async def write_i3c_dat(tb, addr_helper, payload, target_len, immediate=None, device_index=0x0, toc=True):
    await tb.put_dat_entry(device_index=device_index, dyn_addr=addr_helper.trgt_dyn_addr, static_addr=addr_helper.trgt_static_addr, is_i2c=False, bus_idx=ACT_CONTROLLER_IDX)

    if immediate == None:
        immediate = random.getrandbits(1)
    if immediate and len(payload) == 1:
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
        await tb.put_command_desc(cmd_desc.to_int(), bus_idx=ACT_CONTROLLER_IDX)
    else:
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
        queue_filled_event = Event()
        data_write = cocotb.start_soon(tb.put_tx_data(payload, ready_event=queue_filled_event, tx_thld=TX_READY_THLD, bus_idx=ACT_CONTROLLER_IDX))
        await queue_filled_event.wait()
        await tb.put_command_desc(cmd_desc.to_int(), bus_idx=ACT_CONTROLLER_IDX)
        await data_write

    # Wait for response Descriptor when it's the last cmd descriptor
    resp_desc = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
    assert resp_desc.err_status == ErrorStatus.SUCCESS
    assert resp_desc.data_length == target_len
    assert resp_desc.tid == cmd_desc.tid

    await ClockCycles(tb.clk, 100)

    num_words = (target_len + 3) // 4
    # Read RX descriptor
    recv_data = await tb.read_rx_queue(num_words, bus_idx=ACT_TARGET_IDX)

    actual_val = recv_data
    expected_val = payload
    # Compare
 
    for i, (expected, actual) in enumerate(zip(expected_val, actual_val)):
        if expected != actual:
            tb.dut._log.error(f"Mismatch at word {i}: Expected {expected:x} vs Received {actual:x}")
    assert expected_val == actual_val

@cocotb.test()
async def test_i3c_private_write_dat(dut):
    # Setup
    tb, i3c_target, addr_helper = await test_setup(dut)
    i3c_target.address = addr_helper.trgt_dyn_addr

    #target_len = random.randint(tb.tx_queue_depth * 4, tb.tx_queue_depth * 4 * 3) # test larger than tx queue length
    target_len = 7
    num_words = (target_len + 3) // 4
    # Setup

    data = [random.getrandbits(32) for _ in range(num_words)]
    # Masking the last word
    remainder = target_len % 4
    if remainder != 0:
        mask = (1 << (remainder * 8)) - 1
        data[-1] = data[-1] & mask


    tb.dut._log.info("Starting I3C private write")
    await write_i3c_dat(tb, addr_helper=addr_helper, payload=data, target_len=target_len, immediate=False, device_index=0x0, toc=True)
    tb.dut._log.info("Finished I3C private write")



