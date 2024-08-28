# SPDX-License-Identifier: Apache-2.0

from random import randint

from bus2csr import dword2int, int2dword
from hci import (
    DATA_BUFFER_THLD_CTRL,
    QUEUE_THLD_CTRL,
    TTI_DATA_BUFFER_THLD_CTRL,
    TTI_QUEUE_THLD_CTRL,
    HCIBaseTestInterface,
)
from hci_queues import HCIQueuesTestInterface
from tti_queues import TTIQueuesTestInterface
from utils import clog2

import cocotb
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, ReadOnly, RisingEdge


class QueueThldHandler:
    name: str
    thld_reg_addr: int
    thld_start_field_off: int
    thld_ready_field_off: int
    thld_reg_field_size: int

    def __init__(self, name):
        offset = {
            "rx": {
                "start": 24,
                "ready": 8,
            },
            "tx": {
                "start": 16,
                "ready": 0,
            },
            "resp": {"ready": 8},
            "cmd": {"ready": 0},
            "ibi": {"ready": 24},
            "tti_rx": {
                "start": 24,
                "ready": 8,
            },
            "tti_tx": {
                "start": 16,
                "ready": 0,
            },
            "tti_rx_desc": {"ready": 8},
            "tti_tx_desc": {"ready": 0},
            "tti_ibi": {"ready": 24},
        }
        self.thld_ready_field_off = offset[name]["ready"]

        if name in ["tti_tx", "tti_rx"]:
            self.thld_start_field_off = offset[name]["start"]
            self.thld_reg_addr = TTI_DATA_BUFFER_THLD_CTRL
            self.thld_reg_field_size = 3
        elif name in ["tti_tx_desc", "tti_rx_desc", "tti_ibi"]:
            self.thld_reg_addr = TTI_QUEUE_THLD_CTRL
            self.thld_reg_field_size = 8
        elif name in ["rx", "tx"]:
            self.thld_start_field_off = offset[name]["start"]
            self.thld_reg_addr = DATA_BUFFER_THLD_CTRL
            self.thld_reg_field_size = 3
        elif name in ["resp", "cmd", "ibi"]:
            self.thld_reg_addr = QUEUE_THLD_CTRL
            self.thld_reg_field_size = 8
        else:
            raise ValueError(
                f"Unsupported Queue name '{name}', should be one of: {list(offset.keys())}"
            )
        self.name = name.removeprefix("tti_")

    async def adjust_thld_to_boundary(self, interface, new_thld):
        """
        If the requested threshold exceeds the maximum possible value for the threshold,
        set it to the maximum possible threshold value.
        """
        raise NotImplementedError

    async def enqueue(self, interface):
        """
        Insert single data word into queue.
        """
        raise NotImplementedError

    async def dequeue(self, interface):
        """
        Pop single data word from queue.
        """
        raise NotImplementedError

    async def read_until_empty(self, interface):
        """
        Pop data from the queue until it's empty.
        """
        interface.log.debug("Empty the queue")
        while interface.get_empty(self.name) != 1:
            await self.dequeue(interface)
            await RisingEdge(interface.clk)

    def should_limit_ready_thld(self):
        """
        Return True if the queue should adjust the threshold to the queue size. Return False otherwise.
        """
        raise NotImplementedError

    async def get_new_thld_reg_value(self, read_handle, field_off, new_thld):
        thld_field_mask = 2**self.thld_reg_field_size - 1
        prev_thld_reg = dword2int(await read_handle(self.thld_reg_addr, 4))
        clear_q_prev_thld = prev_thld_reg & ~(thld_field_mask << field_off)
        new_thld_reg_value = int2dword(clear_q_prev_thld | (new_thld << field_off))

        return new_thld_reg_value

    async def set_new_start_thld(self, interface, new_thld):
        interface.log.debug(f"Setting start threshold value to {new_thld}")
        new_thld_reg_value = await self.get_new_thld_reg_value(
            interface.read_csr, self.thld_start_field_off, new_thld
        )
        await interface.write_csr(self.thld_reg_addr, new_thld_reg_value, 4)

    async def set_new_ready_thld(self, interface, new_thld):
        interface.log.debug(f"Setting ready threshold value to {new_thld}")
        new_thld_reg_value = await self.get_new_thld_reg_value(
            interface.read_csr, self.thld_ready_field_off, new_thld
        )
        await interface.write_csr(self.thld_reg_addr, new_thld_reg_value, 4)

    async def get_curr_thld(self, read_handle, field_off):
        thld_field_mask = 2**self.thld_reg_field_size - 1
        reg_value = await read_handle(self.thld_reg_addr, 4)
        return (dword2int(reg_value) >> field_off) & thld_field_mask

    async def get_curr_start_thld(self, interface):
        value = await self.get_curr_thld(interface.read_csr, self.thld_start_field_off)
        interface.log.debug(f"Start threshold value read from the registers is {value}")
        return value

    async def get_curr_ready_thld(self, interface):
        value = await self.get_curr_thld(interface.read_csr, self.thld_ready_field_off)
        interface.log.debug(f"Ready threshold value read from the registers is {value}")
        return value

    def get_thld_in_entries(self, thld):
        return thld


class CmdQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("cmd")

    async def adjust_thld_to_boundary(self, interface, new_thld):
        qsize = await interface.read_queue_size(self.name)
        return min(new_thld, qsize - 1)

    async def enqueue(self, interface):
        await interface.put_command_desc()

    async def dequeue(self, interface):
        await interface.get_command_desc()

    def should_limit_ready_thld(self):
        return True


class TxQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("tx")

    async def adjust_thld_to_boundary(self, interface, new_thld):
        qsize = await interface.read_queue_size(self.name)
        return min(new_thld, clog2(qsize) - 1)

    async def enqueue(self, interface):
        await interface.put_tx_data()

    async def dequeue(self, interface):
        await interface.get_tx_data()

    def get_thld_in_entries(self, thld):
        return 2 ** (thld + 1)

    def should_limit_ready_thld(self):
        return False


class RxQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("rx")

    async def adjust_thld_to_boundary(self, interface, new_thld):
        qsize = await interface.read_queue_size(self.name)
        return min(new_thld, clog2(qsize) - 1)

    async def enqueue(self, interface):
        await interface.put_rx_data()

    async def dequeue(self, interface):
        await interface.get_rx_data()

    def get_thld_in_entries(self, thld):
        return 2 ** (thld + 1)

    def should_limit_ready_thld(self):
        return False


class RespQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("resp")

    async def adjust_thld_to_boundary(self, interface, new_thld):
        qsize = await interface.read_queue_size(self.name)
        return min(new_thld, qsize - 1)

    async def enqueue(self, interface):
        await interface.put_response_desc()

    async def dequeue(self, interface):
        await interface.get_response_desc()

    def should_limit_ready_thld(self):
        return True


class IbiQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("ibi")

    async def adjust_thld_to_boundary(self, interface, new_thld):
        qsize = await interface.read_queue_size(self.name)
        return min(new_thld, qsize - 1)

    async def enqueue(self, interface):
        await interface.put_ibi_data()

    async def dequeue(self, interface):
        await interface.get_ibi_data()

    def should_limit_ready_thld(self):
        return False


class TTITxDescQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("tti_tx_desc")

    async def adjust_thld_to_boundary(self, interface, new_thld):
        qsize = await interface.read_queue_size(self.name)
        return min(new_thld, qsize - 1)

    async def enqueue(self, interface):
        await interface.put_tx_desc()

    async def dequeue(self, interface):
        await interface.get_tx_desc()

    def should_limit_ready_thld(self):
        return True


class TTITxQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("tti_tx")

    async def adjust_thld_to_boundary(self, interface, new_thld):
        qsize = await interface.read_queue_size(self.name)
        return min(new_thld, clog2(qsize) - 1)

    async def enqueue(self, interface):
        await interface.put_tx_data()

    async def dequeue(self, interface):
        await interface.get_tx_data()

    def get_thld_in_entries(self, thld):
        return 2 ** (thld + 1)

    def should_limit_ready_thld(self):
        return False


class TTIRxQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("tti_rx")

    async def adjust_thld_to_boundary(self, interface, new_thld):
        qsize = await interface.read_queue_size(self.name)
        return min(new_thld, clog2(qsize) - 1)

    async def enqueue(self, interface):
        await interface.put_rx_data()

    async def dequeue(self, interface):
        await interface.get_rx_data()

    def get_thld_in_entries(self, thld):
        return 2 ** (thld + 1)

    def should_limit_ready_thld(self):
        return False


class TTIRxDescQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("tti_rx_desc")

    async def adjust_thld_to_boundary(self, interface, new_thld):
        qsize = await interface.read_queue_size(self.name)
        return min(new_thld, qsize - 1)

    async def enqueue(self, interface):
        await interface.put_rx_desc()

    async def dequeue(self, interface):
        await interface.get_rx_desc()

    def should_limit_ready_thld(self):
        return True


class TtiIbiQueueThldHandler(QueueThldHandler):
    def __init__(self):
        super().__init__("tti_ibi")

    async def adjust_thld_to_boundary(self, interface, new_thld):
        qsize = await interface.read_queue_size(self.name)
        return min(new_thld, qsize - 1)

    async def enqueue(self, interface):
        await interface.put_ibi_data()

    async def dequeue(self, interface):
        await interface.get_ibi_data()

    def should_limit_ready_thld(self):
        return False


async def setup_sim(dut, type):
    if type == "hci":
        interface = HCIQueuesTestInterface(dut)
    elif type == "tti":
        interface = TTIQueuesTestInterface(dut)
    else:
        raise ValueError(f"Unsupported Queues type: {type}")
    await interface.setup()
    return interface


async def should_setup_start_threshold(interface: HCIBaseTestInterface, q: QueueThldHandler):
    """
    Writes the threshold to appropriate register (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
    Verifies a appropriate value has been written to the CSR.
    Verifies the `_thld_` signal drives the correct value.
    """

    expected_start_thld = randint(1, 2**q.thld_reg_field_size - 1)

    # Setup threshold through appropriate register
    await q.set_new_start_thld(interface, expected_start_thld)

    await ClockCycles(interface.clk, 5)

    # Ensure the register reads appropriate value
    read_start_thld = await q.get_curr_start_thld(interface)

    assert read_start_thld == expected_start_thld, (
        f"The {q} queue start threshold is not reflected by the register. "
        f"Expected {expected_start_thld} retrieved {read_start_thld}."
    )

    await RisingEdge(interface.clk)

    # Check if the threshold signal is properly propagated onto thld_o signal
    s_start_thld = interface.get_thld(q.name, "start")
    assert s_start_thld.integer == expected_start_thld, (
        f"The start thld signal doesn't reflect the CSR-defined value. "
        f"Expected {expected_start_thld} got {s_start_thld.integer}."
    )
    await RisingEdge(interface.clk)


async def should_setup_ready_threshold(interface: HCIBaseTestInterface, q: QueueThldHandler):
    """
    Writes the threshold to appropriate register (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
    Verifies a appropriate value has been written to the CSR.
    Verifies the `_thld_` signal drives the correct value.
    """
    ready_thld = randint(1, 2**q.thld_reg_field_size - 1)
    expected_ready_thld = (
        await q.adjust_thld_to_boundary(interface, ready_thld)
        if q.should_limit_ready_thld()
        else ready_thld
    )

    # Setup threshold through appropriate register
    await q.set_new_ready_thld(interface, ready_thld)

    await ClockCycles(interface.clk, 5)

    # Ensure the register reads appropriate value
    read_ready_thld = await q.get_curr_ready_thld(interface)

    assert read_ready_thld == expected_ready_thld, (
        f"The {q} queue ready threshold is not reflected by the register. "
        f"Expected {expected_ready_thld} retrieved {read_ready_thld}."
    )

    await RisingEdge(interface.clk)

    # Check if the threshold signal is properly propagated onto thld_o signal
    s_ready_thld = interface.get_thld(q.name, "ready")
    assert s_ready_thld.integer == expected_ready_thld, (
        f"The ready thld signal doesn't reflect the CSR-defined value. "
        f"Expected {expected_ready_thld} got {s_ready_thld.integer}."
    )
    await RisingEdge(interface.clk)


@cocotb.test()
async def run_cmd_setup_threshold_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "hci")
    await should_setup_ready_threshold(interface, CmdQueueThldHandler())


