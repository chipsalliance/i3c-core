// SPDX-License-Identifier: Apache-2.0
module bus_tx_flow_test_wrapper
  import i3c_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input scl_i,  // Additional signal for SCL bus mock

    // I3C bus timings -- No longer used in the actual DUT, but the cocotb env must reference them
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
    input logic req_ibi_i,
    input logic [7:0] req_value_i,
    input logic sel_od_pp_i,
    output logic bus_tx_done_o,
    output logic bus_tx_idle_o,
    output logic bus_tx_error_o,

    // Open Drain / Push Pull
    output logic sel_od_pp_o,

    output logic sda_o  // Output I3C SDA bus line
);

  // Map individual signals to struct
  bus_tx_req_t tx_req_i;
  bus_tx_rsp_t tx_rsp_o;

  assign tx_req_i.drive_type = sel_od_pp_i ? PushPull : OpenDrain;
  assign tx_req_i.req_byte   = req_byte_i;
  assign tx_req_i.req_bit    = req_bit_i;
  assign tx_req_i.req_ibi    = req_ibi_i;
  assign tx_req_i.data       = req_value_i;

  assign bus_tx_done_o  = tx_rsp_o.done;
  assign bus_tx_idle_o  = tx_rsp_o.idle;
  assign bus_tx_error_o = tx_rsp_o.error;

  bus_tx_flow xbus_tx_flow (
    .clk_i,
    .rst_ni,
    .scl_negedge_i,
    .scl_posedge_i,
    .scl_stable_low_i,
    .tx_req_i,
    .tx_rsp_o,
    .sel_od_pp_o,
    .sda_o
  );
endmodule
