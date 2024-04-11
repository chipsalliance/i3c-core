// SPDX-License-Identifier: Apache-2.0

module i2c_phy_integration
  import i2c_pkg::*;
#(
    parameter int FifoDepth = 64,
    parameter int AcqFifoDepth = 64,
    localparam int FifoDepthWidth = $clog2(FifoDepth + 1),
    localparam int AcqFifoDepthWidth = $clog2(AcqFifoDepth + 1)
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

    input        ctrl_scl_i,  // serial clock input from i2c fsm
    output logic ctrl_scl_o,  // serial clock output to i2c fsm
    input        ctrl_sda_i,  // serial data input from i2c fsm
    output logic ctrl_sda_o,  // serial data output to i2c fsm

    input        i3c_scl_i,  // serial clock input from i3c bus
    output logic i3c_scl_o,  // serial clock output to i3c bus
    input        i3c_sda_i,  // serial data input from i3c bus
    output logic i3c_sda_o,  // serial data output to i3c bus

    input host_enable_i,  // enable host functionality

    input fmt_fifo_rvalid_i,  // indicates there is valid data in fmt_fifo
    input [FifoDepthWidth-1:0] fmt_fifo_depth_i,  // fmt_fifo_depth
    output logic fmt_fifo_rready_o,  // populates fmt_fifo
    input [7:0] fmt_byte_i,  // byte in fmt_fifo to be sent to target
    input fmt_flag_start_before_i,  // issue start before sending byte
    input fmt_flag_stop_after_i,  // issue stop after sending byte
    input fmt_flag_read_bytes_i,  // indicates byte is an number of reads
    input fmt_flag_read_continue_i,  // host to send Ack to final byte read
    input fmt_flag_nak_ok_i,  // no Ack is expected
    input unhandled_unexp_nak_i,
    input unhandled_nak_timeout_i,  // NACK handler timeout event not cleared

    output logic                     rx_fifo_wvalid_o,  // high if there is valid data in rx_fifo
    output logic [RX_FIFO_WIDTH-1:0] rx_fifo_wdata_o,   // byte in rx_fifo read from target

    output logic host_idle_o,  // indicates the host is idle

    input [15:0] thigh_i,  // high period of the SCL in clock units
    input [15:0] tlow_i,  // low period of the SCL in clock units
    input [15:0] t_r_i,  // rise time of both SDA and SCL in clock units
    input [15:0] t_f_i,  // fall time of both SDA and SCL in clock units
    input [15:0] thd_sta_i,  // hold time for (repeated) START in clock units
    input [15:0] tsu_sta_i,  // setup time for repeated START in clock units
    input [15:0] tsu_sto_i,  // setup time for STOP in clock units
    input [15:0] tsu_dat_i,  // data setup time in clock units
    input [15:0] thd_dat_i,  // data hold time in clock units
    input [15:0] t_buf_i,  // bus free time between STOP and START in clock units
    input [30:0] stretch_timeout_i,  // max time target connected to this host may stretch the clock
    input timeout_enable_i,  // assert if target stretches clock past max
    input [30:0] host_nack_handler_timeout_i, // Timeout threshold for unhandled Host-Mode 'nak' irq.
    input host_nack_handler_timeout_en_i,

    output logic event_nak_o,                    // target didn't Ack when expected
    output logic event_unhandled_nak_timeout_o,  // SW didn't handle the NACK in time
    output logic event_scl_interference_o,       // other device forcing SCL low
    output logic event_sda_interference_o,       // other device forcing SDA low
    output logic event_stretch_timeout_o,        // target stretches clock past max time
    output logic event_sda_unstable_o,           // SDA is not constant during SCL pulse
    output logic event_cmd_complete_o            // Command is complete
);

  // IOs between PHY and I3C bus
  logic scl_io;
  logic scl_o;
  logic scl_en_o;

  logic sda_io;
  logic sda_o;
  logic sda_en_o;

  // Internal signals to communicate FSM with PHY
  logic ctrl_scl_int;
  logic ctrl_sda_int;

  i2c_controller_fsm i2c_controller_fsm (
      .scl_i(ctrl_scl_i),
      .scl_o(ctrl_scl_int),
      .sda_i(ctrl_sda_i),
      .sda_o(ctrl_sda_int),
      .*
  );

  i3c_phy phy (
      .ctrl_scl_i(ctrl_scl_int),
      .ctrl_sda_i(ctrl_sda_int),
      .ctrl_scl_o(ctrl_scl_o),
      .ctrl_sda_o(ctrl_sda_o),
      .scl_i(i3c_scl_i),
      .scl_o(i3c_scl_o),
      .sda_i(i3c_sda_i),
      .sda_o(i3c_sda_o),
      .*
  );

  i3c_io phy_io (
      .scl_io(scl_io),
      .scl_i(i3c_scl_o),
      .scl_en_i(scl_en_o),

      .sda_io(sda_io),
      .sda_i(i3c_sda_o),
      .sda_en_i(sda_en_o)
  );

endmodule
