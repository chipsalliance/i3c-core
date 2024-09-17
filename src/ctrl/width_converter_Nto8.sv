// SPDX-License-Identifier: Apache-2.0

/*
    Bus width converter from N-bit to 8-bit where N is a multiple of 8.

    The module implements data width coverter to be used between TTI TX queue
    and I3C target FSM to send 8-bit data over the bus.
*/

module width_converter_Nto8 #(
    parameter int unsigned Width = 32
) (

    input logic clk_i,
    input logic rst_ni,

    input  logic             in_valid_i,
    output logic             in_ready_o,
    input  logic [Width-1:0] in_data_i,

    output logic       out_valid_o,
    input  logic       out_ready_i,
    output logic [7:0] out_data_o
);

  // Ensure that Width is divisible by 8
  initial begin : param_check
    if ((Width % 8) != 0) $error("Width must be divisible by 8");
  end

  // Number of bytes of wider data bus
  localparam int unsigned Bytes = Width / 8;

  // Byte counter
  logic [$clog2(Bytes):0] bcnt;

  always_ff @(posedge clk_i)
    if (!rst_ni) bcnt <= '0;
    else begin
      if ((bcnt == '0) & in_valid_i & in_ready_o) bcnt <= Bytes;
      else if ((bcnt != '0) & out_valid_o & out_ready_i) bcnt <= bcnt - 1;
    end

  // Valid / ready
  assign in_ready_o  = (bcnt == '0);
  assign out_valid_o = (bcnt != '0);

  // Data register
  logic [Width-1:0] sreg;

  always_ff @(posedge clk_i)
    if (!rst_ni) sreg <= '0;
    else begin
      if ((bcnt == '0) & in_valid_i & in_ready_o) sreg <= in_data_i;
      else if ((bcnt != '0) & out_valid_o & out_ready_i) sreg <= sreg >> 8;
    end

  // Data output
  assign out_data_o = sreg[7:0];

endmodule
