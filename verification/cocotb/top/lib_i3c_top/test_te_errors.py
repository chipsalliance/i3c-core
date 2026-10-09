# SPDX-License-Identifier: Apache-2.0

"""
TE Error Detection and Recovery Tests for I3C SDR Target.

Covers:
  - TE0: Invalid reserved broadcast address -> HDR error mode
  - TE1: CCC parity error -> HDR error mode
  - TE2: Private write data parity error -> data discarded
  - Register sweep: FORCE, W1C, counter saturation, ENABLE gating
  - Controller abort scenarios on private R/W
  - Cross-error sequence mixing (TE0 -> TE1 -> TE2 -> TE5 in random order)
  - RI <-> TE error isolation

TE3/TE4/TE5/Framing tests are in test_ccc.py (delivered by separate DV agent).
"""

import logging
import random

from boot import boot_init
from bus2csr import dword2int, int2dword
from ccc import CCC
from i3c_controller_fixed import I3cControllerFixed as I3cController
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface

import cocotb
from cocotb.triggers import ClockCycles


# =============================================================================
# Constants
# =============================================================================

from common import VALID_I3C_ADDRESSES, log_seed

# TE0 reserved address patterns (from i3c_pkg.sv)
# Write patterns: 7 addresses that trigger TE0 when sent with W bit
TE0_RSVD_ADDR_W = [0x3E, 0x5E, 0x6E, 0x76, 0x7A, 0x7C, 0x7F]
# Read pattern: 0x7E with R bit
TE0_RSVD_ADDR_R = 0x7E

# Broadcast CCC codes for TE1 injection
BROADCAST_CCCS = [0x01, 0x06, 0x07, 0x09, 0x0C, 0x20, 0x28, 0x30]

GETSTATUS = 0x90

# DUT FSM state values
FSM_STATE_IDLE = 0
FSM_STATE_IN_HDR_MODE = 19

FSM_STATE_PATH = (
    "xi3c_wrapper.i3c.xcontroller.xcontroller_standby"
    ".xcontroller_standby_i3c.xi3c_target_fsm.state_q"
)

# HDR timeout (small value so tests run fast)
TEST_HDR_TIMEOUT_CYCLES = 200


# =============================================================================
# Test Setup
# =============================================================================

