// SPDX-License-Identifier: Apache-2.0

// TODO: Consider arbitration difference from i2c:
// Section 5.1.4
// 48b provisioned id and bcr, dcr are used.
// This is to enable dynamic addressing.
module controller_flow_active
  import controller_pkg::*;
  import i3c_pkg::*;
#(
    parameter int unsigned DatAw = i3c_pkg::DatAw,
    parameter int unsigned DctAw = i3c_pkg::DctAw

`ifdef CONTROLLER_SUPPORT,
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
`endif  // CONTROLLER_SUPPORT
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

`ifdef CONTROLLER_SUPPORT
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

`endif  // CONTROLLER_SUPPORT


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

    // Status update signals
    output logic [1:0] ibi_status_o,
    output logic ibi_status_we_o,

    output logic [7:0] rst_action_o,
    output logic       rst_action_valid_o,
    output logic [6:0] set_dasa_o,
    output logic       set_dasa_valid_o,
    output logic       set_dasa_virtual_device_o,
    output logic       set_aasa_o,
    output logic       set_aasa_virt_o,
    output logic       set_newda_o,
    output logic       set_newda_virtual_device_o,
    output logic [6:0] newda_o,
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
    output logic virtual_device_sel_o,
    output logic xfer_in_progress_o
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
  logic [7:0] get_ibil;
  logic [15:0] get_status_fmt1;
  logic [47:0] pid;
  logic [7:0] bcr;
  logic [7:0] dcr;
  logic [47:0] virtual_pid;
  logic [7:0] virtual_bcr;
  logic [7:0] virtual_dcr;
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
  logic set_mwl, set_mrl, set_ibil;
  logic [15:0] mwl, mrl;
  logic [7:0] ibil;

  logic ibi_enable;
  logic [2:0] ibi_retry_num;

  localparam int unsigned RecoveryMode = 'h3;

  configuration xconfiguration (
      .clk_i                          (clk_i),
      .rst_ni                         (rst_ni),
      .hwif_out_i                     (hwif_out_i),
      .phy_en_o                       (phy_en),
      .phy_mux_select_o               (phy_mux_select),
      .i2c_active_en_o                (i2c_active_en),
      .i2c_standby_en_o               (i2c_standby_en),
      .i3c_active_en_o                (i3c_active_en),
      .i3c_standby_en_o               (i3c_standby_en),
      .t_su_dat_o                     (t_su_dat),
      .t_hd_dat_o                     (t_hd_dat),
      .t_r_o                          (t_r),
      .t_f_o                          (t_f),
      .t_bus_free_o                   (t_bus_free),
      .t_bus_idle_o                   (t_bus_idle),
      .t_bus_available_o              (t_bus_available),
      .get_mwl_o                      (get_mwl),
      .get_mrl_o                      (get_mrl),
      .get_ibil_o                     (get_ibil),
      .get_status_fmt1_o              (get_status_fmt1),
      .pid_o                          (pid),
      .bcr_o                          (bcr),
      .dcr_o                          (dcr),
      .virtual_pid_o                  (virtual_pid),
      .virtual_bcr_o                  (virtual_bcr),
      .virtual_dcr_o                  (virtual_dcr),
      .target_sta_addr_o              (target_sta_addr),
      .target_sta_addr_valid_o        (target_sta_addr_valid),
      .target_dyn_addr_o              (target_dyn_addr),
      .target_dyn_addr_valid_o        (target_dyn_addr_valid),
      .virtual_target_sta_addr_o      (virtual_target_sta_addr),
      .virtual_target_sta_addr_valid_o(virtual_target_sta_addr_valid),
      .virtual_target_dyn_addr_o      (virtual_target_dyn_addr),
      .virtual_target_dyn_addr_valid_o(virtual_target_dyn_addr_valid),
      .target_ibi_addr_o              (target_ibi_addr),
      .target_ibi_addr_valid_o        (target_ibi_addr_valid),
      .target_hot_join_addr_o         (target_hot_join_addr),
      .daa_unique_response_o          (daa_unique_response),
      .ibi_enable_o                   (ibi_enable),
      .ibi_retry_num_o                (ibi_retry_num),
      .set_mwl_i                      (set_mwl),
      .set_mrl_i                      (set_mrl),
      .set_ibil_i                     (set_ibil),
      .mwl_i                          (mwl),
      .mrl_i                          (mrl),
      .ibil_i                         (ibil)
  );  //

`ifdef CONTROLLER_SUPPORT
  // Active controller
  logic
      unused_i3c_fsm_idle,
      unused_bus_start,
      unused_bus_rstart,
      unused_bus_stop,
      unused_bus_scl_posedge;
  i3c_err_t unused_err;
  i3c_irq_t unused_irq;
  controller_active_flow_active xcontroller_active_flow_active (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .fmt_fifo_rvalid_o(fmt_fifo_rvalid_o),
      .fmt_fifo_depth_o(fmt_fifo_depth_o),
      .fmt_fifo_rready_i(fmt_fifo_rready_i),
      .fmt_fifo_rdone_i(fmt_fifo_rdone_i),
      .fmt_byte_o(fmt_byte_o),
      .fmt_flag_start_before_o(fmt_flag_start_before_o),
      .fmt_flag_stop_after_o(fmt_flag_stop_after_o),
      .fmt_flag_read_bytes_o(fmt_flag_read_bytes_o),
      .fmt_flag_read_continue_o(fmt_flag_read_continue_o),
      .fmt_flag_nak_ok_o(fmt_flag_nak_ok_o),
      .unhandled_unexp_nak_o(unhandled_unexp_nak_o),
      .unhandled_nak_timeout_o(unhandled_nak_timeout_o),
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
      .i2c_active_en_i(i2c_active_en),
      .i2c_standby_en_i(i2c_standby_en),
      .i3c_active_en_i(1'b1),
      .i3c_fsm_en_i(1'b0),
      .i3c_fsm_idle_o(unused_i3c_fsm_idle),
      .i3c_standby_en_i(i3c_standby_en),
      .t_hd_dat_i(t_hd_dat),
      .t_r_i(t_r),
      .t_f_i(t_f),
      .t_bus_free_i(t_bus_free),
      .t_bus_idle_i(t_bus_idle),
      .t_bus_available_i(t_bus_available),
      .err(unused_err),
      .irq(unused_irq)
  );
`else
  always_comb begin
    err = '0;
    irq = '0;
  end
`endif  // CONTROLLER_SUPPORT
endmodule
