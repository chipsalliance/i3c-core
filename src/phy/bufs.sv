// SPDX-License-Identifier: Apache-2.0

module bufs (
    input logic phy_data_i,
    output wire phy_data_o
);

  logic phy_data_i_z;

  assign phy_data_i_z = ~phy_data_i;

  // Model of a Push-Pull driver
  buf_pp xbuf_pp (
      .pull_up_en(phy_data_i),
      .pull_down_en(phy_data_i_z),
      .buf_pp_o(phy_data_o)
  );

endmodule
