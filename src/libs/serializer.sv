// SPDX-License-Identifier: Apache-2.0

module serializer
  import i3c_ctrl_pkg::*;
#(
    parameter int DATA_W = 9
) (
    input logic clk,
    input logic rst_n,
    input logic load,
    input logic enable,
    input logic [DATA_W-1:0] data,
    output logic q
);

  logic [DATA_W-1:0] sr;

  always_ff @(posedge clk or negedge rst_n) begin : proc_fsm
    if (!rst_n) begin
      sr <= '0;
    end else begin
      if (load) begin
        sr <= data;
      end else begin
        if (enable) begin
          sr[DATA_W-1]   <= '0;
          sr[DATA_W-2:0] <= sr[DATA_W-1:1];
        end
      end
    end
  end

  assign q = sr[0];

endmodule
