// SPDX-License-Identifier: Apache-2.0

module i3c
  import i3c_pkg::*;
  import controller_pkg::*;
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
  localparam int unsigned HciCmdFifoDepthW = $clog2(`CMD_FIFO_DEPTH + 1);
  localparam int unsigned HciRxFifoDepthW = $clog2(`RX_FIFO_DEPTH + 1);
  localparam int unsigned HciTxFifoDepthW = $clog2(`TX_FIFO_DEPTH + 1);
  localparam int unsigned HciRespFifoDepthW = $clog2(`RESP_FIFO_DEPTH + 1);

  // IOs between PHY and I3C bus
  logic                             scl_o;
  logic                             scl_en_o;

  logic                             sda_o;
  logic                             sda_en_o;

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

  // Response queue
  logic                             resprst;
  logic [     HciRespThldWidth-1:0] resp_queue_thld;
  logic [    HciRespFifoDepthW-1:0] resp_queue_depth;
  logic                             resp_queue_full;
  logic                             resp_queue_above_thld;
  logic                             resp_queue_empty;
  logic                             resp_queue_wvalid;
  logic                             resp_queue_wready;
  logic [     HciRespDataWidth-1:0] resp_queue_wdata;
  logic                             resp_queue_rvalid;
  logic                             resp_queue_rready;
  logic [     HciRespDataWidth-1:0] resp_queue_rdata;

  // Command queue
  logic                             cmdrst;
  logic [      HciCmdThldWidth-1:0] cmd_queue_thld;
  logic [     HciCmdFifoDepthW-1:0] cmd_queue_depth;
  logic                             cmd_queue_full;
  logic                             cmd_queue_below_thld;
  logic                             cmd_queue_empty;
  logic                             cmd_queue_wvalid;
  logic                             cmd_queue_wready;
  logic [      HciCmdDataWidth-1:0] cmd_queue_wdata;
  logic                             cmd_queue_rvalid;
  logic                             cmd_queue_rready;
  logic [      HciCmdDataWidth-1:0] cmd_queue_rdata;

  // RX queue
  logic                             rxrst;
  logic [       HciRxThldWidth-1:0] rx_queue_thld;
  logic [      HciRxFifoDepthW-1:0] rx_queue_depth;
  logic                             rx_queue_full;
  logic                             rx_queue_above_thld;
  logic                             rx_queue_empty;
  logic                             rx_queue_wvalid;
  logic                             rx_queue_wready;
  logic [       HciRxDataWidth-1:0] rx_queue_wdata;
  logic                             rx_queue_rvalid;
  logic                             rx_queue_rready;
  logic [       HciRxDataWidth-1:0] rx_queue_rdata;

  // TX queue
  logic                             txrst;
  logic [       HciTxThldWidth-1:0] tx_queue_thld;
  logic [      HciTxFifoDepthW-1:0] tx_queue_depth;
  logic                             tx_queue_full;
  logic                             tx_queue_below_thld;
  logic                             tx_queue_empty;
  logic                             tx_queue_wvalid;
  logic                             tx_queue_wready;
  logic [       HciTxDataWidth-1:0] tx_queue_wdata;
  logic                             tx_queue_rvalid;
  logic                             tx_queue_rready;
  logic [       HciTxDataWidth-1:0] tx_queue_rdata;

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

  // TTI RX descriptors queue
  logic                             tti_tx_desc_queue_full;
  logic [   TtiRxDescThldWidth-1:0] tti_tx_desc_queue_thld;
  logic                             tti_tx_desc_queue_below_thld;
  logic                             tti_tx_desc_queue_empty;
  logic                             tti_tx_desc_queue_rvalid;
  logic                             tti_tx_desc_queue_rready;
  logic [   TtiRxDescDataWidth-1:0] tti_tx_desc_queue_rdata;

  // TTI TX descriptors queue
  logic                             tti_rx_desc_queue_full;
  logic [   TtiTxDescThldWidth-1:0] tti_rx_desc_queue_thld;
  logic                             tti_rx_desc_queue_above_thld;
  logic                             tti_rx_desc_queue_empty;
  logic                             tti_rx_desc_queue_wvalid;
  logic                             tti_rx_desc_queue_wready;
  logic [   TtiTxDescDataWidth-1:0] tti_rx_desc_queue_wdata;

  // TTI RX queue
  logic                             tti_rx_queue_full;
  logic [       TtiRxThldWidth-1:0] tti_rx_queue_thld;
  logic                             tti_rx_queue_above_thld;
  logic                             tti_rx_queue_empty;
  logic                             tti_rx_queue_wvalid;
  logic                             tti_rx_queue_wready;
  logic [       TtiRxDataWidth-1:0] tti_rx_queue_wdata;

  // TTI TX queue
  logic                             tti_tx_queue_full;
  logic [       TtiTxThldWidth-1:0] tti_tx_queue_thld;
  logic                             tti_tx_queue_below_thld;
  logic                             tti_tx_queue_empty;
  logic                             tti_tx_queue_rvalid;
  logic                             tti_tx_queue_rready;
  logic [       TtiTxDataWidth-1:0] tti_tx_queue_rdata;

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

  // TODO: Move configuration to hci.configuration
  // Array to mux SCL/SDA to 4 waveforms
  // Phy select:
  // 00 - i2c controller
  // 01 - i3c controller
  // 10 - i2c target
  // 11 - i3c target
  logic phy2ctrl_scl[4];
  logic phy2ctrl_sda[4];
  logic ctrl2phy_scl[4];
  logic ctrl2phy_sda[4];

  i3c_config_t core_config;

  controller #() xcontroller (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .ctrl_scl_i(phy2ctrl_scl),
      .ctrl_sda_i(phy2ctrl_sda),
      .ctrl_scl_o(ctrl2phy_scl),
      .ctrl_sda_o(ctrl2phy_sda),

      // HCI Response queue
      .resp_queue_thld_i(resp_queue_thld),
      .resp_queue_empty_i(resp_queue_empty),
      .resp_queue_full_i(resp_queue_full),
      .resp_queue_above_thld_i(resp_queue_above_thld),
      .resp_queue_wvalid_o(resp_queue_wvalid),
      .resp_queue_wready_i(resp_queue_wready),
      .resp_queue_wdata_o(resp_queue_wdata),

      // HCI Command queue
      .cmd_queue_thld_i(cmd_queue_thld),
      .cmd_queue_empty_i(cmd_queue_empty),
      .cmd_queue_full_i(cmd_queue_full),
      .cmd_queue_below_thld_i(cmd_queue_below_thld),
      .cmd_queue_rvalid_i(cmd_queue_rvalid),
      .cmd_queue_rready_o(cmd_queue_rready),
      .cmd_queue_rdata_i(cmd_queue_rdata),

      // HCI RX queue
      .rx_queue_thld_i(rx_queue_thld),
      .rx_queue_empty_i(rx_queue_empty),
      .rx_queue_full_i(rx_queue_full),
      .rx_queue_above_thld_i(rx_queue_above_thld),
      .rx_queue_wvalid_o(rx_queue_wvalid),
      .rx_queue_wready_i(rx_queue_wready),
      .rx_queue_wdata_o(rx_queue_wdata),

      // HCI TX queue
      .tx_queue_thld_i(tx_queue_thld),
      .tx_queue_empty_i(tx_queue_empty),
      .tx_queue_full_i(tx_queue_full),
      .tx_queue_below_thld_i(tx_queue_below_thld),
      .tx_queue_rvalid_i(tx_queue_rvalid),
      .tx_queue_rready_o(tx_queue_rready),
      .tx_queue_rdata_i(tx_queue_rdata),

      // TTI: RX Descriptor
      .tti_rx_desc_queue_full_i(tti_rx_desc_queue_full),
      .tti_rx_desc_queue_thld_i(tti_rx_desc_queue_thld),
      .tti_rx_desc_queue_above_thld_i(tti_rx_desc_queue_above_thld),
      .tti_rx_desc_queue_empty_i(tti_rx_desc_queue_empty),
      .tti_rx_desc_queue_wvalid_o(tti_rx_desc_queue_wvalid),
      .tti_rx_desc_queue_wready_i(tti_rx_desc_queue_wready),
      .tti_rx_desc_queue_wdata_o(tti_rx_desc_queue_wdata),

      // TTI: RX Data
      .tti_rx_queue_full_i(tti_rx_queue_full),
      .tti_rx_queue_thld_i(tti_rx_queue_thld),
      .tti_rx_queue_above_thld_i(tti_rx_queue_above_thld),
      .tti_rx_queue_empty_i(tti_rx_queue_empty),
      .tti_rx_queue_wvalid_o(tti_rx_queue_wvalid),
      .tti_rx_queue_wready_i(tti_rx_queue_wready),
      .tti_rx_queue_wdata_o(tti_rx_queue_wdata),

      // TTI: TX Descriptor
      .tti_tx_desc_queue_full_i(tti_tx_desc_queue_full),
      .tti_tx_desc_queue_thld_i(tti_tx_desc_queue_thld),
      .tti_tx_desc_queue_below_thld_i(tti_tx_desc_queue_below_thld),
      .tti_tx_desc_queue_empty_i(tti_tx_desc_queue_empty),
      .tti_tx_desc_queue_rvalid_i(tti_tx_desc_queue_rvalid),
      .tti_tx_desc_queue_rready_o(tti_tx_desc_queue_rready),
      .tti_tx_desc_queue_rdata_i(tti_tx_desc_queue_rdata),

      // TTI: TX Data
      .tti_tx_queue_full_i(tti_tx_queue_full),
      .tti_tx_queue_thld_i(tti_tx_queue_thld),
      .tti_tx_queue_below_thld_i(tti_tx_queue_below_thld),
      .tti_tx_queue_empty_i(tti_tx_queue_empty),
      .tti_tx_queue_rvalid_i(tti_tx_queue_rvalid),
      .tti_tx_queue_rready_o(tti_tx_queue_rready),
      .tti_tx_queue_rdata_i(tti_tx_queue_rdata),

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

      // TODO: TTI interface

      //TODO: Rename
      .i3c_fsm_en_i,
      .i3c_fsm_idle_o,

      .err(),  // TODO: Handle errors
      .irq(),  // TODO: Handle interrupts
      .core_config(core_config)
  );

  hci xhci (
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

      // HCI Response queue
      .hci_resp_full_o(resp_queue_full),
      .hci_resp_thld_o(resp_queue_thld),
      .hci_resp_above_thld_o(resp_queue_above_thld),
      .hci_resp_empty_o(resp_queue_empty),
      .hci_resp_wvalid_i(resp_queue_wvalid),
      .hci_resp_wready_o(resp_queue_wready),
      .hci_resp_wdata_i(resp_queue_wdata),

      // HCI Command queue
      .hci_cmd_full_o(cmd_queue_full),
      .hci_cmd_thld_o(cmd_queue_thld),
      .hci_cmd_below_thld_o(cmd_queue_below_thld),
      .hci_cmd_empty_o(cmd_queue_empty),
      .hci_cmd_rvalid_o(cmd_queue_rvalid),
      .hci_cmd_rready_i(cmd_queue_rready),
      .hci_cmd_rdata_o(cmd_queue_rdata),

      // HCI RX queue
      .hci_rx_full_o(rx_queue_full),
      .hci_rx_thld_o(rx_queue_thld),
      .hci_rx_above_thld_o(rx_queue_above_thld),
      .hci_rx_empty_o(rx_queue_empty),
      .hci_rx_wvalid_i(rx_queue_wvalid),
      .hci_rx_wready_o(rx_queue_wready),
      .hci_rx_wdata_i(rx_queue_wdata),

      // HCI TX queue
      .hci_tx_full_o(tx_queue_full),
      .hci_tx_thld_o(tx_queue_thld),
      .hci_tx_below_thld_o(tx_queue_below_thld),
      .hci_tx_empty_o(tx_queue_empty),
      .hci_tx_rvalid_o(tx_queue_rvalid),
      .hci_tx_rready_i(tx_queue_rready),
      .hci_tx_rdata_o(tx_queue_rdata),

      // TTI RX descriptors queue
      .tti_rx_desc_queue_full_o(tti_rx_desc_queue_full),
      .tti_rx_desc_queue_thld_o(tti_rx_desc_queue_thld),
      .tti_rx_desc_queue_above_thld_o(tti_rx_desc_queue_above_thld),
      .tti_rx_desc_queue_empty_o(tti_rx_desc_queue_empty),
      .tti_rx_desc_queue_wvalid_i(tti_rx_desc_queue_wvalid),
      .tti_rx_desc_queue_wready_o(tti_rx_desc_queue_wready),
      .tti_rx_desc_queue_wdata_i(tti_rx_desc_queue_wdata),

      // TTI TX descriptors queue
      .tti_tx_desc_queue_full_o(tti_tx_desc_queue_full),
      .tti_tx_desc_queue_thld_o(tti_tx_desc_queue_thld),
      .tti_tx_desc_queue_below_thld_o(tti_tx_desc_queue_below_thld),
      .tti_tx_desc_queue_empty_o(tti_tx_desc_queue_empty),
      .tti_tx_desc_queue_rvalid_o(tti_tx_desc_queue_rvalid),
      .tti_tx_desc_queue_rready_i(tti_tx_desc_queue_rready),
      .tti_tx_desc_queue_rdata_o(tti_tx_desc_queue_rdata),

      // TTI RX queue
      .tti_rx_queue_full_o(tti_rx_queue_full),
      .tti_rx_queue_thld_o(tti_rx_queue_thld),
      .tti_rx_queue_above_thld_o(tti_rx_queue_above_thld),
      .tti_rx_queue_empty_o(tti_rx_queue_empty),
      .tti_rx_queue_wvalid_i(tti_rx_queue_wvalid),
      .tti_rx_queue_wready_o(tti_rx_queue_wready),
      .tti_rx_queue_wdata_i(tti_rx_queue_wdata),

      // TTI TX queue
      .tti_tx_queue_full_o(tti_tx_queue_full),
      .tti_tx_queue_thld_o(tti_tx_queue_thld),
      .tti_tx_queue_below_thld_o(tti_tx_queue_below_thld),
      .tti_tx_queue_empty_o(tti_tx_queue_empty),
      .tti_tx_queue_rvalid_o(tti_tx_queue_rvalid),
      .tti_tx_queue_rready_i(tti_tx_queue_rready),
      .tti_tx_queue_rdata_o(tti_tx_queue_rdata),

      .core_config(core_config)
  );

  // I3C muxed PHY
  i3c_muxed_phy xi3c_muxed_phy (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .select_i(core_config.phy_mux_select),

      .scl_i(i3c_scl_i),
      .scl_o(i3c_scl_o),
      .scl_en_o(i3c_scl_en_o),

      .sda_i(i3c_sda_i),
      .sda_o(i3c_sda_o),
      .sda_en_o(i3c_sda_en_o),

      .ctrl_scl_i(ctrl2phy_scl),
      .ctrl_sda_i(ctrl2phy_sda),
      .ctrl_scl_o(phy2ctrl_scl),
      .ctrl_sda_o(phy2ctrl_sda)
  );

endmodule
