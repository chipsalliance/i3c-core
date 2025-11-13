# SPDX-License-Identifier: Apache-2.0

import functools
import logging
import random
from math import ceil

from boot import boot_init
from bus2csr import dword2int, int2dword
from cocotbext_i3c.i3c_controller import I3cController
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface
from utils import format_ibi_data, get_interrupt_status

import cocotb
from cocotb.triggers import ClockCycles, RisingEdge, Timer

VALID_I3C_ADDRESSES = (
    [i for i in range(0x03, 0x3E)]
    + [i for i in range(0x3F, 0x5B)]
    + [i for i in range(0x5C, 0x5E)]
    + [i for i in range(0x5F, 0x6E)]
    + [i for i in range(0x6F, 0x76)]
    + [i for i in range(0x77, 0x7A)]
    + [0x7B, 0x7D]
)
TARGET_ADDRESS = 0x5A


# Wraps cocotb.test with a default timeout
def cocotb_test(timeout=200, unit="us", expect_fail=False, expect_error=(), skip=False, stage=0):
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


async def test_setup(dut, fclk=100.0, fbus=12.5, verify_boot=True,
                     static_addr=0x5A, virtual_static_addr=0x5B,
                     dynamic_addr=None, virtual_dynamic_addr=None):
    """
    Sets up controller, target models and top-level core interface
    """

    cocotb.log.setLevel(logging.INFO)

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

    await boot_init(tb, timings, verify_boot,
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


@cocotb_test()
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
            while irq.value == 0:
                await RisingEdge(tb.clk)

            # Read & check interrupt status
            intrs = await get_interrupt_status(tb)
            assert intrs["RX_DESC_STAT"] == 1

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
            while irq.value != 0:
                await RisingEdge(tb.clk)

            # Read & check interrupt status
            intrs = await get_interrupt_status(tb)
            assert intrs["RX_DESC_STAT"] == 0

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
    rx = cocotb.start_soon(rx_agent())

    # Send Private Writes on I3C. The agent will handle them as their come
    for test_vec in test_data:
        await i3c_controller.i3c_write(TARGET_ADDRESS, test_vec)
        await ClockCycles(tb.clk, 10)

    # Wait
    await rx

    # Compare
    dut._log.info(
        "Comparing input [{}] and RX data [{}]".format(
            " ".join(["[ " + " ".join([f"0x{d:02X}" for d in s]) + " ]" for s in test_data]),
            " ".join(["[ " + " ".join([f"0x{d:02X}" for d in s]) + " ]" for s in recv_data]),
        )
    )
    assert test_data == recv_data


@cocotb_test()
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
        assert expected == received

    # .............

    # Test N consecutive transfers. Do not queue new transfers before completion
    dut._log.info("N consecutive transfers, one at a time")
    for i in range(2):
        tx_data = await make_transfer()
        rx_data = await i3c_controller.i3c_read(TARGET_ADDRESS, len(tx_data))
        rx_data = list(rx_data.data)
        compare(tx_data, rx_data)

    # Test N consecutive transfers. First enqueue, then service
    dut._log.info("N consecutive transfers, enqueued then serviced")
    tx_data = []
    for i in range(3):
        tx_data.append(await make_transfer())

    for i in range(3):
        rx_data = await i3c_controller.i3c_read(TARGET_ADDRESS, len(tx_data[i]))
        rx_data = list(rx_data.data)
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

        rx_data = await i3c_controller.i3c_read(TARGET_ADDRESS, lnt)
        rx_data = list(rx_data.data)
        compare(tx_data[i], rx_data, lnt)

    # Test N consecutive transfers. Do not queue new transfers before completion
    dut._log.info("N consecutive transfers, one at a time (again)")
    for i in range(2):
        tx_data = await make_transfer()
        rx_data = await i3c_controller.i3c_read(TARGET_ADDRESS, len(tx_data))
        rx_data = list(rx_data.data)
        compare(tx_data, rx_data)



@cocotb_test()
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
        assert expected == received

    # issue 20 random read transactions
    # randomly choose to inicialize the FIFO or not
    # if FIFO is not initialized the transation should be NACKed
    for i in range(20):
        transfer_data = random.choice([True, False])
        if transfer_data:
            tx_data = await make_transfer()
            response = await i3c_controller.i3c_read(TARGET_ADDRESS, len(tx_data), send_rsvd = random.choice([True, False]))
            assert not response.nack
            rx_data = list(response.data)
            compare(tx_data, rx_data)
        else:
            response = await i3c_controller.i3c_read(TARGET_ADDRESS, random.randint(1, 16), send_rsvd = random.choice([True, False]))
            assert response.nack


@cocotb_test(timeout=50000)
async def test_i3c_target_read_to_multiple_targets(dut):

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut, fclk=100)

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
        assert expected == received

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
            assert nack == response.nack
            if not nack:
                rx_data = list(response.data)
                compare(tx_data, rx_data)