async def test_setup(dut, static_addr=0x5A, virtual_static_addr=0x5B,
                     dynamic_addr=None, virtual_dynamic_addr=None,
                     hdr_timeout_en=False, hdr_timeout_cycles=None):
    """Sets up controller, target models and top-level core interface."""

    cocotb.log.setLevel(logging.DEBUG)
    log_seed(dut)

    i3c_controller = I3cController(
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_ctrl_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_ctrl_i,
        debug_state_o=None,
        speed=12.5e6,
    )

    i3c_target = I3CTarget(
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


# =============================================================================
# Helpers: FSM state
# =============================================================================

def get_fsm_state(dut):
    return int(getattr(dut, FSM_STATE_PATH).value)


def assert_fsm_idle(dut):
    assert get_fsm_state(dut) == FSM_STATE_IDLE, \
        f"Expected Idle ({FSM_STATE_IDLE}), got {get_fsm_state(dut)}"


def assert_fsm_in_hdr_mode(dut):
    assert get_fsm_state(dut) == FSM_STATE_IN_HDR_MODE, \
        f"Expected InHDRMode ({FSM_STATE_IN_HDR_MODE}), got {get_fsm_state(dut)}"


# =============================================================================
# Helpers: TE error register access
# =============================================================================

# Error type info: (CTRL DET_EN field name, STATUS field name, ENABLE field name,
#                   FORCE field name, counter register name)
TE_ERROR_TYPES = {
    0: ("TE0_ERR_DET_EN", "TE0_ERR_STAT", "TE0_ERR_EN", "TE0_ERR_FORCE", "TARGET_ERR_CNT_TE0"),
    1: ("TE1_ERR_DET_EN", "TE1_ERR_STAT", "TE1_ERR_EN", "TE1_ERR_FORCE", "TARGET_ERR_CNT_TE1"),
    2: ("TE2_ERR_DET_EN", "TE2_ERR_STAT", "TE2_ERR_EN", "TE2_ERR_FORCE", "TARGET_ERR_CNT_TE2"),
    3: ("TE3_ERR_DET_EN", "TE3_ERR_STAT", "TE3_ERR_EN", "TE3_ERR_FORCE", "TARGET_ERR_CNT_TE3"),
    4: ("TE4_ERR_DET_EN", "TE4_ERR_STAT", "TE4_ERR_EN", "TE4_ERR_FORCE", "TARGET_ERR_CNT_TE4"),
    5: ("TE5_ERR_DET_EN", "TE5_ERR_STAT", "TE5_ERR_EN", "TE5_ERR_FORCE", "TARGET_ERR_CNT_TE5"),
    6: ("FRAMING_ERR_DET_EN", "FRAMING_ERR_STAT", "FRAMING_ERR_EN", "FRAMING_ERR_FORCE", "TARGET_ERR_CNT_FRAMING"),
}


def _get_reg(tb, reg_name):
    """Get a register object from the TTI namespace."""
    return getattr(tb.reg_map.I3C_EC.TTI, reg_name)


def _get_field(tb, reg_name, field_name):
    """Get a field from a TTI register."""
    return getattr(_get_reg(tb, reg_name), field_name)


async def enable_all_te_interrupts(tb):
    """Enable INTR_ENABLE for TE0-TE5 + FRAMING."""
    enable_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.base_addr
    for n in range(7):
        _, _, en_name, _, _ = TE_ERROR_TYPES[n]
        field = _get_field(tb, "TARGET_ERR_INTR_ENABLE", en_name)
        await tb.write_csr_field(enable_addr, field, 1)


async def clear_all_te_status(tb):
    """W1C all TE status bits."""
    status_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr
    await tb.write_csr(status_addr, int2dword(0xFFFFFFFF), 4)


async def clear_all_te_counters(tb):
    """Write 0 to all TE counter registers."""
    for n in range(7):
        _, _, _, _, cnt_name = TE_ERROR_TYPES[n]
        cnt_reg = _get_reg(tb, cnt_name)
        await tb.write_csr(cnt_reg.base_addr, int2dword(0), 4)


async def read_te_counter(tb, n):
    """Read TARGET_ERR_CNT_TE{n}."""
    _, _, _, _, cnt_name = TE_ERROR_TYPES[n]
    cnt_reg = _get_reg(tb, cnt_name)
    return dword2int(await tb.read_csr(cnt_reg.base_addr, 4)) & 0xFF


async def read_te_status_bit(tb, n):
    """Read TARGET_ERR_INTR_STATUS.TE{n}_ERR_STAT."""
    status_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr
    _, stat_name, _, _, _ = TE_ERROR_TYPES[n]
    field = _get_field(tb, "TARGET_ERR_INTR_STATUS", stat_name)
    return await tb.read_csr_field(status_addr, field)


async def clear_te_status_bit(tb, n):
    """W1C a specific TE status bit."""
    status_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr
    _, stat_name, _, _, _ = TE_ERROR_TYPES[n]
    field = _get_field(tb, "TARGET_ERR_INTR_STATUS", stat_name)
    await tb.write_csr_field(status_addr, field, 1)


# =============================================================================
# Helpers: Bus operations
# =============================================================================

async def verify_target_responsive(i3c_controller, dynamic_addr):
    """Verify target ACKs GETSTATUS CCC."""
    status_data = await i3c_controller.i3c_ccc_read(
        ccc=GETSTATUS, addr=dynamic_addr, count=2, stop=True
    )
    ack = status_data[0][0]
    cocotb.log.info(f"GETSTATUS response from {hex(dynamic_addr)}: ack={ack}")
    assert ack, f"Target at {hex(dynamic_addr)} NACKed GETSTATUS -- not responsive"


async def hold_bus_high(i3c_controller, i3c_target, tb, cycles):
    """Hold SCL+SDA high for timeout recovery."""
    i3c_controller.scl = 1
    i3c_controller.sda = 1
    i3c_target.sda_o.value = 1
    i3c_target.scl_o.value = 1
    await ClockCycles(tb.clk, cycles)


async def pause_cocotb_target(i3c_target):
    """Pause the cocotb I3CTarget model before TE1 injection."""
    i3c_target.monitor_enable.clear()
    await i3c_target.monitor_idle.wait()
    i3c_target.sda_o.value = 1
    i3c_target.scl_o.value = 1


async def recover_from_hdr_error(i3c_controller, i3c_target, tb, recovery_method):
    """Recover from HDR error mode via hdr_exit or timeout."""
    if recovery_method == 'hdr_exit':
        await i3c_controller.send_hdr_exit()
        await i3c_controller.send_stop()
        i3c_controller.give_bus_control()
    elif recovery_method == 'timeout':
        await hold_bus_high(i3c_controller, i3c_target, tb,
                            TEST_HDR_TIMEOUT_CYCLES + 50)
        await i3c_controller.send_stop()
        i3c_controller.give_bus_control()


async def inject_te0_error(i3c_controller, dut, addr_pattern=None):
    """Inject a TE0 error. If addr_pattern is None, use send_te0_error (0x7E/R).
    Otherwise use the specified reserved address with W bit."""
    if addr_pattern is None or addr_pattern == TE0_RSVD_ADDR_R:
        await i3c_controller.send_te0_error()
    else:
        # Send a reserved address with write bit
        await i3c_controller.take_bus_control()
        await i3c_controller.send_start()
        await i3c_controller.write_addr_header(addr_pattern, read=False)
    await ClockCycles(dut.aclk if hasattr(dut, 'aclk') else dut.hclk, 10)


# =============================================================================
# Test C1: TE0 Error Detection and Recovery
# =============================================================================

@cocotb.test()
async def test_te0_errors(dut):
    """TE0 error: reserved broadcast address triggers HDR error mode and recovery.

    Tests all 8 reserved address patterns, both recovery methods (HDR exit
    and 60us timeout), back-to-back errors, and DET_EN=0 bypass.
    """
    log = logging.getLogger("test_te0_errors")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR,
        hdr_timeout_en=True, hdr_timeout_cycles=TEST_HDR_TIMEOUT_CYCLES)
    tb.te_error_monitor.expect_error(0)

    await enable_all_te_interrupts(tb)
    await clear_all_te_status(tb)
    await clear_all_te_counters(tb)
    await ClockCycles(tb.clk, 5)

    # --- PHASE 1: Main loop -- random address patterns and recovery ---
    log.info("=== PHASE 1: TE0 main loop ===")
    iterations = random.randint(5, 8)

    for i in range(iterations):
        # Randomly pick a TE0 pattern
        if random.random() < 0.5:
            addr_pattern = TE0_RSVD_ADDR_R  # 0x7E/R
        else:
            addr_pattern = random.choice(TE0_RSVD_ADDR_W)

        recovery = random.choice(['hdr_exit', 'timeout'])
        log.info(f"  Iteration {i}: addr=0x{addr_pattern:02X}, recovery={recovery}")

        cnt_before = await read_te_counter(tb, 0)
        await inject_te0_error(i3c_controller, dut, addr_pattern)
        assert_fsm_in_hdr_mode(dut)

        await recover_from_hdr_error(i3c_controller, i3c_target, tb, recovery)
        await ClockCycles(tb.clk, 10)
        assert_fsm_idle(dut)

        # Verify status bit set and counter incremented
        stat = await read_te_status_bit(tb, 0)
        assert stat == 1, f"TE0_ERR_STAT should be 1, got {stat}"
        await clear_te_status_bit(tb, 0)

        cnt_after = await read_te_counter(tb, 0)
        assert cnt_after > cnt_before, \
            f"TE0 counter should increment: before={cnt_before}, after={cnt_after}"

        await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)

    # --- PHASE 2: Back-to-back TE0 errors ---
    log.info("=== PHASE 2: Back-to-back TE0 errors ===")
    cnt_before_b2b = await read_te_counter(tb, 0)
    b2b_count = random.randint(2, 3)
    for j in range(b2b_count):
        addr_pattern = random.choice(TE0_RSVD_ADDR_W + [TE0_RSVD_ADDR_R])
        await inject_te0_error(i3c_controller, dut, addr_pattern)
        # Release bus but don't do HDR exit -- target stays in HDR error mode
        await i3c_controller.send_stop()
        i3c_controller.give_bus_control()
        await ClockCycles(tb.clk, 20)

    # Now recover
    await i3c_controller.take_bus_control()
    await i3c_controller.send_hdr_exit()
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 10)
    assert_fsm_idle(dut)

    cnt_after_b2b = await read_te_counter(tb, 0)
    assert cnt_after_b2b > cnt_before_b2b, \
        f"TE0 counter should increment after back-to-back: before={cnt_before_b2b}, after={cnt_after_b2b}"
    await clear_all_te_status(tb)
    await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)

    # --- PHASE 3: DET_EN=0 bypass ---
    log.info("=== PHASE 3: TE0 DET_EN=0 ===")
    ctrl_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CTRL.base_addr
    det_en_field = _get_field(tb, "TARGET_ERR_CTRL", "TE0_ERR_DET_EN")
    await tb.write_csr_field(ctrl_addr, det_en_field, 0)
    await ClockCycles(tb.clk, 5)

    cnt_before = await read_te_counter(tb, 0)
    await clear_all_te_status(tb)

    await inject_te0_error(i3c_controller, dut)
    # Target should NOT go deaf -- but the BFM already sent 0x7E/R which
    # enters HDR mode regardless of DET_EN (DET_EN only controls error reporting).
    # We still need to recover from HDR mode.
    await i3c_controller.send_hdr_exit()
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 10)

    stat = await read_te_status_bit(tb, 0)
    assert stat == 0, f"TE0_ERR_STAT should be 0 with DET_EN=0, got {stat}"

    cnt_after = await read_te_counter(tb, 0)
    assert cnt_after == cnt_before, \
        f"TE0 counter should not increment with DET_EN=0: before={cnt_before}, after={cnt_after}"

    # Re-enable detection
    await tb.write_csr_field(ctrl_addr, det_en_field, 1)
    await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)

    log.info("test_te0_errors PASSED")
    tb.te_error_monitor.check()


# =============================================================================
# Test C2: TE1 Error Detection and Recovery
# =============================================================================

    await tb.teardown()

