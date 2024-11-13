# SPDX-License-Identifier: Apache-2.0

from bus_monitor import BusMonitor

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge

CLOCK_PERIOD_NS = 2
SCL_CLK_RATIO = 40


async def reset(dut):
    await FallingEdge(dut.clk_i)
    dut.rst_ni.value = 0
    await ClockCycles(dut.clk_i, 10)
    await FallingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)


async def setup_test(dut):
    """
    Spawn system clock, reset the module and
    Happy path testing, arbitrarily selected:
        - 5 -> 10ns for the data hold time (spec has no constraint)
        - 2 -> 4ns for the rise/fall time (spec lowest is 12ns)
    """
    cocotb.log.setLevel("INFO")

    clock = Clock(dut.clk_i, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())
    scl_clock = Clock(dut.scl_i, CLOCK_PERIOD_NS * SCL_CLK_RATIO, units="ns")
    cocotb.start_soon(scl_clock.start())
    bus_monitor = BusMonitor(dut)
    bus_monitor.start()

    dut.rst_ni.value = 0
    dut.target_enable_i.value = 0
    # Test specific ports
    dut.scl_i.value = 1
    dut.sda_i.value = 1
    dut.t_r_i.value = 2
    dut.t_f_i.value = 2
    dut.t_hd_dat_i.value = 5
    # Bus Monitor
    dut.bus_start_det_i.value = 0
    dut.bus_stop_det_i.value = 0
    dut.bus_timeout_i.value = 0
    dut.hdr_exit_detect_i.value = 0
    dut.scl_negedge_i.value = 0
    dut.scl_posedge_i.value = 0
    dut.sda_negedge_i.value = 0
    dut.sda_posedge_i.value = 0
    # Bus TX Flow
    dut.bus_tx_req_err_i.value = 0
    dut.bus_tx_done_i.value = 0
    dut.bus_tx_idle_i.value = 0
    # Bus RX Flow
    dut.bus_rx_done_i.value = 0
    dut.bus_rx_idle_i.value = 0
    dut.bus_rx_data_i.value = 0
    dut.bus_rx_error_i.value = 0
    # TTI TX Queue
    dut.tx_fifo_rvalid_i.value = 0
    dut.tx_fifo_rdata_i.value = 0
    # TTI RX Queue
    dut.rx_fifo_wready_i.value = 0
    # TTI IBI Queue
    dut.ibi_fifo_rvalid_i.value = 0
    dut.ibi_fifo_rdata_i.value = 0
    # Address matching
    dut.target_sta_address_i.value = 0
    dut.target_sta_address_valid_i.value = 0
    dut.target_dyn_address_i.value = 0
    dut.target_dyn_address_valid_i.value = 0
    dut.target_ibi_address_i.value = 0
    dut.target_ibi_address_valid_i.value = 0
    dut.target_reset_detect_i.value = 0
    # SubFSMs
    dut.is_ibi_done_i.value = 0
    dut.is_ccc_done_i.value = 0
    dut.is_hotjoin_done_i.value = 0

    await ClockCycles(dut.clk_i, 10)
    await reset(dut)
    await ClockCycles(dut.clk_i, 10)

    assert dut.target_idle_o.value == 1
    assert dut.target_transmitting_o.value == 0
    assert dut.bus_tx_req_byte_o.value == 0
    assert dut.bus_tx_req_bit_o.value == 0
    assert dut.bus_tx_req_value_o.value == 1  # Pullup by default
    assert dut.bus_rx_req_bit_o.value == 0
    assert dut.bus_rx_req_byte_o.value == 0
    assert dut.tx_fifo_rready_o.value == 0
    assert dut.tx_host_nack_o.value == 0
    assert dut.rx_fifo_wvalid_o.value == 0
    assert dut.rx_fifo_wdata_o.value == 0
    assert dut.rx_last_byte_o.value == 0
    assert dut.ibi_fifo_rready_o.value == 0
    assert dut.event_target_nack_o.value == 0
    assert dut.event_cmd_complete_o.value == 0
    assert dut.event_unexp_stop_o.value == 0
    assert dut.event_tx_arbitration_lost_o.value == 0
    assert dut.event_tx_bus_timeout_o.value == 0
    assert dut.event_read_cmd_received_o.value == 0
    assert dut.rst_action_o.value == 0
    assert dut.is_in_hdr_mode_o.value == 0
    assert dut.parity_err_o.value == 0


@cocotb.test()
async def test_i3c_target_fsm(dut: SimHandleBase):
    cocotb.log.setLevel("INFO")

    await setup_test(dut)
