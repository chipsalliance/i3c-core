// SPDX-License-Identifier: Apache-2.0

// This is a sample implementation of a counter
// q is high if we count down from init value to 0
// q is always low in reset state

module counter_template
  import i3c_ctrl_pkg::*;
#(
    parameter int CNTR_W = 9
) (
    input logic clk,
    input logic rst_n,
    input logic load,
    input logic [CNTR_W-1:0] init_value,
    output logic q
);

  logic [DATA_W-1:0] counter;

  always_ff @(posedge clk or negedge rst_n) begin : proc_fsm
    if (!rst_n) begin
      counter <= '0;
    end else begin
      if (load) begin
        counter <= init_value;
      end else begin
        counter <= counter - 1'b1;
      end
    end

  end

  assign q = (rst_n) & (counter == '0);

endmodule
