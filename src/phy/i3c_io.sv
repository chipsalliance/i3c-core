// Copyright (c) 2024 Antmicro <www.antmicro.com>
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

module i3c_io (
    inout logic scl_io,
    input logic scl_i,
    input logic scl_en_i,

    inout logic sda_io,
    input logic sda_i,
    input logic sda_en_i
);

  assign scl_io = scl_en_i ? scl_i : 1'bz;
  assign sda_io = sda_en_i ? sda_i : 1'bz;

endmodule
