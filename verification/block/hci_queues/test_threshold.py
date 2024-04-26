# SPDX-License-Identifier: Apache-2.0

from math import log2
from random import randint

import cocotb
from cocotb.handle import SimHandleBase
from cocotb.triggers import RisingEdge
from hci_queues_defs import (
    DATA_BUFFER_THLD_CTRL,
    QUEUE_THLD_CTRL,
    HCIQueuesTestInterface,
)
from test_csr_sw_access import ahb_data_to_int, int_to_ahb_data


async def should_setup_threshold(dut: SimHandleBase, q: str):
    """
    Writes the threshold to appropriate register (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
    Verifies a appropriate value has been written to the CSR.
    Verifies the `_thld_` signal drives the correct value.
    """
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()
    # Bit offset to each queue's threshold
    off = {"rx": 8, "tx": 0, "cmd": 0, "resp": 8}
    # TODO: FIXME when QUEUE_SIZE CSRs are initialized properly
    qsize = {"cmd": 64, "rx": 64, "tx": 64, "resp": 256}
    (thld_bit_size, reg) = (3, DATA_BUFFER_THLD_CTRL) if q in ["tx", "rx"] else (8, QUEUE_THLD_CTRL)
    thld = randint(1, 2**thld_bit_size - 1)
    expected_thld = thld

    if q in ["tx", "rx"] and (1 << (thld + 1)) >= qsize[q]:
        expected_thld = int(log2(qsize[q])) - 1

    if q in ["cmd", "resp"]:
        expected_thld = min(thld, qsize[q] - 1)

    # Setup threshold through appropriate register
    await tb.write_csr(reg, int_to_ahb_data(thld << off[q]), 4)

    await RisingEdge(dut.hclk)

    # Ensure the register reads appropriate value
    reg_value = await tb.read_csr(reg, 4)
    read_thld = ahb_data_to_int(reg_value) >> off[q]

    assert read_thld == thld, (
        f"The {q} queue threshold is not reflected by the register."
        f"Expected {thld} retrieved {read_thld}."
    )

    await RisingEdge(dut.hclk)

    # Check if the threshold signal is properly propagated onto thld_o signal
    s_thld = tb.get_thld(q)
    assert s_thld.integer == expected_thld, (
        f"The thld signal doesn't reflect the CSR-defined value"
        f"Expected {expected_thld} got {s_thld.integer}."
    )


@cocotb.test()
async def run_cmd_setup_threshold_test(dut: SimHandleBase):
    await should_setup_threshold(dut, "cmd")


@cocotb.test()
async def run_rx_setup_threshold_test(dut: SimHandleBase):
    await should_setup_threshold(dut, "rx")


@cocotb.test()
async def run_tx_setup_threshold_test(dut: SimHandleBase):
    await should_setup_threshold(dut, "tx")


@cocotb.test()
async def run_resp_setup_threshold_test(dut: SimHandleBase):
    await should_setup_threshold(dut, "resp")


async def should_raise_apch_thld_receiver(dut: SimHandleBase, q: str):
    """
    After the Response / RX queues have reached a threshold number of elements
    a `apch_thld` signal should be raised (which then will trigger an interrupt)
    """
    assert q in ["resp", "rx"], (
        "This test supports the resp & rx queues."
        "For cmd & tx see should_raise_apch_thld_transmitter."
    )
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()
    off = {"rx": 8, "resp": 8}
    enqueue = {"rx": tb.put_rx_data, "resp": tb.put_response_desc}
    (thld_bit_size, reg) = (3, DATA_BUFFER_THLD_CTRL) if q == "rx" else (8, QUEUE_THLD_CTRL)
    thld = randint(2, 2**thld_bit_size - 1)

    # Setup threshold through appropriate register
    await tb.write_csr(reg, int_to_ahb_data(thld << off[q]), 4)

    QUEUE_SIZE = 0x118
    ALT_QUEUE_SIZE = 0x11C

    queue_size = ahb_data_to_int(await tb.read_csr(QUEUE_SIZE, 4))
    alt_queue_size = ahb_data_to_int(await tb.read_csr(ALT_QUEUE_SIZE, 4))

    cmd_q_size = queue_size & 0xFF
    _ = (queue_size >> 16) & 0xFF  # RX queue size
    resp_size = alt_queue_size & 0xFF

    if not resp_size:
        resp_size = cmd_q_size

    # TODO: FIXME when the QUEUE_SIZE CSRs are properly initialized
    qsize = {"rx": 64, "resp": 256}

    thld = 2 ** (thld + 1) if q == "rx" else thld

    # Enqueue `thld` number of elements & check the reported `apch_thld`
    # If `thld` exceeds the size of the queue, the threshold is set to queue size
    thld = min(thld, qsize[q])

    for _ in range(thld - 1):
        await enqueue[q]()

    await RisingEdge(dut.hclk)

    # Check the `apch_thld` is not set before reaching the threshold
    s_apch_thld = tb.get_apch_thld(q)
    assert s_apch_thld == 0, (
        f"{q} queue: apch_thld is raised before the threshold has been reached."
        f"Threshold: {thld} currently enqueued elements {thld-1}"
    )

    # Reach the threshold
    await enqueue[q]()

    await RisingEdge(dut.hclk)

    # Verify the signal is risen
    s_apch_thld = tb.get_apch_thld(q)
    assert s_apch_thld == 1, (
        f"{q} queue: apch_thld should be raised after reaching the threshold."
        f"Threshold: {thld} currently enqueued elements {thld}"
    )


