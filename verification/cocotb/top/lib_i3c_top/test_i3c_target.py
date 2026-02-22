# SPDX-License-Identifier: Apache-2.0

import logging
import random
from math import ceil

from boot import boot_init
from bus2csr import dword2int, int2dword
from ccc import CCC
from i3c_controller_fixed import I3cControllerFixed as I3cController
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface
from utils import format_ibi_data, get_interrupt_status

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer
from cocotbext_i3c.common import I3cState
from common import VALID_I3C_ADDRESSES, timeout_task, log_seed

TARGET_ADDRESS = 0x5A


async def test_setup(dut, fclk=333.0, fbus=12.5,
                     static_addr=TARGET_ADDRESS, virtual_static_addr=0x5B,
                     dynamic_addr=None, virtual_dynamic_addr=None):
    """
    Sets up controller, target models and top-level core interface
    """

    cocotb.log.setLevel(logging.INFO)
    log_seed(dut)
    cocotb.start_soon(timeout_task(500000))

    dut._log.info(f"fclk = {fclk:.3f} MHz")
    dut._log.info(f"fbus = {fbus:.3f} MHz")

    i3c_controller = I3cController(
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_ctrl_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_ctrl_i,
        debug_state_o=None,
        speed=fbus * 1e6,
    )

    i3c_target = I3CTarget(  # noqa
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_target_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_target_i,
        debug_state_o=None,
        speed=fbus * 1e6,
    )

    tb = I3CTopTestInterface(dut)
    await tb.setup(fclk)

    # Configure the top level

    # TODO: For now test with all timings set to 0.
    timings = {
        "T_R": 0,
        "T_F": 0,
        "T_HD_DAT": 0,
        "T_SU_DAT": 0,
    }

    for k, v in timings.items():
        dut._log.info(f"{k} = {v}")

    await boot_init(tb, timings, fclk=fclk,
                    static_addr=static_addr, virtual_static_addr=virtual_static_addr,
                    dynamic_addr=dynamic_addr, virtual_dynamic_addr=virtual_dynamic_addr)

    # Set TTI queues thresholds
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.QUEUE_THLD_CTRL.base_addr,
        tb.reg_map.I3C_EC.TTI.QUEUE_THLD_CTRL.RX_DESC_THLD,
        1,
    )

    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.DATA_BUFFER_THLD_CTRL.base_addr,
        tb.reg_map.I3C_EC.TTI.DATA_BUFFER_THLD_CTRL.RX_DATA_THLD,
        0,  # threshold = 2 ^ (x + 1) = 2
    )

    return i3c_controller, i3c_target, tb


@cocotb.test()
async def test_i3c_target_write(dut):

    test_data = [[0xAA, 0x00, 0xBB, 0xCC, 0xDD], [0xDE, 0xAD, 0xBA, 0xBE]]
    recv_data = []

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut)

    # Receiver agent (firmware side)
    async def rx_agent():
        nonlocal recv_data

        # Enable RX descriptor interrupt
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.TTI.INTERRUPT_ENABLE.base_addr,
            tb.reg_map.I3C_EC.TTI.INTERRUPT_ENABLE.RX_DESC_STAT_EN,
            1,
        )

        for i, tx_data in enumerate(test_data):

            # Wait for the interrupt signal to go high
            irq = dut.xi3c_wrapper.i3c.irq_o
            if irq.value == 0:
                await RisingEdge(irq)

            # Read & check interrupt status
            intrs = await get_interrupt_status(tb)
            assert intrs["RX_DESC_STAT"] == 1, f"RX_DESC_STAT expected 1, got {intrs['RX_DESC_STAT']}"

            # Read RX descriptor, the interrupt should go low
            data = dword2int(
                await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4)
            )
            desc_len = data & 0xFFFF

            # Examine the descriptor
            assert len(tx_data) == desc_len, "Incorrect number of bytes in RX descriptor"
            remainder = desc_len % 4

            err_stat = data >> 28
            assert err_stat == 0, "Unexpected error detected"

            # Wait for the interrupt signal to go low
            irq = dut.xi3c_wrapper.i3c.irq_o
            if irq.value != 0:
                await FallingEdge(irq)

            # Read & check interrupt status
            intrs = await get_interrupt_status(tb)
            assert intrs["RX_DESC_STAT"] == 0, f"RX_DESC_STAT expected 0, got {intrs['RX_DESC_STAT']}"

            # Read RX data
            data_len = ceil(desc_len / 4)
            rx_data = []
            for _ in range(data_len):
                data = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, 4))
                for k in range(4):
                    rx_data.append((data >> (k * 8)) & 0xFF)

            # Remove entries that are outside of the data length
            if remainder:
                for k in range(4 - remainder):
                    rx_data.pop()

            recv_data.append(rx_data)

    # Start the device firmware agent
    cocotb.start_soon(rx_agent())

    # Send Private Writes on I3C. The agent will handle them as their come
    for test_vec in test_data:
        await i3c_controller.i3c_write(TARGET_ADDRESS, test_vec)
        await ClockCycles(tb.clk, 10)

    # Wait
    await ClockCycles(tb.clk, 100)

    # Compare
    dut._log.info(
        "Comparing input [{}] and RX data [{}]".format(
            " ".join(["[ " + " ".join([f"0x{d:02X}" for d in s]) + " ]" for s in test_data]),
            " ".join(["[ " + " ".join([f"0x{d:02X}" for d in s]) + " ]" for s in recv_data]),
        )
    )
    assert test_data == recv_data, f"Private write mismatch: sent={test_data}, recv={recv_data}"

    await tb.teardown()