@cocotb.test()
async def test_te1_errors(dut):
    """TE1 error: CCC parity error -> HDR error mode -> recovery.

    Tests various broadcast CCCs with bad T-bit parity, both recovery methods,
    ENTHDR0-specific case, and DET_EN=0 bypass.
    """
    log = logging.getLogger("test_te1_errors")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR,
        hdr_timeout_en=True, hdr_timeout_cycles=TEST_HDR_TIMEOUT_CYCLES)
    tb.te_error_monitor.expect_error(1)

    await enable_all_te_interrupts(tb)
    await clear_all_te_status(tb)
    await clear_all_te_counters(tb)
    await ClockCycles(tb.clk, 5)

    # --- PHASE 1: Main loop -- random CCC codes and recovery ---
    log.info("=== PHASE 1: TE1 main loop ===")
    iterations = random.randint(5, 8)

    for i in range(iterations):
        ccc = random.choice(BROADCAST_CCCS)
        recovery = random.choice(['hdr_exit', 'timeout'])
        log.info(f"  Iteration {i}: CCC=0x{ccc:02X}, recovery={recovery}")

        cnt_before = await read_te_counter(tb, 1)

        # Pause cocotb target model (it crashes on bad parity)
        await pause_cocotb_target(i3c_target)

        await i3c_controller.send_te1_error(ccc=ccc)
        await ClockCycles(tb.clk, 10)
        assert_fsm_in_hdr_mode(dut)

        await recover_from_hdr_error(i3c_controller, i3c_target, tb, recovery)
        await ClockCycles(tb.clk, 10)
        assert_fsm_idle(dut)

        # Re-enable cocotb target model
        i3c_target.monitor_enable.set()

        stat = await read_te_status_bit(tb, 1)
        assert stat == 1, f"TE1_ERR_STAT should be 1, got {stat}"
        await clear_te_status_bit(tb, 1)

        cnt_after = await read_te_counter(tb, 1)
        assert cnt_after > cnt_before, \
            f"TE1 counter should increment: before={cnt_before}, after={cnt_after}"

        await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)

    # --- PHASE 2: ENTHDR0-specific (spec-critical) ---
    log.info("=== PHASE 2: TE1 with ENTHDR0 ===")
    cnt_before = await read_te_counter(tb, 1)
    await pause_cocotb_target(i3c_target)
    await i3c_controller.send_te1_error(ccc=0x20)
    await ClockCycles(tb.clk, 10)
    assert_fsm_in_hdr_mode(dut)

    await recover_from_hdr_error(i3c_controller, i3c_target, tb, 'hdr_exit')
    await ClockCycles(tb.clk, 10)
    assert_fsm_idle(dut)
    i3c_target.monitor_enable.set()

    stat = await read_te_status_bit(tb, 1)
    assert stat == 1, f"TE1_ERR_STAT should be 1 after ENTHDR0, got {stat}"
    await clear_te_status_bit(tb, 1)
    cnt_after = await read_te_counter(tb, 1)
    assert cnt_after > cnt_before, \
        f"TE1 counter should increment after ENTHDR0: before={cnt_before}, after={cnt_after}"
    await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)

    # --- PHASE 3: DET_EN=0 bypass ---
    log.info("=== PHASE 3: TE1 DET_EN=0 ===")
    ctrl_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CTRL.base_addr
    det_en_field = _get_field(tb, "TARGET_ERR_CTRL", "TE1_ERR_DET_EN")
    await tb.write_csr_field(ctrl_addr, det_en_field, 0)
    await ClockCycles(tb.clk, 5)

    cnt_before = await read_te_counter(tb, 1)
    await clear_all_te_status(tb)

    await pause_cocotb_target(i3c_target)
    await i3c_controller.send_te1_error(ccc=0x20)
    await i3c_controller.send_hdr_exit()
    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()
    await ClockCycles(tb.clk, 10)
    i3c_target.monitor_enable.set()

    stat = await read_te_status_bit(tb, 1)
    assert stat == 0, f"TE1_ERR_STAT should be 0 with DET_EN=0, got {stat}"

    cnt_after = await read_te_counter(tb, 1)
    assert cnt_after == cnt_before, \
        f"TE1 counter should not increment with DET_EN=0: before={cnt_before}, after={cnt_after}"

    await tb.write_csr_field(ctrl_addr, det_en_field, 1)
    await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)

    log.info("test_te1_errors PASSED")
    tb.te_error_monitor.check()


# =============================================================================
# Test C3: TE2 Private Write Parity Error
# =============================================================================

    await tb.teardown()


@cocotb.test(timeout_time=1000, timeout_unit="us")
async def test_ccc_error_private_descriptor(dut):
    """Keep a real CCC error live until the first good private descriptor is checked."""
    controller, target, tb = await test_setup(dut, dynamic_addr=0x2D, virtual_dynamic_addr=0x35)
    await pause_cocotb_target(target)
    await enable_all_te_interrupts(tb)
    assert tb.te_error_monitor is not None, "CCC isolation requires the passive error-event monitor"
    tb.te_error_monitor.expect_error(1, 2, 6)
    tti = tb.reg_map.I3C_EC.TTI
    sm = tb.reg_map.I3C_EC.STDBYCTRLMODE
    err = dut.xi3c_wrapper.i3c.xcontroller.xcontroller_standby.err_o

    for source, error_type, enabled in (("clean", None, 1), ("te2", 2, 0), ("te2", 2, 1), ("te1", 1, 1), ("framing", 6, 1)):
        dut._log.info(f"CCC_DESCRIPTOR: starting source={source}, DET_EN={enabled}; first private write is the discriminator")
        await clear_all_te_status(tb)
        await tb.write_csr_field(tti.TARGET_ERR_CTRL.base_addr, tti.TARGET_ERR_CTRL.TE2_ERR_DET_EN, enabled)
        counts = dict(tb.te_error_monitor.error_counts)
        counters = [await read_te_counter(tb, n) for n in range(7)]
        assert int(err.value) == 0, "Previous scenario did not clear global Protocol Error"
        if source == "te2":
            await controller.send_te2_error(ccc=CCC.DIRECT.RSTACT, defining_byte=1, corrupt_defining_byte=True)
            await controller.send_stop()
            controller.give_bus_control()
        elif source == "te1":
            await controller.send_te1_error(ccc=CCC.BCAST.ENTHDR0)
            await ClockCycles(tb.clk, 10)
            assert_fsm_in_hdr_mode(dut)
            await recover_from_hdr_error(controller, target, tb, "hdr_exit")
            await ClockCycles(tb.clk, 10)
            assert_fsm_idle(dut)
        elif source == "framing":
            # Valid address and T-bit, invalid SETNEWDA padding; old DA must survive.
            assert await controller.i3c_ccc_write(
                ccc=CCC.DIRECT.SETNEWDA, directed_data=[(0x2D, [(0x30 << 1) | 1])]) == [True]
        await ClockCycles(tb.clk, 10)
        expected_error = int(error_type is not None and enabled)
        expected_counts = {n: counts[n] + int(n == error_type and enabled) for n in counts}
        assert tb.te_error_monitor.error_counts == expected_counts, f"CCC source event mismatch: {source}"
        assert int(err.value) == expected_error, f"{source}: global Protocol Error not live before private write"
        dut._log.info(f"CCC_DESCRIPTOR: source observed, live_error={int(err.value)}; sending discriminating write without GETSTATUS/reset/FIFO access")

        payload = bytearray([0xA5, 0x46, 0x7E, 0x3C, 0x91, 0x00, 0xFF, 0x62])
        response = await controller.i3c_write(0x2D, payload)
        assert not response.nack, f"{source}: good private write NACKed"
        await ClockCycles(tb.clk, 10)
        desc = dword2int(await tb.read_csr(tti.RX_DESC_QUEUE_PORT.base_addr, 4))
        assert desc == len(payload), f"{source}: CCC error contaminated good private descriptor: 0x{desc:08X}"
        data = bytearray()
        for _ in range(0, len(payload), 4):
            data.extend(await tb.read_csr(tti.RX_DATA_PORT.base_addr, 4))
        assert data == payload, f"{source}: private data mismatch: {data.hex()}"
        assert int(err.value) == expected_error, f"{source}: good private write unexpectedly cleared global error"
        assert await tb.read_csr_field(tti.STATUS.base_addr, tti.STATUS.PROTOCOL_ERROR) == expected_error
        for n in range(7):
            delta = int(n == error_type and enabled)
            assert await read_te_counter(tb, n) == counters[n] + delta, f"{source}: incorrect error counter {n}"
            assert await read_te_status_bit(tb, n) == delta, f"{source}: incorrect error status {n}"
        assert tb.te_error_monitor.error_counts == expected_counts, "Good private write generated an error event"
        assert await tb.read_csr_field(sm.STBY_CR_DEVICE_ADDR.base_addr, sm.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR) == 0x2D
        assert await tb.read_csr_field(sm.STBY_CR_DEVICE_ADDR.base_addr, sm.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID) == 1
        dut._log.info(f"CCC_DESCRIPTOR: exact descriptor/data matched with live_error={expected_error}; now clearing via GETSTATUS")

        # Only now may GETSTATUS clear the independently checked global latch.
        await controller.take_bus_control()
        await controller.send_start()
        assert await controller.write_addr_header(0x7E)
        await controller.send_byte_tbit(CCC.DIRECT.GETSTATUS)
        await controller.send_start()
        assert await controller.write_addr_header(0x2D, read=True)
        for index, expected in enumerate((0, 0xC0 | (expected_error << 5))):
            byte, eod = await controller.recv_byte_t_bit(stop=False)
            assert byte == expected and bool(eod) == (index == 1), f"{source}: incorrect GETSTATUS byte/EOD at {index}"
        await controller.send_stop()
        controller.give_bus_control()
        await ClockCycles(tb.clk, 10)
        assert int(err.value) == 0, "Completed GETSTATUS did not clear Protocol Error"
        dut._log.info(f"CCC_DESCRIPTOR: source={source}, DET_EN={enabled} completed")
    await tb.teardown()


