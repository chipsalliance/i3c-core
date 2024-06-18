// SPDX-License-Identifier: Apache-2.0

// TODO: Private Read
// TODO: Private Write
// TODO: CCC
// TODO: DAA
// TODO: BCAST

module flow_standby
  import controller_pkg::*;
  import i3c_pkg::*;
  import hci_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    // Let's assume I can get a "byte" interface from the target_fsm
    input logic controller_mode_i,  // Active or Standby
    input logic bus_mode_i,  // I3C or I2C
    input logic bus_enable_i,
    input logic controller_enable_i,

    // "Byte interface" from target
    input logic det_start_i,  // Target detected Start
    input logic addr_match_i,  // Address Matches
    input logic i3c_rsvd_byte_i,  // First byte is I3C Reserved Byte {7'h7E, 1'b0}
    input logic det_rnw_i,  // Target detected Read or Write bit
    input logic rnw_i,  // Read or Write bit
    input logic det_stop_i,  // Target detected Stop
    input logic det_rstart_i,  // Target detected Repeated Start
    input logic det_ack_i,  // Target ACK'ed bit
    input logic det_tbit_i,  // Target detected T-bit
    input logic tbit_i,  // Value of the T-bit
    input logic byte_valid_i,  // high if there is valid data in acq_fifo
    input logic [7:0] byte_i,  // data byte
    output logic byte_valid_o,  // Optional, confirm handshake

    // Error and error recovery
    input logic terminate_force_i,  // Reset everything to IDLE?
    input logic terminate_soft_i,  // Optional, if needed
    output logic terminate_complete_o
);

  //  FSM
  typedef enum logic [3:0] {
    Idle,
    AddressHeaderWait,
    AddressHeaderRead,
    SecondByteWait,
    SecondByteRead,
    NextByteWait,
    NextByteRead,
    //
    CCCDetect,
    CCCWait,
    CCCDirectRead,
    CCCDirectWrite,
    //
    PrivateTransfer,
    PrivateRead,
    PrivateWrite,
    GenericError
  } fsm_state_e;

  fsm_state_e state, state_next;

  // Combinational state output update
  always_comb begin
    unique case (state)
      // Idle: Wait for command appearance in the Command Queue
      Idle: begin

      end
      default: begin
        // TODO
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_
    if (~rst_ni) begin

    end else begin

    end
  end

  // TODO: We go to CCC flow if there was no SR after ACK!
  // TODO: Address after S or SR is for private transfers
  // Combinational state transition
  always_comb begin
    state_next = state;
    unique case (state)
      // Idle: Wait for bus activity
      Idle: begin
        if (det_start_i) begin
          state_next = AddressHeaderWait;
        end
      end
      AddressHeaderWait: begin
        // TODO: Are we always ready to receive?
        if (byte_valid_i)  // We can read the first byte
          state_next = AddressHeaderRead;
      end
      AddressHeaderRead: begin
        // Transfer can still be CCC or Private Read/Write
        if (byte_i == `I3C_RSVD_ADDR) state_next = SecondByteWait;
        // If the first byte is our address, it's a Private RW
        if (addr_match_i & det_rnw_i & rnw_i) state_next = PrivateWrite;
        else if (addr_match_i & det_rnw_i & !rnw_i) state_next = PrivateRead;
      end
      SecondByteWait: begin
        // TODO: Are we always ready to receive?
        // TODO: Check that (ACK and SR) or (ACK) happened
        if (byte_valid_i) begin
          state_next = SecondByteRead;
        end  // Read the second byte
      end
      SecondByteRead: begin
        // TODO: Handle
      end
      CCCDetect: begin
        state_next = CCCWait;
      end
      PrivateTransfer: begin
        if (addr_match_i) begin
          if (rnw_i) begin
            state_next = PrivateRead;
          end else begin
            state_next = PrivateWrite;
          end
        end
      end
      PrivateRead: begin
        // TODO: Handle
        // Raise interrupt if no data in queue
        // Handle reading from TTI queues
        state_next = Idle;
      end
      PrivateWrite: begin
        // TODO: Handle
        // Raise interrupt if no data space in queue
        // Handle writing to TTI queues
        state_next = Idle;
      end
      default: begin
        state_next = Idle;
      end
    endcase
  end

  // Sequential state update
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_test
    if (~rst_ni) begin
      state <= Idle;
    end else begin
      state <= state_next;
    end
  end

endmodule
