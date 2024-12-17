// SPDX-License-Identifier: Apache-2.0

module controller_active
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

    // Interface to SDA/SCL
    input logic ctrl_scl_i[2],
    input logic ctrl_sda_i[2],
    output logic ctrl_scl_o[2],
    output logic ctrl_sda_o[2],
    output logic phy_sel_od_pp_o[2],

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
    input logic phy_en_i,
    input logic [1:0] phy_mux_select_i,
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
      .host_enable_o(host_enable),
      .fmt_fifo_rvalid_o(fmt_fifo_rvalid),
      .fmt_fifo_depth_o(fmt_fifo_depth),
      .fmt_fifo_rready_i(fmt_fifo_rready),
      .fmt_byte_o(fmt_byte),
      .fmt_flag_start_before_o(fmt_flag_start_before),
      .fmt_flag_stop_after_o(fmt_flag_stop_after),
      .fmt_flag_read_bytes_o(fmt_flag_read_bytes),
      .fmt_flag_read_continue_o(fmt_flag_read_continue),
      .fmt_flag_nak_ok_o(fmt_flag_nak_ok),
      .unhandled_unexp_nak_o(unhandled_unexp_nak),
      .unhandled_nak_timeout_o(unhandled_nak_timeout),
      .rx_fifo_wvalid_i(rx_fifo_wvalid),
      .rx_fifo_wdata_i(rx_fifo_wdata),
      .i3c_fsm_en_i,
      .i3c_fsm_idle_o,
      .err,
      .irq
  );

  logic unused_host_idle_o;
  logic unused_event_nak_o;
  logic unused_event_unhandled_nak_timeout_o;
  logic unused_event_scl_interference_o;
  logic unused_event_sda_interference_o;
  logic unused_event_stretch_timeout_o;
  logic unused_event_sda_unstable_o;
  logic unused_event_cmd_complete_o;

  i2c_controller_fsm i2c_fsm (
      .clk_i (clk_i),
      .rst_ni(rst_ni),
      .scl_i (ctrl_scl_i[0]),
      .scl_o (ctrl_scl_o[0]),
      .sda_i (ctrl_sda_i[0]),
      .sda_o (ctrl_sda_o[0]),

      // These should be controlled by the flow FSM
      // TODO: reconnect to flow fsm once configuration.sv is connected properly to CSRs
      .host_enable_i(0),
      .fmt_fifo_rvalid_i(fmt_fifo_rvalid),
      .fmt_fifo_depth_i(fmt_fifo_depth),
      .fmt_fifo_rready_o(fmt_fifo_rready),
      .fmt_byte_i(fmt_byte),
      .fmt_flag_start_before_i(fmt_flag_start_before),
      .fmt_flag_stop_after_i(fmt_flag_stop_after),
      .fmt_flag_read_bytes_i(fmt_flag_read_bytes),
      .fmt_flag_read_continue_i(fmt_flag_read_continue),
      .fmt_flag_nak_ok_i(fmt_flag_nak_ok),
      .unhandled_unexp_nak_i(unhandled_unexp_nak),
      .unhandled_nak_timeout_i(unhandled_nak_timeout),
      .rx_fifo_wvalid_o(rx_fifo_wvalid),
      .rx_fifo_wdata_o(rx_fifo_wdata),
      .host_idle_o(unused_host_idle_o),

      // TODO: Use calculated timing values
      // TODO: Expose as programmable feature
      .thigh_i(16'd10),
      .tlow_i(16'd10),
      .t_r_i(16'd1),
      .t_f_i(16'd1),
      .thd_sta_i(16'd1),
      .tsu_sta_i(16'd1),
      .tsu_sto_i(16'd1),
      .tsu_dat_i(16'd1),
      .thd_dat_i(16'd1),
      .t_buf_i(16'd1),

      // Clock stretch is not supported by I3C bus
      .stretch_timeout_i('0),
      .timeout_enable_i ('0),

      // TODO: Handle NACK on bus
      .host_nack_handler_timeout_i('0),
      .host_nack_handler_timeout_en_i('0),

      // TODO: Handle bus events
      .event_nak_o(unused_event_nak_o),
      .event_unhandled_nak_timeout_o(unused_event_unhandled_nak_timeout_o),
      .event_scl_interference_o(unused_event_scl_interference_o),
      .event_sda_interference_o(unused_event_sda_interference_o),
      .event_stretch_timeout_o(unused_event_stretch_timeout_o),
      .event_sda_unstable_o(unused_event_sda_unstable_o),
      .event_cmd_complete_o(unused_event_cmd_complete_o)
  );

  // TODO: Handle i3c waveform
  i3c_controller_fsm xi3c_controller_fsm (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .ctrl_scl_i(ctrl_scl_i[1]),
      .ctrl_sda_i(ctrl_sda_i[1]),
      .ctrl_scl_o(ctrl_scl_o[1]),
      .ctrl_sda_o(ctrl_sda_o[1])
  );

  // TODO: Handle driver switching in the active controller mode
  assign phy_sel_od_pp_o[0] = '0;
  assign phy_sel_od_pp_o[1] = '0;
endmodule
