// SPDX-License-Identifier: Apache-2.0
module bus_tx_flow_test_wrapper (
    input logic clk_i,
    input logic rst_ni,

    input scl_i,  // Additional signal for SCL bus mock

    // I3C bus timings
    input logic [19:0] t_r_i,      // rise time of both SDA and SCL in clock units
    input logic [12:0] t_f_i,      // rise time of both SDA and SCL in clock units
    input logic [19:0] t_su_dat_i,  // data setup time in clock units
    input logic [19:0] t_hd_dat_i,  // data hold time in clock units

    // Input I3C Bus events
    input logic scl_negedge_i,
    input logic scl_posedge_i,
    input logic scl_stable_low_i,

    // Bus flow control
    input logic req_byte_i,
    input logic req_bit_i,
    input logic [7:0] req_value_i,
    output logic bus_tx_done_o,
    output logic bus_tx_idle_o,
    output logic req_error_o,
    output logic bus_error_o,

    // Open Drain / Push Pull
    input logic  sel_od_pp_i,
    output logic sel_od_pp_o,

    output logic sda_o  // Output I3C SDA bus line
);
  bus_tx_flow xbus_tx_flow (.*);
endmodule
