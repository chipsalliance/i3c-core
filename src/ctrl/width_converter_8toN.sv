// SPDX-License-Identifier: Apache-2.0

/*
    Bus width converter from 8-bit to N-bit (N is a multiple of 8)

    This module implements data width converter to be used to pack 8-bit data
    receiver over I3C into N-bit words to be stored in TTI RX queue.
    The module has a "flush" capability which allows it to output partially
    assembled N-bit words on request.
*/

module width_converter_8toN #(
    parameter int unsigned Width = 32
) (

    input logic clk_i,
    input logic rst_ni,

    input  logic       sink_valid_i,
    output logic       sink_ready_o,
    input  logic [7:0] sink_data_i,
    input  logic       sink_flush_i,

    output logic             source_valid_o,
    input  logic             source_ready_i,
    output logic [Width-1:0] source_data_o
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
      if ((bcnt != '0) & sink_flush_i) bcnt <= Bytes;
      else if ((bcnt != Bytes) & sink_valid_i & sink_ready_o) bcnt <= bcnt + 1;
      else if ((bcnt == Bytes) & source_valid_o & source_ready_i) bcnt <= '0;
    end

  // Valid / ready
  assign sink_ready_o   = (bcnt != Bytes);
  assign source_valid_o = (bcnt == Bytes);

  // Data register
  logic [Width-1:0] sreg;

  always_ff @(posedge clk_i)
    if (!rst_ni) sreg <= '0;
    else begin
      if ((bcnt != Bytes) & sink_valid_i & sink_ready_o) sreg[bcnt*8+:8] <= sink_data_i;
      else if ((bcnt == Bytes) & source_valid_o & source_ready_i)
        sreg <= '0;  // Clear the reg not to leak data
    end

  // Data output
  assign source_data_o = sreg;

endmodule
