// SPDX-License-Identifier: Apache-2.0

// TODO: Consider arbitration difference from i2c:
// Section 5.1.4
// 48b provisioned id and bcr, dcr are used.
// This is to enable dynamic addressing.

module daa
  import i3c_ctrl_pkg::*;
#(
    parameter int TEMP = 0
) (
    input logic clk,
    input logic rst_n
);

  // TODO: Dynamic Adress Assignment 5.1.4

endmodule
