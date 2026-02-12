# SPDX-License-Identifier: Apache-2.0

"""
Tests for HDR mode entry, exit, and error recovery.

Covers:
  - HDR-DDR write/read with HDR exit pattern (I3C spec 5.2.1.1.1)
  - HDR-DDR with repeated start (RSTART) and exit
  - Optional 60us HDR error recovery timer (I3C spec 1.10.1.9)
"""

import logging
import random

from boot import boot_init
from i3c_controller_fixed import I3cControllerFixed as I3cController
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import ClockCycles, Timer

# =============================================================================
# Constants
# =============================================================================

VALID_I3C_ADDRESSES = (
    [i for i in range(0x03, 0x3E)]
    + [i for i in range(0x3F, 0x5E)]
    + [i for i in range(0x5F, 0x6E)]
    + [i for i in range(0x6F, 0x76)]
    + [i for i in range(0x77, 0x7A)]
    + [0x7B, 0x7D]
)

# CCC codes
ENTHDR0 = 0x20
GETSTATUS = 0x90

# DUT FSM state values (from i3c_target_fsm.sv primary_state_e)
FSM_STATE_IDLE = 0
FSM_STATE_IN_HDR_MODE = 18

# DUT hierarchy path to FSM state register
FSM_STATE_PATH = (
    "xi3c_wrapper.i3c.xcontroller.xcontroller_standby"
    ".xcontroller_standby_i3c.xi3c_target_fsm.state_d"
)

# HDR timeout test threshold (small value so tests run fast)
TEST_HDR_TIMEOUT_CYCLES = 200


# =============================================================================
# Helpers: Test setup
# =============================================================================

async def test_setup(dut, static_addr=0x5A, virtual_static_addr=0x5B,
                     dynamic_addr=None, virtual_dynamic_addr=None,
                     hdr_timeout_en=False, hdr_timeout_cycles=None):
    """Sets up controller, target models and top-level core interface."""

    cocotb.log.setLevel(logging.DEBUG)

    i3c_controller = I3cController(
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_ctrl_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_ctrl_i,
        debug_state_o=None,
        speed=12.5e6,
    )

    i3c_target = I3CTarget(  # noqa
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_target_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_target_i,
        debug_state_o=None,
        speed=12.5e6,
    )

    tb = I3CTopTestInterface(dut)
    await tb.setup()
    await ClockCycles(tb.clk, 50)
    await boot_init(tb, static_addr=static_addr,
                    virtual_static_addr=virtual_static_addr,
                    dynamic_addr=dynamic_addr,
                    virtual_dynamic_addr=virtual_dynamic_addr,
                    hdr_timeout_en=hdr_timeout_en,
                    hdr_timeout_cycles=hdr_timeout_cycles)
    return i3c_controller, i3c_target, tb


def get_remaining_addrs(*exclude):
    """Return VALID_I3C_ADDRESSES with the given addresses removed."""
    addrs = VALID_I3C_ADDRESSES.copy()
    for a in exclude:
        addrs.remove(a)
    return addrs


# =============================================================================
# Helpers: FSM state
# =============================================================================

def get_fsm_state(dut):
    """Read the current FSM state_d value."""
    return int(getattr(dut, FSM_STATE_PATH).value)


def assert_fsm_idle(dut):
    assert get_fsm_state(dut) == FSM_STATE_IDLE, \
        f"Expected Idle ({FSM_STATE_IDLE}), got {get_fsm_state(dut)}"


def assert_fsm_in_hdr_mode(dut):
    assert get_fsm_state(dut) == FSM_STATE_IN_HDR_MODE, \
        f"Expected InHDRMode ({FSM_STATE_IN_HDR_MODE}), got {get_fsm_state(dut)}"


# =============================================================================
# Helpers: Bus operations and verification
# =============================================================================

async def verify_target_responsive(i3c_controller, dynamic_addr):
    """Verify the target is responsive by sending GETSTATUS CCC.

    Checks that the target ACKs the direct CCC (i.e., is not deaf).
    The status value itself may vary depending on prior error conditions.
    """
    status_data = await i3c_controller.i3c_ccc_read(
        ccc=GETSTATUS, addr=dynamic_addr, count=2, stop=True
    )
    ack = status_data[0][0]
    cocotb.log.info(f"GETSTATUS response from {hex(dynamic_addr)}: ack={ack}, "
                    f"data={status_data[0][1].hex()}")
    assert ack, f"Target at {hex(dynamic_addr)} NACKed GETSTATUS — not responsive"


