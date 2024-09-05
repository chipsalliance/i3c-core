// SPDX-License-Identifier: Apache-2.0

module queues #(
    parameter int unsigned CsrDataWidth = 32,

    parameter int unsigned TxDescFifoDepth = 64,
    parameter int unsigned RxDescFifoDepth = 256,
    parameter int unsigned TxFifoDepth = 64,
    parameter int unsigned RxFifoDepth = 64,

    parameter int unsigned TxDescFifoDataWidth = 64,
    parameter int unsigned RxDescFifoDataWidth = 32,
    parameter int unsigned TxFifoDataWidth = 32,
    parameter int unsigned RxFifoDataWidth = 32,

    parameter int unsigned TxDescFifoThldWidth = 8,
    parameter int unsigned RxDescFifoThldWidth = 8,
    parameter int unsigned TxFifoThldWidth = 3,
    parameter int unsigned RxFifoThldWidth = 3
) (
    input logic clk_i,
    input logic rst_ni,

    // Response FIFO: status / control
    output logic rx_desc_full_o,
    output logic rx_desc_start_thld_trig_o,
    output logic rx_desc_ready_thld_trig_o,
    output logic rx_desc_empty_o,
    input logic rx_desc_wvalid_i,
    output logic rx_desc_wready_o,
    input logic [RxDescFifoDataWidth-1:0] rx_desc_wdata_i,
    input logic rx_desc_req_i,
    output logic rx_desc_ack_o,
    output logic [RxDescFifoDataWidth-1:0] rx_desc_data_o,
    input logic [RxDescFifoThldWidth-1:0] rx_desc_start_thld_i,
    input logic [RxDescFifoThldWidth-1:0] rx_desc_ready_thld_i,
    output logic [RxDescFifoThldWidth-1:0] rx_desc_ready_thld_o,
    input logic rx_desc_reg_rst_i,
    output logic rx_desc_reg_rst_we_o,
    output logic rx_desc_reg_rst_data_o,

    // Direct FIFO read control
    output logic tx_desc_full_o,
    output logic tx_desc_start_thld_trig_o,
    output logic tx_desc_ready_thld_trig_o,
    output logic tx_desc_empty_o,
    output logic tx_desc_rvalid_o,
    input logic tx_desc_rready_i,
    output logic [TxDescFifoDataWidth-1:0] tx_desc_rdata_o,
    input logic tx_desc_req_i,
    output logic tx_desc_ack_o,
    input logic [CsrDataWidth-1:0] tx_desc_data_i,
    input logic [TxDescFifoThldWidth-1:0] tx_desc_start_thld_i,
    input logic [TxDescFifoThldWidth-1:0] tx_desc_ready_thld_i,
    output logic [TxDescFifoThldWidth-1:0] tx_desc_ready_thld_o,
    input logic tx_desc_reg_rst_i,
    output logic tx_desc_reg_rst_we_o,
    output logic tx_desc_reg_rst_data_o,

    // RX FIFO
    output logic rx_full_o,
    output logic rx_start_thld_trig_o,
    output logic rx_ready_thld_trig_o,
    output logic rx_empty_o,
    input logic rx_wvalid_i,
    output logic rx_wready_o,
    input logic [RxFifoDataWidth-1:0] rx_wdata_i,
    input logic rx_req_i,
    output logic rx_ack_o,
    output logic [RxFifoDataWidth-1:0] rx_data_o,
    input logic [RxFifoThldWidth-1:0] rx_start_thld_i,
    input logic [RxFifoThldWidth-1:0] rx_ready_thld_i,
    output logic [RxFifoThldWidth-1:0] rx_ready_thld_o,
    input logic rx_reg_rst_i,
    output logic rx_reg_rst_we_o,
    output logic rx_reg_rst_data_o,

    // TX FIFO: status / control
    output logic tx_full_o,
    output logic tx_start_thld_trig_o,
    output logic tx_ready_thld_trig_o,
    output logic tx_empty_o,
    output logic tx_rvalid_o,
    input logic tx_rready_i,
    output logic [TxFifoDataWidth-1:0] tx_rdata_o,
    input logic tx_req_i,
    output logic tx_ack_o,
    input logic [CsrDataWidth-1:0] tx_data_i,
    input logic [TxFifoThldWidth-1:0] tx_start_thld_i,
    input logic [TxFifoThldWidth-1:0] tx_ready_thld_i,
    output logic [TxFifoThldWidth-1:0] tx_ready_thld_o,
    input logic tx_reg_rst_i,
    output logic tx_reg_rst_we_o,
    output logic tx_reg_rst_data_o
);

  read_queue #(
      .Depth(RxDescFifoDepth),
      .DataWidth(RxDescFifoDataWidth),
      .ThldWidth(RxDescFifoThldWidth),
      .LimitReadyThld(1),
      .ThldIsPow(0)
  ) rx_desc_fifo (
      .clk_i,
      .rst_ni,
      .full_o(rx_desc_full_o),
      .start_thld_trig_o(rx_desc_start_thld_trig_o),
      .ready_thld_trig_o(rx_desc_ready_thld_trig_o),
      .empty_o(rx_desc_empty_o),
      .wvalid_i(rx_desc_wvalid_i),
      .wready_o(rx_desc_wready_o),
      .wdata_i(rx_desc_wdata_i),
      .req_i(rx_desc_req_i),
      .ack_o(rx_desc_ack_o),
      .data_o(rx_desc_data_o),
      .start_thld_i(rx_desc_start_thld_i),
      .ready_thld_i(rx_desc_ready_thld_i),
      .ready_thld_o(rx_desc_ready_thld_o),
      .reg_rst_i(rx_desc_reg_rst_i),
      .reg_rst_we_o(rx_desc_reg_rst_we_o),
      .reg_rst_data_o(rx_desc_reg_rst_data_o)
  );

  write_queue #(
      .CsrDataWidth(CsrDataWidth),
      .Depth(TxDescFifoDepth),
      .DataWidth(TxDescFifoDataWidth),
      .ThldWidth(TxDescFifoThldWidth),
      .LimitReadyThld(1),
      .ThldIsPow(0)
  ) tx_desc_fifo (
      .clk_i,
      .rst_ni,
      .full_o(tx_desc_full_o),
      .start_thld_trig_o(tx_desc_start_thld_trig_o),
      .ready_thld_trig_o(tx_desc_ready_thld_trig_o),
      .empty_o(tx_desc_empty_o),
      .rvalid_o(tx_desc_rvalid_o),
      .rready_i(tx_desc_rready_i),
      .rdata_o(tx_desc_rdata_o),
      .req_i(tx_desc_req_i),
      .ack_o(tx_desc_ack_o),
      .data_i(tx_desc_data_i),
      .start_thld_i(tx_desc_start_thld_i),
      .ready_thld_i(tx_desc_ready_thld_i),
      .ready_thld_o(tx_desc_ready_thld_o),
      .reg_rst_i(tx_desc_reg_rst_i),
      .reg_rst_we_o(tx_desc_reg_rst_we_o),
      .reg_rst_data_o(tx_desc_reg_rst_data_o)
  );

  read_queue #(
      .Depth(RxFifoDepth),
      .DataWidth(RxFifoDataWidth),
      .ThldWidth(RxFifoThldWidth),
      .LimitReadyThld(0),
      .ThldIsPow(1)
  ) rx_fifo (
      .clk_i,
      .rst_ni,
      .full_o(rx_full_o),
      .start_thld_trig_o(rx_start_thld_trig_o),
      .ready_thld_trig_o(rx_ready_thld_trig_o),
      .empty_o(rx_empty_o),
      .wvalid_i(rx_wvalid_i),
      .wready_o(rx_wready_o),
      .wdata_i(rx_wdata_i),
      .req_i(rx_req_i),
      .ack_o(rx_ack_o),
      .data_o(rx_data_o),
      .start_thld_i(rx_start_thld_i),
      .ready_thld_i(rx_ready_thld_i),
      .ready_thld_o(rx_ready_thld_o),
      .reg_rst_i(rx_reg_rst_i),
      .reg_rst_we_o(rx_reg_rst_we_o),
      .reg_rst_data_o(rx_reg_rst_data_o)
  );

  write_queue #(
      .CsrDataWidth(CsrDataWidth),
      .Depth(TxFifoDepth),
      .DataWidth(TxFifoDataWidth),
      .ThldWidth(TxFifoThldWidth),
      .LimitReadyThld(0),
      .ThldIsPow(1)
  ) tx_fifo (
      .clk_i,
      .rst_ni,
      .full_o(tx_full_o),
      .start_thld_trig_o(tx_start_thld_trig_o),
      .ready_thld_trig_o(tx_ready_thld_trig_o),
      .empty_o(tx_empty_o),
      .rvalid_o(tx_rvalid_o),
      .rready_i(tx_rready_i),
      .rdata_o(tx_rdata_o),
      .req_i(tx_req_i),
      .ack_o(tx_ack_o),
      .data_i(tx_data_i),
      .start_thld_i(tx_start_thld_i),
      .ready_thld_i(tx_ready_thld_i),
      .ready_thld_o(tx_ready_thld_o),
      .reg_rst_i(tx_reg_rst_i),
      .reg_rst_we_o(tx_reg_rst_we_o),
      .reg_rst_data_o(tx_reg_rst_data_o)
  );

endmodule