@cocotb.test()
async def test_i3c_target_read(dut):

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut)

    # Generates a randomized transfer and puts it into the TTI TX queue
    async def make_transfer(min_len=1, max_len=16):

        length = random.randint(min_len, max_len)
        data = [random.randint(0, 255) for _ in range(length)]

        dut._log.info(f"Enqueueing transfer of length {length}")

        # Write data to TTI TX FIFO
        for i in range((length + 3) // 4):
            word = data[4 * i]
            if 4 * i + 1 < length:
                word |= data[4 * i + 1] << 8
            if 4 * i + 2 < length:
                word |= data[4 * i + 2] << 16
            if 4 * i + 3 < length:
                word |= data[4 * i + 3] << 24

            await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, int2dword(word), 4)

        # Write the TX descriptor
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(length), 4)

        return data

    def compare(expected, received, lnt=None):
        if lnt is None or lnt == len(expected):
            sfx = ""
        else:
            sfx = " ([" + " ".join([f"{d:02X}" for d in expected[lnt:]]) + "] skipped)"
            expected = expected[:lnt]

        dut._log.info("Expected: [" + " ".join([f"{d:02X}" for d in expected]) + "]" + sfx)
        dut._log.info("Received: [" + " ".join([f"{d:02X}" for d in received]) + "]")
        assert expected == received, f"Data mismatch: exp=[{' '.join(f'{d:02X}' for d in expected)}] got=[{' '.join(f'{d:02X}' for d in received)}]"

    # .............

    # Test N consecutive transfers. Do not queue new transfers before completion
    dut._log.info("N consecutive transfers, one at a time")
    for i in range(2):
        tx_data = await make_transfer()
        rx_resp = await i3c_controller.i3c_read(TARGET_ADDRESS, len(tx_data))
        assert not rx_resp.nack, "Unexpected NACK on private read (one-at-a-time)"
        rx_data = list(rx_resp.data)
        compare(tx_data, rx_data)


    # Test N consecutive transfers. First enqueue, then service
    dut._log.info("N consecutive transfers, enqueued then serviced")
    tx_data = []
    for i in range(3):
        tx_data.append(await make_transfer())

    for i in range(3):
        rx_resp = await i3c_controller.i3c_read(TARGET_ADDRESS, len(tx_data[i]))
        assert not rx_resp.nack, f"Unexpected NACK on private read (batch, index {i})"
        rx_data = list(rx_resp.data)
        compare(tx_data[i], rx_data)


    # Test N consecutive transfers. First enqueue, then service. Occasionally
    # read less data.
    short = random.sample([i for i in range(5)], 2)
    dut._log.info(f"N consecutive transfers, short read for {short}")

    tx_data = []
    for i in range(5):
        tx_data.append(await make_transfer(min_len=4))

    for i in range(5):
        lnt = len(tx_data[i])
        if i in short:
            lnt -= random.randint(1, 3)

        rx_resp = await i3c_controller.i3c_read(TARGET_ADDRESS, lnt)
        assert not rx_resp.nack, f"Unexpected NACK on private read (short, index {i})"
        rx_data = list(rx_resp.data)
        compare(tx_data[i], rx_data, lnt)


    # Test N consecutive transfers. Do not queue new transfers before completion
    dut._log.info("N consecutive transfers, one at a time (again)")
    for i in range(2):
        tx_data = await make_transfer()
        rx_resp = await i3c_controller.i3c_read(TARGET_ADDRESS, len(tx_data))
        assert not rx_resp.nack, "Unexpected NACK on private read (repeat)"
        rx_data = list(rx_resp.data)
        compare(tx_data, rx_data)

    # Dummy wait

    await tb.teardown()


@cocotb.test()
async def test_i3c_target_read_empty(dut):

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut)
    # Generates a randomized transfer and puts it into the TTI TX queue
    async def make_transfer(min_len=1, max_len=16):

        length = random.randint(min_len, max_len)
        data = [random.randint(0, 255) for _ in range(length)]

        dut._log.info(f"Enqueueing transfer of length {length}")

        # Write data to TTI TX FIFO
        for i in range((length + 3) // 4):
            word = data[4 * i]
            if 4 * i + 1 < length:
                word |= data[4 * i + 1] << 8
            if 4 * i + 2 < length:
                word |= data[4 * i + 2] << 16
            if 4 * i + 3 < length:
                word |= data[4 * i + 3] << 24

            await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, int2dword(word), 4)

        # Write the TX descriptor
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(length), 4)

        return data

    def compare(expected, received, lnt=None):
        if lnt is None or lnt == len(expected):
            sfx = ""
        else:
            sfx = " ([" + " ".join([f"{d:02X}" for d in expected[lnt:]]) + "] skipped)"
            expected = expected[:lnt]

        dut._log.info("Expected: [" + " ".join([f"{d:02X}" for d in expected]) + "]" + sfx)
        dut._log.info("Received: [" + " ".join([f"{d:02X}" for d in received]) + "]")
        assert expected == received, f"Data mismatch: exp=[{' '.join(f'{d:02X}' for d in expected)}] got=[{' '.join(f'{d:02X}' for d in received)}]"

    # issue 20 random read transactions
    # randomly choose to inicialize the FIFO or not
    # if FIFO is not initialized the transation should be NACKed
    for i in range(20):
        transfer_data = random.choice([True, False])
        if transfer_data:
            tx_data = await make_transfer()
            response = await i3c_controller.i3c_read(TARGET_ADDRESS, len(tx_data), send_rsvd = random.choice([True, False]))
            assert not response.nack, "Unexpected NACK"
            rx_data = list(response.data)
            compare(tx_data, rx_data)
        else:
            response = await i3c_controller.i3c_read(TARGET_ADDRESS, random.randint(1, 16), send_rsvd = random.choice([True, False]))
            assert response.nack, "Expected NACK but got ACK"

    await tb.teardown()


@cocotb.test()
async def test_i3c_target_read_to_multiple_targets(dut):

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut, fclk=100, virtual_static_addr=None)

    # Generates a randomized transfer and puts it into the TTI TX queue
    async def make_transfer(min_len=1, max_len=16):

        length = random.randint(min_len, max_len)
        data = [random.randint(0, 255) for _ in range(length)]

        dut._log.info(f"Enqueueing transfer of length {length}")

        # Write data to TTI TX FIFO
        for i in range((length + 3) // 4):
            word = data[4 * i]
            if 4 * i + 1 < length:
                word |= data[4 * i + 1] << 8
            if 4 * i + 2 < length:
                word |= data[4 * i + 2] << 16
            if 4 * i + 3 < length:
                word |= data[4 * i + 3] << 24

            await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, int2dword(word), 4)

        # Write the TX descriptor
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(length), 4)

        return data

    def compare(expected, received, lnt=None):
        if lnt is None or lnt == len(expected):
            sfx = ""
        else:
            sfx = " ([" + " ".join([f"{d:02X}" for d in expected[lnt:]]) + "] skipped)"
            expected = expected[:lnt]

        dut._log.info("Expected: [" + " ".join([f"{d:02X}" for d in expected]) + "]" + sfx)
        dut._log.info("Received: [" + " ".join([f"{d:02X}" for d in received]) + "]")
        assert expected == received, f"Data mismatch: exp=[{' '.join(f'{d:02X}' for d in expected)}] got=[{' '.join(f'{d:02X}' for d in received)}]"

    # issue 40 random read transactions
    # randomly choose to inicialize the FIFO or not
    # if FIFO is not initialized the transation should be NACKed
    for _ in range(40):
        num_transfers = random.randint(3, 10)
        addresses = []
        num_transfers_to_our_target = random.randint(1, num_transfers - 1)
        for _ in range(num_transfers_to_our_target):
            addresses.append(TARGET_ADDRESS)
        while len(addresses) < num_transfers:
            addresses.append(random.choice(VALID_I3C_ADDRESSES))
        random.shuffle(addresses)
        data_len_rsvd_stop_nack = []
        for i, addr in enumerate(addresses):
            send_rsvd = random.choice([True, False]) if i == 0 else False
            stop = i == num_transfers - 1
            if addr == TARGET_ADDRESS:
                tx_data = await make_transfer()
                data_len_rsvd_stop_nack.append((tx_data, len(tx_data), send_rsvd, stop, False))
            else:
                data_len_rsvd_stop_nack.append((None, random.randint(1, 16), send_rsvd, stop, True))

        for address, (tx_data, length, rsvd, stop, nack) in zip(addresses, data_len_rsvd_stop_nack):
            response = await i3c_controller.i3c_read(address, length, send_rsvd=rsvd, stop=stop)
            assert nack == response.nack, f"NACK mismatch: expected response.nack, got {nack}"
            if not nack:
                rx_data = list(response.data)
                compare(tx_data, rx_data)

    await tb.teardown()


