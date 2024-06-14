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
`elsif I3C_USE_AXI
    parameter unsigned AXI_DATA_WIDTH = `AXI_DATA_WIDTH,
    parameter unsigned AXI_ADDR_WIDTH = `AXI_ADDR_WIDTH,
    parameter unsigned AXI_USER_WIDTH = `AXI_USER_WIDTH,
    parameter unsigned AXI_ID_WIDTH = `AXI_ID_WIDTH
`endif
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

`elsif I3C_USE_AXI
    // AXI4 Interface
    // AXI Read Channels
    input  logic [AXI_ADDR_WIDTH-1:0] araddr_i,
    input  logic [               1:0] arburst_i,
    input  logic [               2:0] arsize_i,
    input  logic [               7:0] arlen_i,
    input  logic [AXI_USER_WIDTH-1:0] aruser_i,
    input  logic [  AXI_ID_WIDTH-1:0] arid_i,
    input  logic                      arlock_i,
    input  logic                      arvalid_i,
    output logic                      arready_o,

    output logic [AXI_DATA_WIDTH-1:0] rdata_o,
    output logic [               1:0] rresp_o,
    output logic [  AXI_ID_WIDTH-1:0] rid_o,
    output logic                      rlast_o,
    output logic                      rvalid_o,
    input  logic                      rready_i,

    // AXI Write Channels
    input  logic [AXI_ADDR_WIDTH-1:0] awaddr_i,
    input  logic [               1:0] awburst_i,
    input  logic [               2:0] awsize_i,
    input  logic [               7:0] awlen_i,
    input  logic [AXI_USER_WIDTH-1:0] awuser_i,
    input  logic [  AXI_ID_WIDTH-1:0] awid_i,
    input  logic                      awlock_i,
    input  logic                      awvalid_i,
    output logic                      awready_o,

    input  logic [AXI_DATA_WIDTH-1:0] wdata_i,
    input  logic [               7:0] wstrb_i,
    input  logic                      wlast_i,
    input  logic                      wvalid_i,
    output logic                      wready_o,

    output logic [             1:0] bresp_o,
    output logic [AXI_ID_WIDTH-1:0] bid_o,
    output logic                    bvalid_o,
    input  logic                    bready_i,

`endif

    // I3C bus IO
    input  logic i3c_scl_i,    // serial clock input from i3c bus
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
    output dct_mem_sink_t dct_mem_sink_o,

    input  logic i3c_fsm_en_i,
    output logic i3c_fsm_idle_o

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
  logic [         CmdThldWidth-1:0] cmd_queue_thld;
  logic [        CmdFifoDepthW-1:0] cmd_queue_depth;
  logic                             cmd_queue_full;
  logic                             cmd_queue_below_thld;
  logic                             cmd_queue_empty;
  logic                             cmd_queue_wvalid;
  logic                             cmd_queue_wready;
  logic [         CmdFifoWidth-1:0] cmd_queue_wdata;
  logic                             cmd_queue_rvalid;
  logic                             cmd_queue_rready;
  logic [         CmdFifoWidth-1:0] cmd_queue_rdata;

  // RX queue
  logic                             rxrst;
  logic [          RxThldWidth-1:0] rx_queue_thld;
  logic [         RxFifoDepthW-1:0] rx_queue_depth;
  logic                             rx_queue_full;
  logic                             rx_queue_above_thld;
  logic                             rx_queue_empty;
  logic                             rx_queue_wvalid;
  logic                             rx_queue_wready;
  logic [          RxFifoWidth-1:0] rx_queue_wdata;
  logic                             rx_queue_rvalid;
  logic                             rx_queue_rready;
  logic [          RxFifoWidth-1:0] rx_queue_rdata;

  // TX queue
  logic                             txrst;
  logic [          TxThldWidth-1:0] tx_queue_thld;
  logic [         TxFifoDepthW-1:0] tx_queue_depth;
  logic                             tx_queue_full;
  logic                             tx_queue_below_thld;
  logic                             tx_queue_empty;
  logic                             tx_queue_wvalid;
  logic                             tx_queue_wready;
  logic [          TxFifoWidth-1:0] tx_queue_wdata;
  logic                             tx_queue_rvalid;
  logic                             tx_queue_rready;
  logic [          RxFifoWidth-1:0] tx_queue_rdata;

  // Response queue
  logic                             resprst;
  logic [        RespThldWidth-1:0] resp_queue_thld;
  logic [       RespFifoDepthW-1:0] resp_queue_depth;
  logic                             resp_queue_full;
  logic                             resp_queue_above_thld;
  logic                             resp_queue_empty;
  logic                             resp_queue_wvalid;
  logic                             resp_queue_wready;
  logic [        RespFifoWidth-1:0] resp_queue_wdata;
  logic                             resp_queue_rvalid;
  logic                             resp_queue_rready;
  logic [        RespFifoWidth-1:0] resp_queue_rdata;

  // DAT <-> Controller interface
  logic                             dat_read_valid_hw;
  logic [   $clog2(`DAT_DEPTH)-1:0] dat_index_hw;
  logic [                     63:0] dat_rdata_hw;

  // DCT <-> Controller interface
  logic                             dct_write_valid_hw;
  logic                             dct_read_valid_hw;
  logic [   $clog2(`DCT_DEPTH)-1:0] dct_index_hw;
  logic [                    127:0] dct_wdata_hw;
  logic [                    127:0] dct_rdata_hw;

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

