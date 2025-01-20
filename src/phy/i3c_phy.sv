// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

/*
    This module provides double flip-flop synchronization to the system clock.
*/
module i3c_phy (
    input logic clk_i,
    input logic rst_ni,

    // I3C bus IO
    input  logic scl_i,
    output logic scl_o,

    input  logic sda_i,
    output logic sda_o,

    // I3C controller IO
    input logic ctrl_scl_i,
    input logic ctrl_sda_i,

    output logic ctrl_scl_o,
    output logic ctrl_sda_o,

    // Open-Drain / Push-Pull control
    input  logic sel_od_pp_i,
    output logic sel_od_pp_o
);

  // Synchronize SCL to system clock
  caliptra_prim_flop_2sync #(
      .Width(1),
      .ResetValue(1)
  ) scl_synchronizer (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .d_i(scl_i),
      .q_o(ctrl_scl_o)
  );

  // Synchronize SDA to system clock
  caliptra_prim_flop_2sync #(
      .Width(1),
      .ResetValue(1)
  ) sda_synchronizer (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .d_i(sda_i),
      .q_o(ctrl_sda_o)
  );

  assign sda_o = ctrl_sda_i;
  assign scl_o = ctrl_scl_i;
  assign sel_od_pp_o = sel_od_pp_i;

endmodule
