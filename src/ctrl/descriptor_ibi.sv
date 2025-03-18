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
module descriptor_ibi #(
    parameter int unsigned TtiIbiDataWidth = 32,
    parameter int unsigned TtiIbiDataDepth = 32,
    parameter int unsigned IbiFifoWidth = 8
) (
    input logic clk_i,
    input logic rst_ni,

    // TTI: In-band-interrupt queue
    input logic ibi_queue_full_i,
    input logic ibi_queue_empty_i,
    input logic ibi_queue_rvalid_i,
    input logic [TtiIbiDataDepth-1:0] ibi_queue_depth_i,
    output logic ibi_queue_rready_o,
    input logic [TtiIbiDataWidth-1:0] ibi_queue_rdata_i,

    // Target FSM IBI
    output logic ibi_byte_valid_o,
    input logic ibi_byte_ready_i,
    output logic [IbiFifoWidth-1:0] ibi_byte_o,
    output logic ibi_byte_last_o,
    input logic ibi_byte_err_i
);

  logic [7:0] data_mdb;
  logic [7:0] data_len;
  logic [7:0] data_words;
  logic [7:0] data_cnt;
  logic [7:0] data_byte;
  logic       data_pop;
  logic       ibi_dmux_sel;

  typedef enum logic [7:0] {
    Idle,
    DescLatch,
    DescPop,
    WriteMdb,
    WriteData
  } state_e;

  state_e state_q;

  // TTI IBI Queue ready
  assign ibi_queue_rready_o = ibi_queue_rvalid_i &&
        (state_q == DescPop) ||
        (state_q == WriteData && ibi_byte_ready_i && data_pop);

  // FSM
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) state_q <= Idle;
    else
      unique case (state_q)
        Idle: if (ibi_queue_rvalid_i) state_q <= DescLatch;

        DescLatch:
        if (ibi_queue_depth_i >= (data_words + 1))  // Account for the descriptor
          state_q <= DescPop;

        DescPop: state_q <= WriteMdb;

        WriteMdb:
        if (ibi_byte_ready_i)
          if (data_len == 8'hFF)  // No data
            state_q <= Idle;
          else  // With data
            state_q <= WriteData;

        WriteData: if (ibi_byte_ready_i) if (data_cnt == data_len) state_q <= Idle;

        default: state_q <= Idle;
      endcase

  // Capture IBI descriptor
  always_ff @(posedge clk_i)
    if (state_q == Idle && ibi_queue_rvalid_i) begin
      data_mdb   <= ibi_queue_rdata_i[31:24];
      // -1 to compensate for comparison with data_cnt
      data_len   <= ibi_queue_rdata_i[7:0] - 1;
      // Divide by 4 and round up
      data_words <= 8'(ibi_queue_rdata_i[7:2] + |ibi_queue_rdata_i[1:0]);
    end

  // Data counter
  always_ff @(posedge clk_i)
    if (state_q == Idle) begin
      data_cnt <= '0;
    end else if (state_q == WriteData) begin
      if (ibi_queue_rvalid_i && ibi_byte_ready_i) data_cnt <= data_cnt + 1;
    end

  // 32-bit to 8-bit conversion
  always_comb
    unique case (data_cnt[1:0])
      2'b00:   data_byte = ibi_queue_rdata_i[7:0];
      2'b01:   data_byte = ibi_queue_rdata_i[15:8];
      2'b10:   data_byte = ibi_queue_rdata_i[23:16];
      2'b11:   data_byte = ibi_queue_rdata_i[31:24];
      default: data_byte = ibi_queue_rdata_i[7:0];
    endcase

  assign data_pop = (data_cnt[1:0] == 2'b11) ||  // Pop every 4 bytes
      (data_cnt == data_len);  // Pop the last word

  // Output mux control
  assign ibi_dmux_sel = (state_q == WriteMdb);

  // Output mux
  assign ibi_byte_valid_o = (ibi_dmux_sel) ? 1'b1 : ((state_q == WriteData) && ibi_queue_rvalid_i);
  assign ibi_byte_o = (ibi_dmux_sel) ? data_mdb : data_byte;
  assign ibi_byte_last_o = (ibi_dmux_sel) ? &data_len : (data_cnt == data_len);

endmodule