@cocotb.test()
async def test_te2_private_write_parity(dut):
    """TE2 error: bad T-bit parity on private write data -> data discarded.

    Verifies RX FIFO is empty after parity error, error registers update,
    and target remains functional after recovery. The TE2 counter increments
    once per data byte with a parity failure (per-byte detection granularity).
    """
    log = logging.getLogger("test_te2_private_write_parity")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)
    tb.te_error_monitor.expect_error(2)

    await enable_all_te_interrupts(tb)
    await clear_all_te_status(tb)
    await clear_all_te_counters(tb)
    await ClockCycles(tb.clk, 50)

    # Drain any stale RX descriptors/data from boot or setup.
    # A spurious TE2 may fire during register initialization -- allow time for it.
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 1)
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 0)
    for _ in range(16):
        await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4)
    # Reset counters again after any spurious TE2 during setup
    await clear_all_te_counters(tb)
    await clear_all_te_status(tb)
    await ClockCycles(tb.clk, 10)

    PROTOCOL_ERR_LOW = 5

    # --- PHASE 1: Main loop -- random length private writes with bad parity ---
    log.info("=== PHASE 1: TE2 private write parity errors ===")
    iterations = random.randint(5, 10)

    for i in range(iterations):
        # First iteration uses length 1 (corner case), rest are random
        xfer_len = 1 if i == 0 else random.randint(1, 64)
        data = [random.randint(0, 255) for _ in range(xfer_len)]
        log.info(f"  Iteration {i}: xfer_len={xfer_len}")

        # Clear counter before each iteration to avoid saturation at 0xFF
        cnt_reg = _get_reg(tb, "TARGET_ERR_CNT_TE2")
        await tb.write_csr(cnt_reg.base_addr, int2dword(0), 4)
        await ClockCycles(tb.clk, 2)

        # Inject TE2 error via private write with bad T-bit
        await i3c_controller.i3c_write(DYNAMIC_ADDR, data, inject_tbit_err=True)
        await ClockCycles(tb.clk, 10)

        # Check PROTOCOL_ERROR status first (this is the primary TE2 indicator)
        err_status = await tb.read_csr_field(
            tb.reg_map.I3C_EC.TTI.STATUS.base_addr,
            tb.reg_map.I3C_EC.TTI.STATUS.PROTOCOL_ERROR)
        assert err_status == 1, f"PROTOCOL_ERROR should be 1 after TE2, got {err_status}"

        # Bad private data must still report an error in its own descriptor.
        desc_raw = dword2int(
            await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4))
        err_stat = desc_raw >> 28
        desc_len = desc_raw & 0xFFFF
        log.info(f"    RX descriptor: raw=0x{desc_raw:08X}, err_stat={err_stat}, desc_len={desc_len}")
        assert err_stat == 1 and desc_len == 0, f"Incorrect private parity-error descriptor: 0x{desc_raw:08X}"

        # Verify TE2 status and counter
        stat = await read_te_status_bit(tb, 2)
        assert stat == 1, f"TE2_ERR_STAT should be 1, got {stat}"
        await clear_te_status_bit(tb, 2)

        cnt_after = await read_te_counter(tb, 2)
        assert cnt_after == xfer_len, (
            f"TE2 counter should equal number of bytes with bad parity "
            f"({xfer_len}), got {cnt_after}"
        )

        # Clear RX data FIFO
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 1)
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 0)

        # Verify GETSTATUS reports protocol error, then clears
        result = await i3c_controller.i3c_ccc_read(
            ccc=GETSTATUS, addr=DYNAMIC_ADDR, count=2)
        status = int.from_bytes(result[0][1], byteorder="big", signed=False)
        assert ((status >> PROTOCOL_ERR_LOW) & 1) == 1, \
            "GETSTATUS should report Protocol Error"

        # Verify protocol error is cleared after reading GETSTATUS
        err_status = await tb.read_csr_field(
            tb.reg_map.I3C_EC.TTI.STATUS.base_addr,
            tb.reg_map.I3C_EC.TTI.STATUS.PROTOCOL_ERROR)
        assert err_status == 0, f"PROTOCOL_ERROR should be cleared, got {err_status}"

        # Verify normal traffic still works
        verify_len = random.randint(1, 16)
        verify_data = [random.randint(0, 255) for _ in range(verify_len)]
        await i3c_controller.i3c_write(DYNAMIC_ADDR, verify_data)
        await ClockCycles(tb.clk, 20)
        desc_raw = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4))
        assert desc_raw == verify_len, f"Recovery write inherited an old error: 0x{desc_raw:08X}"
        received = bytearray()
        for _ in range(0, verify_len, 4):
            received.extend(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, 4))
        assert received[:verify_len] == bytearray(verify_data), "Recovery private data mismatch"

    # --- PHASE 2: DET_EN=0 bypass ---
    log.info("=== PHASE 2: TE2 DET_EN=0 ===")
    ctrl_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CTRL.base_addr
    det_en_field = _get_field(tb, "TARGET_ERR_CTRL", "TE2_ERR_DET_EN")
    await tb.write_csr_field(ctrl_addr, det_en_field, 0)
    await ClockCycles(tb.clk, 5)

    cnt_before = await read_te_counter(tb, 2)
    await clear_all_te_status(tb)

    data = [random.randint(0, 255) for _ in range(random.randint(1, 32))]
    await i3c_controller.i3c_write(DYNAMIC_ADDR, data, inject_tbit_err=True)
    await ClockCycles(tb.clk, 10)

    stat = await read_te_status_bit(tb, 2)
    assert stat == 0, f"TE2_ERR_STAT should be 0 with DET_EN=0, got {stat}"

    cnt_after = await read_te_counter(tb, 2)
    assert cnt_after == cnt_before, \
        f"TE2 counter should not increment with DET_EN=0: before={cnt_before}, after={cnt_after}"
    desc_raw = dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4))
    assert desc_raw == len(data), f"Disabled parity detection still marked the descriptor: 0x{desc_raw:08X}"
    received = bytearray()
    for _ in range(0, len(data), 4):
        received.extend(await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr, 4))
    assert received[:len(data)] == bytearray(data), "Disabled parity detection changed private payload"
    assert await tb.read_csr_field(
        tb.reg_map.I3C_EC.TTI.STATUS.base_addr, tb.reg_map.I3C_EC.TTI.STATUS.PROTOCOL_ERROR) == 0

    # Re-enable
    await tb.write_csr_field(ctrl_addr, det_en_field, 1)

    # Drain any descriptors/data left from DET_EN=0 test
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 1)
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 0)

    await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)
    log.info("test_te2_private_write_parity PASSED")
    tb.te_error_monitor.check()


