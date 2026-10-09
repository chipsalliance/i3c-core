// SPDX-License-Identifier: Apache-2.0
`include "i3c_defines.svh"

module descriptor_tx_test_wrapper
  import i3c_pkg::*;
#(
  localparam int unsigned TtiTxFifoDepthWidth = $clog2(`TX_FIFO_DEPTH + 1)
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic tti_tx_desc_queue_rvalid_i,
  output logic tti_tx_desc_queue_rready_o,
  input  logic [31:0] tti_tx_desc_queue_rdata_i,
  input  logic tti_tx_queue_rvalid_i,
  output logic tti_tx_queue_rready_o,
  input  logic [7:0] tti_tx_queue_rdata_i,
  input  logic [TtiTxFifoDepthWidth-1:0] tti_tx_queue_depth_i,
  input  logic tti_tx_queue_empty_i,
  output logic tx_queue_flush_o,
  output logic tx_byte_valid_o,
  input  logic tx_byte_ready_i,
  output i3c_byte_t tx_byte_o,
  output logic tx_byte_last_o,
  input  logic tx_start_i,
  output logic tx_end_o,
  input  logic tx_abort_i,
  output logic tx_desc_avail_o
);

  descriptor_tx #(
    .TtiTxFifoDepthWidth(TtiTxFifoDepthWidth)
  ) xdescriptor_tx (
    .*
  );

endmodule
