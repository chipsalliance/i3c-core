// Copyright (c) 2024 Antmicro <www.antmicro.com>
// SPDX-License-Identifier: Apache-2.0

module i3c_phy_wrapper (
    input logic clk,
    input logic rst_n,

    // I3C bus IO
    inout logic scl_io,
    inout logic sda_io,

    // I3C controller IO
    input logic ctrl_scl_i,
    input logic ctrl_sda_i,

    output logic ctrl_scl_o,
    output logic ctrl_sda_o,
    output logic bus_err_o
);
  logic scl_i;
  logic scl_o;
  logic scl_en_o;

  logic sda_i;
  logic sda_o;
  logic sda_en_o;

  i3c_phy phy (.*);

  i3c_io phy_io (
      .scl_io(scl_io),
      .scl_i(scl_o),
      .scl_en_i(scl_en_o),

      .sda_io(sda_io),
      .sda_i(sda_o),
      .sda_en_i(sda_en_o),
  );
endmodule