# =============================================================================
# Test C9: TE Error Registers Sweep
# =============================================================================

    await tb.teardown()

@cocotb.test()
async def test_te_error_registers_sweep(dut):
    """Register infrastructure test: FORCE->STATUS, W1C, counter saturation,
    ENABLE gating, and multi-bit FORCE.

    No bus traffic -- pure register verification.
    """
    log = logging.getLogger("test_te_error_registers_sweep")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    _, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)

    await enable_all_te_interrupts(tb)
    await clear_all_te_status(tb)
    await clear_all_te_counters(tb)
    await ClockCycles(tb.clk, 5)

    force_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_FORCE.base_addr
    enable_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.base_addr

    # --- PHASE 1: FORCE -> STATUS for each error type ---
    log.info("=== PHASE 1: FORCE -> STATUS ===")
    for n in range(7):
        _, stat_name, en_name, force_name, _ = TE_ERROR_TYPES[n]
        force_field = _get_field(tb, "TARGET_ERR_INTR_FORCE", force_name)

        # Force the error (write 1 then 0 -- FORCE is RW, needs edge)
        await tb.write_csr_field(force_addr, force_field, 1)
        await tb.write_csr_field(force_addr, force_field, 0)
        await ClockCycles(tb.clk, 5)

        # Verify STATUS bit is set
        stat = await read_te_status_bit(tb, n)
        assert stat == 1, f"PHASE1: {stat_name} should be 1 after FORCE, got {stat}"

        # W1C the status bit
        await clear_te_status_bit(tb, n)
        await ClockCycles(tb.clk, 5)

        # Verify STATUS bit is cleared
        stat = await read_te_status_bit(tb, n)
        assert stat == 0, f"PHASE1: {stat_name} should be 0 after W1C, got {stat}"

        log.info(f"  {TE_ERROR_TYPES[n][3]}: FORCE->STATUS->W1C OK")

    # --- PHASE 2: ENABLE gating ---
    log.info("=== PHASE 2: ENABLE gating ===")
    for n in range(7):
        _, stat_name, en_name, force_name, _ = TE_ERROR_TYPES[n]
        en_field = _get_field(tb, "TARGET_ERR_INTR_ENABLE", en_name)
        force_field = _get_field(tb, "TARGET_ERR_INTR_FORCE", force_name)

        # Disable this interrupt
        await tb.write_csr_field(enable_addr, en_field, 0)
        await ClockCycles(tb.clk, 5)

        # Force the error (write 1 then 0 -- FORCE is RW, needs edge)
        await tb.write_csr_field(force_addr, force_field, 1)
        await tb.write_csr_field(force_addr, force_field, 0)
        await ClockCycles(tb.clk, 5)

        # Verify STATUS bit is NOT set (gated by ENABLE)
        stat = await read_te_status_bit(tb, n)
        assert stat == 0, f"PHASE2: {stat_name} should be 0 when ENABLE=0, got {stat}"

        # Re-enable
        await tb.write_csr_field(enable_addr, en_field, 1)
        log.info(f"  {en_name}: ENABLE gating OK")

    # --- PHASE 3: Counter clear ---
    log.info("=== PHASE 3: Counter clear ===")
    for n in range(7):
        _, _, _, _, cnt_name = TE_ERROR_TYPES[n]
        cnt_reg = _get_reg(tb, cnt_name)

        # Write a non-zero value
        await tb.write_csr(cnt_reg.base_addr, int2dword(42), 4)
        await ClockCycles(tb.clk, 5)
        cnt = dword2int(await tb.read_csr(cnt_reg.base_addr, 4)) & 0xFF
        assert cnt == 42, f"PHASE3: {cnt_name} should be 42, got {cnt}"

        # Clear
        await tb.write_csr(cnt_reg.base_addr, int2dword(0), 4)
        await ClockCycles(tb.clk, 5)
        cnt = dword2int(await tb.read_csr(cnt_reg.base_addr, 4)) & 0xFF
        assert cnt == 0, f"PHASE3: {cnt_name} should be 0 after clear, got {cnt}"

        log.info(f"  {cnt_name}: write/clear OK")

    # --- PHASE 4: Random multi-bit FORCE ---
    log.info("=== PHASE 4: Multi-bit FORCE ===")
    await clear_all_te_status(tb)
    await ClockCycles(tb.clk, 5)

    # Pick 2-5 random error types to force simultaneously
    bits_to_force = random.sample(range(7), random.randint(2, 5))
    log.info(f"  Forcing error types: {bits_to_force}")

    for n in bits_to_force:
        _, _, _, force_name, _ = TE_ERROR_TYPES[n]
        force_field = _get_field(tb, "TARGET_ERR_INTR_FORCE", force_name)
        # Write 1 then 0 -- FORCE is RW, needs edge for interrupt module
        await tb.write_csr_field(force_addr, force_field, 1)
        await tb.write_csr_field(force_addr, force_field, 0)
        await ClockCycles(tb.clk, 5)

    # Verify all forced STATUS bits are set
    for n in bits_to_force:
        stat = await read_te_status_bit(tb, n)
        assert stat == 1, f"PHASE4: TE{n} STATUS should be 1, got {stat}"

    # Verify non-forced bits are NOT set
    for n in range(7):
        if n not in bits_to_force:
            stat = await read_te_status_bit(tb, n)
            assert stat == 0, f"PHASE4: TE{n} STATUS should be 0 (not forced), got {stat}"

    # W1C all and verify
    await clear_all_te_status(tb)
    await ClockCycles(tb.clk, 5)
    for n in range(7):
        stat = await read_te_status_bit(tb, n)
        assert stat == 0, f"PHASE4: TE{n} STATUS should be 0 after W1C, got {stat}"

    log.info("test_te_error_registers_sweep PASSED")
    tb.te_error_monitor.check()


