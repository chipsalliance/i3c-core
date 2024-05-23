// SPDX-License-Identifier: Apache-2.0

module i3c
  import i3c_pkg::*;
  import i2c_pkg::*;
  import I3CCSR_pkg::*;
  import hci_pkg::*;
#(
`ifdef I3C_USE_AHB
    parameter int unsigned AHB_DATA_WIDTH = `AHB_DATA_WIDTH,
    parameter int unsigned AHB_ADDR_WIDTH = `AHB_ADDR_WIDTH
`endif  // TODO: AXI4 I/O
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

`ifdef I3C_USE_AHB
    // AHB-Lite interface
    // Byte address of the transfer
    input  logic [  AHB_ADDR_WIDTH-1:0] haddr_i,
    // Indicates the number of bursts in a transfer
    input  logic [                 2:0] hburst_i,     // Unhandled
    // Protection control; provides information on the access type
    input  logic [                 3:0] hprot_i,      // Unhandled
    // Indicates the size of the transfer
    input  logic [                 2:0] hsize_i,
    // Indicates the transfer type
    input  logic [                 1:0] htrans_i,
    // Data for the write operation
    input  logic [  AHB_DATA_WIDTH-1:0] hwdata_i,
    // Write strobes; Deasserted when write data lanes do not contain valid data
    input  logic [AHB_DATA_WIDTH/8-1:0] hwstrb_i,     // Unhandled
    // Indicates write operation when asserted
    input  logic                        hwrite_i,
    // Read data
    output logic [  AHB_DATA_WIDTH-1:0] hrdata_o,
    // Asserted indicates a finished transfer; Can be driven low to extend a transfer
    output logic                        hreadyout_o,
    // Transfer response, high when error occurred
    output logic                        hresp_o,
    // Indicates the subordinate is selected for the transfer
    input  logic                        hsel_i,
    // Indicates all subordinates have finished transfers
    input  logic                        hready_i,
    // TODO: AXI4 I/O
`endif

    // I3C bus IO
    input        i3c_scl_i,    // serial clock input from i3c bus
    output logic i3c_scl_o,    // serial clock output to i3c bus
    output logic i3c_scl_en_o, // serial clock output to i3c bus

    input        i3c_sda_i,    // serial data input from i3c bus
    output logic i3c_sda_o,    // serial data output to i3c bus
    output logic i3c_sda_en_o, // serial data output to i3c bus

    // DAT memory export interface
    input  dat_mem_src_t  dat_mem_src_i,
    output dat_mem_sink_t dat_mem_sink_o,

    // DCT memory export interface
    input  dct_mem_src_t  dct_mem_src_i,
    output dct_mem_sink_t dct_mem_sink_o

    // TODO: Check if anything missing; Interrupts?
);
  // HCI queues' depth widths
  localparam int unsigned CmdFifoDepthW = $clog2(`CMD_FIFO_DEPTH + 1);
  localparam int unsigned RxFifoDepthW = $clog2(`RX_FIFO_DEPTH + 1);
  localparam int unsigned TxFifoDepthW = $clog2(`TX_FIFO_DEPTH + 1);
  localparam int unsigned RespFifoDepthW = $clog2(`RESP_FIFO_DEPTH + 1);

  // IOs between PHY and I3C bus
  logic                             scl_o;
  logic                             scl_en_o;

  logic                             sda_o;
  logic                             sda_en_o;

  logic                             ctrl2phy_scl;
  logic                             phy2ctrl_scl;
  logic                             ctrl2phy_sda;
  logic                             phy2ctrl_sda;

  // I3C SW CSR IF
  logic                             s_cpuif_req;
  logic                             s_cpuif_req_is_wr;
  logic [I3CCSR_MIN_ADDR_WIDTH-1:0] s_cpuif_addr;
  logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_data;
  logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_biten;
  logic                             s_cpuif_req_stall_wr;
  logic                             s_cpuif_req_stall_rd;
  logic                             s_cpuif_rd_ack;
  logic                             s_cpuif_rd_err;
  logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_rd_data;
  logic                             s_cpuif_wr_ack;
  logic                             s_cpuif_wr_err;

  // Command queue
  logic                             cmdrst;
  logic [         CmdThldWidth-1:0] cmd_fifo_thld;
  logic [        CmdFifoDepthW-1:0] cmd_fifo_depth;
  logic                             cmd_fifo_full;
  logic                             cmd_fifo_apch_thld;
  logic                             cmd_fifo_empty;
  logic                             cmd_fifo_wvalid;
  logic                             cmd_fifo_wready;
  logic [         CmdFifoWidth-1:0] cmd_fifo_wdata;
  logic                             cmd_fifo_rvalid;
  logic                             cmd_fifo_rready;
  logic [         CmdFifoWidth-1:0] cmd_fifo_rdata;

  // RX queue
  logic                             rxrst;
  logic [          RxThldWidth-1:0] rx_fifo_thld;
  logic [         RxFifoDepthW-1:0] rx_fifo_depth;
  logic                             rx_fifo_full;
  logic                             rx_fifo_apch_thld;
  logic                             rx_fifo_empty;
  logic                             rx_fifo_wvalid;
  logic                             rx_fifo_wready;
  logic [          RxFifoWidth-1:0] rx_fifo_wdata;
  logic                             rx_fifo_rvalid;
  logic                             rx_fifo_rready;
  logic [          RxFifoWidth-1:0] rx_fifo_rdata;

  // TX queue
  logic                             txrst;
  logic [          TxThldWidth-1:0] tx_fifo_thld;
  logic [         TxFifoDepthW-1:0] tx_fifo_depth;
  logic                             tx_fifo_full;
  logic                             tx_fifo_apch_thld;
  logic                             tx_fifo_empty;
  logic                             tx_fifo_wvalid;
  logic                             tx_fifo_wready;
  logic [          TxFifoWidth-1:0] tx_fifo_wdata;
  logic                             tx_fifo_rvalid;
  logic                             tx_fifo_rready;
  logic [          RxFifoWidth-1:0] tx_fifo_rdata;

  // Response queue
  logic                             resprst;
  logic [        RespThldWidth-1:0] resp_fifo_thld;
  logic [       RespFifoDepthW-1:0] resp_fifo_depth;
  logic                             resp_fifo_full;
  logic                             resp_fifo_apch_thld;
  logic                             resp_fifo_empty;
  logic                             resp_fifo_wvalid;
  logic                             resp_fifo_wready;
  logic [        RespFifoWidth-1:0] resp_fifo_wdata;
  logic                             resp_fifo_rvalid;
  logic                             resp_fifo_rready;
  logic [        RespFifoWidth-1:0] resp_fifo_rdata;

  // DAT <-> Controller interface
  logic                             dat_read_valid_hw_i;
  logic [   $clog2(`DAT_DEPTH)-1:0] dat_index_hw_i;
  logic [                     63:0] dat_rdata_hw_o;

  // DCT <-> Controller interface
  logic                             dct_write_valid_hw_i;
  logic                             dct_read_valid_hw_i;
  logic [   $clog2(`DCT_DEPTH)-1:0] dct_index_hw_i;
  logic [                    127:0] dct_wdata_hw_i;
  logic [                    127:0] dct_rdata_hw_o;

