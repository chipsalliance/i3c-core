# SPDX-License-Identifier: Apache-2.0

import logging
import cocotb
from cocotb.triggers import ClockCycles

from boot import boot_init
from bus2csr import int2dword
from ccc import CCC
from i3c_controller_fixed import I3cControllerFixed as I3cController
from i3c_recovery_interface_fixed import I3cRecoveryInterfaceFixed as I3cRecoveryInterface
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface
from common import timeout_task, log_seed

STATIC_ADDR = 0x5A
VIRT_STATIC_ADDR = 0x5B
DYNAMIC_ADDR = 0x52
VIRT_DYNAMIC_ADDR = 0x53


async def initialize(dut, fclk=333.0, fbus=12.5, timeout=5000):
    """
    Common test initialization routine
    """
    cocotb.log.setLevel(logging.DEBUG)
    log_seed(dut)

    # Start the background timeout task
    await cocotb.start(timeout_task(timeout))

    # Initialize interfaces
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
        address=0x23,
    )

    dut.peripheral_reset_done_i.value = 0

    tb = I3CTopTestInterface(dut)
    await tb.setup(fclk)

    recovery = I3cRecoveryInterface(i3c_controller)

    timings = {
        "T_R": 0,
        "T_F": 0,
        "T_HD_DAT": 0,
        "T_SU_DAT": 0,
    }

    for k, v in timings.items():
        dut._log.info(f"{k} = {v}")

    # Configure the top level
    await boot_init(tb, timings, fclk=fclk,
                    static_addr=STATIC_ADDR, virtual_static_addr=VIRT_STATIC_ADDR,
                    dynamic_addr=DYNAMIC_ADDR, virtual_dynamic_addr=VIRT_DYNAMIC_ADDR)

    # Enable the recovery mode
    status = 0x3
    await tb.write_csr(
        tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, int2dword(status), 4
    )

    return i3c_controller, i3c_target, tb, recovery