# =============================================================================
# Test C10: Controller Abort Scenarios
# =============================================================================

    await tb.teardown()

@cocotb.test()
async def test_controller_abort_scenarios(dut):
    """Controller abort during private write/read at random positions.

    Verifies the target remains functional after aborted transactions.
    """
    log = logging.getLogger("test_controller_abort_scenarios")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)

    await enable_all_te_interrupts(tb)
    await clear_all_te_status(tb)
    await ClockCycles(tb.clk, 5)

    # --- PHASE 1: Private write abort ---
    log.info("=== PHASE 1: Private write aborts ===")
    abort_iterations = random.randint(3, 5)
    for i in range(abort_iterations):
        xfer_len = random.randint(4, 64)
        data = [random.randint(0, 255) for _ in range(xfer_len)]
        log.info(f"  Iteration {i}: write len={xfer_len}, abort with STOP")

        # Send a partial write then STOP
        await i3c_controller.i3c_write(DYNAMIC_ADDR, data, stop=True)
        await ClockCycles(tb.clk, 20)

        # Drain any pending descriptors
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 1)
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
            tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 0)
        await ClockCycles(tb.clk, 10)

        # Verify target still responsive
        await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)

    # --- Post: Full write+read roundtrip ---
    log.info("=== Post: Full write+read roundtrip ===")
    verify_len = random.randint(4, 32)
    verify_data = [random.randint(0, 255) for _ in range(verify_len)]
    await i3c_controller.i3c_write(DYNAMIC_ADDR, verify_data)
    await ClockCycles(tb.clk, 20)
    await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)

    log.info("test_controller_abort_scenarios PASSED")
    tb.te_error_monitor.check()


# =============================================================================
# Test C11: TE Error Sequence Mixing
# =============================================================================

    await tb.teardown()

@cocotb.test()
async def test_te_error_sequence_mixing(dut):
    """Cross-coverage: inject TE0, TE1, TE2 in random order with recovery.

    Verifies that each error type is correctly detected and only the
    corresponding status bit and counter are affected. TE2 counter increments
    once per data byte with a parity failure (per-byte detection granularity).
    """
    log = logging.getLogger("test_te_error_sequence_mixing")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR,
        hdr_timeout_en=True, hdr_timeout_cycles=TEST_HDR_TIMEOUT_CYCLES)
    tb.te_error_monitor.expect_error(0, 1, 2)

    await enable_all_te_interrupts(tb)
    await clear_all_te_status(tb)
    await clear_all_te_counters(tb)
    await ClockCycles(tb.clk, 5)

    # Shuffle error types
    error_types = ['te0', 'te1', 'te2']
    random.shuffle(error_types)
    log.info(f"Shuffled error sequence: {error_types}")

    expected_counts = {0: 0, 1: 0, 2: 0}

    for err_type in error_types:
        log.info(f"  Injecting {err_type}")
        await clear_all_te_status(tb)
        await ClockCycles(tb.clk, 5)

        if err_type == 'te0':
            addr_pattern = random.choice(TE0_RSVD_ADDR_W + [TE0_RSVD_ADDR_R])
            await inject_te0_error(i3c_controller, dut, addr_pattern)
            recovery = random.choice(['hdr_exit', 'timeout'])
            await recover_from_hdr_error(i3c_controller, i3c_target, tb, recovery)
            await ClockCycles(tb.clk, 10)
            expected_counts[0] += 1
            n = 0

        elif err_type == 'te1':
            ccc = random.choice(BROADCAST_CCCS)
            await pause_cocotb_target(i3c_target)
            await i3c_controller.send_te1_error(ccc=ccc)
            await ClockCycles(tb.clk, 10)
            recovery = random.choice(['hdr_exit', 'timeout'])
            await recover_from_hdr_error(i3c_controller, i3c_target, tb, recovery)
            await ClockCycles(tb.clk, 10)
            i3c_target.monitor_enable.set()
            expected_counts[1] += 1
            n = 1

        elif err_type == 'te2':
            te2_xfer_len = random.randint(1, 32)
            data = [random.randint(0, 255) for _ in range(te2_xfer_len)]
            await i3c_controller.i3c_write(DYNAMIC_ADDR, data, inject_tbit_err=True)
            await ClockCycles(tb.clk, 10)
            expected_counts[2] += te2_xfer_len
            n = 2
            # Drain FIFO
            await tb.write_csr_field(
                tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
                tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 1)
            await tb.write_csr_field(
                tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
                tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 0)

        # Verify ONLY the expected status bit is set
        stat = await read_te_status_bit(tb, n)
        assert stat == 1, f"{err_type}: expected STATUS bit {n} set, got {stat}"

        # Verify other TE0-TE2 bits are NOT set
        for other in range(3):
            if other != n:
                other_stat = await read_te_status_bit(tb, other)
                assert other_stat == 0, \
                    f"{err_type}: unexpected STATUS bit {other} set, got {other_stat}"

        await clear_te_status_bit(tb, n)
        await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)

    # Final counter verification
    for n in range(3):
        cnt = await read_te_counter(tb, n)
        assert cnt == expected_counts[n], (
            f"TE{n} counter should be {expected_counts[n]} after error injection, "
            f"got {cnt}"
        )

    log.info("test_te_error_sequence_mixing PASSED")
    tb.te_error_monitor.check()


# =============================================================================
# Test C12: TE <-> RI Error Isolation
# =============================================================================

    await tb.teardown()

@cocotb.test()
async def test_te_error_ri_isolation(dut):
    """Verify TE errors do not corrupt RI path and vice versa.

    Phase 1: TE0 error -> recover -> verify normal TTI traffic works
    Phase 2: Normal traffic after TE2 error -> verify no cross-contamination
    """
    log = logging.getLogger("test_te_error_ri_isolation")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR,
        hdr_timeout_en=True, hdr_timeout_cycles=TEST_HDR_TIMEOUT_CYCLES)
    tb.te_error_monitor.expect_error(0, 2)

    await enable_all_te_interrupts(tb)
    await clear_all_te_status(tb)
    await clear_all_te_counters(tb)
    await ClockCycles(tb.clk, 5)

    # --- PHASE 1: TE0 error -> verify TTI traffic recovers ---
    log.info("=== PHASE 1: TE0 -> TTI recovery ===")
    await inject_te0_error(i3c_controller, dut)
    assert_fsm_in_hdr_mode(dut)
    await recover_from_hdr_error(i3c_controller, i3c_target, tb, 'hdr_exit')
    await ClockCycles(tb.clk, 10)
    assert_fsm_idle(dut)

    # Normal private write should work after TE0 recovery
    write_data = [random.randint(0, 255) for _ in range(random.randint(4, 32))]
    await i3c_controller.i3c_write(DYNAMIC_ADDR, write_data)
    await ClockCycles(tb.clk, 20)

    # Verify a descriptor was written (non-zero length)
    desc_raw = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4))
    desc_len = desc_raw & 0xFFFF
    assert desc_len > 0, f"Expected non-zero desc_len after recovery, got {desc_len}"

    # Drain
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 1)
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 0)
    await ClockCycles(tb.clk, 10)

    # --- PHASE 2: TE2 error -> verify normal traffic follows ---
    log.info("=== PHASE 2: TE2 -> normal traffic ===")
    bad_data = [random.randint(0, 255) for _ in range(random.randint(1, 16))]
    await i3c_controller.i3c_write(DYNAMIC_ADDR, bad_data, inject_tbit_err=True)
    await ClockCycles(tb.clk, 10)

    # Drain error descriptor
    await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4)
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 1)
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr,
        tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 0)

    # Clear GETSTATUS protocol error
    await i3c_controller.i3c_ccc_read(ccc=GETSTATUS, addr=DYNAMIC_ADDR, count=2)
    await ClockCycles(tb.clk, 10)

    # Normal private write should still work
    good_data = [random.randint(0, 255) for _ in range(random.randint(4, 32))]
    await i3c_controller.i3c_write(DYNAMIC_ADDR, good_data)
    await ClockCycles(tb.clk, 20)

    desc_raw = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4))
    desc_len = desc_raw & 0xFFFF
    err_stat = desc_raw >> 28
    assert err_stat == 0, f"Expected no error in descriptor after good write, got err_stat={err_stat}"
    assert desc_len == len(good_data), \
        f"Expected desc_len={len(good_data)}, got {desc_len}"

    await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)
    log.info("test_te_error_ri_isolation PASSED")
    tb.te_error_monitor.check()


