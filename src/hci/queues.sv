// SPDX-License-Identifier: Apache-2.0

module queues
  import hci_pkg::*;
#(
    parameter int unsigned TX_DESC_FIFO_DEPTH = 64,
    parameter int unsigned RX_DESC_FIFO_DEPTH = 256,
    parameter int unsigned RX_FIFO_DEPTH = 64,
    parameter int unsigned TX_FIFO_DEPTH = 64,

    parameter int unsigned TX_DESC_FIFO_DATA_WIDTH = 64,
    parameter int unsigned RX_DESC_FIFO_DATA_WIDTH = 32,
    parameter int unsigned RX_FIFO_DATA_WIDTH = 32,
    parameter int unsigned TX_FIFO_DATA_WIDTH = 32,

    parameter int unsigned TX_DESC_THLD_WIDTH = 8,
    parameter int unsigned TX_THLD_WIDTH = 3,
    parameter int unsigned RX_THLD_WIDTH = 3,
    parameter int unsigned RX_DESC_THLD_WIDTH = 8,

    // HCI queues' depth widths
    localparam int unsigned TxDescFifoDepthW = $clog2(TX_DESC_FIFO_DEPTH + 1),
    localparam int unsigned RxFifoDepthW = $clog2(RX_FIFO_DEPTH + 1),
    localparam int unsigned TxFifoDepthW = $clog2(TX_FIFO_DEPTH + 1),
    localparam int unsigned RxDescFifoDepthW = $clog2(RX_DESC_FIFO_DEPTH + 1)
) (
    input logic clk_i,
    input logic rst_ni,

    // Response FIFO: status / control
    output logic rx_desc_full_o,
    output logic rx_desc_above_thld_o,
    output logic rx_desc_empty_o,
    input logic rx_desc_wvalid_i,
    output logic rx_desc_wready_o,
    input logic [RX_DESC_FIFO_DATA_WIDTH-1:0] rx_desc_wdata_i,
    input logic rx_desc_req_i,
    output logic rx_desc_ack_o,
    output logic [RX_DESC_FIFO_DATA_WIDTH-1:0] rx_desc_data_o,
    input logic [RX_DESC_THLD_WIDTH-1:0] rx_desc_thld_i,
    output logic [RX_DESC_THLD_WIDTH-1:0] rx_desc_thld_o,
    input logic rx_desc_reg_rst_i,
    output logic rx_desc_reg_rst_we_o,
    output logic rx_desc_reg_rst_data_o,

    // Direct FIFO read control
    output logic tx_desc_full_o,
    output logic tx_desc_below_thld_o,
    output logic tx_desc_empty_o,
    output logic tx_desc_rvalid_o,
    input logic tx_desc_rready_i,
    output logic [TX_DESC_FIFO_DATA_WIDTH-1:0] tx_desc_rdata_o,
    input logic tx_desc_req_i,
    output logic tx_desc_ack_o,
    input logic [TX_DESC_FIFO_DATA_WIDTH-1:0] tx_desc_data_i,
    input logic [TX_DESC_THLD_WIDTH-1:0] tx_desc_thld_i,
    output logic [TX_DESC_THLD_WIDTH-1:0] tx_desc_thld_o,
    input logic tx_desc_reg_rst_i,
    output logic tx_desc_reg_rst_we_o,
    output logic tx_desc_reg_rst_data_o,

    // RX FIFO
    output logic rx_full_o,
    output logic rx_above_thld_o,
    output logic rx_empty_o,
    input logic rx_wvalid_i,
    output logic rx_wready_o,
    input logic [RX_FIFO_DATA_WIDTH-1:0] rx_wdata_i,
    input logic rx_req_i,
    output logic rx_ack_o,
    output logic [RX_FIFO_DATA_WIDTH-1:0] rx_data_o,
    input logic [RX_THLD_WIDTH-1:0] rx_thld_i,
    output logic [RX_THLD_WIDTH-1:0] rx_thld_o,
    input logic rx_reg_rst_i,
    output logic rx_reg_rst_we_o,
    output logic rx_reg_rst_data_o,

    // TX FIFO: status / control
    output logic tx_full_o,
    output logic tx_below_thld_o,
    output logic tx_empty_o,
    output logic tx_rvalid_o,
    input logic tx_rready_i,
    output logic [TX_FIFO_DATA_WIDTH-1:0] tx_rdata_o,
    input logic tx_req_i,
    output logic tx_ack_o,
    input logic [TX_FIFO_DATA_WIDTH-1:0] tx_data_i,
    input logic [TX_THLD_WIDTH-1:0] tx_thld_i,
    output logic [TX_THLD_WIDTH-1:0] tx_thld_o,
    input logic tx_reg_rst_i,
    output logic tx_reg_rst_we_o,
    output logic tx_reg_rst_data_o
);

  read_queue #(
      .DEPTH(RX_DESC_FIFO_DEPTH),
      .DATA_WIDTH(RX_DESC_FIFO_DATA_WIDTH),
      .THLD_WIDTH(RX_DESC_THLD_WIDTH),
      .THLD_IS_POW(0)
  ) rx_desc_fifo (
      .clk_i,
      .rst_ni,
      .full_o(rx_desc_full_o),
      .above_thld_o(rx_desc_above_thld_o),
      .empty_o(rx_desc_empty_o),
      .wvalid_i(rx_desc_wvalid_i),
      .wready_o(rx_desc_wready_o),
      .wdata_i(rx_desc_wdata_i),
      .req_i(rx_desc_req_i),
      .ack_o(rx_desc_ack_o),
      .data_o(rx_desc_data_o),
      .thld_i(rx_desc_thld_i),
      .thld_o(rx_desc_thld_o),
      .reg_rst_i(rx_desc_reg_rst_i),
      .reg_rst_we_o(rx_desc_reg_rst_we_o),
      .reg_rst_data_o(rx_desc_reg_rst_data_o)
  );

  write_queue #(
      .DEPTH(TX_DESC_FIFO_DEPTH),
      .DATA_WIDTH(TX_DESC_FIFO_DATA_WIDTH),
      .THLD_WIDTH(TX_DESC_THLD_WIDTH),
      .THLD_IS_POW(0)
  ) tx_desc_fifo (
      .clk_i,
      .rst_ni,
      .full_o(tx_desc_full_o),
      .below_thld_o(tx_desc_below_thld_o),
      .empty_o(tx_desc_empty_o),
      .rvalid_o(tx_desc_rvalid_o),
      .rready_i(tx_desc_rready_i),
      .rdata_o(tx_desc_rdata_o),
      .req_i(tx_desc_req_i),
      .ack_o(tx_desc_ack_o),
      .data_i(tx_desc_data_i),
      .thld_i(tx_desc_thld_i),
      .thld_o(tx_desc_thld_o),
      .reg_rst_i(tx_desc_reg_rst_i),
      .reg_rst_we_o(tx_desc_reg_rst_we_o),
      .reg_rst_data_o(tx_desc_reg_rst_data_o)
  );

  read_queue #(
      .DEPTH(RX_FIFO_DEPTH),
      .DATA_WIDTH(RX_FIFO_DATA_WIDTH),
      .THLD_WIDTH(RX_THLD_WIDTH),
      .THLD_IS_POW(1)
  ) rx_fifo (
      .clk_i,
      .rst_ni,
      .full_o(rx_full_o),
      .above_thld_o(rx_above_thld_o),
      .empty_o(rx_empty_o),
      .wvalid_i(rx_wvalid_i),
      .wready_o(rx_wready_o),
      .wdata_i(rx_wdata_i),
      .req_i(rx_req_i),
      .ack_o(rx_ack_o),
      .data_o(rx_data_o),
      .thld_i(rx_thld_i),
      .thld_o(rx_thld_o),
      .reg_rst_i(rx_reg_rst_i),
      .reg_rst_we_o(rx_reg_rst_we_o),
      .reg_rst_data_o(rx_reg_rst_data_o)
  );

  write_queue #(
      .DEPTH(TX_FIFO_DEPTH),
      .DATA_WIDTH(TX_FIFO_DATA_WIDTH),
      .THLD_WIDTH(TX_THLD_WIDTH),
      .THLD_IS_POW(1)
  ) tx_fifo (
      .clk_i,
      .rst_ni,
      .full_o(tx_full_o),
      .below_thld_o(tx_below_thld_o),
      .empty_o(tx_empty_o),
      .rvalid_o(tx_rvalid_o),
      .rready_i(tx_rready_i),
      .rdata_o(tx_rdata_o),
      .req_i(tx_req_i),
      .ack_o(tx_ack_o),
      .data_i(tx_data_i),
      .thld_i(tx_thld_i),
      .thld_o(tx_thld_o),
      .reg_rst_i(tx_reg_rst_i),
      .reg_rst_we_o(tx_reg_rst_we_o),
      .reg_rst_data_o(tx_reg_rst_data_o)
  );

endmodule
