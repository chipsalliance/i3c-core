// SPDX-License-Identifier: Apache-2.0

/*
    Bus width converter from N-bit to 8-bit where N is a multiple of 8.

    The module implements data width converter to be used between TTI TX queue
    and I3C target FSM to send 8-bit data over the bus.
*/

module width_converter_Nto8 #(
    parameter int unsigned Width = 32
) (

    input logic clk_i,
    input logic rst_ni,

    input  logic             sink_valid_i,
    output logic             sink_ready_o,
    input  logic [Width-1:0] sink_data_i,

    output logic       source_valid_o,
    input  logic       source_ready_i,
    output logic [7:0] source_data_o
);

  // Ensure that Width is divisible by 8
  initial begin : param_check
    if ((Width % 8) != 0) $error("Width must be divisible by 8");
  end

  // Number of bytes of wider data bus
  localparam int unsigned Bytes = Width / 8;

  // Byte counter
  logic [$clog2(Bytes):0] bcnt;

  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) bcnt <= '0;
    else begin
      if ((bcnt == '0) & sink_valid_i & sink_ready_o) bcnt <= Bytes;
      else if ((bcnt != '0) & source_valid_o & source_ready_i) bcnt <= bcnt - 1;
    end

  // Valid / ready
  assign sink_ready_o   = (bcnt == '0);
  assign source_valid_o = (bcnt != '0);

  // Data register
  logic [Width-1:0] sreg;

  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) sreg <= '0;
    else begin
      if ((bcnt == '0) & sink_valid_i & sink_ready_o) sreg <= sink_data_i;
      else if ((bcnt != '0) & source_valid_o & source_ready_i) sreg <= sreg >> 8;
    end

  // Data output
  assign source_data_o = sreg[7:0];

endmodule