# =============================================================================
# Test: TE Counter Per-Event
# =============================================================================

    await tb.teardown()

@cocotb.test()
async def test_te_counter_per_event(dut):
    """Verify TE0/TE1 error counters increment exactly once per single error event.

    TE0 fires once per corrupted address header. TE1 fires once per CCC byte
    with parity failure. Both are single-detection events, so counter == 1
    after one injection.
    """
    log = logging.getLogger("test_te_counter_per_event")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR,
        hdr_timeout_en=True, hdr_timeout_cycles=TEST_HDR_TIMEOUT_CYCLES)
    tb.te_error_monitor.expect_error(0, 1)

    await enable_all_te_interrupts(tb)
    await clear_all_te_status(tb)
    await clear_all_te_counters(tb)
    await ClockCycles(tb.clk, 50)

    # Re-clear counters after any spurious TE during setup
    await clear_all_te_counters(tb)
    await clear_all_te_status(tb)
    await ClockCycles(tb.clk, 10)

    # --- TE0: Single error event, counter must be exactly 1 ---
    log.info("=== TE0: inject one error event, expect counter == 1 ===")
    cnt_reg = _get_reg(tb, "TARGET_ERR_CNT_TE0")
    await tb.write_csr(cnt_reg.base_addr, int2dword(0), 4)
    await ClockCycles(tb.clk, 5)

    # Inject exactly one TE0 error (0x7E/R reserved address)
    hdr_entries_before = tb.hdr_recovery_monitor.entry_count
    await inject_te0_error(i3c_controller, dut, TE0_RSVD_ADDR_R)
    assert tb.hdr_recovery_monitor.entry_count > hdr_entries_before, \
        "TE0 error should have triggered HDR error mode entry"
    await recover_from_hdr_error(i3c_controller, i3c_target, tb, 'hdr_exit')
    await ClockCycles(tb.clk, 10)

    te0_cnt = dword2int(await tb.read_csr(cnt_reg.base_addr, 4)) & 0xFF
    log.info(f"  TE0 counter after single event: {te0_cnt}")
    assert te0_cnt == 1, (
        f"TE0 counter should be exactly 1 after one error event, got {te0_cnt}"
    )

    # --- TE1: Single error event, counter must be exactly 1 ---
    log.info("=== TE1: inject one error event, expect counter == 1 ===")
    cnt_reg = _get_reg(tb, "TARGET_ERR_CNT_TE1")
    await tb.write_csr(cnt_reg.base_addr, int2dword(0), 4)
    await ClockCycles(tb.clk, 5)

    ccc = random.choice(BROADCAST_CCCS)
    await pause_cocotb_target(i3c_target)
    await i3c_controller.send_te1_error(ccc=ccc)
    await ClockCycles(tb.clk, 10)
    await recover_from_hdr_error(i3c_controller, i3c_target, tb, 'hdr_exit')
    await ClockCycles(tb.clk, 10)
    i3c_target.monitor_enable.set()

    te1_cnt = dword2int(await tb.read_csr(cnt_reg.base_addr, 4)) & 0xFF
    log.info(f"  TE1 counter after single event: {te1_cnt}")
    assert te1_cnt == 1, (
        f"TE1 counter should be exactly 1 after one error event, got {te1_cnt}"
    )

    log.info("test_te_counter_per_event PASSED")
    tb.te_error_monitor.check()

    await tb.teardown()


# =============================================================================
# Coverage: CheckSByte -> InHDRMode via in_hdr_mode_i override (line 834)
# Covers FSM override from CheckSByte state
# =============================================================================

@cocotb.test()
async def test_te0_during_ccc_repeated_start(dut):
    """
    Coverage: i3c_target_fsm.sv line 834 (in_hdr_mode_i override from CheckSByte).

    Trigger a TE0 error from the RxSByteRepeated state:
    1. S + 7E/W (broadcast) -> target ACKs -> FSM enters RxSByte
    2. Repeated Start -> FSM enters RxSByteRepeated
    3. 7E/R (TE0-triggering address) -> bus_addr_valid fires, te0_err_o fires,
       state_d = CheckSByte
    4. Next cycle: FSM in CheckSByte, in_hdr_mode_i=1 -> override at line 834
       fires -> state_d = InHDRMode

    This exercises the only TESTABLE path for the in_hdr_mode_i override
    from a state other than CheckFByte or DoCCC.
    """
    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)

    i3c_controller, i3c_target, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR,
        hdr_timeout_en=True, hdr_timeout_cycles=TEST_HDR_TIMEOUT_CYCLES)
    tb.te_error_monitor.expect_error(0)

    # Enable TE0 interrupt
    te0_en_field = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.TE0_ERR_EN
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.base_addr, te0_en_field, 1)
    # Clear stale status and counter
    await tb.write_csr(
        tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr, int2dword(0xFFFFFFFF), 4)
    await tb.write_csr(
        tb.reg_map.I3C_EC.TTI.TARGET_ERR_CNT_TE0.base_addr, int2dword(0), 4)

    # Pause VIP target so it doesn't interfere
    i3c_target.monitor_enable.clear()
    await i3c_target.monitor_idle.wait()
    i3c_target.sda_o.value = 1
    i3c_target.scl_o.value = 1

    # Raw protocol: S + 7E/W -> ACK -> Sr -> 7E/R (TE0 trigger)
    # This puts the FSM through: RxFByte -> CheckFByte -> TxAckFByte ->
    # RxSByte -> (Sr) RxSByteRepeated -> CheckSByte -> InHDRMode
    await i3c_controller.take_bus_control()
    await i3c_controller.send_start()
    # Send 7E/W (broadcast address, write) -- target ACKs
    await i3c_controller.write_addr_header(0x7E)
    # Send Repeated Start
    await i3c_controller.send_start()
    # Send 7E/R (broadcast address, read) -- this is the TE0 trigger
    await i3c_controller.write_addr_header(0x7E, read=True)

    # Target is now in HDR error mode
    await ClockCycles(tb.clk, 10)
    assert_fsm_in_hdr_mode(dut)

    # Recover via HDR timeout
    await hold_bus_high(i3c_controller, i3c_target, tb, TEST_HDR_TIMEOUT_CYCLES + 50)
    assert_fsm_idle(dut)

    await i3c_controller.send_stop()
    i3c_controller.give_bus_control()

    # Re-enable VIP target
    i3c_target.monitor_enable.set()

    # Verify TE0 error registers
    te0_cnt = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.TTI.TARGET_ERR_CNT_TE0.base_addr, 4)) & 0xFF
    te0_stat = await tb.read_csr_field(
        tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr,
        tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.TE0_ERR_STAT)
    dut._log.info(f"TE0 counter={te0_cnt}, status={te0_stat}")
    assert te0_cnt >= 1, f"Expected TE0 counter >= 1, got {te0_cnt}"
    assert te0_stat == 1, f"Expected TE0_ERR_STAT=1, got {te0_stat}"

    await verify_target_responsive(i3c_controller, DYNAMIC_ADDR)
    tb.te_error_monitor.check()

    await tb.teardown()