@cocotb.test()
async def run_rx_setup_threshold_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "hci")
    await should_setup_start_threshold(interface, RxQueueThldHandler())
    await should_setup_ready_threshold(interface, RxQueueThldHandler())


@cocotb.test()
async def run_tx_setup_threshold_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "hci")
    await should_setup_start_threshold(interface, TxQueueThldHandler())
    await should_setup_ready_threshold(interface, TxQueueThldHandler())


@cocotb.test()
async def run_resp_setup_threshold_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "hci")
    await should_setup_ready_threshold(interface, RespQueueThldHandler())


@cocotb.test()
async def run_ibi_setup_threshold_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "hci")
    await should_setup_ready_threshold(interface, IbiQueueThldHandler())


@cocotb.test()
async def run_tti_tx_desc_setup_threshold_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    await should_setup_ready_threshold(interface, TTITxDescQueueThldHandler())


@cocotb.test()
async def run_tti_rx_setup_threshold_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    # TODO: Enable start threshold test once it's added to the design
    # await should_setup_start_threshold(interface, TTIRxQueueThldHandler())
    await should_setup_ready_threshold(interface, TTIRxQueueThldHandler())


@cocotb.test()
async def run_tti_tx_setup_threshold_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    # TODO: Enable start threshold test once it's added to the design
    # await should_setup_start_threshold(interface, TTITxQueueThldHandler())
    await should_setup_ready_threshold(interface, TTITxQueueThldHandler())


@cocotb.test()
async def run_tti_rx_desc_setup_threshold_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    await should_setup_ready_threshold(interface, TTIRxDescQueueThldHandler())


@cocotb.test()
async def run_tti_ibi_setup_threshold_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    await should_setup_ready_threshold(interface, TtiIbiQueueThldHandler())


async def should_raise_start_thld_trig_receiver(
    interface: HCIBaseTestInterface, q: QueueThldHandler
):
    """
    Sets up a start threshold of the read queue and checks whether the trigger
    is properly raised at different levels of the queue fill.
    """
    if not isinstance(
        q,
        (
            RespQueueThldHandler,
            RxQueueThldHandler,
            TTIRxDescQueueThldHandler,
            TTIRxQueueThldHandler,
        ),
    ):
        raise ValueError("This test supports read queues only.")

    # Clear the queue
    await q.read_until_empty(interface)

    max_start_thld = await q.adjust_thld_to_boundary(interface, 2**q.thld_reg_field_size - 1)
    start_thld = randint(2, max_start_thld)

    # Setup threshold through appropriate register
    await q.set_new_start_thld(interface, start_thld)
    s_start_thld_trig = interface.get_thld_status(q.name, "start")
    assert s_start_thld_trig == 1, (
        f"{q} queue: Threshold trigger should be raised with empty queue."
        f"Threshold: {start_thld}, currently enqueued elements: 0"
    )

    # Fill queue with random data just below the threshold level
    start_thld_cnt = q.get_thld_in_entries(start_thld)
    qsize = await interface.read_queue_size(q.name)
    interface.log.debug(f"Writing {qsize - start_thld_cnt + 1} data words to the queue")
    for _ in range(qsize - start_thld_cnt + 1):
        await q.enqueue(interface)

    s_start_thld_trig = interface.get_thld_status(q.name, "start")
    assert s_start_thld_trig == 1, (
        f"{q} queue: Threshold trigger should be raised with number of empty"
        "entries above threshold level."
        f"Threshold: {start_thld_cnt}, currently enqueued elements: {qsize - start_thld_cnt + 1}"
    )

    await ClockCycles(interface.clk, 5)

    # Write one more random data dword to trigger the threshold
    await q.enqueue(interface)
    await RisingEdge(interface.clk)

    s_start_thld_trig = interface.get_thld_status(q.name, "start")
    assert s_start_thld_trig == 0, (
        f"{q} queue: Threshold should not be triggered when number of available"
        "entries is below the threshold level"
        f"Threshold: {start_thld}, currently enqueued elements {start_thld}"
    )


