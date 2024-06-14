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
    output logic [CmdThldWidth-1:0] cmd_queue_thld_o,
    output logic cmd_queue_full_o,
    output logic cmd_queue_below_thld_o,
    output logic cmd_queue_empty_o,
    output logic cmd_queue_rvalid_o,
    input logic cmd_queue_rready_i,
    output logic [CmdFifoWidth-1:0] cmd_queue_rdata_o,
    // RX FIFO
    output logic [RxThldWidth-1:0] rx_queue_thld_o,
    output logic rx_queue_full_o,
    output logic rx_queue_above_thld_o,
    output logic rx_queue_empty_o,
    input logic rx_queue_wvalid_i,
    output logic rx_queue_wready_o,
    input logic [RxFifoWidth-1:0] rx_queue_wdata_i,
    // TX FIFO
    output logic [TxThldWidth-1:0] tx_queue_thld_o,
    output logic tx_queue_full_o,
    output logic tx_queue_below_thld_o,
    output logic tx_queue_empty_o,
    output logic tx_queue_rvalid_o,
    input logic tx_queue_rready_i,
    output logic [TxFifoWidth-1:0] tx_queue_rdata_o,
    // Response FIFO
    output logic [RespThldWidth-1:0] resp_queue_thld_o,
    output logic resp_queue_full_o,
    output logic resp_queue_above_thld_o,
    output logic resp_queue_empty_o,
    input logic resp_queue_wvalid_i,
    output logic resp_queue_wready_o,
    input logic [RespFifoWidth-1:0] resp_queue_wdata_i
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

      // Command queue
      .cmd_full_o(cmd_queue_full_o),
      .cmd_thld_o(cmd_queue_thld_o),
      .cmd_below_thld_o(cmd_queue_below_thld_o),
      .cmd_empty_o(cmd_queue_empty_o),
      .cmd_rvalid_o(cmd_queue_rvalid_o),
      .cmd_rready_i(cmd_queue_rready_i),
      .cmd_rdata_o(cmd_queue_rdata_o),

      // RX queue
      .rx_full_o(rx_queue_full_o),
      .rx_thld_o(rx_queue_thld_o),
      .rx_above_thld_o(rx_queue_above_thld_o),
      .rx_empty_o(rx_queue_empty_o),
      .rx_wvalid_i(rx_queue_wvalid_i),
      .rx_wready_o(rx_queue_wready_o),
      .rx_wdata_i(rx_queue_wdata_i),

      // TX queue
      .tx_full_o(tx_queue_full_o),
      .tx_thld_o(tx_queue_thld_o),
      .tx_below_thld_o(tx_queue_below_thld_o),
      .tx_empty_o(tx_queue_empty_o),
      .tx_rvalid_o(tx_queue_rvalid_o),
      .tx_rready_i(tx_queue_rready_i),
      .tx_rdata_o(tx_queue_rdata_o),

      // Response queue
      .resp_full_o(resp_queue_full_o),
      .resp_thld_o(resp_queue_thld_o),
      .resp_above_thld_o(resp_queue_above_thld_o),
      .resp_empty_o(resp_queue_empty_o),
      .resp_wvalid_i(resp_queue_wvalid_i),
      .resp_wready_o(resp_queue_wready_o),
      .resp_wdata_i(resp_queue_wdata_i)
  );
endmodule
