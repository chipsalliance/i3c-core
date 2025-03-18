// SPDX-License-Identifier: Apache-2.0

/*
  This module is responsible for handling the TX descriptors.

  * The target FSM fetches data from the queue during Private Reads
  * However, if a Private Read occurs before there is a valid TX Descriptor
    and valid data in the queue, then the target will NACK such transaction.
  * This module counts how many bytes were sent to the bus and asserts last
    on the last transfer so that the target FSM can set T-bit correctly.
  * Target FSM may respond with a bus error, which means that the current transaction
  should be aborted.
*/
module descriptor_tx #(
    parameter int unsigned TtiTxDescDataWidth = 32,
    parameter int unsigned TtiTxDataWidth = 8,
    parameter int unsigned TtiTxFifoDepthWidth = 16
) (
    input logic clk_i,
    input logic rst_ni,

    // TTI: TX Descriptor
    input logic tti_tx_desc_queue_rvalid_i,
    output logic tti_tx_desc_queue_rready_o,
    input logic [TtiTxDescDataWidth-1:0] tti_tx_desc_queue_rdata_i,

    // TTI: TX Data
    input logic tti_tx_queue_rvalid_i,
    input logic [TtiTxFifoDepthWidth-1:0] tti_tx_queue_depth_i,
    output logic tti_tx_queue_rready_o,
    input logic [TtiTxDataWidth-1:0] tti_tx_queue_rdata_i,
    input  logic tti_tx_queue_empty_i,
    output logic tx_queue_flush_o,

    // Interface to the target FSM
    input logic tx_start_i,
    input logic tx_abort_i,
    output logic tx_desc_avail_o,
    output logic [7:0] tx_byte_o,
    output logic tx_byte_last_o,
    output logic tx_byte_valid_o,
    input logic tx_byte_ready_i,
    output logic tx_end_o,

    // recovery mode
    input recovery_mode_enter_i
);

  logic [31:0] tx_descriptor;
  logic [15:0] byte_counter;
  logic [15:0] data_len;
  logic [TtiTxDescDataWidth-1:0] data_len_words;
  logic descriptor_valid;
  logic tx_start;
  logic tx_pending;
  logic tx_end;
  logic flush;

  assign tti_tx_desc_queue_rready_o = ~descriptor_valid && tx_start_i &&
                                      tti_tx_desc_queue_rvalid_i && !flush &&
                                      !(tx_abort_i || recovery_mode_enter_i);

  assign tx_desc_avail_o = tti_tx_desc_queue_rvalid_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_
    if (!rst_ni) begin
      descriptor_valid <= '0;
      tx_descriptor <= '0;
    end else begin
      if (tx_end) descriptor_valid <= '0;
      else if (tti_tx_desc_queue_rready_o) begin
        tx_descriptor <= tti_tx_desc_queue_rdata_i;
        descriptor_valid <= '1;
      end
      else if (tx_abort_i || recovery_mode_enter_i) begin
        descriptor_valid <= '0;
        tx_descriptor <= '0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      flush <= '0;
    end else begin
      if (!flush) begin
        if (tx_abort_i || (recovery_mode_enter_i && |byte_counter)) begin
            flush <= '1;
        end
      end else begin
        // Flush complete
        if ((byte_counter == 16'd1) && tti_tx_queue_rvalid_i)
            flush <= '0;
        // No more data in the FIFO to complete the flush
        if (!tti_tx_queue_rvalid_i && tti_tx_queue_empty_i)
            flush <= '0;
        // Last word from the FIFO is flushed
        if (tx_queue_flush_o)
            flush <= '0;
      end
    end
  end

  assign data_len = tx_descriptor[15:0];
  assign data_len_words = TtiTxDescDataWidth'(data_len >> 2);
  // Add 1 to depth, because there is one word in the Nto8 converter
  assign tx_start = ~tx_pending && descriptor_valid &&
                    ((tti_tx_queue_depth_i+1'b1) >= data_len_words);

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_tx_pending
    if (!rst_ni) begin
      tx_pending <= '0;
    end else begin
      if (tx_start) begin
        tx_pending <= '1;
      end else if (tx_end | tx_abort_i) begin
        tx_pending <= '0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_byte_counter
    if (!rst_ni) begin
      byte_counter   <= '0;
    end else begin
      if (tx_start) begin
        byte_counter <= data_len;
      end else if (tti_tx_queue_rready_o) begin
        byte_counter <= byte_counter - 1'b1;
      end else begin
        byte_counter <= byte_counter;
      end
    end
  end

  assign tx_end = (byte_counter == 16'h1 && tx_byte_ready_i | flush);
  assign tx_byte_valid_o = tx_pending && tti_tx_queue_rvalid_i;
  assign tx_byte_last_o = byte_counter == 16'd1;
  assign tx_byte_o = tti_tx_queue_rdata_i;
  assign tti_tx_queue_rready_o = (tx_byte_valid_o && tx_byte_ready_i) | (flush && tti_tx_queue_rvalid_i);

  assign tx_queue_flush_o = (|data_len[1:0] & tx_end) | (|byte_counter[1:0] & tx_end);

  assign tx_end_o = tx_end;
endmodule
