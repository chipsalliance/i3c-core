// SPDX-License-Identifier: Apache-2.0

// TODO: Consider arbitration difference from i2c:
// Section 5.1.4
// 48b provisioned id and bcr, dcr are used.
// This is to enable dynamic addressing.

module controller
  import controller_pkg::*;
  import i3c_pkg::*;
#(
    parameter int unsigned DatAw = i3c_pkg::DatAw,
    parameter int unsigned DctAw = i3c_pkg::DctAw,

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
    parameter int unsigned HciIbiThldWidth  = 8,

    parameter int unsigned TtiRxDescFifoDepth = 64,
    parameter int unsigned TtiTxDescFifoDepth = 64,
    parameter int unsigned TtiRxFifoDepth = 64,
    parameter int unsigned TtiTxFifoDepth = 64,
    parameter int unsigned TtiIbiFifoDepth = 64,

    localparam int unsigned TtiRxDescFifoDepthWidth = $clog2(TtiRxDescFifoDepth + 1),
    localparam int unsigned TtiTxDescFifoDepthWidth = $clog2(TtiTxDescFifoDepth + 1),
    localparam int unsigned TtiTxFifoDepthWidth = $clog2(TtiTxFifoDepth + 1),
    localparam int unsigned TtiRxFifoDepthWidth = $clog2(TtiRxFifoDepth + 1),
    localparam int unsigned TtiIbiFifoDepthWidth = $clog2(TtiIbiFifoDepth + 1),

    parameter int unsigned TtiRxDescDataWidth = 32,
    parameter int unsigned TtiTxDescDataWidth = 32,
    parameter int unsigned TtiRxDataWidth = 8,
    parameter int unsigned TtiTxDataWidth = 8,
    parameter int unsigned TtiIbiDataWidth = 32,

    parameter int unsigned TtiRxDescThldWidth = 8,
    parameter int unsigned TtiTxDescThldWidth = 8,
    parameter int unsigned TtiRxThldWidth = 3,
    parameter int unsigned TtiTxThldWidth = 3,
    parameter int unsigned TtiIbiThldWidth = 8
) (
    input logic clk_i,
    input logic rst_ni,

    // Interface to SDA/SCL
    input  logic scl_i,
    input  logic sda_i,
    output logic scl_o,
    output logic sda_o,
    output logic sel_od_pp_o,

    // HCI queues
    // Command FIFO
    input logic hci_cmd_queue_full_i,
    input logic [HciCmdFifoDepthWidth-1:0] hci_cmd_queue_depth_i,
    input logic [HciCmdThldWidth-1:0] hci_cmd_queue_ready_thld_i,
    input logic hci_cmd_queue_ready_thld_trig_i,
    input logic hci_cmd_queue_empty_i,
    input logic hci_cmd_queue_rvalid_i,
    output logic hci_cmd_queue_rready_o,
    input logic [HciCmdDataWidth-1:0] hci_cmd_queue_rdata_i,
    // RX FIFO
    input logic hci_rx_queue_full_i,
    input logic [HciRxFifoDepthWidth-1:0] hci_rx_queue_depth_i,
    input logic [HciRxThldWidth-1:0] hci_rx_queue_start_thld_i,
    input logic hci_rx_queue_start_thld_trig_i,
    input logic [HciRxThldWidth-1:0] hci_rx_queue_ready_thld_i,
    input logic hci_rx_queue_ready_thld_trig_i,
    input logic hci_rx_queue_empty_i,
    output logic hci_rx_queue_wvalid_o,
    input logic hci_rx_queue_wready_i,
    output logic [HciRxDataWidth-1:0] hci_rx_queue_wdata_o,
    // TX FIFO
    input logic hci_tx_queue_full_i,
    input logic [HciTxFifoDepthWidth-1:0] hci_tx_queue_depth_i,
    input logic [HciTxThldWidth-1:0] hci_tx_queue_start_thld_i,
    input logic hci_tx_queue_start_thld_trig_i,
    input logic [HciTxThldWidth-1:0] hci_tx_queue_ready_thld_i,
    input logic hci_tx_queue_ready_thld_trig_i,
    input logic hci_tx_queue_empty_i,
    input logic hci_tx_queue_rvalid_i,
    output logic hci_tx_queue_rready_o,
    input logic [HciTxDataWidth-1:0] hci_tx_queue_rdata_i,
    // Response FIFO
    input logic hci_resp_queue_full_i,
    input logic [HciRespFifoDepthWidth-1:0] hci_resp_queue_depth_i,
    input logic [HciRespThldWidth-1:0] hci_resp_queue_ready_thld_i,
    input logic hci_resp_queue_ready_thld_trig_i,
    input logic hci_resp_queue_empty_i,
    output logic hci_resp_queue_wvalid_o,
    input logic hci_resp_queue_wready_i,
    output logic [HciRespDataWidth-1:0] hci_resp_queue_wdata_o,

    // In-band Interrupt queue
    input logic hci_ibi_queue_full_i,
    input logic [HciIbiFifoDepthWidth-1:0] hci_ibi_queue_depth_i,
    input logic [HciIbiThldWidth-1:0] hci_ibi_queue_ready_thld_i,
    input logic hci_ibi_queue_ready_thld_trig_i,
    input logic hci_ibi_queue_empty_i,
    output logic hci_ibi_queue_wvalid_o,
    input logic hci_ibi_queue_wready_i,
    output logic [HciIbiDataWidth-1:0] hci_ibi_queue_wdata_o,

    // Target Transaction Interface

    // TTI: RX Descriptor
    input logic tti_rx_desc_queue_full_i,
    input logic [TtiRxDescFifoDepthWidth-1:0] tti_rx_desc_queue_depth_i,
    input logic [TtiRxDescThldWidth-1:0] tti_rx_desc_queue_ready_thld_i,
    input logic tti_rx_desc_queue_ready_thld_trig_i,
    input logic tti_rx_desc_queue_empty_i,
    output logic tti_rx_desc_queue_wvalid_o,
    input logic tti_rx_desc_queue_wready_i,
    output logic [TtiRxDescDataWidth-1:0] tti_rx_desc_queue_wdata_o,

    // TTI: TX Descriptor
    input logic tti_tx_desc_queue_full_i,
    input logic [TtiTxDescFifoDepthWidth-1:0] tti_tx_desc_queue_depth_i,
    input logic [TtiTxDescThldWidth-1:0] tti_tx_desc_queue_ready_thld_i,
    input logic tti_tx_desc_queue_ready_thld_trig_i,
    input logic tti_tx_desc_queue_empty_i,
    input logic tti_tx_desc_queue_rvalid_i,
    output logic tti_tx_desc_queue_rready_o,
    input logic [TtiTxDescDataWidth-1:0] tti_tx_desc_queue_rdata_i,

    // TTI: RX Data
    input logic tti_rx_queue_full_i,
    input logic [TtiRxFifoDepthWidth-1:0] tti_rx_queue_depth_i,
    input logic [TtiRxThldWidth-1:0] tti_rx_queue_start_thld_i,
    input logic tti_rx_queue_start_thld_trig_i,
    input logic [TtiRxThldWidth-1:0] tti_rx_queue_ready_thld_i,
    input logic tti_rx_queue_ready_thld_trig_i,
    input logic tti_rx_queue_empty_i,
    output logic tti_rx_queue_wvalid_o,
    input logic tti_rx_queue_wready_i,
    output logic [TtiRxDataWidth-1:0] tti_rx_queue_wdata_o,
    output logic tti_rx_queue_flush_o,

    // TTI: TX Data
    input logic tti_tx_queue_full_i,
    input logic [TtiTxFifoDepthWidth-1:0] tti_tx_queue_depth_i,
    input logic [TtiTxThldWidth-1:0] tti_tx_queue_start_thld_i,
    input logic tti_tx_queue_start_thld_trig_i,
    input logic [TtiTxThldWidth-1:0] tti_tx_queue_ready_thld_i,
    input logic tti_tx_queue_ready_thld_trig_i,
    input logic tti_tx_queue_empty_i,
    input logic tti_tx_queue_rvalid_i,
    output logic tti_tx_queue_rready_o,
    output logic tti_tx_queue_flush_o,
    input logic [TtiTxDataWidth-1:0] tti_tx_queue_rdata_i,
    output logic tti_tx_host_nack_o,
    output logic tti_tx_pr_end_o,

    // TTI: In-band Interrupt queue
    input logic tti_ibi_queue_full_i,
    input logic [TtiIbiFifoDepthWidth-1:0] tti_ibi_queue_depth_i,
    input logic [TtiIbiThldWidth-1:0] tti_ibi_queue_ready_thld_i,
    input logic tti_ibi_queue_ready_thld_trig_i,
    input logic tti_ibi_queue_empty_i,
    input logic tti_ibi_queue_rvalid_i,
    output logic tti_ibi_queue_rready_o,
    input logic [TtiIbiDataWidth-1:0] tti_ibi_queue_rdata_i,

    // DAT <-> Controller interface
    output logic             dat_read_valid_hw_o,
    output logic [DatAw-1:0] dat_index_hw_o,
    input  logic [     63:0] dat_rdata_hw_i,

    // DCT <-> Controller interface
    output logic             dct_write_valid_hw_o,
    output logic             dct_read_valid_hw_o,
    output logic [DctAw-1:0] dct_index_hw_o,
    output logic [    127:0] dct_wdata_hw_o,
    input  logic [    127:0] dct_rdata_hw_i,

    // I2C/I3C Bus condition detection
    output logic bus_start_o,
    output logic bus_rstart_o,
    output logic bus_stop_o,

    // I2C/I3C received address (with RnW# bit) for the recovery handler
    output logic [7:0] bus_addr_o,
    output logic bus_addr_valid_o,

    input  logic i3c_fsm_en_i,
    output logic i3c_fsm_idle_o,

    // Errors and Interrupts
    output i3c_err_t err,
    output i3c_irq_t irq,

    // Controller configuration
    input I3CCSR_pkg::I3CCSR__out_t hwif_out_i,
    input I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__out_t hwif_rec_i,

    // Status update signals
    output logic [1:0] ibi_status_o,
    output logic ibi_status_we_o,

    output logic [7:0] rst_action_o,
    output logic       rst_action_valid_o,
    output logic [6:0] set_dasa_o,
    output logic       set_dasa_valid_o,
    output logic       set_dasa_virtual_device_o,
    output logic       rstdaa_o,

    output logic enec_ibi_o,
    output logic enec_crr_o,
    output logic enec_hj_o,

    output logic disec_ibi_o,
    output logic disec_crr_o,
    output logic disec_hj_o,

    output logic peripheral_reset_o,
    input  logic peripheral_reset_done_i,
    output logic escalated_reset_o,

    output logic err_o,
    input  logic recovery_mode_enter_i,
    output logic virtual_device_tx_o,
    input  logic virtual_device_tx_done_i
);

  logic phy_en;
  logic [1:0] phy_mux_select;
  logic i2c_active_en;
  logic i2c_standby_en;
  logic i3c_active_en;
  logic i3c_standby_en;
  logic [19:0] t_su_dat;
  logic [19:0] t_hd_dat;
  logic [19:0] t_r;
  logic [19:0] t_f;
  logic [19:0] t_bus_free;
  logic [19:0] t_bus_idle;
  logic [19:0] t_bus_available;
  logic [15:0] get_mwl;
  logic [15:0] get_mrl;
  logic [15:0] get_status_fmt1;
  logic [47:0] pid;
  logic [7:0] bcr;
  logic [7:0] dcr;
  logic [6:0] target_sta_addr;
  logic target_sta_addr_valid;
  logic [6:0] target_dyn_addr;
  logic target_dyn_addr_valid;
  logic [6:0] virtual_target_sta_addr;
  logic virtual_target_sta_addr_valid;
  logic [6:0] virtual_target_dyn_addr;
  logic virtual_target_dyn_addr_valid;
  logic [6:0] target_ibi_addr;
  logic target_ibi_addr_valid;
  logic [6:0] target_hot_join_addr;
  logic [63:0] daa_unique_response;
  logic set_mwl, set_mrl;
  logic [15:0] mwl, mrl;

  logic ibi_enable;
  logic [2:0] ibi_retry_num;

  logic recovery_mode;
  // 4:1 multiplexer for signals between PHY and controllers.
  // Needed, because there are 4 controllers in the design (i2c/i3c + active/standby).
  logic ctrl_scl_i[4];
  logic ctrl_sda_i[4];
  logic ctrl_scl_o[4];
  logic ctrl_sda_o[4];
  logic ctrl_sel_od_pp_i[4];

  localparam int unsigned RecoveryMode = 'h3;
  always_comb begin : mux_4_to_1
    scl_o = ctrl_scl_o[phy_mux_select];
    sda_o = ctrl_sda_o[phy_mux_select];
    ctrl_scl_i[phy_mux_select] = '0;
    ctrl_sda_i[phy_mux_select] = '0;
    ctrl_scl_i[phy_mux_select] = scl_i;
    ctrl_sda_i[phy_mux_select] = sda_i;
    sel_od_pp_o = ctrl_sel_od_pp_i[phy_mux_select];
    recovery_mode = (hwif_rec_i.DEVICE_STATUS_0.PLACEHOLDER.value[7:0] == RecoveryMode);
    end

  configuration xconfiguration (
      .clk_i                           (clk_i),
      .rst_ni                          (rst_ni),
      .hwif_out_i                      (hwif_out_i),
      .phy_en_o                        (phy_en),
      .phy_mux_select_o                (phy_mux_select),
      .i2c_active_en_o                 (i2c_active_en),
      .i2c_standby_en_o                (i2c_standby_en),
      .i3c_active_en_o                 (i3c_active_en),
      .i3c_standby_en_o                (i3c_standby_en),
      .t_su_dat_o                      (t_su_dat),
      .t_hd_dat_o                      (t_hd_dat),
      .t_r_o                           (t_r),
      .t_f_o                           (t_f),
      .t_bus_free_o                    (t_bus_free),
      .t_bus_idle_o                    (t_bus_idle),
      .t_bus_available_o               (t_bus_available),
      .get_mwl_o                       (get_mwl),
      .get_mrl_o                       (get_mrl),
      .get_status_fmt1_o               (get_status_fmt1),
      .pid_o                           (pid),
      .bcr_o                           (bcr),
      .dcr_o                           (dcr),
      .target_sta_addr_o               (target_sta_addr),
      .target_sta_addr_valid_o         (target_sta_addr_valid),
      .target_dyn_addr_o               (target_dyn_addr),
      .target_dyn_addr_valid_o         (target_dyn_addr_valid),
      .virtual_target_sta_addr_o       (virtual_target_sta_addr),
      .virtual_target_sta_addr_valid_o (virtual_target_sta_addr_valid),
      .virtual_target_dyn_addr_o       (virtual_target_dyn_addr),
      .virtual_target_dyn_addr_valid_o (virtual_target_dyn_addr_valid),
      .target_ibi_addr_o               (target_ibi_addr),
      .target_ibi_addr_valid_o         (target_ibi_addr_valid),
      .target_hot_join_addr_o          (target_hot_join_addr),
      .daa_unique_response_o           (daa_unique_response),
      .ibi_enable_o                    (ibi_enable),
      .ibi_retry_num_o                 (ibi_retry_num),
      .set_mwl_i                       (set_mwl),
      .set_mrl_i                       (set_mrl),
      .mwl_i                           (mwl),
      .mrl_i                           (mrl)
  );


  // Active controller
  controller_active xcontroller_active (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .ctrl_scl_i(ctrl_scl_i[0:1]),
      .ctrl_sda_i(ctrl_sda_i[0:1]),
      .ctrl_scl_o(ctrl_scl_o[0:1]),
      .ctrl_sda_o(ctrl_sda_o[0:1]),
      .phy_sel_od_pp_o(ctrl_sel_od_pp_i[0:1]),
      .cmd_queue_full_i(hci_cmd_queue_full_i),
      .cmd_queue_depth_i(hci_cmd_queue_depth_i),
      .cmd_queue_ready_thld_i(hci_cmd_queue_ready_thld_i),
      .cmd_queue_ready_thld_trig_i(hci_cmd_queue_ready_thld_trig_i),
      .cmd_queue_empty_i(hci_cmd_queue_empty_i),
      .cmd_queue_rvalid_i(hci_cmd_queue_rvalid_i),
      .cmd_queue_rready_o(hci_cmd_queue_rready_o),
      .cmd_queue_rdata_i(hci_cmd_queue_rdata_i),
      .rx_queue_full_i(hci_rx_queue_full_i),
      .rx_queue_depth_i(hci_rx_queue_depth_i),
      .rx_queue_start_thld_i(hci_rx_queue_start_thld_i),
      .rx_queue_start_thld_trig_i(hci_rx_queue_start_thld_trig_i),
      .rx_queue_ready_thld_i(hci_rx_queue_ready_thld_i),
      .rx_queue_ready_thld_trig_i(hci_rx_queue_ready_thld_trig_i),
      .rx_queue_empty_i(hci_rx_queue_empty_i),
      .rx_queue_wvalid_o(hci_rx_queue_wvalid_o),
      .rx_queue_wready_i(hci_rx_queue_wready_i),
      .rx_queue_wdata_o(hci_rx_queue_wdata_o),
      .tx_queue_full_i(hci_tx_queue_full_i),
      .tx_queue_depth_i(hci_tx_queue_depth_i),
      .tx_queue_start_thld_i(hci_tx_queue_start_thld_i),
      .tx_queue_start_thld_trig_i(hci_tx_queue_start_thld_trig_i),
      .tx_queue_ready_thld_i(hci_tx_queue_ready_thld_i),
      .tx_queue_ready_thld_trig_i(hci_tx_queue_ready_thld_trig_i),
      .tx_queue_empty_i(hci_tx_queue_empty_i),
      .tx_queue_rvalid_i(hci_tx_queue_rvalid_i),
      .tx_queue_rready_o(hci_tx_queue_rready_o),
      .tx_queue_rdata_i(hci_tx_queue_rdata_i),
      .resp_queue_full_i(hci_resp_queue_full_i),
      .resp_queue_depth_i(hci_resp_queue_depth_i),
      .resp_queue_ready_thld_i(hci_resp_queue_ready_thld_i),
      .resp_queue_ready_thld_trig_i(hci_resp_queue_ready_thld_trig_i),
      .resp_queue_empty_i(hci_resp_queue_empty_i),
      .resp_queue_wvalid_o(hci_resp_queue_wvalid_o),
      .resp_queue_wready_i(hci_resp_queue_wready_i),
      .resp_queue_wdata_o(hci_resp_queue_wdata_o),
      .ibi_queue_full_i(hci_ibi_queue_full_i),
      .ibi_queue_depth_i(hci_ibi_queue_depth_i),
      .ibi_queue_ready_thld_i(hci_ibi_queue_ready_thld_i),
      .ibi_queue_ready_thld_trig_i(hci_ibi_queue_ready_thld_trig_i),
      .ibi_queue_empty_i(hci_ibi_queue_empty_i),
      .ibi_queue_wvalid_o(hci_ibi_queue_wvalid_o),
      .ibi_queue_wready_i(hci_ibi_queue_wready_i),
      .ibi_queue_wdata_o(hci_ibi_queue_wdata_o),
      .dat_read_valid_hw_o(dat_read_valid_hw_o),
      .dat_index_hw_o(dat_index_hw_o),
      .dat_rdata_hw_i(dat_rdata_hw_i),
      .dct_write_valid_hw_o(dct_write_valid_hw_o),
      .dct_read_valid_hw_o(dct_read_valid_hw_o),
      .dct_index_hw_o(dct_index_hw_o),
      .dct_wdata_hw_o(dct_wdata_hw_o),
      .dct_rdata_hw_i(dct_rdata_hw_i),
      .i3c_fsm_en_i(i3c_fsm_en_i),
      .i3c_fsm_idle_o(i3c_fsm_idle_o),
      .err(err),
      .irq(irq),
      .phy_en_i(phy_en),
      .phy_mux_select_i(phy_mux_select),
      .i2c_active_en_i(i2c_active_en),
      .i2c_standby_en_i(i2c_standby_en),
      .i3c_active_en_i(i3c_active_en),
      .i3c_standby_en_i(i3c_standby_en),
      .t_hd_dat_i(t_hd_dat),
      .t_r_i(t_r),
      .t_f_i(t_f),
      .t_bus_free_i(t_bus_free),
      .t_bus_idle_i(t_bus_idle),
      .t_bus_available_i(t_bus_available)
  );

  // Standby (Secondary) Controller
  controller_standby xcontroller_standby (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .ctrl_scl_i(ctrl_scl_i[2:3]),
      .ctrl_sda_i(ctrl_sda_i[2:3]),
      .ctrl_scl_o(ctrl_scl_o[2:3]),
      .ctrl_sda_o(ctrl_sda_o[2:3]),
      .phy_sel_od_pp_o(ctrl_sel_od_pp_i[2:3]),
      .rx_desc_queue_full_i(tti_rx_desc_queue_full_i),
      .rx_desc_queue_depth_i(tti_rx_desc_queue_depth_i),
      .rx_desc_queue_ready_thld_i(tti_rx_desc_queue_ready_thld_i),
      .rx_desc_queue_ready_thld_trig_i(tti_rx_desc_queue_ready_thld_trig_i),
      .rx_desc_queue_empty_i(tti_rx_desc_queue_empty_i),
      .rx_desc_queue_wvalid_o(tti_rx_desc_queue_wvalid_o),
      .rx_desc_queue_wready_i(tti_rx_desc_queue_wready_i),
      .rx_desc_queue_wdata_o(tti_rx_desc_queue_wdata_o),
      .tx_desc_queue_full_i(tti_tx_desc_queue_full_i),
      .tx_desc_queue_depth_i(tti_tx_desc_queue_depth_i),
      .tx_desc_queue_ready_thld_i(tti_tx_desc_queue_ready_thld_i),
      .tx_desc_queue_ready_thld_trig_i(tti_tx_desc_queue_ready_thld_trig_i),
      .tx_desc_queue_empty_i(tti_tx_desc_queue_empty_i),
      .tx_desc_queue_rvalid_i(tti_tx_desc_queue_rvalid_i),
      .tx_desc_queue_rready_o(tti_tx_desc_queue_rready_o),
      .tx_desc_queue_rdata_i(tti_tx_desc_queue_rdata_i),
      .rx_queue_full_i(tti_rx_queue_full_i),
      .rx_queue_depth_i(tti_rx_queue_depth_i),
      .rx_queue_start_thld_i(tti_rx_queue_start_thld_i),
      .rx_queue_start_thld_trig_i(tti_rx_queue_start_thld_trig_i),
      .rx_queue_ready_thld_i(tti_rx_queue_ready_thld_i),
      .rx_queue_ready_thld_trig_i(tti_rx_queue_ready_thld_trig_i),
      .rx_queue_empty_i(tti_rx_queue_empty_i),
      .rx_queue_wvalid_o(tti_rx_queue_wvalid_o),
      .rx_queue_wready_i(tti_rx_queue_wready_i),
      .rx_queue_wdata_o(tti_rx_queue_wdata_o),
      .rx_queue_flush_o(tti_rx_queue_flush_o),
      .tx_queue_full_i(tti_tx_queue_full_i),
      .tx_queue_depth_i(tti_tx_queue_depth_i),
      .tx_queue_start_thld_i(tti_tx_queue_start_thld_i),
      .tx_queue_start_thld_trig_i(tti_tx_queue_start_thld_trig_i),
      .tx_queue_ready_thld_i(tti_tx_queue_ready_thld_i),
      .tx_queue_ready_thld_trig_i(tti_tx_queue_ready_thld_trig_i),
      .tx_queue_empty_i(tti_tx_queue_empty_i),
      .tx_queue_rvalid_i(tti_tx_queue_rvalid_i),
      .tx_queue_rready_o(tti_tx_queue_rready_o),
      .tx_queue_rdata_i(tti_tx_queue_rdata_i),
      .tx_queue_flush_o(tti_tx_queue_flush_o),
      .bus_start_o(bus_start_o),
      .bus_rstart_o(bus_rstart_o),
      .bus_stop_o(bus_stop_o),
      .bus_addr_o(bus_addr_o),
      .bus_addr_valid_o(bus_addr_valid_o),
      .ibi_queue_full_i(tti_ibi_queue_full_i),
      .ibi_queue_depth_i(tti_ibi_queue_depth_i),
      .ibi_queue_ready_thld_i(tti_ibi_queue_ready_thld_i),
      .ibi_queue_ready_thld_trig_i(tti_ibi_queue_ready_thld_trig_i),
      .ibi_queue_empty_i(tti_ibi_queue_empty_i),
      .ibi_queue_rvalid_i(tti_ibi_queue_rvalid_i),
      .ibi_queue_rready_o(tti_ibi_queue_rready_o),
      .ibi_queue_rdata_i(tti_ibi_queue_rdata_i),
      .phy_en_i(phy_en),
      .phy_mux_select_i(phy_mux_select),
      .i2c_active_en_i(i2c_active_en),
      .i2c_standby_en_i(i2c_standby_en),
      .i3c_active_en_i(i3c_active_en),
      .i3c_standby_en_i(i3c_standby_en),
      .t_su_dat_i(t_su_dat),
      .t_hd_dat_i(t_hd_dat),
      .t_r_i(t_r),
      .t_f_i(t_f),
      .t_bus_free_i(t_bus_free),
      .t_bus_idle_i(t_bus_idle),
      .t_bus_available_i(t_bus_available),
      .get_mwl_i(get_mwl),
      .get_mrl_i(get_mrl),
      .get_status_fmt1_i(get_status_fmt1),
      .pid_i(pid),
      .bcr_i(bcr),
      .dcr_i(dcr),
      .target_sta_addr_i(target_sta_addr),
      .target_sta_addr_valid_i(target_sta_addr_valid),
      .target_dyn_addr_i(target_dyn_addr),
      .target_dyn_addr_valid_i(target_dyn_addr_valid),
      .virtual_target_sta_addr_i(virtual_target_sta_addr),
      .virtual_target_sta_addr_valid_i(virtual_target_sta_addr_valid),
      .virtual_target_dyn_addr_i(virtual_target_dyn_addr),
      .virtual_target_dyn_addr_valid_i(virtual_target_dyn_addr_valid),
      .target_ibi_addr_i(target_ibi_addr),
      .target_ibi_addr_valid_i(target_ibi_addr_valid),
      .target_hot_join_addr_i(target_hot_join_addr),
      .ibi_enable_i(ibi_enable),
      .ibi_retry_num_i(ibi_retry_num),
      .daa_unique_response_i(daa_unique_response),
      .tx_host_nack_o(tti_tx_host_nack_o),
      .tx_pr_end_o(tti_tx_pr_end_o),
      .set_dasa_o(set_dasa_o),
      .set_dasa_valid_o(set_dasa_valid_o),
      .set_dasa_virtual_device_o(set_dasa_virtual_device_o),
      .rstdaa_o(rstdaa_o),
      .rst_action_o,
      .rst_action_valid_o,
      .enec_ibi_o(enec_ibi_o),
      .enec_crr_o(enec_crr_o),
      .enec_hj_o(enec_hj_o),
      .disec_ibi_o(disec_ibi_o),
      .disec_crr_o(disec_crr_o),
      .disec_hj_o(disec_hj_o),
      .ibi_status_o(ibi_status_o),
      .ibi_status_we_o(ibi_status_we_o),
      .err_o,
      .set_mwl_o(set_mwl),
      .set_mrl_o(set_mrl),
      .mwl_o(mwl),
      .mrl_o(mrl),
      .peripheral_reset_o,
      .peripheral_reset_done_i,
      .escalated_reset_o,
      .recovery_mode_enter_i(recovery_mode_enter_i),
      .virtual_device_tx_o(virtual_device_tx_o),
      .virtual_device_tx_done_i(virtual_device_tx_done_i),
      .recovery_mode_i(recovery_mode)
  );

endmodule
