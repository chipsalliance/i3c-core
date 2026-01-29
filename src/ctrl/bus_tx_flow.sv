/*
SPDX-License-Identifier: Apache-2.0

This module controls the low-level aspects of the SDA transmit data flow on the I3C bus. It drives
the both the data value and the drive mode (OpenDrain or PushPull) of the SDA pad.
Note: No logic apart from static and guaranteed glitch-free muxing must be inserted between this
      module and the physical SDA pad!

External modules can send following request types to drive the bus:
- Send data byte,
- Initiate an IBI with address as byte payload
- Send Tbit/(N)ACK.

Requests are made through the tx_req_i struct port which encapsulates all required information.
Feedback is provided through tx_rsp_o, including any error states.
*/

module bus_tx_flow import i3c_pkg::*; (
  input  logic clk_i,
  input  logic rst_ni,

  // Input I3C Bus events
  input  logic scl_negedge_i,
  input  logic scl_posedge_i,
  input  logic scl_stable_low_i,

  // Tx request in
  input  bus_tx_req_t tx_req_i,

  // Tx response out
  output bus_tx_rsp_t tx_rsp_o,

  // Open Drain / Push Pull
  output logic sel_od_pp_o,

  // Output I3C SDA bus line
  output logic sda_o
);

  // Signals
  logic       bit_counter_en;
  logic [3:0] bit_counter_q, bit_counter_d;

  logic [2:0] reqs;
  logic       req_any;
  i3c_byte_t  req_value_q, req_value_d;

  logic tx_done;     // Indicates finished bit write
  logic bus_tx_done; // Feedback to requester that transfer is done
  logic req_error;

  typedef enum logic [2:0] {
    Idle,
    DriveByte,
    NextTaskDecision,
    WaitNegEdge,
    WaitPosEdge
  } tx_state_e;

  tx_state_e state_d, state_q;

  // Common logic whenever a transfer gets started, including back-to-back transfers
  function automatic tx_state_e start_transfer(
    input  bus_tx_req_t bus_tx_req,
    output i3c_byte_t   req_value_d,
    output logic        bit_counter_en
  );
    req_value_d[7]   = tx_req_i.data[7];
    req_value_d[6:0] = tx_req_i.req_bit ? '1 : tx_req_i.data[6:0];
    if (bus_tx_req.req_bit) begin
      // Only one bit to send; wait for posedge
      bit_counter_en = 1'b0;
      return WaitPosEdge;
    end else begin
      // Enable bit counter and work on full byte in DriveByte
      bit_counter_en = 1'b1;
      return DriveByte;
    end

  endfunction : start_transfer

  assign reqs    = {tx_req_i.req_byte, tx_req_i.req_bit, tx_req_i.req_ibi};
  assign req_any = |reqs;
  // Clever way to ensure that only one bit is HIGH
  // Source: https://stackoverflow.com/a/11235598
  // It might be optimized if we're sure there are only 2 requests at most
  assign req_error = |(reqs & (reqs - 1));

  // Bit counter used for byte transfers
  always_comb begin
    bit_counter_d = bit_counter_q;

    if (bit_counter_en) begin
      if (tx_done) begin
        bit_counter_d = (bit_counter_q == 4'd0) ? 4'd7 : bit_counter_q - 1;
      end
    end else begin
      bit_counter_d = 4'd7;
    end
  end

  // SDA is simply the MSB of the data shift register. No further logic or muxing.
  assign sda_o = req_value_q[7];

  always_comb begin : tx_fsm
    bit_counter_en = 1'b0;

    tx_done     = 1'b0;
    bus_tx_done = 1'b0;

    req_value_d = req_value_q;
    state_d     = state_q;
    unique case (state_q)
      Idle: begin
        if (req_any) begin
          if (tx_req_i.req_ibi) begin
            // Drive 0 in OD on SDA and wait until the controller gives us a negedge on SCL
            // Note: The controller also could've started to drive SDA below and it will take the
            // delay through the SDA synchronizer for us to detect this, however, this does not
            // present any timing or driving conflict issue.
            req_value_d[7] = 1'b0;
          end
          // For IBI, this state is 2-in-1: First, SDA is driven low above to initiate the IBI by
          // generating a "target-side start condition". Next, on the SCL negedge that follows,
          // initiated by the controller, we have to immediately drive out the first bit of the IBI
          // address, which gets done below as the regular byte payload, which is also used for 
          // non-IBI frames/transfers.
          // Since no clocking event happens between these two phases, we cannot make any state
          // transition and have to handle both in the same state.
          if (scl_negedge_i || scl_stable_low_i) begin
            state_d = start_transfer(tx_req_i, req_value_d, bit_counter_en);
          end else begin
            state_d = WaitNegEdge;
          end
        end
      end
      WaitNegEdge: begin
        if (scl_negedge_i) begin
          state_d = start_transfer(tx_req_i, req_value_d, bit_counter_en);
        end
      end
      DriveByte: begin
        if (tx_req_i.req_byte || tx_req_i.req_ibi) begin
          bit_counter_en = 1'b1;
          // Simply wait for next edge
          if (scl_negedge_i) begin
            tx_done = 1'b1;
            // Shift the register which drives sda left to get next bit
            req_value_d = {req_value_q[6:0], 1'b1};
            // Last bit; wait for one more posedge to signal request completion
            if (bit_counter_q == 4'd1) begin
              state_d = WaitPosEdge;
            end
          end
        end else begin
          // Requester cancelled the transaction, e.g., a bus stop condition has occurred or
          // arbitration was lost during the address phase.
          req_value_d = '1;
          state_d = Idle;
        end
      end
      WaitPosEdge: begin
        // Wait for posedge to avoid following rx requests sampling this bit as well
        if (scl_posedge_i) begin
          bus_tx_done = 1'b1;
          state_d = NextTaskDecision;
        end
      end
      NextTaskDecision: begin
        if (scl_negedge_i) begin
          if (req_any) begin
            // Back-to-back transfer pending, immediately service it
            state_d = start_transfer(tx_req_i, req_value_d, bit_counter_en);
          end else begin
            // Reset sda_o to OpenDrain-high & back to Idle
            req_value_d = '1;
            state_d = Idle;
          end
        end
      end
      default: ;
    endcase

    // Allow to abort and go back to Idle if needed
    if (req_error) begin
      state_d = Idle;
    end
  end

  assign tx_rsp_o = '{
    error: req_error,
    idle:  (state_q == Idle),
    done:  bus_tx_done
  };

  assign sel_od_pp_o = tx_req_i.drive_type; // TODO FIXME - Feedthrough for now

  // Sequential process for all flops
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      bit_counter_q <= '0;
      req_value_q   <= '1;
      state_q       <= Idle;
    end else begin
      bit_counter_q <= bit_counter_d;
      req_value_q   <= req_value_d;
      state_q       <= state_d;
    end
  end

endmodule
