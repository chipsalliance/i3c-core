// SPDX-License-Identifier: Apache-2.0

/*
  Detect that signal line_i is stable and HIGH for at
  least delay_count_i cycles.
*/
module stable_high_detector
  import controller_pkg::*;
#(
    parameter int CNTR_W = 20
) (
    input logic clk_i,
    input logic rst_ni,
    input logic line_i,
    input logic [CNTR_W-1:0] delay_count_i,
    output logic stable_o
);
  logic [CNTR_W-1:0] count;
  logic do_count;
  logic line;
  logic stable_internal;

  assign stable_o = (delay_count_i == 0) ? line_i : stable_internal;
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      line <= '0;
    end else begin
      line <= line_i;
    end
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      count <= '0;
    end else if (line && do_count) begin
      count <= count + 1'b1;
    end else if (!line) begin
      count <= '0;
    end
  end

  always_comb begin
    do_count = '1;
    stable_internal = '0;
    if (count > delay_count_i) begin
      do_count = '0;
      stable_internal = line;
    end
  end
endmodule
