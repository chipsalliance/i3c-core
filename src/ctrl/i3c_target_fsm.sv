// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: I2C finite state machine
// Ongoing effort to adapt it to I3C


// TODO: Detection of T-bit (and parity check)
// Definitely want parity checking to be performed in this module
// TODO: Timings

// Initial focus is on supporting the following I3C flows:
// 1. Private R/W:      ADDR -> ACK -> Data
// 2. CCC:         RSVD_BYTE -> ACK -> CCC
// 3. Private R/W: RSVD_BYTE -> ACK -> SR -> ADDR -> ACK -> Data
// 4. Legacy R/W:  RSVD_BYTE -> ACK -> SR -> ADDR -> ACK -> Data

// Discern between "first" and "second" address

// There is ambiguity if after ACK we are observing a repeated start or first bit of data
// To support all flows, we need to discern {ACK} from {ACK,SR}
// After ACK/NACK bit:
// Ignore tranistions on SDA until we observe a posedge on SCL:
//  transition on SDA might be MSB of next data or P or SR
// After posedge on SCL:
// if we observe SDA transition with stable SCL, that means we have either P or SR
//    if SDA went from 0 to 1, it was a STOP; otherwise, SR
// if we observe SCL transition with stable SDA, that means it was the first data byte

// Note: we only drive data after SR after OUR address
// Note: we may have to include timing considerations? SCL timing is different in P or SR?

// Breakdown EACH flow in Annex A

// {S or Sr}
// {Byte of Data or CCC}
// ACK
// T-bit
// {Sr or P}

// ACK wihout handoff?

module i3c_target_fsm
  import controller_pkg::*;
