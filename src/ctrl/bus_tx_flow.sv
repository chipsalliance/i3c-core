/*
SPDX-License-Identifier: Apache-2.0

This module is supposed to control the data flow on the I3C bus. External modules can
assert following requests to drive the bus:
- send data byte,
- send tbit/ACK/NACK.

In order to request a transfer, assert `req_byte_i` or `req_bit_i` and set the requested value
`req_value_i`. If request is single bit, the LSB of `req_value_i` will be transferred. Request
signals should be asserted until `bus_tx_done_o` is not asserted. Then request should be either
deasserted or immediately configured for new transfer.

Notes:
* The `bus_tx_done_o` is single pulse indicator for finished transfers.
* Asserting both `req_byte_i` and `req_bit_i` will cause an error assertion on `req_error_o`
* The `abort_i` cancels request and releases the bus immediately
* Before asserting a request, ensure `bus_tx_idle_o` is HIGH

*/

module bus_tx_flow (
    input logic clk_i,
    input logic rst_ni,

    // I3C bus timings
    input logic [19:0] t_r_i,       // rise time of both SDA and SCL in clock units
    input logic [19:0] t_su_dat_i,  // data setup time in clock units
    input logic [19:0] t_hd_dat_i,  // data hold time in clock units

    // Input I3C Bus events
    input logic scl_negedge_i,
    input logic scl_posedge_i,
    input logic scl_stable_low_i,

    // Bus flow control
    input logic req_byte_i,
    input logic req_bit_i,
    input logic [7:0] req_value_i,
    output logic bus_tx_done_o,
    output logic bus_tx_idle_o,
    output logic req_error_o,
    output logic bus_error_o,

    // Open Drain / Push Pull
    input  logic sel_od_pp_i,
    output logic sel_od_pp_o,

    output logic sda_o  // Output I3C SDA bus line
);
  logic drive_bit_en;
  logic drive_bit_value;
  logic [3:0] bit_counter;

  logic tx_idle;
  logic tx_done;  // Indicate finished bit write
  logic bus_tx_done;
  logic bus_tx_idle;
  logic bit_counter_en;

  logic [7:0] req_value;
  logic [1:0] reqs;
  logic req;
  logic req_error;
  logic bus_error;
  logic error;

  assign reqs = {req_byte_i, req_bit_i};
  assign req = |reqs;
  // Clever way to ensure that only one bit is HIGH
  // Source: https://stackoverflow.com/a/11235598
  // It might be optimized if we're sure there are only 2 requests at most
  assign req_error = ~(~|(reqs & (reqs - 1)));

  // TODO: Connect to bus_tx module error output signal
  assign bus_error = '0;
  assign error = req_error | bus_error;

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_bit_counter
    if (~rst_ni) begin
      bit_counter <= '0;
    end else begin
      if (bit_counter_en) begin
        if (tx_done) begin
          if (bit_counter == 4'h0) bit_counter <= 4'h7;
          else bit_counter <= bit_counter - 1;
        end else bit_counter <= bit_counter;
      end else begin
        bit_counter <= 4'h7;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_req_value
    if (~rst_ni) begin
      req_value <= '0;
    end else begin
      if (bit_counter_en) begin
        if (tx_done) req_value[7:0] <= {req_value[6:0], 1'b0};
      end else if (bit_counter == 4'h7) begin
        req_value <= req_value_i;
      end else begin
        req_value <= '0;
      end
    end
  end

  typedef enum logic [2:0] {
    Idle,
    DriveByte,
    DriveBit,
    NextTaskDecision
  } tx_state_e;

  tx_state_e state_d, state_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_fsm_state
    if (~rst_ni) begin
      state_q <= Idle;
    end else begin
      state_q <= state_d;
    end
  end

  always_comb begin : tx_fsm_outputs
    bus_tx_idle = '0;
    bus_tx_done = '0;
    drive_bit_en = '0;
    drive_bit_value = 1'b1;  // Pullup by default
    bit_counter_en = '0;

    unique case (state_q)
      Idle: begin
        bus_tx_idle  = tx_idle;
        drive_bit_en = tx_idle ? req : 1'b0;
        drive_bit_value = req_byte_i ? req_value_i[7] : req_value_i[0];
      end
      DriveByte: begin
        bit_counter_en = 1'b1;
        drive_bit_en = 1'b1;
        drive_bit_value = req_value[7];
        if (~|bit_counter & tx_done) begin
          bus_tx_done = 1'b1;
        end
      end
      DriveBit: begin
        drive_bit_value = req_value[0];
        drive_bit_en = 1'b1;
        if (tx_done) bus_tx_done = 1'b1;
      end
      NextTaskDecision: begin
        drive_bit_en = req;
        // FIXME: Observed glitch on SDA
        // drive_bit_value = req_byte_i ? req_value[7] : req_bit_i ? req_value[0] : 1'b1;
        // This partially solves the problem
        drive_bit_value = req_value_i[0];
        // req_value_i[0]
      end
      default: ;
    endcase
  end

  always_comb begin : tx_fsm_state
    state_d = state_q;

    unique case (state_q)
      Idle: begin
        if (tx_idle) begin
          state_d = req_byte_i ? DriveByte : req_bit_i ? DriveBit : Idle;
        end
      end
      DriveByte: begin
        if (bus_tx_done) begin
          state_d = NextTaskDecision;
        end
      end
      DriveBit: begin
        if (tx_done) begin
          state_d = NextTaskDecision;
        end
      end
      NextTaskDecision: begin
        state_d = req_byte_i ? DriveByte : req_bit_i ? DriveBit : Idle;
      end
      default: begin
        state_d = Idle;
      end
    endcase

    // Allow to abort and go back to Idle if needed
    if (~req | error) begin
      state_d = Idle;
    end
  end

  bus_tx xbus_tx (
      .clk_i,
      .rst_ni,
      .t_r_i,
      .t_su_dat_i,
      .t_hd_dat_i,
      .drive_i(drive_bit_en),
      .drive_value_i(drive_bit_value),
      .scl_negedge_i,
      .scl_posedge_i,
      .scl_stable_low_i,
      .sel_od_pp_i,
      .sel_od_pp_o,
      .tx_idle_o(tx_idle),
      .tx_done_o(tx_done),
      .sda_o
  );

  assign req_error_o   = req_error;
  assign bus_error_o   = bus_error;
  assign bus_tx_idle_o = bus_tx_idle;
  assign bus_tx_done_o = bus_tx_done;
endmodule
