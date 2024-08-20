// SPDX-License-Identifier: Apache-2.0

module controller_standby_i3c
  import controller_pkg::*;
  import i3c_pkg::*;
  import hci_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,
    input i3c_config_t core_config,

    // Interface to SDA/SCL
    input  logic ctrl_scl_i,
    input  logic ctrl_sda_i,
    output logic ctrl_scl_o,
    output logic ctrl_sda_o,

    // Target Transaction Interface

    // TTI: RX Descriptor
    input logic tti_rx_desc_queue_full_i,
    input logic [TtiRxDescThldWidth-1:0] tti_rx_desc_queue_ready_thld_i,
    input logic tti_rx_desc_queue_ready_thld_trig_i,
    input logic tti_rx_desc_queue_empty_i,
    output logic tti_rx_desc_queue_wvalid_o,
    input logic tti_rx_desc_queue_wready_i,
    output logic [TtiRxDescDataWidth-1:0] tti_rx_desc_queue_wdata_o,

    // TTI: TX Descriptor
    input logic tti_tx_desc_queue_full_i,
    input logic [TtiTxDescThldWidth-1:0] tti_tx_desc_queue_ready_thld_i,
    input logic tti_tx_desc_queue_ready_thld_trig_i,
    input logic tti_tx_desc_queue_empty_i,
    input logic tti_tx_desc_queue_rvalid_i,
    output logic tti_tx_desc_queue_rready_o,
    input logic [TtiTxDescDataWidth-1:0] tti_tx_desc_queue_rdata_i,

    // TTI: RX Data
    input logic tti_rx_queue_full_i,
    input logic [TtiRxThldWidth-1:0] tti_rx_queue_start_thld_i,
    input logic tti_rx_queue_start_thld_trig_i,
    input logic [TtiRxThldWidth-1:0] tti_rx_queue_ready_thld_i,
    input logic tti_rx_queue_ready_thld_trig_i,
    input logic tti_rx_queue_empty_i,
    output logic tti_rx_queue_wvalid_o,
    input logic tti_rx_queue_wready_i,
    output logic [TtiRxDataWidth-1:0] tti_rx_queue_wdata_o,

    // TTI: TX Data
    input logic tti_tx_queue_full_i,
    input logic [TtiTxThldWidth-1:0] tti_tx_queue_start_thld_i,
    input logic tti_tx_queue_start_thld_trig_i,
    input logic [TtiTxThldWidth-1:0] tti_tx_queue_ready_thld_i,
    input logic tti_tx_queue_ready_thld_trig_i,
    input logic tti_tx_queue_empty_i,
    input logic tti_tx_queue_rvalid_i,
    output logic tti_tx_queue_rready_o,
    input logic [TtiTxDataWidth-1:0] tti_tx_queue_rdata_i
);

  logic enable;
  assign enable = core_config.i3c_standby_en;


  logic [1:0] transfer_type;
  logic rx_byte_valid;
  logic [7:0] rx_byte;
  logic rx_byte_ready;
  logic tx_byte_valid;
  logic [7:0] tx_byte;
  logic tx_byte_ready;

  logic i3c_bus_start_det;
  logic i3c_bus_stop_det;

  flow_standby_i3c xflow_standby_i3c (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .enable_i(enable),
      .rx_queue_full_i(tti_rx_queue_full_i),
      .rx_queue_empty_i(tti_rx_queue_empty_i),
      .rx_queue_wvalid_o(tti_rx_queue_wvalid_o),
      .rx_queue_wready_i(tti_rx_queue_wready_i),
      .rx_queue_wdata_o(tti_rx_queue_wdata_o),

      .tx_queue_full_i  (tti_tx_queue_full_i),
      .tx_queue_empty_i (tti_tx_queue_empty_i),
      .tx_queue_rvalid_i(tti_tx_queue_rvalid_i),
      .tx_queue_rready_o(tti_tx_queue_rready_o),
      .tx_queue_rdata_i (tti_tx_queue_rdata_i),

      .transfer_start_i(i3c_bus_start_det),  // Repeated start is not filtered from this signal
      .transfer_stop_i(i3c_bus_stop_det),
      .transfer_type_i(transfer_type),
      .rx_byte_valid_i(rx_byte_valid),
      .rx_byte_i(rx_byte),
      .rx_byte_ready_o(rx_byte_ready),
      .tx_byte_valid_o(tx_byte_valid),
      .tx_byte_o(tx_byte),
      .tx_byte_ready_i(tx_byte_ready)
  );
  logic i3c_bus_arbitration_lost_i;
  logic i3c_bus_timeout_i;
  logic i3c_target_idle_o;
  logic i3c_target_transmitting_o;
  logic i3c_tx_fifo_rvalid_i;
  logic i3c_tx_fifo_rready_o;
  logic [TX_FIFO_WIDTH-1:0] i3c_tx_fifo_rdata_i;
  logic i3c_rx_fifo_wvalid_o;
  logic [RX_FIFO_WIDTH-1:0] i3c_rx_fifo_wdata_o;
  logic i3c_rx_fifo_wready_i;
  logic [12:0] i3c_t_r_i;
  logic [12:0] i3c_tsu_dat_i;
  logic [12:0] i3c_thd_dat_i;
  logic i3c_event_target_nack_o;
  logic i3c_event_cmd_complete_o;
  logic i3c_event_unexp_stop_o;
  logic i3c_event_tx_arbitration_lost_o;
  logic i3c_event_tx_bus_timeout_o;
  logic i3c_event_read_cmd_received_o;

  assign ctrl_scl_o = '1;
  assign ctrl_sda_o = '1;

  // TODO: Assign timings from CSRs
  assign i3c_t_r_i = 13'd10;
  assign i3c_tsu_dat_i = 13'd10;
  assign i3c_thd_dat_i = 13'd10;

  // Target FSM <--> DAA
  logic [6:0] bus_addr;
  logic bus_addr_valid;
  logic is_sta_addr_match;
  logic is_dyn_addr_match;
  logic is_i3c_rsvd_addr_match;
  logic is_any_addr_match;
  logic [31:0] stby_cr_device_addr_reg;
  logic [31:0] stby_cr_device_char_reg;
  logic [31:0] stby_cr_device_pid_lo_reg;
  logic [63:0] daa_unique_response;
  // Valid, rsvd, dynamic addr, valid, rsvd, static addr
  assign stby_cr_device_addr_reg   = {1'b1, 8'h00, 7'h5A, 1'b1, 8'h00, 7'h22};
  assign stby_cr_device_char_reg   = '0;
  assign stby_cr_device_pid_lo_reg = '0;
  // end: Target FSM <--> DAA

  i3c_target_fsm xi3c_target_fsm (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .target_enable_i(enable),
      .scl_i(ctrl_scl_i),
      .scl_o(ctrl_scl_o),
      .sda_i(ctrl_sda_i),
      .sda_o(ctrl_sda_o),
      .bus_start_det_i(i3c_bus_start_det),
      .bus_stop_detect_i(i3c_bus_stop_det),
      .bus_arbitration_lost_i(i3c_bus_arbitration_lost_i),
      .bus_timeout_i(i3c_bus_timeout_i),
      .target_idle_o(i3c_target_idle_o),
      .target_transmitting_o(i3c_target_transmitting_o),
      .tx_fifo_rvalid_i(tx_byte_valid),
      .tx_fifo_rready_o(tx_byte_ready),
      .tx_fifo_rdata_i(tx_byte),
      .rx_fifo_wvalid_o(rx_byte_valid),
      .rx_fifo_wdata_o(rx_byte),
      .rx_fifo_wready_i(rx_byte_ready),
      .transfer_type_o(transfer_type),
      .t_r_i(i3c_t_r_i),
      .tsu_dat_i(i3c_tsu_dat_i),
      .thd_dat_i(i3c_thd_dat_i),
      .is_sta_addr_match(is_sta_addr_match),
      .is_dyn_addr_match(is_dyn_addr_match),
      .bus_addr(bus_addr),
      .bus_addr_valid(bus_addr_valid),
      .is_i3c_rsvd_addr_match(is_i3c_rsvd_addr_match),
      .is_any_addr_match(is_any_addr_match),
      .event_target_nack_o(i3c_event_target_nack_o),
      .event_cmd_complete_o(i3c_event_cmd_complete_o),
      .event_unexp_stop_o(i3c_event_unexp_stop_o),
      .event_tx_arbitration_lost_o(i3c_event_tx_arbitration_lost_o),
      .event_tx_bus_timeout_o(i3c_event_tx_bus_timeout_o),
      .event_read_cmd_received_o(i3c_event_read_cmd_received_o)
  );

  logic        target_idle_i;
  logic [12:0] thd_dat_i;
  logic [12:0] t_buf_i;
  logic [29:0] bus_active_timeout_i;
  logic        bus_active_timeout_en_i;
  logic [19:0] bus_inactive_timeout_i;

  logic        bus_free_o;
  logic        start_detect_o;
  logic        stop_detect_o;
  logic        event_bus_active_timeout_o;
  logic        event_host_timeout_o;

  // TODO: Should be dynamic (relative to clock)
  // Static configuration of bus monitor
  // These assume 500MHz clk
  // These are tuned, not calculated
  assign thd_dat_i = 13'd10;
  assign t_buf_i = 13'd500;
  assign bus_active_timeout_i = 30'd2500000;
  assign bus_active_timeout_en_i = 1'b1;
  assign bus_inactive_timeout_i = 20'd5000;

  bus_monitor xbus_monitor (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .scl_i(ctrl_scl_i),
      .sda_i(ctrl_sda_i),
      .controller_enable_i('0),
      .multi_controller_enable_i('0),
      .target_enable_i(enable),
      .target_idle_i(target_idle_i),
      .thd_dat_i(thd_dat_i),
      .t_buf_i(t_buf_i),
      .bus_active_timeout_i(bus_active_timeout_i),
      .bus_active_timeout_en_i(bus_active_timeout_en_i),
      .bus_inactive_timeout_i(bus_inactive_timeout_i),
      .bus_free_o(bus_free_o),
      .start_detect_o(i3c_bus_start_det),
      .stop_detect_o(i3c_bus_stop_det),
      .event_bus_active_timeout_o(event_bus_active_timeout_o),
      .event_host_timeout_o(event_host_timeout_o)
  );

  daa xdaa (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .bus_addr(bus_addr),
      .bus_addr_valid(bus_addr_valid),
      .is_sta_addr_match_o(is_sta_addr_match),
      .is_dyn_addr_match_o(is_dyn_addr_match),
      .is_i3c_rsvd_addr_match_o(is_i3c_rsvd_addr_match),
      .is_any_addr_match_o(is_any_addr_match),
      .stby_cr_device_addr_reg(stby_cr_device_addr_reg),
      .stby_cr_device_char_reg(stby_cr_device_char_reg),
      .stby_cr_device_pid_lo_reg(stby_cr_device_pid_lo_reg),
      .daa_unique_response(daa_unique_response)
  );


endmodule