@cocotb.test()
async def test_i3c_target_ibi(dut):
    """
    IBI test. Sends an IBI with no data and then subsequently IBIs with
    different data lengths. Expects the controller to ACK all of them and
    return correctly received data.
    """

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut)

    target = i3c_controller.add_target(TARGET_ADDRESS)
    target.set_bcr_fields(ibi_req_capable=True, ibi_payload=True)

    # Enable IBI ACK-ing
    i3c_controller.enable_ibi(True)

    # Send a broadcast CCC to initialize bus timers (need STOP to start counting)
    await i3c_controller.i3c_ccc_write(ccc=CCC.BCAST.RSTDAA)

    # Write descriptor to the TTI IBI queue. No IBI data
    mdb = 0xAA
    data = []
    ibi_data = format_ibi_data(mdb, data)
    dut._log.info(" ".join([f"0x{d:08X}" for d in ibi_data]))
    for word in ibi_data:
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, int2dword(word), 4)

    # Wait for the IBI to be serviced, check data
    response = await i3c_controller.wait_for_ibi()
    expected = bytearray([TARGET_ADDRESS, mdb] + data)
    assert response == expected, (
        f"IBI MDB/data mismatch: expected [{' '.join(f'0x{b:02X}' for b in expected)}], "
        f"got [{' '.join(f'0x{b:02X}' for b in response)}]"
    )

    # Check LAST_IBI_STATUS
    last_ibi_status = await tb.read_csr_field(tb.reg_map.I3C_EC.TTI.STATUS.base_addr,
                                              tb.reg_map.I3C_EC.TTI.STATUS.LAST_IBI_STATUS)
    assert last_ibi_status == 0, f"LAST_IBI_STATUS: expected 0, got {last_ibi_status}"

    await ClockCycles(tb.clk, 50)

    # Write descriptor to the TTI IBI queue with some data. Check different
    # data lengths to exercise 32-bit to 8-bit conversion that happens inside
    # IBI module
    payload = [0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xCA]

    for lnt in [4, 5, 6, 7, 8]:

        mdb = 0xAA
        data = payload[: lnt + 1]
        ibi_data = format_ibi_data(mdb, data)
        dut._log.info(" ".join([f"0x{d:08X}" for d in ibi_data]))
        for word in ibi_data:
            await tb.write_csr(tb.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, int2dword(word), 4)

        # Wait for the IBI to be serviced, check data
        response = await i3c_controller.wait_for_ibi()
        expected = bytearray([TARGET_ADDRESS, mdb] + data)
        assert response == expected, (
            f"IBI MDB/data mismatch (len={lnt}): "
            f"expected [{' '.join(f'0x{b:02X}' for b in expected)}], "
            f"got [{' '.join(f'0x{b:02X}' for b in response)}]"
        )

        # Check LAST_IBI_STATUS
        last_ibi_status = await tb.read_csr_field(tb.reg_map.I3C_EC.TTI.STATUS.base_addr,
                                                  tb.reg_map.I3C_EC.TTI.STATUS.LAST_IBI_STATUS)
        assert last_ibi_status == 0, (
            f"LAST_IBI_STATUS (len={lnt}): expected 0, got {last_ibi_status}"
        )

        await ClockCycles(tb.clk, 50)

    await tb.teardown()


@cocotb.test()
async def test_i3c_target_ibi_retry(dut):
    """
    Disables IBI ACK-ing in controller, sends an IBI, waits some time for the
    target to retry IBI transmission, re-enables IBI-acking, waits until the
    IBI gets serviced, check if IBI data was received correctly.
    """

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut)

    # Enable indefinite IBI retries
    #  TTI.CONTROL.IBI_EN        = 1
    #  TTI.CONTROL.IBI_RETRY_NUM = 7 (means indefinite)
    await tb.write_csr(tb.reg_map.I3C_EC.TTI.CONTROL.base_addr, int2dword(0x0000F000), 4)

    target = i3c_controller.add_target(TARGET_ADDRESS)
    target.set_bcr_fields(ibi_req_capable=True, ibi_payload=True)

    # Send a broadcast CCC to initialize bus timers (need STOP to start counting)
    await i3c_controller.i3c_ccc_write(ccc=CCC.BCAST.RSTDAA)

    # Disable IBI ACK-ing
    i3c_controller.enable_ibi(False)

    # Write descriptor to the TTI IBI queue
    mdb = 0xAA
    data = [0xBE, 0xEF]
    ibi_data = format_ibi_data(mdb, data)
    dut._log.info(" ".join([f"0x{d:08X}" for d in ibi_data]))
    for word in ibi_data:
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, int2dword(word), 4)

    # Wait for some time so that the target gets a chance to retry IBI
    # transmission
    await Timer(10, "us")

    # T7: Verify the IBI was actually attempted and NACKed (not stale status)
    last_ibi_status = await tb.read_csr_field(tb.reg_map.I3C_EC.TTI.STATUS.base_addr,
                                              tb.reg_map.I3C_EC.TTI.STATUS.LAST_IBI_STATUS)
    assert last_ibi_status == 1, (
        f"LAST_IBI_STATUS after NACK: expected 1 (IbiFailureNack), got {last_ibi_status}"
    )

    # Re-enable IBI ACK-ing
    i3c_controller.enable_ibi(True)

    # Wait for the IBI to be serviced, check data
    response = await i3c_controller.wait_for_ibi()
    expected = bytearray([TARGET_ADDRESS, mdb] + data)
    assert response == expected, (
        f"IBI MDB/data mismatch: expected [{' '.join(f'0x{b:02X}' for b in expected)}], "
        f"got [{' '.join(f'0x{b:02X}' for b in response)}]"
    )

    # Check LAST_IBI_STATUS
    last_ibi_status = await tb.read_csr_field(tb.reg_map.I3C_EC.TTI.STATUS.base_addr,
                                              tb.reg_map.I3C_EC.TTI.STATUS.LAST_IBI_STATUS)
    assert last_ibi_status == 0, (
        f"LAST_IBI_STATUS after success: expected 0, got {last_ibi_status}"
    )

    # Dummy wait
    await ClockCycles(tb.clk, 10)

    await tb.teardown()


