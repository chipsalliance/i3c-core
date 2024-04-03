// Copyright (c) 2024 Antmicro <www.antmicro.com>
// SPDX-License-Identifier: Apache-2.0

module i3c_sdr_pkt_gen
  import i3c_ctrl_pkg::*;
#(
    parameter int TEMP = 0
) (
    input logic clk,
    input logic rst_n,
    //
    input logic addr,
    input logic is_rw,
    input logic [7:0] data,
    input logic sof,
    input logic eof,
    //
    output logic scl,
    output logic sda

);


  // State definitions
  // TODO: Reduce 31 bits
  typedef enum logic [31:0] {
    idle,
    send_address,
    send_data
  } state_t;

  state_t state = state_t.idle;
  state_t state_next = state_t.idle;


  // Next state logic
  always_comb begin : proc_fsm_next_state
    case (state)
      default: begin
        state_next = state_t.idle;
      end
    endcase
  end

  // FSM logic
  always_ff @(posedge clk or negedge rst_n) begin : proc_fsm
    if (!rst_n) begin
      state <= state_t.idle;
    end else begin
      state <= state_next;
    end
  end


endmodule
