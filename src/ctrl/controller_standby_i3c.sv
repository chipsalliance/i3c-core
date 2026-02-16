// SPDX-License-Identifier: Apache-2.0

module controller_standby_i3c
  import controller_pkg::*;
  import i3c_pkg::*;
#(
  parameter  int unsigned TtiRxDescDataWidth = 32,
  parameter  int unsigned TtiTxDescDataWidth = 32,
  parameter  int unsigned TtiRxDataWidth = 8,
  parameter  int unsigned TtiTxDataWidth = 8,
  parameter  int unsigned TtiTxFifoDepth = 16,
  localparam int unsigned TtiTxFifoDepthWidth = $clog2(TtiTxFifoDepth + 1),
  parameter  int unsigned TtiIbiFifoDepth = 16,
  localparam int unsigned TtiIbiFifoDepthWidth = $clog2(TtiIbiFifoDepth + 1),
  parameter  int unsigned TtiIbiDataWidth = 32
) (
  input  logic clk_i,
  input  logic rst_ni,

  input  logic i3c_standby_en_i,

  // Interface to/from SDA/SCL
  input  bus_state_t ctrl_bus_i,
  // Ungated bus state for HDR exit pattern detection
  input  bus_state_t hdr_exit_bus_i,
  output logic       ctrl_scl_o,
  output logic       ctrl_sda_o,
  output logic       ctrl_sda_oe_o,
  output logic       phy_sel_od_pp_o,
  input  logic       arbitration_lost_i,

  // Target Transaction Interface

  // TTI: RX Descriptor
  output logic                          rx_desc_queue_wvalid_o,
  output logic [TtiRxDescDataWidth-1:0] rx_desc_queue_wdata_o,

  // TTI: TX Descriptor
  input  logic                          tx_desc_queue_rvalid_i,
  output logic                          tx_desc_queue_rready_o,
  input  logic [TtiTxDescDataWidth-1:0] tx_desc_queue_rdata_i,

  // TTI: RX Data
  output logic                      rx_queue_wvalid_o,
  input  logic                      rx_queue_wready_i,
  output logic                      rx_queue_flush_o,
  output logic                      rx_queue_wlast_o,
  output logic [TtiRxDataWidth-1:0] rx_queue_wdata_o,

  // TTI: TX Data
  input  logic                           tx_queue_rvalid_i,
  output logic                           tx_queue_rready_o,
  input  logic                           tx_queue_empty_i,
  output logic                           tx_queue_flush_o,
  input  logic [TtiTxFifoDepthWidth-1:0] tx_queue_depth_i,
  input  logic      [TtiTxDataWidth-1:0] tx_queue_rdata_i,  

  // TTI: In-band-interrupt queue
  input  logic                            ibi_queue_rvalid_i,
  output logic                            ibi_queue_rready_o,
  input  logic                            ibi_queue_empty_i,
  input  logic                            ibi_queue_full_i,
  input  logic [TtiIbiFifoDepthWidth-1:0] ibi_queue_depth_i,
  input  logic      [TtiIbiDataWidth-1:0] ibi_queue_rdata_i,

  // I3C received address (with RnW# bit) for the recovery handler
  output logic       bus_addr_valid_o,
  output logic [7:0] bus_addr_o,

  // Timing Configuration
  input  i3c_timeparam_t t_su_dat_i,
  input  i3c_timeparam_t t_hd_dat_i,
  input  i3c_timeparam_t t_r_i,
  input  i3c_timeparam_t t_f_i,
  input  i3c_timeparam_t t_bus_free_i,
  input  i3c_timeparam_t t_bus_idle_i,
  input  i3c_timeparam_t t_bus_available_i,

  // HDR error recovery timer configuration (I3C spec §5.1.10.1.9)
  input  logic           hdr_timeout_en_i,
  input  i3c_timeparam_t t_hdr_timeout_i,  

  // Address Control
  input  logic      target_sta_addr_valid_i,
  input  i3c_addr_t target_sta_addr_i,
  input  logic      target_dyn_addr_valid_i,
  input  i3c_addr_t target_dyn_addr_i,
  input  logic      virtual_target_sta_addr_valid_i,
  input  i3c_addr_t virtual_target_sta_addr_i,
  input  logic      virtual_target_dyn_addr_valid_i,
  input  i3c_addr_t virtual_target_dyn_addr_i,
  input  logic      target_ibi_addr_valid_i,
  input  i3c_addr_t target_ibi_addr_i,

  // Provisioned IDs
  input  logic [47:0] pid_i,
  input  logic [47:0] virtual_pid_i,

  // IBI related control
  input  logic        ibi_enable_i,
  input  logic  [2:0] ibi_retry_num_i,
  output logic        ibi_status_we_o,
  output ibi_status_e ibi_status_o,
  output logic        ibi_pending_o,

  // Max write length
  output logic        set_mwl_o,
  output logic [15:0] mwl_o,
  input  logic [15:0] get_mwl_i,

  // Max read length
  output logic        set_mrl_o,
  output logic [15:0] mrl_o,
  input  logic [15:0] get_mrl_i,

  // IBI payload size, part of MRL
  output logic       set_ibil_o,
  output logic [7:0] ibil_o,
  input  logic [7:0] get_ibil_i,

  // Status format 1
  input  logic [15:0] get_status_fmt1_i,

  // (Virtual) Bus Capability Register
  input  logic [7:0] bcr_i,
  input  logic [7:0] virtual_bcr_i,

  // (Virtual) Device Capability Register
  input  logic [7:0] dcr_i,
  input  logic [7:0] virtual_dcr_i,

  // Target Reset Action
  output logic       rst_action_valid_o,
  output logic [7:0] rst_action_o,

  // Set dynamic address from static address
  output logic      set_dasa_valid_o,
  output logic      set_dasa_virtual_device_o,
  output i3c_addr_t set_dasa_o,
  // Set all addresses to static address
  output logic set_aasa_o,
  output logic set_aasa_virt_o,

  // Set new dynamic address
  output logic      set_newda_o,
  output logic      set_newda_virtual_device_o,
  output i3c_addr_t newda_o,

  // Reset dynamic address assignment
  output logic rstdaa_o,

  // Enable/disable events
  output logic enec_ibi_o,  // Target-initiated interrupts
  output logic disec_ibi_o,

  output logic enec_crr_o,  // Control-role requests
  output logic disec_crr_o,

  output logic enec_hj_o,   // Hot Join requests
  output logic disec_hj_o,

  //
  output logic tx_host_nack_o,
  output logic tx_pr_end_o,
  output logic tx_pr_start_o,

  //
  output logic get_status_done_o,

  // Protocol Error Report (GETSTATUS Format 1): errors Controller cannot detect
  output logic protocol_err_o,
  // Individual TE error outputs for interrupt reporting
  output logic te0_err_o,
  output logic te1_err_o,
  output logic te2_err_o,
  output logic te3_err_o,
  output logic te4_err_o,
  output logic te5_err_o,
  output logic framing_err_o,

  // Target Error Detection Enables (from TTI CSR)
  input  logic te0_err_det_en_i,
  input  logic te1_err_det_en_i,
  input  logic te2_err_det_en_i,
  input  logic te3_err_det_en_i,
  input  logic te4_err_det_en_i,
  input  logic te5_err_det_en_i,
  input  logic framing_err_det_en_i,


  output logic peripheral_reset_o,
  input  logic peripheral_reset_done_i,
  output logic escalated_reset_o,

  // recovery mode
  input  logic recovery_mode_enter_i,
  output logic virtual_device_sel_o,
  output logic xfer_in_progress_o,
  output logic in_hdr_mode_o
);

  // Bus TX flow
  bus_tx_req_t bus_tx_req, bus_tx_req_fsm, bus_tx_req_ccc;
  bus_tx_rsp_t bus_tx_rsp, bus_tx_rsp_fsm, bus_tx_rsp_ccc;

  // Bus RX flow
  bus_rx_req_t bus_rx_req, bus_rx_req_fsm, bus_rx_req_ccc;
  bus_rx_rsp_t bus_rx_rsp, bus_rx_rsp_fsm, bus_rx_rsp_ccc;

  // TX Queue interface
  logic      tx_desc_avail;
  logic      tx_fifo_rvalid;
  logic      tx_fifo_rready;
  i3c_byte_t tx_fifo_rdata;

  // RX Queue interface
  logic      rx_fifo_wvalid;
  logic      rx_fifo_wready;
  i3c_byte_t rx_fifo_wdata;

  logic rx_last_byte;
  logic tx_last_byte;

  // IBI Queue interface
  logic      ibi_fifo_rvalid;
  logic      ibi_fifo_rready;
  i3c_byte_t ibi_fifo_rdata;
  logic      ibi_last_byte;
  logic      ibi_fifo_flush;

  // Bus events notifications
  logic event_target_nack;
  logic event_cmd_complete;
  logic event_unexp_stop;
  logic event_tx_arbitration_lost;
  logic event_tx_bus_timeout;
  logic event_read_cmd_received;

  // Special bus patterns
  logic target_reset_detect;
  logic hdr_exit_detect;
  logic in_hdr_err_mode;

  // CCC sub-FSM data and status
  ccc_cmd_e  ccc_data;
  logic      ccc_valid;
  logic      ccc_done;
  logic      ccc_next;

  // Bus events detection
  logic bus_timeout;
  logic hotjoin_done;

  //
  logic tx_pr_abort;

  logic rx_overflow_err;
  logic bus_busy;
  logic bus_free;
  logic bus_idle;
  logic bus_available;

  // CCCs
  logic get_acccr;
  logic get_mxds;

  // TE0 error signals
  logic te0_enable;
  logic te0_err;

  // CCC parity error signals (for Protocol Error Report)
  logic te1_err_ccc;      // CCC command parity error (TE1)
  logic te2_err_ccc;      // CCC data parity error (TE2)
  logic te3_err_ccc;      // ENTDAA PID mismatch (TE3)
  logic te4_err_ccc;      // ENTDAA BCR/DCR mismatch (TE4)
  logic te5_err_ccc;      // Broadcast/Direct DA mismatch (TE5)
  logic framing_err_ccc;  // DA padding errors from CCC (for Protocol Error Report)

  // Private write parity error (from target FSM)
  logic te2_err_priv_wr;

  logic escalate_reset;
  logic rstact_armed;

  // Drive all unused inputs here
  assign ctrl_scl_o   = 1'b1;
  assign get_acccr    = 1'b0;
  assign get_mxds     = 1'b0;
  assign bus_timeout  = 1'b0;
  assign hotjoin_done = 1'b0;

  typedef enum logic {
    Fsm,
    Ccc
  } xfer_mux_sel_e;

  // Mux Rx/Tx between
  // 0 - Target FSM
  // 1 - CCC
  xfer_mux_sel_e xfer_mux_sel;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      xfer_mux_sel <= Fsm;
    end else if ((xfer_mux_sel == Fsm) && ccc_valid) begin
      xfer_mux_sel <= Ccc;
    end else if ((xfer_mux_sel == Ccc) && (ccc_done || ccc_next)) begin
      xfer_mux_sel <= Fsm;
    end
  end

  always_comb begin
    bus_tx_req = '{drive_type: OpenDrain, req_type: RawBit, default: '0};
    bus_rx_req = '{default: '0};

    bus_tx_rsp_fsm = '{default: '0};
    bus_tx_rsp_ccc = '{default: '0};

    bus_rx_rsp_fsm = '{default: '0};
    bus_rx_rsp_ccc = '{default: '0};

    unique case (xfer_mux_sel)
      Fsm: begin
        bus_tx_req = bus_tx_req_fsm;
        bus_rx_req = bus_rx_req_fsm;

        bus_tx_rsp_fsm = bus_tx_rsp;
        bus_rx_rsp_fsm = bus_rx_rsp;
      end
      Ccc: begin
        bus_tx_req = bus_tx_req_ccc;
        bus_rx_req = bus_rx_req_ccc;

        bus_tx_rsp_ccc = bus_tx_rsp;
        bus_rx_rsp_ccc = bus_rx_rsp;
      end
      default: ;
    endcase
  end


  // Target FSM
  i3c_target_fsm xi3c_target_fsm (
    .clk_i,
    .rst_ni,

    .target_enable_i      (i3c_standby_en_i),

    .scl_negedge_i        (ctrl_bus_i.scl.neg_edge),
    .bus_start_det_i      (ctrl_bus_i.start_det),
    .bus_rstart_det_i     (ctrl_bus_i.rstart_det),
    .bus_stop_det_i       (ctrl_bus_i.stop_det),

    .bus_available_i      (bus_available),
    .bus_timeout_i        (bus_timeout),
    .arbitration_lost_i,

    .target_idle_o        (/* unused */),

    .bus_tx_req_o(bus_tx_req_fsm),
    .bus_tx_rsp_i(bus_tx_rsp_fsm),

    .bus_rx_req_o(bus_rx_req_fsm),
    .bus_rx_rsp_i(bus_rx_rsp_fsm),

    // Private read start/abort
    .tx_pr_start_o   (tx_pr_start_o),
    .tx_pr_abort_o   (tx_pr_abort),

    .tx_desc_avail_i (tx_desc_avail),

    .tx_fifo_rvalid_i(tx_fifo_rvalid),
    .tx_fifo_rready_o(tx_fifo_rready),
    .tx_fifo_rdata_i (tx_fifo_rdata),

    .tx_host_nack_o  (tx_host_nack_o),
    .tx_last_byte_i  (tx_last_byte),

    .rx_fifo_wvalid_o(rx_fifo_wvalid),
    .rx_fifo_wdata_o (rx_fifo_wdata),
    .rx_fifo_wready_i(rx_fifo_wready),
    .rx_last_byte_o  (rx_last_byte),

    .ibi_byte_valid_i(ibi_fifo_rvalid),
    .ibi_byte_ready_o(ibi_fifo_rready),
    .ibi_byte_i      (ibi_fifo_rdata),
    .ibi_byte_last_i (ibi_last_byte),
    .ibi_byte_flush_o(ibi_fifo_flush),

    .target_sta_addr_i,
    .target_sta_addr_valid_i,
    .target_dyn_addr_i,
    .target_dyn_addr_valid_i,

    .virtual_target_sta_addr_i,
    .virtual_target_sta_addr_valid_i,
    .virtual_target_dyn_addr_i,
    .virtual_target_dyn_addr_valid_i,

    .target_ibi_addr_valid_i,
    .target_ibi_addr_i,

    .event_target_nack_o        (event_target_nack),
    .event_cmd_complete_o       (event_cmd_complete),
    .event_unexp_stop_o         (event_unexp_stop),
    .event_tx_arbitration_lost_o(event_tx_arbitration_lost),
    .event_tx_bus_timeout_o     (event_tx_bus_timeout),
    .event_read_cmd_received_o  (event_read_cmd_received),

    .target_reset_detect_i      (target_reset_detect),

    .hdr_exit_detect_i          (hdr_exit_detect),
    .in_hdr_mode_i              (in_hdr_mode_o),

    .ibi_enable_i,
    .ibi_retry_num_i,
    .ibi_status_o,
    .ibi_status_we_o,

    .ccc_data_o                 (ccc_data),
    .ccc_valid_o                (ccc_valid),
    .is_ccc_done_i              (ccc_done),
    .is_next_ccc_i              (ccc_next),

    .te0_enable_i               (te0_enable),
    .te0_err_o                  (te0_err),

    .is_hotjoin_done_i          (hotjoin_done),

    .te2_err_det_en_i           (te2_err_det_en_i),

    .last_addr_o                (bus_addr_o),
    .last_addr_valid_o          (bus_addr_valid_o),

    .rx_overflow_err_o          (rx_overflow_err),
    .te2_err_priv_wr            (te2_err_priv_wr),
    .virtual_device_sel_o,
    .xfer_in_progress_o
  );

  ccc xccc (
    .clk_i,
    .rst_ni,

    .arbitration_lost_i,

    .ccc_data_i (ccc_data),
    .ccc_valid_i(ccc_valid),
    .done_fsm_o (ccc_done),
    .next_ccc_o (ccc_next),

    .te0_enable_o(te0_enable),
    .te0_err_i   (te0_err),
    .te1_err_o   (te1_err_ccc),
    .te2_err_ccc_o(te2_err_ccc),
    .te3_err_o   (te3_err_ccc),
    .te4_err_o   (te4_err_ccc),
    .te5_err_o   (te5_err_ccc),
    .framing_err_o(framing_err_ccc),

    .te0_err_det_en_i(te0_err_det_en_i),
    .te1_err_det_en_i(te1_err_det_en_i),
    .te2_err_det_en_i(te2_err_det_en_i),
    .te3_err_det_en_i(te3_err_det_en_i),
    .te4_err_det_en_i(te4_err_det_en_i),
    .te5_err_det_en_i(te5_err_det_en_i),
    .framing_err_det_en_i(framing_err_det_en_i),

    .bus_start_det_i (ctrl_bus_i.start_det),
    .bus_rstart_det_i(ctrl_bus_i.rstart_det),
    .bus_stop_det_i  (ctrl_bus_i.stop_det),

    .bus_tx_req_o(bus_tx_req_ccc),
    .bus_tx_rsp_i(bus_tx_rsp_ccc),

    .bus_rx_req_o(bus_rx_req_ccc),
    .bus_rx_rsp_i(bus_rx_rsp_ccc),

    .target_sta_address_i      (target_sta_addr_i),
    .target_sta_address_valid_i(target_sta_addr_valid_i),
    .target_dyn_address_i      (target_dyn_addr_i),
    .target_dyn_address_valid_i(target_dyn_addr_valid_i),

    .virtual_target_sta_address_i      (virtual_target_sta_addr_i),
    .virtual_target_sta_address_valid_i(virtual_target_sta_addr_valid_i),
    .virtual_target_dyn_address_i      (virtual_target_dyn_addr_i),
    .virtual_target_dyn_address_valid_i(virtual_target_dyn_addr_valid_i),

    .enec_ibi_o,
    .enec_crr_o,
    .enec_hj_o,
    .disec_ibi_o,
    .disec_crr_o,
    .disec_hj_o,

    .entas0_o(/* unused */),
    .entas1_o(/* unused */),
    .entas2_o(/* unused */),
    .entas3_o(/* unused */),

    .rstdaa_o,
    .entdaa_o(/* unused */),

    .get_mwl_i,
    .set_mwl_o,
    .mwl_o,
    .get_mrl_i,
    .set_mrl_o,
    .mrl_o,

    .get_ibil_i,
    .set_ibil_o,
    .ibil_o,

    .ent_tm_o(/* unused */),
    .tm_o    (/* unused */),

    .exit_hdr_i    (hdr_exit_detect),
    .in_hdr_mode_o (in_hdr_mode_o),
    .in_hdr_err_mode_o (in_hdr_err_mode),

    .set_dasa_o,
    .set_dasa_valid_o,
    .set_dasa_virtual_device_o,
    .set_aasa_o,
    .set_aasa_virt_o,
    .set_newda_o,
    .set_newda_virtual_device_o,
    .newda_o,

    .rst_action_o,
    .rst_action_valid_o,

    .get_pid_i        (pid_i),
    .get_bcr_i        (bcr_i),
    .get_dcr_i        (dcr_i),
    .virtual_get_pid_i(virtual_pid_i),
    .virtual_get_bcr_i(virtual_bcr_i),
    .virtual_get_dcr_i(virtual_dcr_i),

    .get_status_fmt1_i,
    .get_acccr_i       (get_acccr),
    .set_brgtgt_o      (/* unused */),
    .get_mxds_i        (get_mxds),
    .get_status_done_o,

    .target_reset_detect_i   (target_reset_detect),
    .peripheral_reset_done_i,
    .rstact_armed_o          (rstact_armed),
    .escalate_reset_o        (escalate_reset)
  );

  bus_tx_flow u_bus_tx_flow (
    .clk_i,
    .rst_ni,

    .bus_i(ctrl_bus_i),

    .tx_req_i(bus_tx_req),
    .tx_rsp_o(bus_tx_rsp),

    .sel_od_pp_o(phy_sel_od_pp_o),
    .sda_oe_o   (ctrl_sda_oe_o),
    .sda_o      (ctrl_sda_o)
  );

  bus_rx_flow xbus_rx_flow (
    .clk_i,
    .rst_ni,

    .scl_posedge_i    (ctrl_bus_i.scl.pos_edge),
    .scl_stable_high_i(ctrl_bus_i.scl.stable_high),
    .sda_i            (ctrl_bus_i.sda.value),

    .rx_req_i(bus_rx_req),
    .rx_rsp_o(bus_rx_rsp)
  );

  i3c_bus_monitor xbus_monitor (
    .clk_i,
    .rst_ni,

    .enable_i             (i3c_standby_en_i),

    .bus_i                (hdr_exit_bus_i),

    .is_in_hdr_mode_i     (in_hdr_mode_o),
    .is_in_hdr_err_mode_i (in_hdr_err_mode),

    .hdr_timeout_en_i     (hdr_timeout_en_i),
    .t_hdr_timeout_i      (t_hdr_timeout_i),

    .hdr_exit_detect_o    (hdr_exit_detect),
    .target_reset_detect_o(target_reset_detect)
  );

  bus_timers xbus_timers (
    .clk_i,
    .rst_ni,

    .enable_i         (i3c_standby_en_i),

    .bus_start_i      (ctrl_bus_i.start_det | ctrl_bus_i.rstart_det),
    .bus_stop_i       (ctrl_bus_i.stop_det),
    .in_hdr_mode_i    (in_hdr_mode_o),

    .t_bus_free_i     (t_bus_free_i),
    .t_bus_idle_i     (t_bus_idle_i),
    .t_bus_available_i(t_bus_available_i),

    .bus_busy_o       (bus_busy),
    .bus_free_o       (bus_free),
    .bus_idle_o       (bus_idle),
    .bus_available_o  (bus_available)
  );

  // Protocol Error Report (GETSTATUS Format 1): errors Controller cannot detect
  // - te1_err_ccc: CCC command parity error (TE1)
  // - te2_err_ccc: CCC data parity error (TE2)
  // - te2_err_priv_wr: Private write parity error (TE2)
  // - framing_err_ccc: SETDASA/SETNEWDA padding bit error (Bit[0] != 0)
  assign protocol_err_o = te1_err_ccc | te2_err_ccc | te2_err_priv_wr | framing_err_ccc;

  // Individual TE error outputs for interrupt reporting
  assign te0_err_o = te0_err;
  assign te1_err_o = te1_err_ccc;
  assign te2_err_o = te2_err_ccc | te2_err_priv_wr;
  assign te3_err_o = te3_err_ccc;
  assign te4_err_o = te4_err_ccc;
  assign te5_err_o = te5_err_ccc;
  assign framing_err_o = framing_err_ccc;

  logic rx_error;

  assign rx_error = protocol_err_o | rx_overflow_err;

  descriptor_rx #(
    .TtiRxDescDataWidth(TtiRxDescDataWidth),
    .TtiRxDataWidth    (TtiRxDataWidth)
  ) xdescriptor_rx (
    .clk_i,
    .rst_ni,

    .tti_rx_desc_queue_wvalid_o(rx_desc_queue_wvalid_o),
    .tti_rx_desc_queue_wdata_o (rx_desc_queue_wdata_o),

    .tti_rx_queue_wready_i     (rx_queue_wready_i),
    .tti_rx_queue_wvalid_o     (rx_queue_wvalid_o),
    .tti_rx_queue_flush_o      (rx_queue_flush_o),
    .tti_rx_queue_wdata_o      (rx_queue_wdata_o),

    .rx_byte_i                 (rx_fifo_wdata),
    .rx_byte_last_i            (rx_last_byte),
    .rx_byte_valid_i           (rx_fifo_wvalid),
    .rx_byte_ready_o           (rx_fifo_wready),
    .rx_byte_err_i             (rx_error)
  );

  // Expose rx_last_byte directly (aligned with rx_queue_wvalid_o)
  assign rx_queue_wlast_o = rx_last_byte;

  descriptor_tx #(
    .TtiTxDescDataWidth  (TtiTxDescDataWidth),
    .TtiTxDataWidth      (TtiTxDataWidth),
    .TtiTxFifoDepthWidth (TtiTxFifoDepthWidth)
  ) xdescriptor_tx (
    .clk_i,
    .rst_ni,

    .tti_tx_desc_queue_rvalid_i(tx_desc_queue_rvalid_i),
    .tti_tx_desc_queue_rready_o(tx_desc_queue_rready_o),
    .tti_tx_desc_queue_rdata_i (tx_desc_queue_rdata_i),

    .tti_tx_queue_empty_i      (tx_queue_empty_i),
    .tti_tx_queue_rvalid_i     (tx_queue_rvalid_i),
    .tti_tx_queue_depth_i      (tx_queue_depth_i),
    .tti_tx_queue_rready_o     (tx_queue_rready_o),
    .tti_tx_queue_rdata_i      (tx_queue_rdata_i),

    .tx_queue_flush_o          (tx_queue_flush_o),
    .tx_start_i                (tx_pr_start_o),
    .tx_abort_i                (tx_pr_abort),
    .tx_desc_avail_o           (tx_desc_avail),

    .tx_byte_o                 (tx_fifo_rdata),
    .tx_byte_last_o            (tx_last_byte),
    .tx_byte_valid_o           (tx_fifo_rvalid),
    .tx_byte_ready_i           (tx_fifo_rready),

    .recovery_mode_enter_i     (recovery_mode_enter_i),
    .tx_end_o                  (tx_pr_end_o)
  );

  descriptor_ibi #(
    .TtiIbiDataWidth(TtiIbiDataWidth),
    .TtiIbiDataDepth(TtiIbiFifoDepthWidth)
  ) u_descriptor_ibi (
    .clk_i,
    .rst_ni,

    .ibi_queue_rvalid_i,
    .ibi_queue_depth_i,
    .ibi_queue_rready_o,
    .ibi_queue_rdata_i,

    .ibi_byte_valid_o(ibi_fifo_rvalid),
    .ibi_byte_ready_i(ibi_fifo_rready),
    .ibi_byte_o      (ibi_fifo_rdata),
    .ibi_byte_last_o (ibi_last_byte),
    .ibi_byte_flush_i(ibi_fifo_flush),
    .ibi_pending_o
  );

  logic peripheral_reset;
  logic escalated_reset;

  always_ff @(posedge clk_i or negedge rst_ni) begin : register_peripheral_reset
    if (~rst_ni) begin
      peripheral_reset_o <= '0;
    end else begin
      if (peripheral_reset) peripheral_reset_o <= 1'b1;
      if (peripheral_reset_done_i) peripheral_reset_o <= '0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : register_escalated_reset
    if (~rst_ni) begin
      escalated_reset_o <= '0;
    end else begin
      if (escalated_reset) escalated_reset_o <= 1'b1;
    end
  end

  // Reset peripheral for reset action 0x1 or when we receive 1st Target Reset Pattern
  assign peripheral_reset = ((rst_action_o == 8'h1) & rst_action_valid_o) |
                              (target_reset_detect & ~escalate_reset & ~rstact_armed);
  // Escalate reset for reset action 0x2 or when we receive 2nd Target Reset Pattern
  assign escalated_reset = ((rst_action_o == 8'h2) & rst_action_valid_o) |
                             (target_reset_detect & escalate_reset & ~rstact_armed);

endmodule