async def hold_bus_high(i3c_controller, i3c_target, tb, cycles):
    """Hold both SCL and SDA high for specified number of clock cycles.

    Releases both the controller and target model bus drivers to ensure
    the open-drain bus actually goes high.
    """
    i3c_controller.scl = 1
    i3c_controller.sda = 1
    i3c_target.sda_o.value = 1
    i3c_target.scl_o.value = 1
    await ClockCycles(tb.clk, cycles)


# =============================================================================
# Helpers: TE0/TE1 error injection (delegates to I3cControllerFixed)
# =============================================================================

async def trigger_te0_error(i3c_controller):
    """Trigger a TE0 error. See I3cControllerFixed.send_te0_error()."""
    await i3c_controller.send_te0_error()


async def trigger_te1_error(i3c_controller, i3c_target):
    """Trigger a TE1 error, pausing the cocotb target model first.

    The cocotb I3CTarget model also monitors the bus and will crash on a
    parity error assertion.  We pause it before injecting the error and
    release the bus lines so the model doesn't hold SDA low.
    """
    # Pause the cocotb target model so it doesn't crash on the bad parity
    i3c_target.monitor_enable.clear()
    await i3c_target.monitor_idle.wait()
    i3c_target.sda_o.value = 1
    i3c_target.scl_o.value = 1

    await i3c_controller.send_te1_error()


# =============================================================================
# Tests: HDR-DDR entry and exit via HDR Exit Pattern
# =============================================================================

@cocotb.test()
async def test_enter_exit_hdr_mode_write(dut):
    """Single HDR-DDR write with exit pattern."""
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)

    remaining_addrs = get_remaining_addrs(
        STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)

    for _ in range(random.randint(10, 15)):
        await i3c_controller.i3c_ccc_write(
            ENTHDR0, broadcast_data=[], stop=False, pull_scl_low=True)
        await ClockCycles(tb.clk, 10)
        assert_fsm_in_hdr_mode(dut)

        test_addr = random.choice(remaining_addrs)
        data_len = random.randint(1, 8)
        test_data = [random.randint(0, 0xFFFF) for _ in range(data_len)]
        accept_data = random.randint(0, 1)
        i3c_target.address = test_addr if accept_data == 1 else 0

        cocotb.log.info(f"Sending HDR-DDR write to {hex(test_addr)} with data: {test_data}")
        test_data = await i3c_controller.send_hdr_ddr_write(
            addr=test_addr, data=test_data)
        assert (
            (test_data.nack == True and accept_data == 0) or
            (test_data.nack == False and accept_data == 1)
        )

        await i3c_controller.send_hdr_exit()
        i3c_target.address = 0
        assert_fsm_idle(dut)
        await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)


@cocotb.test()
async def test_enter_restart_exit_hdr_mode_write(dut):
    """Multiple HDR-DDR writes with RSTART, final exit pattern."""
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)

    remaining_addrs = get_remaining_addrs(
        STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)

    for _ in range(random.randint(10, 15)):
        await i3c_controller.i3c_ccc_write(
            ENTHDR0, broadcast_data=[], stop=False, pull_scl_low=True)
        await ClockCycles(tb.clk, 10)
        assert_fsm_in_hdr_mode(dut)

        transactions = random.randint(10, 15)
        for i in range(transactions):
            test_addr = random.choice(remaining_addrs)
            data_len = random.randint(1, 8)
            test_data = [random.randint(0, 0xFFFF) for _ in range(data_len)]
            accept_data = random.randint(0, 1)
            i3c_target.address = test_addr if accept_data == 1 else 0

            cocotb.log.info(f"Sending HDR-DDR write to {hex(test_addr)} with data: {test_data}")
            test_data = await i3c_controller.send_hdr_ddr_write(
                addr=test_addr, data=test_data)
            assert (
                (test_data.nack == True and accept_data == 0) or
                (test_data.nack == False and accept_data == 1)
            )

            if i != transactions - 1:
                await i3c_controller.send_hdr_rstart()
            else:
                await i3c_controller.send_hdr_exit()
            i3c_target.address = 0

        assert_fsm_idle(dut)
        await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)


