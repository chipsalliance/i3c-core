// SPDX-License-Identifier: Apache-2.0

module controller_standby
  import controller_pkg::*;
  import i3c_pkg::*;
  import hci_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,
    input i3c_config_t core_config,

    // Interface to SDA/SCL
    input  logic ctrl_scl_i[2],
    input  logic ctrl_sda_i[2],
    output logic ctrl_scl_o[2],
    output logic ctrl_sda_o[2],

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

  logic sel_i2c_i3c;  // i2c = 0; i3c = 1;
  always_comb begin
    if (core_config.i2c_standby_en) begin
      sel_i2c_i3c = '0;
    end else if (core_config.i3c_standby_en) begin
      sel_i2c_i3c = '1;
    end else begin
      sel_i2c_i3c = '1;
    end
    // TODO: Assert that i3c_standby_en and i2c_standby_en are never high at the same time
  end

  logic i3c_tti_rx_desc_queue_wvalid_o;
  logic i2c_tti_rx_desc_queue_wvalid_o;
  logic [TtiRxDescDataWidth-1:0] i3c_tti_rx_desc_queue_wdata_o;
  logic [TtiRxDescDataWidth-1:0] i2c_tti_rx_desc_queue_wdata_o;
  logic i3c_tti_rx_queue_wvalid_o;
  logic i2c_tti_rx_queue_wvalid_o;
  logic [TtiRxDataWidth-1:0] i3c_tti_rx_queue_wdata_o;
  logic [TtiRxDataWidth-1:0] i2c_tti_rx_queue_wdata_o;
  logic i3c_tti_tx_desc_queue_rready_o;
  logic i2c_tti_tx_desc_queue_rready_o;
  logic i3c_tti_tx_queue_rready_o;
  logic i2c_tti_tx_queue_rready_o;
  // Mux TTI outputs between I2C and I3C
  always_comb begin
    tti_rx_desc_queue_wvalid_o  = sel_i2c_i3c ? i3c_tti_rx_desc_queue_wvalid_o
                                              : i2c_tti_rx_desc_queue_wvalid_o;
    tti_rx_desc_queue_wdata_o   = sel_i2c_i3c ? i3c_tti_rx_desc_queue_wdata_o
                                              : i2c_tti_rx_desc_queue_wdata_o;
    tti_rx_queue_wvalid_o = sel_i2c_i3c ? i3c_tti_rx_queue_wvalid_o : i2c_tti_rx_queue_wvalid_o;
    tti_rx_queue_wdata_o = sel_i2c_i3c ? i3c_tti_rx_queue_wdata_o : i2c_tti_rx_queue_wdata_o;
    tti_tx_desc_queue_rready_o  = sel_i2c_i3c ? i3c_tti_tx_desc_queue_rready_o
                                              : i2c_tti_tx_desc_queue_rready_o;
    tti_tx_queue_rready_o = sel_i2c_i3c ? i3c_tti_tx_queue_rready_o : i2c_tti_tx_queue_rready_o;
  end

  controller_standby_i2c xcontroller_standby_i2c (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .core_config(core_config),
      .ctrl_scl_i(ctrl_scl_i[0]),
      .ctrl_sda_i(ctrl_sda_i[0]),
      .ctrl_scl_o(ctrl_scl_o[0]),
      .ctrl_sda_o(ctrl_sda_o[0]),
      .tti_rx_desc_queue_full_i(tti_rx_desc_queue_full_i),
      .tti_rx_desc_queue_ready_thld_i(tti_rx_desc_queue_ready_thld_i),
      .tti_rx_desc_queue_ready_thld_trig_i(tti_rx_desc_queue_ready_thld_trig_i),
      .tti_rx_desc_queue_empty_i(tti_rx_desc_queue_empty_i),
      .tti_rx_desc_queue_wvalid_o(i2c_tti_rx_desc_queue_wvalid_o),
      .tti_rx_desc_queue_wready_i(tti_rx_desc_queue_wready_i),
      .tti_rx_desc_queue_wdata_o(i2c_tti_rx_desc_queue_wdata_o),
      .tti_tx_desc_queue_full_i(tti_tx_desc_queue_full_i),
      .tti_tx_desc_queue_ready_thld_i(tti_tx_desc_queue_ready_thld_i),
      .tti_tx_desc_queue_ready_thld_trig_i(tti_tx_desc_queue_ready_thld_trig_i),
      .tti_tx_desc_queue_empty_i(tti_tx_desc_queue_empty_i),
      .tti_tx_desc_queue_rvalid_i(tti_tx_desc_queue_rvalid_i),
      .tti_tx_desc_queue_rready_o(i2c_tti_tx_desc_queue_rready_o),
      .tti_tx_desc_queue_rdata_i(tti_tx_desc_queue_rdata_i),
      .tti_rx_queue_full_i(tti_rx_queue_full_i),
      .tti_rx_queue_start_thld_i(tti_rx_queue_start_thld_i),
      .tti_rx_queue_start_thld_trig_i(tti_rx_queue_start_thld_trig_i),
      .tti_rx_queue_ready_thld_i(tti_rx_queue_ready_thld_i),
      .tti_rx_queue_ready_thld_trig_i(tti_rx_queue_ready_thld_trig_i),
      .tti_rx_queue_empty_i(tti_rx_queue_empty_i),
      .tti_rx_queue_wvalid_o(i2c_tti_rx_queue_wvalid_o),
      .tti_rx_queue_wready_i(tti_rx_queue_wready_i),
      .tti_rx_queue_wdata_o(i2c_tti_rx_queue_wdata_o),
      .tti_tx_queue_full_i(tti_tx_queue_full_i),
      .tti_tx_queue_start_thld_i(tti_tx_queue_start_thld_i),
      .tti_tx_queue_start_thld_trig_i(tti_tx_queue_start_thld_trig_i),
      .tti_tx_queue_ready_thld_i(tti_tx_queue_ready_thld_i),
      .tti_tx_queue_ready_thld_trig_i(tti_tx_queue_ready_thld_trig_i),
      .tti_tx_queue_empty_i(tti_tx_queue_empty_i),
      .tti_tx_queue_rvalid_i(tti_tx_queue_rvalid_i),
      .tti_tx_queue_rready_o(i2c_tti_tx_queue_rready_o),
      .tti_tx_queue_rdata_i(tti_tx_queue_rdata_i)
  );


  controller_standby_i3c xcontroller_standby_i3c (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .core_config(core_config),
      .ctrl_scl_i(ctrl_scl_i[1]),
      .ctrl_sda_i(ctrl_sda_i[1]),
      .ctrl_scl_o(ctrl_scl_o[1]),
      .ctrl_sda_o(ctrl_sda_o[1]),
      .tti_rx_desc_queue_full_i(tti_rx_desc_queue_full_i),
      .tti_rx_desc_queue_ready_thld_i(tti_rx_desc_queue_ready_thld_i),
      .tti_rx_desc_queue_ready_thld_trig_i(tti_rx_desc_queue_ready_thld_trig_i),
      .tti_rx_desc_queue_empty_i(tti_rx_desc_queue_empty_i),
      .tti_rx_desc_queue_wvalid_o(i3c_tti_rx_desc_queue_wvalid_o),
      .tti_rx_desc_queue_wready_i(tti_rx_desc_queue_wready_i),
      .tti_rx_desc_queue_wdata_o(i3c_tti_rx_desc_queue_wdata_o),
      .tti_rx_queue_full_i(tti_rx_queue_full_i),
      .tti_rx_queue_start_thld_i(tti_rx_queue_start_thld_i),
      .tti_rx_queue_start_thld_trig_i(tti_rx_queue_start_thld_trig_i),
      .tti_rx_queue_ready_thld_i(tti_rx_queue_ready_thld_i),
      .tti_rx_queue_ready_thld_trig_i(tti_rx_queue_ready_thld_trig_i),
      .tti_rx_queue_empty_i(tti_rx_queue_empty_i),
      .tti_rx_queue_wvalid_o(i3c_tti_rx_queue_wvalid_o),
      .tti_rx_queue_wready_i(tti_rx_queue_wready_i),
      .tti_rx_queue_wdata_o(i3c_tti_rx_queue_wdata_o),
      .tti_tx_desc_queue_full_i(tti_tx_desc_queue_full_i),
      .tti_tx_desc_queue_ready_thld_i(tti_tx_desc_queue_ready_thld_i),
      .tti_tx_desc_queue_ready_thld_trig_i(tti_tx_desc_queue_ready_thld_trig_i),
      .tti_tx_desc_queue_empty_i(tti_tx_desc_queue_empty_i),
      .tti_tx_desc_queue_rvalid_i(tti_tx_desc_queue_rvalid_i),
      .tti_tx_desc_queue_rready_o(i3c_tti_tx_desc_queue_rready_o),
      .tti_tx_desc_queue_rdata_i(tti_tx_desc_queue_rdata_i),
      .tti_tx_queue_full_i(tti_tx_queue_full_i),
      .tti_tx_queue_start_thld_i(tti_tx_queue_start_thld_i),
      .tti_tx_queue_start_thld_trig_i(tti_tx_queue_start_thld_trig_i),
      .tti_tx_queue_ready_thld_i(tti_tx_queue_ready_thld_i),
      .tti_tx_queue_ready_thld_trig_i(tti_tx_queue_ready_thld_trig_i),
      .tti_tx_queue_empty_i(tti_tx_queue_empty_i),
      .tti_tx_queue_rvalid_i(tti_tx_queue_rvalid_i),
      .tti_tx_queue_rready_o(i3c_tti_tx_queue_rready_o),
      .tti_tx_queue_rdata_i(tti_tx_queue_rdata_i)
  );

endmodule
