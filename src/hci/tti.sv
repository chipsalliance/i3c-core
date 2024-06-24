// SPDX-License-Identifier: Apache-2.0

// I3C Target Transaction Interface
module tti
  import I3CCSR_pkg::*;
  import i3c_pkg::*;
  import hci_pkg::*;
(
    input clk_i,  // clock
    input rst_ni, // active low reset

    // I3C CSR access interface
    input I3CCSR__out_t hwif_out_i,

    // RX descriptors queue
    output logic rx_desc_queue_full_o,
    output logic [TtiRxDescThldWidth-1:0] rx_desc_queue_thld_o,
    output logic rx_desc_queue_above_thld_o,
    output logic rx_desc_queue_empty_o,
    input logic rx_desc_queue_wvalid_i,
    output logic rx_desc_queue_wready_o,
    input logic [TtiRxDescDataWidth-1:0] rx_desc_queue_wdata_i,
    output logic rx_desc_queue_rd_ack_o,
    output logic [TtiRxDescDataWidth-1:0] rx_desc_queue_rd_data_o,

    // RX queue
    output logic rx_queue_full_o,
    output logic [TtiRxThldWidth-1:0] rx_queue_thld_o,
    output logic rx_queue_above_thld_o,
    output logic rx_queue_empty_o,
    input logic rx_queue_wvalid_i,
    output logic rx_queue_wready_o,
    input logic [TtiRxDataWidth-1:0] rx_queue_wdata_i,
    output logic rx_queue_rd_ack_o,
    output logic [TtiRxDataWidth-1:0] rx_queue_rd_data_o,

    // TX descriptors queue
    output logic tx_desc_queue_full_o,
    output logic [TtiTxDescThldWidth-1:0] tx_desc_queue_thld_o,
    output logic tx_desc_queue_below_thld_o,
    output logic tx_desc_queue_empty_o,
    output logic tx_desc_queue_rvalid_o,
    input logic tx_desc_queue_rready_i,
    output logic [TtiTxDescDataWidth-1:0] tx_desc_queue_rdata_o,
    output logic tx_desc_queue_wr_ack_o,

    // TX queue
    output logic tx_queue_full_o,
    output logic [TtiTxThldWidth-1:0] tx_queue_thld_o,
    output logic tx_queue_below_thld_o,
    output logic tx_queue_empty_o,
    output logic tx_queue_rvalid_o,
    input logic tx_queue_rready_i,
    output logic [TtiTxDataWidth-1:0] tx_queue_rdata_o,
    output logic tx_queue_wr_ack_o
);
  // TTI queues thresholds
  logic [TtiTxDescThldWidth-1:0] rx_desc_queue_thld;
  logic [TtiRxDescThldWidth-1:0] tx_desc_queue_thld;
  logic [TtiRxThldWidth-1:0] rx_queue_thld;
  logic [TtiTxThldWidth-1:0] tx_queue_thld;

  // TTI queues port control
  logic rx_desc_queue_req;

  logic tx_desc_queue_req;
  logic tx_desc_queue_req_is_wr;
  logic [TtiTxDescDataWidth-1:0] tx_desc_queue_wr_data;

  logic rx_queue_req;
  logic [TtiRxDataWidth-1:0] rx_queue_rd_data;

  logic tx_queue_req;
  logic tx_queue_req_is_wr;
  logic [TtiTxDataWidth-1:0] tx_queue_wr_data;

  // TODO: Connect queue soft resets

  always_comb begin : wire_hwif_thld
    rx_desc_queue_thld = hwif_out_i.I3C_EC.TTI.QUEUE_THRESHOLD_CONTROL.RX_DESC_THLD.value;
    tx_desc_queue_thld = hwif_out_i.I3C_EC.TTI.QUEUE_THRESHOLD_CONTROL.TX_DESC_THLD.value;
    rx_queue_thld = hwif_out_i.I3C_EC.TTI.QUEUE_THRESHOLD_CONTROL.RX_DATA_THLD.value;
    tx_queue_thld = hwif_out_i.I3C_EC.TTI.QUEUE_THRESHOLD_CONTROL.TX_DATA_THLD.value;
  end : wire_hwif_thld

  always_comb begin : wire_hwif_xfer
    rx_desc_queue_req = hwif_out_i.I3C_EC.TTI.RX_DESC_QUEUE_PORT.req;

    tx_desc_queue_req = hwif_out_i.I3C_EC.TTI.TX_DESC_QUEUE_PORT.req;
    tx_desc_queue_req_is_wr = hwif_out_i.I3C_EC.TTI.TX_DESC_QUEUE_PORT.req_is_wr;
    tx_desc_queue_wr_data = hwif_out_i.I3C_EC.TTI.TX_DESC_QUEUE_PORT.wr_data;

    rx_queue_req = hwif_out_i.I3C_EC.TTI.RX_DATA_PORT.req;

    tx_queue_req = hwif_out_i.I3C_EC.TTI.TX_DATA_PORT.req;
    tx_queue_req_is_wr = hwif_out_i.I3C_EC.TTI.TX_DATA_PORT.req_is_wr;
    tx_queue_wr_data = hwif_out_i.I3C_EC.TTI.TX_DATA_PORT.wr_data;
  end : wire_hwif_xfer

  queues #(
      .RX_DESC_FIFO_DEPTH(`RESP_FIFO_DEPTH),
      .TX_DESC_FIFO_DEPTH(`CMD_FIFO_DEPTH),
      .RX_FIFO_DEPTH(`RX_FIFO_DEPTH),
      .TX_FIFO_DEPTH(`TX_FIFO_DEPTH),

      .RX_DESC_FIFO_DATA_WIDTH(TtiRxDescDataWidth),
      .TX_DESC_FIFO_DATA_WIDTH(TtiTxDescDataWidth),
      .RX_FIFO_DATA_WIDTH(TtiRxDataWidth),
      .TX_FIFO_DATA_WIDTH(TtiTxDataWidth),

      .RX_DESC_THLD_WIDTH(TtiRxDescThldWidth),
      .TX_DESC_THLD_WIDTH(TtiTxDescThldWidth),
      .TX_THLD_WIDTH(TtiTxThldWidth),
      .RX_THLD_WIDTH(TtiRxThldWidth)
  ) tti_queues (
      .clk_i,
      .rst_ni,

      .rx_desc_full_o(rx_desc_queue_full_o),
      .rx_desc_above_thld_o(rx_desc_queue_above_thld_o),
      .rx_desc_empty_o(rx_desc_queue_empty_o),
      .rx_desc_wvalid_i(rx_desc_queue_wvalid_i),
      .rx_desc_wready_o(rx_desc_queue_wready_o),
      .rx_desc_wdata_i(rx_desc_queue_wdata_i),
      .rx_desc_req_i(rx_desc_queue_req),
      .rx_desc_ack_o(rx_desc_queue_rd_ack_o),
      .rx_desc_data_o(rx_desc_queue_rd_data_o),
      .rx_desc_thld_i(rx_desc_queue_thld),
      .rx_desc_thld_o(rx_desc_queue_thld_o),
      .rx_desc_reg_rst_i('0),
      .rx_desc_reg_rst_we_o(),
      .rx_desc_reg_rst_data_o(),

      .tx_desc_full_o(tx_desc_queue_full_o),
      .tx_desc_below_thld_o(tx_desc_queue_below_thld_o),
      .tx_desc_empty_o(tx_desc_queue_empty_o),
      .tx_desc_rvalid_o(tx_desc_queue_rvalid_o),
      .tx_desc_rready_i(tx_desc_queue_rready_i),
      .tx_desc_rdata_o(tx_desc_queue_rdata_o),
      .tx_desc_req_i(tx_desc_queue_req),
      .tx_desc_ack_o(tx_desc_queue_wr_ack_o),
      .tx_desc_data_i(tx_desc_queue_wr_data),
      .tx_desc_thld_i(tx_desc_queue_thld),
      .tx_desc_thld_o(tx_desc_queue_thld_o),
      .tx_desc_reg_rst_i('0),
      .tx_desc_reg_rst_we_o(),
      .tx_desc_reg_rst_data_o(),

      .rx_full_o(rx_queue_full_o),
      .rx_above_thld_o(rx_queue_above_thld_o),
      .rx_empty_o(rx_queue_empty_o),
      .rx_wvalid_i(rx_queue_wvalid_i),
      .rx_wready_o(rx_queue_wready_o),
      .rx_wdata_i(rx_queue_wdata_i),
      .rx_req_i(rx_queue_req),
      .rx_ack_o(rx_queue_rd_ack_o),
      .rx_data_o(rx_queue_rd_data_o),
      .rx_thld_i(rx_queue_thld),
      .rx_thld_o(rx_queue_thld_o),
      .rx_reg_rst_i('0),
      .rx_reg_rst_we_o(),
      .rx_reg_rst_data_o(),

      .tx_full_o(tx_queue_full_o),
      .tx_below_thld_o(tx_queue_below_thld_o),
      .tx_empty_o(tx_queue_empty_o),
      .tx_rvalid_o(tx_queue_rvalid_o),
      .tx_rready_i(tx_queue_rready_i),
      .tx_rdata_o(tx_queue_rdata_o),
      .tx_req_i(tx_queue_req),
      .tx_ack_o(tx_queue_wr_ack_o),
      .tx_data_i(tx_queue_wr_data),
      .tx_thld_i(tx_queue_thld),
      .tx_thld_o(tx_queue_thld_o),
      .tx_reg_rst_i('0),
      .tx_reg_rst_we_o(),
      .tx_reg_rst_data_o()
  );
endmodule : tti
