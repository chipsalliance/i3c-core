// SPDX-License-Identifier: Apache-2.0
module bus_rx_flow_test_wrapper (
    input logic clk_i,
    input logic rst_ni,

    input scl_i,  // Additional signal for SCL bus mock

    // I3C bus timings
    input logic [12:0] t_r_i,      // rise time of both SDA and SCL in clock units
    input logic [12:0] t_f_i,      // rise time of both SDA and SCL in clock units

    // Begin reading in data.
    // From now on, each SCL negedge is a data bit
    input logic scl_posedge_i,
    input logic scl_stable_high_i,
    input logic sda_i,

    input logic rx_req_bit_i,
    input logic rx_req_byte_i,
    output logic [7:0] rx_data_o,
    output logic rx_done_o,
    output logic rx_idle_o
);
  bus_rx_flow xbus_rx_flow (.*);
endmodule
