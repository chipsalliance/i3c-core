// SPDX-License-Identifier: Apache-2.0
/*
    Private Read

    As soon as the primary FSM recognizes that the current transfer
    is a Private Read, control is transferred to this subordinate FSM.
*/
module private_read#()(
    input clk_i,  // clock
    input rst_ni, // active low reset

    // Interface to primary FSM in i3c_target_fsm.sv
    input logic priv_read_begin_i,
    output logic is_priv_read_done_o,
    input logic is_xfer_i3c, // i2c: 0; i3c: 1

    // Interface to byte_read
    input logic byte_valid_i,
    input logic [7:0] byte_read_i,
    output logic byte_consumed_o,

    // Interface to TTI: RX Queue
    input logic tx_queue_full_i,
    input logic tx_queue_empty_i,
    input logic tx_queue_rvalid_i,
    output logic tx_queue_rready_o,
    input logic [TxDataWidth-1:0] tx_queue_rdata_i
);

  typedef enum logic [7:0] {
    Idle,
    // There is a contract between primary and secondary
    // FSM that the transition will occur just before
    // an ACK/NACK should be sent.
    WriteAck,
    // Read incoming data bytes from the bus
    ReadByte,
    // Read T-bit
    ReadTbit,
    Done
  } pread_state_e;

  pread_state_e state_q, state_d;

 always_comb begin : state_transitions
    case (state_q)
      Idle: begin
        if (priv_read_begin_i)
            state_d = WriteAck;
      end
      WriteAck: begin
        if (write_ack_done)
            state_d = ReadByte;
      end
      ReadByte: begin
        if (byte_valid_i) begin
            if (is_xfer_i3c)
                state_d = ReadTbit;
            else
                state_d = WriteAck;
        end
      end
      ReadTbit: begin
        if (tbit_read)
            state_d = '0; // FIXME
      end
      default:
        state_d = state_q;

    endcase
 end

  // Synchronous state transition
  always_ff @(posedge clk_i or negedge rst_ni) begin : state_transition
    if (!rst_ni) begin
      state_q <= Idle;
    end else begin
      state_q <= state_d;
    end
  end

endmodule
