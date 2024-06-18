// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

module i3c_phy_4to1_mux (
    // Select
    input logic [1:0] select_i,

    // To Phy
    input logic phy_scl_i,
    input logic phy_sda_i,

    output logic phy_scl_o,
    output logic phy_sda_o,

    // To 4 Controllers
    input logic ctrl_scl_i[4],
    input logic ctrl_sda_i[4],

    output logic ctrl_scl_o[4],
    output logic ctrl_sda_o[4]
);

  always_comb begin
    phy_scl_o = ctrl_scl_i[select_i];
    phy_sda_o = ctrl_sda_i[select_i];
    ctrl_scl_o[select_i] = phy_scl_i;
    ctrl_sda_o[select_i] = phy_sda_i;
  end


endmodule
