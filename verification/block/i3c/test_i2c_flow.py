# SPDX-License-Identifier: Apache-2.0

import logging

import cocotb
from cocotb.triggers import ClockCycles, RisingEdge
from hci import ResponseDescriptor, dat_entry, immediate_transfer_descriptor
from interface import I3CTopTestInterface


@cocotb.test()
async def run_write_cmd_queue(dut):
    cocotb.log.setLevel(logging.DEBUG)

    dut.i3c_scl_i.value = 1
    dut.i3c_sda_i.value = 1

    tb = I3CTopTestInterface(dut)
    await tb.setup()

    dut.i3c_fsm_en_i.value = 1

    entry = dat_entry(
        static_addr=0x5A,
        ibi_payload=0,
        ibi_reject=0,
        crr_reject=0,
        ts=0,
        ring_id=0x5A,
        dynamic_addr=0,
        dev_nack_retry_cnt=1,
        device=1,
        autocmd_mask=0xFF,
        autocmd_value=0xFF,
        autocmd_mode=0,
        autocmd_hdr_code=0,
    ).to_int()

    dut._log.debug("Writing DAT entry")
    await tb.write_dat_entry(5, entry)
    await RisingEdge(dut.hclk)

    dut._log.debug("Writing Command Queue descriptor")
    desc = immediate_transfer_descriptor(5, 0, 0, 5, 4, 0, 0, 0, 1, 0xDEADBEEF).to_int()
    await tb.put_command_desc(desc)
    await RisingEdge(dut.i3c_fsm_idle_o)
    await RisingEdge(dut.hclk)

    resp_desc = ResponseDescriptor(data_length=0, tid=5, err_status=0).to_int()
    desc = await tb.get_response_desc()
    assert (
        desc == resp_desc
    ), f"Received incorrect response descriptor: received {hex(desc)}, expected {hex(resp_desc)}"

    await ClockCycles(dut.hclk, 10)