@cocotb.test()
async def test_i3c_target_ibi_data(dut):
    """
    Set a limit on how many IBI data bytes the controller may accept. Issue
    an IBI with more data and check if it gets serviced correctly. Finally
    issue yet another IBI to check if target logic flushed the remaining data
    correctly.
    """

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut)

    target = i3c_controller.add_target(TARGET_ADDRESS)
    target.set_bcr_fields(ibi_req_capable=True, ibi_payload=True)

    # Send a broadcast CCC to initialize bus timers (need STOP to start counting)
    await i3c_controller.i3c_ccc_write(ccc=CCC.BCAST.RSTDAA)

    # Limit IBI data count that the controller can accept
    i3c_controller.set_max_ibi_data_len(6)

    # Write descriptor to the TTI IBI queue
    mdb = 0xAA
    data = [0xCA, 0xFE, 0xBA, 0xCA, 0xAA, 0xBB, 0xCC, 0xDD]
    ibi_data = format_ibi_data(mdb, data)
    dut._log.info(" ".join([f"0x{d:08X}" for d in ibi_data]))
    for word in ibi_data:
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, int2dword(word), 4)

    # Wait for the IBI to be serviced, check data (truncated to 6 bytes)
    response = await i3c_controller.wait_for_ibi()
    expected = bytearray([TARGET_ADDRESS, mdb] + data[:6])
    assert response == expected, (
        f"Truncated IBI mismatch: expected [{' '.join(f'0x{b:02X}' for b in expected)}], "
        f"got [{' '.join(f'0x{b:02X}' for b in response)}]"
    )

    # T8: Controller truncated data — RTL should report IbiFailurePartialData(2)
    await ClockCycles(tb.clk, 10)
    last_ibi_status = await tb.read_csr_field(tb.reg_map.I3C_EC.TTI.STATUS.base_addr,
                                              tb.reg_map.I3C_EC.TTI.STATUS.LAST_IBI_STATUS)
    assert last_ibi_status == 2, (
        f"LAST_IBI_STATUS after truncation: expected 2 (IbiFailurePartialData), got {last_ibi_status}"
    )

    # Wait
    await ClockCycles(tb.clk, 50)

    # Do another IBI to check if remaining data from the TTI IBI queue got
    # flushed correctly.
    mdb = 0xAA
    data = [0x11, 0x22, 0x33]
    ibi_data = format_ibi_data(mdb, data)
    dut._log.info(" ".join([f"0x{d:08X}" for d in ibi_data]))
    for word in ibi_data:
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, int2dword(word), 4)

    # Wait for the IBI to be serviced, check data
    response = await i3c_controller.wait_for_ibi()
    expected = bytearray([TARGET_ADDRESS, mdb] + data)
    assert response == expected, (
        f"IBI after flush mismatch: expected [{' '.join(f'0x{b:02X}' for b in expected)}], "
        f"got [{' '.join(f'0x{b:02X}' for b in response)}]"
    )

    # Second IBI should succeed
    last_ibi_status = await tb.read_csr_field(tb.reg_map.I3C_EC.TTI.STATUS.base_addr,
                                              tb.reg_map.I3C_EC.TTI.STATUS.LAST_IBI_STATUS)
    assert last_ibi_status == 0, (
        f"LAST_IBI_STATUS after second IBI: expected 0, got {last_ibi_status}"
    )

    # Dummy wait
    await ClockCycles(tb.clk, 10)

    await tb.teardown()


@cocotb.test()
async def test_i3c_target_writes_and_reads(dut):

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut)

    tx_data_len = 16
    tx_test_data = [random.randint(0, 255) for _ in range(tx_data_len)]

    # Write data to TTI TX FIFO
    for i in range(0, len(tx_test_data), 4):
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, tx_test_data[i : i + 4], 4)

    # Write the TX descriptor
    await tb.write_csr(
        tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(tx_data_len), 4
    )

    # Send Private Write on I3C
    test_data = [[0xAA, 0x00, 0xBB, 0xCC, 0xDD], [0xDE, 0xAD, 0xBA, 0xBE]]
    for test_vec in test_data:
        await i3c_controller.i3c_write(TARGET_ADDRESS, test_vec)
        await ClockCycles(tb.clk, 10)

    # Wait for an interrupt
    wait_irq = True
    timeout = 0
    # Number of clock cycles after which we should observe an interrupt
    TIMEOUT_THRESHOLD = 50
    while wait_irq:
        timeout += 1
        await ClockCycles(tb.clk, 10)
        irq = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS.base_addr, 4))
        if irq:
            wait_irq = False
            dut._log.debug(":::Interrupt was raised:::")
        if timeout > TIMEOUT_THRESHOLD:
            wait_irq = False
            dut._log.debug(":::Timeout cancelled polling:::")

    # Read data
    recv_data = []
    for test_vec in test_data:
        recv_xfer = []
        # Read RX descriptor
        r_data = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4))
        desc_len = r_data & 0xFFFF
        assert len(test_vec) == desc_len, "Incorrect number of bytes in RX descriptor"
        remainder = desc_len % 4
        err_stat = r_data >> 28
        assert err_stat == 0, "Unexpected error detected"

        # Read RX data
        data_len = ceil(desc_len / 4)
        for _ in range(data_len):
            r_data = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, 4))
            for k in range(4):
                recv_xfer.append((r_data >> (k * 8)) & 0xFF)

        # Remove entries that are outside of the data length
        if remainder:
            for k in range(4 - remainder):
                recv_xfer.pop()
        recv_data.append(recv_xfer)

    # Compare
    dut._log.info(
        "Comparing input [{}] and RX data [{}]".format(
            " ".join(["[ " + " ".join([f"0x{d:02X}" for d in s]) + " ]" for s in test_data]),
            " ".join(["[ " + " ".join([f"0x{d:02X}" for d in s]) + " ]" for s in recv_data]),
        )
    )
    assert test_data == recv_data, f"RX data mismatch after write+read"

    # Issue a private read
    recv_data = await i3c_controller.i3c_read(TARGET_ADDRESS, 16)
    recv_data = list(recv_data.data)

    assert tx_test_data == recv_data, f"TX read-back mismatch: sent={tx_test_data}, recv={recv_data}"

    # Dummy wait
    await ClockCycles(tb.clk, 10)

    await tb.teardown()


@cocotb.test()
async def test_i3c_target_pwrite_err_detection(dut):
    I3C_DIRECT_GETSTATUS = 0x90
    PROTOCOL_ERR_LOW = 5

    # Setup
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    # Initialize
    i3c_controller, _, tb = await test_setup(dut,
        static_addr=STATIC_ADDR, virtual_static_addr=VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)
    tb.te_error_monitor.expect_error(2)

    # Enable TE2 interrupt and clear counters for register verification
    te2_en_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.TE2_ERR_EN
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.base_addr, te2_en_field, 1)
    await tb.write_csr(
        tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr, int2dword(0xFFFFFFFF), 4)
    await tb.write_csr(tb.reg_map.I3C_EC.TTI.TARGET_ERR_CNT_TE2.base_addr, int2dword(0), 4)

    for i in range(random.randint(5, 10)):
        target_addr = DYNAMIC_ADDR
        # Check error status
        err_status = await tb.read_csr_field(
            tb.reg_map.I3C_EC.TTI.STATUS.base_addr, tb.reg_map.I3C_EC.TTI.STATUS.PROTOCOL_ERROR
        )
        assert err_status == 0, "Unexpected error detected"

        # Read target status to ensure there's no error
        result = await i3c_controller.i3c_ccc_read(
            ccc=I3C_DIRECT_GETSTATUS, addr=target_addr, count=2
        )
        status = result[0][1]
        status = int.from_bytes(status, byteorder="big", signed=False)
        assert (
            (status >> PROTOCOL_ERR_LOW) & 1
        ) == 0, "GETSTATUS reported unexpected Protocol Error"

        # Test corner case with data length 1
        TRANSFER_LENGTH = random.randint(1, 256) if i != 0 else 1

        # Send Private Write on I3C
        test_data = [random.randint(0, 255) for _ in range(TRANSFER_LENGTH)]
        await i3c_controller.i3c_write(target_addr, test_data, inject_tbit_err=True)
        await ClockCycles(tb.clk, 10)

        # Check error status
        err_status = await tb.read_csr_field(
            tb.reg_map.I3C_EC.TTI.STATUS.base_addr, tb.reg_map.I3C_EC.TTI.STATUS.PROTOCOL_ERROR
        )
        assert err_status == 1, "Expected error was not detected"
        # Read RX descriptor
        data = dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4)
        )
        err_stat = data >> 28
        assert err_stat == 1, "Expected error detection"

        # Verify TE2 error counter and status (delta-based: counter is level-sensitive)
        te2_cnt = dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.TTI.TARGET_ERR_CNT_TE2.base_addr, 4)) & 0xFF
        te2_stat = await tb.read_csr_field(
            tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr,
            tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.TE2_ERR_STAT)
        dut._log.info(f"TE2 counter={te2_cnt}, status={te2_stat}")
        assert te2_cnt >= 1, f"Expected TE2 counter >= 1, got {te2_cnt}"
        assert te2_stat == 1, f"Expected TE2_ERR_STAT=1, got {te2_stat}"
        # W1C the status bit
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr,
            tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.TE2_ERR_STAT, 1)

        desc_len = data & 0xFFFF
        # All bytes have corrupted T-bits so none enter the RX FIFO
        assert desc_len == 0, f"Expected desc_len 0 (parity-errored bytes dropped), got {desc_len}"
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST,
            1,
        )
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST,
            0,
        )

        # Read target status to clear error
        result = await i3c_controller.i3c_ccc_read(
            ccc=I3C_DIRECT_GETSTATUS, addr=target_addr, count=2
        )
        status = result[0][1]
        status = int.from_bytes(status, byteorder="big", signed=False)
        assert ((status >> PROTOCOL_ERR_LOW) & 1) == 1, "GETSTATUS did not report Protocol Error"

        # Check error status
        err_status = await tb.read_csr_field(
            tb.reg_map.I3C_EC.TTI.STATUS.base_addr, tb.reg_map.I3C_EC.TTI.STATUS.PROTOCOL_ERROR
        )
        assert err_status == 0, "Unexpected error detected"
        await ClockCycles(tb.clk, 100)

    await ClockCycles(tb.clk, 100)
    tb.te_error_monitor.check()

    await tb.teardown()


