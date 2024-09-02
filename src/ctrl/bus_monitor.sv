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

    // TODO: Refactor signals to `state_detected` to clarify purpose
    output logic start_detect_o,  // Module detected START or REPEATED START condition
    output logic stop_detect_o    // Module detected STOP condition
);
  logic enable, enable_q;

  logic scl_negedge;
  logic scl_posedge;
  logic scl_edge;
  logic scl_stable_high;

  logic sda_negedge;
  logic sda_posedge;
  logic sda_edge;

  logic start_det_trigger, start_det_pending;
  logic start_det;  // indicates start or repeated start is detected on the bus
  logic stop_det_trigger, stop_det_pending;
  logic stop_det;  // indicates stop is detected on the bus
  // Stop / Start detection counter
  logic [13:0] ctrl_det_count;

  assign enable = enable_i;

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

  assign scl_negedge = scl_i_q && !scl_i;
  assign scl_posedge = !scl_i_q && scl_i;
  assign sda_negedge = sda_i_q && !sda_i;
  assign sda_posedge = !sda_i_q && sda_i;

  assign scl_edge = scl_negedge | scl_posedge;
  assign sda_edge = sda_negedge | sda_posedge;

  assign scl_stable_high = scl_i_q & scl_i;

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

  // (Repeated) Start condition detection by target
  assign start_det_trigger = enable & scl_stable_high & sda_negedge;
  assign start_det = enable & start_det_pending & (ctrl_det_count >= 14'(t_hd_dat_i));

  // Stop condition detection by target
  assign stop_det_trigger = enable & scl_stable_high & sda_posedge;
  assign stop_det = enable & stop_det_pending & (ctrl_det_count >= 14'(t_hd_dat_i));

  assign start_detect_o = start_det;
  assign stop_detect_o = stop_det;

endmodule
