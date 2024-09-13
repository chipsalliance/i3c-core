// SPDX-License-Identifier: Apache-2.0

// Bus width converter from 8-bit to N-bit
module width_converter_8toN #(
    parameter int unsigned Width = 32
) (

    input logic clk_i,
    input logic rst_ni,

    input  logic       in_valid_i,
    output logic       in_ready_o,
    input  logic [7:0] in_data_i,
    input  logic       in_flush_i,

    output logic             out_valid_o,
    input  logic             out_ready_i,
    output logic [Width-1:0] out_data_o
);

  // Number of bytes of wider data bus
  localparam int unsigned Bytes = (Width + 7) / 8;

  // Byte counter
  logic [$clog2(Bytes):0] bcnt;

  always_ff @(posedge clk_i)
    if (!rst_ni) bcnt <= 0;
    else begin
      if ((bcnt != 0) & in_flush_i) bcnt <= Bytes;
      else if ((bcnt != Bytes) & in_valid_i & in_ready_o) bcnt <= bcnt + 1;
      else if ((bcnt == Bytes) & out_valid_o & out_ready_i) bcnt <= 0;
    end

  // Valid / ready
  assign in_ready_o  = (bcnt != Bytes);
  assign out_valid_o = (bcnt == Bytes);

  // Data register
  logic [Width-1:0] sreg;

  always_ff @(posedge clk_i)
    if (!rst_ni) sreg <= {Width{1'b0}};
    else begin
      if ((bcnt != Bytes) & in_valid_i & in_ready_o) sreg[bcnt*8+:8] <= in_data_i;
      else if ((bcnt == Bytes) & out_valid_o & out_ready_i)
        sreg <= {Width{1'b0}};  // Clear the reg not to leak data
    end

  // Data output
  assign out_data_o = sreg;

endmodule
