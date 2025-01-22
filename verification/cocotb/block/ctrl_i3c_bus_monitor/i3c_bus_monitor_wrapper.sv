module i3c_bus_monitor_wrapper
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

    input logic is_in_hdr_mode_i,  // Module is in HDR mode
    output logic hdr_exit_detect_o,     // Detected HDR exit condition (see: 5.2.1.1.1 of the base spec)
    output logic target_reset_detect_o  // Detected Target Reset condtition
);

  bus_state_t state;

  bus_monitor xmonitor (
    .state_o (state),
    .*
  );

  i3c_bus_monitor xi3c_monitor(
    .bus_i (state),
    .*
  );

endmodule
