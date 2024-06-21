# SPDX-License-Identifier: Apache-2.0

from random import randint

import cocotb
from bus2csr import dword2int, int2dword
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, RisingEdge
from hci import DATA_BUFFER_THLD_CTRL, QUEUE_THLD_CTRL, TTI_QUEUE_THRESHOLD_CONTROL
from hci_queues import HCIQueuesTestInterface
from tti_queues import TTIQueuesTestInterface
from utils import clog2


class QueueThldHandler:
    name: str
    thld_reg_addr: int
    thld_field_off: int
    thld_reg_field_size: int

    def __init__(self, name):
        offset = {
            "rx": 8,
            "tx": 0,
            "resp": 8,
            "cmd": 0,
            "tti_rx": 16,
            "tti_tx": 24,
            "tti_rx_desc": 0,
            "tti_tx_desc": 8,
        }
        self.name = name
        if name in ["tti_tx", "tti_rx"]:
            self.thld_reg_addr = TTI_QUEUE_THRESHOLD_CONTROL
            self.thld_reg_field_size = 3
        elif name in ["tti_tx_desc", "tti_rx_desc"]:
            self.thld_reg_addr = TTI_QUEUE_THRESHOLD_CONTROL
            self.thld_reg_field_size = 8
        elif name in ["tx", "rx"]:
            self.thld_reg_addr = DATA_BUFFER_THLD_CTRL
            self.thld_reg_field_size = 3
        else:
            self.thld_reg_addr = QUEUE_THLD_CTRL
            self.thld_reg_field_size = 8

        self.thld_field_off = offset[name]

    async def adjust_thld_to_boundary(self, tb, new_thld):
        """
        If the requested threshold exceeds the maximum possible value for the threshold,
        set it to the maximum possible threshold value.
        """
        pass

    async def enqueue(self, tb):
        pass

    async def set_new_thld(self, tb, new_thld):
        thld_field_mask = 2**self.thld_reg_field_size - 1
        prev_thld_reg = dword2int(await tb.read_csr(self.thld_reg_addr, 4))
        clear_q_prev_thld = prev_thld_reg & ~(thld_field_mask << self.thld_field_off)
        new_thld_reg_value = int2dword(clear_q_prev_thld | (new_thld << self.thld_field_off))
        await tb.write_csr(self.thld_reg_addr, new_thld_reg_value, 4)

    async def get_curr_thld(self, tb):
        thld_field_mask = 2**self.thld_reg_field_size - 1
        reg_value = await tb.read_csr(self.thld_reg_addr, 4)
        return (dword2int(reg_value) >> self.thld_field_off) & thld_field_mask

    def get_thld_in_entries(self, thld):
        return thld


class CmdQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("cmd")

    async def adjust_thld_to_boundary(self, tb, new_thld):
        qsize = await tb.read_queue_size(self.name)
        return min(new_thld, qsize)

    async def enqueue(self, tb):
        await tb.put_command_desc()


class TxQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("tx")

    async def adjust_thld_to_boundary(self, tb, new_thld):
        qsize = await tb.read_queue_size(self.name)
        return min(new_thld, clog2(qsize) - 1)

    async def enqueue(self, tb):
        await tb.put_tx_data()

    def get_thld_in_entries(self, thld):
        return 2 ** (thld + 1)


class RxQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("rx")

    async def adjust_thld_to_boundary(self, tb, new_thld):
        qsize = await tb.read_queue_size(self.name)
        return min(new_thld, clog2(qsize) - 2)

    async def enqueue(self, tb):
        await tb.put_rx_data()

    def get_thld_in_entries(self, thld):
        return 2 ** (thld + 1)


class RespQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("resp")

    async def adjust_thld_to_boundary(self, tb, new_thld):
        qsize = await tb.read_queue_size(self.name)
        return min(new_thld, qsize - 1)

    async def enqueue(self, tb):
        await tb.put_response_desc()


class TTITxDescQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("tti_tx_desc")

    async def adjust_thld_to_boundary(self, tb, new_thld):
        qsize = await tb.read_queue_size(self.name)
        return min(new_thld, qsize)

    async def enqueue(self, tb):
        await tb.put_tx_desc()


class TTITxQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("tti_tx")

    async def adjust_thld_to_boundary(self, tb, new_thld):
        qsize = await tb.read_queue_size(self.name)
        return min(new_thld, clog2(qsize) - 1)

    async def enqueue(self, tb):
        await tb.put_tx_data()

    def get_thld_in_entries(self, thld):
        return 2 ** (thld + 1)


class TTIRxQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("tti_rx")

    async def adjust_thld_to_boundary(self, tb, new_thld):
        qsize = await tb.read_queue_size(self.name)
        return min(new_thld, clog2(qsize) - 2)

    async def enqueue(self, tb):
        await tb.put_rx_data()

    def get_thld_in_entries(self, thld):
        return 2 ** (thld + 1)


class TTIRxDescQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("tti_rx_desc")

    async def adjust_thld_to_boundary(self, tb, new_thld):
        qsize = await tb.read_queue_size(self.name)
        return min(new_thld, qsize - 1)

    async def enqueue(self, tb):
        await tb.put_rx_desc()


async def should_setup_threshold(dut: SimHandleBase, q: QueueThldHandler, type="hci"):
    """
    Writes the threshold to appropriate register (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
    Verifies a appropriate value has been written to the CSR.
    Verifies the `_thld_` signal drives the correct value.
    """
    if type == "hci":
        tb = HCIQueuesTestInterface(dut)
    elif type == "tti":
        tb = TTIQueuesTestInterface(dut)
    else:
        assert False, f"Unsupported Queues type: {type}"
    await tb.setup()

    thld = randint(1, 2**q.thld_reg_field_size - 1)
    expected_thld = await q.adjust_thld_to_boundary(tb, thld)

    # Setup threshold through appropriate register
    await q.set_new_thld(tb, thld)

    await ClockCycles(tb.clk, 5)

    # Ensure the register reads appropriate value
    read_thld = await q.get_curr_thld(tb)

    assert read_thld == thld, (
        f"The {q} queue threshold is not reflected by the register. "
        f"Expected {thld} retrieved {read_thld}."
    )

    await RisingEdge(tb.clk)

    # Check if the threshold signal is properly propagated onto thld_o signal
    s_thld = tb.get_thld(q.name)
    assert s_thld.integer == expected_thld, (
        f"The thld signal doesn't reflect the CSR-defined value. "
        f"Expected {expected_thld} got {s_thld.integer}."
    )
    await RisingEdge(tb.clk)


@cocotb.test()
async def run_cmd_setup_threshold_test(dut: SimHandleBase):
    await should_setup_threshold(dut, CmdQueueThldHandler())


@cocotb.test()
async def run_rx_setup_threshold_test(dut: SimHandleBase):
    await should_setup_threshold(dut, RxQueueThldHandler())


@cocotb.test()
async def run_tx_setup_threshold_test(dut: SimHandleBase):
    await should_setup_threshold(dut, TxQueueThldHandler())


@cocotb.test()
async def run_resp_setup_threshold_test(dut: SimHandleBase):
    await should_setup_threshold(dut, RespQueueThldHandler())


@cocotb.test()
async def run_tti_tx_desc_setup_threshold_test(dut: SimHandleBase):
    await should_setup_threshold(dut, TTITxDescQueueThldHandler(), "tti")


@cocotb.test()
async def run_tti_rx_setup_threshold_test(dut: SimHandleBase):
    await should_setup_threshold(dut, TTIRxQueueThldHandler(), "tti")


@cocotb.test()
async def run_tti_tx_setup_threshold_test(dut: SimHandleBase):
    await should_setup_threshold(dut, TTITxQueueThldHandler(), "tti")


@cocotb.test()
async def run_tti_rx_desc_setup_threshold_test(dut: SimHandleBase):
    await should_setup_threshold(dut, TTIRxDescQueueThldHandler(), "tti")


