// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

/*
  Combined model of the Open-Drain Driver and Push-Pull Driver for the I3C bus lines.

  | sel_driver_i | phy_data_i | phy_data_io |
  |            0 |          0 |           z |
  |            0 |          1 |           0 |
  |            1 |          0 |           0 |
  |            1 |          1 |           1 |
*/
module bufs (
    input logic phy_data_i,
    input logic sel_od_pp_i,
    inout wire  phy_data_io
);

  logic phy_data_i_z;

  assign phy_data_i_z = ~phy_data_i;

  logic buf_pp_o, buf_od_o;

  // Model of a Push-Pull driver
  buf_pp xbuf_pp (
      .pull_up_en(phy_data_i),
      .pull_down_en(phy_data_i_z),
      .buf_pp_o(buf_pp_o)
  );

  // Model of an Open-Drain driver
  buf_od xbuf_od (
      .drive_low(phy_data_i),
      .buf_od_o (buf_od_o)
  );

  // Mux between OD and PP
  assign phy_data_io = sel_od_pp_i ? buf_pp_o : buf_od_o;

endmodule