@cocotb.test()
async def test_i3c_target_pwrite_overflow_detection(dut):
    I3C_DIRECT_GETSTATUS = 0x90
    PROTOCOL_ERR_LOW = 5

    # Setup
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    # Initialize
    i3c_controller, _, tb = await test_setup(dut,
        static_addr=STATIC_ADDR, virtual_static_addr=VIRT_STATIC_ADDR,
        dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)

    for _ in range(random.randint(5, 10)):
        target_addr = DYNAMIC_ADDR
        # Check error status
        err_status = await tb.read_csr_field(
            tb.reg_map.I3C_EC.TTI.STATUS.base_addr, tb.reg_map.I3C_EC.TTI.STATUS.PROTOCOL_ERROR
        )
        assert err_status == 0, "Unexpected error detected"

        # Read target status to ensure there's no error
        result = await i3c_controller.i3c_ccc_read(
            ccc=I3C_DIRECT_GETSTATUS, addr=target_addr, count=2
        )
        status = result[0][1]
        status = int.from_bytes(status, byteorder="big", signed=False)
        assert (
            (status >> PROTOCOL_ERR_LOW) & 1
        ) == 0, "GETSTATUS reported unexpected Protocol Error"
        # FIFO size is 256 bytes + 4 bytes in the width conversion stage
        TRANSFER_LENGTH = random.randint(261, 512)

        # Send Private Write on I3C
        test_data = [random.randint(0, 255) for _ in range(TRANSFER_LENGTH)]
        await i3c_controller.i3c_write(target_addr, test_data)
        await ClockCycles(tb.clk, 10)

        # Check error status
        err_status = await tb.read_csr_field(
            tb.reg_map.I3C_EC.TTI.STATUS.base_addr, tb.reg_map.I3C_EC.TTI.STATUS.PROTOCOL_ERROR
        )
        assert err_status == 0, "Overflow is not a Protocol Error"
        # Read RX descriptor
        data = dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4)
        )
        err_stat = data >> 28
        assert err_stat == 1, "Expected error detection"

        desc_len = data & 0xFFFF
        assert desc_len == 260, f"Descriptor mismatch: expected 260, got {desc_len}"

        # T12: Read and verify surviving bytes match the first 260 bytes sent
        rx_data = []
        for _ in range(ceil(desc_len / 4)):
            word = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, 4))
            for k in range(4):
                rx_data.append((word >> (k * 8)) & 0xFF)
        rx_data = rx_data[:desc_len]
        assert rx_data == test_data[:desc_len], (
            f"Overflow: first {desc_len} bytes do not match sent data"
        )

        # Clear RX data FIFO
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST,
            1,
        )
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST,
            0,
        )

        await ClockCycles(tb.clk, 100)

    await ClockCycles(tb.clk, 100)

    await tb.teardown()


