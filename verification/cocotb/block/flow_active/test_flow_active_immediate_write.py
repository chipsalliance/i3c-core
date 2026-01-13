# SPDX-License-Identifier: Apache-2.0

import logging
import random

from common_methods import test_write, test_read, test_write_read
from common_flow_active import FmtTransaction
from common_flow_active import FlowActiveTestInterface
from hci import immediate_transfer_descriptor_direct

from cocotb_helpers import cycle, reset_n

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.queue import Queue, QueueEmpty, QueueFull
from cocotb.triggers import ClockCycles, RisingEdge

def reference_model_predictor(cmd_desc):
    """
    Inputs:
        descriptor_val: The 64-bit command descriptor integer.
    Returns:
        List[FmtTransaction]
    """
    expected_trans_queue = []
    
    addr_byte = (cmd_desc.device_address << 1) | 0  # Write bit (0)
    
    # Create Address Transaction (Start + Addr)
    expected_trans_queue.append(FmtTransaction(byte=addr_byte, start=1, stop=0))
    
    data_bytes = [(cmd_desc.data >> (i * 8)) & 0xFF for i in range(4)]
    
    # Create Data Transactions
    for i, data in enumerate(data_bytes):
        is_last_byte = (i == cmd_desc.dtt - 1)
        
        # Logic for STOP flag: typically only on the very last byte if TOC=1
        should_stop = 1 if (is_last_byte and cmd_desc.toc) else 0
        
        expected_trans_queue.append(FmtTransaction(byte=data, start=0, stop=should_stop))
        if(should_stop): 
            break
        
    return expected_trans_queue

# Monitor function
async def fmt_monitor(dut, captured_trans_queue):
    """
    Monitors the fmt interface and pushes observed transactions to a queue.
    """
    while True:
        await RisingEdge(dut.fmt_fifo_rdone_i)
        # Only capture if Valid AND Ready (handshake complete)
        if dut.fmt_fifo_rvalid_o.value == 1 and dut.fmt_fifo_rready_i.value == 1:
            trans = FmtTransaction(
                byte=int(dut.fmt_byte_o.value),
                start=int(dut.fmt_flag_start_before_o.value),
                stop=int(dut.fmt_flag_stop_after_o.value)
            )
            captured_trans_queue.append(trans)
            dut._log.info(f"[Monitor] Captured: {trans}")

# Stimulate fmt_fifo_rdone_i
async def fifo_done(tb):
    tb.dut.fmt_fifo_rdone_i.value = 0
    while True:
        # 5 cycles per bit translates to 10ns -> we are able to handle I3C speeds 
        await ClockCycles(tb.clk, 5)
        tb.dut.fmt_fifo_rdone_i.value = 1
        tb.dut._log.info(f"fmt_fifo_rdone_i was pulsed to {tb.dut.fmt_fifo_rdone_i.value}")
        await ClockCycles(tb.clk, 1)
        tb.dut.fmt_fifo_rdone_i.value = 0
        tb.dut._log.info(f"fmt_fifo_rdone_i is back at {tb.dut.fmt_fifo_rdone_i.value}")

@cocotb.test()
async def test_immediate_write(dut: SimHandleBase):
    """
    Test sending data to the bus
    """
    # Setup testbench
    tb = FlowActiveTestInterface(dut)
    await tb.setup()

    dut.fmt_fifo_rdone_i.value = 0
    await ClockCycles(dut.aclk, 100) 

    # Create Command Descriptor
    commands = [
        immediate_transfer_descriptor_direct(
            tid=0x1,
            i2c=False,
            cmd=0,
            cp=False,
            device_address=0x50,
            dtt=2,      
            mode=0,
            rnw=False,
            wroc=False,
            toc=True,  
            data=0xAABBCCDD
        ),
        immediate_transfer_descriptor_direct(
            tid=0x2,
            i2c=False,
            cmd=0,
            cp=False,
            device_address=0x51,
            dtt=4,  
            mode=0,
            rnw=False,
            wroc=False,
            toc=True,    
            data=0x12345678
        )
    ]

    actual_queue = []
    expected_queue = []
    # Reference prediction
    for cmd_desc in commands:
        expected_queue.extend(reference_model_predictor(cmd_desc))

    # write cmd descriptor to CSR
    for cmd_desc in commands:
        await tb.put_command_desc(cmd_desc.to_int())

    dut._log.info("Successfully sent command descriptors")

    # Get DUT queue
    cocotb.start_soon(fifo_done(tb))
    cocotb.start_soon(fmt_monitor(dut, actual_queue))

    # set fmt_fifo_rready_i signal
    # TODO make this random
    dut.fmt_fifo_rready_i.value = 1

    # Wait for fmt transactions to finish
    await ClockCycles(dut.aclk, 50)

    # Scoreboard
    assert len(actual_queue) == len(expected_queue), "Length mismatch between actual_queue and expected_queue"
    for i in range(len(expected_queue)):
        assert actual_queue[i] == expected_queue[i], \
            f"Mismatch at index {i}: Exp {expected_queue[i]} vs Got {actual_queue[i]}"
