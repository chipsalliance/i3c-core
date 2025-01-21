// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//

/*
I3C bus monitor. Detects HDR exit pattern and reset pattern
*/
module i3c_bus_monitor
  import i3c_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input logic enable_i,

    // Bus state
    bus_state_t bus_i,

    input logic is_in_hdr_mode_i,  // Module is in HDR mode
    output logic hdr_exit_detect_o,     // Detected HDR exit condition (see: 5.2.1.1.1 of the base spec)
    output logic target_reset_detect_o  // Detected Target Reset condtition
);
  // FFs for HDR exit condition detection
  logic [4:0] hdr_exit_det_count;
  logic hdr_exit_det_pending;
  logic hdr_exit_det_trigger;
  logic hdr_exit_det;

  // exit HDR detection
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      hdr_exit_det_count   <= 5'b10000;
      hdr_exit_det_pending <= 1'b0;
    end else if (hdr_exit_det_trigger) begin
      hdr_exit_det_pending <= 1'b1;
    end else if (!enable_i || bus_i.stop_det) begin
      hdr_exit_det_count   <= 5'b10000;
      hdr_exit_det_pending <= 1'b0;
    end else if (enable_i && hdr_exit_det_pending && bus_i.sda.neg_edge) begin
      hdr_exit_det_count <= {1'b0, hdr_exit_det_count[4:1]};
    end
  end

  // hdr_exit detection by target
  assign hdr_exit_det = enable_i & hdr_exit_det_count[0] & bus_i.stop_det;
  assign hdr_exit_det_trigger = bus_i.scl.stable_low && bus_i.sda.stable_high && is_in_hdr_mode_i;

  target_reset_detector target_reset_detector (
      .clk_i,
      .rst_ni,
      .enable_i,
      .scl_high(bus_i.scl.stable_high),
      .scl_low(bus_i.scl.stable_low),
      .scl_negedge(bus_i.scl.neg_edge),
      .sda_posedge(bus_i.sda.pos_edge),
      .sda_negedge(bus_i.sda.neg_edge),
      .start_detected_i(bus_i.start_det),
      .stop_detected_i(bus_i.stop_det),
      .target_reset_detect_o
  );

  assign hdr_exit_detect_o = hdr_exit_det;

endmodule