@cocotb.test()
async def test_enter_exit_hdr_mode_read(dut):
    """Single HDR-DDR read with exit pattern."""
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)

    remaining_addrs = get_remaining_addrs(
        STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)

    for _ in range(random.randint(10, 15)):
        await i3c_controller.i3c_ccc_write(
            ENTHDR0, broadcast_data=[], stop=False, pull_scl_low=True)
        await ClockCycles(tb.clk, 10)
        assert_fsm_in_hdr_mode(dut)

        test_addr = random.choice(remaining_addrs)
        data_len = random.randint(1, 8)
        exp_data = [random.randint(0, 0xFFFF) for _ in range(data_len)]
        accept_data = random.randint(0, 1)
        i3c_target.address = test_addr if accept_data == 1 else 0
        i3c_target._mem.clear()
        i3c_target._mem.write(
            [byte for word in exp_data for byte in word.to_bytes(2, "big")],
            2 * data_len
        )

        cocotb.log.info(f"Sending HDR-DDR read to {hex(test_addr)} with length: {data_len}")
        test_data = await i3c_controller.send_hdr_ddr_read(addr=test_addr)
        assert (
            (test_data.nack == True and accept_data == 0) or
            (test_data.nack == False and accept_data == 1)
        )

        await i3c_controller.send_hdr_exit()
        i3c_target.address = 0
        assert_fsm_idle(dut)
        await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)


@cocotb.test()
async def test_enter_restart_exit_hdr_mode_read(dut):
    """Multiple HDR-DDR reads with RSTART, final exit pattern."""
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)

    remaining_addrs = get_remaining_addrs(
        STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)

    for _ in range(random.randint(10, 15)):
        await i3c_controller.i3c_ccc_write(
            ENTHDR0, broadcast_data=[], stop=False, pull_scl_low=True)
        await ClockCycles(tb.clk, 10)
        assert_fsm_in_hdr_mode(dut)

        transactions = random.randint(10, 15)
        for i in range(transactions):
            test_addr = random.choice(remaining_addrs)
            data_len = random.randint(1, 8)
            exp_data = [random.randint(0, 0xFFFF) for _ in range(data_len)]
            accept_data = random.randint(0, 1)
            i3c_target.address = test_addr if accept_data == 1 else 0
            i3c_target._mem.clear()
            i3c_target._mem.write(
                [byte for word in exp_data for byte in word.to_bytes(2, "big")],
                2 * data_len
            )

            cocotb.log.info(f"Sending HDR-DDR read to {hex(test_addr)} with length: {data_len}")
            test_data = await i3c_controller.send_hdr_ddr_read(addr=test_addr)
            assert (
                (test_data.nack == True and accept_data == 0) or
                (test_data.nack == False and accept_data == 1)
            )

            if i != transactions - 1:
                await i3c_controller.send_hdr_rstart()
            else:
                await i3c_controller.send_hdr_exit()
            i3c_target.address = 0

        assert_fsm_idle(dut)
        await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)


# =============================================================================
# Tests: HDR error recovery timer (I3C spec 1.10.1.9)
# =============================================================================

@cocotb.test()
async def test_hdr_timeout_recovery_te0(dut):
    """60us timeout recovery after TE0 error (invalid reserved address)."""
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR,
        hdr_timeout_en=True, hdr_timeout_cycles=TEST_HDR_TIMEOUT_CYCLES)

    await trigger_te0_error(i3c_controller)
    await ClockCycles(tb.clk, 10)
    assert_fsm_in_hdr_mode(dut)

    await hold_bus_high(i3c_controller, i3c_target, tb, TEST_HDR_TIMEOUT_CYCLES + 50)
    assert_fsm_idle(dut)

    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)


@cocotb.test()
async def test_hdr_timeout_recovery_te1(dut):
    """60us timeout recovery after TE1 error (CCC parity error)."""
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR,
        hdr_timeout_en=True, hdr_timeout_cycles=TEST_HDR_TIMEOUT_CYCLES)

    await trigger_te1_error(i3c_controller, i3c_target)
    await ClockCycles(tb.clk, 10)
    assert_fsm_in_hdr_mode(dut)

    await hold_bus_high(i3c_controller, i3c_target, tb, TEST_HDR_TIMEOUT_CYCLES + 50)
    assert_fsm_idle(dut)

    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()

    # Re-enable the cocotb target model after recovery
    i3c_target.monitor_enable.set()
    await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)


