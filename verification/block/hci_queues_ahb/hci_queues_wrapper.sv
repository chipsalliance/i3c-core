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
    // Response queue
    output logic [HciRespThldWidth-1:0] resp_queue_thld_o,
    output logic resp_queue_full_o,
    output logic resp_queue_above_thld_o,
    output logic resp_queue_empty_o,
    input logic resp_queue_wvalid_i,
    output logic resp_queue_wready_o,
    input logic [HciRespDataWidth-1:0] resp_queue_wdata_i,

    // Command queue
    output logic [HciCmdThldWidth-1:0] cmd_queue_thld_o,
    output logic cmd_queue_full_o,
    output logic cmd_queue_below_thld_o,
    output logic cmd_queue_empty_o,
    output logic cmd_queue_rvalid_o,
    input logic cmd_queue_rready_i,
    output logic [HciCmdDataWidth-1:0] cmd_queue_rdata_o,

    // RX queue
    output logic [HciRxThldWidth-1:0] rx_queue_thld_o,
    output logic rx_queue_full_o,
    output logic rx_queue_above_thld_o,
    output logic rx_queue_empty_o,
    input logic rx_queue_wvalid_i,
    output logic rx_queue_wready_o,
    input logic [HciRxDataWidth-1:0] rx_queue_wdata_i,

    // TX queue
    output logic [HciTxThldWidth-1:0] tx_queue_thld_o,
    output logic tx_queue_full_o,
    output logic tx_queue_below_thld_o,
    output logic tx_queue_empty_o,
    output logic tx_queue_rvalid_o,
    input logic tx_queue_rready_i,
    output logic [HciTxDataWidth-1:0] tx_queue_rdata_o,

    // Target Transaction Interface
    // RX descriptors queue
    output logic tti_rx_desc_queue_full_o,
    output logic [TtiTxDescThldWidth-1:0] tti_rx_desc_queue_thld_o,
    output logic tti_rx_desc_queue_above_thld_o,
    output logic tti_rx_desc_queue_empty_o,
    input logic tti_rx_desc_queue_wvalid_i,
    output logic tti_rx_desc_queue_wready_o,
    input logic [TtiTxDescDataWidth-1:0] tti_rx_desc_queue_wdata_i,

    // TX descriptors queue
    output logic tti_tx_desc_queue_full_o,
    output logic [TtiRxDescThldWidth-1:0] tti_tx_desc_queue_thld_o,
    output logic tti_tx_desc_queue_below_thld_o,
    output logic tti_tx_desc_queue_empty_o,
    output logic tti_tx_desc_queue_rvalid_o,
    input logic tti_tx_desc_queue_rready_i,
    output logic [TtiRxDescDataWidth-1:0] tti_tx_desc_queue_rdata_o,

    // RX queue
    output logic tti_rx_queue_full_o,
    output logic [TtiRxThldWidth-1:0] tti_rx_queue_thld_o,
    output logic tti_rx_queue_above_thld_o,
    output logic tti_rx_queue_empty_o,
    input logic tti_rx_queue_wvalid_i,
    output logic tti_rx_queue_wready_o,
    input logic [TtiRxDataWidth-1:0] tti_rx_queue_wdata_i,

    // TX queue
    output logic tti_tx_queue_full_o,
    output logic [TtiTxThldWidth-1:0] tti_tx_queue_thld_o,
    output logic tti_tx_queue_below_thld_o,
    output logic tti_tx_queue_empty_o,
    output logic tti_tx_queue_rvalid_o,
    input logic tti_tx_queue_rready_i,
    output logic [TtiTxDataWidth-1:0] tti_tx_queue_rdata_o
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

      // HCI Response queue
      .hci_resp_full_o(resp_queue_full_o),
      .hci_resp_thld_o(resp_queue_thld_o),
      .hci_resp_above_thld_o(resp_queue_above_thld_o),
      .hci_resp_empty_o(resp_queue_empty_o),
      .hci_resp_wvalid_i(resp_queue_wvalid_i),
      .hci_resp_wready_o(resp_queue_wready_o),
      .hci_resp_wdata_i(resp_queue_wdata_i),

      // HCI Command queue
      .hci_cmd_full_o(cmd_queue_full_o),
      .hci_cmd_thld_o(cmd_queue_thld_o),
      .hci_cmd_below_thld_o(cmd_queue_below_thld_o),
      .hci_cmd_empty_o(cmd_queue_empty_o),
      .hci_cmd_rvalid_o(cmd_queue_rvalid_o),
      .hci_cmd_rready_i(cmd_queue_rready_i),
      .hci_cmd_rdata_o(cmd_queue_rdata_o),

      // HCI RX queue
      .hci_rx_full_o(rx_queue_full_o),
      .hci_rx_thld_o(rx_queue_thld_o),
      .hci_rx_above_thld_o(rx_queue_above_thld_o),
      .hci_rx_empty_o(rx_queue_empty_o),
      .hci_rx_wvalid_i(rx_queue_wvalid_i),
      .hci_rx_wready_o(rx_queue_wready_o),
      .hci_rx_wdata_i(rx_queue_wdata_i),

      // HCI TX queue
      .hci_tx_full_o(tx_queue_full_o),
      .hci_tx_thld_o(tx_queue_thld_o),
      .hci_tx_below_thld_o(tx_queue_below_thld_o),
      .hci_tx_empty_o(tx_queue_empty_o),
      .hci_tx_rvalid_o(tx_queue_rvalid_o),
      .hci_tx_rready_i(tx_queue_rready_i),
      .hci_tx_rdata_o(tx_queue_rdata_o),

      // TTI RX descriptors queue
      .tti_rx_desc_queue_full_o(tti_rx_desc_queue_full_o),
      .tti_rx_desc_queue_thld_o(tti_rx_desc_queue_thld_o),
      .tti_rx_desc_queue_above_thld_o(tti_rx_desc_queue_above_thld_o),
      .tti_rx_desc_queue_empty_o(tti_rx_desc_queue_empty_o),
      .tti_rx_desc_queue_wvalid_i(tti_rx_desc_queue_wvalid_i),
      .tti_rx_desc_queue_wready_o(tti_rx_desc_queue_wready_o),
      .tti_rx_desc_queue_wdata_i(tti_rx_desc_queue_wdata_i),

      // TTI TX descriptors queue
      .tti_tx_desc_queue_full_o(tti_tx_desc_queue_full_o),
      .tti_tx_desc_queue_thld_o(tti_tx_desc_queue_thld_o),
      .tti_tx_desc_queue_below_thld_o(tti_tx_desc_queue_below_thld_o),
      .tti_tx_desc_queue_empty_o(tti_tx_desc_queue_empty_o),
      .tti_tx_desc_queue_rvalid_o(tti_tx_desc_queue_rvalid_o),
      .tti_tx_desc_queue_rready_i(tti_tx_desc_queue_rready_i),
      .tti_tx_desc_queue_rdata_o(tti_tx_desc_queue_rdata_o),

      // TTI RX queue
      .tti_rx_queue_full_o(tti_rx_queue_full_o),
      .tti_rx_queue_thld_o(tti_rx_queue_thld_o),
      .tti_rx_queue_above_thld_o(tti_rx_queue_above_thld_o),
      .tti_rx_queue_empty_o(tti_rx_queue_empty_o),
      .tti_rx_queue_wvalid_i(tti_rx_queue_wvalid_i),
      .tti_rx_queue_wready_o(tti_rx_queue_wready_o),
      .tti_rx_queue_wdata_i(tti_rx_queue_wdata_i),

      // TTI TX queue
      .tti_tx_queue_full_o(tti_tx_queue_full_o),
      .tti_tx_queue_thld_o(tti_tx_queue_thld_o),
      .tti_tx_queue_below_thld_o(tti_tx_queue_below_thld_o),
      .tti_tx_queue_empty_o(tti_tx_queue_empty_o),
      .tti_tx_queue_rvalid_o(tti_tx_queue_rvalid_o),
      .tti_tx_queue_rready_i(tti_tx_queue_rready_i),
      .tti_tx_queue_rdata_o(tti_tx_queue_rdata_o)
  );
endmodule
