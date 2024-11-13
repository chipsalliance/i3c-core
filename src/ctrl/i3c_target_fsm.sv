// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: I2C finite state machine

/*
  ACK/First data bit ambiguity

  It is important for the FSM to know, which symbol occurs after ACK:
    - Repeated Start
    - or first bit of a data byte

  Detection:
    - ACK bit
    - Ignore transitions on SDA until we observe a posedge on SCL:
    - Next, if:
      - SDA transitions with stable SCL, that means we have either P or SR
    if SDA went from 0 to 1, it was a STOP; otherwise, SR
      - we observe SCL transition with stable SDA, that means it was the first data byte

  Dynamic/static address precedence:
    * If neither address is defined, then the core will ignore all addressed traffic
    * If only static address is defined, it will be used for Legacy I2C transfers or in bus configuration stage
    * If only dynamic address is defined, it will be used for I3C transfers
    * If both are defined, then:
      * static address will be used for Legacy I2C transfers
      * dynamic address will be used for I3C transfers
*/

module i3c_target_fsm #(
    parameter int unsigned RxDataWidth  = 8,
    parameter int unsigned TxDataWidth  = 8,
    parameter int unsigned IbiDataWidth = 8
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

    input target_enable_i,  // enable target functionality

    // Bus monitor interface
    input logic bus_start_det_i,
    input logic bus_rstart_det_i,
    input logic bus_stop_det_i,
    input logic bus_timeout_i,  // The bus timed out, with SCL held low for too long.

    output logic target_idle_o,  // indicates the target is idle
    output logic target_transmitting_o,  // Target is transmitting SDA (disambiguates high sda_o)

    // Bus TX interface
    input logic bus_tx_req_err_i,
    input logic bus_tx_done_i,
    input logic bus_tx_idle_i,
    output logic bus_tx_req_byte_o,
    output logic bus_tx_req_bit_o,
    output logic [TxDataWidth-1:0] bus_tx_req_value_o,
    output logic bus_tx_sel_od_pp_o,

    // Bus RX interface
    output logic bus_rx_req_bit_o,
    output logic bus_rx_req_byte_o,
    input logic bus_rx_done_i,
    input logic bus_rx_idle_i,
    input logic [RxDataWidth-1:0] bus_rx_data_i,
    input logic bus_rx_error_i,

    // TX FIFO used for Target Read
    input  logic                   tx_fifo_rvalid_i,  // indicates there is valid data in tx_fifo
    output logic                   tx_fifo_rready_o,  // pop entry from tx_fifo
    input  logic [TxDataWidth-1:0] tx_fifo_rdata_i,   // byte in tx_fifo to be sent to host
    output logic                   tx_host_nack_o,    // NACK has been received during transmission
    // FIXME: use me! to simplify the valid/ready/tbit generation
    input  logic                   tx_last_byte_i,

    // RX FIFO used for Target Write
    output logic                   rx_fifo_wvalid_o,  // high if there is valid data in rx_fifo
    output logic [RxDataWidth-1:0] rx_fifo_wdata_o,   // data to write to rx_fifo from target
    input  logic                   rx_fifo_wready_i,
    output logic                   rx_last_byte_o,

    // IBI FIFO
    input  logic                    ibi_fifo_rvalid_i,
    output logic                    ibi_fifo_rready_o,
    input  logic [IbiDataWidth-1:0] ibi_fifo_rdata_i,
    input  logic                    ibi_last_byte_i,

    // IBI address
    input logic [6:0] target_sta_address_i,
    input logic target_sta_address_valid_i,
    input logic [6:0] target_dyn_address_i,
    input logic target_dyn_address_valid_i,
    input logic [6:0] target_ibi_address_i,
    input logic target_ibi_address_valid_i,

    output logic event_target_nack_o,  // this target sent a NACK (this is used to keep count)
    output logic event_cmd_complete_o,  // Command is complete
    output logic event_unexp_stop_o,  // target received an unexpected stop
    output logic event_tx_arbitration_lost_o,  // Arbitration was lost during a read transfer
    output logic event_tx_bus_timeout_o,  // Bus timed out during a read transfer
    output logic event_read_cmd_received_o,  // A read awaits confirmation for TX FIFO release

    input  logic       target_reset_detect_i,
    output logic [7:0] rst_action_o,
    input  logic       hdr_exit_detect_i,
    output logic       is_in_hdr_mode_o,

    // Interfacing with IBI subFSMs
    input logic is_ibi_done_i,

    // Interfacing with CCC subFSMs
    output logic [7:0] ccc_o,
    output logic ccc_valid_o,
    input logic is_ccc_done_i,

    input logic is_hotjoin_done_i,

    output logic [7:0] last_addr_o,
    output logic       last_addr_valid_o,

    input logic scl_negedge_i,
    input logic scl_posedge_i,
    input logic sda_negedge_i,
    input logic sda_posedge_i,

    output logic parity_err_o,
    output logic rx_overflow_err_o
);
  logic bus_start_det;
  assign bus_start_det = bus_start_det_i | bus_rstart_det_i;

  // TODO: Set OD/PP in correct states
  assign bus_tx_sel_od_pp_o = '0;

  // Target specific variables
  logic nack_transaction_q, nack_transaction_d;
  logic is_ibi_pending;

  assign is_ibi_pending = ibi_fifo_rvalid_i;

  // Latch whether this transaction is to be NACK'd.
  always_ff @(posedge clk_i or negedge rst_ni) begin : clk_nack_transaction
    if (!rst_ni) begin
      nack_transaction_q <= 1'b0;
    end else begin
      nack_transaction_q <= nack_transaction_d;
    end
  end

  logic [RxDataWidth-1:0] rx_data_byte;
  logic rx_data_byte_valid;
  logic [TxDataWidth-1:0] tx_data_byte;
  logic tx_data_byte_valid;

  // State definitions
  // We can go to CCC secondary FSM after {S|SR,Byte,ACK,First bit}
  // We can go to Private RW after {S|SR,Byte(=Address)}
  // or {S|SR,Byte,ACK,SR}
  //
  // LegacyRW is handled within PrivateRW respectively
  typedef enum logic [7:0] {
    // Wait for:
    // - Start
    // - pending IBI
    // - hot-join
    // - reset pattern
    Idle,
    // Read first incoming byte of the transaction
    RxFByte,
    // Check if we should participate in the xfer
    CheckFByte,
    // Ack the xfer
    TxAckFByte,
    // Receive second byte
    RxSByte,
    RxSByteRepeated,
    // Check if if it's our address
    CheckSByte,
    // Ack the address
    TxAckSByte,
    // Receive data in Private Write transfer
    RxPWriteData,
    RxPWriteTbit,
    // Send data in Private Read transfer
    TxPReadData,
    TxPReadTbit,
    // Transfer is not targeted to us, wait for SR or P
    Wait,

    // If bus is available and an IBI is pending
    // Go to subFSM for IBI execution
    DoIBI,
    // After IBI is done, return here
    DoneIBI,

    // There is a CCC to process
    // Go to subFSM for CCC execution
    DoCCC,
    // After CCC is done, return here
    DoneCCC,

    DoHotJoin,

    // Reset pattern causes reset of the core
    // so "Done" return state is not needed.
    DoRstAction,
    DoHdrExit
  } primary_state_e;

  primary_state_e state_q, state_d;

  // Register last input byte
  logic [7:0] last_byte, last_addr;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_last_byte
    if (~rst_ni) begin
      last_byte <= '0;
    end else begin
      if (bus_rx_done_i & bus_rx_req_byte_o) last_byte <= bus_rx_data_i;
    end
  end

  assign rx_fifo_wdata_o = last_byte;
  assign last_addr_o = last_byte;
  assign last_addr_valid_o = (state_d == TxPReadData  & state_q != TxPReadTbit) |
                             (state_d == RxPWriteData & state_q != RxPWriteTbit) ?
                             1'b1 : 1'b0;

  // ACK, T-bit, Parity
  logic ack_done, parity_bit;
  logic rx_tbit_done, tx_tbit_done;
  assign ack_done = bus_tx_done_i;
  assign tx_tbit_done = bus_tx_done_i;
  assign rx_tbit_done = bus_rx_done_i;
  assign parity_bit = ^{last_byte, 1'b1};

  // Decoder of bytes
  logic bus_addr_valid;
  logic bus_rnw_d, bus_rnw_q;
  logic [6:0] bus_addr_d, bus_addr_q;
  logic is_our_addr_match, is_rsvd_byte_match;
  assign is_our_addr_match = target_dyn_address_valid_i ? (target_dyn_address_i == bus_addr_q) :
                             target_sta_address_valid_i ? (target_sta_address_i == bus_addr_q) :
                             1'b0;
  assign is_rsvd_byte_match = ({bus_addr_q, bus_rnw_q} == 8'hFC);

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_bus_addr_matcher
    if (~rst_ni) begin
      bus_rnw_q  <= '0;
      bus_addr_q <= '0;
    end else begin
      if (bus_addr_valid) begin
        bus_rnw_q  <= bus_rnw_d;
        bus_addr_q <= bus_addr_d;
      end else if (target_idle_o) begin
        bus_rnw_q  <= '0;
        bus_addr_q <= '0;
      end
    end
  end

  logic parity_err;
  always_ff @(posedge clk_i or negedge rst_ni) begin : latch_parity_error
    if (~rst_ni) begin
      parity_err <= 1'b0;
    end else begin
      if (parity_err_o) begin
        parity_err <= 1'b1;
      end else if (target_idle_o) begin
        parity_err <= 1'b0;
      end
    end
  end

  logic rx_overflow_err_q, rx_overflow_err_r;
  always_ff @(posedge clk_i or negedge rst_ni) begin : latch_rx_overflow_error
    if (~rst_ni) begin
      rx_overflow_err_r <= 1'b0;
      rx_overflow_err_q <= 1'b0;
    end else begin
      rx_overflow_err_q <= rx_overflow_err_r;
      if (state_d == RxPWriteData & ~rx_fifo_wready_i) rx_overflow_err_r <= 1'b1;
      else if (target_idle_o | state_d inside {RxFByte, Idle}) rx_overflow_err_r <= 1'b0;
    end
  end
  assign rx_overflow_err_o = ~rx_overflow_err_q & rx_overflow_err_r;

  // RX FIFO valid when we finish reading byte (leave RxPWriteData) and there was no parity error
  assign rx_fifo_wvalid_o = (state_q == RxPWriteTbit) &
                            (state_d != RxPWriteTbit) &
                            ~(parity_err | rx_overflow_err_o);
  // Last RX byte when we leave Private Write loop
  assign rx_last_byte_o = (state_q == RxPWriteData) & (state_d inside {RxFByte, Idle});

  // TX FIFO ready when we start writing byte (enter TxPReadData)
  // FIXME: If we enter state TXPReadData, then asserting rready will cause a byte to be
  // consumed from the FIFO, but we might cancel TxPReadData if Rstart occurs.
  assign tx_fifo_rready_o = (state_q != TxPReadData) & (state_d == TxPReadData);

  // State outputs
  always_comb begin : state_outputs
    bus_rx_req_bit_o = '0;
    bus_rx_req_byte_o = '0;
    bus_tx_req_byte_o = '0;
    bus_tx_req_bit_o = '0;
    bus_tx_req_value_o = 8'h1;
    tx_host_nack_o = '0;
    ibi_fifo_rready_o = '0;
    bus_addr_d = '0;
    bus_addr_valid = '0;
    bus_rnw_d = '0;
    rst_action_o = '0;
    is_in_hdr_mode_o = '0;
    nack_transaction_d = '0;
    parity_err_o = '0;

    case (state_q)
      Idle: ;
      RxFByte: begin
        bus_rx_req_byte_o = ~bus_start_det;
        if (bus_rx_done_i) begin
          bus_addr_valid = 1'b1;
          bus_addr_d = bus_rx_data_i[7:1];
          bus_rnw_d = bus_rx_data_i[0];
        end
      end
      CheckFByte: ;
      TxAckFByte: begin
        bus_tx_req_bit_o = 1'b1;
        bus_tx_req_value_o[0] = 1'b0;  // LSB is the only bit used for bit TX transfer
      end
      RxSByte: begin
        bus_rx_req_byte_o = ~bus_start_det;
        if (bus_rx_done_i) begin
          bus_addr_valid = 1'b1;
          bus_addr_d = bus_rx_data_i[7:1];
          bus_rnw_d = bus_rx_data_i[0];
        end
      end
      RxSByteRepeated: begin
        bus_rx_req_byte_o = ~bus_start_det;
        if (bus_rx_done_i) begin
          bus_addr_valid = 1'b1;
          bus_addr_d = bus_rx_data_i[7:1];
          bus_rnw_d = bus_rx_data_i[0];
        end
      end
      CheckSByte: ;
      TxAckSByte: begin
        bus_tx_req_bit_o   = 1'b1;
        bus_tx_req_value_o = '0;
      end
      RxPWriteData: begin
        // TODO: Handle FIFO handshake properly
        bus_rx_req_byte_o = 1'b1;
      end
      RxPWriteTbit: begin
        bus_rx_req_bit_o = 1'b1;
        if (rx_tbit_done) parity_err_o = (parity_bit != bus_rx_data_i[0]);
      end
      TxPReadData: begin
        bus_tx_req_byte_o  = 1'b1;
        bus_tx_req_value_o = tx_fifo_rdata_i;
      end
      TxPReadTbit: begin
        bus_tx_req_bit_o   = 1'b1;
        // FIXME: Try to send always T-bit==1 so that we can get to the end of 1 frame
        // bus_tx_req_value_o = {7'h0, tx_fifo_rvalid_i};
        bus_tx_req_value_o = {7'h0, 1'b1};
      end
      Wait: begin
        nack_transaction_d = 1'b1;
      end

      DoIBI: begin
      end
      DoneIBI: begin
      end

      DoCCC: begin
      end
      DoneCCC: begin
      end

      DoRstAction: begin
      end
      DoHdrExit: begin
      end
      DoHotJoin: begin
      end
      default: ;
    endcase
  end

  // State transitions
  always_comb begin : state_transitions
    state_d = state_q;
    case (state_q)
      Idle: begin
        if (target_enable_i)
          state_d = target_reset_detect_i ? DoRstAction :
          // TODO: Add flow for Hot-Join
          // do_hot_join        ? DoHotJoin :
          is_ibi_pending ? DoIBI : bus_start_det ? RxFByte : Idle;
      end
      RxFByte: begin
        if (bus_rx_done_i) begin
          state_d = CheckFByte;
        end
      end
      CheckFByte: begin
        if (is_rsvd_byte_match || is_our_addr_match) state_d = TxAckFByte;
        else state_d = Wait;
      end
      TxAckFByte: begin
        if (ack_done) begin
          if (is_rsvd_byte_match) state_d = RxSByte;
          else if (is_our_addr_match && bus_rnw_q) state_d = TxPReadData;
          else if (is_our_addr_match && ~bus_rnw_q) state_d = RxPWriteData;
          else state_d = Wait;
        end
      end
      RxSByte: begin
        if (bus_start_det) begin
          state_d = RxSByteRepeated;
        end else if (bus_rx_done_i) begin
          state_d = DoCCC;
        end
      end
      RxSByteRepeated: begin
        if (bus_rx_done_i) begin
          state_d = CheckSByte;
        end
      end
      CheckSByte: begin
        if (is_our_addr_match) state_d = TxAckSByte;
        else state_d = Wait;
      end
      TxAckSByte: begin
        if (ack_done) begin
          if (is_our_addr_match && bus_rnw_q) state_d = TxPReadData;
          else if (is_our_addr_match && ~bus_rnw_q) state_d = RxPWriteData;
          else state_d = Wait;
        end
      end

      // Private Write data loop
      RxPWriteData: begin
        if (bus_start_det) state_d = RxFByte;
        else if (bus_stop_det_i) state_d = Idle;
        else if (bus_rx_done_i) state_d = RxPWriteTbit;
      end
      RxPWriteTbit: begin
        if (rx_tbit_done) state_d = RxPWriteData;
      end

      // Private Read data loop
      TxPReadData: begin
        if (bus_start_det) state_d = RxFByte;
        else if (bus_stop_det_i) state_d = Idle;
        else if (bus_tx_done_i) state_d = TxPReadTbit;
      end
      TxPReadTbit: begin
        if (tx_tbit_done)
          if (tx_fifo_rvalid_i) state_d = TxPReadData;
          else state_d = Wait;
      end

      Wait: begin
        if (bus_start_det) state_d = RxFByte;
        else if (bus_stop_det_i) state_d = Idle;
      end

      DoIBI: begin
        if (is_ibi_done_i) state_d = DoneIBI;
      end
      DoneIBI: begin
        state_d = Idle;
      end

      DoCCC: begin
        if (is_ccc_done_i) state_d = DoneCCC;
      end
      DoneCCC: begin
        state_d = Idle;
      end

      DoRstAction: begin
        // Here, a reset of the core will happen
        // so the state should transition to Idle anyway
        // The transition should be explicit to avoid undefined behavior
        state_d = Idle;
      end
      DoHdrExit: begin
        state_d = Idle;
      end
      DoHotJoin: begin
        if (is_hotjoin_done_i) state_d = Idle;
      end
      default: begin
        state_d = state_q;
      end
    endcase

    // Bypass state transition for Target Reset Pattern and HDR Exit Pattern
    if (target_reset_detect_i) state_d = DoRstAction;
    else if (hdr_exit_detect_i) state_d = DoHdrExit;
  end

  // Synchronous state transition
  always_ff @(posedge clk_i or negedge rst_ni) begin : state_transition
    if (!rst_ni) begin
      state_q <= Idle;
    end else begin
      state_q <= state_d;
    end
  end

  assign target_idle_o = (state_q == Idle);

  // TODO: Also sub FSM should contribute
  // TODO: Maybe we can do it based on write module rather than states
  assign target_transmitting_o =
  (state_q inside {TxAckFByte, TxAckSByte, TxPReadData, TxPReadTbit});

  // TODO: Count which transaction and transfers were addressed to us
  // TODO: Expose xfer,xact counters
  assign event_cmd_complete_o = '0;

  // TODO: Handle events
  assign event_unexp_stop_o = '0;
  assign event_tx_arbitration_lost_o = '0;
  assign event_tx_bus_timeout_o = '0;
  assign event_read_cmd_received_o = '0;

  // During a host issued read, a stop was received without first seeing a nack.
  // This may be harmless but is technically illegal behavior, notify software.
  assign event_unexp_stop_o = target_enable_i & ~bus_tx_idle_i;

  // Record each transaction that gets NACK'd.
  assign event_target_nack_o = !nack_transaction_q && nack_transaction_d;

endmodule : i3c_target_fsm
