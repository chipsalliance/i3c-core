// SPDX-License-Identifier: Apache-2.0

module controller_standby_i2c
  import controller_pkg::*;
  import i3c_pkg::*;
#(
    parameter int AcqFifoDepth = 64,
    localparam int AcqFifoDepthWidth = $clog2(AcqFifoDepth + 1),

    parameter int unsigned TtiRxDescDataWidth = 32,
    parameter int unsigned TtiTxDescDataWidth = 32,
    parameter int unsigned TtiRxDataWidth = 32,
    parameter int unsigned TtiTxDataWidth = 32,

    parameter int unsigned TtiRxDescThldWidth = 8,
    parameter int unsigned TtiTxDescThldWidth = 8,
    parameter int unsigned TtiRxThldWidth = 3,
    parameter int unsigned TtiTxThldWidth = 3
) (
    input logic clk_i,
    input logic rst_ni,

    // Interface to SDA/SCL
    input  logic ctrl_scl_i,
    input  logic ctrl_sda_i,
    output logic ctrl_scl_o,
    output logic ctrl_sda_o,
    output logic phy_sel_od_pp_o,

    // Target Transaction Interface

    // TTI: RX Descriptor
    input logic rx_desc_queue_full_i,
    input logic [TtiRxDescThldWidth-1:0] rx_desc_queue_ready_thld_i,
    input logic rx_desc_queue_ready_thld_trig_i,
    input logic rx_desc_queue_empty_i,
    output logic rx_desc_queue_wvalid_o,
    input logic rx_desc_queue_wready_i,
    output logic [TtiRxDescDataWidth-1:0] rx_desc_queue_wdata_o,

    // TTI: TX Descriptor
    input logic tx_desc_queue_full_i,
    input logic [TtiTxDescThldWidth-1:0] tx_desc_queue_ready_thld_i,
    input logic tx_desc_queue_ready_thld_trig_i,
    input logic tx_desc_queue_empty_i,
    input logic tx_desc_queue_rvalid_i,
    output logic tx_desc_queue_rready_o,
    input logic [TtiTxDescDataWidth-1:0] tx_desc_queue_rdata_i,

    // TTI: RX Data
    input logic rx_queue_full_i,
    input logic [TtiRxThldWidth-1:0] rx_queue_start_thld_i,
    input logic rx_queue_start_thld_trig_i,
    input logic [TtiRxThldWidth-1:0] rx_queue_ready_thld_i,
    input logic rx_queue_ready_thld_trig_i,
    input logic rx_queue_empty_i,
    output logic rx_queue_wvalid_o,
    input logic rx_queue_wready_i,
    output logic [TtiRxDataWidth-1:0] rx_queue_wdata_o,

    // TTI: TX Data
    input logic tx_queue_full_i,
    input logic [TtiTxThldWidth-1:0] tx_queue_start_thld_i,
    input logic tx_queue_start_thld_trig_i,
    input logic [TtiTxThldWidth-1:0] tx_queue_ready_thld_i,
    input logic tx_queue_ready_thld_trig_i,
    input logic tx_queue_empty_i,
    input logic tx_queue_rvalid_i,
    output logic tx_queue_rready_o,
    input logic [TtiTxDataWidth-1:0] tx_queue_rdata_i,

    // Bus condition detection
    output logic bus_start_o,
    output logic bus_rstart_o,
    output logic bus_stop_o,

    // I2C received address (with RnW# bit) for the recovery handler
    output logic [7:0] bus_addr_o,
    output logic bus_addr_valid_o,

    input logic phy_en_i,
    input logic [1:0] phy_mux_select_i,
    input logic i2c_active_en_i,
    input logic i2c_standby_en_i,
    input logic i3c_active_en_i,
    input logic i3c_standby_en_i,
    input logic [19:0] t_hd_dat_i,
    input logic [19:0] t_r_i,
    input logic [19:0] t_bus_free_i,
    input logic [19:0] t_bus_idle_i,
    input logic [19:0] t_bus_available_i,

    output logic tx_host_nack_o
);

  logic [TxFifoWidth-1:0] tx_fifo_data_int;
  logic tx_fifo_valid_int;
  logic tx_fifo_ready_int;

  logic [AcqFifoWidth-1:0] acq_fifo_data_int;
  logic [AcqFifoDepthWidth-1:0] acq_fifo_depth_int;
  logic acq_fifo_ready_int;
  logic acq_fifo_valid_int;
  logic err;


  flow_standby_i2c #(
      .AcqFifoDepth(AcqFifoDepth)
  ) xflow_standby_i2c (
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
      .cmd_fifo_rdata_i (tx_desc_queue_rdata_i),
      .cmd_fifo_rvalid_i(tx_desc_queue_rvalid_i),
      .cmd_fifo_rready_o(tx_desc_queue_rready_o),

      .response_fifo_wdata_o (rx_desc_queue_wdata_o),
      .response_fifo_wvalid_o(rx_desc_queue_wvalid_o),
      .response_fifo_wready_i(rx_desc_queue_wready_i),

      .tx_fifo_rdata_i (tx_queue_rdata_i),
      .tx_fifo_rvalid_i(tx_queue_rvalid_i),
      .tx_fifo_rready_o(tx_queue_rready_o),

      .rx_fifo_wdata_o (rx_queue_wdata_o),
      .rx_fifo_wvalid_o(rx_queue_wvalid_o),
      .rx_fifo_wready_i(rx_queue_wready_i),

      // Other
      .err_o(err)
  );


  i2c_target_fsm #(
      .AcqFifoDepth(AcqFifoDepth)
  ) xi2c_target_fsm (
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
      .target_enable_i(i2c_standby_en_i),
      .target_idle_o(),
      .target_sr_p_cond_o(),
      .event_target_nack_o(),
      .event_cmd_complete_o(),
      .event_tx_stretch_o(),
      .event_unexp_stop_o(),
      .event_host_timeout_o()
  );

  // TODO: Temporarily set here to always use OD. Verify this connection
  assign phy_sel_od_pp_o = 1'b0;

  // TODO: Make the I2C FSM report start/stop condition detection
  assign bus_start_o = '0;
  assign bus_rstart_o= '0;
  assign bus_stop_o  = '0;

  // TODO: Make the I2C FSM output its received address + RnW bit and connect
  // them here.
  assign bus_addr_o = '0;
  assign bus_addr_valid_o = '0;

  // TODO: Detect host NACKs and expose them here
  assign tx_host_nack_o = '0;

endmodule
