// SPDX-License-Identifier: Apache-2.0

/*
  This module extracts fields related to addressing from CSRs.
*/

module addr_match
  import controller_pkg::*;
  import i3c_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    // CSRs
    input logic [31:0] stby_cr_device_addr_reg_i,
    input logic [31:0] stby_cr_device_char_reg_i,
    input logic [31:0] stby_cr_device_pid_lo_reg_i,

    output logic [47:0] pid_o, // Target ID
    output logic [7:0] bcr_o, // Bus Characteristics Register
    output logic [7:0] dcr_o, // Device Characteristics Register

    // Output effective target address (static or dynamic)
    output logic [6:0] target_sta_addr_o,
    output logic target_sta_addr_valid_o,
    output logic [6:0] target_dyn_addr_o,
    output logic target_dyn_addr_valid_o,
    output logic [6:0] target_ibi_addr_o,
    output logic target_ibi_addr_valid_o,

    // Hot-Join address is always valid
    output logic [6:0] target_hot_join_addr_o,

    // Response for ENTDAA
    output [63:0] daa_unique_response_o
);

  assign target_sta_addr_valid_o = stby_cr_device_addr_reg_i[15];
  assign target_sta_addr_o = stby_cr_device_addr_reg_i[6:0];

  assign target_dyn_addr_valid_o = stby_cr_device_addr_reg_i[31];
  assign target_dyn_addr_o = stby_cr_device_addr_reg_i[22:16];

  assign pid_o = {stby_cr_device_char_reg_i[15:1], 1'b0, stby_cr_device_pid_lo_reg_i};

  assign bcr_o = stby_cr_device_char_reg_i[31:24];
  assign dcr_o = stby_cr_device_char_reg_i[23:16];
  assign daa_unique_response_o = {pid_o, bcr_o, dcr_o};

  assign target_ibi_addr_o = target_dyn_addr_valid_o ? target_dyn_addr_o : target_sta_addr_o;
  assign target_ibi_addr_valid_o = target_sta_addr_valid_o || target_dyn_addr_valid_o;

  assign target_hot_join_addr_o = 7'h02;

endmodule