async def should_raise_apch_thld_receiver(dut: SimHandleBase, q: QueueThldHandler, type="hci"):
    """
    After the Response / RX queues have reached a threshold number of elements
    a `apch_thld` signal should be raised (which then will trigger an interrupt)
    """
    assert isinstance(
        q,
        (
            RespQueueThldHandler,
            RxQueueThldHandler,
            TTIRxDescQueueThldHandler,
            TTIRxQueueThldHandler,
        ),
    ), (
        "This test supports the resp & rx queues."
        "For cmd & tx see should_raise_apch_thld_transmitter."
    )
    if type == "hci":
        tb = HCIQueuesTestInterface(dut)
    elif type == "tti":
        tb = TTIQueuesTestInterface(dut)
    else:
        assert False, f"Unsupported Queues type: {type}"
    await tb.setup()

    thld_init = randint(2, 2**q.thld_reg_field_size - 1)
    thld = await q.adjust_thld_to_boundary(tb, thld_init)
    # Setup threshold through appropriate register
    await q.set_new_thld(tb, thld_init)

    thld = q.get_thld_in_entries(thld)
    for _ in range(thld - 1):
        await q.enqueue(tb)

    await ClockCycles(tb.clk, 5)

    # Check the `apch_thld` is not set before reaching the threshold
    s_apch_thld = tb.get_thld_status(q.name)
    assert s_apch_thld == 0, (
        f"{q} queue: apch_thld is raised before the threshold has been reached."
        f"Threshold: {thld} currently enqueued elements {thld-1}"
    )

    # Reach the threshold
    await q.enqueue(tb)
    await RisingEdge(tb.clk)

    # Verify the signal is risen
    s_apch_thld = tb.get_thld_status(q.name)
    assert s_apch_thld == 1, (
        f"{q} queue: apch_thld should be raised after reaching the threshold."
        f"Threshold: {thld} currently enqueued elements {thld}"
    )


@cocotb.test()
async def run_resp_should_raise_apch_test(dut: SimHandleBase):
    await should_raise_apch_thld_receiver(dut, RespQueueThldHandler())


@cocotb.test()
async def run_rx_should_raise_apch_test(dut: SimHandleBase):
    await should_raise_apch_thld_receiver(dut, RxQueueThldHandler())


@cocotb.test()
async def run_tti_rx_desc_should_raise_apch_test(dut: SimHandleBase):
    await should_raise_apch_thld_receiver(dut, TTIRxDescQueueThldHandler(), "tti")


@cocotb.test()
async def run_tti_rx_should_raise_apch_test(dut: SimHandleBase):
    await should_raise_apch_thld_receiver(dut, TTIRxQueueThldHandler(), "tti")


async def should_raise_apch_thld_transmitter(dut: SimHandleBase, q: QueueThldHandler, type="hci"):
    """
    After Command / TX queues have a threshold elements left for the `apch_thld` signal
    to be raised.
    Ensure the `apch_thld` is raised on empty queue & falls down after there's less than
    threshold elements left.
    """
    assert isinstance(
        q,
        (CmdQueueThldHandler, TxQueueThldHandler, TTITxDescQueueThldHandler, TTITxQueueThldHandler),
    ), (
        "This test supports the cmd & tx queues."
        "For resp & rx see should_raise_apch_thld_receiver."
    )
    if type == "hci":
        tb = HCIQueuesTestInterface(dut)
    elif type == "tti":
        tb = TTIQueuesTestInterface(dut)
    await tb.setup()

    thld_init = randint(2, 2**q.thld_reg_field_size - 1)
    # Setup threshold through appropriate register
    await q.set_new_thld(tb, thld_init)

    thld = await q.adjust_thld_to_boundary(tb, thld_init)
    thld = q.get_thld_in_entries(thld)

    qsize = await tb.read_queue_size(q.name)

    # Empty queue, check if `apch_thld` properly reports number of empty entires
    s_apch_thld = tb.get_thld_status(q.name)
    assert s_apch_thld == 1, (
        f"{q} queue: apch_thld should be raised with empty queue. "
        f"Threshold: {thld} currently enqueued elements: 0"
    )

    # Leave threshold - 1 entries in the queue
    for _ in range(qsize - thld + 1):
        await q.enqueue(tb)
    await ClockCycles(tb.clk, 5)

    # The `apch_thld` should stop being reported when there's less than thld empty entries
    s_apch_thld = tb.get_thld_status(q.name)
    assert s_apch_thld == 0, (
        f"{q} queue: Less than threshold empty entries apch_thld should not be raised. "
        f"Threshold: {thld} currently enqueued elements {qsize - thld + 1}"
    )


@cocotb.test()
async def run_cmd_should_raise_apch_test(dut: SimHandleBase):
    await should_raise_apch_thld_transmitter(dut, CmdQueueThldHandler())


@cocotb.test()
async def run_tx_should_raise_apch_test(dut: SimHandleBase):
    await should_raise_apch_thld_transmitter(dut, TxQueueThldHandler())


@cocotb.test()
async def run_tti_tx_desc_should_raise_apch_test(dut: SimHandleBase):
    await should_raise_apch_thld_transmitter(dut, TTITxDescQueueThldHandler(), "tti")


@cocotb.test()
async def run_tti_tx_should_raise_apch_test(dut: SimHandleBase):
    await should_raise_apch_thld_transmitter(dut, TTITxQueueThldHandler(), "tti")