@cocotb_test()
async def test_i3c_target_ibi(dut):
    """
    IBI test. Sends an IBI with no data and then subsequently IBIs with
    different data lengths. Expects the controller to ACK all of them and
    return correctly received data.
    """

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut, verify_boot=True)

    target = i3c_controller.add_target(TARGET_ADDRESS)
    target.set_bcr_fields(ibi_req_capable=True, ibi_payload=True)

    result = True

    # Enable IBI ACK-ing
    i3c_controller.enable_ibi(True)

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
    if response != expected:
        dut._log.critical(
            "IBI MDB/data mismatch! tgt: [ {}] ctl: [ {}]".format(
                "".join("".join(f"0x{d:02X}") + " " for d in expected),
                "".join("".join(f"0x{d:02X}") + " " for d in response),
            )
        )
        result = False

    # Check LAST_IBI_STATUS
    status = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.STATUS.base_addr, 4))
    last_ibi_status = (status & (3 << 14)) >> 14
    expected_status = 0
    if last_ibi_status != expected_status:
        dut._log.critical(
            f"Incorrect IBI status, expected {expected_status}, got {last_ibi_status}"
        )
        result = False

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
        if response != expected:
            dut._log.critical(
                "IBI MDB/data mismatch! tgt: [ {}] ctl: [ {}]".format(
                    "".join("".join(f"0x{d:02X}") + " " for d in expected),
                    "".join("".join(f"0x{d:02X}") + " " for d in response),
                )
            )
            result = False

        # Check LAST_IBI_STATUS
        status = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.STATUS.base_addr, 4))
        last_ibi_status = (status & (3 << 14)) >> 14
        expected_status = 0
        if last_ibi_status != expected_status:
            dut._log.critical(
                f"Incorrect IBI status, expected {expected_status}, got {last_ibi_status}"
            )
            result = False

    # Report the test result
    assert result