`ifdef I3C_USE_AHB
  ahb_if #(
      .AHB_DATA_WIDTH(AHB_DATA_WIDTH),
      .AHB_ADDR_WIDTH(AHB_ADDR_WIDTH)
  ) i3c_ahb_if (
      .hclk_i(clk_i),
      .hreset_n_i(rst_ni),
      .haddr_i(haddr_i),
      .hburst_i(hburst_i),
      .hprot_i(hprot_i),
      .hsize_i(hsize_i),
      .htrans_i(htrans_i),
      .hwdata_i(hwdata_i),
      .hwstrb_i(hwstrb_i),
      .hwrite_i(hwrite_i),
      .hrdata_o(hrdata_o),
      .hreadyout_o(hreadyout_o),
      .hresp_o(hresp_o),
      .hsel_i(hsel_i),
      .hready_i(hready_i),
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
  // TODO: AXI4 I/O
  // `else
`endif

  i3c_ctrl #() i3c_ctrl (
      .clk  (clk_i),
      .rst_n(rst_ni),

      .sda_i(i3c_sda_i),
      .sda_o(i3c_sda_o),
      .scl_i(i3c_scl_i),
      .scl_o(i3c_scl_o),

      .cmd_fifo_thld_i(cmd_fifo_thld),
      .cmd_fifo_empty_i(cmd_fifo_empty),
      .cmd_fifo_full_i(cmd_fifo_full),
      .cmd_fifo_apch_thld_i(cmd_fifo_apch_thld),
      .cmd_fifo_rvalid_i(cmd_fifo_rvalid),
      .cmd_fifo_rready_o(cmd_fifo_rready),
      .cmd_fifo_rdata_i(cmd_fifo_rdata),

      .rx_fifo_thld_i(rx_fifo_thld),
      .rx_fifo_empty_i(rx_fifo_empty),
      .rx_fifo_full_i(rx_fifo_full),
      .rx_fifo_apch_thld_i(rx_fifo_apch_thld),
      .rx_fifo_wvalid_o(rx_fifo_wvalid),
      .rx_fifo_wready_i(rx_fifo_wready),
      .rx_fifo_wdata_o(rx_fifo_wdata),

      .tx_fifo_thld_i(tx_fifo_thld),
      .tx_fifo_empty_i(tx_fifo_empty),
      .tx_fifo_full_i(tx_fifo_full),
      .tx_fifo_apch_thld_i(tx_fifo_apch_thld),
      .tx_fifo_rvalid_i(tx_fifo_rvalid),
      .tx_fifo_rready_o(tx_fifo_rready),
      .tx_fifo_rdata_i(tx_fifo_rdata),

      .resp_fifo_thld_i(resp_fifo_thld),
      .resp_fifo_empty_i(resp_fifo_empty),
      .resp_fifo_full_i(resp_fifo_full),
      .resp_fifo_apch_thld_i(resp_fifo_apch_thld),
      .resp_fifo_wvalid_o(resp_fifo_wvalid),
      .resp_fifo_wready_i(resp_fifo_wready),
      .resp_fifo_wdata_o(resp_fifo_wdata),

      .err(),  // TODO: Handle errors
      .irq()   // TODO: Handle interrupts
  );

  hci hci (
      .clk_i,
      .rst_ni,
      .s_cpuif_req,
      .s_cpuif_req_is_wr,
      .s_cpuif_addr,
      .s_cpuif_wr_data,
      .s_cpuif_wr_biten,
      .s_cpuif_req_stall_wr,
      .s_cpuif_req_stall_rd,
      .s_cpuif_rd_ack,
      .s_cpuif_rd_err,
      .s_cpuif_rd_data,
      .s_cpuif_wr_ack,
      .s_cpuif_wr_err,

      .dat_read_valid_hw_i,
      .dat_index_hw_i,
      .dat_rdata_hw_o,

      .dct_write_valid_hw_i,
      .dct_read_valid_hw_i,
      .dct_index_hw_i,
      .dct_wdata_hw_i,
      .dct_rdata_hw_o,

      .dat_mem_src_i,
      .dat_mem_sink_o,

      .dct_mem_src_i,
      .dct_mem_sink_o,

      // Command queue
      .cmdrst,
      .cmd_fifo_thld_o  (cmd_fifo_thld),
      .cmd_fifo_empty_i (cmd_fifo_empty),
      .cmd_fifo_wvalid_o(cmd_fifo_wvalid),
      .cmd_fifo_wready_i(cmd_fifo_wready),
      .cmd_fifo_wdata_o (cmd_fifo_wdata),

      // RX queue
      .rxrst,
      .rx_fifo_thld_o  (rx_fifo_thld),
      .rx_fifo_empty_i (rx_fifo_empty),
      .rx_fifo_rvalid_i(rx_fifo_rvalid),
      .rx_fifo_rready_o(rx_fifo_rready),
      .rx_fifo_rdata_i (rx_fifo_rdata),

      // TX queue
      .txrst,
      .tx_fifo_thld_o  (tx_fifo_thld),
      .tx_fifo_empty_i (tx_fifo_empty),
      .tx_fifo_wvalid_o(tx_fifo_wvalid),
      .tx_fifo_wready_i(tx_fifo_wready),
      .tx_fifo_wdata_o (tx_fifo_wdata),

      // Response queue
      .resprst,
      .resp_fifo_thld_o  (resp_fifo_thld),
      .resp_fifo_empty_i (resp_fifo_empty),
      .resp_fifo_rvalid_i(resp_fifo_rvalid),
      .resp_fifo_rready_o(resp_fifo_rready),
      .resp_fifo_rdata_i (resp_fifo_rdata)
  );

  // HCI queues
  hci_ctrl_queues #(
      .CMD_FIFO_DEPTH (`CMD_FIFO_DEPTH),
      .RESP_FIFO_DEPTH(`RESP_FIFO_DEPTH),
      .RX_FIFO_DEPTH  (`RX_FIFO_DEPTH),
      .TX_FIFO_DEPTH  (`TX_FIFO_DEPTH)
  ) hci_ctrl_queues (
      .clk_i,
      .rst_ni,

      .cmd_fifo_clr_i   (cmdrst),
      .cmd_fifo_thld_i  (cmd_fifo_thld),
      .cmd_fifo_depth_o (cmd_fifo_depth),
      .cmd_fifo_full_o  (cmd_fifo_full),
      .cmd_fifo_apch_thld_o(cmd_fifo_apch_thld),
      .cmd_fifo_empty_o (cmd_fifo_empty),
      .cmd_fifo_wvalid_i(cmd_fifo_wvalid),
      .cmd_fifo_wready_o(cmd_fifo_wready),
      .cmd_fifo_wdata_i (cmd_fifo_wdata),
      .cmd_fifo_rvalid_o(cmd_fifo_rvalid),
      .cmd_fifo_rready_i(cmd_fifo_rready),
      .cmd_fifo_rdata_o (cmd_fifo_rdata),

      .rx_fifo_clr_i   (rxrst),
      .rx_fifo_thld_i  (rx_fifo_thld),
      .rx_fifo_depth_o (rx_fifo_depth),
      .rx_fifo_full_o  (rx_fifo_full),
      .rx_fifo_apch_thld_o(rx_fifo_apch_thld),
      .rx_fifo_empty_o (rx_fifo_empty),
      .rx_fifo_wvalid_i(rx_fifo_wvalid),
      .rx_fifo_wready_o(rx_fifo_wready),
      .rx_fifo_wdata_i (rx_fifo_wdata),
      .rx_fifo_rvalid_o(rx_fifo_rvalid),
      .rx_fifo_rready_i(rx_fifo_rready),
      .rx_fifo_rdata_o (rx_fifo_rdata),

      .tx_fifo_clr_i   (txrst),
      .tx_fifo_thld_i  (tx_fifo_thld),
      .tx_fifo_depth_o (tx_fifo_depth),
      .tx_fifo_full_o  (tx_fifo_full),
      .tx_fifo_apch_thld_o(tx_fifo_apch_thld),
      .tx_fifo_empty_o (tx_fifo_empty),
      .tx_fifo_wvalid_i(tx_fifo_wvalid),
      .tx_fifo_wready_o(tx_fifo_wready),
      .tx_fifo_wdata_i (tx_fifo_wdata),
      .tx_fifo_rvalid_o(tx_fifo_rvalid),
      .tx_fifo_rready_i(tx_fifo_rready),
      .tx_fifo_rdata_o (tx_fifo_rdata),

      .resp_fifo_clr_i   (resprst),
      .resp_fifo_thld_i  (resp_fifo_thld),
      .resp_fifo_depth_o (resp_fifo_depth),
      .resp_fifo_full_o  (resp_fifo_full),
      .resp_fifo_apch_thld_o(resp_fifo_apch_thld),
      .resp_fifo_empty_o (resp_fifo_empty),
      .resp_fifo_wvalid_i(resp_fifo_wvalid),
      .resp_fifo_wready_o(resp_fifo_wready),
      .resp_fifo_wdata_i (resp_fifo_wdata),
      .resp_fifo_rvalid_o(resp_fifo_rvalid),
      .resp_fifo_rready_i(resp_fifo_rready),
      .resp_fifo_rdata_o (resp_fifo_rdata)
  );

  // I3C PHY
  i3c_phy phy (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .scl_i(i3c_scl_i),
      .scl_o(i3c_scl_o),
      .scl_en_o(i3c_scl_en_o),

      .sda_i(i3c_sda_i),
      .sda_o(i3c_sda_o),
      .sda_en_o(i3c_sda_en_o),

      .ctrl_scl_i(ctrl2phy_scl),
      .ctrl_scl_o(phy2ctrl_scl),
      .ctrl_sda_i(ctrl2phy_sda),
      .ctrl_sda_o(phy2ctrl_sda)
  );
endmodule
