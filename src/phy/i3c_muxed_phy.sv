// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

module i3c_muxed_phy (
    input logic clk_i,
    input logic rst_ni,
    // Select
    input logic [1:0] select_i,

    // I3C bus IO
    input  logic scl_i,
    output logic scl_o,
    output logic scl_en_o,

    input  logic sda_i,
    output logic sda_o,
    output logic sda_en_o,

    // To 4 Controllers
    input  logic ctrl_scl_i[4],
    input  logic ctrl_sda_i[4],
    output logic ctrl_scl_o[4],
    output logic ctrl_sda_o[4]
);

  logic mux_phy_scl;
  logic mux_phy_sda;
  logic phy_mux_scl;
  logic phy_mux_sda;

  // I3C PHY
  i3c_phy_4to1_mux xi3c_phy_4to1_mux (
      .select_i(select_i),

      .phy_scl_i(phy_mux_scl),
      .phy_sda_i(phy_mux_sda),
      .phy_scl_o(mux_phy_scl),
      .phy_sda_o(mux_phy_sda),

      .ctrl_scl_i(ctrl_scl_i),
      .ctrl_sda_i(ctrl_sda_i),
      .ctrl_scl_o(ctrl_scl_o),
      .ctrl_sda_o(ctrl_sda_o)
  );

  // I3C PHY
  i3c_phy xphy (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .scl_i(scl_i),
      .scl_o(scl_o),
      .scl_en_o(scl_en_o),

      .sda_i(sda_i),
      .sda_o(sda_o),
      .sda_en_o(sda_en_o),

      .ctrl_scl_i(mux_phy_scl),
      .ctrl_scl_o(phy_mux_scl),
      .ctrl_sda_i(mux_phy_sda),
      .ctrl_sda_o(phy_mux_sda)
  );


endmodule