async def should_raise_ready_thld_trig_receiver(
    interface: HCIBaseTestInterface, q: QueueThldHandler
):
    """
    Sets up a ready threshold of the read queue and checks whether the trigger
    is properly raised at different levels of the queue fill.
    """
    if not isinstance(
        q,
        (
            RespQueueThldHandler,
            RxQueueThldHandler,
            IbiQueueThldHandler,
            TTIRxDescQueueThldHandler,
            TTIRxQueueThldHandler,
        ),
    ):
        raise ValueError("This test supports read queues only.")

    # Clear the queue
    await q.read_until_empty(interface)

    max_ready_thld = await q.adjust_thld_to_boundary(interface, 2**q.thld_reg_field_size - 1)
    ready_thld = randint(2, max_ready_thld)
    # Setup threshold through appropriate register
    await q.set_new_ready_thld(interface, ready_thld)

    # Fill queue with random data just below the threshold level
    ready_thld_cnt = q.get_thld_in_entries(ready_thld)
    for _ in range(ready_thld_cnt - 1):
        await q.enqueue(interface)

    await ClockCycles(interface.clk, 5)

    s_ready_thld_trig = interface.get_thld_status(q.name, "ready")
    assert s_ready_thld_trig == 0, (
        f"{q} queue: Threshold should not be triggered when number of entries"
        " is below the threshold level"
        f"Threshold: {ready_thld_cnt}, currently enqueued elements {ready_thld_cnt - 1}"
    )

    # Write one more random data dword to trigger the threshold
    await q.enqueue(interface)
    await RisingEdge(interface.clk)

    s_ready_thld_trig = interface.get_thld_status(q.name, "ready")
    assert s_ready_thld_trig == 1, (
        f"{q} queue: Threshold trigger should be raised with number of entries"
        " above threshold level."
        f"Threshold: {ready_thld_cnt} currently enqueued elements {ready_thld_cnt}"
    )


@cocotb.test()
async def run_resp_should_raise_thld_trig_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "hci")
    await should_raise_ready_thld_trig_receiver(interface, RespQueueThldHandler())


@cocotb.test()
async def run_rx_should_raise_thld_trig_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "hci")
    await should_raise_start_thld_trig_receiver(interface, RxQueueThldHandler())
    await should_raise_ready_thld_trig_receiver(interface, RxQueueThldHandler())


@cocotb.test()
async def run_ibi_should_raise_thld_trig_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "hci")
    await should_raise_ready_thld_trig_receiver(interface, IbiQueueThldHandler())


@cocotb.test()
async def run_tti_rx_desc_should_raise_thld_trig_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    await should_raise_ready_thld_trig_receiver(interface, TTIRxDescQueueThldHandler())


@cocotb.test()
async def run_tti_rx_should_raise_thld_trig_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    # TODO: Enable start threshold test once it's added to the design
    await should_raise_start_thld_trig_receiver(interface, TTIRxQueueThldHandler())
    await should_raise_ready_thld_trig_receiver(interface, TTIRxQueueThldHandler())


async def should_raise_start_thld_trig_transmitter(
    interface: HCIBaseTestInterface, q: QueueThldHandler
):
    """
    Sets up a start threshold of the write queue and checks whether the trigger
    is properly raised at different levels of the queue fill.
    """
    if not isinstance(
        q,
        (CmdQueueThldHandler, TxQueueThldHandler, TTITxDescQueueThldHandler, TTITxQueueThldHandler),
    ):
        raise ValueError("This test supports write queues only.")

    # Clear the queue
    await q.read_until_empty(interface)

    max_start_thld = await q.adjust_thld_to_boundary(interface, 2**q.thld_reg_field_size - 1)
    start_thld = randint(2, max_start_thld)
    # Setup threshold through appropriate register
    await q.set_new_start_thld(interface, start_thld)
    s_start_thld_trig = interface.get_thld_status(q.name, "start")
    assert s_start_thld_trig == 0, (
        f"{q} queue: Threshold trigger should not be raised with an empty queue. "
        f"Threshold: {start_thld} currently enqueued elements: 0"
    )

    # Fill queue with random data just below the threshold level
    start_thld_cnt = q.get_thld_in_entries(start_thld)
    for _ in range(start_thld_cnt - 1):
        await q.enqueue(interface)
    await ClockCycles(interface.clk, 5)

    # Ensure that the trigger is not set before reaching the threshold
    s_start_thld_trig = interface.get_thld_status(q.name, "start")
    assert s_start_thld_trig == 0, (
        f"{q} queue: Threshold trigger should be raised with number of empty"
        " entries above threshold level. "
        f"Threshold: {start_thld_cnt} currently enqueued elements {start_thld_cnt - 1}"
    )

    # Reach the threshold
    await q.enqueue(interface)
    await RisingEdge(interface.clk)

    # Verify the signal is risen
    s_start_thld_trig = interface.get_thld_status(q.name, "start")
    assert s_start_thld_trig == 1, (
        f"{q} queue: Threshold trigger should be raised with number of empty"
        " entries above threshold level. "
        f"Threshold: {start_thld_cnt} currently enqueued elements {start_thld_cnt}"
    )


