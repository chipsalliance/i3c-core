// SPDX-License-Identifier: Apache-2.0

/*
  This module is responsible for handling the IBI descriptors.

  The descriptor is written to the TTI IBI queue by software. Optional IBI
  data follows immediately the descriptor in the same queue.

  The module watches the TTI IBI queue for descriptor write. Once a descriptor
  is in the module peeks it and waits until the defined count of data words is
  written to the queue. Finally, the module outputs MDB and the data as 8-bit
  words.

  TODO: The TTI IBI queue must be EMPTY each time a descriptor is written.
  This is because the module relies on absolute count of data words stored in
  it, not the distance between two consecutive descriptors.
*/
module descriptor_ibi import i3c_pkg::i3c_byte_t; #(
  parameter int unsigned TtiIbiDataWidth = 32,
  parameter int unsigned TtiIbiDataDepth = 32
) (
  input  logic clk_i,
  input  logic rst_ni,

  // TTI: In-band-interrupt queue
  input  logic                       ibi_queue_rvalid_i,
  output logic                       ibi_queue_rready_o,
  input  logic [TtiIbiDataWidth-1:0] ibi_queue_rdata_i,
  input  logic [TtiIbiDataDepth-1:0] ibi_queue_depth_i,

  // Interface to/from target FSM
  output logic      ibi_byte_valid_o,
  input  logic      ibi_byte_ready_i,
  output i3c_byte_t ibi_byte_o,
  output logic      ibi_byte_last_o,
  input  logic      ibi_byte_flush_i
);

  i3c_byte_t data_mdb;
  i3c_byte_t data_byte;

  logic [7:0] data_len;
  logic [7:0] data_words;
  logic       latch_descriptor;

  logic [7:0] data_cnt_q, data_cnt_d;

  typedef enum logic [2:0] {
    Idle,
    DescLatch,
    DescPop,
    WriteMdb,
    WriteData,
    Flush
  } state_e;

  state_e state_q, state_d;

  // 32-bit to 8-bit data conversion
  assign data_byte = ibi_queue_rdata_i[data_cnt_q[1:0]*8 +: 8];

  // FSM combinational process
  always_comb begin
    ibi_byte_o       = '0;
    ibi_byte_valid_o = 1'b0;
    ibi_byte_last_o  = 1'b0;

    ibi_queue_rready_o = 1'b0;

    latch_descriptor = 1'b0;

    data_cnt_d = data_cnt_q;
    state_d    = state_q;
    case (state_q)
      Idle: begin
        if (ibi_queue_rvalid_i) begin
          data_cnt_d = '0;
          latch_descriptor = 1'b1;
          state_d = DescLatch;
        end
      end

      DescLatch: begin
        // Only proceed if enough data has been pushed to queue, including the descriptor
        if (ibi_queue_depth_i >= (data_words + 1)) begin
          state_d = DescPop;
        end
      end

      DescPop: begin
        ibi_queue_rready_o = 1'b1;
        state_d = WriteMdb;
      end

      WriteMdb: begin
        ibi_byte_o       = data_mdb;
        ibi_byte_valid_o = 1'b1;
        // No payload data - data_len is derived by subtracting 1 from the respective descriptor
        // field, said field being zero therefore results in 0xFF for data_len (deliberate underflow).
        ibi_byte_last_o  = (data_len == 8'hFF);

        if (ibi_byte_flush_i) begin
          // Handle special cases for flushing
          if (data_words == 0) begin
            // No data after MDB, flushing is a NOP
            state_d = Idle;
          end else begin
            // At least one word in queue after descriptor, flush it out
            ibi_queue_rready_o = 1'b1;
            // If there's more than one word, actually go to the Flush state
            state_d = (data_words == 8'd1) ? Idle : Flush;
          end
        end else if (ibi_byte_ready_i) begin
          // Back to Idle on no payload data
          state_d = (data_len == 8'hFF) ? Idle : WriteData;
        end
      end

      WriteData: begin
        ibi_byte_o       = data_byte;
        ibi_byte_valid_o = ibi_queue_rvalid_i;
        ibi_byte_last_o  = (data_len == data_cnt_q); // Last payload byte

        if (ibi_byte_flush_i) begin
          ibi_queue_rready_o = 1'b1;
          // Overflow check
          if (data_cnt_q[7:2] != '1) begin
            // Round up to next full word and pop word from queue
            data_cnt_d = {data_cnt_q[7:2] + 1, 2'b00};
            state_d = Flush;
          end else begin
            // This was a very big IBI and we happened to be at the last word already
            data_cnt_d = '0;
            state_d = Idle;
          end
        end else if (ibi_byte_ready_i && (data_cnt_q == data_len)) begin
          // Last byte read by target FSM; back to Idle
          ibi_queue_rready_o = 1'b1;
          data_cnt_d = '0;
          state_d = Idle;
        end else if (ibi_byte_ready_i) begin
          data_cnt_d = data_cnt_q + 1;
          ibi_queue_rready_o = (data_cnt_q[1:0] == 2'b11);
        end
      end

      Flush: begin
        if (data_cnt_q >= data_len) begin
          data_cnt_d = '0;
          state_d = Idle;
        end else begin
          // Flush out any data as fast as possible
          ibi_queue_rready_o = 1'b1;
          // Overflow check, only increment if not at last word already
          if (data_cnt_q[7:2] != '1) begin
            data_cnt_d = data_cnt_q + 4;
          end else begin
            data_cnt_d = '0;
            state_d = Idle;
          end
        end
      end
    endcase
  end

  // Capture IBI descriptor
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      data_mdb   <= '0;
      data_len   <= '0;
      data_words <= '0;
    end else if (latch_descriptor) begin
      data_mdb   <= ibi_queue_rdata_i[31:24];
      // -1 to compensate for comparison with data_cnt_q
      data_len   <= ibi_queue_rdata_i[7:0] - 1;
      // Divide by 4 and round up
      data_words <= 8'(ibi_queue_rdata_i[7:2] + |ibi_queue_rdata_i[1:0]);
    end
  end

  // FSM and data counter flops
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q    <= Idle;
      data_cnt_q <= '0;
    end else begin
      state_q    <= state_d;
      data_cnt_q <= data_cnt_d;
    end
  end

endmodule
