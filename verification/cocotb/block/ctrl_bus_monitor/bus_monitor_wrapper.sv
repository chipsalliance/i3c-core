module bus_monitor_wrapper
  import i3c_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input logic enable_i,  // Enable

    input logic scl_i,  // Bus SCL
    input logic sda_i,  // Bus SDA

    input logic [19:0] t_hd_dat_i,  // Data hold time
    input logic [19:0] t_r_i,       // Rise time
    input logic [19:0] t_f_i,       // Fall time

    output logic sda_o,
    output logic sda_posedge_o,
    output logic sda_negedge_o,
    output logic sda_stable_high_o,
    output logic sda_stable_low_o,

    output logic scl_o,
    output logic scl_posedge_o,
    output logic scl_negedge_o,
    output logic scl_stable_high_o,
    output logic scl_stable_low_o,

    output logic start_det_o,
    output logic rstart_det_o,
    output logic stop_det_o
);

  bus_state_t state;

  always_comb begin
    sda_o               = state.sda.value;
    sda_posedge_o       = state.sda.pos_edge;
    sda_negedge_o       = state.sda.neg_edge;
    sda_stable_low_o    = state.sda.stable_low;
    sda_stable_high_o   = state.sda.stable_high;

    scl_o               = state.scl.value;
    scl_posedge_o       = state.scl.pos_edge;
    scl_negedge_o       = state.scl.neg_edge;
    scl_stable_low_o    = state.scl.stable_low;
    scl_stable_high_o   = state.scl.stable_high;

    start_det_o         = state.start_det;
    rstart_det_o        = state.rstart_det;
    stop_det_o          = state.stop_det;
  end

  bus_monitor xmonitor (
    .state_o (state),
    .*
  );

endmodule
