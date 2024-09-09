// SPDX-License-Identifier: Apache-2.0

module i3c_controller_fsm
  import controller_pkg::*;
  import i3c_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    // Interface to SDA/SCL
    input  logic ctrl_scl_i,
    input  logic ctrl_sda_i,
    output logic ctrl_scl_o,
    output logic ctrl_sda_o
);

  // TODO: Implement, skipped in first round
  always_comb begin
    ctrl_sda_o = '1;
    ctrl_scl_o = '1;
  end

endmodule
