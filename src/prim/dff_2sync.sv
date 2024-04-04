// Copyright (c) 2024 Antmicro <www.antmicro.com>
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

// TODO: Use Caliptra primitives
module dff_2sync (
    input clk,
    input rst_n,
    input d_i,
    output logic q_o
);

  logic d_r;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      d_r <= 1'b0;
      q_o <= 1'b0;
    end else begin
      d_r <= d_i;
      q_o <= d_r;
    end
  end

endmodule
