// SPDX-License-Identifier: Apache-2.0

/*
  ENTDAA (Enter Dynamic Address Assignment) Sub-FSM

  This module implements the Target-side ENTDAA procedure as defined in the
  I3C specification. ENTDAA allows a Controller to dynamically assign 7-bit
  addresses to Targets on the bus.

  ENTDAA Procedure (Target perspective):
  1. Controller sends ENTDAA broadcast CCC (0x07)
  2. Controller sends Repeated Start + 7'h7E/R (reserved byte with Read)
  3. All unaddressed Targets ACK and begin transmitting their 64-bit Provisioned ID
  4. Arbitration occurs bit-by-bit; Targets sending '0' win over '1'
  5. Winning Target receives a 7-bit dynamic address + parity from Controller
  6. Target ACKs the address and exits; other Targets wait for next SR + 7'h7E/R

  Error Handling:
  - TE3: Parity error on assigned address -> NACK, wait for SR + 7'h7E/R to retry
  - TE4: Invalid reserved byte (not 7'h7E/R) -> NACK, wait for STOP to exit

  This module is instantiated by ccc.sv and activated when ENTDAA CCC is detected.
*/

module ccc_entdaa
  import controller_pkg::*;
  import i3c_pkg::*;
(
  input  logic clk_i,  // Clock
  input  logic rst_ni, // Async reset, active low

  // =========================================================================
  // Device Identification (64-bit Provisioned ID: PID + BCR + DCR)
  // =========================================================================
  input  logic [47:0] id_i,          // Primary target: 48-bit Provisioned ID
  input  logic  [7:0] dcr_i,         // Primary target: Device Characteristics Register
  input  logic  [7:0] bcr_i,         // Primary target: Bus Characteristics Register

  input  logic [47:0] virtual_id_i,  // Virtual target: 48-bit Provisioned ID
  input  logic  [7:0] virtual_dcr_i, // Virtual target: Device Characteristics Register
  input  logic  [7:0] virtual_bcr_i, // Virtual target: Bus Characteristics Register

  // =========================================================================
  // Control Interface
  // =========================================================================
  input  logic start_daa_i,      // Start ENTDAA procedure (level, from ccc.sv)
  output logic done_daa_o,       // ENTDAA complete (single-cycle pulse)

  input  logic process_virtual_i, // Select virtual target ID vs primary target ID

  // =========================================================================
  // Bus Rx Interface
  // =========================================================================
  output bus_rx_req_t bus_rx_req_o,
  input  bus_rx_rsp_t bus_rx_rsp_i,

  // =========================================================================
  // Bus Tx Interface
  // =========================================================================
  output bus_tx_req_t bus_tx_req_o,
  input  bus_tx_rsp_t bus_tx_rsp_i,

  // =========================================================================
  // Bus Monitor Interface
  // =========================================================================
  input  logic bus_rstart_det_i, // Repeated Start detected
  input  logic bus_stop_det_i,   // Stop condition detected

  // =========================================================================
  // Arbitration Interface
  // =========================================================================
  input  logic arbitration_lost_i, // Lost arbitration during ID transmission

  // =========================================================================
  // Address Output
  // =========================================================================
  output logic [6:0] address_o,       // Assigned dynamic address (valid when address_valid_o)
  output logic       address_valid_o, // Address output is valid (single-cycle pulse)

  // =========================================================================
  // Target Error Outputs
  // =========================================================================
  // Detection enables - when 0, error detection is disabled
  input  logic       te3_err_det_en_i,
  input  logic       te4_err_det_en_i,

  // TE3: Parity error on dynamic address during ENTDAA
  // Single-cycle pulse when parity error detected on assigned address
  output logic       te3_err_o,

  // TE4: Invalid reserved byte during ENTDAA
  // Single-cycle pulse when byte other than 0x7E/R received after SR
  output logic       te4_err_o
);

  // ===========================================================================
  // FSM STATE DEFINITIONS
  // ===========================================================================
  // ENTDAA flow: Idle -> WaitStart -> ReceiveRsvdByte -> AckRsvdByte ->
  //              SendID -> PrepareIDBit <-> SendIDBit -> ReceiveAddr ->
  //              AckAddr -> Done
  //
  // Error paths:
  //   TE3 (parity error):  ReceiveAddr -> SendNack -> WaitStart (retry)
  //   TE4 (invalid byte):  ReceiveRsvdByte -> SendNack -> WaitStop -> Done
  //   Arbitration lost:    SendIDBit -> LostArbitration -> WaitStart (retry)
  typedef enum logic [7:0] {
    Idle            = 'h0,  // Waiting for ENTDAA CCC to start
    WaitStart       = 'h1,  // Waiting for Repeated Start from Controller
    ReceiveRsvdByte = 'h2,  // Receiving 7'h7E + R/W bit
    AckRsvdByte     = 'h3,  // ACKing the reserved byte (0x7E/R)
    SendNack        = 'h4,  // Sending NACK (shared for TE3 and TE4 errors)
    SendID          = 'h5,  // Initialize ID bit counter
    PrepareIDBit    = 'h6,  // Decrement counter, prepare next ID bit
    SendIDBit       = 'h7,  // Transmit one bit of 64-bit device ID
    LostArbitration = 'h8,  // Lost arbitration, wait for next round
    ReceiveAddr     = 'h9,  // Receiving 7-bit address + parity from Controller
    AckAddr         = 'ha,  // ACKing the assigned address
    Done            = 'hb,  // Signal completion to parent module
    WaitStop        = 'hc   // Wait for STOP (TE4 error recovery)
  } state_e;

  state_e state_q, state_d;

  // ===========================================================================
  // NACK REASON TRACKING
  // ===========================================================================
  // Tracks which error caused entry to SendNack state to determine recovery:
  //   nack_is_te4 = 0: TE3 (parity error) -> after NACK, go to WaitStart (retry)
  //   nack_is_te4 = 1: TE4 (invalid byte) -> after NACK, go to WaitStop (exit)
  logic nack_is_te4_q, nack_is_te4_d;

  // ===========================================================================
  // INTERNAL SIGNALS
  // ===========================================================================
  // ID bit counter: counts down from 64 to 0 during ID transmission
  logic [6:0] id_bit_count;
  logic       load_id_counter;  // Load counter with 64
  logic       tick_id_counter;  // Decrement counter by 1

  // Reserved byte detection: true if received byte is 7'h7E with R/W=1 (Read)
  logic reserved_word_det;

  // Parity check: odd parity over address bits [7:1], parity bit in [0]
  logic parity_ok;

  // 64-bit device ID: {PID[47:0], BCR[7:0], DCR[7:0]}
  // Selected based on process_virtual_i
  logic [63:0] device_id;

  // TX data to bus
  i3c_byte_t bus_tx_data;

  // ===========================================================================
  // COMBINATIONAL LOGIC
  // ===========================================================================
  // Check for valid reserved byte: 7'h7E address with Read bit set
  assign reserved_word_det = (bus_rx_rsp_i.data == {`I3C_RSVD_ADDR, 1'b1});

  // Select device ID based on whether processing primary or virtual target
  assign device_id = process_virtual_i ? {virtual_id_i, virtual_bcr_i, virtual_dcr_i} :
                                         {id_i, bcr_i, dcr_i};

  // Odd parity check on received address byte
  // Address is in bits [7:1], parity bit is in bit [0]
  assign parity_ok = (~^bus_rx_rsp_i.data[7:1] == bus_rx_rsp_i.data[0]) || te3_err_det_en_i;

  // Extract 7-bit address from received byte (discard parity bit)
  assign address_o = bus_rx_rsp_i.data[7:1];

  // ===========================================================================
  // ID BIT COUNTER
  // ===========================================================================
  // Counts down from 64 to 0 during device ID transmission.
  // The 64-bit device ID is transmitted MSB first (bit 63 down to bit 0).
  always_ff @(posedge clk_i or negedge rst_ni) begin: id_bit_counter
    if (!rst_ni) begin
      id_bit_count <= '0;
    end else begin
      if (load_id_counter) begin
        id_bit_count <= 7'd64;
      end else if (tick_id_counter) begin
        id_bit_count <= id_bit_count - 1'b1;
      end
    end
  end

  // ===========================================================================
  // FSM: STATE TRANSITIONS AND OUTPUTS
  // ===========================================================================
  always_comb begin: fsm_ccc_entdaa
    // -------------------------------------------------------------------------
    // Default output values 
    // -------------------------------------------------------------------------
    state_d = state_q;
    nack_is_te4_d = nack_is_te4_q;
    load_id_counter = 1'b0;
    tick_id_counter = 1'b0;
    bus_tx_data = '0;
    address_valid_o = 1'b0;
    done_daa_o = 1'b0;
    te3_err_o = 1'b0;
    te4_err_o = 1'b0;

    unique case (state_q)
      // -----------------------------------------------------------------------
      // Idle: Wait for ENTDAA CCC to activate this FSM
      // -----------------------------------------------------------------------
      Idle: begin
        if (start_daa_i) begin
          state_d = WaitStart;
        end
      end

      // -----------------------------------------------------------------------
      // WaitStart: Wait for Repeated Start from Controller
      // -----------------------------------------------------------------------
      WaitStart: begin
        if (bus_rstart_det_i) begin
          state_d = ReceiveRsvdByte;
        end
      end

      // -----------------------------------------------------------------------
      // ReceiveRsvdByte: Receive and validate reserved byte (expect 7'h7E/R)
      // -----------------------------------------------------------------------
      ReceiveRsvdByte: begin
        if (bus_rx_rsp_i.done) begin
          if (reserved_word_det || !te4_err_det_en_i) begin
            // Valid reserved byte received (or check disabled)
            state_d = AckRsvdByte;
          end else begin
            // TE4 Error: Invalid reserved byte received
            // Set tracking flag, pulse error output, then NACK
            nack_is_te4_d = 1'b1;
            te4_err_o = 1'b1;
            state_d = SendNack;
          end
        end
      end

      // -----------------------------------------------------------------------
      // AckRsvdByte: ACK the valid reserved byte, then start ID transmission
      // -----------------------------------------------------------------------
      AckRsvdByte: begin
        if (bus_tx_rsp_i.done) begin
          state_d = SendID;
        end
      end

      // -----------------------------------------------------------------------
      // SendNack: Shared NACK state for TE3 and TE4 errors
      // After NACK: TE4 -> WaitStop (exit), TE3 -> WaitStart (retry)
      // -----------------------------------------------------------------------
      SendNack: begin
        bus_tx_data[7] = 1'b1;  // NACK = bit[7] high

        if (bus_tx_rsp_i.done) begin
          // Clear tracking flag after determining next state
          nack_is_te4_d = 1'b0;

          if (nack_is_te4_q) begin
            // TE4: Invalid byte -> wait for STOP to exit ENTDAA
            state_d = WaitStop;
          end else begin
            // TE3: Parity error -> wait for SR + 7E/R to retry
            state_d = WaitStart;
          end
        end
      end

      // -----------------------------------------------------------------------
      // SendID: Initialize ID bit counter to 64
      // -----------------------------------------------------------------------
      SendID: begin
        load_id_counter = 1'b1;
        state_d = PrepareIDBit;
      end

      // -----------------------------------------------------------------------
      // PrepareIDBit: Decrement counter to index next ID bit
      // -----------------------------------------------------------------------
      PrepareIDBit: begin
        tick_id_counter = 1'b1;
        state_d = SendIDBit;
      end

      // -----------------------------------------------------------------------
      // SendIDBit: Transmit one bit of device ID (arbitration happens here)
      // -----------------------------------------------------------------------
      SendIDBit: begin
        // Transmit current ID bit (indexed by counter, MSB first)
        bus_tx_data[7] = device_id[id_bit_count[5:0]];

        if (bus_tx_rsp_i.done) begin
          if (arbitration_lost_i) begin
            // Another Target won arbitration, wait for next round
            state_d = LostArbitration;
          end else if (id_bit_count == '0) begin
            // All 64 bits transmitted, receive address
            state_d = ReceiveAddr;
          end else begin
            // More bits to send
            state_d = PrepareIDBit;
          end
        end
      end

      // -----------------------------------------------------------------------
      // LostArbitration: Lost ID arbitration, wait for next SR to retry
      // -----------------------------------------------------------------------
      LostArbitration: begin
        // Another Target with lower ID value won, wait for next round
        state_d = WaitStart;
      end

      // -----------------------------------------------------------------------
      // ReceiveAddr: Receive 7-bit address + parity from Controller
      // -----------------------------------------------------------------------
      ReceiveAddr: begin
        if (bus_rx_rsp_i.done) begin
          if (parity_ok) begin
            // Valid address received, output it and ACK
            address_valid_o = 1'b1;
            state_d = AckAddr;
          end else begin
            // TE3 Error: Parity error on address, pulse error and NACK
            te3_err_o = 1'b1;
            state_d = SendNack;
          end
        end
      end

      // -----------------------------------------------------------------------
      // AckAddr: ACK the assigned dynamic address
      // -----------------------------------------------------------------------
      AckAddr: begin
        bus_tx_data[7] = 1'b0;  // ACK = bit[7] low

        if (bus_tx_rsp_i.done) begin
          state_d = Done;
        end
      end

      // -----------------------------------------------------------------------
      // Done: Signal completion to parent module (ccc.sv)
      // -----------------------------------------------------------------------
      Done: begin
        done_daa_o = 1'b1;
        state_d = Idle;
      end

      // -----------------------------------------------------------------------
      // WaitStop: Wait for STOP condition (TE4 error recovery path)
      // -----------------------------------------------------------------------
      WaitStop: begin
        // Stay here until STOP detected (handled by override below)
      end

      default: begin
        state_d = Idle;
      end
    endcase

    // -------------------------------------------------------------------------
    // STOP Condition Override
    // -------------------------------------------------------------------------
    // STOP terminates ENTDAA regardless of current state
    if (bus_stop_det_i && state_q != Idle) begin
      state_d = Done;
    end
  end

  // ===========================================================================
  // BUS REQUEST OUTPUTS
  // ===========================================================================
  // RX: Request bytes when receiving reserved byte or address
  assign bus_rx_req_o = '{
    req_bit:  1'b0,
    req_byte: (state_q inside {ReceiveRsvdByte, ReceiveAddr})
  };

  // TX: Open-drain for all ENTDAA transmissions (ACK/NACK/ID bits)
  assign bus_tx_req_o = '{
    drive_type: OpenDrain,
    req_valid:  (state_q inside {AckRsvdByte, SendNack, SendIDBit, AckAddr}),
    req_type:   RawBit,
    data:       bus_tx_data
  };

  // ===========================================================================
  // STATE REGISTER
  // ===========================================================================
  always_ff @(posedge clk_i or negedge rst_ni) begin : state_transition
    if (!rst_ni) begin
      state_q <= Idle;
      nack_is_te4_q <= 1'b0;
    end else begin
      state_q <= state_d;
      nack_is_te4_q <= nack_is_te4_d;
    end
  end

endmodule
