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

    input        host_enable_i,    // enable host functionality
    input        target_enable_i,  // enable target functionality
    output logic host_disable_o,   // disable host mode

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

    output logic                     rx_fifo_wvalid_o,  // high if there is valid data in rx_fifo
    output logic [RX_FIFO_WIDTH-1:0] rx_fifo_wdata_o,   // byte in rx_fifo read from target

    input                            tx_fifo_rvalid_i,  // indicates there is valid data in tx_fifo
    output logic                     tx_fifo_rready_o,  // pop entry from tx_fifo
    input        [TX_FIFO_WIDTH-1:0] tx_fifo_rdata_i,   // byte in tx_fifo to be sent to host

    output logic acq_fifo_wvalid_o,  // high if there is valid data in acq_fifo
    output logic [ACQ_FIFO_WIDTH-1:0] acq_fifo_wdata_o,  // data to write to acq_fifo from target
    input [AcqFifoDepthWidth-1:0] acq_fifo_depth_i,  // fill level of acq_fifo
    output logic acq_fifo_wready_o,  // local version of ready
    input [ACQ_FIFO_WIDTH-1:0] acq_fifo_rdata_i,  // only used for assertion

    output logic host_idle_o,   // indicates the host is idle
    output logic target_idle_o, // indicates the target is idle

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
    input [31:0] host_timeout_i,  // max time target waits for host to pull clock down
    input [30:0] nack_timeout_i,  // max time target may stretch until it should NACK
    input nack_timeout_en_i,  // enable nack timeout
    input [30:0] host_nack_handler_timeout_i,  // Timeout threshold
                                               // for unhandled Host-Mode 'nak' irq.
    input host_nack_handler_timeout_en_i,

    input logic [6:0] target_address0_i,
    input logic [6:0] target_mask0_i,
    input logic [6:0] target_address1_i,
    input logic [6:0] target_mask1_i,

    output logic target_sr_p_cond_o,  // Saw RSTART/STOP in Target-Mode.
    output logic event_target_nack_o,  // this target sent a NACK (this is used to keep count)
    output logic event_nak_o,  // target didn't Ack when expected
    output logic event_scl_interference_o,  // other device forcing SCL low
    output logic event_sda_interference_o,  // other device forcing SDA low
    output logic event_stretch_timeout_o,  // target stretches clock past max time
    output logic event_sda_unstable_o,  // SDA is not constant during SCL pulse
    output logic event_cmd_complete_o,  // Command is complete
    output logic event_tx_stretch_o,  // tx transaction is being stretched
    output logic event_unexp_stop_o,  // target received an unexpected stop
    output logic event_host_timeout_o  // host ceased sending SCL pulses during ongoing transactn
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

  i2c_fsm i2c_fsm (
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
