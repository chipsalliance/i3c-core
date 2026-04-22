// SPDX-License-Identifier: Apache-2.0

/*
  This module implements logic to detect bus events: START, STOP, REPEATED START.
*/
module bus_monitor
  import i3c_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input logic enable_i,  // Enable

    input logic scl_i,  // Bus SCL
    input logic sda_i,  // Bus SDA

    input logic [i3c_pkg::TimingWidth-1:0] t_hd_dat_i,  // Data hold time
    input logic [i3c_pkg::TimingWidth-1:0] t_r_i,       // Rise time
    input logic [i3c_pkg::TimingWidth-1:0] t_f_i,       // Fall time

    // HDR mode gating: when high, state_o signals are gated
    input logic in_hdr_mode_i,

    // Gated output: all signals masked during HDR mode
    output bus_state_t state_o,

    // Ungated output: only contains signals needed for HDR exit detection
    output bus_state_t hdr_exit_state_o
);
  logic enable;

  logic scl;
  logic scl_negedge_i;
  logic scl_posedge_i;
  logic scl_negedge;
  logic scl_posedge;
  logic scl_stable_high;
  logic scl_stable_low;
  logic scl_internal;

  logic sda;
  logic sda_negedge;
  logic sda_posedge;
  logic sda_negedge_i;
  logic sda_posedge_i;
  logic sda_stable_high;
  logic sda_stable_low;
  logic sda_internal;


  logic start_det_trigger, start_det_pending;
  logic start_det;  // indicates start or repeated start is detected on the bus
  logic stop_det_trigger, stop_det_pending;
  logic stop_det;  // indicates stop is detected on the bus

  logic rstart_detection_en;

  assign enable = enable_i;

  // Gate inputs: when disabled, force bus to appear idle (high)
  assign scl_internal = enable ? scl_i : 1'b1;
  assign sda_internal = enable ? sda_i : 1'b1;

  // SDA and SCL at the previous clock edge
  logic scl_i_q, sda_i_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : bus_prev
    if (!rst_ni) begin
      scl_i_q <= 1'b1;
      sda_i_q <= 1'b1;
    end else begin
      scl_i_q <= scl_internal;
      sda_i_q <= sda_internal;
    end
  end

  assign scl_negedge_i = scl_i_q && !scl_internal;
  assign scl_posedge_i = !scl_i_q && scl_internal;
  assign sda_negedge_i = sda_i_q && !sda_internal;
  assign sda_posedge_i = !sda_i_q && sda_internal;


  logic simultaneous_posedge, simultaneous_negedge;
  assign simultaneous_posedge = sda_posedge && scl_posedge;
  assign simultaneous_negedge = sda_negedge && scl_negedge;

  edge_detector #(
      .DETECT_NEGEDGE(1'b1)
  ) edge_detector_scl_negedge (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .trigger(scl_negedge_i),
      .line(scl_i_q),
      .delay_count(t_f_i),
      .detect(scl_negedge)
  );

  edge_detector edge_detector_scl_posedge (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .trigger(scl_posedge_i),
      .line(scl_i_q),
      .delay_count(t_r_i),
      .detect(scl_posedge)
  );

  edge_detector #(
      .DETECT_NEGEDGE(1'b1)
  ) edge_detector_sda_negedge (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .trigger(sda_negedge_i),
      .line(sda_i_q),
      .delay_count(t_f_i),
      .detect(sda_negedge)
  );

  edge_detector edge_detector_sda_posedge (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .trigger(sda_posedge_i),
      .line(sda_i_q),
      .delay_count(t_r_i),
      .detect(sda_posedge)
  );

  stable_high_detector stable_detector_sda_high (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .line_i(sda_i_q),
      .delay_count_i(t_r_i),
      .stable_o(sda_stable_high)
  );

  stable_high_detector stable_detector_scl_high (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .line_i(scl_i_q),
      .delay_count_i(t_r_i),
      .stable_o(scl_stable_high)
  );

  stable_high_detector stable_detector_scl_low (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .line_i(!scl_i_q),
      .delay_count_i(t_f_i),
      .stable_o(scl_stable_low)
  );

  stable_high_detector stable_detector_sda_low (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .line_i(!sda_i_q),
      .delay_count_i(t_f_i),
      .stable_o(sda_stable_low)
  );

  // Synchronize input SDA/SCL to edge detectors
  logic sda_r;
  logic scl_r;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sda_r <= '1;
    end else begin
      if (sda_posedge) begin
        sda_r <= '1;
      end else if (sda_negedge) begin
        sda_r <= '0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      scl_r <= '1;
    end else begin
      if (scl_posedge) begin
        scl_r <= '1;
      end else if (scl_negedge) begin
        scl_r <= '0;
      end
    end
  end

  assign sda = sda_r | sda_posedge;
  assign scl = scl_r | scl_posedge;

  // Start and Stop detection
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      start_det_pending <= 1'b0;
    end else if (start_det_trigger) begin
      start_det_pending <= 1'b1;
    end else if (!enable || !scl || start_det || stop_det_trigger) begin
      start_det_pending <= 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      stop_det_pending <= 1'b0;
    end else if (stop_det_trigger) begin
      stop_det_pending <= 1'b1;
    end else if (!enable || !scl || stop_det || start_det_trigger) begin
      stop_det_pending <= 1'b0;
    end
  end

  // START/Repeated START distinction
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      rstart_detection_en <= '0;
    end else begin
      if (stop_det) begin
        rstart_detection_en <= '0;
      end else if (start_det) begin
        rstart_detection_en <= '1;
      end
    end
  end

  // (Repeated) Start condition detection by target
  assign start_det_trigger = enable & scl_stable_high & sda_negedge & !scl_negedge & !simultaneous_negedge;
  assign start_det = enable & start_det_pending;

  // Stop condition detection by target
  assign stop_det_trigger = enable & scl_stable_high & sda_posedge & !scl_negedge & !simultaneous_posedge;
  assign stop_det = enable & stop_det_pending;

  // Detection output

  // Gated output: all signals masked during HDR mode to prevent false
  // START/STOP/RSTART detection from corrupting bus_timers and FSM state
  assign state_o.sda.value          = sda          & ~in_hdr_mode_i;
  assign state_o.sda.pos_edge       = sda_posedge  & ~in_hdr_mode_i;
  assign state_o.sda.neg_edge       = sda_negedge  & ~in_hdr_mode_i;
  assign state_o.sda.stable_high    = sda_stable_high & ~in_hdr_mode_i;
  assign state_o.sda.stable_low     = sda_stable_low & ~in_hdr_mode_i;

  assign state_o.scl.value          = scl          & ~in_hdr_mode_i;
  assign state_o.scl.pos_edge       = scl_posedge  & ~in_hdr_mode_i;
  assign state_o.scl.neg_edge       = scl_negedge  & ~in_hdr_mode_i;
  assign state_o.scl.stable_high    = scl_stable_high & ~in_hdr_mode_i;
  assign state_o.scl.stable_low     = scl_stable_low  & ~in_hdr_mode_i;

  assign state_o.start_det  = start_det & ~rstart_detection_en & ~in_hdr_mode_i;
  assign state_o.rstart_det = start_det &  rstart_detection_en & ~in_hdr_mode_i;
  assign state_o.stop_det   = stop_det  & ~in_hdr_mode_i;

  // Ungated output: provides signals needed for HDR exit pattern detection
  // All signals are passed through ungated
  assign hdr_exit_state_o.sda.value       = sda;
  assign hdr_exit_state_o.sda.pos_edge    = sda_posedge;
  assign hdr_exit_state_o.sda.neg_edge    = sda_negedge;
  assign hdr_exit_state_o.sda.stable_high = sda_stable_high;
  assign hdr_exit_state_o.sda.stable_low  = sda_stable_low;

  assign hdr_exit_state_o.scl.value       = scl;
  assign hdr_exit_state_o.scl.pos_edge    = scl_posedge;
  assign hdr_exit_state_o.scl.neg_edge    = scl_negedge;
  assign hdr_exit_state_o.scl.stable_high = scl_stable_high;
  assign hdr_exit_state_o.scl.stable_low  = scl_stable_low;

  assign hdr_exit_state_o.start_det  = start_det & ~rstart_detection_en;
  assign hdr_exit_state_o.rstart_det = start_det &  rstart_detection_en;
  assign hdr_exit_state_o.stop_det   = stop_det;

endmodule
