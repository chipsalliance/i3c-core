// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: I2C finite state machine


// TODO: Detection of T-bit (and parity check)
// TODO: Reintegrate address matching
// TODO: Timings

module i3c_target_fsm
  import controller_pkg::*;
#(
    parameter int AcqFifoDepth = 64,
    localparam int AcqFifoDepthWidth = $clog2(AcqFifoDepth + 1)
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

    input        scl_i,  // serial clock input from i2c bus
    output logic scl_o,  // serial clock output to i2c bus
    input        sda_i,  // serial data input from i2c bus
    output logic sda_o,  // serial data output to i2c bus

    // TODO: better to name them force_* to force certain states if needed
    input start_detect_i,
    input stop_detect_i,

    output logic transmitting_o,  // Target is transmitting SDA (disambiguates high sda_o)

    input target_enable_i,  // enable target functionality

    // TX FIFO used for Target Write
    input                            tx_fifo_rvalid_i,  // indicates there is valid data in tx_fifo
    output logic                     tx_fifo_rready_o,  // pop entry from tx_fifo
    input        [TX_FIFO_WIDTH-1:0] tx_fifo_rdata_i,   // byte in tx_fifo to be sent to host

    // Acquisition FIFO used for Target Read
    output logic acq_fifo_wvalid_o,  // high if there is valid data in acq_fifo
    output logic [ACQ_FIFO_WIDTH-1:0] acq_fifo_wdata_o,  // data to write to acq_fifo from target

    input [AcqFifoDepthWidth-1:0] acq_fifo_depth_i,  // fill level of acq_fifo
    output logic acq_fifo_full_o,  // local version of "full"

    output logic target_idle_o,  // indicates the target is idle

    input [12:0] t_r_i,               // rise time of both SDA and SCL in clock units
    input [12:0] tsu_dat_i,           // data setup time in clock units
    input [12:0] thd_dat_i,           // data hold time in clock units
    input        arbitration_lost_i,  // Lost arbitration while transmitting
    input        bus_timeout_i,       // The bus timed out, with SCL held low for too long.

    input logic [6:0] target_address0_i,
    input logic [6:0] target_mask0_i,
    input logic [6:0] target_address1_i,
    input logic [6:0] target_mask1_i,

    output logic event_target_nack_o,  // this target sent a NACK (this is used to keep count)
    output logic event_cmd_complete_o,  // Command is complete
    output logic event_unexp_stop_o,  // target received an unexpected stop
    output logic event_tx_arbitration_lost_o,  // Arbitration was lost during a read transfer
    output logic event_tx_bus_timeout_o,  // Bus timed out during a read transfer
    output logic event_read_cmd_received_o,  // A read awaits confirmation for TX FIFO release

    // Debugging
    output logic target_internal_state  // Output current state of the fsm
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
  logic       scl_i_q;  // scl_i delayed by one clock

  // Target specific variables
  logic       restart_det_q;  // indicates the latest start was a repeated start
  logic       restart_det_d;

  // TODO: Reintegrate address matching
  logic       address_match;  // indicates one of target's addresses matches the one sent by host

  logic       xact_for_us_q;  // Target was addressed in this transaction
  logic       xact_for_us_d;  //     - We only record Stop if the Target was addressed.
  logic       xfer_for_us_q;  // Target was addressed in this transfer
  logic       xfer_for_us_d;  //     - event_cmd_complete_o is only for our transfers

  logic [7:0] input_byte;  // register for reads from host
  logic       input_byte_clr;  // clear input_byte contents
  logic       nack_timeout;
  logic       expect_stop;

  // Target bit counter variables
  logic [3:0] bit_idx;  // bit index including ack/nack
  logic       bit_ack;  // indicates ACK bit been sent or received
  logic       rw_bit;  // indicates host wants to read (1) or write (0)
  logic       host_ack;  // indicates host acknowledged transmitted byte


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
    end else begin
      scl_i_q <= scl_i;
    end
  end

  // Track the transaction framing and this target's participation in it.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      restart_det_q <= 1'b0;
      xact_for_us_q <= 1'b0;
      xfer_for_us_q <= 1'b0;
    end else begin
      restart_det_q <= restart_det_d;
      xact_for_us_q <= xact_for_us_d;
      xfer_for_us_q <= xfer_for_us_d;
    end
  end

  // Bit counter on the target side
  assign bit_ack = (bit_idx == 4'd8);  // ack

  // Increment counter on negative SCL edge
  always_ff @(posedge clk_i or negedge rst_ni) begin : tgt_bit_counter
    if (!rst_ni) begin
      bit_idx <= 4'd0;
    end else if (start_detect_i) begin
      bit_idx <= 4'd0;
    end else if (scl_i_q && !scl_i) begin
      // input byte clear is always asserted on a "start"
      // condition.
      if (input_byte_clr || bit_ack) bit_idx <= 4'd0;
      else bit_idx <= bit_idx + 1'b1;
    end else begin
      bit_idx <= bit_idx;
    end
  end

  // TODO: Address matching in i3c is more complex, moved function to daa.sv
  // Temporarily testing, mock that all addresses match
  assign address_match = '1;


  // Shift data in on positive SCL edge
  always_ff @(posedge clk_i or negedge rst_ni) begin : tgt_input_register
    if (!rst_ni) begin
      input_byte <= 8'h00;
    end else if (input_byte_clr) begin
      input_byte <= 8'h00;
    end else if (!scl_i_q && scl_i) begin
      if (!bit_ack) input_byte[7:0] <= {input_byte[6:0], sda_i};  // MSB goes in first
    end
  end

  // Detection by the target of ACK bit sent by the host
  // In I3C 9-bit is T-bit, not ACK, maybe do parity check here?
  always_ff @(posedge clk_i or negedge rst_ni) begin : host_ack_register
    if (!rst_ni) begin
      host_ack <= 1'b0;
    end else if (!scl_i_q && scl_i) begin
      if (bit_ack) host_ack <= ~sda_i;
    end
  end

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
  typedef enum logic [4:0] {
    Idle,
    // Target function receives start and address from external host
    AcquireStart,
    AddrRead,
    // Target function acknowledges the address and returns an ack to external host
    AddrAckWait,
    AddrAckSetup,
    AddrAckPulse,
    AddrAckHold,
    // Target function sends read data to external host-receiver
    TransmitWait,
    TransmitSetup,
    TransmitPulse,
    TransmitHold,
    // Target function receives ack from external host
    TransmitAck,
    TransmitAckPulse,
    WaitForStop,
    // Target function receives write data from the external host
    AcquireByte,
    // Target function sends ack to external host
    AcquireAckWait,
    AcquireAckSetup,
    AcquireAckPulse,
    AcquireAckHold
  } state_e;

  state_e state_q, state_d;

  logic rw_bit_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rw_bit_q <= '0;
    end else if (bit_ack && address_match) begin
      rw_bit_q <= rw_bit;
    end
  end

  // Reverse the bit order since data should be sent out MSB first
  logic [TX_FIFO_WIDTH-1:0] tx_fifo_rdata;
  assign tx_fifo_rdata = {<<1{tx_fifo_rdata_i}};

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
                              stop_detect_i & !expect_stop;

  // Record each transaction that gets NACK'd.
  assign event_target_nack_o = !nack_transaction_q && nack_transaction_d;

  // Outputs for each state
  always_comb begin : state_outputs
    target_idle_o = 1'b1;
    sda_d = 1'b1;
    scl_d = 1'b1;
    transmitting_o = 1'b0;
    tx_fifo_rready_o = 1'b0;
    acq_fifo_wvalid_o = 1'b0;
    acq_fifo_wdata_o = ACQ_FIFO_WIDTH'(0);
    event_cmd_complete_o = 1'b0;
    rw_bit = rw_bit_q;
    expect_stop = 1'b0;
    restart_det_d = restart_det_q;
    xact_for_us_d = xact_for_us_q;
    xfer_for_us_d = xfer_for_us_q;
    nack_transaction_d = nack_transaction_q;
    event_tx_arbitration_lost_o = 1'b0;
    event_tx_bus_timeout_o = 1'b0;
    event_read_cmd_received_o = 1'b0;

    unique case (state_q)
      // Idle: initial state, SDA is released (high), SCL is released if the
      // bus is idle. Otherwise, if no STOP condition has been sent yet,
      // continue pulling SCL low in host mode.
      Idle: begin
        sda_d = 1'b1;
        scl_d = 1'b1;
        restart_det_d = 1'b0;
        xact_for_us_d = 1'b0;
        xfer_for_us_d = 1'b0;
        nack_transaction_d = 1'b0;
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
          if (address_match) begin
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
        transmitting_o = 1'b1;
      end
      // AddrAckPulse: target pulls SDA low while SCL is released
      AddrAckPulse: begin
        target_idle_o = 1'b0;
        sda_d = 1'b0;
        transmitting_o = 1'b1;
      end
      // AddrAckHold: target pulls SDA low while SCL is pulled low
      AddrAckHold: begin
        target_idle_o = 1'b0;
        sda_d = 1'b0;
        transmitting_o = 1'b1;

        // Upon transition to next state, populate the acquisition fifo
        if (tcount_q == 20'd1) begin
          if (nack_transaction_q) begin
            // No need to record anything here. We already recorded the first
            // NACK'd byte in a stretch state or abandoned the transaction in
            // AddrAckWait.
          end else begin
            // Only write to fifo if stretching conditions are not met
            acq_fifo_wvalid_o = 1'b1;
            event_read_cmd_received_o = rw_bit_q;
          end

          if (restart_det_q) begin
            acq_fifo_wdata_o = {AcqRestart, input_byte};
          end else begin
            acq_fifo_wdata_o = {AcqStart, input_byte};
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
        sda_d = tx_fifo_rdata[3'(bit_idx)];
        transmitting_o = 1'b1;
      end
      // TransmitPulse: target holds indexed bit onto SDA while SCL is released
      TransmitPulse: begin
        target_idle_o = 1'b0;

        // Hold value
        sda_d = sda_q;
        transmitting_o = 1'b1;
      end
      // TransmitHold: target holds indexed bit onto SDA while SCL is pulled low, for the hold time
      TransmitHold: begin
        target_idle_o = 1'b0;

        // Hold value
        sda_d = sda_q;
        transmitting_o = 1'b1;
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
        transmitting_o = 1'b1;
      end
      // AcquireAckPulse: target pulls SDA low while SCL is released
      AcquireAckPulse: begin
        target_idle_o = 1'b0;
        sda_d = 1'b0;
        transmitting_o = 1'b1;
      end
      // AcquireAckHold: target pulls SDA low while SCL is pulled low
      AcquireAckHold: begin
        target_idle_o = 1'b0;
        sda_d = 1'b0;
        transmitting_o = 1'b1;

        if (tcount_q == 20'd1) begin
          // TODO: put '1 in place of stretch_rx
          acq_fifo_wvalid_o = '1;  // assert that acq_fifo has space
          acq_fifo_wdata_o  = {AcqData, input_byte};  // transfer data to acq_fifo
        end
      end
      // default
      default: begin
        target_idle_o = 1'b1;
        sda_d = 1'b1;
        scl_d = 1'b1;
        transmitting_o = 1'b0;
        tx_fifo_rready_o = 1'b0;
        acq_fifo_wvalid_o = 1'b0;
        acq_fifo_wdata_o = ACQ_FIFO_WIDTH'(0);
        event_cmd_complete_o = 1'b0;
        restart_det_d = 1'b0;
        xact_for_us_d = 1'b0;
        nack_transaction_d = 1'b0;
      end
    endcase  // unique case (state_q)

    // start / stop override
    if (target_enable_i && (stop_detect_i || bus_timeout_i)) begin
      event_cmd_complete_o = xfer_for_us_q;
      event_tx_bus_timeout_o = bus_timeout_i && rw_bit_q;
      // Note that we assume the ACQ FIFO can accept a new item and will
      // receive the arbiter grant without delay. No other FIFOs should have
      // activity during a Start or Stop symbol.
      // TODO: Add an assertion.
      acq_fifo_wvalid_o = xact_for_us_q;
      if (nack_transaction_q || bus_timeout_i) begin
        acq_fifo_wdata_o = {AcqNackStop, input_byte};
      end else begin
        acq_fifo_wdata_o = {AcqStop, input_byte};
      end
    end else if (target_enable_i && start_detect_i) begin
      restart_det_d = !target_idle_o;
      event_cmd_complete_o = xfer_for_us_q;
    end else if (arbitration_lost_i) begin
      nack_transaction_d = 1'b1;
      event_cmd_complete_o = xfer_for_us_q;
      event_tx_arbitration_lost_o = rw_bit_q;
    end
  end



  // Conditional state transition
  always_comb begin : state_functions
    state_d = state_q;
    load_tcount = 1'b0;
    tcount_sel = tNoDelay;
    input_byte_clr = 1'b0;


    unique case (state_q)
      // Idle: initial state, SDA and SCL are released (high)
      Idle: begin
        // The bus is idle. Waiting for a Start.
      end

      // AcquireStart: hold for the end of the start condition
      AcquireStart: begin
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
          if (address_match) begin
            state_d = AddrAckWait;
            // Wait for hold time to avoid interfering with the controller.
            load_tcount = 1'b1;
            tcount_sel = tHoldData;
          end else begin  // !address_match
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
      // An inert state just waiting for host to issue a stop
      // Cannot cycle back to idle directly as other events depend on the system being
      // non-idle.
      WaitForStop: begin
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
      // default
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
    end else if (target_enable_i && start_detect_i) begin
      state_d = AcquireStart;
    end else if (stop_detect_i || bus_timeout_i) begin
      state_d = Idle;
    end else if (arbitration_lost_i) begin
      state_d = WaitForStop;
    end
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

  // Fed out for interrupt purposes
  // TODO : Connect to real signal
  assign acq_fifo_full_o = '0;


  // Debugging
  assign target_internal_state = state_q;

  // Assertions
  // // Make sure we never attempt to send a single cycle glitch
  // `ASSERT(SclOutputGlitch_A, $rose(scl_o) |-> ##1 scl_o)

endmodule
