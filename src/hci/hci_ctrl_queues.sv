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
    // Command FIFO: status / control
    input  logic                     cmd_fifo_clr_i,
    input  logic [ CmdThldWidth-1:0] cmd_fifo_thld_i,
    output logic [CmdFifoDepthW-1:0] cmd_fifo_depth_o,
    output logic                     cmd_fifo_full_o,
    output logic                     cmd_fifo_apch_thld_o,  // Almost full
    output logic                     cmd_fifo_empty_o,
    // Command FIFO: writes controlled by CSR
    input  logic                     cmd_fifo_wvalid_i,
    output logic                     cmd_fifo_wready_o,
    input  logic [ CmdFifoWidth-1:0] cmd_fifo_wdata_i,
    // Command FIFO: reads controlled by FSM
    output logic                     cmd_fifo_rvalid_o,
    input  logic                     cmd_fifo_rready_i,
    output logic [ CmdFifoWidth-1:0] cmd_fifo_rdata_o,

    // RX FIFO: status / control
    input  logic                    rx_fifo_clr_i,
    input  logic [ RxThldWidth-1:0] rx_fifo_thld_i,
    output logic [RxFifoDepthW-1:0] rx_fifo_depth_o,
    output logic                    rx_fifo_full_o,
    output logic                    rx_fifo_apch_thld_o,  // Reached thld_i entries
    output logic                    rx_fifo_empty_o,
    // RX FIFO: writes controller by FSM
    input  logic                    rx_fifo_wvalid_i,
    output logic                    rx_fifo_wready_o,
    input  logic [ RxFifoWidth-1:0] rx_fifo_wdata_i,
    // RX FIFO: reads controlled by CSR
    output logic                    rx_fifo_rvalid_o,
    input  logic                    rx_fifo_rready_i,
    output logic [ RxFifoWidth-1:0] rx_fifo_rdata_o,

    // TX FIFO: status / control
    input  logic                    tx_fifo_clr_i,
    input  logic [ TxThldWidth-1:0] tx_fifo_thld_i,
    output logic [TxFifoDepthW-1:0] tx_fifo_depth_o,
    output logic                    tx_fifo_full_o,
    output logic                    tx_fifo_apch_thld_o,  // Almost full
    output logic                    tx_fifo_empty_o,
    // TX FIFO: writes controlled by CSR
    input  logic                    tx_fifo_wvalid_i,
    output logic                    tx_fifo_wready_o,
    input  logic [ TxFifoWidth-1:0] tx_fifo_wdata_i,
    // TX FIFO: reads controlled by FSM
    output logic                    tx_fifo_rvalid_o,
    input  logic                    tx_fifo_rready_i,
    output logic [ TxFifoWidth-1:0] tx_fifo_rdata_o,

    // Response FIFO: status / control
    input  logic                      resp_fifo_clr_i,
    input  logic [ RespThldWidth-1:0] resp_fifo_thld_i,
    output logic [RespFifoDepthW-1:0] resp_fifo_depth_o,
    output logic                      resp_fifo_full_o,
    output logic                      resp_fifo_apch_thld_o,  // Reached thld_i entries
    output logic                      resp_fifo_empty_o,
    // Response FIFO: writes controlled by FSM
    input  logic                      resp_fifo_wvalid_i,
    output logic                      resp_fifo_wready_o,
    input  logic [ RespFifoWidth-1:0] resp_fifo_wdata_i,
    // Response FIFO: reads controlled by CSR
    output logic                      resp_fifo_rvalid_o,
    input  logic                      resp_fifo_rready_i,
    output logic [ RespFifoWidth-1:0] resp_fifo_rdata_o
);

  always_comb begin : gen_fifos_status_indicators
    assign cmd_fifo_empty_o = ~|cmd_fifo_depth_o;
    assign rx_fifo_empty_o = ~|rx_fifo_depth_o;
    assign tx_fifo_empty_o = ~|tx_fifo_depth_o;
    assign resp_fifo_empty_o = ~|resp_fifo_depth_o;

    // Queue approached the threshold
    // 'cmd_fifo_apch_thld' is raised when there's at least 'cmd_fifo_thld' empty entries available
    assign cmd_fifo_apch_thld_o = CMD_FIFO_DEPTH - cmd_fifo_depth_o >= cmd_fifo_thld_i;
    // 'rx_fifo_pch_thld' is raised when there's at least '2^(rx_fifo_thld+1)' entries enqueued
    assign rx_fifo_apch_thld_o = rx_fifo_depth_o >= (1 << (rx_fifo_thld_i + 1));
    // 'tx_fifo_apch_thld' is raised when there's at least '2^(tx_fifo_thld+1)' empty entries available
    assign tx_fifo_apch_thld_o = TX_FIFO_DEPTH - tx_fifo_depth_o >= (1 << (tx_fifo_thld_i + 1));
    // 'resp_fifo_apch_thld' is raised when there's at least 'resp_fifo_thld' entries enqueued
    assign resp_fifo_apch_thld_o = resp_fifo_depth_o >= resp_fifo_thld_i;
  end

  caliptra_prim_fifo_sync #(
      .Width(CmdFifoWidth),
      .Pass (1'b0),
      .Depth(CMD_FIFO_DEPTH)
  ) cmd_fifo (
      .clk_i,
      .rst_ni,
      .clr_i   (cmd_fifo_clr_i),
      .wvalid_i(cmd_fifo_wvalid_i),
      .wready_o(cmd_fifo_wready_o),
      .wdata_i (cmd_fifo_wdata_i),
      .depth_o (cmd_fifo_depth_o),
      .rvalid_o(cmd_fifo_rvalid_o),
      .rready_i(cmd_fifo_rready_i),
      .rdata_o (cmd_fifo_rdata_o),
      .full_o  (cmd_fifo_full_o),
      .err_o   ()
  );

  caliptra_prim_fifo_sync #(
      .Width(RxFifoWidth),
      .Pass (1'b0),
      .Depth(RX_FIFO_DEPTH)
  ) rx_fifo (
      .clk_i,
      .rst_ni,
      .clr_i   (rx_fifo_clr_i),
      .wvalid_i(rx_fifo_wvalid_i),
      .wready_o(rx_fifo_wready_o),
      .wdata_i (rx_fifo_wdata_i),
      .depth_o (rx_fifo_depth_o),
      .rvalid_o(rx_fifo_rvalid_o),
      .rready_i(rx_fifo_rready_i),
      .rdata_o (rx_fifo_rdata_o),
      .full_o  (rx_fifo_full_o),
      .err_o   ()
  );

  caliptra_prim_fifo_sync #(
      .Width(TxFifoWidth),
      .Pass (1'b0),
      .Depth(TX_FIFO_DEPTH)
  ) tx_fifo (
      .clk_i,
      .rst_ni,
      .clr_i   (tx_fifo_clr_i),
      .wvalid_i(tx_fifo_wvalid_i),
      .wready_o(tx_fifo_wready_o),
      .wdata_i (tx_fifo_wdata_i),
      .depth_o (tx_fifo_depth_o),
      .rvalid_o(tx_fifo_rvalid_o),
      .rready_i(tx_fifo_rready_i),
      .rdata_o (tx_fifo_rdata_o),
      .full_o  (tx_fifo_full_o),
      .err_o   ()
  );

  caliptra_prim_fifo_sync #(
      .Width(RespFifoWidth),
      .Pass (1'b0),
      .Depth(RESP_FIFO_DEPTH)
  ) resp_fifo (
      .clk_i,
      .rst_ni,
      .clr_i   (resp_fifo_clr_i),
      .wvalid_i(resp_fifo_wvalid_i),
      .wready_o(resp_fifo_wready_o),
      .wdata_i (resp_fifo_wdata_i),
      .depth_o (resp_fifo_depth_o),
      .rvalid_o(resp_fifo_rvalid_o),
      .rready_i(resp_fifo_rready_i),
      .rdata_o (resp_fifo_rdata_o),
      .full_o  (resp_fifo_full_o),
      .err_o   ()
  );

endmodule
