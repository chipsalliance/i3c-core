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

  TODO: Check that dynamic address really takes precedence
  over static address in determining communication flow (I2C/I3C)

  Specification doesn't exactly mention which address takes
  precedence in a situation where the dynamic and static address
  are the same - this can happen as there's even a dedicated CCC
  for setting the dynamic address to be the same as the static
  address. This is important for determining whether or not to
  expect ACKs or T-bits after a byte is transmitted. Since there
  are communication flow variants where the transfer starts/doesn't
  start with a reserved byte for both I2C and I3C so the type of
  communication (I2C/I3C) is decided based on the type of address
  that matched.
  We assume here that dynamic address takes precedence over the
  static address since sections 5.1.2 and 5.1.2.1.1 hint at this
  interpretation but it's not explicitly written anywhere
*/

module i3c_target_fsm
  import controller_pkg::*;
#(
    parameter int unsigned RxDataWidth = 8,
    parameter int unsigned TxDataWidth = 8
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

    input target_enable_i,  // enable target functionality

    input        scl_i,       // serial clock input from i2c bus
    output logic scl_o,       // serial clock output to i2c bus
    input        sda_i,       // serial data input from i2c bus
    output logic sda_o,       // serial data output to i2c bus
    output logic sel_od_pp_o, // select open-drain or push-pull driver

    // Bus monitor interface
    input logic bus_start_det_i,
    input logic bus_stop_detect_i,
    input logic bus_arbitration_lost_i,  // Lost arbitration while transmitting
    input logic bus_timeout_i,           // The bus timed out, with SCL held low for too long.

    output logic target_idle_o,  // indicates the target is idle
    output logic target_transmitting_o,  // Target is transmitting SDA (disambiguates high sda_o)

    // Bus TX interface
    input logic bus_tx_req_err_i,
    input logic bus_tx_done_i,
    input logic bus_tx_idle_i,
    output logic bus_tx_req_byte_o,
    output logic bus_tx_req_bit_o,
    output logic [7:0] bus_tx_req_value_o,

    // Bus RX interface
    output logic bus_rx_req_o,
    output logic bus_rx_abort_o,
    input logic bus_rx_done_i, // Byte can be read
    input logic [7:0] bus_rx_data_i, // Byte
    input logic [3:0] bus_rx_data_idx_i, // Bit id in byte (0-7)

    // TX FIFO used for Target Read
    input  logic                   tx_fifo_rvalid_i,  // indicates there is valid data in tx_fifo
    output logic                   tx_fifo_rready_o,  // pop entry from tx_fifo
    input  logic [TxFifoWidth-1:0] tx_fifo_rdata_i,   // byte in tx_fifo to be sent to host
    output logic                   tx_host_nack_o,    // NACK has been received during transmission

    // RX FIFO used for Target Write
    output logic                   rx_fifo_wvalid_o,  // high if there is valid data in rx_fifo
    output logic [RxFifoWidth-1:0] rx_fifo_wdata_o,   // data to write to rx_fifo from target
    input  logic                   rx_fifo_wready_i,

    // IBI FIFO
    input  logic                    ibi_fifo_rvalid_i,
    output logic                    ibi_fifo_rready_o,
    input  logic [IbiFifoWidth-1:0] ibi_fifo_rdata_i,

    // IBI address
    input logic [6:0] ibi_address_i,

    input logic is_sta_addr_match_i,
    input logic is_dyn_addr_match_i,
    input logic is_i3c_rsvd_addr_match_i,
    input logic is_any_addr_match_i,
    output logic [6:0] bus_addr_o,
    output logic bus_rnw_o,
    output logic bus_addr_valid_o,

    output logic event_target_nack_o,  // this target sent a NACK (this is used to keep count)
    output logic event_cmd_complete_o,  // Command is complete
    output logic event_unexp_stop_o,  // target received an unexpected stop
    output logic event_tx_arbitration_lost_o,  // Arbitration was lost during a read transfer
    output logic event_tx_bus_timeout_o,  // Bus timed out during a read transfer
    output logic event_read_cmd_received_o,  // A read awaits confirmation for TX FIFO release

    output logic [7:0] rst_action_o,
    output logic       is_in_hdr_mode_o,
    input  logic       hdr_exit_detect_i,

    input logic scl_negedge_i,
    input logic scl_posedge_i,
    input logic sda_negedge_i,
    input logic sda_posedge_i
);
  logic        nack_transaction_q;  // Set if the rest of the transaction needs to be nack'd.
  logic        nack_transaction_d;

  // Other internal variables
  logic scl_d;  // scl internal
  logic sda_d;  // data internal

  // Target specific variables
  logic expect_stop;

  // Latch whether this transaction is to be NACK'd.
  always_ff @(posedge clk_i or negedge rst_ni) begin : clk_nack_transaction
    if (!rst_ni) begin
      nack_transaction_q <= 1'b0;
    end else begin
      nack_transaction_q <= nack_transaction_d;
    end
  end

  // First 2 bytes of the transfer define the flow
  logic [7:0] fbyte; // First byte
  logic fbyte_valid;
  logic [7:0] sbyte; // Second byte
  logic sbyte_valid;

  logic [7:0] rx_data_byte;
  logic rx_data_byte_valid;
  logic [7:0] tx_data_byte;
  logic tx_data_byte_valid;

  // Decoder of bytes
  logic is_byte_our_addr;
  assign is_byte_our_addr = is_dyn_addr_match_i | is_sta_addr_match_i;

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
    Idle,
    // Read first incoming byte of the transaction
    RxFByte,
    // Check if we should participate in the xfer
    CheckFByte,
    // Ack or Nack the xfer
    TxAckFByte,
    // Check for next symbol after ACK
    // If the symbol is
    RxFSymbol,
    RxSByte,
    CheckSByte,
    TxAckSByte,
    RxPWriteData,
    RxPWriteTbit,
    RxDSymbol,
    RxPWriteData,
    RxPWriteTbit,
    RxPWriteSymbol,
    TxPReadData,
    TxPReadTbit,
    Wait,

    Idle,
    // Decode beginning of the frame
    // After S, there is always a byte to read:
    // - matching Target Address
    // - not matching Target Address
    // - Reserved Address
    ReadFByte,
    // ACK participation (if applicable)
    // After ACK there can be RS or Data Byte
    // Preemptively begin byte_read, which will be
    // canceled in ReadSymbol if the symbol is RS
    WriteAck,
    // Check if symbol is RS or first data bit
    ReadSymbol,

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


    // Handle the HDR pattern
    DoHDR,
    DoneHDR,

    // Reset pattern causes reset of the core
    // so "Done" return state is not needed.
    DoRstAction,

    // A transfer is happening, but we ignore it,
    // so we wait for SR or P here
    // Example:
    // In first part of the transfer another target is addressed,
    // but after RS we could be addressed.
    Wait
  } primary_state_e;

  primary_state_e state_q, state_d;

  // ACK, T-bit
  logic ack_done;
  assign ack_done = bus_tx_done_i;

  logic tbit_done;
  assign tbit_done = bus_tx_done_i;

  // Byte Read
  logic byte_read_done;
  logic [2:0] bit_id;
  logic [7:0] byte_read_sr;
  always_ff @( posedge clk_i or negedge rst_ni ) begin : proc_bit_id
    if (!rst_ni) begin
        bit_id <= '0;
        byte_read_sr <= '0;
    end else begin
        if (byte_read_clr) begin
          bit_id <= '0;
          byte_read_sr <= '0;
        end else if (scl_posedge) begin
          bit_id <= bit_id + 1'b1;
          byte_read_sr[7:0] <= {byte_read_sr[6:0],sda_i};
        end else begin
          bit_id <= bit_id;
        end
    end
  end

  assign byte_read_done = (bit_id == 3'h7);
  assign byte_read_clr = (state_q == Idle) && bus_start_det_i;

  // Register last input byte
  logic[7:0] last_byte;
  always_ff @( posedge clk_ni or negedge rst_ni ) begin : proc_last_byte
    if(~rst_ni) begin
      last_byte <= '0;
    end else begin
      if (byte_read_done)
        last_byte <= byte_read_sr;
    end
  end

  assign is_byte_rsvd_addr = last_byte == {7'h7E,1'b0};

  logic [6:0] bus_addr;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      bus_rnw_o <= '0;
      bus_addr_o <= '0;
      bus_addr_valid_o <= '0;
    end else begin
      if (bus_addr_valid) begin
        bus_rnw_o <= bus_rnw;
        bus_addr_o <= bus_addr;
        bus_addr_valid_o <= bus_addr_valid;
      end else if (target_idle_o) begin
        bus_rnw_o <= '0;
        bus_addr_o <= '0;
        bus_addr_valid_o <= '0;
      end
    end
  end

  // State outputs
  always_comb begin : state_transitions
    target_idle_o = '0;
    target_transmitting_o = '0;
    bus_rx_req_o = '0;
    bus_rx_abort_o = '0;
    bus_tx_req_byte_o = '0;
    bus_tx_req_bit_o = '0;
    bus_tx_req_value_o = '0;
    tx_fifo_rready_o = '0;
    tx_host_nack_o = '0;
    rx_fifo_wvalid_o = '0;
    rx_fifo_wdata_o = '0;
    ibi_fifo_rready_o = '0;
    bus_addr = '0;
    bus_addr_valid = '0;
    bus_rnw = '0;
    rst_action_o = '0;
    is_in_hdr_mode_o = '0;

    case (state_q)
      Idle: begin
        target_idle_o = 1'b1;
        bus_rx_req_o = bus_start_det_i;  // Assert HIGH as preparation for next state
      end
      RxFByte: begin
        if (bus_rx_done_i) begin
          bus_addr = bus_rx_data_i[7:1];
          bus_rnw = bus_rx_data_i[0];
          bus_addr_valid = 1'b1;
        end
      end
      CheckFByte: ;
      TxAckFByte: begin
        bus_tx_req_bit_o = 1'b1;
        bus_tx_req_value_o[0] = 1'b0;  // LSB is the only bit used for bit TX transfer
        bus_rx_req_o = 1'b1;  // Assert HIGH as preparation for next state
      end
      RxSByte: begin
        if (bus_start_det_i) begin
          bus_rx_abort_o = 1'b1;
        end
      end
      RxSByteRepeated:begin
        if (byte_rx_done) begin
          if (is_byte_our_addr && bus_rnw_o)
              state_d = PReadData;
          else if (is_byte_our_addr && ~bus_rnw_o)
              state_d = PWriteData;
          else
              state_d = Wait;
        end
      end
      CheckSByte: begin
      end
      TxAckSByte: begin
      end
      RxPWriteData: begin
      end
      RxPWriteTbit: begin
      end
      RxDSymbol: begin
      end
      RxPWriteData: begin
      end
      RxPWriteTbit: begin
      end
      RxPWriteSymbol: begin
      end
      TxPReadData: begin
      end
      TxPReadTbit: begin
      end
      Wait: begin
      end
      DoIBI: begin
      end
      DoCCC: begin
      end
      DoRstAction: begin
      end
      DoHotJoin: begin
      end
      DoneIBI: begin
      end
      DoneCCC: begin
      end
      default: ;
    endcase
  end

  // State transitions
  always_comb begin : state_transitions
    case (state_q)
      Idle: begin
        state_d = is_hdr_mode                         ? Idle :
                  bus_detect_rst_pattern              ? DoRstAction :
                  do_hot_join                         ? DoHotJoin :
                  (bus_available_i && is_ibi_pending) ? DoIBI :
                  bus_start_det_i                     ? ReadFByte : Idle;
        end
      RxFByte: begin
        if (bus_rx_done_i) begin
          state_d = CheckFByte;
        end
      end
      CheckFByte: begin
        if (is_i3c_rsvd_addr_match_i || is_byte_our_addr)
          state_d = TxAckFByte;
        else
          state_d = Wait;
      end
      TxAckFByte: begin
        if (bus_tx_done_i) begin
          if (is_i3c_rsvd_addr_match_i)
              state_d = RxSByte;
          else if (is_byte_our_addr && bus_rnw_o)
              state_d = PReadData;
          else if (is_byte_our_addr && ~bus_rnw_o)
              state_d = PWriteData;
          else
              state_d = Wait;
        end
      end
      RxSByte: begin
        if (bus_start_det_i) begin
          state_d = RxSByteRepeated;
        end else if (bus_rx_done_i) begin
          state_d = DoCCC;
        end
      end
      RxSByteRepeated:begin
        if (bus_rx_done_i) begin
          if (is_byte_our_addr && bus_rnw_o)
              state_d = PReadData;
          else if (is_byte_our_addr && ~bus_rnw_o)
              state_d = PWriteData;
          else
              state_d = Wait;
        end
      end
      CheckSByte: begin
        if (is_sbyte_our_addr)
          state_d = TxAckSByte;
        else
          state_d = Wait;
      end
      TxAckSByte: begin
        if (ack_done) begin
          if (is_sbyte_our_addr && is_xfer_rnw)
              state_d = TxPReadData;
          else if (is_sbyte_our_addr && ~is_xfer_rnw)
              state_d = RxPWriteData;
        end
      end

      // Private Write data loop
      RxPWriteData: begin
          if (byte_rx_done)
            state_d = RxPWriteTbit;
      end
      RxPWriteTbit: begin
          if (tbit_rx_done)
            state_d = RxDSymbol;
      end
      RxDSymbol: begin
        if (bus_start_det_i) begin
          state_d = RxSByteRepeated;
        end else if(bus_first_bit_det_i) begin
            state_d = RxPWriteData;
        end
      end

      // Private Write data loop
      RxPWriteData: begin
          if (byte_rx_done)
            state_d = RxPWriteTbit;
      end
      RxPWriteTbit: begin
          if (tbit_rx_done)
            state_d = RxPWriteSymbol;
      end
      RxPWriteSymbol: begin
        if (bus_start_det_i) begin
          state_d = RxFByte;
        end else if(bus_first_bit_det_i) begin
            state_d = RxPWriteData;
        end
      end

      // Private Read data loop
      TxPReadData: begin
          if (byte_tx_done)
            state_d = TxPReadTbit;
      end
      TxPReadTbit: begin
          if (tbit_tx_done)
            if (tbit)
              state_d = TxPReadData;
            else
              state_d = Wait;
      end

      Wait: begin
        if (bus_start_det_i)
          state_d = RxFByte;
        else if (bus_stop_detect_i)
          state_d = Idle;
      end

      DoIBI: begin
        if(is_ibi_done)
          state_d = DoneIBI;
      end
      DoCCC: begin
        if(is_ccc_done)
          state_d = DoneCCC;
      end
      DoRstAction: begin
        // Here, a reset of the core will happen
        // so the state should transition to Idle anyway
        // The transition should be explicit to avoid undefined behavior
        state_d = Idle;
      end
      DoHotJoin: begin
        if (is_hot_join_done)
          state_d = Idle;
      end
      DoneIBI: begin
        state_d = ReadSymbol;
      end
      DoneCCC: begin
        state_d = ReadSymbol;
      end
      default: begin
        state_d = state_q;
      end
    endcase
  end

  always_comb begin : state_outputs
    case (state_q)
        WriteAck: begin
          bus_drive_o = 1'b1;
        end
        default: begin
          bus_drive_o = 1'b0;
      end
    endcase
  end

  // Register address from incoming transfers
  logic [6:0] last_incoming_addr;

  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) begin
      last_incoming_addr <= 1'b0;
    end else if ((state_q == ReadFirstByte || state_q == ReadSecondByte) && byte_read_done) begin
      last_incoming_addr <= byte_read;
    end

  // Synchronous state transition
  always_ff @(posedge clk_i or negedge rst_ni) begin : state_transition
    if (!rst_ni) begin
      state_q <= Idle;
    end else begin
      state_q <= state_d;
    end
  end

  assign scl_o = scl_d;
  assign sda_o = sda_d;

  logic target_idle;
  assign target_idle = state_q == Idle;
  assign target_idle_o = target_idle;

  // TODO: Also sub FSM should contribute
  // TODO: Maybe we can do it based on write module rather than states
  assign target_transmitting_o = (state_q == WriteAck);

  // TODO: Count which transaction and transfers were addressed to us
  // TODO: Expose xfer,xact counters
  assign event_cmd_complete_o = '0;

  // During a host issued read, a stop was received without first seeing a nack.
  // This may be harmless but is technically illegal behavior, notify software.
  assign event_unexp_stop_o = target_enable_i & rw_bit_q &
                              bus_stop_detect_i & !expect_stop;

  // Record each transaction that gets NACK'd.
  assign event_target_nack_o = !nack_transaction_q && nack_transaction_d;

endmodule : i3c_target_fsm
