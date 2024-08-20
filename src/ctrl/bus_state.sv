// SPDX-License-Identifier: Apache-2.0


module bus_state
  import controller_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,
    input logic sda_i,  // Monitor bus SDA
    input logic scl_i,  // Monitor bus SCL
    output logic [3:0] bus_state,  // States: Idle, Free, Available, Busy
    output logic det_bus_start,  // Detect Start Condition
    output logic det_bus_stop  // Detect Stop Condition
);

  // SDA delayed by 1 cycle
  logic sda_i_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_delay_sda
    if (!rst_ni) begin
      sda_i_q <= '0;
    end else begin
      sda_i_q <= sda_i;
    end
  end

  // Detect Stop condition
  assign det_bus_stop  = sda_i & scl_i;

  // Detect Start Condition
  assign det_bus_start = (sda_i ^ sda_i_q) & (~sda_i);

  // State definitions
  typedef enum logic [1:0] {
    Idle,
    Avail,
    Free,
    Busy
  } state_t;

  // TODO: Add counters to calculate time durations from:
  // Like in src/ctrl/i2c_controller_fsm.sv#L102-152
  // Figure 24 Bus Condition Timing
  logic [31:0] cnt_tidle;
  logic [31:0] cnt_tavail;
  logic [31:0] cnt_tcas;
  logic [31:0] cnt_tbuf;
  state_t bus_state_next;

  // TODO: this does not consider the hot-join mechanism
  // TODO: this assumes that the device will wakeup when SCL/SDA are HIGH
  // Next state logic
  always_comb begin : proc_fsm_next_state
    case (bus_state)
      Idle: begin
        bus_state_next = det_bus_start ? Busy : Idle;
      end
      Busy: begin
        if (cnt_tcas) bus_state_next = Free;
        else if (cnt_tbuf) bus_state_next = Free;
        else if (cnt_tavail) bus_state_next = Avail;
        else if (cnt_tidle) bus_state_next = Idle;
      end
      Avail: begin
        bus_state_next = det_bus_start ? Busy : Idle;
      end
      Free: begin
        bus_state_next = det_bus_start ? Busy : Idle;
      end
      default: bus_state_next = Idle;
    endcase
  end

  // FSM logic
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_fsm
    if (!rst_ni) begin
      bus_state <= Idle;
    end else begin
      bus_state <= bus_state_next;
    end
  end

endmodule