@cocotb.test()
async def test_recovery_coverage_only(dut):
    """
    Standalone test specifically targeting missed toggle coverage in recovery_handler.sv.
    Covers:
    - TTI queue ready thresholds (CSR-driven toggles and Depth-1 clamp checks)
    - RX descriptor queue depth[6:4] and full signals
    """
    i3c_controller, i3c_target, tb, recovery = await initialize(dut, timeout=5000)
    rh = dut.xi3c_wrapper.i3c.xrecovery_handler
    q_thld_ctrl = tb.reg_map.I3C_EC.TTI.QUEUE_THLD_CTRL
    q_status = tb.reg_map.I3C_EC.TTI.QUEUE_STATUS
    desc_depth_csr = tb.reg_map.I3C_EC.TTI.DESC_QUEUE_DEPTH

    dut._log.info("Disabling recovery mode to unlock TTI CSRs...")
    await tb.write_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, int2dword(0x02), 4)
    await ClockCycles(tb.clk, 10)

    # 1. Toggle Queue Thresholds via CSR writes and verify Depth-1 (0x3F) clamping.
    # In src/hci/queues.sv, rx_desc_fifo and tx_desc_fifo are instantiated with
    # LimitReadyThld=1, ThldIsPow=0, Depth=64, clamping ready_thld_o <= 63 (0x3F)
    # and writing the clamped value back to QUEUE_THLD_CTRL.{RX,TX}_DESC_THLD.
    # ibi_queue has LimitReadyThld=0, so IBI_THLD retains all 8 bits (0xFF).
    dut._log.info("Toggling QUEUE_THLD_CTRL bits and verifying CSR-driven clamping...")
    # Start with 0 to ensure bit [0] (which defaults to 1) transitions 1->0
    await tb.write_csr(q_thld_ctrl.base_addr, int2dword(0x00000000), 4)
    await ClockCycles(tb.clk, 10)
    assert await tb.read_csr_field(q_thld_ctrl.base_addr, q_thld_ctrl.TX_DESC_THLD) == 0x00
    assert await tb.read_csr_field(q_thld_ctrl.base_addr, q_thld_ctrl.RX_DESC_THLD) == 0x00
    assert await tb.read_csr_field(q_thld_ctrl.base_addr, q_thld_ctrl.IBI_THLD) == 0x00
    assert int(rh.ctl_tti_tx_desc_queue_ready_thld_o.value) == 0x00
    assert int(rh.ctl_tti_rx_desc_queue_ready_thld_o.value) == 0x00
    assert int(rh.ctl_tti_ibi_queue_ready_thld_o.value) == 0x00

    # Write all 1s: input bits [7:0] toggle 0->1 while descriptor outputs clamp to 0x3F (63)
    await tb.write_csr(q_thld_ctrl.base_addr, int2dword(0xFFFFFFFF), 4)
    await ClockCycles(tb.clk, 10)
    assert await tb.read_csr_field(q_thld_ctrl.base_addr, q_thld_ctrl.TX_DESC_THLD) == 0x3F
    assert await tb.read_csr_field(q_thld_ctrl.base_addr, q_thld_ctrl.RX_DESC_THLD) == 0x3F
    assert await tb.read_csr_field(q_thld_ctrl.base_addr, q_thld_ctrl.IBI_THLD) == 0xFF
    assert int(rh.ctl_tti_tx_desc_queue_ready_thld_o.value) == 0x3F
    assert int(rh.csr_tti_tx_desc_queue_ready_thld_o.value) == 0x3F
    assert int(rh.ctl_tti_rx_desc_queue_ready_thld_o.value) == 0x3F
    assert int(rh.csr_tti_rx_desc_queue_ready_thld_o.value) == 0x3F
    assert int(rh.ctl_tti_ibi_queue_ready_thld_o.value) == 0xFF

    # Write all 0s to trigger 1->0 transitions on reachable bits
    await tb.write_csr(q_thld_ctrl.base_addr, int2dword(0x00000000), 4)
    await ClockCycles(tb.clk, 10)
    assert await tb.read_csr_field(q_thld_ctrl.base_addr, q_thld_ctrl.TX_DESC_THLD) == 0x00
    assert await tb.read_csr_field(q_thld_ctrl.base_addr, q_thld_ctrl.RX_DESC_THLD) == 0x00
    assert await tb.read_csr_field(q_thld_ctrl.base_addr, q_thld_ctrl.IBI_THLD) == 0x00
    assert int(rh.ctl_tti_tx_desc_queue_ready_thld_o.value) == 0x00
    assert int(rh.ctl_tti_rx_desc_queue_ready_thld_o.value) == 0x00
    assert int(rh.ctl_tti_ibi_queue_ready_thld_o.value) == 0x00

    # Re-enable recovery mode and verify threshold clamp behavior in recovery mode
    await tb.write_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, int2dword(0x03), 4)
    await ClockCycles(tb.clk, 10)
    await tb.write_csr(q_thld_ctrl.base_addr, int2dword(0xFFFFFFFF), 4)
    await ClockCycles(tb.clk, 10)
    assert await tb.read_csr_field(q_thld_ctrl.base_addr, q_thld_ctrl.TX_DESC_THLD) == 0x3F
    assert await tb.read_csr_field(q_thld_ctrl.base_addr, q_thld_ctrl.RX_DESC_THLD) == 0x3F
    assert int(rh.ctl_tti_tx_desc_queue_ready_thld_o.value) == 0x3F
    assert int(rh.ctl_tti_rx_desc_queue_ready_thld_o.value) == 0x3F
    await tb.write_csr(q_thld_ctrl.base_addr, int2dword(0x00000000), 4)
    await ClockCycles(tb.clk, 10)
    assert await tb.read_csr_field(q_thld_ctrl.base_addr, q_thld_ctrl.TX_DESC_THLD) == 0x00
    assert await tb.read_csr_field(q_thld_ctrl.base_addr, q_thld_ctrl.RX_DESC_THLD) == 0x00

    # 2. Fill RX Descriptor Queue to cover depth[6:4] and full_o
    dut._log.info("Setting Dynamic Address to send Private Writes...")
    await i3c_controller.i3c_ccc_write(ccc=CCC.DIRECT.SETDASA, directed_data=[(STATIC_ADDR, [DYNAMIC_ADDR << 1])])

    dut._log.info("Disabling recovery mode to route traffic to TTI...")
    await tb.write_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, int2dword(0x02), 4)
    await ClockCycles(tb.clk, 10)

    dut._log.info("Sending 65 private writes to fill RX Desc queue...")
    # RX desc queue depth is 64. Verify the first 64 writes are accepted and fill the queue.
    for i in range(65):
        resp = await i3c_controller.i3c_write(DYNAMIC_ADDR, [0xAA])
        if i < 64:
            assert not resp.nack, f"Expected private write {i} to be ACKed, got NACK"
        await ClockCycles(tb.clk, 2)
    await ClockCycles(tb.clk, 50)

    rx_desc_depth = await tb.read_csr_field(
        desc_depth_csr.base_addr, desc_depth_csr.RX_DESC_QUEUE_DEPTH
    )
    rx_desc_full = await tb.read_csr_field(
        q_status.base_addr, q_status.RX_DESC_QUEUE_FULL
    )
    assert rx_desc_depth == 64, f"Expected RX_DESC_QUEUE_DEPTH == 64, got {rx_desc_depth}"
    assert rx_desc_full == 1, f"Expected RX_DESC_QUEUE_FULL == 1, got {rx_desc_full}"
    assert int(rh.ctl_tti_rx_desc_queue_depth_o.value) == 64
    assert int(rh.ctl_tti_rx_desc_queue_full_o.value) == 1

    # Reset queues to clean up
    dut._log.info("Resetting RX data and desc queues")
    await tb.write_csr_field(tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr, tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DESC_RST, 1)
    await tb.write_csr_field(tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr, tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 1)
    await ClockCycles(tb.clk, 10)
    await tb.write_csr_field(tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr, tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DESC_RST, 0)
    await tb.write_csr_field(tb.reg_map.I3C_EC.TTI.RESET_CONTROL.base_addr, tb.reg_map.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST, 0)
    await ClockCycles(tb.clk, 20)

    rx_desc_depth_after = await tb.read_csr_field(
        desc_depth_csr.base_addr, desc_depth_csr.RX_DESC_QUEUE_DEPTH
    )
    rx_desc_full_after = await tb.read_csr_field(
        q_status.base_addr, q_status.RX_DESC_QUEUE_FULL
    )
    assert rx_desc_depth_after == 0, f"Expected RX_DESC_QUEUE_DEPTH == 0 after reset, got {rx_desc_depth_after}"
    assert rx_desc_full_after == 0, f"Expected RX_DESC_QUEUE_FULL == 0 after reset, got {rx_desc_full_after}"

    # Re-enable recovery mode to leave in clean state
    await tb.write_csr(tb.reg_map.I3C_EC.SECFWRECOVERYIF.DEVICE_STATUS_0.base_addr, int2dword(0x03), 4)
    await ClockCycles(tb.clk, 10)

    await tb.teardown()