@cocotb.test()
async def run_resp_should_raise_apch_test(dut: SimHandleBase):
    await should_raise_apch_thld_receiver(dut, "resp")


@cocotb.test()
async def run_rx_should_raise_apch_test(dut: SimHandleBase):
    await should_raise_apch_thld_receiver(dut, "rx")


async def should_raise_apch_thld_transmitter(dut: SimHandleBase, q: str):
    """
    After Command / TX queues have a threshold elements left for the `apch_thld` signal
    to be raised.
    Ensure the `apch_thld` is raised on empty queue & falls down after there's less than
    threshold elements left.
    """
    assert q in ["cmd", "tx"], (
        "This test supports the cmd & tx queues."
        "For resp & rx see should_raise_apch_thld_receiver."
    )
    tb = HCIQueuesTestInterface(dut)
    await tb.setup()
    off = {"tx": 0, "cmd": 0}
    enqueue = {"tx": tb.put_tx_data, "cmd": tb.put_command_desc}
    (thld_bit_size, reg) = (3, DATA_BUFFER_THLD_CTRL) if q == "tx" else (8, QUEUE_THLD_CTRL)
    thld_init = randint(2, 2**thld_bit_size - 1)
    # Setup threshold through appropriate register
    await tb.write_csr(reg, int_to_ahb_data(thld_init << off[q]), 4)

    QUEUE_SIZE = 0x118

    queue_size = ahb_data_to_int(await tb.read_csr(QUEUE_SIZE, 4))
    # TODO: FIXME when the QUEUE_SIZE CSRs are properly initialized
    _ = queue_size & 0xFF  # Command queue size
    _ = queue_size >> 24  # TX queue size
    qsize = {"cmd": 64, "tx": 64}

    # Threshold in DWORDs
    thld = 2 ** (thld_init + 1) if q == "tx" else thld_init

    # If requested threshold exceeds the size of the queue, the size of queue is considered
    thld = min(qsize[q] - 1, thld)

    # Empty queue, check if `apch_thld` properly reports number of empty entires
    s_apch_thld = tb.get_apch_thld(q)
    assert s_apch_thld == 1, (
        f"{q} queue: apch_thld should be raised with empty queue. "
        f"Threshold: {thld} currently enqueued elements: 0"
    )

    enq = 0
    # Leave threshold - 1 entries in the queue
    for _ in range(thld - 1, qsize[q]):
        await enqueue[q]()
        enq += 1

    await RisingEdge(dut.hclk)

    # The `apch_thld` should stop being reported when there's less than thld empty entries
    s_apch_thld = tb.get_apch_thld(q)
    assert s_apch_thld == 0, (
        f"{q} queue: Less than threshold empty entries apch_thld should not be raised. "
        f"Threshold: {thld} currently enqueued elements {enq}"
    )


@cocotb.test()
async def run_cmd_should_raise_apch_test(dut: SimHandleBase):
    await should_raise_apch_thld_transmitter(dut, "cmd")


@cocotb.test()
async def run_tx_should_raise_apch_test(dut: SimHandleBase):
    await should_raise_apch_thld_transmitter(dut, "tx")
