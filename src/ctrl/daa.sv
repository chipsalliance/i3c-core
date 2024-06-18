// SPDX-License-Identifier: Apache-2.0

// TODO: Consider arbitration difference from i2c:
// Section 5.1.4
// 48b provisioned id and bcr, dcr are used.
// This is to enable dynamic addressing.

module daa
  import controller_pkg::*;
  import i3c_pkg::*;
#(
    parameter int TEMP = 0
) (
    input logic clk_i,
    input logic rst_ni,

    // Check bus_addr for matching address
    input logic [6:0] bus_addr,
    output logic is_sta_addr_match,
    output logic is_dyn_addr_match,
    output logic is_i3c_rsvd_addr_match,
    output logic is_any_addr_match,

    // Produce response for ENTDAA
    input  [31:0] stby_cr_device_addr_reg,
    input  [31:0] stby_cr_device_char_reg,
    input  [31:0] stby_cr_device_pid_lo_reg,
    output [63:0] daa_unique_response
);

  // Address matching
  logic [6:0] target_sta_addr;
  logic [6:0] target_dyn_addr;
  assign target_sta_addr_valid = stby_cr_device_addr_reg[15];
  assign target_sta_addr = stby_cr_device_addr_reg[6:0];

  assign target_dyn_addr_valid = stby_cr_device_addr_reg[31];
  assign target_dyn_addr = stby_cr_device_addr_reg[22:16];

  assign is_sta_addr_match = (bus_addr == target_sta_addr) & target_sta_addr_valid;
  assign is_dyn_addr_match = (bus_addr == target_dyn_addr) & target_dyn_addr_valid;
  assign is_i3c_rsvd_addr_match = bus_addr == `I3C_RSVD_ADDR;
  assign is_any_addr_match = is_sta_addr_match || is_dyn_addr_match || is_i3c_rsvd_addr_match;

  // Dynamic Address Assignment
  // HCI, Section 7.7.11.5
  logic [47:0] pid;
  assign pid = {stby_cr_device_char_reg[15:1], 1'b0, stby_cr_device_pid_lo_reg};

  logic [7:0] bcr;
  logic [7:0] dcr;
  assign bcr = stby_cr_device_char_reg[31:24];
  assign dcr = stby_cr_device_char_reg[23:16];
  assign daa_unique_response = {pid, bcr, dcr};

endmodule
