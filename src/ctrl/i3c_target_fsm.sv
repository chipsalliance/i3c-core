// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: I3C finite state machine

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

  Dynmic/static address precedence:
    * If neither address is defined, then the core will ignore all addressed traffic
    * If only static address is defined, it will be used for Legacy I2C transfers or in bus configuration stage
    * If only dynamic address is defined, it will be used for I3C transfers
    * If both are defined, then:
      * static address will be used for Legacy I2C transfers
      * dynamic address will be used for I3C transfers
*/

module i3c_target_fsm import i3c_pkg::*; (
  input  clk_i,  // clock
  input  rst_ni, // active low reset

  input  logic target_enable_i, // enable target functionality

  // Bus monitor interface
  input  logic bus_start_det_i,
  input  logic bus_rstart_det_i,
  input  logic bus_stop_det_i,
  input  logic bus_timeout_i,  // The bus timed out, with SCL held low for too long.
  input  logic bus_available_i,
  input  logic arbitration_lost_i,

  input  logic scl_negedge_i,  // For assertions only

  output logic target_idle_o,  // indicates the target is idle

  // Bus Tx interface
  output bus_tx_req_t bus_tx_req_o,
  input  bus_tx_rsp_t bus_tx_rsp_i,

  // Bus Rx interface
  output bus_rx_req_t bus_rx_req_o,
  input  bus_rx_rsp_t bus_rx_rsp_i,

  // TX FIFO used for Target Read
  input  logic      tx_desc_avail_i,
  input  logic      tx_fifo_rvalid_i,  // indicates there is valid data in tx_fifo
  output logic      tx_fifo_rready_o,  // pop entry from tx_fifo
  input  i3c_byte_t tx_fifo_rdata_i,   // byte in tx_fifo to be sent to Controller
  output logic      tx_host_nack_o,    // NACK has been received during transmission
  input  logic      tx_last_byte_i,

  // RX FIFO used for Target Write
  output logic      rx_fifo_wvalid_o,  // high if there is valid data for rx_fifo
  output i3c_byte_t rx_fifo_wdata_o,   // data to write to rx_fifo from target
  input  logic      rx_fifo_wready_i,
  output logic      rx_last_byte_o,

  // Target address
  input  logic [6:0] target_sta_addr_i,
  input  logic       target_sta_addr_valid_i,
  input  logic [6:0] target_dyn_addr_i,
  input  logic       target_dyn_addr_valid_i,
  input  logic [6:0] virtual_target_sta_addr_i,
  input  logic       virtual_target_sta_addr_valid_i,
  input  logic [6:0] virtual_target_dyn_addr_i,
  input  logic       virtual_target_dyn_addr_valid_i,
  // Required for decision whether to act upon IBI requests
  input  logic       target_ibi_addr_valid_i,
  input  logic [6:0] target_ibi_addr_i,

  // IBI data interface
  input  logic      ibi_byte_valid_i,
  output logic      ibi_byte_ready_o,
  input  i3c_byte_t ibi_byte_i,
  input  logic      ibi_byte_last_i,
  output logic      ibi_byte_flush_o,     // Aborts IBI and flushes TTI IBI Queue

  // IBI control / status
  input  logic [2:0]  ibi_retry_num_i,     // TTI.CONTROL.IBI_RETRY_NUM
  input  logic        ibi_retry_ctr_rst_i, // TTI.RESET_CONTROL.IBI_RETRY_CTR_RST
  output ibi_status_e ibi_status_o,        // TTI.STATUS.LAST_IBI_STATUS
  output logic        ibi_status_we_o,     // TTI.STATUS.LAST_IBI_STATUS write enable, triggers IRQ

  output logic [7:0] last_addr_o,     // Includes rnw as LSB
  output logic       last_addr_valid_o,

  output logic event_target_nack_o,  // this target sent a NACK (this is used to keep count)
  output logic event_cmd_complete_o,  // Command is complete
  output logic event_unexp_stop_o,  // target received an unexpected stop
  output logic event_tx_arbitration_lost_o,  // Arbitration was lost during a read transfer
  output logic event_tx_bus_timeout_o,  // Bus timed out during a read transfer
  output logic event_read_cmd_received_o,  // A read awaits confirmation for TX FIFO release

  input  logic target_reset_detect_i,
  input  logic hdr_exit_detect_i,
  input  logic in_hdr_mode_i,          // From CCC module: currently in HDR mode
  input  logic ibi_enable_i,           // TTI.CONTROL.IBI_EN

  // Interfacing with CCC subFSMs
  output ccc_cmd_e  ccc_data_o,
  output logic      ccc_valid_o,
  input  logic      is_ccc_done_i,
  input  logic      is_next_ccc_i,

  // TE0 Error Interface (HDR Exit condition)
  input  logic      te0_enable_i,
  output logic      te0_err_o,

  input  logic is_hotjoin_done_i,

  // TE2 Error Detection Enable
  input  logic te2_err_det_en_i,

  output logic te2_err_priv_wr,
  output logic rx_overflow_err_o,
  output logic virtual_device_sel_o,
  output logic xfer_in_progress_o,

  output logic tx_pr_start_o,
  output logic tx_pr_abort_o
);

  logic bus_any_start_det;

  // Target specific variables
  logic nack_transaction_q, nack_transaction_d;
  logic rx_overflow_err_q, rx_overflow_err_r;

  i3c_byte_t last_byte;

  logic bus_tx_req_bit;
  logic bus_rx_req_bit, bus_rx_req_byte;

  logic parity_bit;
  logic parity_err;
  logic rx_fifo_wvalid;

  logic      bus_addr_valid;
  logic      bus_rnw_d, bus_rnw_q;
  i3c_addr_t bus_addr_d, bus_addr_q;

  logic is_our_addr_match, is_virtual_addr_match, is_any_addr_match, is_rsvd_byte_match;

  logic [2:0] ibi_retry_cnt_q, ibi_retry_cnt_d;
  logic       ibi_pending, ibi_can_retry;

  // Data type to encode various conditions for suppressing the servicing of pending IBIs
  typedef enum logic [1:0] { 
    InhibitNone,
    InhibitRetry,
    InhibitArbLost
  } ibi_inhibit_e;

  ibi_inhibit_e ibi_inhibit_q, ibi_inhibit_d;

  ccc_cmd_e  ccc_data;
  logic      ccc_data_valid;

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
    // - hot-join (currently not implemented)
    // - reset pattern
    Idle,
    // Read first incoming byte of the transaction, arbitrable
    RxFByteArb,
    // Read first incoming byte of the transaction, non-arbitrable
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
    // Signal to Controller in Tbit to transfer more bytes
    TxPReadTbitCont,
    // Signal to Controller in Tbit to end the transfer
    TxPReadTbitEnd,
    // Transfer is not targeted to us or we are not ready, NAck and wait for SR or P
    WaitRestart,

    // There is a CCC to process
    // Go to subFSM for CCC execution
    DoCCC,
    // After CCC is done, return here
    DoneCCC,

    // Currently not implemented and not reachable
    DoHotJoin,

    // Reset pattern causes reset of the core
    // so "Done" return state is not needed.
    DoRstAction,

    // HDR Mode: ignore all bus activity until HDR exit pattern detected
    InHDRMode,

    // IBI handling states
    // Drive IBI address onto SDA after pulling it low on a bus available condition
    IbiDriveAddr,
    // Read (N)ACK bit and check whether the Controller accepted our IBI request
    IbiReadAck,
    // Send IBI payload in push-pull mode, including MDB
    IbiSendData,
    // Try to send another IBI payload byte
    IbiTbitCont,
    // Last IBI payload byte sent; signal end to Controller
    IbiTbitEnd
  } primary_state_e;

  primary_state_e state_q, state_d;


  // Either Start or RStart condition
  assign bus_any_start_det = bus_start_det_i || bus_rstart_det_i;

  // FUTUREFIX: tx_host_nack_o is irrelevant for v1p5 release
  assign tx_host_nack_o = 1'b0;

  // Shorthand helper signal for checking for active bit requests
  assign bus_tx_req_bit = bus_tx_req_o.req_valid && (bus_tx_req_o.req_type == RawBit);

  assign bus_rx_req_o = '{
    req_byte: bus_rx_req_byte,
    req_bit:  bus_rx_req_bit
  };

  assign rx_fifo_wdata_o = last_byte;

  // Calculate parity bit
  assign parity_bit = ^{last_byte, 1'b1};

  // Primary target address matching
  // Per I3C spec: Once a target has a dynamic address, it stops responding to its static address
  assign is_our_addr_match = ((bus_addr_q == target_dyn_addr_i) && target_dyn_addr_valid_i) ||
                             ((bus_addr_q == target_sta_addr_i) && target_sta_addr_valid_i && ~target_dyn_addr_valid_i);

  // Virtual target address matching
  // Per I3C spec: Once a target has a dynamic address, it stops responding to its static address
  assign is_virtual_addr_match = ((bus_addr_q == virtual_target_dyn_addr_i) && virtual_target_dyn_addr_valid_i) ||
                                 ((bus_addr_q == virtual_target_sta_addr_i) && virtual_target_sta_addr_valid_i && ~virtual_target_dyn_addr_valid_i);

  assign is_any_addr_match = is_our_addr_match || is_virtual_addr_match;

  assign is_rsvd_byte_match = ({bus_addr_q, bus_rnw_q} == 8'hFC); // `I3C_RSVD_BYTE

  // Shorthand signal for when all conditions for sending an IBI are acutally met
  assign ibi_pending = ibi_byte_valid_i && ibi_enable_i && target_ibi_addr_valid_i;
  // Retry allowed if count not yet met or indefinite attempts allowed
  assign ibi_can_retry = (ibi_retry_num_i == 3'd7) || (ibi_retry_cnt_q <= ibi_retry_num_i);

  // TE0 error: Invalid reserved address + RnW combinations
  // Uses shared function from i3c_pkg to ensure consistency with ccc.sv
  // Qualified with last_addr_valid_o to only report when address is valid
  assign te0_err_o = te0_enable_i && last_addr_valid_o && is_te0_rsvd_addr_err(bus_addr_q, bus_rnw_q);

  // Latch whether this transaction is to be NACK'd.
  always_ff @(posedge clk_i or negedge rst_ni) begin : clk_nack_transaction
    if (!rst_ni) begin
      nack_transaction_q <= 1'b0;
    end else begin
      nack_transaction_q <= nack_transaction_d;
    end
  end

  // Register last input byte
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_last_byte
    if (~rst_ni) begin
      last_byte <= '0;
    end else begin
      if (bus_rx_rsp_i.done && bus_rx_req_byte) last_byte <= bus_rx_rsp_i.data;
    end
  end

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

  assign last_addr_o = {bus_addr_q, bus_rnw_q};

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      last_addr_valid_o <= '0;
    end else if (bus_any_start_det || bus_stop_det_i || in_hdr_mode_i) begin
      last_addr_valid_o <= '0;
    end else if (bus_addr_valid) begin
      last_addr_valid_o <= '1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : latch_parity_error
    if (~rst_ni) begin
      parity_err <= 1'b0;
    end else begin
      // te2_err_priv_wr is already gated with te2_err_det_en_i at detection source
      if (te2_err_priv_wr) begin
        parity_err <= 1'b1;
      end else if (target_idle_o) begin
        parity_err <= 1'b0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : latch_rx_overflow_error
    if (~rst_ni) begin
      rx_overflow_err_r <= 1'b0;
      rx_overflow_err_q <= 1'b0;
    end else begin
      rx_overflow_err_q <= rx_overflow_err_r;
      if (state_d == RxPWriteData & ~rx_fifo_wready_i & rx_fifo_wvalid_o) rx_overflow_err_r <= 1'b1;
      else if (target_idle_o | state_d inside {RxFByte, Idle}) rx_overflow_err_r <= 1'b0;
    end
  end

  assign rx_overflow_err_o = ~rx_overflow_err_q & rx_overflow_err_r;

  // RX FIFO valid when we finish reading byte (leave RxPWriteTbit) and there was no protocol error.
  // Use te2_err_priv_wr (combinational) so that errored byte is blocked in the same cycle the 
  // mismatch is detected.
  assign rx_fifo_wvalid = (state_q == RxPWriteTbit) && (state_d != RxPWriteTbit) &&
                          !(te2_err_priv_wr || parity_err || rx_overflow_err_o);

  always_ff @(posedge clk_i or negedge rst_ni) begin : latch_rx_fifo_wvalid
    if (~rst_ni) begin
      rx_fifo_wvalid_o <= 1'b0;
    end else begin
      if (rx_fifo_wvalid) begin
        rx_fifo_wvalid_o <= 1'b1;
      end
      if (rx_fifo_wvalid_o & rx_fifo_wready_i) begin
        rx_fifo_wvalid_o <= 1'b0;
      end
    end
  end
  // FSM on the last T bit will transition to
  // RxPWriteData because the Sr/Stop doesn't happen until after we complete
  // the T bit and are waiting for the next set of data in RxPWriteData. In
  // this state if we get a repeat start we transition into RxFByte if we get
  // a stop we transition to Idle. 
  assign rx_last_byte_o = (state_q == RxPWriteData) && (state_d inside {RxFByte, Idle});

  // Logic for latching CCC code
  always_ff @(posedge clk_i or negedge rst_ni) begin : latch_ccc_data
    if (~rst_ni) begin
      ccc_data_o <= ccc_cmd_e'('0);
    end else if (ccc_data_valid) begin
      ccc_data_o <= ccc_data;
    end
  end

  // IBI retry counter logic
  always_comb begin
    ibi_retry_cnt_d = ibi_retry_cnt_q;

    // Reset counter on success or request by FW, increment on appropriate failure types
    if ((ibi_status_we_o && (ibi_status_o == IbiSuccess)) || ibi_retry_ctr_rst_i) begin
      ibi_retry_cnt_d = '0;
    end else if ((ibi_retry_num_i != 3'd7) && ibi_status_we_o &&
                 (ibi_status_o inside {IbiFailureAddressArb, IbiFailureNack})) begin
      ibi_retry_cnt_d = ibi_retry_cnt_q + 1;
    end
  end

  // Mini-FSM to suppress repeated IBI attempts and status reports on certain conditions
  always_comb begin : fsm_ibi_inhibit
    ibi_inhibit_d = ibi_inhibit_q;
    case (ibi_inhibit_q)
      // Normal operation; leave when any suppression condition becomes true
      InhibitNone: begin
        if (ibi_status_we_o && (ibi_status_o == IbiFailureAddressArb)) begin
          ibi_inhibit_d = InhibitArbLost;
        end else if (ibi_status_we_o && (ibi_status_o == IbiFailureRetry)) begin
          ibi_inhibit_d = InhibitRetry;
        end
      end
      // IBIs suppressed due to lost arbitration: Release upon bus available condition
      InhibitArbLost: begin
        if (bus_available_i) begin
          ibi_inhibit_d = InhibitNone;
        end
      end
      // IBIs suppressed due to retry failure: Release upon retry condition becoming true again
      InhibitRetry: begin
        if (ibi_can_retry) begin
          ibi_inhibit_d = InhibitNone;
        end
      end
    endcase
  end

  // Main FSM
  always_comb begin : fsm_target_main
    tx_pr_start_o = 1'b0;
    tx_pr_abort_o = 1'b0;
    te2_err_priv_wr = 1'b0;

    nack_transaction_d = 1'b0;

    ccc_data       = ccc_cmd_e'('0);
    ccc_data_valid = 1'b0;
    ccc_valid_o    = 1'b0;

    bus_addr_d     = '0;
    bus_addr_valid = 1'b0;

    bus_rnw_d = 1'b0;

    bus_tx_req_o = '{
      req_valid:  1'b0,
      req_type:   RawBit,
      drive_type: OpenDrain,
      data:       '1
    };

    tx_fifo_rready_o = 1'b0;

    bus_rx_req_bit  = 1'b0;
    bus_rx_req_byte = 1'b0;

    ibi_status_o     = IbiSuccess;
    ibi_status_we_o  = 1'b0;
    ibi_byte_ready_o = 1'b0;
    ibi_byte_flush_o = 1'b0;

    state_d = state_q;
    case (state_q)
      Idle: begin
        if (target_enable_i) begin
          if (ibi_pending && (ibi_inhibit_q != InhibitRetry)) begin
            if (!ibi_can_retry) begin
              ibi_status_we_o = 1'b1;
              ibi_status_o    = IbiFailureRetry;
            end else if (bus_available_i) begin
              state_d = IbiDriveAddr;
            end
          end
          
          // Reset detection and Start conditions overwrite the state_d decision above
          // Any pending IBIs will be handled in RxFByteArb
          if (target_reset_detect_i) begin
            state_d = DoRstAction;
          end else if (bus_start_det_i) begin
            // In Idle, we only wait for a Start, which initiates the arbitrable address header
            // Suppress arbitration after a lost IBI arbitration until bus available condition,
            // as per Sect. 5.1.6.2, or if we already had a retry failure.
            state_d = (ibi_pending && (ibi_inhibit_q == InhibitNone)) ? RxFByteArb : RxFByte;
          end
        end
      end

      IbiDriveAddr: begin
        // In this state, we send an IBI request to bus_tx_flow, which then first pulls SDA low and
        // subsequently transmits our IBI address, starting at the following negedge of SCL.
        bus_tx_req_o.req_valid = 1'b1;
        bus_tx_req_o.req_type  = InitIbi;
        bus_tx_req_o.data      = {target_ibi_addr_i, 1'b1};

        if (bus_tx_rsp_i.done) begin
          state_d = IbiReadAck;
        end else if (arbitration_lost_i) begin
          // Someone else decided to start transmitting an IBI at almost the exact same time and
          // won arbitration - bad luck for us
          ibi_status_we_o = 1'b1;
          ibi_status_o    = IbiFailureAddressArb;
          state_d = WaitRestart;
        end
      end
      IbiReadAck: begin
        bus_tx_req_o.req_valid = 1'b1;
        bus_tx_req_o.req_type  = AckIbi;

        // Note: Tx and Rx simultaneously! This relies on the 'done' being asserted for both at
        // the rising edge of SCL!
        bus_rx_req_bit = 1'b1;
        if (bus_rx_rsp_i.done) begin
          if (bus_rx_rsp_i.data[0]) begin
            // Controller has NACKed our write request
            ibi_status_we_o = 1'b1;
            ibi_status_o    = IbiFailureNack;
            state_d = WaitRestart;
          end else begin
            state_d = IbiSendData;
          end
        end
      end
      IbiSendData: begin
        bus_tx_req_o.drive_type = PushPull;
        bus_tx_req_o.req_valid  = 1'b1;
        bus_tx_req_o.req_type   = RawByte;
        bus_tx_req_o.data       = ibi_byte_i;

        if (bus_tx_rsp_i.done) begin
          ibi_byte_ready_o = 1'b1;
          state_d = ibi_byte_last_i ? IbiTbitEnd : IbiTbitCont;
        end
      end
      IbiTbitEnd: begin
        bus_tx_req_o.req_valid = 1'b1;
        bus_tx_req_o.req_type  = TReadEnd;

        if (bus_tx_rsp_i.done) begin
          ibi_status_we_o = 1'b1;
          ibi_status_o    = IbiSuccess;
          state_d = WaitRestart;
        end
      end
      IbiTbitCont: begin
        bus_tx_req_o.req_valid = 1'b1;
        bus_tx_req_o.req_type  = TReadCont;
        bus_tx_req_o.data      = ibi_byte_i;

        if (bus_tx_rsp_i.abort) begin
          // The host has pulled SDA low before the next SCL negedge to end the transfer (this is
          // equivalent to a Rs condition) and cancelled the IBI prematurely
          ibi_byte_flush_o = 1'b1;
          ibi_status_we_o  = 1'b1;
          ibi_status_o     = IbiFailurePartialData;
          state_d = RxFByte;
        end else if (bus_tx_rsp_i.done) begin
          // TBit was successfully transmitted as high, we may therefore continue with the next byte
          state_d = IbiSendData;
        end
      end

      RxFByte: begin
        bus_rx_req_byte = !bus_rstart_det_i;
        if (bus_rx_rsp_i.done) begin
          bus_addr_valid = 1'b1;
          bus_addr_d     = bus_rx_rsp_i.data[7:1];
          bus_rnw_d      = bus_rx_rsp_i.data[0];

          state_d = CheckFByte;
        end
      end

      RxFByteArb: begin
        bus_rx_req_byte = !bus_rstart_det_i;

        // Currently, we only get to this state if there is a pending IBI, and IBIs are not surpressed
        // Therefore, the only condition where we do not submit our IBI address is if the retry
        // counter has hit the limit. In that case, and in case we lose arbitration during the address
        // phase, we switch to RxFByte, which continues to hold bus_rx_req_byte high, and processes the
        // received data. We only stay in RxFByteArb is we successfully initiated an IBI, in which case
        // the "received" data is irrelevant, as it is our own IBI address.
        if (ibi_can_retry) begin
          bus_tx_req_o.req_valid  = 1'b1;
          bus_tx_req_o.req_type   = RawByte;
          bus_tx_req_o.drive_type = OpenDrain;
          bus_tx_req_o.data       = {target_ibi_addr_i, 1'b1};

          // On arb lost, inform IBI requester and hand over to regular RxFByte
          // to receive rest of address
          if (arbitration_lost_i) begin
            ibi_status_we_o = 1'b1;
            ibi_status_o    = IbiFailureAddressArb;
            state_d = RxFByte;
          end else if (bus_tx_rsp_i.done) begin
            // IBI address has been submitted successfully, we won arbitration. Continue with IBI.
            state_d = IbiReadAck;
          end
        end else begin
          // Retry count reached
          ibi_status_we_o = 1'b1;
          ibi_status_o    = IbiFailureRetry;
          state_d = RxFByte;
        end
      end
      CheckFByte: begin
        // Signal begin of a private read
        tx_pr_start_o = is_any_addr_match && bus_rnw_q;

        if (is_rsvd_byte_match || is_any_addr_match) begin
          // Do not ACK transaction if it is a read and we don't have data to send
          if (~tx_desc_avail_i && bus_rnw_q) begin
            state_d = WaitRestart;
          end else begin
            state_d = TxAckFByte;
          end
        end else begin
          // Nothing on the bus happened which requires our action; wait for next (Re)Start condition.
          state_d = WaitRestart;
        end
      end
      TxAckFByte: begin
        bus_tx_req_o.req_valid = 1'b1;
        bus_tx_req_o.req_type  = bus_rnw_q ? AckRegular : AckWrite;

        if (bus_tx_rsp_i.done) begin
          if (is_rsvd_byte_match) begin
            state_d = RxSByte;
          end else if (is_any_addr_match) begin
            state_d = bus_rnw_q ? TxPReadData : RxPWriteData;
          end else begin
            state_d = WaitRestart;
          end
        end
      end

      RxSByte: begin
        bus_rx_req_byte = !bus_rstart_det_i;

        if (bus_rstart_det_i) begin
          state_d = RxSByteRepeated;
        end else if (bus_rx_rsp_i.done) begin
          // If we got CCC, this is the Command Code, we need to latch it for the CCC FSM
          ccc_data_valid = 1'b1;
          ccc_data       = ccc_cmd_e'(bus_rx_rsp_i.data);

          state_d = DoCCC;
        end
      end
      RxSByteRepeated: begin
        bus_rx_req_byte = !bus_rstart_det_i;

        if (bus_rx_rsp_i.done) begin
          bus_addr_valid = 1'b1;
          bus_addr_d     = bus_rx_rsp_i.data[7:1];
          bus_rnw_d      = bus_rx_rsp_i.data[0];

          state_d = CheckSByte;
        end
      end
      CheckSByte: begin
        if (is_any_addr_match) begin
          // Signal begin of a private read
          tx_pr_start_o = bus_rnw_q;
          if (!bus_rnw_q || tx_desc_avail_i) begin
            // Either private write or private read and data available
            state_d = TxAckSByte;
          end else begin
            // NAck in case of private read without data available
            state_d = WaitRestart;
          end
        end else begin
          state_d = WaitRestart;
        end
      end
      TxAckSByte: begin
        bus_tx_req_o.req_valid = 1'b1;
        bus_tx_req_o.req_type  = AckRegular;

        if (bus_tx_rsp_i.done) begin
          state_d = bus_rnw_q ? TxPReadData : RxPWriteData;
        end
      end

      // Private Write data loop
      RxPWriteData: begin
        bus_rx_req_byte = !bus_rstart_det_i;

        if (bus_rstart_det_i) begin
          state_d = RxFByte;
        end else if (bus_rx_rsp_i.done) begin
          state_d = RxPWriteTbit;
        end
      end
      RxPWriteTbit: begin
        bus_rx_req_bit = !bus_rstart_det_i;

        if (bus_rstart_det_i) begin
          // Repeated Start during T-bit - new address phase
          state_d = RxFByte;
        end else if (bus_rx_rsp_i.done) begin
          // Gate parity error detection with detection enable at the source
          te2_err_priv_wr = te2_err_det_en_i && (parity_bit != bus_rx_rsp_i.data[0]);
          state_d = RxPWriteData;
        end
      end

      // Private Read data loop
      TxPReadData: begin
        bus_tx_req_o.drive_type = PushPull;
        bus_tx_req_o.req_valid  = 1'b1;
        bus_tx_req_o.req_type   = RawByte;
        bus_tx_req_o.data       = tx_fifo_rdata_i;

        // Neither stop nor restart may occur as SDA is under control of target. Therefore, we do
        // not check for Rs or P here.

        if (bus_tx_rsp_i.done) begin
          // Acknowledge consumption of current byte
          tx_fifo_rready_o = 1'b1;
          // Signal continue or end of read
          state_d = tx_last_byte_i ? TxPReadTbitEnd : TxPReadTbitCont;
        end
      end
      TxPReadTbitEnd: begin
        bus_tx_req_o.req_valid = 1'b1;
        bus_tx_req_o.req_type  = TReadEnd;

        if (bus_tx_rsp_i.done) begin
          state_d = WaitRestart;
        end
      end
      TxPReadTbitCont: begin
        // Special request type: We have to wait until the following SCL negedge to know whether the
        // Controller has aborted the read prematurely. However, if not, we need to provide the MSB
        // of the next byte on that very negedge. Therefore, already provide the next byte as part
        // of this Tbit request; bus_tx_flow will handle all the low-level details.
        bus_tx_req_o.req_valid = 1'b1;
        bus_tx_req_o.req_type  = TReadCont;
        bus_tx_req_o.data      = tx_fifo_rdata_i;

        if (bus_tx_rsp_i.abort) begin
          // The host has pulled SDA low before the next SCL negedge to end the transfer (this is
          // equivalent to a Rs condition)
          tx_pr_abort_o = 1'b1;
          state_d = RxFByte;
        end else if (bus_stop_det_i) begin
          // Should not be possible: SDA is controlled in PP-high by us until the next SCL posedge
          tx_pr_abort_o = 1'b1;
          state_d = WaitRestart;
        end else if (bus_tx_rsp_i.done) begin
          // TBit was successfully transmitted as high, we may therefore continue with the next byte
          state_d = TxPReadData;
        end
      end

      WaitRestart: begin
        nack_transaction_d = 1'b1;
        if (bus_rstart_det_i) begin
          state_d = RxFByte;
        end
      end

      DoCCC: begin
        ccc_valid_o = 1'b1;

        if (is_ccc_done_i) begin
          state_d = DoneCCC;
        end else if (is_next_ccc_i) begin
          state_d = RxSByte;
        end
      end
      DoneCCC: begin
        // After CCC completes, check if we entered HDR mode
        if (in_hdr_mode_i) begin
          state_d = InHDRMode;
        end else begin
          state_d = Idle;
        end
      end

      DoRstAction: begin
        // Here, a reset of the core will happen so the state should transition to Idle anyway
        // The transition should be explicit to avoid undefined behavior
        state_d = Idle;
      end

      InHDRMode: begin
        // Stay in HDR mode, ignoring all bus activity.
        // Only hdr_exit_detect_i (handled below) can exit this state.
        state_d = InHDRMode;
      end

      DoHotJoin: begin
        if (is_hotjoin_done_i) begin
          state_d = Idle;
        end
      end
      default: begin end
    endcase

    // Priority overrides for bus conditions and HDR mode
    // Order matters: HDR exit has highest priority, then HDR mode entry, then STOP
    if (hdr_exit_detect_i && (state_q == InHDRMode)) begin
      // HDR Exit Pattern detected - exit HDR mode
      state_d = Idle;
    end else if (in_hdr_mode_i) begin
      // Enter InHDRMode immediately when in_hdr_mode_i asserts
      state_d = InHDRMode;
    end else if (bus_stop_det_i) begin
      // STOP received in SDR mode - return to Idle
      state_d = Idle;
    end
  end

  // Synchronous state transition
  always_ff @(posedge clk_i or negedge rst_ni) begin : state_transition
    if (!rst_ni) begin
      state_q <= Idle;
      ibi_retry_cnt_q <= 3'd0;
      ibi_inhibit_q   <= InhibitNone;
    end else begin
      state_q <= state_d;
      ibi_retry_cnt_q <= ibi_retry_cnt_d;
      ibi_inhibit_q   <= ibi_inhibit_d;
    end
  end

  assign target_idle_o = (state_q == Idle);

  always_ff @(posedge clk_i or negedge rst_ni) begin : virtual_device_sel_latch
    if (!rst_ni) begin
      virtual_device_sel_o <= '0;
    end else if (bus_any_start_det || bus_stop_det_i) begin
      // Clear on Start/Repeated Start/Stop - transaction boundary
      virtual_device_sel_o <= '0;
    end else unique case(state_q)
      CheckFByte:
        if (!is_rsvd_byte_match && virtual_device_sel_o != is_virtual_addr_match)
            virtual_device_sel_o <= is_virtual_addr_match;
      CheckSByte:
        if (!is_rsvd_byte_match && virtual_device_sel_o != is_virtual_addr_match)
            virtual_device_sel_o <= is_virtual_addr_match;
      default:
        virtual_device_sel_o <= virtual_device_sel_o;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      xfer_in_progress_o <= '0;
    end else unique case(state_q)
      Idle:       xfer_in_progress_o <= '0;
      CheckFByte: xfer_in_progress_o <= is_any_addr_match;
      CheckSByte: xfer_in_progress_o <= is_any_addr_match;
      default:    xfer_in_progress_o <= xfer_in_progress_o;
    endcase
  end

  // FUTUREFIX: v1p5 deferral — xfer/xact counters and cmd completion tracking
  assign event_cmd_complete_o = '0;

  // FUTUREFIX: v1p5 deferral — event detection (unexpected stop, arb lost, timeout, read cmd)
  assign event_unexp_stop_o = '0;
  assign event_tx_arbitration_lost_o = '0;
  assign event_tx_bus_timeout_o = '0;
  assign event_read_cmd_received_o = '0;

  // Record each transaction that gets NACK'd.
  // FUTUREFIX This is not true every time we wait for a start! Also, just make this a simple pulse!
  assign event_target_nack_o = !nack_transaction_q && nack_transaction_d;

`ifndef SYNTHESIS
`ifndef VERILATOR
  property cover_known_addr_ack;
    @(posedge clk_i)
    (
      $rose(bus_addr_valid) |=>
      ##2 ((is_rsvd_byte_match || is_any_addr_match) && ~bus_tx_req_o.data[7])
      ##1 @(posedge scl_negedge_i) ##1
      ##1 @(posedge clk_i) ##1 $fell(bus_tx_req_bit)
    );
  endproperty : cover_known_addr_ack
  covprop_known_addr_ack: cover property (cover_known_addr_ack);

  property cover_unknown_addr_nack;
    @(posedge clk_i)
    (
      $rose(bus_addr_valid) |=>
      ##2 (~(is_rsvd_byte_match || is_any_addr_match) && bus_tx_req_o.data[7])
      ##1 @(posedge scl_negedge_i) ##1
      ##1 @(posedge clk_i) ##1 ($stable(bus_tx_req_bit) && ~bus_tx_req_bit)
    );
  endproperty : cover_unknown_addr_nack
  covprop_unknown_addr_nack: cover property (cover_unknown_addr_nack);

  covprop_valid_addr: cover property (@(posedge clk_i) ($rose(bus_addr_valid)));

  covergroup cg_bus_event_fsm_transitions @(posedge clk_i);
    FsmState: coverpoint state_q {
      bins valid_start_trans =
        (Idle => RxFByte);
      bins valid_rstart_trans =
        (RxPWriteData, TxPReadData, TxPReadTbitCont, WaitRestart => RxFByte),
        (RxSByte => RxSByteRepeated);
      bins valid_stop_trans =
        (RxFByte, CheckFByte, TxAckFByte, RxSByte, RxSByteRepeated, CheckSByte, TxAckSByte,
         RxPWriteData, RxPWriteTbit, TxPReadData, WaitRestart, DoCCC,
         DoneCCC, DoHotJoin, DoRstAction, InHDRMode => Idle);
    }
    BusStartEvent: coverpoint bus_start_det_i {
      bins start_detected = {1'b1};
    }
    BusRStartEvent: coverpoint bus_rstart_det_i {
      bins rstart_detected = {1'b1};
    }
    BusStopEvent: coverpoint bus_stop_det_i {
      bins stop_detected = {1'b1};
    }

  endgroup : cg_bus_event_fsm_transitions

  cg_bus_event_fsm_transitions cg_bus_event_fsm_trans = new();
`endif
`endif
endmodule : i3c_target_fsm