`elsif I3C_USE_AXI
  axi_adapter #(
      .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
      .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
      .AXI_USER_WIDTH(AXI_USER_WIDTH),
      .AXI_ID_WIDTH  (AXI_ID_WIDTH)
  ) i3c_axi_if (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      // AXI Read Channels
      .araddr_i(araddr_i),
      .arburst_i(arburst_i),
      .arsize_i(arsize_i),
      .arlen_i(arlen_i),
      .aruser_i(aruser_i),
      .arid_i(arid_i),
      .arlock_i(arlock_i),
      .arvalid_i(arvalid_i),
      .arready_o(arready_o),

      .rdata_o(rdata_o),
      .rresp_o(rresp_o),
      .rid_o(rid_o),
      .rlast_o(rlast_o),
      .rvalid_o(rvalid_o),
      .rready_i(rready_i),

      // AXI Write Channels
      .awaddr_i(awaddr_i),
      .awburst_i(awburst_i),
      .awsize_i(awsize_i),
      .awlen_i(awlen_i),
      .awuser_i(awuser_i),
      .awid_i(awid_i),
      .awlock_i(awlock_i),
      .awvalid_i(awvalid_i),
      .awready_o(awready_o),

      .wdata_i (wdata_i),
      .wstrb_i (wstrb_i),
      .wlast_i (wlast_i),
      .wvalid_i(wvalid_i),
      .wready_o(wready_o),

      .bresp_o(bresp_o),
      .bid_o(bid_o),
      .bvalid_o(bvalid_o),
      .bready_i(bready_i),

      // I3C SW CSR access interface
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
`endif

  i3c_ctrl #() i3c_ctrl (
      .clk  (clk_i),
      .rst_n(rst_ni),

      .sda_i(i3c_sda_i),
      .sda_o(i3c_sda_o),
      .scl_i(i3c_scl_i),
      .scl_o(i3c_scl_o),

      .cmd_queue_thld_i(cmd_queue_thld),
      .cmd_queue_empty_i(cmd_queue_empty),
      .cmd_queue_full_i(cmd_queue_full),
      .cmd_queue_below_thld_i(cmd_queue_below_thld),
      .cmd_queue_rvalid_i(cmd_queue_rvalid),
      .cmd_queue_rready_o(cmd_queue_rready),
      .cmd_queue_rdata_i(cmd_queue_rdata),

      .rx_queue_thld_i(rx_queue_thld),
      .rx_queue_empty_i(rx_queue_empty),
      .rx_queue_full_i(rx_queue_full),
      .rx_queue_above_thld_i(rx_queue_above_thld),
      .rx_queue_wvalid_o(rx_queue_wvalid),
      .rx_queue_wready_i(rx_queue_wready),
      .rx_queue_wdata_o(rx_queue_wdata),

      .tx_queue_thld_i(tx_queue_thld),
      .tx_queue_empty_i(tx_queue_empty),
      .tx_queue_full_i(tx_queue_full),
      .tx_queue_below_thld_i(tx_queue_below_thld),
      .tx_queue_rvalid_i(tx_queue_rvalid),
      .tx_queue_rready_o(tx_queue_rready),
      .tx_queue_rdata_i(tx_queue_rdata),

      .resp_queue_thld_i(resp_queue_thld),
      .resp_queue_empty_i(resp_queue_empty),
      .resp_queue_full_i(resp_queue_full),
      .resp_queue_above_thld_i(resp_queue_above_thld),
      .resp_queue_wvalid_o(resp_queue_wvalid),
      .resp_queue_wready_i(resp_queue_wready),
      .resp_queue_wdata_o(resp_queue_wdata),

      // DAT <-> Controller interface
      .dat_read_valid_hw_o(dat_read_valid_hw),
      .dat_index_hw_o(dat_index_hw),
      .dat_rdata_hw_i(dat_rdata_hw),

      // DCT <-> Controller interface
      .dct_write_valid_hw_o(dct_write_valid_hw),
      .dct_read_valid_hw_o(dct_read_valid_hw),
      .dct_index_hw_o(dct_index_hw),
      .dct_wdata_hw_o(dct_wdata_hw),
      .dct_rdata_hw_i(dct_rdata_hw),

      .i3c_fsm_en_i,
      .i3c_fsm_idle_o,

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

      .dat_read_valid_hw_i(dat_read_valid_hw),
      .dat_index_hw_i(dat_index_hw),
      .dat_rdata_hw_o(dat_rdata_hw),

      .dct_write_valid_hw_i(dct_write_valid_hw),
      .dct_read_valid_hw_i(dct_read_valid_hw),
      .dct_index_hw_i(dct_index_hw),
      .dct_wdata_hw_i(dct_wdata_hw),
      .dct_rdata_hw_o(dct_rdata_hw),

      .dat_mem_src_i,
      .dat_mem_sink_o,

      .dct_mem_src_i,
      .dct_mem_sink_o,

      // Command queue
      .cmd_full_o(cmd_queue_full),
      .cmd_thld_o(cmd_queue_thld),
      .cmd_below_thld_o(cmd_queue_below_thld),
      .cmd_empty_o(cmd_queue_empty),
      .cmd_rvalid_o(cmd_queue_rvalid),
      .cmd_rready_i(cmd_queue_rready),
      .cmd_rdata_o(cmd_queue_rdata),

      // RX queue
      .rx_full_o(rx_queue_full),
      .rx_thld_o(rx_queue_thld),
      .rx_above_thld_o(rx_queue_above_thld),
      .rx_empty_o(rx_queue_empty),
      .rx_wvalid_i(rx_queue_wvalid),
      .rx_wready_o(rx_queue_wready),
      .rx_wdata_i(rx_queue_wdata),

      // TX queue
      .tx_full_o(tx_queue_full),
      .tx_thld_o(tx_queue_thld),
      .tx_below_thld_o(tx_queue_below_thld),
      .tx_empty_o(tx_queue_empty),
      .tx_rvalid_o(tx_queue_rvalid),
      .tx_rready_i(tx_queue_rready),
      .tx_rdata_o(tx_queue_rdata),

      // Response queue
      .resp_full_o(resp_queue_full),
      .resp_thld_o(resp_queue_thld),
      .resp_above_thld_o(resp_queue_above_thld),
      .resp_empty_o(resp_queue_empty),
      .resp_wvalid_i(resp_queue_wvalid),
      .resp_wready_o(resp_queue_wready),
      .resp_wdata_i(resp_queue_wdata)
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
