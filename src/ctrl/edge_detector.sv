// SPDX-License-Identifier: Apache-2.0

/*
  This module implements logic to detect edges on the SDA and SCL lines,
  respecting timings
*/

module edge_detector
  import controller_pkg::*;
#(
    parameter int CNTR_W = 20,
    parameter logic INVERT_DETECTION = 1'b0
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
  assign detect_line = line ^ INVERT_DETECTION;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      count <= {CNTR_W{1'b0}};
      detect <= 1'b0;
    end else if (trigger) begin
      check_in_progress <= 1'b1;
      count <= {CNTR_W{1'b0}};
    end else if(check_in_progress && detect_line) begin
      count <= count + 1'b1;
      if (count >= delay_count) begin
        check_in_progress <= 1'b0;
        detect <= 1'b1;
      end
    end else begin
      detect <= 1'b0;
    end
  end

endmodule
