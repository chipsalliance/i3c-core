// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

module i3c_phy (
    input logic clk_i,
    input logic rst_ni,

    // I3C bus IO
    input  logic scl_i,
    output logic scl_o,
    output logic scl_en_o,

    input  logic sda_i,
    output logic sda_o,
    output logic sda_en_o,

    // I3C controller IO
    input logic ctrl_scl_i,
    input logic ctrl_sda_i,

    output logic ctrl_scl_o,
    output logic ctrl_sda_o
);

  // Synchronized bus lines
  logic scl_sync;
  logic sda_sync;

  // Synchronized controller lines
  logic scl_en_int;
  logic sda_en_int;

  wire scl_en_sync, sda_en_sync;

  assign scl_en_o = scl_en_sync;
  assign sda_en_o = sda_en_sync;

  // Assert bus lines LOW and control them via enable signals to reproduce
  // Open Drain as a tri-state in FPGA
  assign scl_o = 1'b0;
  assign sda_o = 1'b0;

  assign scl_en_int = ~ctrl_scl_i;
  assign sda_en_int = ~ctrl_sda_i;

  assign ctrl_scl_o = scl_en_sync ? 1'b0 : scl_sync;
  assign ctrl_sda_o = sda_en_sync ? 1'b0 : sda_sync;

  // Synchronize SCL to system clock
  caliptra_prim_flop_2sync #(
      .Width(1)
  ) scl_synchronizer (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .d_i(scl_i),
      .q_o(scl_sync)
  );

  // Synchronize SDA to system clock
  caliptra_prim_flop_2sync #(
      .Width(1)
  ) sda_synchronizer (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .d_i(sda_i),
      .q_o(sda_sync)
  );

  // Synchronize SCL enable
  caliptra_prim_flop_2sync #(
      .Width(1)
  ) scl_en_int_synchronizer (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .d_i(scl_en_int),
      .q_o(scl_en_sync)
  );

  // Synchronize SDA enable
  caliptra_prim_flop_2sync #(
      .Width(1)
  ) sda_en_int_synchronizer (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .d_i(sda_en_int),
      .q_o(sda_en_sync)
  );

endmodule
