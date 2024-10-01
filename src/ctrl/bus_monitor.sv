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

    // TODO: Refactor signals to `state_detected` to clarify purpose
    output logic start_detect_o,  // Module detected START or REPEATED START condition
    output logic stop_detect_o,   // Module detected STOP condition

    input is_in_hdr_mode_i,       // Module is in HDR mode
    output hdr_exit_detect_o      // Detected HDR exit condition (see: 5.2.1.1.1 of the base spec)
 );
  logic enable, enable_q;

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
  logic [13:0] ctrl_det_count;

  // FFs for HDR exit condition detection
  logic [4:0] hdr_exit_det_count;
  logic hdr_exit_det_pending;
  logic hdr_exit_det_trigger;
  logic detected_hdr_exit;
  logic hdr_exit_det;

  assign enable = enable_i;

  edge_detector #(.DETECT_NEGEDGE(1'b1))
  edge_detector_scl_negedge (
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

  edge_detector #(.DETECT_NEGEDGE(1'b1))
  edge_detector_sda_negedge (
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

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      enable_q <= 1'b0;
    end else begin
      enable_q <= enable;
    end
  end

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

  // Start and Stop detection

  // Note that this counter combines Start and Stop detection into one
  // counter. A controller-only reset scenario could end up with a Stop
  // following shortly after a Start, with the requisite setup time not
  // observed.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ctrl_det_count <= '0;
    end else if (start_det_trigger || stop_det_trigger) begin
      ctrl_det_count <= 14'd1;
    end else if (start_det_pending || stop_det_pending) begin
      ctrl_det_count <= ctrl_det_count + 1'b1;
    end
  end

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

  // exit HDR detection
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      hdr_exit_det_count <= 5'b10000;
      hdr_exit_det_pending <= 1'b0;
      detected_hdr_exit <= 1'b0;
    end else if (hdr_exit_det_trigger) begin
      hdr_exit_det_pending <= 1'b1;
    end else if (!enable || stop_det) begin
      hdr_exit_det_count <= 5'b10000;
      hdr_exit_det_pending <= 1'b0;
    end else if (enable && hdr_exit_det_pending && sda_negedge) begin
      hdr_exit_det_count <= {1'b0, hdr_exit_det_count[4:1]};
    end
  end
  // hdr_exit detection by target
  assign hdr_exit_det = enable & hdr_exit_det_count[0] & stop_det;
  assign hdr_exit_det_trigger = scl_stable_low && sda_stable_high && is_in_hdr_mode_i;

  // (Repeated) Start condition detection by target
  assign start_det_trigger = enable & scl_stable_high & sda_negedge;
  assign start_det = enable & start_det_pending & (ctrl_det_count >= 14'(t_hd_dat_i));

  // Stop condition detection by target
  assign stop_det_trigger = enable & scl_stable_high & sda_posedge;
  assign stop_det = enable & stop_det_pending & (ctrl_det_count >= 14'(t_hd_dat_i));

  assign start_detect_o = start_det;
  assign stop_detect_o = stop_det;
  assign hdr_exit_detect_o = hdr_exit_det;

endmodule