@cocotb.test()
async def test_i3c_target_private_read_sizes_and_abort(dut):
    """
    Test private read transfers with specific sizes and controller-initiated aborts.

    1. Private read of exactly 256 bytes
    2. Private read of exactly 8 bytes
    3. Private read of exactly 11 bytes (non-word-aligned)
    4. Private read: target has 64 bytes, controller aborts after 4 bytes
    5. Private read: target has 64 bytes, controller aborts after 5 bytes
    """

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut)

    async def enqueue_tx_data(data):
        """Write data to TTI TX FIFO and TX descriptor."""
        length = len(data)

        # Write data to TTI TX FIFO
        for i in range((length + 3) // 4):
            word = data[4 * i]
            if 4 * i + 1 < length:
                word |= data[4 * i + 1] << 8
            if 4 * i + 2 < length:
                word |= data[4 * i + 2] << 16
            if 4 * i + 3 < length:
                word |= data[4 * i + 3] << 24

            await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, int2dword(word), 4)

        # Write the TX descriptor
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(length), 4)

    def compare(expected, received):
        dut._log.info("Expected: [" + " ".join([f"{d:02X}" for d in expected]) + "]")
        dut._log.info("Received: [" + " ".join([f"{d:02X}" for d in received]) + "]")
        assert expected == received, f"Data mismatch: exp=[{' '.join(f'{d:02X}' for d in expected)}] got=[{' '.join(f'{d:02X}' for d in received)}]"

    # ---- Test 1: Private read of exactly 256 bytes ----
    dut._log.info("Test 1: Private read of 256 bytes")
    tx_data_256 = [random.randint(0, 255) for _ in range(256)]
    await enqueue_tx_data(tx_data_256)
    rx_resp = await i3c_controller.i3c_read(TARGET_ADDRESS, 256)
    assert not rx_resp.nack, "Unexpected NACK on 256-byte read"
    compare(tx_data_256, list(rx_resp.data))
    await ClockCycles(tb.clk, 10)

    # ---- Test 2: Private read of exactly 8 bytes ----
    dut._log.info("Test 2: Private read of 8 bytes")
    tx_data_8 = [random.randint(0, 255) for _ in range(8)]
    await enqueue_tx_data(tx_data_8)
    rx_resp = await i3c_controller.i3c_read(TARGET_ADDRESS, 8)
    assert not rx_resp.nack, "Unexpected NACK on 8-byte read"
    compare(tx_data_8, list(rx_resp.data))
    await ClockCycles(tb.clk, 10)

    # ---- Test 3: Private read of exactly 11 bytes (non-word-aligned) ----
    dut._log.info("Test 3: Private read of 11 bytes")
    tx_data_11 = [random.randint(0, 255) for _ in range(11)]
    await enqueue_tx_data(tx_data_11)
    rx_resp = await i3c_controller.i3c_read(TARGET_ADDRESS, 11)
    assert not rx_resp.nack, "Unexpected NACK on 11-byte read"
    compare(tx_data_11, list(rx_resp.data))
    await ClockCycles(tb.clk, 10)

    # ---- Test 4: Controller aborts after 4 bytes (target has 64) ----
    dut._log.info("Test 4: Controller abort after 4 bytes (word-aligned)")
    tx_data_64a = [random.randint(0, 255) for _ in range(64)]
    await enqueue_tx_data(tx_data_64a)
    rx_resp = await i3c_controller.i3c_read(TARGET_ADDRESS, 4)
    assert not rx_resp.nack, "Unexpected NACK on abort read"
    compare(tx_data_64a[:4], list(rx_resp.data))
    await ClockCycles(tb.clk, 10)

    # After abort, do a normal transfer to verify the target recovered
    dut._log.info("Test 4 recovery: Normal 8-byte read after abort")
    tx_data_recover = [random.randint(0, 255) for _ in range(8)]
    await enqueue_tx_data(tx_data_recover)
    rx_resp = await i3c_controller.i3c_read(TARGET_ADDRESS, 8)
    assert not rx_resp.nack, "Unexpected NACK on recovery read"
    compare(tx_data_recover, list(rx_resp.data))
    await ClockCycles(tb.clk, 10)

    # ---- Test 5: Controller aborts after 5 bytes (non-word-aligned) ----
    dut._log.info("Test 5: Controller abort after 5 bytes (non-word-aligned)")
    tx_data_64b = [random.randint(0, 255) for _ in range(64)]
    await enqueue_tx_data(tx_data_64b)
    rx_resp = await i3c_controller.i3c_read(TARGET_ADDRESS, 5)
    assert not rx_resp.nack, "Unexpected NACK on abort read"
    compare(tx_data_64b[:5], list(rx_resp.data))
    await ClockCycles(tb.clk, 10)

    # After abort, do a normal transfer to verify the target recovered
    dut._log.info("Test 5 recovery: Normal 8-byte read after abort")
    tx_data_recover2 = [random.randint(0, 255) for _ in range(8)]
    await enqueue_tx_data(tx_data_recover2)
    rx_resp = await i3c_controller.i3c_read(TARGET_ADDRESS, 8)
    assert not rx_resp.nack, "Unexpected NACK on recovery read"
    compare(tx_data_recover2, list(rx_resp.data))
    await ClockCycles(tb.clk, 10)

    await ClockCycles(tb.clk, 100)

    await tb.teardown()


@cocotb.test()
async def test_i3c_target_tx_flush_clears_converter(dut):
    """
    Verify that TTI RESET_CONTROL.TX_DATA_RST flushes both the TX FIFO
    and the width_converter_Nto8 shift register.

    Steps:
    1. Write 8 bytes (2 dwords) to the TX FIFO (no descriptor yet, so no read).
       The first dword is eagerly pulled into the Nto8 converter's sreg.
    2. Flush TX data queue via RESET_CONTROL.TX_DATA_RST.
    3. Write new data and a descriptor, then perform a private read.
    4. Verify the read returns only the new data (no stale sreg bytes).
    """

    i3c_controller, i3c_target, tb = await test_setup(dut)

    def compare(expected, received):
        dut._log.info("Expected: [" + " ".join([f"{d:02X}" for d in expected]) + "]")
        dut._log.info("Received: [" + " ".join([f"{d:02X}" for d in received]) + "]")
        assert expected == received, f"Data mismatch: exp=[{' '.join(f'{d:02X}' for d in expected)}] got=[{' '.join(f'{d:02X}' for d in received)}]"

    async def enqueue_tx_data(data):
        """Write data to TTI TX FIFO and TX descriptor."""
        length = len(data)
        for i in range((length + 3) // 4):
            word = data[4 * i]
            if 4 * i + 1 < length:
                word |= data[4 * i + 1] << 8
            if 4 * i + 2 < length:
                word |= data[4 * i + 2] << 16
            if 4 * i + 3 < length:
                word |= data[4 * i + 3] << 24
            await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, int2dword(word), 4)
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(length), 4)

    # Step 1: Write stale data to TX FIFO (data only, no descriptor)
    stale_data = [0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE]
    for i in range(2):
        word = (stale_data[4 * i]
                | stale_data[4 * i + 1] << 8
                | stale_data[4 * i + 2] << 16
                | stale_data[4 * i + 3] << 24)
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, int2dword(word), 4)

    # Wait for the converter to pull the first dword into its sreg
    await ClockCycles(tb.clk, 10)

    # Step 2: Flush TX data queue via RESET_CONTROL
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.TX_DATA_RST,
        1,
    )
    await ClockCycles(tb.clk, 10)
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.TX_DATA_RST,
        0,
    )

    # Also flush the TX descriptor queue
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.TX_DESC_RST,
        1,
    )
    await ClockCycles(tb.clk, 10)
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.TX_DESC_RST,
        0,
    )
    await ClockCycles(tb.clk, 10)

    # Step 3: Write new data and enqueue descriptor, then do private read
    new_data = [random.randint(0, 255) for _ in range(8)]
    await enqueue_tx_data(new_data)
    rx_resp = await i3c_controller.i3c_read(TARGET_ADDRESS, 8)
    assert not rx_resp.nack, "Unexpected NACK on post-flush read"

    # Step 4: Verify we got the new data, not stale sreg contents
    compare(new_data, list(rx_resp.data))

    await ClockCycles(tb.clk, 100)


# =============================================================================
# Private Write Abort Test Helpers
# =============================================================================

    await tb.teardown()

async def _read_rx_descriptor(tb, dut, timeout_clks=500):
    """Poll for RX descriptor interrupt, read and return (byte_count, err_stat) or None."""
    for _ in range(timeout_clks):
        intrs = await get_interrupt_status(tb)
        if intrs["RX_DESC_STAT"]:
            data = dword2int(
                await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4)
            )
            byte_count = data & 0xFFFF
            err_stat = data >> 28
            return (byte_count, err_stat)
        await RisingEdge(tb.clk)
    return None


async def _read_rx_data(tb, byte_count):
    """Read byte_count bytes from the RX data queue."""
    data_len = ceil(byte_count / 4)
    rx_data = []
    for _ in range(data_len):
        data = dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, 4)
        )
        for k in range(4):
            rx_data.append((data >> (k * 8)) & 0xFF)
    return rx_data[:byte_count]


async def _enable_rx_interrupt(tb):
    """Enable the RX descriptor interrupt."""
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.INTERRUPT_ENABLE.base_addr,
        tb.reg_map.I3C_EC.TTI.INTERRUPT_ENABLE.RX_DESC_STAT_EN,
        1,
    )


async def _do_lowlevel_private_write(i3c_controller, addr, complete_bytes):
    """
    Send a complete private write using low-level BFM methods (for parity with
    abort tests that also use low-level methods).
    """
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(addr)
    assert ack, f"Target 0x{addr:02X} should ACK private write"

    for byte in complete_bytes:
        await i3c_controller.send_byte_tbit(byte)

    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()


