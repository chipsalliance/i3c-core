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

from controller_interface import I3CTopControllerTestInterface
from controller_interface import get_interrupt_status

import cocotb
from cocotb.triggers import ClockCycles, RisingEdge, Timer, Combine, Event

VALID_I3C_ADDRESSES = (
    [i for i in range(0x03, 0x3E)]
    + [i for i in range(0x3F, 0x5B)]
    + [i for i in range(0x5C, 0x5E)]
    + [i for i in range(0x5F, 0x6E)]
    + [i for i in range(0x6F, 0x76)]
    + [i for i in range(0x77, 0x7A)]
    + [0x7B, 0x7D]
)
ACT_TARGET_IDX = 2 # Port idx of actual target
ACT_CONTROLLER_IDX = 1 # Port idx of actual controller
RX_READY_THLD = 0x1 # RX ready threshold
RX_STAT_THLD = 0x1 # RX start threshold

async def test_setup(dut, fclk=333.0, fbus=12.5):
    """
    Sets up controller, target models and top-level core interface
    according to the 'Expected Bus' architecture.
    """

    cocotb.log.setLevel(logging.INFO)
    logging.getLogger("cocotb.3").setLevel(logging.WARNING)
    dut._log.info(f"fclk = {fclk:.3f} MHz")
    dut._log.info(f"fbus = {fbus:.3f} MHz")

    # 1. Controller Sim (cocotbext) connected to Expected Bus
    #    Sim Controller drives 'exp_bus_sda/scl'
    #    DUT outputs 'sda/scl_sim_ctrl_i' (inputs to RTL)
    i3c_controller = I3cController(
        sda_i=dut.exp_bus_sda,
        sda_o=dut.sda_sim_ctrl_i,
        scl_i=dut.exp_bus_scl,
        scl_o=dut.scl_sim_ctrl_i,
        debug_state_o=None,
        speed=fbus * 1e6,
    )

    # 2. Instantiate the Multi-Port Test Interface
    tb = I3CTopControllerTestInterface(dut, num_busses=3)
    
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

    # 1. Schedule all boots
    tasks = []
    for cfg in core_configs:
        t = cocotb.start_soon(
            boot_init(
                tb, 
                bus_idx=cfg["idx"], 
                mode=cfg["mode"], 
                static_addr=cfg["addr"],
                verify=True
            )
        )
        tasks.append(t)

    # 2. Wait for all to complete
    await cocotb.triggers.Combine(*[t.join() for t in tasks])
    
    dut._log.info("All cores booted successfully.")

    return i3c_controller, tb    

@cocotb.test(timeout_time=20000, timeout_unit='us')
async def test_i3c_private_read_no_edge_case(dut):
    """
    Tests I3C Private Read transfers with randomized payload lengths (RX_STAT_THLD to RX_QUEUE_DEPTH) and randomized data.
    Checks if Controller reads the same data as the target writes
    """

    # Setup
    i3c_controller, tb = await test_setup(dut)
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
        device_address=0x50,
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
    i3c_controller, tb = await test_setup(dut)
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
        device_address=0x50,
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


