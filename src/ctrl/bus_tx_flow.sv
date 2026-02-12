/*
  SPDX-License-Identifier: Apache-2.0

  This module controls the low-level aspects of the SDA transmit data flow on the I3C bus. It drives
  the both the data value and the drive mode (OpenDrain or PushPull) of the SDA pad.
  Note: No logic apart from static and guaranteed glitch-free muxing must be inserted between this
        module and the physical SDA pad!

  External modules can send following request types to drive the bus:
  - Send raw data bits, including regular ACK/NACK,
  - Send raw data bytes
  - Initiate an IBI with address as byte payload
  - Send an ACK following a write request by the contoller which requires special handoff
  - Send TbitAbort in a private read, requiring half-bit drive mode change
  - Send TbitContinue in a private read, requiring special checks for controller-side abort

  Requests are made through the tx_req_i struct port which encapsulates all required information.
  Feedback is provided through tx_rsp_o, including any error states.
*/

module bus_tx_flow import i3c_pkg::*; (
  input  logic clk_i,
  input  logic rst_ni,

  // Input I3C Bus events
  input  bus_state_t bus_i,

  // Tx request in
  input  bus_tx_req_t tx_req_i,

  // Tx response out
  output bus_tx_rsp_t tx_rsp_o,

  // Open Drain / Push Pull
  output logic sel_od_pp_o,

  // Output enable for SDA pad
  output logic sda_oe_o,

  // Output I3C SDA bus line
  output logic sda_o
);

  // Signals
  logic       bit_counter_en;
  logic [3:0] bit_counter_q, bit_counter_d;

  // Registers for all critical signals directly connected to the SDA pad
  i3c_byte_t  req_value_q, req_value_d;
  i3c_drive_e drive_mode_q, drive_mode_d;
  logic       sda_oe_q, sda_oe_d;

  logic tx_done;     // Indicates finished bit write
  logic bus_tx_done; // Feedback to requester that transfer is done
  logic bus_tx_abort;

  typedef enum logic [2:0] {
    Idle,
    DriveByte,
    NextTaskDecision,
    WaitNegEdge,
    WaitPosEdge,
    TReadContSpecial
  } tx_state_e;

  tx_state_e state_d, state_q;

  // SDA is simply the MSB of the data shift register. No further logic or muxing.
  // Similar for pad drive mode and output enable.
  assign sda_o = req_value_q[7];
  assign sel_od_pp_o = drive_mode_q;
  assign sda_oe_o = sda_oe_q;

  /*
    Truth table for sda_oe.

    sel_od_pp_o | sda_o  || sda_oe_o | IO state
    ------------+--------++----------+-----------
         0      |   0    ||    1     |    0
         0      |   1    ||    0     |   hi-z
         1      |   0    ||    1     |    0
         1      |   1    ||    1     |    1
  */
  assign sda_oe_d = drive_mode_d || !req_value_d[7];

  // Common logic whenever a transfer gets started, including back-to-back transfers
  function automatic tx_state_e start_transfer(
    input  bus_tx_req_t bus_tx_req,
    output i3c_byte_t   req_value,
    output i3c_drive_e  drive_mode,
    output logic        counter_en
  );

    // Unconditional default values to keep Lint happy
    req_value  = '1;
    drive_mode = OpenDrain;
    counter_en = 1'b0;

    // Decide on value and drive mode following SCL negedge
    case (bus_tx_req.req_type)
      RawByte: begin
        req_value    = bus_tx_req.data;
        drive_mode   = bus_tx_req.drive_type;
      end
      RawBit: begin
        req_value    = {bus_tx_req.data[7], {7{1'b1}}};
        drive_mode   = bus_tx_req.drive_type;
      end
      AckIbi: begin
        req_value    = '1;
        drive_mode   = OpenDrain;
      end
      AckRegular, AckWrite: begin
        req_value[7] = 1'b0;
        drive_mode   = OpenDrain;
      end
      TReadCont: begin
        req_value[7] = 1'b1;
        drive_mode   = PushPull;
      end
      TReadEnd: begin
        req_value[7] = 1'b0;
        drive_mode   = PushPull;
      end
      InitIbi: begin
        req_value    = bus_tx_req.data; // Data is IBI address
        drive_mode   = OpenDrain;
      end
      default: begin end
    endcase

    // Most request types are only a single bit in length; completion can be signalled at the next
    // SCL rising edge.
    if (bus_tx_req.req_type inside {RawByte, InitIbi}) begin
      // Enable bit counter and work on full byte in DriveByte
      counter_en = 1'b1;
      return DriveByte;
    end else begin
      counter_en = 1'b0;
      return WaitPosEdge;
    end

  endfunction : start_transfer

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

  // Main FSM which handles all low-level bus details in terms of transmitting
  always_comb begin : tx_fsm
    bit_counter_en = 1'b0;

    tx_done      = 1'b0;
    bus_tx_done  = 1'b0;
    bus_tx_abort = 1'b0;

    req_value_d  = req_value_q;
    drive_mode_d = drive_mode_q;
    state_d      = state_q;
    unique case (state_q)
      Idle: begin
        if (tx_req_i.req_valid) begin
          if (tx_req_i.req_type == InitIbi) begin
            // Drive 0 in OD on SDA and wait until the controller gives us a negedge on SCL
            // Note: The controller also could've started to drive SDA below and it will take the
            // delay through the SDA synchronizer for us to detect this, however, this does not
            // present any timing or driving conflict issue.
            req_value_d[7] = 1'b0;
            drive_mode_d   = OpenDrain;
          end
          // For IBI, this state is 2-in-1: First, SDA is driven low above to initiate the IBI by
          // generating a "target-side start condition". Next, on the SCL negedge that follows,
          // initiated by the controller, we have to immediately drive out the first bit of the IBI
          // address, which gets done below as the regular byte payload, which is also used for 
          // non-IBI frames/transfers.
          // Since no clocking event happens between these two phases, we cannot make any state
          // transition and have to handle both in the same state.
          if (bus_i.scl.neg_edge || bus_i.scl.stable_low) begin
            state_d = start_transfer(tx_req_i, req_value_d, drive_mode_d, bit_counter_en);
          end else begin
            state_d = WaitNegEdge;
          end
        end
      end
      WaitNegEdge: begin
        if (bus_i.scl.neg_edge) begin
          state_d = start_transfer(tx_req_i, req_value_d, drive_mode_d, bit_counter_en);
        end
      end
      DriveByte: begin
        if (tx_req_i.req_valid) begin
          bit_counter_en = 1'b1;
          // Simply wait for next edge
          if (bus_i.scl.neg_edge) begin
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
          drive_mode_d = OpenDrain;
          req_value_d  = '1;
          state_d = Idle;
        end
      end
      WaitPosEdge: begin
        // Wait for posedge to avoid following rx requests sampling this bit as well
        if (bus_i.scl.pos_edge) begin
          // Handle all cases that require half-bit changes to SDA data and drive mode
          case (tx_req_i.req_type)
            AckWrite: begin
              // Release SDA in the middle of ACK to high-Z; Controller takes over driving
              // Specified in Section 5.1.2.3.1
              req_value_d[7] = 1'b1;
            end
            AckIbi: begin
              // Take over to drive SDA low in PP in case of an IBI Ack by the controller
              // Specified in Section 5.1.2.3.2
              if (bus_i.sda.value == 1'b0) begin
                req_value_d[7] = 1'b0;
                drive_mode_d = PushPull;
              end
            end
            TReadEnd, TReadCont: begin
              // Both cases require to release SDA to high-Z; in case of TReadEnd, the Controller
              // will take over driving SDA low. In case of TReadCont, the Controller may drive SDA
              // low after the rising edge to signal a read abort to us.
              // Specified in Section 5.1.2.3.4
              req_value_d[7] = 1'b1;
              drive_mode_d = OpenDrain;
            end
            default: begin end
          endcase
          // In most cases the transaction is completed; flag this to the requester. For TReadCont,
          // we however must wait until the next SCL negedge, as the Controller may sent an Rs
          // between then and the SCL posedge that just happened to deny our request to continue.
          if (tx_req_i.req_type == TReadCont) begin
            state_d = TReadContSpecial;
          end else begin
            bus_tx_done = 1'b1;
            state_d = NextTaskDecision;
          end
        end
      end
      TReadContSpecial: begin
        // If we see an SDA negedge before the next SCL negedge, the Controller aborted the read
        if (bus_i.sda.neg_edge) begin
          bus_tx_abort = 1'b1;
          state_d = Idle;
        end
        // Controller has accepted to continue and the requester has provided the respective data
        // already as part of the TReadCont request such that we are able to clock out the MSB
        // on this very negedge. Continue with the remaining 7 bits in DriveByte.
        if (bus_i.scl.neg_edge) begin
          bus_tx_done    = 1'b1;
          bit_counter_en = 1'b1;
          drive_mode_d = PushPull;
          req_value_d  = tx_req_i.data;
          state_d      = DriveByte;
        end
      end
      NextTaskDecision: begin
        if (bus_i.scl.neg_edge) begin
          if (tx_req_i.req_valid) begin
            // Back-to-back transfer pending, immediately service it
            state_d = start_transfer(tx_req_i, req_value_d, drive_mode_d, bit_counter_en);
          end else begin
            // Reset sda_o to High-Z & back to Idle
            drive_mode_d = OpenDrain;
            req_value_d  = '1;
            state_d = Idle;
          end
        end
      end
      default: begin end
    endcase
  end

  assign tx_rsp_o = '{
    // FUTUREFIX: error is unused; available for future bus error reporting
    error: 1'b0,
    idle:  (state_q == Idle),
    done:  bus_tx_done,
    abort: bus_tx_abort
  };

  // Sequential process for all flops
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      bit_counter_q <= '0;
      req_value_q   <= '1;
      drive_mode_q  <= OpenDrain;
      sda_oe_q      <= 1'b0;
      state_q       <= Idle;
    end else begin
      bit_counter_q <= bit_counter_d;
      req_value_q   <= req_value_d;
      drive_mode_q  <= drive_mode_d;
      sda_oe_q      <= sda_oe_d;
      state_q       <= state_d;
    end
  end

endmodule
