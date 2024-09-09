// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

/*
  Model of an Open-Drain Driver

  | drive_low | out |
  |         0 | z   |
  |         1 | 0   |
*/
module buf_od (
    input logic drive_low,
    inout logic buf_od_o
);

  assign buf_od_o = drive_low ? 1'b0 : 1'bz;

endmodule
