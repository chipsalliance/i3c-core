// SPDX-License-Identifier: Apache-2.0

module hci_queues_wrapper
  import i3c_pkg::*;
  import I3CCSR_pkg::I3CCSR_DATA_WIDTH;
  import I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
#(
    localparam int unsigned CsrAddrWidth = I3CCSR_MIN_ADDR_WIDTH,
    localparam int unsigned CsrDataWidth = I3CCSR_DATA_WIDTH,

    parameter int unsigned AxiAddrWidth = 12,
    parameter int unsigned AxiDataWidth = 32,
    parameter int unsigned AxiUserWidth = 32,
    parameter int unsigned AxiIdWidth   = 2,

    parameter int unsigned HciRespFifoDepth = 64,
    parameter int unsigned HciCmdFifoDepth  = 64,
    parameter int unsigned HciRxFifoDepth   = 64,
    parameter int unsigned HciTxFifoDepth   = 64,
    parameter int unsigned HciIbiFifoDepth  = 64,

    localparam int unsigned HciRespFifoDepthWidth = $clog2(HciRespFifoDepth + 1),
    localparam int unsigned HciCmdFifoDepthWidth = $clog2(HciCmdFifoDepth + 1),
    localparam int unsigned HciRxFifoDepthWidth = $clog2(HciRxFifoDepth + 1),
    localparam int unsigned HciTxFifoDepthWidth = $clog2(HciTxFifoDepth + 1),
    localparam int unsigned HciIbiFifoDepthWidth = $clog2(HciIbiFifoDepth + 1),

    parameter int unsigned HciRespDataWidth = 32,
    parameter int unsigned HciCmdDataWidth  = 64,
    parameter int unsigned HciRxDataWidth   = 32,
    parameter int unsigned HciTxDataWidth   = 32,
    parameter int unsigned HciIbiDataWidth  = 32,

    parameter int unsigned HciRespThldWidth = 8,
    parameter int unsigned HciCmdThldWidth  = 8,
    parameter int unsigned HciRxThldWidth   = 3,
    parameter int unsigned HciTxThldWidth   = 3,
    parameter int unsigned HciIbiThldWidth  = 8,

    parameter int unsigned TtiRxDescFifoDepth = 64,
    parameter int unsigned TtiTxDescFifoDepth  = 64,
    parameter int unsigned TtiRxDataFifoDepth   = 64,
    parameter int unsigned TtiTxDataFifoDepth   = 64,
    parameter int unsigned TtiIbiFifoDepth  = 64,

    localparam int unsigned TtiRxDescFifoDepthWidth = $clog2(TtiRxDescFifoDepth + 1),
    localparam int unsigned TtiTxDescFifoDepthWidth = $clog2(TtiTxDescFifoDepth + 1),
    localparam int unsigned TtiRxDataFifoDepthWidth = $clog2(TtiRxDataFifoDepth + 1),
    localparam int unsigned TtiTxDataFifoDepthWidth = $clog2(TtiTxDataFifoDepth + 1),
    localparam int unsigned TtiIbiFifoDepthWidth = $clog2(TtiIbiFifoDepth + 1),

    parameter int unsigned TtiRxDescDataWidth = 32,
    parameter int unsigned TtiTxDescDataWidth = 32,
    parameter int unsigned TtiRxDataWidth = 32,
    parameter int unsigned TtiTxDataWidth = 32,
    parameter int unsigned TtiIbiDataWidth = 32,

    parameter int unsigned TtiRxDescThldWidth = 8,
    parameter int unsigned TtiTxDescThldWidth = 8,
    parameter int unsigned TtiRxThldWidth = 3,
    parameter int unsigned TtiTxThldWidth = 3,
    parameter int unsigned TtiIbiThldWidth = 8
) (
    input aclk,  // clock
    input areset_n,  // active low reset

    // AXI4 Interface
    // AXI Read Channels
    input  logic [AxiAddrWidth-1:0] araddr,
    input        [             1:0] arburst,
    input  logic [             2:0] arsize,
    input        [             7:0] arlen,
    input        [AxiUserWidth-1:0] aruser,
    input  logic [  AxiIdWidth-1:0] arid,
    input  logic                    arlock,
    input  logic                    arvalid,
    output logic                    arready,

    output logic [AxiDataWidth-1:0] rdata,
    output logic [             1:0] rresp,
    output logic [  AxiIdWidth-1:0] rid,
    output logic                    rlast,
    output logic                    rvalid,
    input  logic                    rready,

    // AXI Write Channels
    input  logic [AxiAddrWidth-1:0] awaddr,
    input        [             1:0] awburst,
    input  logic [             2:0] awsize,
    input        [             7:0] awlen,
    input        [AxiUserWidth-1:0] awuser,
    input  logic [  AxiIdWidth-1:0] awid,
    input  logic                    awlock,
    input  logic                    awvalid,
    output logic                    awready,

    input  logic [AxiDataWidth-1:0] wdata,
    input  logic [             3:0] wstrb,
    input  logic                    wlast,
    input  logic                    wvalid,
    output logic                    wready,

    output logic [           1:0] bresp,
    output logic [AxiIdWidth-1:0] bid,
    output logic                  bvalid,
    input  logic                  bready,

    // HCI queues (FSM side)
    // Response queue
    output logic [HciRespThldWidth-1:0] hci_resp_ready_thld_o,
    output logic hci_resp_full_o,
    output logic [HciRespFifoDepthWidth-1:0] hci_resp_depth_o,
    output logic hci_resp_ready_thld_trig_o,
    output logic hci_resp_empty_o,
    input logic hci_resp_wvalid_i,
    output logic hci_resp_wready_o,
    input logic [HciRespDataWidth-1:0] hci_resp_wdata_i,

    // Command queue
    output logic [HciCmdThldWidth-1:0] hci_cmd_ready_thld_o,
    output logic hci_cmd_full_o,
    output logic [HciCmdFifoDepthWidth-1:0] hci_cmd_depth_o,
    output logic hci_cmd_ready_thld_trig_o,
    output logic hci_cmd_empty_o,
    output logic hci_cmd_rvalid_o,
    input logic hci_cmd_rready_i,
    output logic [HciCmdDataWidth-1:0] hci_cmd_rdata_o,

    // RX queue
    output logic [HciRxThldWidth-1:0] hci_rx_start_thld_o,
    output logic [HciRxThldWidth-1:0] hci_rx_ready_thld_o,
    output logic hci_rx_full_o,
    output logic [HciRxFifoDepthWidth-1:0] hci_rx_depth_o,
    output logic hci_rx_start_thld_trig_o,
    output logic hci_rx_ready_thld_trig_o,
    output logic hci_rx_empty_o,
    input logic hci_rx_wvalid_i,
    output logic hci_rx_wready_o,
    input logic [HciRxDataWidth-1:0] hci_rx_wdata_i,

    // TX queue
    output logic [HciTxThldWidth-1:0] hci_tx_start_thld_o,
    output logic [HciTxThldWidth-1:0] hci_tx_ready_thld_o,
    output logic hci_tx_full_o,
    output logic [HciTxFifoDepthWidth-1:0] hci_tx_depth_o,
    output logic hci_tx_start_thld_trig_o,
    output logic hci_tx_ready_thld_trig_o,
    output logic hci_tx_empty_o,
    output logic hci_tx_rvalid_o,
    input logic hci_tx_rready_i,
    output logic [HciTxDataWidth-1:0] hci_tx_rdata_o,

    output logic hci_ibi_full_o,
    output logic [HciIbiFifoDepthWidth-1:0] hci_ibi_depth_o,
    output logic [HciIbiThldWidth-1:0] hci_ibi_ready_thld_o,
    output logic hci_ibi_ready_thld_trig_o,
    output logic hci_ibi_empty_o,
    input logic hci_ibi_wvalid_i,
    output logic hci_ibi_wready_o,
    input logic [HciIbiDataWidth-1:0] hci_ibi_wdata_i,


    // Target Transaction Interface
    // RX descriptors queue
    output logic tti_rx_desc_full_o,
    output logic [TtiRxDescFifoDepthWidth-1:0] tti_rx_desc_depth_o,
    output logic [TtiRxDescThldWidth-1:0] tti_rx_desc_ready_thld_o,
    output logic tti_rx_desc_ready_thld_trig_o,
    output logic tti_rx_desc_empty_o,
    input logic tti_rx_desc_wvalid_i,
    output logic tti_rx_desc_wready_o,
    input logic [TtiRxDescDataWidth-1:0] tti_rx_desc_wdata_i,

    // TX descriptors queue
    output logic tti_tx_desc_full_o,
    output logic [TtiTxDescFifoDepthWidth-1:0] tti_tx_desc_depth_o,
    output logic [TtiTxDescThldWidth-1:0] tti_tx_desc_ready_thld_o,
    output logic tti_tx_desc_ready_thld_trig_o,
    output logic tti_tx_desc_empty_o,
    output logic tti_tx_desc_rvalid_o,
    input logic tti_tx_desc_rready_i,
    output logic [TtiRxDescDataWidth-1:0] tti_tx_desc_rdata_o,

    // RX queue
    output logic tti_rx_full_o,
    output logic [TtiRxDataFifoDepthWidth-1:0] tti_rx_depth_o,
    output logic [TtiRxThldWidth-1:0] tti_rx_start_thld_o,
    output logic [TtiRxThldWidth-1:0] tti_rx_ready_thld_o,
    output logic tti_rx_start_thld_trig_o,
    output logic tti_rx_ready_thld_trig_o,
    output logic tti_rx_empty_o,
    input logic tti_rx_wvalid_i,
    output logic tti_rx_wready_o,
    input logic [7:0] tti_rx_wdata_i,

    // TX queue
    output logic tti_tx_full_o,
    output logic [TtiTxDataFifoDepthWidth-1:0] tti_tx_depth_o,
    output logic [TtiTxThldWidth-1:0] tti_tx_start_thld_o,
    output logic [TtiTxThldWidth-1:0] tti_tx_ready_thld_o,
    output logic tti_tx_start_thld_trig_o,
    output logic tti_tx_ready_thld_trig_o,
    input logic tti_tx_host_nack_i,
    output logic tti_tx_empty_o,
    output logic tti_tx_rvalid_o,
    input logic tti_tx_rready_i,
    output logic [7:0] tti_tx_rdata_o,

    // In-band Interrupt Queue
    output logic tti_ibi_full_o,
    output logic [TtiIbiFifoDepthWidth-1:0] tti_ibi_depth_o,
    output logic [TtiIbiThldWidth-1:0] tti_ibi_ready_thld_o,
    output logic tti_ibi_ready_thld_trig_o,
    input logic [TtiIbiDataWidth-1:0] tti_ibi_wr_data_i,
    output logic tti_ibi_empty_o,
    output logic tti_ibi_rvalid_o,
    input logic tti_ibi_rready_i,
    output logic [TtiIbiDataWidth-1:0] tti_ibi_rdata_o,

    input logic [7:0] rst_action_i,

    // S/Sr and P bus condition
    input logic bus_start_i,
    input logic bus_stop_i,

    // Received I2C/I3C address along with RnW# bit
    input logic [7:0] bus_addr_i,
    input logic bus_addr_valid_i
);

  // I3C SW CSR IF
  logic s_cpuif_req;
  logic s_cpuif_req_is_wr;
  logic [CsrAddrWidth-1:0] s_cpuif_addr;
  logic [CsrDataWidth-1:0] s_cpuif_wr_data;
  logic [CsrDataWidth-1:0] s_cpuif_wr_biten;
  logic s_cpuif_req_stall_wr;
  logic s_cpuif_req_stall_rd;
  logic s_cpuif_rd_ack;
  logic s_cpuif_rd_err;
  logic [CsrDataWidth-1:0] s_cpuif_rd_data;
  logic s_cpuif_wr_ack;
  logic s_cpuif_wr_err;

  axi_adapter #(
      .AxiDataWidth,
      .AxiAddrWidth,
      .AxiUserWidth,
      .AxiIdWidth
  ) i3c_axi_if (
      .clk_i (aclk),
      .rst_ni(areset_n),

      // AXI Read Channels
      .araddr_i(araddr),
      .arburst_i(arburst),
      .arsize_i(arsize),
      .arlen_i(arlen),
      .aruser_i(aruser),
      .arid_i(arid),
      .arlock_i(arlock),
      .arvalid_i(arvalid),
      .arready_o(arready),

      .rdata_o(rdata),
      .rresp_o(rresp),
      .rid_o(rid),
      .rlast_o(rlast),
      .rvalid_o(rvalid),
      .rready_i(rready),

      // AXI Write Channels
      .awaddr_i(awaddr),
      .awburst_i(awburst),
      .awsize_i(awsize),
      .awlen_i(awlen),
      .awuser_i(awuser),
      .awid_i(awid),
      .awlock_i(awlock),
      .awvalid_i(awvalid),
      .awready_o(awready),

      .wdata_i (wdata),
      .wstrb_i (wstrb),
      .wlast_i (wlast),
      .wvalid_i(wvalid),
      .wready_o(wready),

      .bresp_o(bresp),
      .bid_o(bid),
      .bvalid_o(bvalid),
      .bready_i(bready),

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

  logic [63:0] unused_dat_rdata_hw;
  logic [127:0] unused_dct_rdata_hw;
  dat_mem_sink_t unused_dat_mem_sink;
  dct_mem_sink_t unused_dct_mem_sink;
  logic unused_phy_en_o;
  logic [1:0] unused_phy_mux_select_o;
  logic unused_i2c_active_en_o;
  logic unused_i2c_standby_en_o;
  logic unused_i3c_active_en_o;
  logic unused_i3c_standby_en_o;
  logic [19:0] unused_t_hd_dat_o;
  logic [19:0] unused_t_r_o;
  logic [19:0] unused_t_bus_free_o;
  logic [19:0] unused_t_bus_idle_o;
  logic [19:0] unused_t_bus_available_o;

  logic tti_rx_wflush;

  // HCI
  I3CCSR_pkg::I3CCSR__out_t unused_hwif_out;

  I3CCSR_pkg::I3CCSR__I3C_EC__TTI__out_t hwif_tti_out;
  I3CCSR_pkg::I3CCSR__I3C_EC__TTI__in_t hwif_tti_inp;

  I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__out_t hwif_rec_out;
  I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__in_t hwif_rec_inp;

  hci #(
      .HciRespFifoDepth,
      .HciCmdFifoDepth,
      .HciRxFifoDepth,
      .HciTxFifoDepth,
      .HciIbiFifoDepth,
      .HciRespDataWidth,
      .HciCmdDataWidth,
      .HciRxDataWidth,
      .HciTxDataWidth,
      .HciIbiDataWidth,
      .HciRespThldWidth,
      .HciCmdThldWidth,
      .HciRxThldWidth,
      .HciTxThldWidth,
      .HciIbiThldWidth
  ) hci (
      .clk_i(aclk),  // clock
      .rst_ni(areset_n), // active low reset

      // I3C SW CSR access interface
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

      // DAT <-> Controller interface
      .dat_read_valid_hw_i('0),
      .dat_index_hw_i('0),
      .dat_rdata_hw_o(unused_dat_rdata_hw),

      .dct_write_valid_hw_i('0),
      .dct_read_valid_hw_i('0),
      .dct_index_hw_i('0),
      .dct_wdata_hw_i('0),
      .dct_rdata_hw_o(unused_dct_rdata_hw),

      .dat_mem_src_i ('0),
      .dat_mem_sink_o(unused_dat_mem_sink),

      .dct_mem_src_i ('0),
      .dct_mem_sink_o(unused_dct_mem_sink),

      // Response queue
      .hci_resp_full_o,
      .hci_resp_depth_o,
      .hci_resp_ready_thld_o,
      .hci_resp_ready_thld_trig_o,
      .hci_resp_empty_o,
      .hci_resp_wvalid_i,
      .hci_resp_wready_o,
      .hci_resp_wdata_i,

      // Command queue
      .hci_cmd_full_o,
      .hci_cmd_depth_o,
      .hci_cmd_ready_thld_o,
      .hci_cmd_ready_thld_trig_o,
      .hci_cmd_empty_o,
      .hci_cmd_rvalid_o,
      .hci_cmd_rready_i,
      .hci_cmd_rdata_o,

      // RX queue
      .hci_rx_full_o,
      .hci_rx_depth_o,
      .hci_rx_start_thld_o,
      .hci_rx_ready_thld_o,
      .hci_rx_start_thld_trig_o,
      .hci_rx_ready_thld_trig_o,
      .hci_rx_empty_o,
      .hci_rx_wvalid_i,
      .hci_rx_wready_o,
      .hci_rx_wdata_i,

      // TX queue
      .hci_tx_full_o,
      .hci_tx_depth_o,
      .hci_tx_start_thld_o,
      .hci_tx_ready_thld_o,
      .hci_tx_start_thld_trig_o,
      .hci_tx_ready_thld_trig_o,
      .hci_tx_empty_o,
      .hci_tx_rvalid_o,
      .hci_tx_rready_i,
      .hci_tx_rdata_o,

      // In-band Interrupt queue
      .hci_ibi_full_o,
      .hci_ibi_depth_o,
      .hci_ibi_ready_thld_o,
      .hci_ibi_ready_thld_trig_o,
      .hci_ibi_empty_o,
      .hci_ibi_wvalid_i,
      .hci_ibi_wready_o,
      .hci_ibi_wdata_i,

      // Target Transaction Interface CSRs
      .hwif_tti_o(hwif_tti_out),
      .hwif_tti_i(hwif_tti_inp),

      // Recovery interface CSRs
      .hwif_rec_o(hwif_rec_out),
      .hwif_rec_i(hwif_rec_inp),

      // Controller configuration
      .hwif_out_o(unused_hwif_out),

      .rst_action_i
  );

  // TTI

  // TTI RX Descriptor queue
  logic                          csr_tti_rx_desc_queue_req;
  logic                          csr_tti_rx_desc_queue_ack;
  logic [TtiRxDescDataWidth-1:0] csr_tti_rx_desc_queue_data;
  logic [TtiRxDescThldWidth-1:0] csr_tti_rx_desc_queue_ready_thld_i;
  logic [TtiRxDescThldWidth-1:0] csr_tti_rx_desc_queue_ready_thld_o;
  logic                          csr_tti_rx_desc_queue_reg_rst;
  logic                          csr_tti_rx_desc_queue_reg_rst_we;
  logic                          csr_tti_rx_desc_queue_reg_rst_data;

  // TTI TX Descriptor queue
  logic                          csr_tti_tx_desc_queue_req;
  logic                          csr_tti_tx_desc_queue_ack;
  logic [      CsrDataWidth-1:0] csr_tti_tx_desc_queue_data;
  logic [TtiTxDescThldWidth-1:0] csr_tti_tx_desc_queue_ready_thld_i;
  logic [TtiTxDescThldWidth-1:0] csr_tti_tx_desc_queue_ready_thld_o;
  logic                          csr_tti_tx_desc_queue_reg_rst;
  logic                          csr_tti_tx_desc_queue_reg_rst_we;
  logic                          csr_tti_tx_desc_queue_reg_rst_data;

  // TTI RX data queue
  logic                          csr_tti_rx_data_queue_req;
  logic                          csr_tti_rx_data_queue_ack;
  logic [    TtiRxDataWidth-1:0] csr_tti_rx_data_queue_data;
  logic [    TtiRxThldWidth-1:0] csr_tti_rx_data_queue_start_thld;
  logic [    TtiRxThldWidth-1:0] csr_tti_rx_data_queue_ready_thld_i;
  logic [    TtiRxThldWidth-1:0] csr_tti_rx_data_queue_ready_thld_o;
  logic                          csr_tti_rx_data_queue_reg_rst;
  logic                          csr_tti_rx_data_queue_reg_rst_we;
  logic                          csr_tti_rx_data_queue_reg_rst_data;

  // TTI TX data queue
  logic                          csr_tti_tx_data_queue_req;
  logic                          csr_tti_tx_data_queue_ack;
  logic [      CsrDataWidth-1:0] csr_tti_tx_data_queue_data;
  logic [    TtiTxThldWidth-1:0] csr_tti_tx_data_queue_start_thld;
  logic [    TtiTxThldWidth-1:0] csr_tti_tx_data_queue_ready_thld_i;
  logic [    TtiTxThldWidth-1:0] csr_tti_tx_data_queue_ready_thld_o;
  logic                          csr_tti_tx_data_queue_reg_rst;
  logic                          csr_tti_tx_data_queue_reg_rst_we;
  logic                          csr_tti_tx_data_queue_reg_rst_data;

  // TTI In-band Interrupt (IBI) queue
  logic                          csr_tti_ibi_queue_req;
  logic                          csr_tti_ibi_queue_ack;
  logic [      CsrDataWidth-1:0] csr_tti_ibi_queue_data;
  logic [   TtiIbiThldWidth-1:0] csr_tti_ibi_queue_ready_thld;
  logic                          csr_tti_ibi_queue_reg_rst;
  logic                          csr_tti_ibi_queue_reg_rst_we;
  logic                          csr_tti_ibi_queue_reg_rst_data;

  // Interrupt
  logic irq;

  // Recovery status
  logic payload_available;
  logic image_activated;

  tti xtti (
      .clk_i (aclk),
      .rst_ni(areset_n),

      .hwif_tti_i(hwif_tti_out),
      .hwif_tti_o(hwif_tti_inp),

      // TTI RX descriptors queue
      .rx_desc_queue_req_o         (csr_tti_rx_desc_queue_req),
      .rx_desc_queue_ack_i         (csr_tti_rx_desc_queue_ack),
      .rx_desc_queue_data_i        (csr_tti_rx_desc_queue_data),
      .rx_desc_queue_ready_thld_o  (csr_tti_rx_desc_queue_ready_thld_i),
      .rx_desc_queue_ready_thld_i  (csr_tti_rx_desc_queue_ready_thld_o),
      .rx_desc_queue_reg_rst_o     (csr_tti_rx_desc_queue_reg_rst),
      .rx_desc_queue_reg_rst_we_i  (csr_tti_rx_desc_queue_reg_rst_we),
      .rx_desc_queue_reg_rst_data_i(csr_tti_rx_desc_queue_reg_rst_data),

      // TTI TX descriptors queue
      .tx_desc_queue_req_o         (csr_tti_tx_desc_queue_req),
      .tx_desc_queue_ack_i         (csr_tti_tx_desc_queue_ack),
      .tx_desc_queue_data_o        (csr_tti_tx_desc_queue_data),
      .tx_desc_queue_ready_thld_o  (csr_tti_tx_desc_queue_ready_thld_i),
      .tx_desc_queue_ready_thld_i  (csr_tti_tx_desc_queue_ready_thld_o),
      .tx_desc_queue_reg_rst_o     (csr_tti_tx_desc_queue_reg_rst),
      .tx_desc_queue_reg_rst_we_i  (csr_tti_tx_desc_queue_reg_rst_we),
      .tx_desc_queue_reg_rst_data_i(csr_tti_tx_desc_queue_reg_rst_data),

      // TTI RX queue
      .rx_data_queue_req_o         (csr_tti_rx_data_queue_req),
      .rx_data_queue_ack_i         (csr_tti_rx_data_queue_ack),
      .rx_data_queue_data_i        (csr_tti_rx_data_queue_data),
      .rx_data_queue_start_thld_o  (csr_tti_rx_data_queue_start_thld),
      .rx_data_queue_ready_thld_o  (csr_tti_rx_data_queue_ready_thld_i),
      .rx_data_queue_ready_thld_i  (csr_tti_rx_data_queue_ready_thld_o),
      .rx_data_queue_reg_rst_o     (csr_tti_rx_data_queue_reg_rst),
      .rx_data_queue_reg_rst_we_i  (csr_tti_rx_data_queue_reg_rst_we),
      .rx_data_queue_reg_rst_data_i(csr_tti_rx_data_queue_reg_rst_data),

      // TTI TX queue
      .tx_data_queue_req_o         (csr_tti_tx_data_queue_req),
      .tx_data_queue_ack_i         (csr_tti_tx_data_queue_ack),
      .tx_data_queue_data_o        (csr_tti_tx_data_queue_data),
      .tx_data_queue_start_thld_o  (csr_tti_tx_data_queue_start_thld),
      .tx_data_queue_ready_thld_o  (csr_tti_tx_data_queue_ready_thld_i),
      .tx_data_queue_ready_thld_i  (csr_tti_tx_data_queue_ready_thld_o),
      .tx_data_queue_reg_rst_o     (csr_tti_tx_data_queue_reg_rst),
      .tx_data_queue_reg_rst_we_i  (csr_tti_tx_data_queue_reg_rst_we),
      .tx_data_queue_reg_rst_data_i(csr_tti_tx_data_queue_reg_rst_data),

      // TTI In-band Interrupt (IBI) queue
      .ibi_queue_req_o         (csr_tti_ibi_queue_req),
      .ibi_queue_ack_i         (csr_tti_ibi_queue_ack),
      .ibi_queue_data_o        (csr_tti_ibi_queue_data),
      .ibi_queue_ready_thld_o  (csr_tti_ibi_queue_ready_thld),
      .ibi_queue_reg_rst_o     (csr_tti_ibi_queue_reg_rst),
      .ibi_queue_reg_rst_we_i  (csr_tti_ibi_queue_reg_rst_we),
      .ibi_queue_reg_rst_data_i(csr_tti_ibi_queue_reg_rst_data)
  );

  // Recovery handler
  recovery_handler xrecovery_handler (
      .clk_i (aclk),
      .rst_ni(areset_n),

      // Recovery CSR interface
      .hwif_rec_i(hwif_rec_out),
      .hwif_rec_o(hwif_rec_inp),

      // Interrupt
      .irq_o(irq),

      // Recovery status
      .payload_available_o(payload_available),
      .image_activated_o(image_activated),

      // ...........................
      // TTI CSR interface

      // TTI RX descriptors queue
      .csr_tti_rx_desc_queue_req_i         (csr_tti_rx_desc_queue_req),
      .csr_tti_rx_desc_queue_ack_o         (csr_tti_rx_desc_queue_ack),
      .csr_tti_rx_desc_queue_data_o        (csr_tti_rx_desc_queue_data),
      .csr_tti_rx_desc_queue_ready_thld_i  (csr_tti_rx_desc_queue_ready_thld_i),
      .csr_tti_rx_desc_queue_ready_thld_o  (csr_tti_rx_desc_queue_ready_thld_o),
      .csr_tti_rx_desc_queue_reg_rst_i     (csr_tti_rx_desc_queue_reg_rst),
      .csr_tti_rx_desc_queue_reg_rst_we_o  (csr_tti_rx_desc_queue_reg_rst_we),
      .csr_tti_rx_desc_queue_reg_rst_data_o(csr_tti_rx_desc_queue_reg_rst_data),

      // TTI TX descriptors queue
      .csr_tti_tx_desc_queue_req_i         (csr_tti_tx_desc_queue_req),
      .csr_tti_tx_desc_queue_ack_o         (csr_tti_tx_desc_queue_ack),
      .csr_tti_tx_desc_queue_data_i        (csr_tti_tx_desc_queue_data),
      .csr_tti_tx_desc_queue_ready_thld_i  (csr_tti_tx_desc_queue_ready_thld_i),
      .csr_tti_tx_desc_queue_ready_thld_o  (csr_tti_tx_desc_queue_ready_thld_o),
      .csr_tti_tx_desc_queue_reg_rst_i     (csr_tti_tx_desc_queue_reg_rst),
      .csr_tti_tx_desc_queue_reg_rst_we_o  (csr_tti_tx_desc_queue_reg_rst_we),
      .csr_tti_tx_desc_queue_reg_rst_data_o(csr_tti_tx_desc_queue_reg_rst_data),

      // TTI RX queue
      .csr_tti_rx_data_queue_req_i         (csr_tti_rx_data_queue_req),
      .csr_tti_rx_data_queue_ack_o         (csr_tti_rx_data_queue_ack),
      .csr_tti_rx_data_queue_data_o        (csr_tti_rx_data_queue_data),
      .csr_tti_rx_data_queue_start_thld_i  (csr_tti_rx_data_queue_start_thld),
      .csr_tti_rx_data_queue_ready_thld_i  (csr_tti_rx_data_queue_ready_thld_i),
      .csr_tti_rx_data_queue_ready_thld_o  (csr_tti_rx_data_queue_ready_thld_o),
      .csr_tti_rx_data_queue_reg_rst_i     (csr_tti_rx_data_queue_reg_rst),
      .csr_tti_rx_data_queue_reg_rst_we_o  (csr_tti_rx_data_queue_reg_rst_we),
      .csr_tti_rx_data_queue_reg_rst_data_o(csr_tti_rx_data_queue_reg_rst_data),

      // TTI TX queue
      .csr_tti_tx_data_queue_req_i         (csr_tti_tx_data_queue_req),
      .csr_tti_tx_data_queue_ack_o         (csr_tti_tx_data_queue_ack),
      .csr_tti_tx_data_queue_data_i        (csr_tti_tx_data_queue_data),
      .csr_tti_tx_data_queue_start_thld_i  (csr_tti_tx_data_queue_start_thld),
      .csr_tti_tx_data_queue_ready_thld_i  (csr_tti_tx_data_queue_ready_thld_i),
      .csr_tti_tx_data_queue_ready_thld_o  (csr_tti_tx_data_queue_ready_thld_o),
      .csr_tti_tx_data_queue_reg_rst_i     (csr_tti_tx_data_queue_reg_rst),
      .csr_tti_tx_data_queue_reg_rst_we_o  (csr_tti_tx_data_queue_reg_rst_we),
      .csr_tti_tx_data_queue_reg_rst_data_o(csr_tti_tx_data_queue_reg_rst_data),

      // TTI In-band Interrupt (IBI) queue
      .csr_tti_ibi_queue_req_i         (csr_tti_ibi_queue_req),
      .csr_tti_ibi_queue_ack_o         (csr_tti_ibi_queue_ack),
      .csr_tti_ibi_queue_data_i        (csr_tti_ibi_queue_data),
      .csr_tti_ibi_queue_ready_thld_i  (csr_tti_ibi_queue_ready_thld),
      .csr_tti_ibi_queue_reg_rst_i     (csr_tti_ibi_queue_reg_rst),
      .csr_tti_ibi_queue_reg_rst_we_o  (csr_tti_ibi_queue_reg_rst_we),
      .csr_tti_ibi_queue_reg_rst_data_o(csr_tti_ibi_queue_reg_rst_data),

    // S/Sr and P bus condition
      .ctl_bus_start_i(bus_start_i),
      .ctl_bus_stop_i(bus_stop_i),

    // Received I2C/I3C address along with RnW# bit
      .ctl_bus_addr_i(bus_addr_i),
      .ctl_bus_addr_valid_i(bus_addr_valid_i),

      // ...........................
      // TTI controller interface

      // TTI RX descriptors queue
      .ctl_tti_rx_desc_queue_full_o(tti_rx_desc_full_o),
      .ctl_tti_rx_desc_queue_depth_o(tti_rx_desc_depth_o),
      .ctl_tti_rx_desc_queue_empty_o(tti_rx_desc_empty_o),
      .ctl_tti_rx_desc_queue_wvalid_i(tti_rx_desc_wvalid_i),
      .ctl_tti_rx_desc_queue_wready_o(tti_rx_desc_wready_o),
      .ctl_tti_rx_desc_queue_wdata_i(tti_rx_desc_wdata_i),
      .ctl_tti_rx_desc_queue_ready_thld_o(tti_rx_desc_ready_thld_o),
      .ctl_tti_rx_desc_queue_ready_thld_trig_o(tti_rx_desc_ready_thld_trig_o),

      // TTI TX descriptors queue
      .ctl_tti_tx_desc_queue_full_o(tti_tx_desc_full_o),
      .ctl_tti_tx_desc_queue_depth_o(tti_tx_desc_depth_o),
      .ctl_tti_tx_desc_queue_empty_o(tti_tx_desc_empty_o),
      .ctl_tti_tx_desc_queue_rvalid_o(tti_tx_desc_rvalid_o),
      .ctl_tti_tx_desc_queue_rready_i(tti_tx_desc_rready_i),
      .ctl_tti_tx_desc_queue_rdata_o(tti_tx_desc_rdata_o),
      .ctl_tti_tx_desc_queue_ready_thld_o(tti_tx_desc_ready_thld_o),
      .ctl_tti_tx_desc_queue_ready_thld_trig_o(tti_tx_desc_ready_thld_trig_o),

      // TTI RX data queue
      .ctl_tti_rx_data_queue_full_o(tti_rx_full_o),
      .ctl_tti_rx_data_queue_depth_o(tti_rx_depth_o),
      .ctl_tti_rx_data_queue_empty_o(tti_rx_empty_o),
      .ctl_tti_rx_data_queue_wvalid_i(tti_rx_wvalid_i),
      .ctl_tti_rx_data_queue_wready_o(tti_rx_wready_o),
      .ctl_tti_rx_data_queue_wdata_i(tti_rx_wdata_i),
      .ctl_tti_rx_data_queue_wflush_i(tti_rx_wflush),
      .ctl_tti_rx_data_queue_start_thld_o(tti_rx_start_thld_o),
      .ctl_tti_rx_data_queue_start_thld_trig_o(tti_rx_start_thld_trig_o),
      .ctl_tti_rx_data_queue_ready_thld_o(tti_rx_ready_thld_o),
      .ctl_tti_rx_data_queue_ready_thld_trig_o(tti_rx_ready_thld_trig_o),

      // TTI TX data queue
      .ctl_tti_tx_data_queue_full_o(tti_tx_full_o),
      .ctl_tti_tx_data_queue_depth_o(tti_tx_depth_o),
      .ctl_tti_tx_data_queue_empty_o(tti_tx_empty_o),
      .ctl_tti_tx_data_queue_rvalid_o(tti_tx_rvalid_o),
      .ctl_tti_tx_data_queue_rready_i(tti_tx_rready_i),
      .ctl_tti_tx_data_queue_rdata_o(tti_tx_rdata_o),
      .ctl_tti_tx_data_queue_start_thld_o(tti_tx_start_thld_o),
      .ctl_tti_tx_data_queue_start_thld_trig_o(tti_tx_start_thld_trig_o),
      .ctl_tti_tx_data_queue_ready_thld_o(tti_tx_ready_thld_o),
      .ctl_tti_tx_data_queue_ready_thld_trig_o(tti_tx_ready_thld_trig_o),
      .ctl_tti_tx_host_nack_i(tti_tx_host_nack_i),

      // TTI In-band Interrupt (IBI) queue
      .ctl_tti_ibi_queue_full_o(tti_ibi_full_o),
      .ctl_tti_ibi_queue_depth_o(tti_ibi_depth_o),
      .ctl_tti_ibi_queue_empty_o(tti_ibi_empty_o),
      .ctl_tti_ibi_queue_rvalid_o(tti_ibi_rvalid_o),
      .ctl_tti_ibi_queue_rready_i(tti_ibi_rready_i),
      .ctl_tti_ibi_queue_rdata_o(tti_ibi_rdata_o),
      .ctl_tti_ibi_queue_ready_thld_o(tti_ibi_ready_thld_o),
      .ctl_tti_ibi_queue_ready_thld_trig_o(tti_ibi_ready_thld_trig_o)
  );

  // TODO: These write-enable signals were not combo-driven or initialized on reset.
  // This is a placeholder driver. They require either unimplemented drivers or changes in RDL.
  always_comb begin : missing_csr_we_inits
    hwif_tti_inp.RESET_CONTROL.SOFT_RST.we = 0;
    hwif_tti_inp.RESET_CONTROL.RX_DATA_RST.we = 0;
    hci.hwif_in.I3CBase.HC_CONTROL.RESUME.we = 0;
    hci.hwif_in.I3CBase.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR.we = 0;
    hci.hwif_in.I3CBase.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR_VALID.we = 0;
    hci.hwif_in.I3CBase.RESET_CONTROL.SOFT_RST.we = 0;
    hci.hwif_in.I3CBase.DCT_SECTION_OFFSET.TABLE_INDEX.we = 0;
    hci.hwif_in.I3CBase.IBI_DATA_ABORT_CTRL.IBI_DATA_ABORT_MON.we = 0;
    hci.hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.HANDOFF_DEEP_SLEEP.we = 0;
    hci.hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.CR_REQUEST_SEND.we = 0;
    hci.hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.BAST_CCC_IBI_RING.we = 0;
    hci.hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.TARGET_XACT_ENABLE.we = 0;
    hci.hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_SETAASA_ENABLE.we = 0;
    hci.hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_SETDASA_ENABLE.we = 0;
    hci.hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_ENTDAA_ENABLE.we = 0;
    hci.hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.RSTACT_DEFBYTE_02.we = 0;
    hci.hwif_in.I3C_EC.TTI.RESET_CONTROL.SOFT_RST.we = 0;
    hci.hwif_in.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST.we = 0;
    hci.hwif_in.I3C_EC.CtrlCfg.CONTROLLER_CONFIG.OPERATION_MODE.we = 0;
    xtti.hwif_tti_o.RESET_CONTROL.RX_DATA_RST.we = 0;

    hci.hwif_in.I3CBase.HC_CONTROL.BUS_ENABLE.we = 0;
    hci.hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.STBY_CR_ENABLE_INIT.we = 0;

    xtti.hwif_tti_o.QUEUE_THLD_CTRL.IBI_THLD.we = 0;
    xtti.hwif_tti_o.RESET_CONTROL.IBI_QUEUE_RST.we = 0;
    xtti.hwif_tti_o.RESET_CONTROL.TX_DATA_RST.we = 0;
    xtti.hwif_tti_o.RESET_CONTROL.RX_DESC_RST.we = 0;
    xtti.hwif_tti_o.RESET_CONTROL.SOFT_RST.we = 0;
    xtti.hwif_tti_o.RESET_CONTROL.TX_DESC_RST.we = 0;
  end : missing_csr_we_inits

  always_comb begin : other_uninit_signals
    xrecovery_handler.irq_o = 0;
    xrecovery_handler.recv_tti_rx_data_queue_flow = 0;
    tti_rx_wflush = 0;
  end : other_uninit_signals

endmodule
