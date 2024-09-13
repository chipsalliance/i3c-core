// SPDX-License-Identifier: Apache-2.0

// TODO: Private Read
// TODO: Private Write
// TODO: CCC
// TODO: DAA
// TODO: BCAST

// This module is supposed to operate on I3C Frames, which
// are stripped of starts, stops, addresses, reserved bytes.
// For now, it is sufficient to:
// - receive information if the next byte is R or W or CCC
module flow_standby_i3c
  import controller_pkg::*;
  import i3c_pkg::*;
#(
    parameter int unsigned RxDataWidth = 8,
    parameter int unsigned TxDataWidth = 8
) (
    input logic clk_i,
    input logic rst_ni,
    input logic enable_i,

    // Interface to TTI
    // RX queue
    input logic rx_queue_full_i,
    input logic rx_queue_empty_i,
    output logic rx_queue_wvalid_o,
    input logic rx_queue_wready_i,
    output logic [RxDataWidth-1:0] rx_queue_wdata_o,

    // TX queue
    input logic tx_queue_full_i,
    input logic tx_queue_empty_i,
    input logic tx_queue_rvalid_i,
    output logic tx_queue_rready_o,
    input logic [TxDataWidth-1:0] tx_queue_rdata_i,

    // Interface to target_fsm
    input logic transfer_start_i,
    input logic transfer_stop_i,
    input logic [1:0] transfer_type_i,  // 00 - Write, 01- Read, 10 - CCC
    // input logic transfer_err_i, //target_fsm reported error?

    // Receive byte from the bus
    input logic rx_byte_valid_i,
    input logic [7:0] rx_byte_i,
    output logic rx_byte_ready_o,

    // Transmit byte onto the bus
    output logic tx_byte_valid_o,
    output logic [7:0] tx_byte_o,
    input logic tx_byte_ready_i

    // TODO: Error and error recovery
    // We may need additional override logic to force a state
    // or perform a state reset (or a graceful halt, where we wait until
    // current transaction ends)
);

  logic [7:0] transfer_rx_byte;
  logic [7:0] transfer_tx_byte;

  // TODO: Drive outputs appropriately
  always_comb begin
    tx_queue_rready_o = 1'b0;
  end

  //  FSM
  typedef enum logic [3:0] {
    Idle,
    TransferWait,
    TransferStart,
    TransferWrite,
    TransferRead,
    TransferCCC
  } fsm_state_e;

  fsm_state_e state, state_next;

  // Combinational state output update
  always_comb begin
    unique case (state)
      Idle: begin
      end
      default: begin
      end
    endcase
  end

  // Combinational state transition
  always_comb begin
    state_next = state;
    unique case (state)
      // Idle: Wait for bus activity
      Idle: begin
        if (enable_i) begin
          state_next = TransferWait;
        end
      end
      TransferWait: begin
        if (transfer_start_i) begin
          state_next = TransferStart;
        end
      end
      TransferStart: begin
        if (transfer_type_i == 2'b00) begin
          state_next = TransferWrite;
        end else if (transfer_type_i == 2'b01) begin
          state_next = TransferRead;
        end else if (transfer_type_i == 2'b10) begin
          state_next = TransferCCC;
        end else if (transfer_type_i == 2'b11) begin
          // We should never reach here!
          state_next = Idle;
        end
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

  // Simplified RX/TX transfer handler
  assign rx_byte_ready_o = rx_byte_valid_i;  //TODO: temporarily always accept transfers

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_handler_rx
    if (~rst_ni) begin
      transfer_rx_byte <= '0;
    end else begin
      if (rx_byte_valid_i && rx_byte_ready_o) begin
        transfer_rx_byte <= rx_byte_i;
      end
    end
  end

  assign tx_byte_valid_o = tx_byte_ready_i;  // TODO: temporarily always accept transfers

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_handler_tx
    if (~rst_ni) begin
      transfer_tx_byte <= '0;
    end else begin
      transfer_tx_byte <= 8'hBC;  // TODO: temporarily hard-coded data path
      if (tx_byte_valid_o && tx_byte_ready_i) begin
        tx_byte_o <= transfer_tx_byte;
      end
    end
  end

  // Pass data to TTI RX queue
  // TODO: Check for full, handshake
  // TODO: Depend on correct state in the FSM

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_tti_rx
    if (~rst_ni) begin
      rx_queue_wdata_o  <= '0;
      rx_queue_wvalid_o <= '0;
    end else begin
      if (rx_byte_valid_i && rx_byte_ready_o) begin
        rx_queue_wdata_o  <= rx_byte_i;
        rx_queue_wvalid_o <= '1;
      end else begin
        rx_queue_wdata_o  <= '0;
        rx_queue_wvalid_o <= '0;
      end
    end
  end


endmodule