#(
    parameter int AcqFifoDepth = 64,
    localparam int AcqFifoDepthWidth = $clog2(AcqFifoDepth + 1)
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

    input target_enable_i,  // enable target functionality

    input        scl_i,       // serial clock input from i2c bus
    output logic scl_o,       // serial clock output to i2c bus
    input        sda_i,       // serial data input from i2c bus
    output logic sda_o,       // serial data output to i2c bus
    output logic sel_od_pp_o, // select open-drain or push-pull driver

    // TODO: Bus monitor detection
    input logic bus_start_det_i,
    input logic bus_stop_detect_i,
    input logic bus_arbitration_lost_i,  // Lost arbitration while transmitting
    input logic bus_timeout_i,           // The bus timed out, with SCL held low for too long.

    output logic target_idle_o,  // indicates the target is idle
    output logic target_transmitting_o,  // Target is transmitting SDA (disambiguates high sda_o)

    // TX FIFO used for Target Read
    input                          tx_fifo_rvalid_i,  // indicates there is valid data in tx_fifo
    output logic                   tx_fifo_rready_o,  // pop entry from tx_fifo
    input        [TxFifoWidth-1:0] tx_fifo_rdata_i,   // byte in tx_fifo to be sent to host

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

    output logic [ 1:0] transfer_type_o,  // 00 - Write, 01- Read, 10 - CCC
    // TODO: Revisit widths of the timings; each timing is configured via 20-bit CSR field
    // Timings
    input        [12:0] t_r_i,            // rise time of both SDA and SCL in clock units
    input        [12:0] t_f_i,            // fall time of both SDA and SCL in clock units
    input        [12:0] tsu_dat_i,        // data setup time in clock units
    input        [12:0] thd_dat_i,        // data hold time in clock units

    // input logic [6:0] target_address_i,
    // input logic [6:0] target_mask_i,
    input logic is_sta_addr_match,
    input logic is_dyn_addr_match,
    input logic is_i3c_rsvd_addr_match,
    input logic is_any_addr_match,
    output logic [7:0] bus_addr,
    output logic bus_rnw,
    output logic bus_addr_match,
    output logic bus_addr_valid,

    output logic event_target_nack_o,  // this target sent a NACK (this is used to keep count)
    output logic event_cmd_complete_o,  // Command is complete
    output logic event_unexp_stop_o,  // target received an unexpected stop
    output logic event_tx_arbitration_lost_o,  // Arbitration was lost during a read transfer
    output logic event_tx_bus_timeout_o,  // Bus timed out during a read transfer
    output logic event_read_cmd_received_o  // A read awaits confirmation for TX FIFO release
);

  // I2C bus clock timing variables
  logic [15:0] tcount_q;  // current counter for setting delays
  logic [15:0] tcount_d;  // next counter for setting delays
  logic        load_tcount;  // indicates counter must be loaded

  logic        nack_transaction_q;  // Set if the rest of the transaction needs to be nack'd.
  logic        nack_transaction_d;

  // Other internal variables
  logic        scl_d;  // scl internal
  logic sda_d, sda_q;  // data internal
  logic sda_r;
  logic sda_i_q;  // sda_i delayed by one clock
  logic scl_i_q;  // scl_i delayed by one clock

  // Target specific variables
  logic restart_det_d, restart_det_q;
  assign restart_det_q = '0;  // TODO: Handle

  logic       xact_for_us_q;  // Target was addressed in this transaction
  logic       xact_for_us_d;  //     - We only record Stop if the Target was addressed.
  logic       xfer_for_us_q;  // Target was addressed in this transfer
  logic       xfer_for_us_d;  //     - event_cmd_complete_o is only for our transfers

  logic       input_strobe;
  logic [7:0] input_byte;  // register for reads from host
  logic       input_byte_clr;  // clear input_byte contents
  // logic       nack_timeout;
  logic       expect_stop;

  // Target bit counter variables
  logic [3:0] bit_idx;  // bit index including ack/nack
  logic       bit_ack;  // indicates ACK bit been sent or received
  logic       rw_bit;  // indicates host wants to read (1) or write (0)
  logic       host_ack;  // indicates host acknowledged transmitted byte

  // TODO: Set transfer type based on the discovered state
  assign transfer_type_o = 0;

  // IBI
  logic ibi_handling;  // Asserted when an IBI is transmitter
  logic ibi_payload;  // Asserted when data from IBI queue is transmitter

  // Clock counter implementation
  typedef enum logic [1:0] {
    tSetupData,
    tHoldData,
    tNoDelay
  } tcount_sel_e;

  tcount_sel_e tcount_sel;

  always_comb begin : counter_functions
    tcount_d = tcount_q;
    if (load_tcount) begin
      unique case (tcount_sel)
        tSetupData: tcount_d = 13'(t_r_i) + 13'(tsu_dat_i);
        tHoldData:  tcount_d = 16'(thd_dat_i);
        tNoDelay:   tcount_d = 16'h0001;
        default:    tcount_d = 16'h0001;
      endcase
    end else if (target_enable_i) begin
      tcount_d = tcount_q - 1'b1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : clk_counter
    if (!rst_ni) begin
      tcount_q <= '1;
    end else begin
      tcount_q <= tcount_d;
    end
  end

  // Latch whether this transaction is to be NACK'd.
  always_ff @(posedge clk_i or negedge rst_ni) begin : clk_nack_transaction
    if (!rst_ni) begin
      nack_transaction_q <= 1'b0;
    end else begin
      nack_transaction_q <= nack_transaction_d;
    end
  end

  // SDA and SCL at the previous clock edge
  always_ff @(posedge clk_i or negedge rst_ni) begin : bus_prev
    if (!rst_ni) begin
      scl_i_q <= 1'b1;
      sda_i_q <= 1'b1;
    end else begin
      scl_i_q <= scl_i;
      sda_i_q <= sda_i;
    end
  end

  // Track the transaction framing and this target's participation in it.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      xact_for_us_q <= 1'b0;
      xfer_for_us_q <= 1'b0;
    end else begin
      xact_for_us_q <= xact_for_us_d;
      xfer_for_us_q <= xfer_for_us_d;
    end
  end

  // Bit counter on the target side
  assign bit_ack = (bit_idx == 4'd8);  // ack


  logic scl_negedge;
  logic scl_posedge;
  logic sda_negedge;
  logic sda_posedge;

  assign scl_negedge = scl_i_q && !scl_i;
  assign scl_posedge = !scl_i_q && scl_i;
  assign sda_negedge = sda_i_q && !sda_i;
  assign sda_posedge = !sda_i_q && sda_i;

  // Increment counter on negative SCL edge
  always_ff @(posedge clk_i or negedge rst_ni) begin : tgt_bit_counter
    if (!rst_ni) begin
      bit_idx <= 4'd0;
    end else if (bus_start_det_i) begin
      bit_idx <= 4'd0;
      // FIXME: This is incorrect, the FSM should wait a hold time before changing SDA.
    end else if (scl_negedge) begin
      // input byte clear is always asserted on a "start"
      // condition.
      if (input_byte_clr || bit_ack) begin
        bit_idx <= 4'd0;
      end else begin
        bit_idx <= bit_idx + 1'b1;
      end
    end else begin
      bit_idx <= bit_idx;
    end
  end

  // Shift data in on positive SCL edge
  always_ff @(posedge clk_i or negedge rst_ni) begin : tgt_input_register
    if (!rst_ni) begin
      input_byte <= 8'h00;
    end else if (input_byte_clr) begin
      input_byte <= 8'h00;
    end else if (scl_posedge) begin
      if (!bit_ack) begin
        input_byte[7:0] <= {input_byte[6:0], sda_i};  // MSB goes in first
      end
    end
  end

  // Sampled data strobe
  always_ff @(posedge clk_i or negedge rst_ni) begin : tgt_input_register_strobe
    if (!rst_ni) begin
      input_strobe <= 1'b0;
    end else if (scl_posedge & !bit_ack) begin
      input_strobe <= 1'b1;
    end else begin
      input_strobe <= 1'b0;
    end
  end

  // Detection by the target of ACK bit sent by the host
  // In I3C 9th-bit is a T-bit (instead of ACK), maybe do parity check here?
  always_ff @(posedge clk_i or negedge rst_ni) begin : host_ack_register
    if (!rst_ni) begin
      host_ack <= 1'b0;
    end else if (scl_posedge) begin
      if (bit_ack) begin
        host_ack <= ~sda_i;
      end
    end
  end

  // Latch received bus address
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) bus_addr <= '0;
    else if (input_strobe & (bit_idx != 4'd7)) bus_addr <= input_byte;

  // Latch received RnW bit
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) bus_rnw <= '0;
    else if (input_strobe & (bit_idx == 4'd7)) bus_rnw <= input_byte[0];

  // An artificial acq_fifo_wready is used here to ensure we always have
  // space to asborb a stop / repeat start format byte.  Without guaranteeing
  // space for this entry, the target module would need to stretch the
  // repeat start / stop indication.  If a system does not support stretching,
  // there's no good way for a stop to be NACK'd.
  // Besides the space necessary for the stop format byte, we also need one
  // space to send a NACK. This means that we can notify software that a NACK
  // has happened while still keeping space for a subsequent stop or repeated
  // start.

  // TODO: Ack fifo remainder problem should be solved in our implementation, because
  // we are using programmable thresholds. Restore if needed

  // State definitions
  // TODO: Controller side stretching handler
  typedef enum logic [6:0] {
    Idle = 'd0,
    // Target function receives start and address from external host
    AcquireStart = 5'd1,
    AddrRead = 'd2,
    // Target function acknowledges the address and returns an ack to external host
    AddrAckWait = 'd3,
    AddrAckSetup = 'd4,
    AddrAckPulse = 'd5,
    AddrAckHold = 'd6,
    // TODO: Tbit
    //  TbitWait, TbitSetup, TbitPulse, TbitHold
    // Target function sends read data to external host-receiver
    TransmitWait = 'd7,
    TransmitSetup = 'd8,
    TransmitPulse = 'd9,
    TransmitHold = 'd10,
    // Target function receives ack from external host
    TransmitAck = 'd11,
    TransmitAckPulse = 'd12,
    WaitForStop = 'd13,
    // Target function receives write data from the external host
    AcquireByte = 'd14,
    // Target function sends ack to external host
    AcquireAckWait = 'd15,
    AcquireAckSetup = 'd16,
    AcquireAckPulse = 'd17,
    AcquireAckHold = 'd18,

    // If in AddrRead we read I3C Reserved Byte, we go to ACK here
    RsvdByteAckWait  = 'd19,
    RsvdByteAckSetup = 'd20,
    RsvdByteAckPulse = 'd21,
    RsvdByteAckHold  = 'd22,

    // Do we get SR or CCC next?
    // This state is only reached from RsvdByte* (may become obsolete with T-bits)
    PostAckSymbolDetect = 'd23,
    PostAckSymbolDetect2 = 'd24,
    PostAckSymbolDetect3 = 'd25,
    // Read the CCC byte
    CCCRead = 'd26,
    AcquireRStart = 'd27,
    AcquireTBit = 5'd28,

    // IBI start
    AcquireIbiStart = 'd30,
    // IBI address transmission
    IbiAddrWait = 'd31,
    IbiAddrSetup = 'd32,
    IbiAddrPulse = 'd33,
    IbiAddrHold = 'd34,
    // IBI address ACK reception
    IbiAckWait = 'd35,
    IbiAckSetup = 'd36,
    IbiAckLatch = 'd37,
    IbiAckHold = 'd38,
    // IBI payload transmission
    IbiTransmitWait = 'd39,
    IbiTransmitSetup = 'd40,
    IbiTransmitPulse = 'd41,
    IbiTransmitHold = 'd42,
    // IBI T-bit transmission
    IbiTbitWait = 'd43,
    IbiTbitSetup = 'd44,
    IbiTbitPulse = 'd45,
    IbiTbitHold = 'd46
  } state_e;

  state_e state_q, state_d;

  logic rw_bit_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rw_bit_q <= '0;
      // TODO: Originally bit_ack was anded with address_match
      // Do we need it?
    end else if (bit_ack) begin  //  && address_match
      rw_bit_q <= rw_bit;
    end
  end

  // Target transmitt data
  logic [7:0] output_byte;

  always_comb begin
    if (ibi_handling)
      if (ibi_payload) output_byte = ibi_fifo_rdata_i;
      else output_byte = {ibi_address_i, 1'b1};
    else begin
      output_byte = tx_fifo_rdata_i;
    end
  end

  // The usage of target_idle_o directly confuses xcelium and leads the
  // the simulator to a combinational loop. While it may be a tool recognized
  // loop, it is not an actual physical loop, since target_idle affects only
  // state_d, which is not used directly by any logic in this module.
  // This is a work around for a known tool limitation.
  logic target_idle;
  assign target_idle = target_idle_o;

  // During a host issued read, a stop was received without first seeing a nack.
  // This may be harmless but is technically illegal behavior, notify software.
  assign event_unexp_stop_o = target_enable_i & xfer_for_us_q & rw_bit_q &
                              bus_stop_detect_i & !expect_stop;

  // Record each transaction that gets NACK'd.
  assign event_target_nack_o = !nack_transaction_q && nack_transaction_d;

  state_e post_ack_decision_d;  // Decision what to do after ACK is taken in AddrRead
  state_e post_ack_decision_q;  // Latch _d

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_latch_ack_decision
    if (~rst_ni) begin
      post_ack_decision_q <= Idle;
    end else begin
      post_ack_decision_q <= post_ack_decision_d;
    end
  end

  // Outputs for each state
  // TODO: Fix latch
  // verilator lint_off LATCH
  always_comb begin : state_outputs
    target_idle_o = 1'b1;
    sda_d = 1'b1;
    scl_d = 1'b1;
    target_transmitting_o = 1'b0;
    tx_fifo_rready_o = 1'b0;
    rx_fifo_wvalid_o = 1'b0;
    rx_fifo_wdata_o = AcqFifoWidth'(0);
    event_cmd_complete_o = 1'b0;
    rw_bit = rw_bit_q;
    expect_stop = 1'b0;
    xact_for_us_d = xact_for_us_q;
    xfer_for_us_d = xfer_for_us_q;
    nack_transaction_d = nack_transaction_q;
    event_tx_arbitration_lost_o = 1'b0;
    event_tx_bus_timeout_o = 1'b0;
    event_read_cmd_received_o = 1'b0;
    ibi_fifo_rready_o = 1'b0;

    unique case (state_q)
      // Idle: initial state, SDA is released (high), SCL is released if the
      // bus is idle. Otherwise, if no STOP condition has been sent yet,
      // continue pulling SCL low in host mode.
      Idle: begin
        sda_d = 1'b1;
        scl_d = 1'b1;
        xact_for_us_d = 1'b0;
        xfer_for_us_d = 1'b0;
        nack_transaction_d = 1'b0;

        // There's an IBI pending in the queue. Pull SDA low and wait for
        // the controller to begin clocking SCL
        if (ibi_fifo_rvalid_i) begin
          sda_d = 1'b0;
          target_transmitting_o = 1'b1;
        end
      end
      // AcquireIbiStart:
      AcquireIbiStart: begin
        target_idle_o = 1'b0;
        target_transmitting_o = 1'b1;
        sda_d = 1'b0;
      end

      IbiAddrWait: begin
        target_idle_o = 1'b0;
        target_transmitting_o = 1'b1;
        sda_d = sda_r;
      end
      IbiAddrSetup: begin
        target_idle_o = 1'b0;
        target_transmitting_o = 1'b1;
        sda_d = sda_r;
      end
      IbiAddrPulse: begin
        target_idle_o = 1'b0;
        target_transmitting_o = 1'b1;
        sda_d = sda_r;
      end
      IbiAddrHold: begin
        target_idle_o = 1'b0;
        target_transmitting_o = 1'b1;
        sda_d = sda_r;
      end

      IbiTransmitWait: begin
        target_idle_o = 1'b0;
        target_transmitting_o = 1'b1;
        sda_d = sda_r;
      end
      IbiTransmitSetup: begin
        target_idle_o = 1'b0;
        target_transmitting_o = 1'b1;
        sda_d = sda_r;
      end
      IbiTransmitPulse: begin
        target_idle_o = 1'b0;
        target_transmitting_o = 1'b1;
        sda_d = sda_r;
      end
      IbiTransmitHold: begin
        target_idle_o = 1'b0;
        target_transmitting_o = 1'b1;
        sda_d = sda_r;
      end

      IbiTbitWait: begin
        target_idle_o = 1'b0;
        target_transmitting_o = 1'b1;
        sda_d = sda_r;
      end
      IbiTbitSetup: begin
        target_idle_o = 1'b0;
        target_transmitting_o = 1'b1;
        sda_d = sda_r;
        if (tcount_q == 20'd1) ibi_fifo_rready_o = 1'b1;
      end
      IbiTbitPulse: begin
        target_idle_o = 1'b0;
        target_transmitting_o = 1'b1;
        sda_d = sda_r;
      end
      IbiTbitHold: begin
        target_idle_o = 1'b0;
        target_transmitting_o = 1'b1;
        sda_d = sda_r;
      end

      // AcquireStart: hold for the end of the start condition
      AcquireStart: begin
        target_idle_o = 1'b0;
        xfer_for_us_d = 1'b0;
      end
      // AddrRead: read and compare target address
      AddrRead: begin
        target_idle_o = 1'b0;
        rw_bit = input_byte[0];

        if (bit_ack) begin
          if (is_any_addr_match) begin
            xact_for_us_d = 1'b1;
            xfer_for_us_d = 1'b1;
          end
        end
      end
      // AddrAckWait: pause for hold time before acknowledging
      AddrAckWait: begin
        target_idle_o = 1'b0;
        if (scl_i) begin
          // The controller is going too fast. Abandon the transaction.
          // Nothing gets recorded for this case.
          nack_transaction_d = 1'b1;
        end
      end
      // AddrAckSetup: target pulls SDA low while SCL is low
      AddrAckSetup: begin
        target_idle_o = 1'b0;
        sda_d = 1'b0;
        target_transmitting_o = 1'b1;
      end
      // AddrAckPulse: target pulls SDA low while SCL is released
      AddrAckPulse: begin
        target_idle_o = 1'b0;
        sda_d = 1'b0;
        target_transmitting_o = 1'b1;
      end
      // AddrAckHold: target pulls SDA low while SCL is pulled low
      AddrAckHold: begin
        target_idle_o = 1'b0;
        sda_d = 1'b0;
        target_transmitting_o = 1'b1;

        // Upon transition to next state, populate the acquisition fifo
        if (tcount_q == 20'd1) begin
          if (nack_transaction_q) begin
            // No need to record anything here. We already recorded the first
            // NACK'd byte in a stretch state or abandoned the transaction in
            // AddrAckWait.
          end else begin
            event_read_cmd_received_o = rw_bit_q;
          end
          if (restart_det_q) begin
            rx_fifo_wdata_o = {AcqRestart, input_byte};
          end else begin
            rx_fifo_wdata_o = {AcqStart, input_byte};
          end
        end
      end
      // TransmitWait: Check if data is available prior to transmit
      TransmitWait: begin
        target_idle_o = 1'b0;
      end
      // TransmitSetup: target shifts indexed bit onto SDA while SCL is low
      TransmitSetup: begin
        target_idle_o = 1'b0;
        sda_d = tx_fifo_rdata_i[3'(7-bit_idx)];
        target_transmitting_o = 1'b1;
      end
      // TransmitPulse: target holds indexed bit onto SDA while SCL is released
      TransmitPulse: begin
        target_idle_o = 1'b0;

        // Hold value
        sda_d = sda_q;
        target_transmitting_o = 1'b1;
      end
      // TransmitHold: target holds indexed bit onto SDA while SCL is pulled low, for the hold time
      TransmitHold: begin
        target_idle_o = 1'b0;

        // Hold value
        sda_d = sda_q;
        target_transmitting_o = 1'b1;
      end
      // TransmitAck: target waits for host to ACK transmission
      TransmitAck: begin
        target_idle_o = 1'b0;
      end
      TransmitAckPulse: begin
        target_idle_o = 1'b0;
        if (!scl_i) begin
          // Pop Fifo regardless of ack/nack
          tx_fifo_rready_o = 1'b1;
        end
      end
      // WaitForStop just waiting for host to trigger a stop after nack
      WaitForStop: begin
        target_idle_o = 1'b0;
        expect_stop = 1'b1;
        sda_d = 1'b1;
      end
      // AcquireByte: target acquires a byte
      AcquireByte: begin
        target_idle_o = 1'b0;
      end
      // AcquireAckWait: pause before acknowledging
      AcquireAckWait: begin
        target_idle_o = 1'b0;
        if (scl_i) begin
          // The controller is going too fast. Abandon the transaction.
          // Nothing is recorded for this case.
          nack_transaction_d = 1'b1;
        end
      end
      // AcquireAckSetup: target pulls SDA low while SCL is low
      AcquireAckSetup: begin
        target_idle_o = 1'b0;
        sda_d = 1'b0;
        target_transmitting_o = 1'b1;
      end
      // AcquireAckPulse: target pulls SDA low while SCL is released
      AcquireAckPulse: begin
        target_idle_o = 1'b0;
        sda_d = 1'b0;
        target_transmitting_o = 1'b1;
      end
      // AcquireAckHold: target pulls SDA low while SCL is pulled low
      AcquireAckHold: begin
        target_idle_o = 1'b0;
        sda_d = 1'b0;
        target_transmitting_o = 1'b1;
        if (tcount_q == 20'd1) begin
          rx_fifo_wvalid_o = '1;
          rx_fifo_wdata_o  = input_byte;  // transfer data to rx_fifo
        end
      end
      // AcquireRStart: hold for the end of the repeated start condition
      AcquireRStart: begin
        target_idle_o = 1'b0;
        xfer_for_us_d = 1'b0;
      end

      // RsvdByteAckWait: pause before acknowledging
      RsvdByteAckWait: begin
        target_idle_o = 1'b0;
        if (scl_i) begin
          // The controller is going too fast. Abandon the transaction.
          // Nothing is recorded for this case.
          nack_transaction_d = 1'b1;
        end
      end
      // RsvdByteAckSetup: target pulls SDA low while SCL is low
      RsvdByteAckSetup: begin
        target_idle_o = 1'b0;
        sda_d = 1'b0;
        target_transmitting_o = 1'b1;
      end
      // RsvdByteAckPulse: target pulls SDA low while SCL is released
      RsvdByteAckPulse: begin
        target_idle_o = 1'b0;
        sda_d = 1'b0;
        target_transmitting_o = 1'b1;
      end
      // RsvdByteAckHold: target pulls SDA low while SCL is pulled low
      RsvdByteAckHold: begin
        target_idle_o = 1'b0;
        sda_d = 1'b0;
        target_transmitting_o = 1'b1;
      end

      CCCRead: begin
        target_idle_o = 1'b1;
      end

      // default
      default: begin
        target_idle_o = 1'b1;
        sda_d = 1'b1;
        scl_d = 1'b1;
        target_transmitting_o = 1'b0;
        tx_fifo_rready_o = 1'b0;
        rx_fifo_wvalid_o = 1'b0;
        rx_fifo_wdata_o = AcqFifoWidth'(0);
        event_cmd_complete_o = 1'b0;
        xact_for_us_d = 1'b0;
        nack_transaction_d = 1'b0;
      end
    endcase  // unique case (state_q)

    // start / stop override
    if (target_enable_i && (bus_stop_detect_i || bus_timeout_i)) begin
      event_cmd_complete_o   = xfer_for_us_q;
      event_tx_bus_timeout_o = bus_timeout_i && rw_bit_q;
      // Note that we assume the ACQ FIFO can accept a new item and will
      // receive the arbiter grant without delay. No other FIFOs should have
      // activity during a Start or Stop symbol.
      // TODO: Add an assertion.
      if (nack_transaction_q || bus_timeout_i) begin
        rx_fifo_wdata_o = {AcqNackStop, input_byte};
      end else begin
        rx_fifo_wdata_o = {AcqStop, input_byte};
      end
    end else if (target_enable_i && bus_start_det_i) begin
      restart_det_d = !target_idle_o;
      event_cmd_complete_o = xfer_for_us_q;
    end else if (bus_arbitration_lost_i) begin
      nack_transaction_d = 1'b1;
      event_cmd_complete_o = xfer_for_us_q;
      event_tx_arbitration_lost_o = rw_bit_q;
    end
  end
  // verilator lint_on LATCH

  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) ibi_handling <= '0;
    else if (state_q == Idle) ibi_handling <= ibi_fifo_rvalid_i;

  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) ibi_payload <= '0;
    else if (state_q == Idle) ibi_payload <= '0;
    else if (state_q == IbiTransmitWait) ibi_payload <= 1'b1;
    else if (state_q == IbiTbitWait) ibi_payload <= 1'b1;

  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) sda_r <= 1'b1;
    else if (state_q == IbiAddrSetup || state_q == IbiTransmitSetup)
      sda_r <= output_byte[3'(7-bit_idx)];
    else if (state_q == IbiTbitSetup)
      // TODO: We are sending T=0 as we currently assume there's only one IBI byte
      sda_r <= 1'b0;

  // Conditional state transition
  // TODO: Fix latch
  // verilator lint_off LATCH
  always_comb begin : state_functions
    state_d = state_q;
    load_tcount = 1'b0;
    tcount_sel = tNoDelay;
    input_byte_clr = 1'b0;
    unique case (state_q)
      // Idle: initial state, SDA and SCL are released (high)
      Idle: begin
        // We have an IBI pending in the queue. SDA will be pulled low. Wait
        // for the controller to provide SCL clock.
        if (ibi_fifo_rvalid_i) state_d = AcquireIbiStart;
        // The bus is idle. Waiting for a Start.
        post_ack_decision_d = Idle;
        // Initially don't drive the bus using push-pull
        sel_od_pp_o = 1'b0;
      end
      // AcquireIbiStart:
      AcquireIbiStart: begin
        if (!scl_i) begin
          state_d = IbiAddrWait;
          input_byte_clr = 1'b1;
          load_tcount = 1'b1;
          tcount_sel = tSetupData;
        end
      end
      // AcquireStart: hold for the end of the start condition
      AcquireStart: begin
        post_ack_decision_d = Idle;
        if (!scl_i) begin
          state_d = AddrRead;
          input_byte_clr = 1'b1;
        end
      end
      // AddrRead: read and compare target address
      AddrRead: begin
        // bit_ack goes high the cycle after scl_i goes low, after the 8th bit
        // was captured.
        if (bit_ack) begin
          if (is_dyn_addr_match || is_sta_addr_match) begin  // Static, Dynamic or Reserved
            // We can follow old flow
            state_d = AddrAckWait;
            // Wait for hold time to avoid interfering with the controller.
            load_tcount = 1'b1;
            tcount_sel = tHoldData;
          end else if (is_i3c_rsvd_addr_match) begin
            state_d = RsvdByteAckWait;
            load_tcount = 1'b1;
            tcount_sel = tHoldData;
          end else begin  // no matching address
            // This means this transfer is not meant for us.
            state_d = WaitForStop;
          end
        end
      end
      // AddrAckWait: pause for hold time before acknowledging
      AddrAckWait: begin
        if (scl_i) begin
          // The controller is going too fast. Abandon the transaction.
          state_d = WaitForStop;
        end else if (tcount_q == 20'd1) begin
          if (nack_transaction_q) begin
            // We must have stretched before, and software has been notified
            // through an ACQ FIFO full event. For writes we should NACK all
            // bytes in the transfer unconditionally. For reads, we NACK
            // the address byte, then release SDA for the rest of the
            // transfer.
            // Essentially, we're waiting for the end of the transaction.
            state_d = WaitForStop;
          end else begin
            // The transaction hasn't already been NACK'd, and there is
            // room in the ACQ FIFO. Proceed.
            state_d = AddrAckSetup;
          end
        end
      end
      // AddrAckSetup: target pulls SDA low while SCL is low
      AddrAckSetup: begin
        if (scl_i) state_d = AddrAckPulse;
      end
      // AddrAckPulse: target pulls SDA low while SCL is released
      AddrAckPulse: begin
        if (!scl_i) begin
          state_d = AddrAckHold;
          load_tcount = 1'b1;
          tcount_sel = tHoldData;
        end
      end
      // AddrAckHold: target pulls SDA low while SCL is pulled low
      AddrAckHold: begin
        if (tcount_q == 20'd1) begin
          if (nack_transaction_q) begin
            // If the Target is set to NACK already, release SDA and wait
            // for a Stop. This isn't an ideal response for SMBus reads, since
            // 127 bytes of 0xff will just happen to have a correct PEC. It's
            // best for software to ensure there is always space in the ACQ
            // FIFO.
            state_d = WaitForStop;
          end else if (rw_bit_q) begin
            // Not NACKing automatically, not stretching, and it's a read.
            state_d = TransmitWait;
          end else begin
            // Not NACKing automatically, not stretching, and it's a write.
            state_d = AcquireByte;
          end
        end
      end
      // TransmitWait: Evaluate whether there are entries to send first
      TransmitWait: begin
        state_d = TransmitSetup;
      end
      // TransmitSetup: target shifts indexed bit onto SDA while SCL is low
      TransmitSetup: begin
        if (scl_i) state_d = TransmitPulse;
      end
      // TransmitPulse: target shifts indexed bit onto SDA while SCL is released
      TransmitPulse: begin
        if (!scl_i) begin
          state_d = TransmitHold;
          load_tcount = 1'b1;
          tcount_sel = tHoldData;
        end
      end
      // TransmitHold: target shifts indexed bit onto SDA while SCL is pulled low
      TransmitHold: begin
        if (tcount_q == 20'd1) begin
          if (bit_ack) begin
            state_d = TransmitAck;
          end else begin
            load_tcount = 1'b1;
            tcount_sel = tHoldData;
            state_d = TransmitSetup;
          end
        end
      end
      // Wait for clock to become positive.
      TransmitAck: begin
        if (scl_i) begin
          state_d = TransmitAckPulse;
        end
      end
      // TransmitAckPulse: target waits for host to ACK transmission
      // If a nak is received, that means a stop is incoming.
      TransmitAckPulse: begin
        if (!scl_i) begin
          // If host acknowledged, that means we must continue
          if (host_ack) begin
            state_d = TransmitWait;
          end else begin
            // If host nak'd then the transaction is about to terminate, go to a wait state
            state_d = WaitForStop;
          end
        end
      end

      // IBI address
      IbiAddrWait: begin
        if (!scl_i) begin
          state_d = IbiAddrSetup;
          load_tcount = 1'b1;
          tcount_sel = tSetupData;
        end
      end
      IbiAddrSetup: begin
        if (tcount_q == 20'd1) begin
          state_d = IbiAddrPulse;
        end
      end
      IbiAddrPulse: begin
        if (scl_i) begin
          state_d = IbiAddrHold;
          load_tcount = 1'b1;
          tcount_sel = tHoldData;
        end
      end
      IbiAddrHold: begin
        if (tcount_q == 20'd1) begin
          if (bit_idx == 7) state_d = IbiAckWait;
          else state_d = IbiAddrWait;
          load_tcount = 1'b1;
          tcount_sel  = tSetupData;
        end
      end

      // IBI address ACK
      IbiAckWait: begin
        if (!scl_i) begin
          state_d = IbiAckSetup;
          load_tcount = 1'b1;
          tcount_sel = tSetupData;
        end
      end
      IbiAckSetup: begin
        if (tcount_q == 20'd1) state_d = IbiAckLatch;
      end
      IbiAckLatch: begin
        if (scl_i) begin
          if (sda_i) post_ack_decision_d = WaitForStop;  // NACK
          else post_ack_decision_d = IbiTransmitWait;  // ACK
          state_d = IbiAckHold;
          load_tcount = 1'b1;
          tcount_sel = tHoldData;
        end
      end
      IbiAckHold: begin
        if (tcount_q == 20'd1) begin
          state_d = post_ack_decision_d;
        end
      end

      // IBI payload
      IbiTransmitWait: begin
        sel_od_pp_o = 1'b1;
        if (!scl_i) begin
          state_d = IbiTransmitSetup;
          load_tcount = 1'b1;
          tcount_sel = tSetupData;
        end
      end
      IbiTransmitSetup: begin
        if (tcount_q == 20'd1) begin
          state_d = IbiTransmitPulse;
        end
      end
      IbiTransmitPulse: begin
        if (scl_i) begin
          state_d = IbiTransmitHold;
          load_tcount = 1'b1;
          tcount_sel = tHoldData;
        end
      end
      IbiTransmitHold: begin
        if (tcount_q == 20'd1) begin
          if (bit_idx == 7) state_d = IbiTbitWait;
          else state_d = IbiTransmitWait;
          load_tcount = 1'b1;
          tcount_sel  = tSetupData;
        end
      end

      // IBI payload T-bit
      IbiTbitWait: begin
        if (!scl_i) begin
          state_d = IbiTbitSetup;
          load_tcount = 1'b1;
          tcount_sel = tSetupData;
        end
      end
      IbiTbitSetup: begin
        if (tcount_q == 20'd1) begin
          state_d = IbiTbitPulse;
        end
      end
      IbiTbitPulse: begin
        if (scl_i) begin
          state_d = IbiTbitHold;
          load_tcount = 1'b1;
          tcount_sel = tHoldData;
        end
      end
      IbiTbitHold: begin
        if (tcount_q == 20'd1) begin
          // TODO: Currently we assume that there's no more than one byte of IBI payload
          state_d = WaitForStop;
          load_tcount = 1'b1;
          tcount_sel = tSetupData;
          sel_od_pp_o = 1'b0;  // Release the bus
        end
      end

      // An inert state just waiting for host to issue a stop
      // Cannot cycle back to idle directly as other events depend on the system being
      // non-idle.
      WaitForStop: begin
        sel_od_pp_o = 1'b0;
        state_d = WaitForStop;
      end
      // AcquireByte: target acquires a byte
      AcquireByte: begin
        if (bit_ack) begin
          state_d = AcquireAckWait;
          load_tcount = 1'b1;
          tcount_sel = tHoldData;
        end
      end
      // AcquireAckWait: pause for hold time before acknowledging
      AcquireAckWait: begin
        if (scl_i) begin
          // The controller is going too fast. Abandon the transaction.
          state_d = WaitForStop;
        end else if (tcount_q == 20'd1) begin
          if (nack_transaction_q) begin
            state_d = WaitForStop;
          end else begin
            state_d = AcquireAckSetup;
          end
        end
      end
      // AcquireAckSetup: target pulls SDA low while SCL is low
      AcquireAckSetup: begin
        if (scl_i) state_d = AcquireAckPulse;
      end
      // AcquireAckPulse: target pulls SDA low while SCL is released
      AcquireAckPulse: begin
        if (!scl_i) begin
          state_d = AcquireAckHold;
          load_tcount = 1'b1;
          tcount_sel = tHoldData;
        end
      end
      // AcquireAckHold: target pulls SDA low while SCL is pulled low
      AcquireAckHold: begin
        if (tcount_q == 20'd1) begin
          state_d = AcquireByte;
        end
      end
      PostAckSymbolDetect: begin
        input_byte_clr = '1;  // Clear input byte
        state_d = PostAckSymbolDetect2;
      end
      PostAckSymbolDetect2: begin
        // TODO: Currently we wait for scl posedge indefinitely, add correct timings and timeout

        // When SCL posedge comes, latch SDA
        if (scl_posedge) begin
          state_d = PostAckSymbolDetect3;
        end
      end
      PostAckSymbolDetect3: begin
        // Check if next transition is on SDA or SCL
        if (scl_posedge || scl_negedge) begin
          // TODO: This assumes a Private Write, add logic for handling Private Read:
          // if ( rnw ) // Transmit* or Acquire*
          // This is next data byte
          state_d = AcquireByte;
        end
        if (sda_posedge) begin
          // This is a STOP
          input_byte_clr = '1;  // Clear input byte
          state_d = WaitForStop;  // Is this the right state?
        end
        if (sda_negedge) begin
          // This is a Repeated Start
          input_byte_clr = '1;  // Clear input byte
          state_d = AcquireRStart;
        end
      end
      // RsvdByteAckWait: pause for hold time before acknowledging
      RsvdByteAckWait: begin
        if (scl_i) begin
          // The controller is going too fast. Abandon the transaction.
          state_d = WaitForStop;
        end else if (tcount_q == 20'd1) begin
          if (nack_transaction_q) begin
            state_d = WaitForStop;
          end else begin
            state_d = RsvdByteAckSetup;
          end
        end
      end
      // RsvdByteAckSetup: target pulls SDA low while SCL is low
      RsvdByteAckSetup: begin
        if (scl_i) state_d = RsvdByteAckPulse;
      end
      // RsvdByteAckPulse: target pulls SDA low while SCL is released
      RsvdByteAckPulse: begin
        if (!scl_i) begin
          state_d = RsvdByteAckHold;
          load_tcount = 1'b1;
          tcount_sel = tHoldData;
        end
      end
      // RsvdByteAckHold: target pulls SDA low while SCL is pulled low
      RsvdByteAckHold: begin
        if (tcount_q == 20'd1) begin
          // TODO: detect potential repeated start after this ACK
          state_d = CCCRead;
        end
      end

      CCCRead: begin
        if (bit_ack) begin
          state_d = AcquireTBit;
          load_tcount = 1'b1;
          tcount_sel = tHoldData;
        end
      end

      AcquireTBit: begin

      end

      // AcquireRStart: hold for the end of the Repeated Start condition
      AcquireRStart: begin
        post_ack_decision_d = Idle;
        if (!scl_i) begin
          state_d = AddrRead;
          input_byte_clr = 1'b1;
        end
      end
      default: begin
        state_d = Idle;
        load_tcount = 1'b0;
        tcount_sel = tNoDelay;
        input_byte_clr = 1'b0;
      end
    endcase  // unique case (state_q)

    // When a start is detected, always go to the acquire start state.
    // Differences in repeated start / start handling are done in the
    // other FSM.
    if (!target_idle && !target_enable_i) begin
      // If the target function is currently not idle but target_enable is suddenly dropped,
      // (maybe because the host locked up and we want to cycle back to an initial state),
      // transition immediately.
      // The same treatment is not given to the host mode because it already attempts to
      // gracefully terminate.  If the host cannot gracefully terminate for whatever reason,
      // (the other side is holding SCL low), we may need to forcefully reset the module.
      // ICEBOX(#18004): It may be worth having a force stop condition to force the host back to
      // Idle in case graceful termination is not possible.
      state_d = Idle;
    end else if (target_enable_i && bus_start_det_i && !ibi_handling) begin
      state_d = AcquireStart;
    end else if (bus_stop_detect_i || bus_timeout_i) begin
      state_d = Idle;
    end else if (bus_arbitration_lost_i) begin
      state_d = WaitForStop;
    end
  end
  // verilator lint_on LATCH

  // Signal the DAA module to perform addres check
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) begin
      bus_addr_valid <= 1'b0;
    end else if (state_q == AddrRead & bit_idx == 4'd6 & input_strobe) begin
      bus_addr_valid <= 1'b1;
    end else begin
      bus_addr_valid <= 1'b0;
    end

  // Announce that a valid address has been received
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) begin
      bus_addr_match <= 1'b0;
    end else if (state_q == AddrRead & bit_idx == 4'd7 & input_strobe) begin
      bus_addr_match <= is_dyn_addr_match | is_sta_addr_match;
    end else begin
      bus_addr_match <= 1'b0;
    end

  // Synchronous state transition
  always_ff @(posedge clk_i or negedge rst_ni) begin : state_transition
    if (!rst_ni) begin
      state_q <= Idle;
    end else begin
      state_q <= state_d;
    end
  end

  // Saved sda output used in certain states.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sda_q <= 1'b1;
    end else begin
      sda_q <= sda_d;
    end
  end

  assign scl_o = scl_d;
  assign sda_o = sda_d;

  // Assertions
  // // Make sure we never attempt to send a single cycle glitch
  // `ASSERT(SclOutputGlitch_A, $rose(scl_o) |-> ##1 scl_o)

endmodule : i3c_target_fsm
