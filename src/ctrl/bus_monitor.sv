// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//

/*
  This module implements logic to detect bus events: START, STOP, REPEATED START.

  TODO: Arbitration detection:
    - Compare SCL/SDA that we want to drive with received value
*/

module bus_monitor
  import controller_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input logic enable_i,  // Enable

    input logic scl_i,  // Bus SCL (delayed by synchronization FFs)
    input logic sda_i,  // Bus SDA (delayed by synchronization FFs)

    input logic [19:0] t_hd_dat_i,  // Data hold time
    input logic [19:0] t_r_i,       // Rise time
    input logic [19:0] t_f_i,       // Fall time

    // SCL/SDA edge transitions
    output logic scl_negedge_o,
    output logic scl_posedge_o,
    output logic sda_negedge_o,
    output logic sda_posedge_o,

    // SCL stable states
    output logic scl_stable_low_o,
    output logic scl_stable_high_o,

    // TODO: Refactor signals to `state_detected` to clarify purpose
    output logic start_det_o,   // Module detected START condition
    output logic rstart_det_o,  // Module detected REPEATED START condition
    output logic stop_det_o,    // Module detected STOP condition

    input logic is_in_hdr_mode_i,  // Module is in HDR mode
    output logic hdr_exit_detect_o,     // Detected HDR exit condition (see: 5.2.1.1.1 of the base spec)
    output logic target_reset_detect_o  // Detected Target Reset condtition
);
  logic enable;

  logic scl_negedge_i;
  logic scl_posedge_i;
  logic scl_negedge;
  logic scl_posedge;
  logic scl_edge;
  logic scl_stable_high;
  logic scl_stable_low;

  logic sda_negedge;
  logic sda_posedge;
  logic sda_negedge_i;
  logic sda_posedge_i;
  logic sda_edge;
  logic sda_stable_high;

  logic start_det_trigger, start_det_pending;
  logic start_det;  // indicates start or repeated start is detected on the bus
  logic stop_det_trigger, stop_det_pending;
  logic stop_det;  // indicates stop is detected on the bus
  // Stop / Start detection counter
  logic [19:0] ctrl_det_count;

  // FFs for HDR exit condition detection
  logic [4:0] hdr_exit_det_count;
  logic hdr_exit_det_pending;
  logic hdr_exit_det_trigger;
  logic hdr_exit_det;

  logic rstart_detection_en;

  assign enable = enable_i;

  edge_detector #(
      .DETECT_NEGEDGE(1'b1)
  ) edge_detector_scl_negedge (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .trigger(scl_negedge_i),
      .line(scl_i),
      .delay_count(t_f_i),
      .detect(scl_negedge)
  );

  edge_detector edge_detector_scl_posedge (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .trigger(scl_posedge_i),
      .line(scl_i),
      .delay_count(t_r_i),
      .detect(scl_posedge)
  );

  edge_detector #(
      .DETECT_NEGEDGE(1'b1)
  ) edge_detector_sda_negedge (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .trigger(sda_negedge_i),
      .line(sda_i),
      .delay_count(t_f_i),
      .detect(sda_negedge)
  );

  edge_detector edge_detector_sda_posedge (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .trigger(sda_posedge_i),
      .line(sda_i),
      .delay_count(t_r_i),
      .detect(sda_posedge)
  );

  stable_high_detector stable_detector_sda_high (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .line_i(sda_i),
      .delay_count_i(t_r_i),
      .stable_o(sda_stable_high)
  );

  stable_high_detector stable_detector_scl_high (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .line_i(scl_i),
      .delay_count_i(t_r_i),
      .stable_o(scl_stable_high)
  );

  stable_high_detector stable_detector_scl_low (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .line_i(!scl_i),
      .delay_count_i(t_f_i),
      .stable_o(scl_stable_low)
  );

  // SDA and SCL at the previous clock edge
  logic scl_i_q, sda_i_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : bus_prev
    if (!rst_ni) begin
      scl_i_q <= 1'b1;
      sda_i_q <= 1'b1;
    end else begin
      scl_i_q <= scl_i;
      sda_i_q <= sda_i;
    end
  end

  assign scl_negedge_i = scl_i_q && !scl_i;
  assign scl_posedge_i = !scl_i_q && scl_i;
  assign sda_negedge_i = sda_i_q && !sda_i;
  assign sda_posedge_i = !sda_i_q && sda_i;

  assign scl_edge = scl_negedge | scl_posedge;
  assign sda_edge = sda_negedge | sda_posedge;

  logic simultaneous_posedge, simultaneous_negedge;
  assign simultaneous_posedge = sda_posedge && scl_posedge;
  assign simultaneous_negedge = sda_negedge && scl_negedge;

  // Start and Stop detection
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      start_det_pending <= 1'b0;
    end else if (start_det_trigger) begin
      start_det_pending <= 1'b1;
    end else if (!enable || !scl_i || start_det || stop_det_trigger) begin
      start_det_pending <= 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      stop_det_pending <= 1'b0;
    end else if (stop_det_trigger) begin
      stop_det_pending <= 1'b1;
    end else if (!enable || !scl_i || stop_det || start_det_trigger) begin
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

  // exit HDR detection
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      hdr_exit_det_count   <= 5'b10000;
      hdr_exit_det_pending <= 1'b0;
    end else if (hdr_exit_det_trigger) begin
      hdr_exit_det_pending <= 1'b1;
    end else if (!enable || stop_det) begin
      hdr_exit_det_count   <= 5'b10000;
      hdr_exit_det_pending <= 1'b0;
    end else if (enable && hdr_exit_det_pending && sda_negedge) begin
      hdr_exit_det_count <= {1'b0, hdr_exit_det_count[4:1]};
    end
  end
  // hdr_exit detection by target
  assign hdr_exit_det = enable & hdr_exit_det_count[0] & stop_det;
  assign hdr_exit_det_trigger = scl_stable_low && sda_stable_high && is_in_hdr_mode_i;

  // (Repeated) Start condition detection by target
  assign start_det_trigger = enable & scl_stable_high & sda_negedge & !simultaneous_negedge;
  assign start_det = enable & start_det_pending;

  // Stop condition detection by target
  assign stop_det_trigger = enable & scl_stable_high & sda_posedge & !simultaneous_posedge;
  assign stop_det = enable & stop_det_pending;

  assign start_det_o = start_det & ~rstart_detection_en;
  assign rstart_det_o = start_det & rstart_detection_en;
  assign stop_det_o = stop_det;
  assign hdr_exit_detect_o = hdr_exit_det;

  target_reset_detector target_reset_detector (
      .clk_i,
      .rst_ni,
      .enable_i,
      .scl_high(scl_stable_high),
      .scl_low(scl_stable_low),
      .scl_negedge,
      .sda_posedge,
      .sda_negedge,
      .start_detected_i(start_det),
      .stop_detected_i(stop_det),
      .target_reset_detect_o
  );
  assign scl_negedge_o = scl_negedge;
  assign scl_posedge_o = scl_posedge;
  assign sda_negedge_o = sda_negedge;
  assign sda_posedge_o = sda_posedge;

  assign scl_stable_low_o = scl_stable_low;
  assign scl_stable_high_o = scl_stable_high;
endmodule
