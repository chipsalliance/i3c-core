// SPDX-License-Identifier: Apache-2.0

/*
  This module is responsible for handling the IBI descriptors.

  TODO: Make number of retries configurable
*/
module descriptor_ibi #(
    parameter int unsigned TtiIbiDataWidth = 32,
    parameter int unsigned IbiFifoWidth = 8
) (
    input logic clk_i,
    input logic rst_ni,

    // TTI: In-band-interrupt queue
    input logic ibi_queue_full_i,
    input logic ibi_queue_empty_i,
    input logic ibi_queue_rvalid_i,
    output logic ibi_queue_rready_o,
    input logic [TtiIbiDataWidth-1:0] ibi_queue_rdata_i,

    // Target FSM IBI
    output logic                    ibi_fifo_rvalid_o,
    input  logic                    ibi_fifo_rready_i,
    output logic [IbiFifoWidth-1:0] ibi_fifo_rdata_o,
    output logic                    ibi_last_o,
    input  logic                    ibi_err_i
);

  // TODO: Implement IBI descriptor and queue handling
  assign ibi_fifo_rdata_o = '0;
  assign ibi_fifo_rvalid_o = '0;
  assign ibi_last_o = '0;

endmodule