async def should_raise_ready_thld_trig_transmitter(
    interface: HCIBaseTestInterface, q: QueueThldHandler
):
    """
    Sets up a ready threshold of the write queue and checks whether the trigger
    is properly raised at different levels of the queue fill.
    """
    if not isinstance(
        q,
        (
            CmdQueueThldHandler,
            TxQueueThldHandler,
            TTITxDescQueueThldHandler,
            TTITxQueueThldHandler,
            TtiIbiQueueThldHandler,
        ),
    ):
        raise ValueError("This test supports write queues only.")

    # Clear the queue
    await q.read_until_empty(interface)

    max_ready_thld = await q.adjust_thld_to_boundary(interface, 2**q.thld_reg_field_size - 1)
    ready_thld = randint(2, max_ready_thld)
    # Setup threshold through appropriate register
    await q.set_new_ready_thld(interface, ready_thld)
    await RisingEdge(interface.clk)
    await ReadOnly()

    s_ready_thld_trig = interface.get_thld_status(q.name, "ready")
    assert s_ready_thld_trig == 1, (
        f"{q} queue: Threshold trigger should be raised with empty queue."
        f"Threshold: {ready_thld} currently enqueued elements: 0"
    )

    # Fill queue with random data just below the threshold level
    ready_thld_cnt = q.get_thld_in_entries(ready_thld)
    qsize = await interface.read_queue_size(q.name)
    for _ in range(qsize - ready_thld_cnt):
        await q.enqueue(interface)

    s_ready_thld_trig = interface.get_thld_status(q.name, "ready")
    assert s_ready_thld_trig == 1, (
        f"{q} queue: Threshold trigger should be raised with number of entries"
        " above threshold level. "
        f"Threshold: {ready_thld} currently enqueued elements: {ready_thld_cnt - 1}"
    )

    await ClockCycles(interface.clk, 5)

    # Reach the threshold
    await q.enqueue(interface)
    await RisingEdge(interface.clk)

    # Verify the signal is risen
    s_ready_thld_trig = interface.get_thld_status(q.name, "ready")
    assert s_ready_thld_trig == 0, (
        f"{q} queue: Threshold trigger should not be raised with number of empty"
        " entries above threshold level. "
        f"Threshold: {ready_thld} currently enqueued elements {ready_thld}"
    )


@cocotb.test()
async def run_cmd_should_raise_thld_trig_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "hci")
    await should_raise_ready_thld_trig_transmitter(interface, CmdQueueThldHandler())


@cocotb.test()
async def run_tx_should_raise_thld_trig_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "hci")
    await should_raise_start_thld_trig_transmitter(interface, TxQueueThldHandler())
    await should_raise_ready_thld_trig_transmitter(interface, TxQueueThldHandler())


@cocotb.test()
async def run_tti_tx_desc_should_raise_thld_trig_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    await should_raise_ready_thld_trig_transmitter(interface, TTITxDescQueueThldHandler())


@cocotb.test()
async def run_tti_tx_should_raise_thld_trig_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    # TODO: Enable start threshold test once it's added to the design
    await should_raise_start_thld_trig_transmitter(interface, TTITxQueueThldHandler())
    await should_raise_ready_thld_trig_transmitter(interface, TTITxQueueThldHandler())


@cocotb.test()
async def run_tti_ibi_should_raise_thld_trig_test(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    await should_raise_ready_thld_trig_transmitter(interface, TtiIbiQueueThldHandler())
