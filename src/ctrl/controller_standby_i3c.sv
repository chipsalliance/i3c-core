// SPDX-License-Identifier: Apache-2.0

module controller_standby_i3c
  import controller_pkg::*;
  import i3c_pkg::*;
#(
    parameter int unsigned TtiRxDescDataWidth = 32,
    parameter int unsigned TtiTxDescDataWidth = 32,
    parameter int unsigned TtiRxDataWidth = 8,
    parameter int unsigned TtiTxDataWidth = 8,
    parameter int unsigned TtiTxFifoDepth = 16,  // FIXME
    localparam int unsigned TtiTxFifoDepthWidth = $clog2(TtiTxFifoDepth + 1),
    parameter int unsigned TtiIbiFifoDepth = 16,
    localparam int unsigned TtiIbiFifoDepthWidth = $clog2(TtiIbiFifoDepth + 1),
    parameter int unsigned TtiIbiDataWidth = 32
) (
    input logic clk_i,
    input logic rst_ni,
    input logic [47:0] id_i,

    // Interface to SDA/SCL
    input bus_state_t ctrl_bus_i,
    output logic ctrl_scl_o,
    output logic ctrl_sda_o,
    output logic phy_sel_od_pp_o,

    // Target Transaction Interface

    // TTI: RX Descriptor
    output logic rx_desc_queue_wvalid_o,
    output logic [TtiRxDescDataWidth-1:0] rx_desc_queue_wdata_o,

    // TTI: TX Descriptor
    input logic tx_desc_queue_rvalid_i,
    output logic tx_desc_queue_rready_o,
    input logic [TtiTxDescDataWidth-1:0] tx_desc_queue_rdata_i,

    // TTI: RX Data
    input logic rx_queue_wready_i,
    output logic rx_queue_wvalid_o,
    output logic rx_queue_flush_o,
    output logic [TtiRxDataWidth-1:0] rx_queue_wdata_o,

    // TTI: TX Data
    input logic tx_queue_rvalid_i,
    input logic [TtiTxFifoDepthWidth-1:0] tx_queue_depth_i,
    output logic tx_queue_rready_o,
    input logic [TtiTxDataWidth-1:0] tx_queue_rdata_i,
    input logic tx_queue_empty_i,
    output logic tx_queue_flush_o,

    // TTI: In-band-interrupt queue
    input logic ibi_queue_full_i,
    input logic ibi_queue_empty_i,
    input logic ibi_queue_rvalid_i,
    input logic [TtiIbiFifoDepthWidth-1:0] ibi_queue_depth_i,
    output logic ibi_queue_rready_o,
    input logic [TtiIbiDataWidth-1:0] ibi_queue_rdata_i,

    // I3C received address (with RnW# bit) for the recovery handler
    output logic [7:0] bus_addr_o,
    output logic bus_addr_valid_o,

    // Configuration
    input logic i3c_standby_en_i,
    input logic [19:0] t_su_dat_i,
    input logic [19:0] t_hd_dat_i,
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
    input logic [6:0] virtual_target_sta_addr_i,
    input logic virtual_target_sta_addr_valid_i,
    input logic [6:0] virtual_target_dyn_addr_i,
    input logic virtual_target_dyn_addr_valid_i,
    input logic [6:0] target_ibi_addr_i,
    input logic target_ibi_addr_valid_i,
    input logic [6:0] target_hot_join_addr_i,
    input logic [63:0] daa_unique_response_i,
    input logic ibi_enable_i,
    input logic [2:0] ibi_retry_num_i,

    output logic [7:0] rst_action_o,
    output logic rst_action_valid_o,
    output logic tx_host_nack_o,
    output logic tx_pr_end_o,
    output logic tx_pr_start_o,
    output logic [6:0] set_dasa_o,
    output logic set_dasa_valid_o,
    output logic set_dasa_virtual_device_o,
    output logic rstdaa_o,

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

    output logic get_status_done_o,

    output logic parity_err_o,

    output logic peripheral_reset_o,
    input  logic peripheral_reset_done_i,
    output logic escalated_reset_o,

    // recovery mode
    input  logic recovery_mode_enter_i,
    output logic virtual_device_sel_o,
    output logic xfer_in_progress_o
);
  logic i3c_standby_en;
  assign i3c_standby_en = i3c_standby_en_i;

  // Bus events detection
  logic bus_timeout;

  // Target control signals
  logic target_idle;
  logic target_transmitting;

  // Bus TX flow
  logic bus_tx_req_err;
  logic bus_tx_done;
  logic bus_tx_idle;
  logic bus_tx_req_byte;
  logic bus_tx_req_bit;
  logic [7:0] bus_tx_req_value;
  logic bus_tx_sel_od_pp;

  logic fsm_bus_tx_req_err;
  logic fsm_bus_tx_done;
  logic fsm_bus_tx_idle;
  logic fsm_bus_tx_req_byte;
  logic fsm_bus_tx_req_bit;
  logic [7:0] fsm_bus_tx_req_value;
  logic fsm_bus_tx_sel_od_pp;

  logic ccc_bus_tx_req_err;
  logic ccc_bus_tx_done;
  logic ccc_bus_tx_idle;
  logic ccc_bus_tx_req_byte;
  logic ccc_bus_tx_req_bit;
  logic [7:0] ccc_bus_tx_req_value;
  logic ccc_bus_tx_sel_od_pp;

  logic ibi_bus_tx_req_err;
  logic ibi_bus_tx_done;
  logic ibi_bus_tx_idle;
  logic ibi_bus_tx_req_byte;
  logic ibi_bus_tx_req_bit;
  logic [7:0] ibi_bus_tx_req_value;
  logic ibi_bus_tx_sel_od_pp;

  // Bus RX flow
  logic bus_rx_req_bit;
  logic bus_rx_req_byte;
  logic bus_rx_done;
  logic bus_rx_idle;
  logic [7:0] bus_rx_data;
  logic bus_rx_error;

  logic fsm_bus_rx_req_bit;
  logic fsm_bus_rx_req_byte;
  logic fsm_bus_rx_done;
  logic fsm_bus_rx_idle;
  logic [7:0] fsm_bus_rx_data;
  logic fsm_bus_rx_error;

  logic ccc_bus_rx_req_bit;
  logic ccc_bus_rx_req_byte;
  logic ccc_bus_rx_done;
  logic ccc_bus_rx_idle;
  logic [7:0] ccc_bus_rx_data;
  logic ccc_bus_rx_error;

  logic ibi_bus_rx_req_bit;
  logic ibi_bus_rx_req_byte;
  logic ibi_bus_rx_done;
  logic [7:0] ibi_bus_rx_data;

  // TX Queue interface
  logic tx_desc_avail;
  logic tx_fifo_rvalid;
  logic tx_fifo_rready;
  logic [7:0] tx_fifo_rdata;
  logic tx_host_nack;

  // RX Queue interface
  logic rx_fifo_wvalid;
  logic [7:0] rx_fifo_wdata;
  logic rx_fifo_wready;
  logic rx_last_byte;
  logic tx_last_byte;

  // IBI Queue interface
  logic ibi_fifo_rvalid;
  logic ibi_fifo_rready;
  logic [7:0] ibi_fifo_rdata;
  logic ibi_last_byte;

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
  logic is_in_hdr_mode;

  // SubFSMs status
  logic ibi_pending;
  logic ibi_begin;
  logic ibi_done;

  logic [7:0] ccc;
  logic ccc_valid;
  logic is_ccc_done;
  logic is_hotjoin_done;

  //
  logic tx_pr_abort;

  logic rx_overflow_err;
  logic bus_error;
  logic bus_busy;
  logic bus_free;
  logic bus_idle;
  logic bus_available;

  // CCCs
  logic entas0, entas1, entas2, entas3;
  logic entdaa;
  logic ent_tm;
  logic [7:0] tm;
  logic ent_hdr_0, ent_hdr_1, ent_hdr_2, ent_hdr_3, ent_hdr_4, ent_hdr_5, ent_hdr_6, ent_hdr_7;
  logic set_newda;
  logic [6:0] newda;
  logic get_acccr;
  logic set_brgtgt;
  logic get_mxds;

  logic escalate_reset;
  logic rstact_armed;

  // Drive all unused inputs here
  always_comb begin
    ctrl_scl_o = '1;
    get_acccr = '0;
    get_mxds = '0;
    bus_timeout = '0;
    is_hotjoin_done = '0;
  end

  typedef enum logic [1:0] {
    Fsm,
    Ccc,
    Ibi
  } xfer_mux_sel_e;

  // Mux Rx/Tx between
  // 0 - Target FSM
  // 1 - CCC
  // 2 - IBI
  xfer_mux_sel_e xfer_mux_sel;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) xfer_mux_sel <= Fsm;
    else if (xfer_mux_sel == Fsm)
      unique case ({
        ibi_begin, ccc_valid
      })
        2'b01:   xfer_mux_sel <= Ccc;
        2'b10:   xfer_mux_sel <= Ibi;
        default: xfer_mux_sel <= Fsm;
      endcase
    else if (xfer_mux_sel == Ccc && is_ccc_done) xfer_mux_sel <= Fsm;
    else if (xfer_mux_sel == Ibi && ibi_done) xfer_mux_sel <= Fsm;
  end

  always_comb begin
    ccc_bus_tx_req_err = '0;
    ccc_bus_tx_done    = '0;
    ccc_bus_tx_idle    = '0;
    fsm_bus_tx_req_err = '0;
    fsm_bus_tx_done    = '0;
    fsm_bus_tx_idle    = '0;
    bus_tx_req_byte    = '0;
    bus_tx_req_bit     = '0;
    bus_tx_req_value   = '0;
    bus_tx_sel_od_pp   = '0;
    bus_rx_req_bit     = '0;
    bus_rx_req_byte    = '0;
    fsm_bus_rx_done    = '0;
    fsm_bus_rx_idle    = '0;
    fsm_bus_rx_data    = '0;
    fsm_bus_rx_error   = '0;
    ccc_bus_rx_done    = '0;
    ccc_bus_rx_idle    = '0;
    ccc_bus_rx_data    = '0;
    ccc_bus_rx_error   = '0;
    ibi_bus_tx_req_err = '0;
    ibi_bus_tx_done    = '0;
    ibi_bus_tx_idle    = '0;
    ibi_bus_rx_done    = '0;
    ibi_bus_rx_data    = '0;

    unique case (xfer_mux_sel)
      Fsm: begin
        fsm_bus_tx_req_err = bus_tx_req_err;
        fsm_bus_tx_done    = bus_tx_done;
        fsm_bus_tx_idle    = bus_tx_idle;
        bus_tx_req_byte    = fsm_bus_tx_req_byte;
        bus_tx_req_bit     = fsm_bus_tx_req_bit;
        bus_tx_req_value   = fsm_bus_tx_req_value;
        bus_tx_sel_od_pp   = fsm_bus_tx_sel_od_pp;

        bus_rx_req_bit     = fsm_bus_rx_req_bit;
        bus_rx_req_byte    = fsm_bus_rx_req_byte;
        fsm_bus_rx_done    = bus_rx_done;
        fsm_bus_rx_idle    = bus_rx_idle;
        fsm_bus_rx_data    = bus_rx_data;
        fsm_bus_rx_error   = bus_rx_error;
      end
      Ccc: begin
        ccc_bus_tx_req_err = bus_tx_req_err;
        ccc_bus_tx_done    = bus_tx_done;
        ccc_bus_tx_idle    = bus_tx_idle;
        bus_tx_req_byte    = ccc_bus_tx_req_byte;
        bus_tx_req_bit     = ccc_bus_tx_req_bit;
        bus_tx_req_value   = ccc_bus_tx_req_value;
        bus_tx_sel_od_pp   = ccc_bus_tx_sel_od_pp;

        bus_rx_req_bit     = ccc_bus_rx_req_bit;
        bus_rx_req_byte    = ccc_bus_rx_req_byte;
        ccc_bus_rx_done    = bus_rx_done;
        ccc_bus_rx_idle    = bus_rx_idle;
        ccc_bus_rx_data    = bus_rx_data;
        ccc_bus_rx_error   = bus_rx_error;
      end
      Ibi: begin
        //ibi_bus_tx_req_err = bus_tx_req_err;
        ibi_bus_tx_done  = bus_tx_done;
        //ibi_bus_tx_idle    = bus_tx_idle;
        bus_tx_req_byte  = ibi_bus_tx_req_byte;
        bus_tx_req_bit   = ibi_bus_tx_req_bit;
        bus_tx_req_value = ibi_bus_tx_req_value;
        bus_tx_sel_od_pp = ibi_bus_tx_sel_od_pp;
        bus_rx_req_byte  = ibi_bus_rx_req_byte;
        bus_rx_req_bit   = ibi_bus_rx_req_bit;
        ibi_bus_rx_data  = bus_rx_data;
        ibi_bus_rx_done  = bus_rx_done;
      end
      default: ;
    endcase
  end

  // Allow IBI module to pull SDA
  logic ibi_sda;
  logic tx_sda;

  assign ctrl_sda_o = tx_sda & ibi_sda;

  // Target FSM
  i3c_target_fsm #(
      .RxDataWidth (8),
      .TxDataWidth (8),
      .IbiDataWidth(32)
  ) xi3c_target_fsm (
      .clk_i,
      .rst_ni,
      .target_enable_i      (i3c_standby_en),
      .bus_start_det_i      (ctrl_bus_i.start_det),
      .bus_rstart_det_i     (ctrl_bus_i.rstart_det),
      .bus_stop_det_i       (ctrl_bus_i.stop_det),
      .bus_timeout_i        (bus_timeout),
      .target_idle_o        (target_idle),
      .target_transmitting_o(target_transmitting),
      .bus_tx_req_err_i     (fsm_bus_tx_req_err),
      .bus_tx_done_i        (fsm_bus_tx_done),
      .bus_tx_idle_i        (fsm_bus_tx_idle),
      .bus_tx_req_byte_o    (fsm_bus_tx_req_byte),
      .bus_tx_req_bit_o     (fsm_bus_tx_req_bit),
      .bus_tx_req_value_o   (fsm_bus_tx_req_value),
      .bus_tx_sel_od_pp_o   (fsm_bus_tx_sel_od_pp),
      .bus_rx_req_bit_o     (fsm_bus_rx_req_bit),
      .bus_rx_req_byte_o    (fsm_bus_rx_req_byte),
      .bus_rx_done_i        (fsm_bus_rx_done),
      .bus_rx_idle_i        (fsm_bus_rx_idle),
      .bus_rx_data_i        (fsm_bus_rx_data),
      .bus_rx_error_i       (fsm_bus_rx_error),

      .tx_pr_start_o              (tx_pr_start_o),
      .tx_pr_abort_o              (tx_pr_abort),
      .tx_desc_avail_i            (tx_desc_avail),
      .tx_fifo_rvalid_i           (tx_fifo_rvalid),
      .tx_fifo_rready_o           (tx_fifo_rready),
      .tx_fifo_rdata_i            (tx_fifo_rdata),
      .tx_host_nack_o             (tx_host_nack),
      .tx_last_byte_i             (tx_last_byte),
      .rx_fifo_wvalid_o           (rx_fifo_wvalid),
      .rx_fifo_wdata_o            (rx_fifo_wdata),
      .rx_fifo_wready_i           (rx_fifo_wready),
      .rx_last_byte_o             (rx_last_byte),
      .target_sta_address_i       (target_sta_addr_i),
      .target_sta_address_valid_i (target_sta_addr_valid_i),
      .target_dyn_address_i       (target_dyn_addr_i),
      .target_dyn_address_valid_i (target_dyn_addr_valid_i),
      .virtual_target_sta_address_i       (virtual_target_sta_addr_i),
      .virtual_target_sta_address_valid_i (virtual_target_sta_addr_valid_i),
      .virtual_target_dyn_address_i       (virtual_target_dyn_addr_i),
      .virtual_target_dyn_address_valid_i (virtual_target_dyn_addr_valid_i),
      .event_target_nack_o        (event_target_nack),
      .event_cmd_complete_o       (event_cmd_complete),
      .event_unexp_stop_o         (event_unexp_stop),
      .event_tx_arbitration_lost_o(event_tx_arbitration_lost),
      .event_tx_bus_timeout_o     (event_tx_bus_timeout),
      .event_read_cmd_received_o  (event_read_cmd_received),
      .target_reset_detect_i      (target_reset_detect),
      .hdr_exit_detect_i          (hdr_exit_detect),
      .is_in_hdr_mode_o           (is_in_hdr_mode),
      .ibi_enable_i               (ibi_enable_i),
      .ibi_pending_i              (ibi_pending),
      .ibi_begin_o                (ibi_begin),
      .ibi_done_i                 (ibi_done),
      .ccc_o                      (ccc),
      .ccc_valid_o                (ccc_valid),
      .is_ccc_done_i              (is_ccc_done),
      .is_hotjoin_done_i          (is_hotjoin_done),
      .last_addr_o                (bus_addr_o),
      .last_addr_valid_o          (bus_addr_valid_o),
      .scl_negedge_i              (ctrl_bus_i.scl.neg_edge),
      .scl_posedge_i              (ctrl_bus_i.scl.pos_edge),
      .sda_negedge_i              (ctrl_bus_i.sda.neg_edge),
      .sda_posedge_i              (ctrl_bus_i.sda.pos_edge),
      .parity_err_o,
      .rx_overflow_err_o          (rx_overflow_err),
      .virtual_device_sel_o       (virtual_device_sel_o),
      .xfer_in_progress_o         (xfer_in_progress_o)
  );

  ccc xccc (
      .clk_i,
      .rst_ni,
      .id_i,
      .ccc_i                     (ccc),
      .ccc_valid_i               (ccc_valid),
      .done_fsm_o                (is_ccc_done),
      .bus_start_det_i           (ctrl_bus_i.start_det),
      .bus_rstart_det_i          (ctrl_bus_i.rstart_det),
      .bus_stop_det_i            (ctrl_bus_i.stop_det),
      .bus_tx_done_i             (ccc_bus_tx_done),
      .bus_tx_req_byte_o         (ccc_bus_tx_req_byte),
      .bus_tx_req_bit_o          (ccc_bus_tx_req_bit),
      .bus_tx_req_value_o        (ccc_bus_tx_req_value),
      .bus_tx_sel_od_pp_o        (ccc_bus_tx_sel_od_pp),
      .bus_rx_data_i             (ccc_bus_rx_data),
      .bus_rx_done_i             (ccc_bus_rx_done),
      .bus_rx_req_bit_o          (ccc_bus_rx_req_bit),
      .bus_rx_req_byte_o         (ccc_bus_rx_req_byte),
      .target_sta_address_i      (target_sta_addr_i),
      .target_sta_address_valid_i(target_sta_addr_valid_i),
      .target_dyn_address_i      (target_dyn_addr_i),
      .target_dyn_address_valid_i(target_dyn_addr_valid_i),
      .virtual_target_sta_address_i      (virtual_target_sta_addr_i),
      .virtual_target_sta_address_valid_i(virtual_target_sta_addr_valid_i),
      .virtual_target_dyn_address_i      (virtual_target_dyn_addr_i),
      .virtual_target_dyn_address_valid_i(virtual_target_dyn_addr_valid_i),
      .enec_ibi_o                (enec_ibi_o),
      .enec_crr_o                (enec_crr_o),
      .enec_hj_o                 (enec_hj_o),
      .disec_ibi_o               (disec_ibi_o),
      .disec_crr_o               (disec_crr_o),
      .disec_hj_o                (disec_hj_o),
      .entas0_o                  (entas0),
      .entas1_o                  (entas1),
      .entas2_o                  (entas2),
      .entas3_o                  (entas3),
      .rstdaa_o                  (rstdaa_o),
      .entdaa_o                  (entdaa),
      .set_mwl_o                 (set_mwl_o),
      .mwl_o                     (mwl_o),
      .set_mrl_o                 (set_mrl_o),
      .mrl_o                     (mrl_o),
      .ent_tm_o                  (ent_tm),
      .tm_o                      (tm),
      .ent_hdr_0_o               (ent_hdr_0),
      .ent_hdr_1_o               (ent_hdr_1),
      .ent_hdr_2_o               (ent_hdr_2),
      .ent_hdr_3_o               (ent_hdr_3),
      .ent_hdr_4_o               (ent_hdr_4),
      .ent_hdr_5_o               (ent_hdr_5),
      .ent_hdr_6_o               (ent_hdr_6),
      .ent_hdr_7_o               (ent_hdr_7),
      .set_dasa_o                (set_dasa_o),
      .set_dasa_valid_o          (set_dasa_valid_o),
      .set_dasa_virtual_device_o (set_dasa_virtual_device_o),
      .rst_action_o,
      .rst_action_valid_o,
      .set_newda_o               (set_newda),
      .newda_o                   (newda),
      .get_mwl_i                 (get_mwl_i),
      .get_mrl_i                 (get_mrl_i),
      .get_pid_i                 (pid_i),
      .get_bcr_i                 (bcr_i),
      .get_dcr_i                 (dcr_i),
      .get_status_fmt1_i         (get_status_fmt1_i),
      .get_acccr_i               (get_acccr),
      .set_brgtgt_o              (set_brgtgt),
      .get_mxds_i                (get_mxds),
      .get_status_done_o,
      .target_reset_detect_i     (target_reset_detect),
      .peripheral_reset_done_i,
      .rstact_armed_o            (rstact_armed),
      .escalate_reset_o          (escalate_reset)
  );

  ibi u_ibi (
      .clk_i,
      .rst_ni,

      .ibi_retry_num_i(ibi_retry_num_i),
      .ibi_abort_i    (1'b0),
      .ibi_status_o   (ibi_status_o),
      .ibi_status_we_o(ibi_status_we_o),

      .begin_i(ibi_begin),
      .done_o (ibi_done),

      .target_ibi_addr_i,
      .target_ibi_addr_valid_i,

      .ibi_byte_valid_i(ibi_fifo_rvalid),
      .ibi_byte_ready_o(ibi_fifo_rready),
      .ibi_byte_i      (ibi_fifo_rdata),
      .ibi_byte_last_i (ibi_last_byte),
      .ibi_byte_err_o  (),                 // FIXME

      .scl_negedge_i  (ctrl_bus_i.scl.neg_edge),
      .scl_posedge_i  (ctrl_bus_i.scl.pos_edge),
      .bus_available_i(bus_available),
      .bus_stop_i     (ctrl_bus_i.stop_det),

      .bus_tx_done_i     (ibi_bus_tx_done),
      .bus_tx_req_byte_o (ibi_bus_tx_req_byte),
      .bus_tx_req_bit_o  (ibi_bus_tx_req_bit),
      .bus_tx_req_value_o(ibi_bus_tx_req_value),
      .bus_tx_sel_od_pp_o(ibi_bus_tx_sel_od_pp),

      .bus_rx_done_i     (ibi_bus_rx_done),
      .bus_rx_req_byte_o (ibi_bus_rx_req_byte),
      .bus_rx_req_bit_o  (ibi_bus_rx_req_bit),
      .bus_rx_req_value_i(ibi_bus_rx_data),

      .t_hd_dat_i(t_hd_dat_i),
      .sda_o(ibi_sda)
  );

  // An IBI is pending as long as the descriptor_ibi has something to send to
  // the ibi module.
  assign ibi_pending = ibi_fifo_rvalid;

  bus_tx_flow u_bus_tx_flow (
      .clk_i,
      .rst_ni,
      .t_r_i,
      .t_su_dat_i,
      .t_hd_dat_i,
      .scl_negedge_i   (ctrl_bus_i.scl.neg_edge),
      .scl_posedge_i   (ctrl_bus_i.scl.pos_edge),
      .scl_stable_low_i(ctrl_bus_i.scl.stable_low),
      .req_byte_i      (bus_tx_req_byte),
      .req_bit_i       (bus_tx_req_bit),
      .req_value_i     (bus_tx_req_value),
      .bus_tx_done_o   (bus_tx_done),
      .bus_tx_idle_o   (bus_tx_idle),
      .req_error_o     (bus_tx_req_err),
      .bus_error_o     (bus_error),
      .sel_od_pp_i     (bus_tx_sel_od_pp),
      .sel_od_pp_o     (phy_sel_od_pp_o),
      .sda_o           (tx_sda)
  );

  bus_rx_flow xbus_rx_flow (
      .clk_i,
      .rst_ni,
      .scl_posedge_i    (ctrl_bus_i.scl.pos_edge),
      .scl_stable_high_i(ctrl_bus_i.scl.stable_high),
      .sda_i            (ctrl_bus_i.sda.value),
      .rx_req_bit_i     (bus_rx_req_bit),
      .rx_req_byte_i    (bus_rx_req_byte),
      .rx_data_o        (bus_rx_data),
      .rx_done_o        (bus_rx_done),
      .rx_idle_o        (bus_rx_idle),
      .error_o          (bus_rx_error)
  );

  i3c_bus_monitor xbus_monitor (
      .clk_i,
      .rst_ni,
      .enable_i             (i3c_standby_en),
      .bus_i                (ctrl_bus_i),
      .is_in_hdr_mode_i     (is_in_hdr_mode),
      .hdr_exit_detect_o    (hdr_exit_detect),
      .target_reset_detect_o(target_reset_detect)
  );

  bus_timers xbus_timers (
      .clk_i,
      .rst_ni,
      .enable_i         (i3c_standby_en),
      .restart_counter_i(ctrl_bus_i.stop_det),
      .t_bus_free_i     (t_bus_free_i),
      .t_bus_idle_i     (t_bus_idle_i),
      .t_bus_available_i(t_bus_available_i),
      .bus_busy_o       (bus_busy),
      .bus_free_o       (bus_free),
      .bus_idle_o       (bus_idle),
      .bus_available_o  (bus_available)
  );

  descriptor_rx #(
      .TtiRxDescDataWidth(TtiRxDescDataWidth),
      .TtiRxDataWidth    (TtiRxDataWidth)
  ) xdescriptor_rx (
      .clk_i                     (clk_i),
      .rst_ni                    (rst_ni),
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
      .rx_byte_err_i             ('0)                       // FIXME
  );

  descriptor_tx #(
      .TtiTxDescDataWidth  (TtiTxDescDataWidth),
      .TtiTxDataWidth      (TtiTxDataWidth),
      .TtiTxFifoDepthWidth (TtiTxFifoDepthWidth)
  ) xdescriptor_tx (
      .clk_i                     (clk_i),
      .rst_ni                    (rst_ni),
      .tti_tx_desc_queue_rvalid_i(tx_desc_queue_rvalid_i),
      .tti_tx_desc_queue_rready_o(tx_desc_queue_rready_o),
      .tti_tx_desc_queue_rdata_i (tx_desc_queue_rdata_i),
      .tti_tx_queue_rvalid_i     (tx_queue_rvalid_i),
      .tti_tx_queue_depth_i      (tx_queue_depth_i),
      .tti_tx_queue_rready_o     (tx_queue_rready_o),
      .tti_tx_queue_rdata_i      (tx_queue_rdata_i),
      .tti_tx_queue_empty_i      (tx_queue_empty_i),
      .tx_queue_flush_o          (tx_queue_flush_o),
      .tx_start_i                (tx_pr_start_o),
      .tx_abort_i                (tx_pr_abort | tx_host_nack),
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
      .clk_i             (clk_i),
      .rst_ni            (rst_ni),
      .ibi_queue_full_i  (ibi_queue_full_i),
      .ibi_queue_empty_i (ibi_queue_empty_i),
      .ibi_queue_rvalid_i(ibi_queue_rvalid_i),
      .ibi_queue_depth_i (ibi_queue_depth_i),
      .ibi_queue_rready_o(ibi_queue_rready_o),
      .ibi_queue_rdata_i (ibi_queue_rdata_i),
      .ibi_byte_valid_o  (ibi_fifo_rvalid),
      .ibi_byte_ready_i  (ibi_fifo_rready),
      .ibi_byte_o        (ibi_fifo_rdata),
      .ibi_byte_last_o   (ibi_last_byte),
      .ibi_byte_err_i    ('0)                   // FIXME
  );

  assign tx_host_nack_o = tx_host_nack;

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