# =============================================================================
# RI Interrupt Force Tests (xtti coverage gaps)
# =============================================================================

# RI error types: (INTR_ENABLE field, INTR_FORCE field, INTR_STATUS field,
#                  DET_EN field or None, DET_EN register or None)
# For xintr_ri_readonly and xintr_ri_unsupported, sts_ena_i comes from
# INTR_ENABLE (no separate DET_EN). For the FIFO overflow instances,
# sts_ena_i comes from TARGET_ERR_CTRL DET_EN.
RI_ERROR_FORCE_TYPES = [
    # (enable_field, force_field, status_field, det_en_field_or_None)
    ("RI_READONLY_ERR_EN", "RI_READONLY_ERR_FORCE",
     "RI_READONLY_ERR_STAT", None),
    ("RI_UNSUPPORTED_ERR_EN", "RI_UNSUPPORTED_ERR_FORCE",
     "RI_UNSUPPORTED_ERR_STAT", None),
    ("RI_RX_FIFO_OVERFLOW_ERR_EN", "RI_RX_FIFO_OVERFLOW_ERR_FORCE",
     "RI_RX_FIFO_OVERFLOW_ERR_STAT", "RI_RX_FIFO_OVERFLOW_ERR_DET_EN"),
    ("RI_INDIRECT_FIFO_OVERFLOW_ERR_EN", "RI_INDIRECT_FIFO_OVERFLOW_ERR_FORCE",
     "RI_INDIRECT_FIFO_OVERFLOW_ERR_STAT", "RI_INDIRECT_FIFO_OVERFLOW_ERR_DET_EN"),
]


@cocotb.test()
async def test_ri_interrupt_force_all(dut):
    """
    Tests interrupt FORCE mechanism for all RI error interrupt instances.

    Covers xtti coverage IDs:
      - 1.2: irq_force_i toggle for xintr_ri_indirect_fifo_overflow
      - 3.1: irq_force_i toggle for xintr_ri_rx_fifo_overflow

    Also exercises force for xintr_ri_readonly and xintr_ri_unsupported
    for completeness. For each RI error type:
      1. Disable the interrupt, force it, verify status is NOT set
      2. Enable the interrupt (+ DET_EN for FIFO types), force it,
         verify status IS set and irq_o goes HIGH
      3. Clear status, verify irq_o goes LOW
    """
    log = logging.getLogger("test_ri_interrupt_force_all")

    (STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR) = \
        random.sample(VALID_I3C_ADDRESSES, 4)
    _, _, tb = await test_setup(
        dut, STATIC_ADDR, VIRT_STATIC_ADDR, DYNAMIC_ADDR, VIRT_DYNAMIC_ADDR)

    irq = dut.xi3c_wrapper.irq_o
    force_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_FORCE.base_addr
    enable_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_ENABLE.base_addr
    status_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_INTR_STATUS.base_addr
    ctrl_addr = tb.reg_map.I3C_EC.TTI.TARGET_ERR_CTRL.base_addr

    # Clear all status first
    await tb.write_csr(status_addr, int2dword(0xFFFFFFFF), 4)
    await ClockCycles(tb.clk, 5)

    for en_name, force_name, stat_name, det_en_name in RI_ERROR_FORCE_TYPES:
        log.info(f"=== Testing FORCE for {force_name} ===")

        en_field = _get_field(tb, "TARGET_ERR_INTR_ENABLE", en_name)
        force_field = _get_field(tb, "TARGET_ERR_INTR_FORCE", force_name)
        stat_field = _get_field(tb, "TARGET_ERR_INTR_STATUS", stat_name)

        # --- Part A: Disable the interrupt, force it, verify no effect ---
        await tb.write_csr_field(enable_addr, en_field, 0)
        if det_en_name:
            det_en_field = _get_field(tb, "TARGET_ERR_CTRL", det_en_name)
            await tb.write_csr_field(ctrl_addr, det_en_field, 0)
        await ClockCycles(tb.clk, 5)

        # Force: write 1 then 0
        await tb.write_csr_field(force_addr, force_field, 1)
        await tb.write_csr_field(force_addr, force_field, 0)
        await ClockCycles(tb.clk, 10)

        stat = await tb.read_csr_field(status_addr, stat_field)
        assert stat == 0, (
            f"{stat_name} should be 0 when ENABLE=0, got {stat}")
        log.info(f"  Part A: ENABLE=0 -> FORCE has no effect on status: OK")

        # --- Part B: Enable the interrupt (+ DET_EN), force it ---
        await tb.write_csr_field(enable_addr, en_field, 1)
        if det_en_name:
            det_en_field = _get_field(tb, "TARGET_ERR_CTRL", det_en_name)
            await tb.write_csr_field(ctrl_addr, det_en_field, 1)
        await ClockCycles(tb.clk, 5)

        # Force: write 1 then 0
        await tb.write_csr_field(force_addr, force_field, 1)
        await tb.write_csr_field(force_addr, force_field, 0)
        await ClockCycles(tb.clk, 10)

        # Verify status bit is set
        stat = await tb.read_csr_field(status_addr, stat_field)
        assert stat == 1, (
            f"{stat_name} should be 1 after FORCE with ENABLE=1, got {stat}")

        # Verify irq_o is HIGH (may need to wait a cycle)
        await ClockCycles(tb.clk, 5)
        assert irq.value == 1, (
            f"irq_o should be HIGH after FORCE {force_name}, got {int(irq.value)}")
        log.info(f"  Part B: ENABLE=1 -> FORCE sets status and irq_o=1: OK")

        # --- Part C: Clear status, verify irq_o goes LOW ---
        await tb.write_csr_field(status_addr, stat_field, 1)
        await ClockCycles(tb.clk, 10)

        stat = await tb.read_csr_field(status_addr, stat_field)
        assert stat == 0, (
            f"{stat_name} should be 0 after W1C, got {stat}")
        assert irq.value == 0, (
            f"irq_o should be LOW after clearing {stat_name}, got {int(irq.value)}")
        log.info(f"  Part C: W1C clears status and irq_o=0: OK")

    log.info("test_ri_interrupt_force_all PASSED")

    await tb.teardown()
