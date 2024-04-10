// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

module i3c_phy
  import i3c_phy_pkg::*;
(
    input logic clk,
    input logic rst_n,

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
    output logic ctrl_sda_o,

    input logic arbitration_en_i,
    output i3c_phy_err_t phy_err_o
);

  // Synchronized bus lines
  logic scl_sync;
  logic sda_sync;

  // Synchronized controller lines
  logic scl_en_int;
  logic sda_en_int;
  logic arbitration_en_sync;

  // Bus errors
  logic bus_sda_err;
  logic bus_scl_err;

  wire scl_en_sync, sda_en_sync;

  assign scl_en_o = scl_en_sync;
  assign sda_en_o = sda_en_sync;

  assign phy_err_o.interference_scl_err_o = arbitration_en_sync & bus_scl_err;
  assign phy_err_o.interference_sda_err_o = arbitration_en_sync & bus_sda_err;

  // Assert bus lines LOW and control them via enable signals to reproduce
  // Open Drain as a tri-state in FPGA
  assign scl_o = 1'b0;
  assign sda_o = 1'b0;

  assign scl_en_int = ~ctrl_scl_i;
  assign sda_en_int = ~ctrl_sda_i;

  assign ctrl_scl_o = scl_en_sync ? 1'b0 : scl_sync;
  assign ctrl_sda_o = sda_en_sync ? 1'b0 : sda_sync;

  // Synchronize SCL to system clock
  dff_2sync scl_synchronizer (
      .clk  (clk),
      .rst_n(rst_n),
      .d_i  (scl_i),
      .q_o  (scl_sync)
  );

  // Synchronize SDA to system clock
  dff_2sync sda_synchronizer (
      .clk  (clk),
      .rst_n(rst_n),
      .d_i  (sda_i),
      .q_o  (sda_sync)
  );

  // Synchronize SCL enable
  dff_2sync scl_en_int_synchronizer (
      .clk  (clk),
      .rst_n(rst_n),
      .d_i  (scl_en_int),
      .q_o  (scl_en_sync)
  );

  // Synchronize SDA enable
  dff_2sync sda_en_int_synchronizer (
      .clk  (clk),
      .rst_n(rst_n),
      .d_i  (sda_en_int),
      .q_o  (sda_en_sync)
  );

  // Synchronize arbitration enable
  dff_2sync arbitration_en_synchronizer (
      .clk  (clk),
      .rst_n(rst_n),
      .d_i  (arbitration_en_i),
      .q_o  (arbitration_en_sync)
  );

  // Report bus error if bus has different value than driven
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      bus_scl_err <= 1'b0;
      bus_sda_err <= 1'b0;
    end else begin
      bus_scl_err <= ctrl_scl_i & ~scl_sync;
      bus_sda_err <= ctrl_sda_i & ~sda_sync;
    end
  end

endmodule
