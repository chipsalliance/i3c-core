// SPDX-License-Identifier: Apache-2.0

module controller_standby
  import controller_pkg::*;
  import i3c_pkg::*;
#(
    parameter int unsigned TtiRxDescDataWidth = 32,
    parameter int unsigned TtiTxDescDataWidth = 32,
    parameter int unsigned TtiRxDataWidth = 8,
    parameter int unsigned TtiTxDataWidth = 8,
    parameter int unsigned TtiIbiDataWidth = 32,

    parameter int unsigned TtiRxDescThldWidth = 8,
    parameter int unsigned TtiTxDescThldWidth = 8,
    parameter int unsigned TtiRxThldWidth = 3,
    parameter int unsigned TtiTxThldWidth = 3
) (
    input logic clk_i,
    input logic rst_ni,

    // Interface to SDA/SCL
    input logic ctrl_scl_i[2],
    input logic ctrl_sda_i[2],
    output logic ctrl_scl_o[2],
    output logic ctrl_sda_o[2],
    output logic phy_sel_od_pp_o[2],

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
    output logic rx_queue_wflush_o,

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

    // TTI: In-band-interrupt queue
    input logic ibi_queue_full_i,
    input logic ibi_queue_empty_i,
    input logic ibi_queue_rvalid_i,
    output logic ibi_queue_rready_o,
    input logic [TtiIbiDataWidth-1:0] ibi_queue_rdata_i,

    // I2C/I3C Bus condition detection
    output logic bus_start_o,
    output logic bus_rstart_o,
    output logic bus_stop_o,

    // I2C/I3C received address (with RnW# bit) for the recovery handler
    output logic [7:0] bus_addr_o,
    output logic bus_addr_valid_o,

    // Configuration
    input logic phy_en_i,
    input logic [1:0] phy_mux_select_i,
    input logic i2c_active_en_i,
    input logic i2c_standby_en_i,
    input logic i3c_active_en_i,
    input logic i3c_standby_en_i,
    input logic [19:0] t_hd_dat_i,
    input logic [19:0] t_su_dat_i,
    input logic [19:0] t_r_i,
    input logic [19:0] t_f_i,
    input logic [19:0] t_bus_free_i,
    input logic [19:0] t_bus_idle_i,
    input logic [19:0] t_bus_available_i,

    output logic [7:0] rst_action_o,
    output logic tx_host_nack_o
);

  logic sel_i2c_i3c;  // i2c = 0; i3c = 1;
  assign sel_i2c_i3c = i3c_active_en_i | i3c_standby_en_i;

  logic i3c_rx_desc_queue_wvalid_o;
  logic i2c_rx_desc_queue_wvalid_o;
  logic [TtiRxDescDataWidth-1:0] i3c_rx_desc_queue_wdata_o;
  logic [TtiRxDescDataWidth-1:0] i2c_rx_desc_queue_wdata_o;
  logic i3c_rx_queue_wvalid_o;
  logic i2c_rx_queue_wvalid_o;
  logic [TtiRxDataWidth-1:0] i3c_rx_queue_wdata_o;
  logic [TtiRxDataWidth-1:0] i2c_rx_queue_wdata_o;
  logic i3c_rx_queue_wflush_o;
  logic i2c_rx_queue_wflush_o;
  logic i3c_tx_desc_queue_rready_o;
  logic i2c_tx_desc_queue_rready_o;
  logic i3c_tx_queue_rready_o;
  logic i2c_tx_queue_rready_o;
  logic i3c_bus_start_o;
  logic i2c_bus_start_o;
  logic i3c_bus_rstart_o;
  logic i2c_bus_rstart_o;
  logic i3c_bus_stop_o;
  logic i2c_bus_stop_o;
  logic [7:0] i3c_bus_addr_o;
  logic i3c_bus_addr_valid_o;
  logic [7:0] i2c_bus_addr_o;
  logic i2c_bus_addr_valid_o;
  logic i3c_ibi_queue_full_i;
  logic i3c_ibi_queue_empty_i;
  logic i3c_ibi_queue_rvalid_i;
  logic i3c_ibi_queue_rready_o;
  logic i3c_tx_host_nack_o;
  logic i2c_tx_host_nack_o;
  // Mux TTI outputs between I2C and I3C
  always_comb begin
    rx_desc_queue_wvalid_o = sel_i2c_i3c ? i3c_rx_desc_queue_wvalid_o : i2c_rx_desc_queue_wvalid_o;
    rx_desc_queue_wdata_o = sel_i2c_i3c ? i3c_rx_desc_queue_wdata_o : i2c_rx_desc_queue_wdata_o;
    rx_queue_wvalid_o = sel_i2c_i3c ? i3c_rx_queue_wvalid_o : i2c_rx_queue_wvalid_o;
    rx_queue_wdata_o = sel_i2c_i3c ? i3c_rx_queue_wdata_o : i2c_rx_queue_wdata_o;
    rx_queue_wflush_o = sel_i2c_i3c ? i3c_rx_queue_wflush_o : i2c_rx_queue_wflush_o;
    tx_desc_queue_rready_o = sel_i2c_i3c ? i3c_tx_desc_queue_rready_o : i2c_tx_desc_queue_rready_o;
    tx_queue_rready_o = sel_i2c_i3c ? i3c_tx_queue_rready_o : i2c_tx_queue_rready_o;
    bus_start_o = sel_i2c_i3c ? i3c_bus_start_o : i2c_bus_start_o;
    bus_rstart_o = sel_i2c_i3c ? i3c_bus_rstart_o : i2c_bus_rstart_o;
    bus_stop_o = sel_i2c_i3c ? i3c_bus_stop_o : i2c_bus_stop_o;
    bus_addr_o = sel_i2c_i3c ? i3c_bus_addr_o : i2c_bus_addr_o;
    bus_addr_valid_o = sel_i2c_i3c ? i3c_bus_addr_valid_o : i2c_bus_addr_valid_o;

    // Connect IBI only in I3C mode
    i3c_ibi_queue_full_i = sel_i2c_i3c ? ibi_queue_full_i : '0;
    i3c_ibi_queue_empty_i = sel_i2c_i3c ? ibi_queue_empty_i : '0;
    i3c_ibi_queue_rvalid_i = sel_i2c_i3c ? ibi_queue_rvalid_i : '0;
    ibi_queue_rready_o = sel_i2c_i3c ? i3c_ibi_queue_rready_o : '0;

    tx_host_nack_o = sel_i2c_i3c ? i3c_tx_host_nack_o : i2c_tx_host_nack_o;
  end

  controller_standby_i2c #(
      .TtiRxDescDataWidth(TtiRxDescDataWidth),
      .TtiTxDescDataWidth(TtiTxDescDataWidth),
      .TtiRxDataWidth(TtiRxDataWidth),
      .TtiTxDataWidth(TtiTxDataWidth),
      .TtiRxDescThldWidth(TtiRxDescThldWidth),
      .TtiTxDescThldWidth(TtiTxDescThldWidth),
      .TtiRxThldWidth(TtiRxThldWidth),
      .TtiTxThldWidth(TtiTxThldWidth)
  ) xcontroller_standby_i2c (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .ctrl_scl_i(ctrl_scl_i[0]),
      .ctrl_sda_i(ctrl_sda_i[0]),
      .ctrl_scl_o(ctrl_scl_o[0]),
      .ctrl_sda_o(ctrl_sda_o[0]),
      .phy_sel_od_pp_o(phy_sel_od_pp_o[0]),
      .rx_desc_queue_full_i(rx_desc_queue_full_i),
      .rx_desc_queue_ready_thld_i(rx_desc_queue_ready_thld_i),
      .rx_desc_queue_ready_thld_trig_i(rx_desc_queue_ready_thld_trig_i),
      .rx_desc_queue_empty_i(rx_desc_queue_empty_i),
      .rx_desc_queue_wvalid_o(i2c_rx_desc_queue_wvalid_o),
      .rx_desc_queue_wready_i(rx_desc_queue_wready_i),
      .rx_desc_queue_wdata_o(i2c_rx_desc_queue_wdata_o),
      .tx_desc_queue_full_i(tx_desc_queue_full_i),
      .tx_desc_queue_ready_thld_i(tx_desc_queue_ready_thld_i),
      .tx_desc_queue_ready_thld_trig_i(tx_desc_queue_ready_thld_trig_i),
      .tx_desc_queue_empty_i(tx_desc_queue_empty_i),
      .tx_desc_queue_rvalid_i(tx_desc_queue_rvalid_i),
      .tx_desc_queue_rready_o(i2c_tx_desc_queue_rready_o),
      .tx_desc_queue_rdata_i(tx_desc_queue_rdata_i),
      .rx_queue_full_i(rx_queue_full_i),
      .rx_queue_start_thld_i(rx_queue_start_thld_i),
      .rx_queue_start_thld_trig_i(rx_queue_start_thld_trig_i),
      .rx_queue_ready_thld_i(rx_queue_ready_thld_i),
      .rx_queue_ready_thld_trig_i(rx_queue_ready_thld_trig_i),
      .rx_queue_empty_i(rx_queue_empty_i),
      .rx_queue_wvalid_o(i2c_rx_queue_wvalid_o),
      .rx_queue_wready_i(rx_queue_wready_i),
      .rx_queue_wdata_o(i2c_rx_queue_wdata_o),
      //      .rx_queue_wflush_o(i2c_rx_queue_wflush_o), // TODO: Add flush support for I2C
      .tx_queue_full_i(tx_queue_full_i),
      .tx_queue_start_thld_i(tx_queue_start_thld_i),
      .tx_queue_start_thld_trig_i(tx_queue_start_thld_trig_i),
      .tx_queue_ready_thld_i(tx_queue_ready_thld_i),
      .tx_queue_ready_thld_trig_i(tx_queue_ready_thld_trig_i),
      .tx_queue_empty_i(tx_queue_empty_i),
      .tx_queue_rvalid_i(tx_queue_rvalid_i),
      .tx_queue_rready_o(i2c_tx_queue_rready_o),
      .tx_queue_rdata_i(tx_queue_rdata_i),
      .bus_start_o(i2c_bus_start_o),
      .bus_rstart_o(i2c_bus_rstart_o),
      .bus_stop_o(i2c_bus_stop_o),
      .bus_addr_o(i2c_bus_addr_o),
      .bus_addr_valid_o(i2c_bus_addr_valid_o),
      .phy_en_i(phy_en_i),
      .phy_mux_select_i(phy_mux_select_i),
      .i2c_active_en_i(i2c_active_en_i),
      .i2c_standby_en_i(i2c_standby_en_i),
      .i3c_active_en_i(i3c_active_en_i),
      .i3c_standby_en_i(i3c_standby_en_i),
      .t_hd_dat_i(t_hd_dat_i),
      .t_r_i(t_r_i),
      .t_bus_free_i(t_bus_free_i),
      .t_bus_idle_i(t_bus_idle_i),
      .t_bus_available_i(t_bus_available_i),
      .tx_host_nack_o(i2c_tx_host_nack_o)
  );


  controller_standby_i3c #(
      .TtiRxDescDataWidth(TtiRxDescDataWidth),
      .TtiTxDescDataWidth(TtiTxDescDataWidth),
      .TtiRxDataWidth(TtiRxDataWidth),
      .TtiTxDataWidth(TtiTxDataWidth),
      .TtiRxDescThldWidth(TtiRxDescThldWidth),
      .TtiTxDescThldWidth(TtiTxDescThldWidth),
      .TtiRxThldWidth(TtiRxThldWidth),
      .TtiTxThldWidth(TtiTxThldWidth)
  ) xcontroller_standby_i3c (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .ctrl_scl_i(ctrl_scl_i[1]),
      .ctrl_sda_i(ctrl_sda_i[1]),
      .ctrl_scl_o(ctrl_scl_o[1]),
      .ctrl_sda_o(ctrl_sda_o[1]),
      .phy_sel_od_pp_o(phy_sel_od_pp_o[1]),
      .rx_desc_queue_full_i(rx_desc_queue_full_i),
      .rx_desc_queue_ready_thld_i(rx_desc_queue_ready_thld_i),
      .rx_desc_queue_ready_thld_trig_i(rx_desc_queue_ready_thld_trig_i),
      .rx_desc_queue_empty_i(rx_desc_queue_empty_i),
      .rx_desc_queue_wvalid_o(i3c_rx_desc_queue_wvalid_o),
      .rx_desc_queue_wready_i(rx_desc_queue_wready_i),
      .rx_desc_queue_wdata_o(i3c_rx_desc_queue_wdata_o),
      .rx_queue_full_i(rx_queue_full_i),
      .rx_queue_start_thld_i(rx_queue_start_thld_i),
      .rx_queue_start_thld_trig_i(rx_queue_start_thld_trig_i),
      .rx_queue_ready_thld_i(rx_queue_ready_thld_i),
      .rx_queue_ready_thld_trig_i(rx_queue_ready_thld_trig_i),
      .rx_queue_empty_i(rx_queue_empty_i),
      .rx_queue_wvalid_o(i3c_rx_queue_wvalid_o),
      .rx_queue_wready_i(rx_queue_wready_i),
      .rx_queue_wdata_o(i3c_rx_queue_wdata_o),
      .rx_queue_wflush_o(i3c_rx_queue_wflush_o),
      .tx_desc_queue_full_i(tx_desc_queue_full_i),
      .tx_desc_queue_ready_thld_i(tx_desc_queue_ready_thld_i),
      .tx_desc_queue_ready_thld_trig_i(tx_desc_queue_ready_thld_trig_i),
      .tx_desc_queue_empty_i(tx_desc_queue_empty_i),
      .tx_desc_queue_rvalid_i(tx_desc_queue_rvalid_i),
      .tx_desc_queue_rready_o(i3c_tx_desc_queue_rready_o),
      .tx_desc_queue_rdata_i(tx_desc_queue_rdata_i),
      .tx_queue_full_i(tx_queue_full_i),
      .tx_queue_start_thld_i(tx_queue_start_thld_i),
      .tx_queue_start_thld_trig_i(tx_queue_start_thld_trig_i),
      .tx_queue_ready_thld_i(tx_queue_ready_thld_i),
      .tx_queue_ready_thld_trig_i(tx_queue_ready_thld_trig_i),
      .tx_queue_empty_i(tx_queue_empty_i),
      .tx_queue_rvalid_i(tx_queue_rvalid_i),
      .tx_queue_rready_o(i3c_tx_queue_rready_o),
      .tx_queue_rdata_i(tx_queue_rdata_i),
      .ibi_queue_full_i(i3c_ibi_queue_full_i),
      .ibi_queue_empty_i(i3c_ibi_queue_empty_i),
      .ibi_queue_rvalid_i(i3c_ibi_queue_rvalid_i),
      .ibi_queue_rready_o(i3c_ibi_queue_rready_o),
      .ibi_queue_rdata_i(ibi_queue_rdata_i),
      .bus_start_o(i3c_bus_start_o),
      .bus_rstart_o(i3c_bus_rstart_o),
      .bus_stop_o(i3c_bus_stop_o),
      .bus_addr_o(i3c_bus_addr_o),
      .bus_addr_valid_o(i3c_bus_addr_valid_o),
      .phy_en_i(phy_en_i),
      .phy_mux_select_i(phy_mux_select_i),
      .i2c_active_en_i(i2c_active_en_i),
      .i2c_standby_en_i(i2c_standby_en_i),
      .i3c_active_en_i(i3c_active_en_i),
      .i3c_standby_en_i(i3c_standby_en_i),
      .t_su_dat_i(t_su_dat_i),
      .t_hd_dat_i(t_hd_dat_i),
      .t_r_i(t_r_i),
      .t_f_i(t_f_i),
      .t_bus_free_i(t_bus_free_i),
      .t_bus_idle_i(t_bus_idle_i),
      .t_bus_available_i(t_bus_available_i),
      .rst_action_o(rst_action_o),
      .tx_host_nack_o(i3c_tx_host_nack_o)
  );

endmodule
