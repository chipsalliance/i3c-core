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
TX_READY_THLD = 0x1 # TX ready threshold
TX_START_THLD = 0x1 # TX start threshold

# Wraps cocotb.test with a default timeout
def cocotb_test(timeout=10000, unit="us", expect_fail=False, expect_error=(), skip=False, stage=0):
    def wrapper(func):
        @cocotb.test(
            timeout_time=timeout,
            timeout_unit=unit,
            expect_fail=expect_fail,
            expect_error=expect_error,
            skip=skip,
            stage=stage,
        )
        @functools.wraps(func)
        async def runCocotb(*args, **kwargs):
            await func(*args, **kwargs)

        return runCocotb
    return wrapper


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

@cocotb_test()
async def test_i3c_private_write_target_read(dut):

    cmd_desc = immediate_transfer_descriptor_direct(
            tid=0x1,
            i2c=False,
            cmd=0,
            cp=False,
            device_address=0x50,
            dtt=4,      
            mode=0,
            rnw=False,
            wroc=False,
            toc=True,  
            data=random.getrandbits(32)
        )

    # Setup
    i3c_controller, tb = await test_setup(dut)

    #Heartbeat
    async def heartbeat():
        while True:
            await Timer(1000, units='ns')
            dut._log.debug("Heartbeat: Still alive at %s" % cocotb.utils.get_sim_time(units='ns'))

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
    hb = cocotb.start_soon(heartbeat())
    # Start the device firmware agent
    #rx = cocotb.start_soon(rx_agent())
    

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
    dut._log.info(
        f"Received data {actual_val:x}"
    )
    assert expected_val == actual_val


@cocotb_test()
async def test_i3c_private_write_tx_queue_target_read(dut):
    """
    Tests I3C Private Write transfers with randomized payload lengths (1 byte to FIFO depth) and randomized data.
    Verifies data integrity and correct handling of non-word-aligned sizes by comparing
    the Controller's TX Queue input against the Target's RX Queue output with proper masking.
    """

    # Setup
    i3c_controller, tb = await test_setup(dut)
    TX_QUEUE_DEPTH = tb.tx_queue_depth
    dut._log.info(f"TX_QUEUE_DEPTH is {TX_QUEUE_DEPTH}")

    target_len = random.randint(1, TX_QUEUE_DEPTH * 4) # cap the data length at 3x TX queue length such that the tests finish in a reasonable time
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
        rnw=0x0,
        wroc=0x0,
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

    async def heartbeat():
        while True:
            await Timer(1000, units='ns')
            dut._log.debug("Heartbeat: Still alive at %s" % cocotb.utils.get_sim_time(units='ns'))
    hb = cocotb.start_soon(heartbeat())

    data_write = cocotb.start_soon(tb.put_tx_data(data, bus_idx=1))
    await data_write

    actual_write = cocotb.start_soon(tb.put_command_desc(cmd_desc.to_int(), bus_idx=1))
    await actual_write

    await ClockCycles(tb.clk, (250 + (300 * target_len)) * 2)

    # Read RX descriptor
    recv_data = await tb.read_rx_queue(num_words, bus_idx=ACT_TARGET_IDX)

    actual_val = recv_data
    expected_val = data
    # Compare
    for i, (expected, actual) in enumerate(zip(expected_val, actual_val)):
        if expected != actual:
            dut._log.error(f"Mismatch at word {i}: Expected {expected:x} vs Received {actual:x}")
    assert expected_val == actual_val

@cocotb_test()
async def test_i3c_private_write_tx_queue_target_read_fifo_full(dut):
    """
    Tests I3C Private Write transfers with randomized payload lengths (FIFO depth to 3x FIFO depth) and randomized data.
    Verifies data integrity and correct handling of non-word-aligned sizes by comparing
    the Controller's TX Queue input against the Target's RX Queue output with proper masking.
    """

    # Setup
    i3c_controller, tb = await test_setup(dut)
    TX_QUEUE_DEPTH = tb.tx_queue_depth

    target_len = random.randint(TX_QUEUE_DEPTH * 4, TX_QUEUE_DEPTH * 4 * 3) # test larger than tx queue length
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
        rnw=0x0,
        wroc=0x0,
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

    async def heartbeat():
        while True:
            await Timer(1000, units='ns')
            dut._log.debug("Heartbeat: Still alive at %s" % cocotb.utils.get_sim_time(units='ns'))
    hb = cocotb.start_soon(heartbeat())

    queue_filled_event = Event()

    data_write = cocotb.start_soon(tb.put_tx_data(data, ready_event=queue_filled_event, tx_queue_depth=TX_QUEUE_DEPTH, tx_thld=TX_READY_THLD, bus_idx=1))
    dut._log.info("Filling TX Queue...")
    await queue_filled_event.wait() 
    dut._log.info("Queue Full. Sending Command Descriptor.")

    actual_write = cocotb.start_soon(tb.put_command_desc(cmd_desc.to_int(), bus_idx=1))
    await actual_write

    await data_write

    await ClockCycles(tb.clk, (250 + (300 * target_len)) * 2)

    # Read RX descriptor
    recv_data = await tb.read_rx_queue(num_words, bus_idx=ACT_TARGET_IDX)

    actual_val = recv_data
    expected_val = data
    # Compare
    for i, (expected, actual) in enumerate(zip(expected_val, actual_val)):
        if expected != actual:
            dut._log.error(f"Mismatch at word {i}: Expected {expected:x} vs Received {actual:x}")
    assert expected_val == actual_val


