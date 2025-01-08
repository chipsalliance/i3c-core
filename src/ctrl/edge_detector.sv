// SPDX-License-Identifier: Apache-2.0

/*
  This module implements logic to detect edges on the SDA and SCL lines.

  A counter is used to measure time specified by the input `delay_count` signal.
  After `trigger` is asserted, the counter starts and can only advance if signal
  `line` is in high state (low state if DETECT_NEGEDGE == 1). Reassertion of
  `trigger` during this time causes the counter to reset. As a result, the
  output `detect` signal will be asserted only if `line` signal is stable for
  `delay_count` time since the assertion of the `trigger` signal.
*/

module edge_detector
  import controller_pkg::*;
#(
    parameter int CNTR_W = 20,
    parameter logic DETECT_NEGEDGE = 1'b0
) (
    input logic clk_i,
    input logic rst_ni,
    input logic trigger,
    input logic line,
    input logic [CNTR_W-1:0] delay_count,
    output logic detect
);

  logic [CNTR_W-1:0] count;
  logic check_in_progress;
  logic detect_line;
  logic detect_internal;
  assign detect_line = line ^ DETECT_NEGEDGE;
  assign detect = (delay_count == 0) ? trigger : detect_internal;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      count <= '0;
      check_in_progress <= 1'b0;
      detect_internal <= 1'b0;
    end else if (trigger) begin
      check_in_progress <= 1'b1;
      count <= '0;
    end else if (check_in_progress && detect_line) begin
      count <= count + 1'b1;
      if (count >= delay_count) begin
        check_in_progress <= 1'b0;
        detect_internal <= 1'b1;
      end
    end else begin
      detect_internal <= 1'b0;
    end
  end

endmodule
