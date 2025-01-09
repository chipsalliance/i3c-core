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
    parameter int unsigned TtiTxThldWidth = 3,
    parameter int unsigned TtiIbiThldWidth = 8,

    parameter int unsigned TtiRxDescFifoDepth = 64,
    parameter int unsigned TtiTxDescFifoDepth = 64,
    parameter int unsigned TtiRxFifoDepth = 64,
    parameter int unsigned TtiTxFifoDepth = 64,
    parameter int unsigned TtiIbiFifoDepth = 64,

    localparam int unsigned TtiTxDescFifoDepthWidth = $clog2(TtiTxDescFifoDepth + 1),
    localparam int unsigned TtiRxDescFifoDepthWidth = $clog2(TtiRxDescFifoDepth + 1),
    localparam int unsigned TtiTxFifoDepthWidth = $clog2(TtiTxFifoDepth + 1),
    localparam int unsigned TtiRxFifoDepthWidth = $clog2(TtiRxFifoDepth + 1),
    localparam int unsigned TtiIbiFifoDepthWidth = $clog2(TtiIbiFifoDepth + 1)
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
    input logic [TtiRxDescFifoDepthWidth-1:0] rx_desc_queue_depth_i,
    input logic [TtiRxDescThldWidth-1:0] rx_desc_queue_ready_thld_i,
    input logic rx_desc_queue_ready_thld_trig_i,
    input logic rx_desc_queue_empty_i,
    output logic rx_desc_queue_wvalid_o,
    input logic rx_desc_queue_wready_i,
    output logic [TtiRxDescDataWidth-1:0] rx_desc_queue_wdata_o,

    // TTI: TX Descriptor
    input logic tx_desc_queue_full_i,
    input logic [TtiTxDescFifoDepthWidth-1:0] tx_desc_queue_depth_i,
    input logic [TtiTxDescThldWidth-1:0] tx_desc_queue_ready_thld_i,
    input logic tx_desc_queue_ready_thld_trig_i,
    input logic tx_desc_queue_empty_i,
    input logic tx_desc_queue_rvalid_i,
    output logic tx_desc_queue_rready_o,
    input logic [TtiTxDescDataWidth-1:0] tx_desc_queue_rdata_i,

    // TTI: RX Data
    input logic rx_queue_full_i,
    input logic [TtiRxFifoDepthWidth-1:0] rx_queue_depth_i,
    input logic [TtiRxThldWidth-1:0] rx_queue_start_thld_i,
    input logic rx_queue_start_thld_trig_i,
    input logic [TtiRxThldWidth-1:0] rx_queue_ready_thld_i,
    input logic rx_queue_ready_thld_trig_i,
    input logic rx_queue_empty_i,
    output logic rx_queue_wvalid_o,
    input logic rx_queue_wready_i,
    output logic [TtiRxDataWidth-1:0] rx_queue_wdata_o,
    output logic rx_queue_flush_o,

    // TTI: TX Data
    input logic tx_queue_full_i,
    input logic [TtiTxFifoDepthWidth-1:0] tx_queue_depth_i,
    input logic [TtiTxThldWidth-1:0] tx_queue_start_thld_i,
    input logic tx_queue_start_thld_trig_i,
    input logic [TtiTxThldWidth-1:0] tx_queue_ready_thld_i,
    input logic tx_queue_ready_thld_trig_i,
    input logic tx_queue_empty_i,
    input logic tx_queue_rvalid_i,
    output logic tx_queue_rready_o,
    input logic [TtiTxDataWidth-1:0] tx_queue_rdata_i,
    output logic tx_queue_flush_o,

    // TTI: In-band-interrupt queue
    input logic ibi_queue_full_i,
    input logic [TtiIbiFifoDepthWidth-1:0] ibi_queue_depth_i,
    input logic [TtiIbiThldWidth-1:0] ibi_queue_ready_thld_i,
    input logic ibi_queue_ready_thld_trig_i,
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
    input logic [15:0] get_mwl_i,
    input logic [15:0] get_mrl_i,
    input logic [15:0] get_status_fmt1_i,
    input logic [47:0] pid_i,
    input logic [7:0] bcr_i,
    input logic [7:0] dcr_i,
    input logic [6:0] target_sta_addr_i,
    input logic target_sta_addr_valid_i,
    input logic [6:0] target_dyn_addr_i,
    input logic target_dyn_addr_valid_i,
    input logic [6:0] target_ibi_addr_i,
    input logic target_ibi_addr_valid_i,
    input logic [6:0] target_hot_join_addr_i,
    input logic [63:0] daa_unique_response_i,
    input logic ibi_enable_i,
    input logic [2:0] ibi_retry_num_i,

    output logic tx_host_nack_o,
    output logic [7:0] set_dasa_o,
    output logic set_dasa_valid_o,
    output logic rstdaa_o,
    output logic [7:0] rst_action_o,
    output logic rst_action_valid_o,

    output logic enec_ibi_o,
    output logic enec_crr_o,
    output logic enec_hj_o,

    output logic disec_ibi_o,
    output logic disec_crr_o,
    output logic disec_hj_o,

    output logic set_mwl_o,
    output logic set_mrl_o,
    output logic [15:0] mwl_o,
    output logic [15:0] mrl_o,

    output logic [1:0] ibi_status_o,
    output logic ibi_status_we_o,

    output logic peripheral_reset_o,
    input  logic peripheral_reset_done_i,
    output logic escalated_reset_o,

    output logic err_o,
    input  recovery_mode_enter_i
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
  logic i3c_rx_queue_flush_o;
  logic i2c_rx_queue_flush_o;
  logic i3c_tx_desc_queue_rready_o;
  logic i2c_tx_desc_queue_rready_o;
  logic i3c_tx_queue_rready_o;
  logic i2c_tx_queue_rready_o;
  logic i3c_tx_queue_flush_o;
  logic i2c_tx_queue_flush_o;
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
    rx_queue_flush_o = sel_i2c_i3c ? i3c_rx_queue_flush_o : i2c_rx_queue_flush_o;
    tx_desc_queue_rready_o = sel_i2c_i3c ? i3c_tx_desc_queue_rready_o : i2c_tx_desc_queue_rready_o;
    tx_queue_rready_o = sel_i2c_i3c ? i3c_tx_queue_rready_o : i2c_tx_queue_rready_o;
    tx_queue_flush_o = sel_i2c_i3c ? i3c_tx_queue_flush_o : i2c_tx_queue_flush_o;
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

  logic parity_err;
  logic get_status_done;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      err_o <= '0;
    end else begin
      if (parity_err) err_o <= 1'b1;
      if (get_status_done) err_o <= 1'b0;
    end
  end

  assign i2c_rx_queue_flush_o = '0;

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
      //      .rx_queue_flush_o(i2c_rx_queue_flush_o), // TODO: Add flush support for I2C
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
      .pid_i(pid_i),
      .bcr_i(bcr_i),
      .dcr_i(dcr_i),
      .target_sta_addr_i(target_sta_addr_i),
      .target_sta_addr_valid_i(target_sta_addr_valid_i),
      .target_dyn_addr_i(target_dyn_addr_i),
      .target_dyn_addr_valid_i(target_dyn_addr_valid_i),
      .target_ibi_addr_i(target_ibi_addr_i),
      .target_ibi_addr_valid_i(target_ibi_addr_valid_i),
      .target_hot_join_addr_i(target_hot_join_addr_i),
      .daa_unique_response_i(daa_unique_response_i),
      .tx_host_nack_o(i2c_tx_host_nack_o)
  );


  controller_standby_i3c #(
      .TtiRxDescDataWidth(TtiRxDescDataWidth),
      .TtiTxDescDataWidth(TtiTxDescDataWidth),
      .TtiRxDataWidth(TtiRxDataWidth),
      .TtiTxDataWidth(TtiTxDataWidth),
      .TtiIbiFifoDepth(TtiIbiFifoDepth),
      .TtiIbiDataWidth(TtiIbiDataWidth),
      .TtiTxFifoDepth(TtiTxFifoDepth)
  ) xcontroller_standby_i3c (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .ctrl_scl_i(ctrl_scl_i[1]),
      .ctrl_sda_i(ctrl_sda_i[1]),
      .ctrl_scl_o(ctrl_scl_o[1]),
      .ctrl_sda_o(ctrl_sda_o[1]),
      .phy_sel_od_pp_o(phy_sel_od_pp_o[1]),
      .rx_desc_queue_wvalid_o(i3c_rx_desc_queue_wvalid_o),
      .rx_desc_queue_wdata_o(i3c_rx_desc_queue_wdata_o),
      .tx_desc_queue_rvalid_i(tx_desc_queue_rvalid_i),
      .tx_desc_queue_rready_o(i3c_tx_desc_queue_rready_o),
      .tx_desc_queue_rdata_i(tx_desc_queue_rdata_i),
      .rx_queue_full_i(rx_queue_full_i),
      .rx_queue_wvalid_o(i3c_rx_queue_wvalid_o),
      .rx_queue_wdata_o(i3c_rx_queue_wdata_o),
      .rx_queue_flush_o(i3c_rx_queue_flush_o),
      .tx_queue_rvalid_i(tx_queue_rvalid_i),
      .tx_queue_depth_i(tx_queue_depth_i),
      .tx_queue_rready_o(i3c_tx_queue_rready_o),
      .tx_queue_rdata_i(tx_queue_rdata_i),
      .tx_queue_flush_o(i3c_tx_queue_flush_o),
      .ibi_queue_full_i(ibi_queue_full_i),
      .ibi_queue_empty_i(ibi_queue_empty_i),
      .ibi_queue_rvalid_i(ibi_queue_rvalid_i),
      .ibi_queue_depth_i(ibi_queue_depth_i),
      .ibi_queue_rready_o(i3c_ibi_queue_rready_o),
      .ibi_queue_rdata_i(ibi_queue_rdata_i),
      .bus_start_o(i3c_bus_start_o),
      .bus_rstart_o(i3c_bus_rstart_o),
      .bus_stop_o(i3c_bus_stop_o),
      .bus_addr_o(i3c_bus_addr_o),
      .bus_addr_valid_o(i3c_bus_addr_valid_o),
      .i3c_standby_en_i(i3c_standby_en_i),
      .t_su_dat_i(t_su_dat_i),
      .t_hd_dat_i(t_hd_dat_i),
      .t_r_i(t_r_i),
      .t_f_i(t_f_i),
      .t_bus_free_i(t_bus_free_i),
      .t_bus_idle_i(t_bus_idle_i),
      .t_bus_available_i(t_bus_available_i),
      .get_mwl_i(get_mwl_i),
      .get_mrl_i(get_mrl_i),
      .get_status_fmt1_i(get_status_fmt1_i),
      .pid_i(pid_i),
      .bcr_i(bcr_i),
      .dcr_i(dcr_i),
      .target_sta_addr_i(target_sta_addr_i),
      .target_sta_addr_valid_i(target_sta_addr_valid_i),
      .target_dyn_addr_i(target_dyn_addr_i),
      .target_dyn_addr_valid_i(target_dyn_addr_valid_i),
      .target_ibi_addr_i(target_ibi_addr_i),
      .target_ibi_addr_valid_i(target_ibi_addr_valid_i),
      .target_hot_join_addr_i(target_hot_join_addr_i),
      .ibi_enable_i(ibi_enable_i),
      .ibi_retry_num_i(ibi_retry_num_i),
      .daa_unique_response_i(daa_unique_response_i),
      .tx_host_nack_o(i3c_tx_host_nack_o),
      .set_dasa_o(set_dasa_o),
      .set_dasa_valid_o(set_dasa_valid_o),
      .rst_action_o,
      .rst_action_valid_o,
      .enec_ibi_o(enec_ibi_o),
      .enec_crr_o(enec_crr_o),
      .enec_hj_o(enec_hj_o),
      .disec_ibi_o(disec_ibi_o),
      .disec_crr_o(disec_crr_o),
      .disec_hj_o(disec_hj_o),
      .set_mwl_o(set_mwl_o),
      .set_mrl_o(set_mrl_o),
      .mwl_o(mwl_o),
      .mrl_o(mrl_o),
      .rstdaa_o(rstdaa_o),
      .ibi_status_o(ibi_status_o),
      .ibi_status_we_o(ibi_status_we_o),
      .get_status_done_o(get_status_done),
      .parity_err_o(parity_err),
      .peripheral_reset_o,
      .peripheral_reset_done_i,
      .escalated_reset_o,
      .recovery_mode_enter_i(recovery_mode_enter_i)
  );

endmodule
