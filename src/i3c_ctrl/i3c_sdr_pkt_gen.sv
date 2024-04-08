// SPDX-License-Identifier: Apache-2.0

module i3c_sdr_pkt_gen
  import i3c_ctrl_pkg::*;
#(
    parameter int TEMP = 0
) (
    input logic clk,
    input logic rst_n,
    //
    input logic en,
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

  logic   is_send_address;
  logic   is_send_data;
  // Next state logic
  always_comb begin : proc_fsm_next_state
    case (state)
      state_t.idle: begin
        state_next = en ? state_t.send_address : state_t.idle;
      end
      state_t.send_address: begin
        state_next = is_send_address ? state_t.send_address : state_t.send_data;
      end
      state_t.send_data: begin
        state_next = is_send_data ? state_t.send_data : state_t.idle;
      end
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

  // Comb outputs
  always_comb begin : proc_fsm_outputs
    case (state)
      state_t.idle: begin
        is_send_address = sof;
      end
      state_t.send_address: begin
        is_send_address = '0;  //TODO: After how many cycles?
      end
      state_t.send_data: begin
        is_send_address = '0;
      end
      default: begin
        is_send_address = '0;
        is_send_data = '0;
      end
    endcase
  end

  // Serialize data onto SDA/SCL lines
  logic sda_load;
  logic sda_en;
  logic [8:0] sda_data;
  assign sda_data = {data, is_rw};

  xser_sda serializer (
      .clk(clk),
      .rst_n(rst_n),
      .load(sda_load),
      .enable(sda_en),
      .data(sda_data),
      .q(sda),
  );

  logic scl_load;
  logic scl_en;
  logic [8:0] scl_data = 9'b1010_1010_1;

  xser_scl serializer (
      .clk(clk),
      .rst_n(rst_n),
      .load(scl_load),
      .enable(scl_en),
      .data(scl_data),
      .q(scl),
  );

endmodule
