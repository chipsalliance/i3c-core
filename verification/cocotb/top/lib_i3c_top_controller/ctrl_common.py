# SPDX-License-Identifier: Apache-2.0
import random
from bus2csr import dword2int, int2dword
from hci import immediate_transfer_descriptor_direct, regular_transfer_descriptor_direct,  ErrorStatus, regular_transfer_descriptor, immediate_transfer_descriptor, address_assignment_descriptor, internal_control_descriptor
from ccc import CCC

import cocotb
from cocotb.triggers import ClockCycles, Event

ACT_CONTROLLER_IDX = 1 # Port idx of actual controller
ACT_TARGET_IDX = 2 # Port idx of actual target
TX_QUEUE_DEPTH = 64 # Depth of TX_QUEUE in dwords.
TX_READY_THLD = 0x1 # TX ready threshold
TX_START_THLD = 0x1 # TX start threshold

async def write_ccc(tb, addr_helper, ccc, immediate=None, payload=None, data_length=0, device_address=0x50, toc=True, dat=None, device_index=None, bus_idx=ACT_CONTROLLER_IDX):
    # Disable all target events
    no_payload = False
    if dat == None:
        dat = random.getrandbits(1)
    if immediate == None:
        immediate = random.getrandbits(1)
    if dat:
        await tb.put_dat_entry(device_index=device_index, dyn_addr=addr_helper.trgt_dyn_addr, static_addr=addr_helper.trgt_static_addr, is_i2c=False, bus_idx=bus_idx)
    if payload == None:
        no_payload = True
        payload = [0]
    if immediate or no_payload: # no payload CCCs are always immediate transfers
        if dat:
            cmd_desc = immediate_transfer_descriptor(
                tid=random.getrandbits(3),
                cmd=ccc,
                cp=True,
                device_index=device_index,
                byte_count=data_length,
                mode=0,
                rnw=False,
                wroc=0x1,
                toc=toc,  
                data=payload[0]
            )
        else:
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
        if dat:
            cmd_desc = regular_transfer_descriptor(
            tid=random.getrandbits(3),
            cmd=ccc,
            cp=0x1,
            device_index=device_index,
            short_read_err=0x0,
            defining_byte_present=0x0,
            mode=0x0,
            rnw=0x0,
            wroc=True,
            toc=toc,
            def_byte=0x0,
            data_length=data_length,
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
        await tb.put_tx_data(payload, tx_queue_depth=TX_QUEUE_DEPTH, tx_thld=TX_READY_THLD, bus_idx=bus_idx)

    await tb.put_command_desc(cmd_desc.to_int(), bus_idx=bus_idx)
    # Wait for response Descriptor when it's the last cmd descriptor
    if toc:
        resp_desc = await tb.read_resp_desc(bus_idx=bus_idx)
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


async def write_i3c(tb, addr_helper, payload, target_len, immediate=None, device_address=0x50, toc=True, dat=None, device_index=None, expect_success=True, bus_idx=ACT_CONTROLLER_IDX):
    # Disable all target events
    if dat == None:
        dat = random.getrandbits(1)
        if device_index == None:
            device_index = random.getrandbits(5)
    if immediate == None:
        immediate = random.getrandbits(1)

    if dat:
        await tb.put_dat_entry(device_index=device_index, dyn_addr=addr_helper.trgt_dyn_addr, static_addr=addr_helper.trgt_static_addr, is_i2c=False, bus_idx=bus_idx)

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
                i2c=False,
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
        await tb.put_command_desc(cmd_desc.to_int(), bus_idx=bus_idx)
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
            i2c=0x0,
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
        data_write = cocotb.start_soon(tb.put_tx_data(payload, ready_event=queue_filled_event, tx_thld=TX_READY_THLD, bus_idx=bus_idx))
        await queue_filled_event.wait()
        await tb.put_command_desc(cmd_desc.to_int(), bus_idx=bus_idx)
        await data_write

    # Wait for response Descriptor when it's the last cmd descriptor
    tb.dut._log.info("Waiting for resp desc")
    resp_desc = await tb.read_resp_desc(bus_idx=bus_idx)
    if expect_success:
        assert resp_desc.err_status == ErrorStatus.SUCCESS
        assert resp_desc.data_length == target_len
        assert resp_desc.tid == cmd_desc.tid

    await ClockCycles(tb.clk, 100)
    num_words = (target_len + 3) // 4
    # Read RX descriptor
    tb.dut._log.info("Waiting for rx queue desc")
    recv_data = await tb.read_rx_queue(num_words, bus_idx=ACT_TARGET_IDX)

    actual_val = recv_data
    expected_val = payload
    # Compare
 
    for i, (expected, actual) in enumerate(zip(expected_val, actual_val)):
        if expected != actual:
            tb.dut._log.error(f"Mismatch at word {i}: Expected {expected:x} vs Received {actual:x}")
    if expect_success:
        assert expected_val == actual_val

async def read_i3c(tb, addr_helper, target_len, device_address=0x50, toc=True, dat=None, device_index=None):
    if dat == None:
        dat = random.getrandbits(1)
        if device_index == None:
            device_index = random.getrandbits(5)

    if dat:
        await tb.put_dat_entry(device_index=device_index, dyn_addr=addr_helper.trgt_dyn_addr, static_addr=addr_helper.trgt_static_addr, is_i2c=False, bus_idx=ACT_CONTROLLER_IDX)
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
        i2c=0x0,
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

    num_words = (target_len + 3) // 4
    data = [random.getrandbits(32) for _ in range(num_words)]
    # Masking the last word
    remainder = target_len % 4
    if remainder != 0:
        mask = (1 << (remainder * 8)) - 1
        data[-1] = data[-1] & mask

    await tb.put_tx_tti_data(data, data_length=target_len, bus_idx=ACT_TARGET_IDX)
    tb.dut._log.info("Filling TTI TX Queue...")

    tb.dut._log.info("Sending Command Descriptor for I3C private read")
    await tb.put_command_desc(cmd_desc.to_int(), bus_idx=ACT_CONTROLLER_IDX)

    # Wait for response Descriptor when it's the last cmd descriptor
    resp_desc = await tb.read_resp_desc(bus_idx=ACT_CONTROLLER_IDX)
    tb.dut._log.info("Finished I3C private read")
    assert resp_desc.err_status == ErrorStatus.SUCCESS
    assert resp_desc.data_length == target_len
    assert resp_desc.tid == cmd_desc.tid

    # Read RX queue
    tb.dut._log.info("Starting to read the RX Queue.")
    ctrl_rx_queue_addr = tb.reg_map.PIOCONTROL.RX_DATA_PORT.base_addr
    recv_data = await tb.read_rx_queue((target_len + 3) // 4, bus_idx=ACT_CONTROLLER_IDX, rx_port_addr=ctrl_rx_queue_addr)
    tb.dut._log.info("Finished reading RX Queue.")
    actual_val = recv_data
    expected_val = data
    # Compare
    for i, (expected, actual) in enumerate(zip(expected_val, actual_val)):
        if expected != actual:
            tb.dut._log.error(f"Mismatch at word {i}: Expected {expected:x} vs Received {actual:x}")
    assert expected_val == actual_val

async def check_ibi(tb, exp_payload, target_dyn_address, expect_err=False, expect_reject=False):
    ibi_status_desc, ibi_payload = await tb.read_ibi(bus_idx=ACT_CONTROLLER_IDX)

    act_dyn_addr = (ibi_status_desc.ibi_id & 0xFE) >> 1
    act_rnw = ibi_status_desc.ibi_id & 0x1

    assert act_dyn_addr == target_dyn_address, f"Mismatch between Dynamic address in IBI Status {act_dyn_addr:x} and Expected dynamic address {target_dyn_address:x}!"
    assert act_rnw == 1, "Expected RnW bit to be 1'b1!"
    if expect_err:
        assert ibi_status_desc.error == 1, "Expected an IBI overflow error, but error bit was 0!"
        tb.dut._log.info(f"Successfully caught expected IBI Error. Hardware saved {len(ibi_payload)} DWORDs.")
        
        truncated_expected = exp_payload[:len(ibi_payload)]
        for i, (expected, actual) in enumerate(zip(truncated_expected, ibi_payload)):
            if expected != actual:
                tb.dut._log.error(f"[Overflow Check] Mismatch at word {i}: Expected {expected:x} vs Received {actual:x}")
        assert truncated_expected == ibi_payload, "Truncated payload mismatch during overflow"

    elif expect_reject:
        assert ibi_status_desc.ibi_sts == 1, "Expected IBI Status to indicate NACK (1'b1)"

    else:
        # Standard success checks
        assert ibi_status_desc.error == 0, f"Unexpected IBI Error encountered!"

        for i, (expected, actual) in enumerate(zip(exp_payload, ibi_payload)):
            if expected != actual:
                tb.dut._log.error(f"Mismatch at word {i}: Expected {expected:x} vs Received {actual:x}")
        
        assert exp_payload == ibi_payload, "Full payload mismatch"