@cocotb.test()
async def test_hdr_timeout_does_not_fire_for_ccc_hdr(dut):
    """Timer does NOT fire during normal HDR mode entered via ENTHDR CCC."""
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR,
        hdr_timeout_en=True, hdr_timeout_cycles=TEST_HDR_TIMEOUT_CYCLES)

    await i3c_controller.i3c_ccc_write(
        ENTHDR0, broadcast_data=[], stop=False, pull_scl_low=True)
    await ClockCycles(tb.clk, 10)
    assert_fsm_in_hdr_mode(dut)

    # Hold bus high well past threshold — timer must NOT fire for CCC-entered HDR
    await hold_bus_high(i3c_controller, i3c_target, tb, TEST_HDR_TIMEOUT_CYCLES * 3)
    assert_fsm_in_hdr_mode(dut)

    await i3c_controller.send_hdr_exit()
    assert_fsm_idle(dut)
    await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)


@cocotb.test()
async def test_hdr_timeout_resets_on_line_low(dut):
    """Timer resets when either SCL or SDA goes low."""
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR,
        hdr_timeout_en=True, hdr_timeout_cycles=TEST_HDR_TIMEOUT_CYCLES)

    await trigger_te0_error(i3c_controller)
    await ClockCycles(tb.clk, 10)
    assert_fsm_in_hdr_mode(dut)

    # Hold for 80% of threshold (not enough)
    partial_wait = int(TEST_HDR_TIMEOUT_CYCLES * 0.8)
    await hold_bus_high(i3c_controller, i3c_target, tb, partial_wait)
    assert_fsm_in_hdr_mode(dut)

    # Briefly pull SCL low to reset the timer
    i3c_controller.scl = 0
    await ClockCycles(tb.clk, 5)
    i3c_controller.scl = 1
    await ClockCycles(tb.clk, 5)

    # Another 80% — cumulative would exceed threshold, but timer was reset
    await hold_bus_high(i3c_controller, i3c_target, tb, partial_wait)
    assert_fsm_in_hdr_mode(dut)

    # Full threshold from the reset point
    await hold_bus_high(i3c_controller, i3c_target, tb, TEST_HDR_TIMEOUT_CYCLES + 50)
    assert_fsm_idle(dut)

    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)


@cocotb.test()
async def test_hdr_timeout_disabled_by_default(dut):
    """Timer does not fire when enable bit is 0 (default)."""
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR,
        hdr_timeout_cycles=TEST_HDR_TIMEOUT_CYCLES)

    await trigger_te0_error(i3c_controller)
    await ClockCycles(tb.clk, 10)
    assert_fsm_in_hdr_mode(dut)

    await hold_bus_high(i3c_controller, i3c_target, tb, TEST_HDR_TIMEOUT_CYCLES * 3)
    assert_fsm_in_hdr_mode(dut)

    await i3c_controller.send_hdr_exit()
    assert_fsm_idle(dut)
    await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)


@cocotb.test()
async def test_hdr_timeout_configurable_threshold(dut):
    """Timer fires at configured threshold, not hardcoded 60us."""
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    SHORT_THRESHOLD = 100
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR,
        hdr_timeout_en=True, hdr_timeout_cycles=SHORT_THRESHOLD)

    await trigger_te0_error(i3c_controller)
    await ClockCycles(tb.clk, 10)
    assert_fsm_in_hdr_mode(dut)

    await hold_bus_high(i3c_controller, i3c_target, tb, SHORT_THRESHOLD + 50)
    assert_fsm_idle(dut)

    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)


@cocotb.test()
async def test_hdr_exit_pattern_works_alongside_timer(dut):
    """Normal HDR Exit Pattern still works when timer is enabled."""
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = random.sample(VALID_I3C_ADDRESSES, 4)
    LARGE_THRESHOLD = 100000
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR,
        hdr_timeout_en=True, hdr_timeout_cycles=LARGE_THRESHOLD)

    await trigger_te0_error(i3c_controller)
    await ClockCycles(tb.clk, 10)
    assert_fsm_in_hdr_mode(dut)

    # Exit via pattern well before timer would fire
    await i3c_controller.send_hdr_exit()
    assert_fsm_idle(dut)
    await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)
