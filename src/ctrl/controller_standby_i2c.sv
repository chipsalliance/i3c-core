// SPDX-License-Identifier: Apache-2.0

module controller_standby_i2c
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
  assign enable = core_config.i2c_standby_en;

  logic [TX_FIFO_WIDTH-1:0] tx_fifo_data_int;
  logic tx_fifo_valid_int;
  logic tx_fifo_ready_int;

  logic [ACQ_FIFO_WIDTH-1:0] acq_fifo_data_int;
  logic acq_fifo_depth_int;
  logic acq_fifo_ready_int;
  logic acq_fifo_valid_int;
  logic err;


  flow_standby_i2c xflow_standby_i2c (
      // Clock, reset
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      // OT FIFOs
      .tx_fifo_rdata_o (tx_fifo_data_int),
      .tx_fifo_rvalid_o(tx_fifo_valid_int),
      .tx_fifo_rready_i(tx_fifo_ready_int),

      .acq_fifo_wdata_i (acq_fifo_data_int),
      .acq_fifo_wvalid_i(acq_fifo_valid_int),
      .acq_fifo_wready_i(acq_fifo_ready_int),
      .acq_fifo_depth_o (acq_fifo_depth_int),

      // TTI FIFOs
      .tti_cmd_fifo_rdata_i (tti_tx_desc_queue_rdata_i),
      .tti_cmd_fifo_rvalid_i(tti_tx_desc_queue_rvalid_i),
      .tti_cmd_fifo_rready_o(tti_tx_desc_queue_rready_o),

      .tti_response_fifo_wdata_o (tti_rx_desc_queue_wdata_o),
      .tti_response_fifo_wvalid_o(tti_rx_desc_queue_wvalid_o),
      .tti_response_fifo_wready_i(tti_rx_desc_queue_wready_i),

      .tti_tx_fifo_rdata_i (tti_tx_queue_rdata_i),
      .tti_tx_fifo_rvalid_i(tti_tx_queue_rvalid_i),
      .tti_tx_fifo_rready_o(tti_tx_queue_rready_o),

      .tti_rx_fifo_wdata_o (tti_rx_queue_wdata_o),
      .tti_rx_fifo_wvalid_o(tti_rx_queue_wvalid_o),
      .tti_rx_fifo_wready_i(tti_rx_queue_wready_i),

      // Other
      .err_o(err)
  );


  i2c_target_fsm xi2c_target_fsm (
      // Clock, reset
      .clk_i,
      .rst_ni,
      .scl_i(ctrl_scl_i),
      .scl_o(ctrl_scl_o),
      .sda_i(ctrl_sda_i),
      .sda_o(ctrl_sda_o),
      .tx_fifo_rdata_i(tx_fifo_data_int),
      .tx_fifo_rvalid_i(tx_fifo_valid_int),
      .tx_fifo_rready_o(tx_fifo_ready_int),
      .acq_fifo_wdata_o(acq_fifo_data_int),
      .acq_fifo_wvalid_o(acq_fifo_valid_int),
      .acq_fifo_depth_i(acq_fifo_depth_int),
      .acq_fifo_wready_o(acq_fifo_ready_int),
      .acq_fifo_rdata_i(1),  // This is only used for assertions by OpenTitan
      // Timing setup
      // TODO: Use calculated timing values
      .t_r_i(16'd1),
      .tsu_dat_i(16'd1),
      .thd_dat_i(16'd1),
      .host_timeout_i(0),
      .nack_timeout_i(0),
      .nack_timeout_en_i(0),
      // Addressing setup
      // TODO: Make it configurable
      .target_address0_i('h0c),
      .target_mask0_i('h7f),
      .target_address1_i(0),
      .target_mask1_i(0),
      // Others
      .target_enable_i(enable),
      .target_idle_o(),
      .target_sr_p_cond_o(),
      .event_target_nack_o(),
      .event_cmd_complete_o(),
      .event_tx_stretch_o(),
      .event_unexp_stop_o(),
      .event_host_timeout_o()
  );


endmodule
