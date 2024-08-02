module i2c_target_fsm_harness
  import controller_pkg::*;
#(
    parameter int AcqFifoDepth = 64,
    localparam int AcqFifoDepthWidth = $clog2(AcqFifoDepth + 1)
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

    input        scl_i,  // serial clock input from i2c bus
    output logic scl_o,  // serial clock output to i2c bus
    input        sda_i,  // serial data input from i2c bus
    output logic sda_o,  // serial data output to i2c bus

    input target_enable_i,  // enable target functionality

    input                          tx_fifo_rvalid_i,  // indicates there is valid data in tx_fifo
    output logic                   tx_fifo_rready_o,  // pop entry from tx_fifo
    input        [TxFifoWidth-1:0] tx_fifo_rdata_i,   // byte in tx_fifo to be sent to host

    output logic acq_fifo_wvalid_o,  // high if there is valid data in acq_fifo
    output logic [AcqFifoWidth-1:0] acq_fifo_wdata_o,  // data to write to acq_fifo from target
    input [AcqFifoDepthWidth-1:0] acq_fifo_depth_i,  // fill level of acq_fifo
    output logic acq_fifo_wready_o,  // local version of ready
    input [AcqFifoWidth-1:0] acq_fifo_rdata_i,  // only used for assertion

    output logic target_idle_o,  // indicates the target is idle

    input [15:0] t_r_i,             // rise time of both SDA and SCL in clock units
    input [15:0] tsu_dat_i,         // data setup time in clock units
    input [15:0] thd_dat_i,         // data hold time in clock units
    input [31:0] host_timeout_i,    // max time target waits for host to pull clock down
    input [30:0] nack_timeout_i,    // max time target may stretch until it should NACK
    input        nack_timeout_en_i, // enable nack timeout

    input logic [6:0] target_address0_i,
    input logic [6:0] target_mask0_i,
    input logic [6:0] target_address1_i,
    input logic [6:0] target_mask1_i,

    output logic target_sr_p_cond_o,    // Saw RSTART/STOP in Target-Mode.
    output logic event_target_nack_o,   // this target sent a NACK (this is used to keep count)
    output logic event_cmd_complete_o,  // Command is complete
    output logic event_tx_stretch_o,    // tx transaction is being stretched
    output logic event_unexp_stop_o,    // target received an unexpected stop
    output logic event_host_timeout_o   // host ceased sending SCL pulses during ongoing transactn
);
  logic scl_i_q, sda_i_q;

  // Synchronize i2c signals
  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      scl_i_q <= scl_i;
      sda_i_q <= sda_i;
    end
  end

  i2c_target_fsm #(AcqFifoDepth) i2c_target_fsm (
      .*,
      .scl_i(scl_i_q),
      .sda_i(sda_i_q)
  );
endmodule
