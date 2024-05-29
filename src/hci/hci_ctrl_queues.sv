// SPDX-License-Identifier: Apache-2.0

module hci_ctrl_queues
  import hci_pkg::*;
#(
    parameter int unsigned CMD_FIFO_DEPTH = 64,
    parameter int unsigned RESP_FIFO_DEPTH = 256,
    parameter int unsigned RX_FIFO_DEPTH = 64,
    parameter int unsigned TX_FIFO_DEPTH = 64,
    // HCI queues' depth widths
    localparam int unsigned CmdFifoDepthW = $clog2(CMD_FIFO_DEPTH + 1),
    localparam int unsigned RxFifoDepthW = $clog2(RX_FIFO_DEPTH + 1),
    localparam int unsigned TxFifoDepthW = $clog2(TX_FIFO_DEPTH + 1),
    localparam int unsigned RespFifoDepthW = $clog2(RESP_FIFO_DEPTH + 1)
) (
    input logic clk_i,
    input logic rst_ni,

    // TODO: Ensure if the _depth_o need to be exposed
    // Direct FIFO read control
    output logic cmd_full_o,
    output logic cmd_below_thld_o,
    output logic cmd_empty_o,
    output logic cmd_rvalid_o,
    input logic cmd_rready_i,
    output logic [CmdFifoWidth-1:0] cmd_rdata_o,
    input logic cmd_req_i,
    output logic cmd_ack_o,
    input logic [CmdFifoWidth-1:0] cmd_data_i,
    input logic [CmdThldWidth-1:0] cmd_thld_i,
    output logic [CmdThldWidth-1:0] cmd_thld_o,
    input logic cmd_reg_rst_i,
    output logic cmd_reg_rst_we_o,
    output logic cmd_reg_rst_data_o,

    // RX FIFO
    output logic rx_full_o,
    output logic rx_above_thld_o,
    output logic rx_empty_o,
    input logic rx_wvalid_i,
    output logic rx_wready_o,
    input logic [RxFifoWidth-1:0] rx_wdata_i,
    input logic rx_req_i,
    output logic rx_ack_o,
    output logic [RxFifoWidth-1:0] rx_data_o,
    input logic [RxThldWidth-1:0] rx_thld_i,
    output logic [RxThldWidth-1:0] rx_thld_o,
    input logic rx_reg_rst_i,
    output logic rx_reg_rst_we_o,
    output logic rx_reg_rst_data_o,

    // TX FIFO: status / control
    output logic tx_full_o,
    output logic tx_below_thld_o,
    output logic tx_empty_o,
    output logic tx_rvalid_o,
    input logic tx_rready_i,
    output logic [TxFifoWidth-1:0] tx_rdata_o,
    input logic tx_req_i,
    output logic tx_ack_o,
    input logic [TxFifoWidth-1:0] tx_data_i,
    input logic [TxThldWidth-1:0] tx_thld_i,
    output logic [TxThldWidth-1:0] tx_thld_o,
    input logic tx_reg_rst_i,
    output logic tx_reg_rst_we_o,
    output logic tx_reg_rst_data_o,

    // Response FIFO: status / control
    output logic resp_full_o,
    output logic resp_above_thld_o,
    output logic resp_empty_o,
    input logic resp_wvalid_i,
    output logic resp_wready_o,
    input logic [RespFifoWidth-1:0] resp_wdata_i,
    input logic resp_req_i,
    output logic resp_ack_o,
    output logic [RespFifoWidth-1:0] resp_data_o,
    input logic [RespThldWidth-1:0] resp_thld_i,
    output logic [RespThldWidth-1:0] resp_thld_o,
    input logic resp_reg_rst_i,
    output logic resp_reg_rst_we_o,
    output logic resp_reg_rst_data_o
);

  write_queue #(
      .DEPTH(CMD_FIFO_DEPTH),
      .DATA_WIDTH(CmdFifoWidth),
      .THLD_WIDTH(CmdThldWidth),
      .THLD_IS_POW(0)
  ) cmd_fifo (
      .clk_i,
      .rst_ni,
      .full_o(cmd_full_o),
      .below_thld_o(cmd_below_thld_o),
      .empty_o(cmd_empty_o),
      .rvalid_o(cmd_rvalid_o),
      .rready_i(cmd_rready_i),
      .rdata_o(cmd_rdata_o),
      .req_i(cmd_req_i),
      .ack_o(cmd_ack_o),
      .data_i(cmd_data_i),
      .thld_i(cmd_thld_i),
      .thld_o(cmd_thld_o),
      .reg_rst_i(cmd_reg_rst_i),
      .reg_rst_we_o(cmd_reg_rst_we_o),
      .reg_rst_data_o(cmd_reg_rst_data_o)
  );

  read_queue #(
      .DEPTH(RX_FIFO_DEPTH),
      .DATA_WIDTH(RxFifoWidth),
      .THLD_WIDTH(RxThldWidth),
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
      .DATA_WIDTH(TxFifoWidth),
      .THLD_WIDTH(TxThldWidth),
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

  read_queue #(
      .DEPTH(RESP_FIFO_DEPTH),
      .DATA_WIDTH(RespFifoWidth),
      .THLD_WIDTH(RespThldWidth),
      .THLD_IS_POW(0)
  ) resp_fifo (
      .clk_i,
      .rst_ni,
      .full_o(resp_full_o),
      .above_thld_o(resp_above_thld_o),
      .empty_o(resp_empty_o),
      .wvalid_i(resp_wvalid_i),
      .wready_o(resp_wready_o),
      .wdata_i(resp_wdata_i),
      .req_i(resp_req_i),
      .ack_o(resp_ack_o),
      .data_o(resp_data_o),
      .thld_i(resp_thld_i),
      .thld_o(resp_thld_o),
      .reg_rst_i(resp_reg_rst_i),
      .reg_rst_we_o(resp_reg_rst_we_o),
      .reg_rst_data_o(resp_reg_rst_data_o)
  );

endmodule
