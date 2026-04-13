// SPDX-License-Identifier: Apache-2.0

module controller_active_flow_active
  import controller_pkg::*;
  import i3c_pkg::*;
#(
    parameter int unsigned HciRespFifoDepth = 64,
    parameter int unsigned HciCmdFifoDepth  = 64,
    parameter int unsigned HciRxFifoDepth   = 64,
    parameter int unsigned HciTxFifoDepth   = 64,
    parameter int unsigned HciIbiFifoDepth  = 64,

    localparam int unsigned HciRespFifoDepthWidth = $clog2(HciRespFifoDepth + 1),
    localparam int unsigned HciCmdFifoDepthWidth  = $clog2(HciCmdFifoDepth + 1),
    localparam int unsigned HciTxFifoDepthWidth   = $clog2(HciTxFifoDepth + 1),
    localparam int unsigned HciRxFifoDepthWidth   = $clog2(HciRxFifoDepth + 1),
    localparam int unsigned HciIbiFifoDepthWidth  = $clog2(HciIbiFifoDepth + 1),

    parameter int unsigned HciRespDataWidth = 32,
    parameter int unsigned HciCmdDataWidth  = 64,
    parameter int unsigned HciRxDataWidth   = 32,
    parameter int unsigned HciTxDataWidth   = 32,
    parameter int unsigned HciIbiDataWidth  = 32,

    parameter int unsigned HciRespThldWidth = 8,
    parameter int unsigned HciCmdThldWidth  = 8,
    parameter int unsigned HciRxThldWidth   = 3,
    parameter int unsigned HciTxThldWidth   = 3,
    parameter int unsigned HciIbiThldWidth  = 8
) (
    input logic clk_i,
    input logic rst_ni,

    // FMT interface
    output logic fmt_fifo_rvalid_o,
    output logic [I2CFifoDepthWidth-1:0] fmt_fifo_depth_o,
    input logic fmt_fifo_rready_i,
    input logic fmt_fifo_rdone_i,
    output logic [7:0] fmt_byte_o,
    output logic fmt_flag_start_before_o,
    output logic fmt_flag_stop_after_o,
    output logic fmt_flag_read_bytes_o,
    output logic fmt_flag_read_continue_o,
    output logic fmt_flag_nak_ok_o,
    output logic unhandled_unexp_nak_o,
    output logic unhandled_nak_timeout_o,
    // HCI queues
    // Command FIFO
    input logic cmd_queue_full_i,
    input logic [HciCmdFifoDepthWidth-1:0] cmd_queue_depth_i,
    input logic [HciCmdThldWidth-1:0] cmd_queue_ready_thld_i,
    input logic cmd_queue_ready_thld_trig_i,
    input logic cmd_queue_empty_i,
    input logic cmd_queue_rvalid_i,
    output logic cmd_queue_rready_o,
    input logic [HciCmdDataWidth-1:0] cmd_queue_rdata_i,
    // RX FIFO
    input logic rx_queue_full_i,
    input logic [HciRxFifoDepthWidth-1:0] rx_queue_depth_i,
    input logic [HciRxThldWidth-1:0] rx_queue_start_thld_i,
    input logic rx_queue_start_thld_trig_i,
    input logic [HciRxThldWidth-1:0] rx_queue_ready_thld_i,
    input logic rx_queue_ready_thld_trig_i,
    input logic rx_queue_empty_i,
    output logic rx_queue_wvalid_o,
    input logic rx_queue_wready_i,
    output logic [HciRxDataWidth-1:0] rx_queue_wdata_o,
    // TX FIFO
    input logic tx_queue_full_i,
    input logic [HciTxFifoDepthWidth-1:0] tx_queue_depth_i,
    input logic [HciTxThldWidth-1:0] tx_queue_start_thld_i,
    input logic tx_queue_start_thld_trig_i,
    input logic [HciTxThldWidth-1:0] tx_queue_ready_thld_i,
    input logic tx_queue_ready_thld_trig_i,
    input logic tx_queue_empty_i,
    input logic tx_queue_rvalid_i,
    output logic tx_queue_rready_o,
    input logic [HciTxDataWidth-1:0] tx_queue_rdata_i,
    // Response FIFO
    input logic resp_queue_full_i,
    input logic [HciRespFifoDepthWidth-1:0] resp_queue_depth_i,
    input logic [HciRespThldWidth-1:0] resp_queue_ready_thld_i,
    input logic resp_queue_ready_thld_trig_i,
    input logic resp_queue_empty_i,
    output logic resp_queue_wvalid_o,
    input logic resp_queue_wready_i,
    output logic [HciRespDataWidth-1:0] resp_queue_wdata_o,

    // In-band Interrupt queue
    input logic ibi_queue_full_i,
    input logic [HciIbiFifoDepthWidth-1:0] ibi_queue_depth_i,
    input logic [HciIbiThldWidth-1:0] ibi_queue_ready_thld_i,
    input logic ibi_queue_ready_thld_trig_i,
    input logic ibi_queue_empty_i,
    output logic ibi_queue_wvalid_o,
    input logic ibi_queue_wready_i,
    output logic [HciIbiDataWidth-1:0] ibi_queue_wdata_o,

    // DAT <-> Controller interface
    output logic                          dat_read_valid_hw_o,
    output logic [$clog2(`DAT_DEPTH)-1:0] dat_index_hw_o,
    input  logic [                  63:0] dat_rdata_hw_i,

    // DCT <-> Controller interface
    output logic                          dct_write_valid_hw_o,
    output logic                          dct_read_valid_hw_o,
    output logic [$clog2(`DCT_DEPTH)-1:0] dct_index_hw_o,
    output logic [                 127:0] dct_wdata_hw_o,
    input  logic [                 127:0] dct_rdata_hw_i,

    // TODO: rename
    input  logic i3c_fsm_en_i,
    output logic i3c_fsm_idle_o,

    // Errors and Interrupts
    output i3c_err_t err,
    output i3c_irq_t irq,
    input logic i2c_active_en_i,
    input logic i2c_standby_en_i,
    input logic i3c_active_en_i,
    input logic i3c_standby_en_i,
    input logic [19:0] t_hd_dat_i,
    input logic [19:0] t_r_i,
    input logic [19:0] t_f_i,
    input logic [19:0] t_bus_free_i,
    input logic [19:0] t_bus_idle_i,
    input logic [19:0] t_bus_available_i

);

  logic host_enable;
  logic fmt_fifo_rvalid;
  logic [I2CFifoDepthWidth-1:0] fmt_fifo_depth;
  logic fmt_fifo_rready;
  logic [7:0] fmt_byte;
  logic fmt_flag_start_before;
  logic fmt_flag_stop_after;
  logic fmt_flag_read_bytes;
  logic fmt_flag_read_continue;
  logic fmt_flag_nak_ok;
  logic unhandled_unexp_nak;
  logic unhandled_nak_timeout;
  logic rx_fifo_wvalid;
  logic [RxFifoWidth-1:0] rx_fifo_wdata;
  logic unused_phy_sel_od_pp, unused_fmt_flag_restart_after, unused_i3c_fsm_idle;
  logic fmt_bit;

  // TODO: Connect I2C Controller SDA/SCL to I3C Flow FSM

  flow_active flow_fsm (
      .clk_i,
      .rst_ni,
      .cmd_queue_full_i,
      .cmd_queue_ready_thld_i,
      .cmd_queue_ready_thld_trig_i,
      .cmd_queue_empty_i,
      .cmd_queue_rvalid_i,
      .cmd_queue_rready_o,
      .cmd_queue_rdata_i,
      .rx_queue_full_i,
      .rx_queue_start_thld_i,
      .rx_queue_start_thld_trig_i,
      .rx_queue_ready_thld_i,
      .rx_queue_ready_thld_trig_i,
      .rx_queue_empty_i,
      .rx_queue_wvalid_o,
      .rx_queue_wready_i,
      .rx_queue_wdata_o,
      .tx_queue_full_i,
      .tx_queue_start_thld_i,
      .tx_queue_start_thld_trig_i,
      .tx_queue_ready_thld_i,
      .tx_queue_ready_thld_trig_i,
      .tx_queue_empty_i,
      .tx_queue_rvalid_i,
      .tx_queue_rready_o,
      .tx_queue_rdata_i,
      .resp_queue_full_i,
      .resp_queue_ready_thld_i,
      .resp_queue_ready_thld_trig_i,
      .resp_queue_empty_i,
      .resp_queue_wvalid_o,
      .resp_queue_wready_i,
      .resp_queue_wdata_o,
      .ibi_queue_full_i,
      .ibi_queue_ready_thld_i,
      .ibi_queue_ready_thld_trig_i,
      .ibi_queue_empty_i,
      .ibi_queue_wvalid_o,
      .ibi_queue_wready_i,
      .ibi_queue_wdata_o,
      .dat_read_valid_hw_o,
      .dat_index_hw_o,
      .dat_rdata_hw_i,
      .dct_write_valid_hw_o,
      .dct_read_valid_hw_o,
      .dct_index_hw_o,
      .dct_wdata_hw_o,
      .dct_rdata_hw_i,
      .host_enable_o(host_enable),  // unconnected
      .fmt_fifo_rvalid_o(fmt_fifo_rvalid_o),
      .fmt_fifo_depth_o(fmt_fifo_depth_o),
      .fmt_fifo_rready_i(fmt_fifo_rready_i),
      .fmt_fifo_rdone_i(fmt_fifo_rdone_i),
      .fmt_byte_o(fmt_byte_o),
      .fmt_bit_o(fmt_bit),
      .fmt_flag_start_before_o(fmt_flag_start_before_o),
      .fmt_flag_stop_after_o(fmt_flag_stop_after_o),
      .fmt_flag_read_bytes_o(fmt_flag_read_bytes_o),
      .fmt_flag_restart_after_o(unused_fmt_flag_restart_after),
      .fmt_flag_read_continuous_o(fmt_flag_read_continue_o),
      .fmt_flag_nak_ok_o(fmt_flag_nak_ok_o),
      .fmt_receive_nack_i(1'b0),  // we never receive nacks in this test
      .fmt_sda_arbitration_i(1'b0),  // this feature is not tested in this test
      .fmt_byte_i('0),  // unused
      .fmt_bit_i(1'b0),  // unused
      .fmt_flag_read_valid_i(1'b0),  // unused
      .unhandled_unexp_nak_o(unhandled_unexp_nak_o),
      .unhandled_nak_timeout_o(unhandled_nak_timeout_o),
      .rx_fifo_wvalid_i(rx_fifo_wvalid),  // unconnected
      .rx_fifo_wdata_i(rx_fifo_wdata),  // unconnected
      .i3c_fsm_en_i(i3c_active_en_i),
      .phy_sel_od_pp_i(1'b0),
      .phy_sel_od_pp_o(unused_phy_sel_od_pp),
      .i3c_fsm_idle_o(unused_i3c_fsm_idle),
      .err,
      .irq
  );

endmodule