# =============================================================================
# Scenario F: Normal STOP after complete 8-byte private write (baseline)
# =============================================================================
@cocotb.test()
async def test_priv_write_normal_stop_baseline(dut):
    """
    Baseline: 8-byte private write completes normally with STOP.
    Verifies RX descriptor byte count = 8 and data matches.
    """
    i3c_controller, _, tb = await test_setup(dut)
    await _enable_rx_interrupt(tb)

    test_data = [0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE]
    await _do_lowlevel_private_write(i3c_controller, TARGET_ADDRESS, test_data)
    await ClockCycles(tb.clk, 50)

    result = await _read_rx_descriptor(tb, dut)
    assert result is not None, "Expected RX descriptor after normal 8-byte write"
    byte_count, err_stat = result
    assert byte_count == 8, f"Expected byte_count=8, got {byte_count}"
    assert err_stat == 0, f"Expected no error, got err_stat=0x{err_stat:X}"

    rx_data = await _read_rx_data(tb, byte_count)
    assert rx_data == test_data, f"Data mismatch: expected {test_data}, got {rx_data}"

    await ClockCycles(tb.clk, 50)


# =============================================================================
# Scenario A: STOP mid-byte during RxPWriteData
# =============================================================================

    await tb.teardown()
@cocotb.test()
async def test_priv_write_stop_mid_byte(dut):
    """
    8-byte private write. After 5 complete bytes+T-bits, send 4 bits of byte 6,
    then STOP. Verifies RX descriptor reports 5 bytes and data matches.
    Also verifies clean recovery with a subsequent normal write.
    """
    i3c_controller, _, tb = await test_setup(dut)
    await _enable_rx_interrupt(tb)

    test_data = [0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE]

    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(TARGET_ADDRESS)
    assert ack, "Target should ACK"

    # Send 5 complete bytes with T-bits
    for byte in test_data[:5]:
        await i3c_controller.send_byte_tbit(byte)

    # Send 4 bits of byte 6 (partial byte — FSM in RxPWriteData)
    byte6 = test_data[5]
    for i in range(4):
        await i3c_controller.send_bit(bool(byte6 & (1 << (7 - i))))

    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 50)

    # Check descriptor: should report 5 complete bytes
    result = await _read_rx_descriptor(tb, dut)
    assert result is not None, "Expected RX descriptor after STOP mid-byte"
    byte_count, err_stat = result
    assert byte_count == 5, f"Expected byte_count=5, got {byte_count}"

    rx_data = await _read_rx_data(tb, byte_count)
    assert rx_data == test_data[:5], f"Data mismatch: expected {test_data[:5]}, got {rx_data}"

    # Recovery: next full write should work normally
    recovery_data = [0x11, 0x22, 0x33, 0x44]
    await _do_lowlevel_private_write(i3c_controller, TARGET_ADDRESS, recovery_data)
    await ClockCycles(tb.clk, 50)

    result = await _read_rx_descriptor(tb, dut)
    assert result is not None, "Expected RX descriptor after recovery write"
    byte_count, err_stat = result
    assert byte_count == 4, f"Recovery: expected byte_count=4, got {byte_count}"

    rx_data = await _read_rx_data(tb, byte_count)
    assert rx_data == recovery_data, \
        f"Recovery data mismatch: expected {recovery_data}, got {rx_data}"

    await ClockCycles(tb.clk, 50)


# =============================================================================
# Scenario B: Sr mid-byte during RxPWriteData
# =============================================================================

    await tb.teardown()
@cocotb.test()
async def test_priv_write_sr_mid_byte(dut):
    """
    8-byte private write. After 5 complete bytes, send 4 bits of byte 6,
    then Repeated Start + STOP. Verifies RX descriptor reports 5 bytes.
    Also verifies clean recovery.
    """
    i3c_controller, _, tb = await test_setup(dut)
    await _enable_rx_interrupt(tb)

    test_data = [0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE]

    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(TARGET_ADDRESS)
    assert ack, "Target should ACK"

    for byte in test_data[:5]:
        await i3c_controller.send_byte_tbit(byte)

    byte6 = test_data[5]
    for i in range(4):
        await i3c_controller.send_bit(bool(byte6 & (1 << (7 - i))))

    # Repeated Start (abort), then STOP to end the frame
    await i3c_controller.send_start()
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 50)

    result = await _read_rx_descriptor(tb, dut)
    assert result is not None, "Expected RX descriptor after Sr mid-byte"
    byte_count, err_stat = result
    assert byte_count == 5, f"Expected byte_count=5, got {byte_count}"

    rx_data = await _read_rx_data(tb, byte_count)
    assert rx_data == test_data[:5], f"Data mismatch: expected {test_data[:5]}, got {rx_data}"

    # Recovery
    recovery_data = [0x55, 0x66, 0x77]
    await _do_lowlevel_private_write(i3c_controller, TARGET_ADDRESS, recovery_data)
    await ClockCycles(tb.clk, 50)

    result = await _read_rx_descriptor(tb, dut)
    assert result is not None, "Expected RX descriptor after recovery write"
    byte_count, _ = result
    assert byte_count == 3, f"Recovery: expected byte_count=3, got {byte_count}"

    rx_data = await _read_rx_data(tb, byte_count)
    assert rx_data == recovery_data, \
        f"Recovery data mismatch: expected {recovery_data}, got {rx_data}"

    await ClockCycles(tb.clk, 50)


# =============================================================================
# Scenario C: STOP during T-bit (RxPWriteTbit)
# BLOCKED BY DESIGN BUG: see verification/bugs/stop_during_tbit.md
# =============================================================================

    await tb.teardown()