@cocotb_test()
async def test_i3c_target_ibi_retry(dut):
    """
    Disables IBI ACK-ing in controller, sends an IBI, waits some time for the
    target to retry IBI transmission, re-enables IBI-acking, waits until the
    IBI gets serviced, check if IBI data was received correctly.
    """

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut, verify_boot=True)

    # Enable indefinite IBI retries
    #  TTI.CONTROL.IBI_EN        = 1
    #  TTI.CONTROL.IBI_RETRY_NUM = 7 (means indefinite)
    await tb.write_csr(tb.reg_map.I3C_EC.TTI.CONTROL.base_addr, int2dword(0x0000F000), 4)

    target = i3c_controller.add_target(TARGET_ADDRESS)
    target.set_bcr_fields(ibi_req_capable=True, ibi_payload=True)

    result = True

    # Disable IBI ACK-ing
    i3c_controller.enable_ibi(False)

    # Write descriptor to the TTI IBI queue
    mdb = 0xAA
    data = [0xBE, 0xEF]
    ibi_data = format_ibi_data(mdb, data)
    dut._log.info(" ".join([f"0x{d:08X}" for d in ibi_data]))
    for word in ibi_data:
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, int2dword(word), 4)

    # Wait for some time so that the target gets a change to retry IBI
    # transmission
    await Timer(10, "us")

    # Check LAST_IBI_STATUS
    status = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.STATUS.base_addr, 4))
    last_ibi_status = (status & (3 << 14)) >> 14
    expected_status = 3
    if last_ibi_status != expected_status:
        dut._log.critical(
            f"Incorrect IBI status, expected {expected_status}, got {last_ibi_status}"
        )
        result = False

    # Re-enable IBI ACK-ing
    i3c_controller.enable_ibi(True)

    # Wait for the IBI to be serviced, check data
    response = await i3c_controller.wait_for_ibi()
    expected = bytearray([TARGET_ADDRESS, mdb] + data)
    if response != expected:
        dut._log.critical(
            "IBI MDB/data mismatch! tgt: [ {}] ctl: [ {}]".format(
                "".join("".join(f"0x{d:02X}") + " " for d in expected),
                "".join("".join(f"0x{d:02X}") + " " for d in response),
            )
        )
        result = False

    # Check LAST_IBI_STATUS
    status = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.STATUS.base_addr, 4))
    last_ibi_status = (status & (3 << 14)) >> 14
    expected_status = 0
    if last_ibi_status != expected_status:
        dut._log.critical(
            f"Incorrect IBI status, expected {expected_status}, got {last_ibi_status}"
        )
        result = False

    # Report the test result
    assert result


@cocotb_test()
async def test_i3c_target_ibi_data(dut):
    """
    Set a limit on how many IBI data bytes the controller may accept. Issue
    an IBI with more data and check if it gets serviced correctly. Finally
    issue yet another IBI to check if target logic flushed the remaining data
    correctly.
    """

    # Setup
    i3c_controller, i3c_target, tb = await test_setup(dut, verify_boot=True)

    target = i3c_controller.add_target(TARGET_ADDRESS)
    target.set_bcr_fields(ibi_req_capable=True, ibi_payload=True)

    result = True

    # Limit IBI data count that the controller can accept
    i3c_controller.set_max_ibi_data_len(6)

    # Write descriptor to the TTI IBI queue
    mdb = 0xAA
    data = [0xCA, 0xFE, 0xBA, 0xCA, 0xAA, 0xBB, 0xCC, 0xDD]
    ibi_data = format_ibi_data(mdb, data)
    dut._log.info(" ".join([f"0x{d:08X}" for d in ibi_data]))
    for word in ibi_data:
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, int2dword(word), 4)

    # Wait for the IBI to be serviced, check data
    response = await i3c_controller.wait_for_ibi()
    expected = bytearray([TARGET_ADDRESS, mdb] + data[:6])
    if response != expected:
        dut._log.critical(
            "IBI MDB/data mismatch! tgt: [ {}] ctl: [ {}]".format(
                "".join("".join(f"0x{d:02X}") + " " for d in expected),
                "".join("".join(f"0x{d:02X}") + " " for d in response),
            )
        )
        result = False

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
    if response != expected:
        dut._log.critical(
            "IBI MDB/data mismatch! tgt: [ {}] ctl: [ {}]".format(
                "".join("".join(f"0x{d:02X}") + " " for d in expected),
                "".join("".join(f"0x{d:02X}") + " " for d in response),
            )
        )
        result = False

    # Report the test result
    assert result


@cocotb_test()
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
    assert test_data == recv_data

    # Issue a private read
    recv_data = await i3c_controller.i3c_read(TARGET_ADDRESS, 16)
    recv_data = list(recv_data.data)

    assert tx_test_data == recv_data


@cocotb_test()
async def test_i3c_target_pwrite_err_detection(dut):
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
        TRANSFER_LENGTH = random.randint(1, 256)

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

        desc_len = data & 0xFFFF
        assert desc_len < TRANSFER_LENGTH

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
