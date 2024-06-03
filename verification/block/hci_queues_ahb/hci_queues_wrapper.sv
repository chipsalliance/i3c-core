// SPDX-License-Identifier: Apache-2.0

module hci_queues_wrapper
  import i3c_pkg::*;
  import hci_pkg::*;
  import I3CCSR_pkg::I3CCSR_DATA_WIDTH;
  import I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
(
    input hclk,  // clock
    input hreset_n,  // active low reset

    // AHB-Lite interface
    input logic [`AHB_ADDR_WIDTH-1:0] haddr,
    input logic [2:0] hburst,
    input logic [3:0] hprot,
    input logic [2:0] hsize,
    input logic [1:0] htrans,
    input logic [`AHB_DATA_WIDTH-1:0] hwdata,
    input logic [`AHB_DATA_WIDTH/8-1:0] hwstrb,
    input logic hwrite,
    output logic [`AHB_DATA_WIDTH-1:0] hrdata,
    output logic hreadyout,
    output logic hresp,
    input logic hsel,
    input logic hready,

    // HCI queues (FSM side)
    // Command FIFO
    output logic [CmdThldWidth-1:0] cmd_fifo_thld_o,
    output logic cmd_fifo_full_o,
    output logic cmd_fifo_apch_thld_o,
    output logic cmd_fifo_empty_o,
    output logic cmd_fifo_rvalid_o,
    input logic cmd_fifo_rready_i,
    output logic [CmdFifoWidth-1:0] cmd_fifo_rdata_o,
    // RX FIFO
    output logic [RxThldWidth-1:0] rx_fifo_thld_o,
    output logic rx_fifo_full_o,
    output logic rx_fifo_apch_thld_o,
    output logic rx_fifo_empty_o,
    input logic rx_fifo_wvalid_i,
    output logic rx_fifo_wready_o,
    input logic [RxFifoWidth-1:0] rx_fifo_wdata_i,
    // TX FIFO
    output logic [TxThldWidth-1:0] tx_fifo_thld_o,
    output logic tx_fifo_full_o,
    output logic tx_fifo_apch_thld_o,
    output logic tx_fifo_empty_o,
    output logic tx_fifo_rvalid_o,
    input logic tx_fifo_rready_i,
    output logic [TxFifoWidth-1:0] tx_fifo_rdata_o,
    // Response FIFO
    output logic [RespThldWidth-1:0] resp_fifo_thld_o,
    output logic resp_fifo_full_o,
    output logic resp_fifo_apch_thld_o,
    output logic resp_fifo_empty_o,
    input logic resp_fifo_wvalid_i,
    output logic resp_fifo_wready_o,
    input logic [RespFifoWidth-1:0] resp_fifo_wdata_i
);
  // HCI queues' depth widths
  localparam int unsigned CmdFifoDepthW = $clog2(`CMD_FIFO_DEPTH + 1);
  localparam int unsigned RxFifoDepthW = $clog2(`RX_FIFO_DEPTH + 1);
  localparam int unsigned TxFifoDepthW = $clog2(`TX_FIFO_DEPTH + 1);
  localparam int unsigned RespFifoDepthW = $clog2(`RESP_FIFO_DEPTH + 1);

  // I3C SW CSR IF
  logic s_cpuif_req;
  logic s_cpuif_req_is_wr;
  logic [I3CCSR_MIN_ADDR_WIDTH-1:0] s_cpuif_addr;
  logic [I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_data;
  logic [I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_biten;
  logic s_cpuif_req_stall_wr;
  logic s_cpuif_req_stall_rd;
  logic s_cpuif_rd_ack;
  logic s_cpuif_rd_err;
  logic [I3CCSR_DATA_WIDTH-1:0] s_cpuif_rd_data;
  logic s_cpuif_wr_ack;
  logic s_cpuif_wr_err;

  // Command queue
  logic cmdrst;
  logic [CmdFifoDepthW-1:0] cmd_fifo_depth;
  logic cmd_fifo_wvalid;
  logic cmd_fifo_wready;
  logic [CmdFifoWidth-1:0] cmd_fifo_wdata;

  // RX queue
  logic rxrst;
  logic [RxFifoDepthW-1:0] rx_fifo_depth;
  logic rx_fifo_rvalid;
  logic rx_fifo_rready;
  logic [RxFifoWidth-1:0] rx_fifo_rdata;

  // TX queue
  logic txrst;
  logic [TxFifoDepthW-1:0] tx_fifo_depth;
  logic tx_fifo_wvalid;
  logic tx_fifo_wready;
  logic [TxFifoWidth-1:0] tx_fifo_wdata;

  // Response queue
  logic resprst;
  logic [RespFifoDepthW-1:0] resp_fifo_depth;
  logic resp_fifo_rvalid;
  logic resp_fifo_rready;
  logic [RespFifoWidth-1:0] resp_fifo_rdata;

  ahb_if #(
      .AHB_DATA_WIDTH(`AHB_DATA_WIDTH),
      .AHB_ADDR_WIDTH(`AHB_ADDR_WIDTH)
  ) i3c_ahb_if (
      .hclk_i(hclk),
      .hreset_n_i(hreset_n),
      .haddr_i(haddr),
      .hburst_i(hburst),
      .hprot_i(hprot),
      .hsize_i(hsize),
      .htrans_i(htrans),
      .hwdata_i(hwdata),
      .hwstrb_i(hwstrb),
      .hwrite_i(hwrite),
      .hrdata_o(hrdata),
      .hreadyout_o(hreadyout),
      .hresp_o(hresp),
      .hsel_i(hsel),
      .hready_i(hready),
      .s_cpuif_req(s_cpuif_req),
      .s_cpuif_req_is_wr(s_cpuif_req_is_wr),
      .s_cpuif_addr(s_cpuif_addr),
      .s_cpuif_wr_data(s_cpuif_wr_data),
      .s_cpuif_wr_biten(s_cpuif_wr_biten),
      .s_cpuif_req_stall_wr(s_cpuif_req_stall_wr),
      .s_cpuif_req_stall_rd(s_cpuif_req_stall_rd),
      .s_cpuif_rd_ack(s_cpuif_rd_ack),
      .s_cpuif_rd_err(s_cpuif_rd_err),
      .s_cpuif_rd_data(s_cpuif_rd_data),
      .s_cpuif_wr_ack(s_cpuif_wr_ack),
      .s_cpuif_wr_err(s_cpuif_wr_err)
  );

  hci hci (
      .clk_i(hclk),
      .rst_ni(hreset_n),
      .s_cpuif_req(s_cpuif_req),
      .s_cpuif_req_is_wr(s_cpuif_req_is_wr),
      .s_cpuif_addr(s_cpuif_addr),
      .s_cpuif_wr_data(s_cpuif_wr_data),
      .s_cpuif_wr_biten(s_cpuif_wr_biten),
      .s_cpuif_req_stall_wr(s_cpuif_req_stall_wr),
      .s_cpuif_req_stall_rd(s_cpuif_req_stall_rd),
      .s_cpuif_rd_ack(s_cpuif_rd_ack),
      .s_cpuif_rd_err(s_cpuif_rd_err),
      .s_cpuif_rd_data(s_cpuif_rd_data),
      .s_cpuif_wr_ack(s_cpuif_wr_ack),
      .s_cpuif_wr_err(s_cpuif_wr_err),

      // Command queue
      .cmdrst(cmdrst),
      .cmd_fifo_thld_o(cmd_fifo_thld_o),
      .cmd_fifo_empty_i(cmd_fifo_empty_o),
      .cmd_fifo_wvalid_o(cmd_fifo_wvalid),
      .cmd_fifo_wready_i(cmd_fifo_wready),
      .cmd_fifo_wdata_o(cmd_fifo_wdata),

      // RX queue
      .rxrst(rxrst),
      .rx_fifo_thld_o(rx_fifo_thld_o),
      .rx_fifo_empty_i(rx_fifo_empty_o),
      .rx_fifo_rvalid_i(rx_fifo_rvalid),
      .rx_fifo_rready_o(rx_fifo_rready),
      .rx_fifo_rdata_i(rx_fifo_rdata),

      // TX queue
      .txrst(txrst),
      .tx_fifo_thld_o(tx_fifo_thld_o),
      .tx_fifo_empty_i(tx_fifo_empty_o),
      .tx_fifo_wvalid_o(tx_fifo_wvalid),
      .tx_fifo_wready_i(tx_fifo_wready),
      .tx_fifo_wdata_o(tx_fifo_wdata),

      // Response queue
      .resprst(resprst),
      .resp_fifo_thld_o(resp_fifo_thld_o),
      .resp_fifo_empty_i(resp_fifo_empty_o),
      .resp_fifo_rvalid_i(resp_fifo_rvalid),
      .resp_fifo_rready_o(resp_fifo_rready),
      .resp_fifo_rdata_i(resp_fifo_rdata)
  );

  // HCI queues
  hci_ctrl_queues #(
      .CMD_FIFO_DEPTH (`CMD_FIFO_DEPTH),
      .RESP_FIFO_DEPTH(`RESP_FIFO_DEPTH),
      .RX_FIFO_DEPTH  (`RX_FIFO_DEPTH),
      .TX_FIFO_DEPTH  (`TX_FIFO_DEPTH)
  ) hci_ctrl_queues (
      .clk_i (hclk),
      .rst_ni(hreset_n),

      .cmd_fifo_clr_i   (cmdrst),
      .cmd_fifo_thld_i  (cmd_fifo_thld_o),
      .cmd_fifo_depth_o (cmd_fifo_depth),
      .cmd_fifo_full_o  (cmd_fifo_full_o),
      .cmd_fifo_apch_thld_o(cmd_fifo_apch_thld_o),
      .cmd_fifo_empty_o (cmd_fifo_empty_o),
      .cmd_fifo_wvalid_i(cmd_fifo_wvalid),
      .cmd_fifo_wready_o(cmd_fifo_wready),
      .cmd_fifo_wdata_i (cmd_fifo_wdata),
      .cmd_fifo_rvalid_o(cmd_fifo_rvalid_o),
      .cmd_fifo_rready_i(cmd_fifo_rready_i),
      .cmd_fifo_rdata_o (cmd_fifo_rdata_o),

      .rx_fifo_clr_i   (rxrst),
      .rx_fifo_thld_i  (rx_fifo_thld_o),
      .rx_fifo_depth_o (rx_fifo_depth),
      .rx_fifo_full_o  (rx_fifo_full_o),
      .rx_fifo_apch_thld_o(rx_fifo_apch_thld_o),
      .rx_fifo_empty_o (rx_fifo_empty_o),
      .rx_fifo_wvalid_i(rx_fifo_wvalid_i),
      .rx_fifo_wready_o(rx_fifo_wready_o),
      .rx_fifo_wdata_i (rx_fifo_wdata_i),
      .rx_fifo_rvalid_o(rx_fifo_rvalid),
      .rx_fifo_rready_i(rx_fifo_rready),
      .rx_fifo_rdata_o (rx_fifo_rdata),

      .tx_fifo_clr_i   (txrst),
      .tx_fifo_thld_i  (tx_fifo_thld_o),
      .tx_fifo_depth_o (tx_fifo_depth),
      .tx_fifo_full_o  (tx_fifo_full_o),
      .tx_fifo_apch_thld_o(tx_fifo_apch_thld_o),
      .tx_fifo_empty_o (tx_fifo_empty_o),
      .tx_fifo_wvalid_i(tx_fifo_wvalid),
      .tx_fifo_wready_o(tx_fifo_wready),
      .tx_fifo_wdata_i (tx_fifo_wdata),
      .tx_fifo_rvalid_o(tx_fifo_rvalid_o),
      .tx_fifo_rready_i(tx_fifo_rready_i),
      .tx_fifo_rdata_o (tx_fifo_rdata_o),

      .resp_fifo_clr_i   (resprst),
      .resp_fifo_thld_i  (resp_fifo_thld_o),
      .resp_fifo_depth_o (resp_fifo_depth),
      .resp_fifo_full_o  (resp_fifo_full_o),
      .resp_fifo_apch_thld_o(resp_fifo_apch_thld_o),
      .resp_fifo_empty_o (resp_fifo_empty_o),
      .resp_fifo_wvalid_i(resp_fifo_wvalid_i),
      .resp_fifo_wready_o(resp_fifo_wready_o),
      .resp_fifo_wdata_i (resp_fifo_wdata_i),
      .resp_fifo_rvalid_o(resp_fifo_rvalid),
      .resp_fifo_rready_i(resp_fifo_rready),
      .resp_fifo_rdata_o (resp_fifo_rdata)
  );
endmodule