@cocotb.test()
async def test_priv_write_stop_during_tbit(dut):
    """
    BLOCKED BY DESIGN BUG: see verification/bugs/stop_during_tbit.md

    8-byte private write. After 5 complete bytes+T-bits, send 8 data bits of
    byte 6 (no T-bit), then STOP fires while FSM is in RxPWriteTbit.

    Per spec (Sec.5.1.2.3.3): The Target shall only push a byte after verifying
    T-bit parity. A STOP during the T-bit means parity was never checked, so
    the byte shall NOT be pushed to the RX queue. An RX descriptor shall be
    generated for the 5 previously completed bytes.

    RTL bug: rx_fifo_wvalid_raw fires on any exit from RxPWriteTbit (including
    STOP override), pushing the unchecked byte. rx_last_byte_o does not fire
    because state_q != RxPWriteData, so no descriptor is generated.
    """
    i3c_controller, _, tb = await test_setup(dut)
    await _enable_rx_interrupt(tb)

    # Use byte value with LSB=0 so SDA is LOW after 8th data bit
    complete_data = [0xDE, 0xAD, 0xBE, 0xEF, 0xCA]
    abort_byte = 0xFE  # bits: 11111110, LSB=0 → SDA=0 after 8 data bits

    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(TARGET_ADDRESS)
    assert ack, "Target should ACK"

    for byte in complete_data:
        await i3c_controller.send_byte_tbit(byte)

    # Send 8 data bits of the abort byte individually (no T-bit)
    for i in range(8):
        await i3c_controller.send_bit(bool(abort_byte & (1 << (7 - i))))

    # SCL is HIGH, SDA is LOW (abort_byte LSB=0).
    # Create STOP without providing a SCL posedge for the T-bit:
    # SDA LOW→HIGH while SCL is HIGH = STOP condition.
    # The bus_rx_flow never gets a SCL posedge for the T-bit, so bus_rx_rsp.done
    # does NOT fire. The FSM is in RxPWriteTbit when bus_stop_det_i fires.
    await Timer(1, "ns")
    i3c_controller.sda = 1  # SDA rising → STOP detected by bus_monitor
    await Timer(100, "ns")

    # Fix BFM state to reflect bus idle
    i3c_controller._state = I3cState.FREE
    i3c_controller.hold_data = False
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 100)

    # Per spec: descriptor should be generated with byte_count = 5
    # (the 5 complete bytes; the abort byte should NOT be counted)
    result = await _read_rx_descriptor(tb, dut)
    assert result is not None, \
        "Expected RX descriptor after STOP during T-bit (5 complete bytes received)"
    byte_count, err_stat = result
    assert byte_count == 5, f"Expected byte_count=5, got {byte_count}"

    rx_data = await _read_rx_data(tb, byte_count)
    assert rx_data == complete_data, \
        f"Data mismatch: expected {complete_data}, got {rx_data}"

    # Recovery: verify next transfer's descriptor byte count is correct
    # (not corrupted by stale byte_counter)
    recovery_data = [0x11, 0x22, 0x33]
    await _do_lowlevel_private_write(i3c_controller, TARGET_ADDRESS, recovery_data)
    await ClockCycles(tb.clk, 50)

    result = await _read_rx_descriptor(tb, dut)
    assert result is not None, "Expected RX descriptor after recovery write"
    byte_count, _ = result
    assert byte_count == 3, f"Recovery: expected byte_count=3, got {byte_count}"

    rx_data = await _read_rx_data(tb, byte_count)
    assert rx_data == recovery_data, \
        f"Recovery data mismatch: expected {recovery_data}, got {rx_data}"

    await ClockCycles(tb.clk, 50)


# =============================================================================
# Scenario D: Sr during T-bit (RxPWriteTbit)
# BLOCKED BY DESIGN BUG: see verification/bugs/sr_during_tbit.md
# =============================================================================

    await tb.teardown()
@cocotb.test()
async def test_priv_write_sr_during_tbit(dut):
    """
    BLOCKED BY DESIGN BUG: see verification/bugs/sr_during_tbit.md

    8-byte private write. After 5 complete bytes+T-bits, send 8 data bits of
    byte 6, then Sr fires while FSM is in RxPWriteTbit.

    Per spec (Sec.5.1.2.3.3): Same as Scenario C — byte shall not be pushed
    without T-bit parity check. Descriptor shall be generated for 5 bytes.

    RTL bug: Same as Scenario C — rx_fifo_wvalid_raw fires spuriously,
    rx_last_byte_o does not fire, no descriptor generated.
    """
    i3c_controller, _, tb = await test_setup(dut)
    await _enable_rx_interrupt(tb)

    complete_data = [0xDE, 0xAD, 0xBE, 0xEF, 0xCA]
    # Use byte value with LSB=1 so SDA is HIGH after 8th data bit
    abort_byte = 0xAB  # bits: 10101011, LSB=1 → SDA=1 after 8 data bits

    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(TARGET_ADDRESS)
    assert ack, "Target should ACK"

    for byte in complete_data:
        await i3c_controller.send_byte_tbit(byte)

    for i in range(8):
        await i3c_controller.send_bit(bool(abort_byte & (1 << (7 - i))))

    # SCL is HIGH, SDA is HIGH (abort_byte LSB=1).
    # Create Sr without providing a SCL posedge for the T-bit:
    # SDA HIGH→LOW while SCL is HIGH = START/RESTART condition.
    await Timer(1, "ns")
    i3c_controller.sda = 0  # SDA falling → RESTART detected by bus_monitor
    await Timer(100, "ns")

    # Complete the bus frame with STOP
    i3c_controller.scl = 0
    await Timer(40, "ns")
    i3c_controller.sda = 0
    await Timer(40, "ns")
    i3c_controller.scl = 1
    await Timer(40, "ns")
    i3c_controller.sda = 1  # STOP
    await Timer(100, "ns")

    i3c_controller._state = I3cState.FREE
    i3c_controller.hold_data = False
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 100)

    # Per spec: descriptor should be generated with byte_count = 5
    result = await _read_rx_descriptor(tb, dut)
    assert result is not None, \
        "Expected RX descriptor after Sr during T-bit (5 complete bytes received)"
    byte_count, err_stat = result
    assert byte_count == 5, f"Expected byte_count=5, got {byte_count}"

    rx_data = await _read_rx_data(tb, byte_count)
    assert rx_data == complete_data, \
        f"Data mismatch: expected {complete_data}, got {rx_data}"

    # Recovery
    recovery_data = [0x44, 0x55]
    await _do_lowlevel_private_write(i3c_controller, TARGET_ADDRESS, recovery_data)
    await ClockCycles(tb.clk, 50)

    result = await _read_rx_descriptor(tb, dut)
    assert result is not None, "Expected RX descriptor after recovery write"
    byte_count, _ = result
    assert byte_count == 2, f"Recovery: expected byte_count=2, got {byte_count}"

    rx_data = await _read_rx_data(tb, byte_count)
    assert rx_data == recovery_data, \
        f"Recovery data mismatch: expected {recovery_data}, got {rx_data}"

    await ClockCycles(tb.clk, 50)


# =============================================================================
# Scenario E: Tight timing — Sr immediately after last complete byte
# =============================================================================

    await tb.teardown()
@cocotb.test()
async def test_priv_write_tight_timing_sr(dut):
    """
    5-byte private write. All bytes+T-bits complete normally. Sr issued
    immediately after the last T-bit (tight timing). Verifies descriptor
    reports exactly 5 bytes (not 4 due to off-by-one).
    """
    i3c_controller, _, tb = await test_setup(dut)
    await _enable_rx_interrupt(tb)

    test_data = [0x11, 0x22, 0x33, 0x44, 0x55]

    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    await i3c_controller.write_addr_header(0x7E)
    await i3c_controller.send_start()
    ack = await i3c_controller.write_addr_header(TARGET_ADDRESS)
    assert ack, "Target should ACK"

    # Send all 5 bytes with T-bits
    for byte in test_data:
        await i3c_controller.send_byte_tbit(byte)

    # Immediately send Sr (FSM just returned to RxPWriteData from last T-bit)
    # The tight timing tests whether rx_fifo_wvalid_o and rx_last_byte_o
    # can fire simultaneously without off-by-one in descriptor byte_counter.
    await i3c_controller.send_start()
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 50)

    result = await _read_rx_descriptor(tb, dut)
    assert result is not None, "Expected RX descriptor after tight-timing Sr"
    byte_count, err_stat = result
    assert byte_count == 5, f"Expected byte_count=5, got {byte_count}"
    assert err_stat == 0, f"Expected no error, got err_stat=0x{err_stat:X}"

    rx_data = await _read_rx_data(tb, byte_count)
    assert rx_data == test_data, f"Data mismatch: expected {test_data}, got {rx_data}"

    await ClockCycles(tb.clk, 50)

    await tb.teardown()
