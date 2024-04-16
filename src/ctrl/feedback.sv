// SPDX-License-Identifier: Apache-2.0


module feedback
  import i3c_ctrl_pkg::*;
#(
    parameter int DATA_W = 9
) (
    input  logic clk,
    input  logic rst_n,
    input  logic sda_i,
    input  logic scl_i,
    output logic bus_state,
    output logic det_bus_start,
    output logic det_bus_stop
);

  // input i3c_phy_pkg::i3c_phy_err_t phy_err_o
  // input logic is_arbitr_lost,
  // output logic stop_tx,
  // input logic is_ack_bit_active,
  // output logic err_nack

  // Detect STOP condition
  logic det_bus_stop;
  assign det_bus_stop = sda_i & scl_i;

  logic det_bus_start;
  logic sda_i_d;
  always_ff @(posedge clk or negedge rst_n) begin : proc_fsm
    if (!rst_n) begin
      sda_i_d <= '0;
    end else begin
      sda_i_d <= sda_i;
    end
  end

  assign det_bus_start = (sda_i ^ sda_i_d) & (~sda_i);

  // State definitions
  typedef enum logic [31:0] {
    idle,
    aval,
    free,
    busy
  } state_t;

  logic [31:0] bus_state;

  // TODO: Add counters to calculate time durations from:
  // Figure 24 Bus Condition Timing
  logic [31:0] cnt_tidle;
  logic [31:0] cnt_taval;
  logic [31:0] cnt_tcas;
  logic [31:0] cnt_tbuf;

  // TODO: this does not consider the hot-join mechanism
  // TODO: this assumes that the device will wakeup when SCL/SDA are HIGH
  // Next state logic
  always_comb begin : proc_fsm_next_state
    case (state)
      state_t.idle: bus_state_next = det_bus_start ? state_t.busy : state_t.idle;
      state_t.busy: begin
        if (cnt_tcas) bus_state_next = state_t.free;
        else if (cnt_tbuf) bus_state_next = state_t.free;
        else if (cnt_taval) bus_state_next = state_t.aval;
        else if (cnt_tidle) bus_state_next = state_t.idle;
      end
      state_t.aval: bus_state_next = det_bus_start ? state_t.busy : state_t.idle;
      state_t.free: bus_state_next = det_bus_start ? state_t.busy : state_t.idle;
      default: bus_state_next = state_t.idle;
    endcase
  end

  // FSM logic
  always_ff @(posedge clk or negedge rst_n) begin : proc_fsm
    if (!rst_n) begin
      state <= state_t.idle;
    end else begin
      state <= bus_state_next;
    end
  end

endmodule

