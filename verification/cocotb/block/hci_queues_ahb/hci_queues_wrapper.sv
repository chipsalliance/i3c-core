// SPDX-License-Identifier: Apache-2.0

module hci_queues_wrapper
  import i3c_pkg::*;
  import I3CCSR_pkg::I3CCSR_DATA_WIDTH;
  import I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
#(
    localparam int unsigned CsrAddrWidth = I3CCSR_MIN_ADDR_WIDTH,
    localparam int unsigned CsrDataWidth = I3CCSR_DATA_WIDTH,

    parameter int unsigned HciRespFifoDepth = 64,
    parameter int unsigned HciCmdFifoDepth  = 64,
    parameter int unsigned HciRxFifoDepth   = 64,
    parameter int unsigned HciTxFifoDepth   = 64,
    parameter int unsigned HciIbiFifoDepth  = 64,

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

    parameter int unsigned TtiRespFifoDepth = 64,
    parameter int unsigned TtiCmdFifoDepth  = 64,
    parameter int unsigned TtiRxFifoDepth   = 64,
    parameter int unsigned TtiTxFifoDepth   = 64,
    parameter int unsigned TtiIbiFifoDepth  = 64,

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
    output logic [HciRespThldWidth-1:0] hci_resp_queue_ready_thld_o,
    output logic hci_resp_queue_full_o,
    output logic hci_resp_queue_ready_thld_trig_o,
    output logic hci_resp_queue_empty_o,
    input logic hci_resp_queue_wvalid_i,
    output logic hci_resp_queue_wready_o,
    input logic [HciRespDataWidth-1:0] hci_resp_queue_wdata_i,

    // Command queue
    output logic [HciCmdThldWidth-1:0] hci_cmd_queue_ready_thld_o,
    output logic hci_cmd_queue_full_o,
    output logic hci_cmd_queue_ready_thld_trig_o,
    output logic hci_cmd_queue_empty_o,
    output logic hci_cmd_queue_rvalid_o,
    input logic hci_cmd_queue_rready_i,
    output logic [HciCmdDataWidth-1:0] hci_cmd_queue_rdata_o,

    // RX queue
    output logic [HciRxThldWidth-1:0] hci_rx_queue_start_thld_o,
    output logic [HciRxThldWidth-1:0] hci_rx_queue_ready_thld_o,
    output logic hci_rx_queue_full_o,
    output logic hci_rx_queue_start_thld_trig_o,
    output logic hci_rx_queue_ready_thld_trig_o,
    output logic hci_rx_queue_empty_o,
    input logic hci_rx_queue_wvalid_i,
    output logic hci_rx_queue_wready_o,
    input logic [HciRxDataWidth-1:0] hci_rx_queue_wdata_i,

    // TX queue
    output logic [HciTxThldWidth-1:0] hci_tx_queue_start_thld_o,
    output logic [HciTxThldWidth-1:0] hci_tx_queue_ready_thld_o,
    output logic hci_tx_queue_full_o,
    output logic hci_tx_queue_start_thld_trig_o,
    output logic hci_tx_queue_ready_thld_trig_o,
    output logic hci_tx_queue_empty_o,
    output logic hci_tx_queue_rvalid_o,
    input logic hci_tx_queue_rready_i,
    output logic [HciTxDataWidth-1:0] hci_tx_queue_rdata_o,

    output logic hci_ibi_queue_full_o,
    output logic [HciIbiThldWidth-1:0] hci_ibi_queue_ready_thld_o,
    output logic hci_ibi_queue_ready_thld_trig_o,
    output logic hci_ibi_queue_empty_o,
    input logic hci_ibi_queue_wvalid_i,
    output logic hci_ibi_queue_wready_o,
    input logic [HciIbiDataWidth-1:0] hci_ibi_queue_wdata_i,


    // Target Transaction Interface
    // RX descriptors queue
    output logic tti_rx_desc_queue_full_o,
    output logic [TtiRxDescThldWidth-1:0] tti_rx_desc_queue_ready_thld_o,
    output logic tti_rx_desc_queue_ready_thld_trig_o,
    output logic tti_rx_desc_queue_empty_o,
    input logic tti_rx_desc_queue_wvalid_i,
    output logic tti_rx_desc_queue_wready_o,
    input logic [TtiRxDescDataWidth-1:0] tti_rx_desc_queue_wdata_i,

    // TX descriptors queue
    output logic tti_tx_desc_queue_full_o,
    output logic [TtiTxDescThldWidth-1:0] tti_tx_desc_queue_ready_thld_o,
    output logic tti_tx_desc_queue_ready_thld_trig_o,
    output logic tti_tx_desc_queue_empty_o,
    output logic tti_tx_desc_queue_rvalid_o,
    input logic tti_tx_desc_queue_rready_i,
    output logic [TtiRxDescDataWidth-1:0] tti_tx_desc_queue_rdata_o,

    // RX queue
    output logic tti_rx_queue_full_o,
    output logic [TtiRxThldWidth-1:0] tti_rx_queue_start_thld_o,
    output logic [TtiRxThldWidth-1:0] tti_rx_queue_ready_thld_o,
    output logic tti_rx_queue_start_thld_trig_o,
    output logic tti_rx_queue_ready_thld_trig_o,
    output logic tti_rx_queue_empty_o,
    input logic tti_rx_queue_wvalid_i,
    output logic tti_rx_queue_wready_o,
    input logic [TtiRxDataWidth-1:0] tti_rx_queue_wdata_i,

    // TX queue
    output logic tti_tx_queue_full_o,
    output logic [TtiTxThldWidth-1:0] tti_tx_queue_start_thld_o,
    output logic [TtiTxThldWidth-1:0] tti_tx_queue_ready_thld_o,
    output logic tti_tx_queue_start_thld_trig_o,
    output logic tti_tx_queue_ready_thld_trig_o,
    output logic tti_tx_queue_empty_o,
    output logic tti_tx_queue_rvalid_o,
    input logic tti_tx_queue_rready_i,
    output logic [TtiTxDataWidth-1:0] tti_tx_queue_rdata_o,

    // In-band Interrupt Queue
    output logic tti_ibi_queue_full_o,
    output logic [TtiIbiThldWidth-1:0] tti_ibi_queue_ready_thld_o,
    output logic tti_ibi_queue_ready_thld_trig_o,
    input logic [TtiIbiDataWidth-1:0] tti_ibi_queue_wr_data_i,
    output logic tti_ibi_queue_empty_o,
    output logic tti_ibi_queue_rvalid_o,
    input logic tti_ibi_queue_rready_i,
    output logic [TtiIbiDataWidth-1:0] tti_ibi_queue_rdata_o
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

  ahb_if #(
      .AhbDataWidth(`AHB_DATA_WIDTH),
      .AhbAddrWidth(`AHB_ADDR_WIDTH)
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

  // HCI
  I3CCSR_pkg::I3CCSR__I3C_EC__TTI__out_t             hwif_tti_out;
  I3CCSR_pkg::I3CCSR__I3C_EC__TTI__in_t              hwif_tti_inp;

  I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__out_t hwif_rec_out;
  I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__in_t  hwif_rec_inp;

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
      .HciIbiThldWidth,
      .TtiRespFifoDepth,
      .TtiCmdFifoDepth,
      .TtiRxFifoDepth,
      .TtiTxFifoDepth,
      .TtiIbiFifoDepth,
      .TtiRxDescDataWidth,
      .TtiTxDescDataWidth,
      .TtiRxDataWidth,
      .TtiTxDataWidth,
      .TtiIbiDataWidth,
      .TtiRxDescThldWidth,
      .TtiTxDescThldWidth,
      .TtiRxThldWidth,
      .TtiTxThldWidth,
      .TtiIbiThldWidth
  ) hci (
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

      .hwif_tti_o(hwif_tti_out),
      .hwif_tti_i(hwif_tti_inp),

      .hwif_rec_o(hwif_rec_out),
      .hwif_rec_i(hwif_rec_inp),

      // HCI Response queue
      .hci_resp_full_o(hci_resp_queue_full_o),
      .hci_resp_ready_thld_o(hci_resp_queue_ready_thld_o),
      .hci_resp_ready_thld_trig_o(hci_resp_queue_ready_thld_trig_o),
      .hci_resp_empty_o(hci_resp_queue_empty_o),
      .hci_resp_wvalid_i(hci_resp_queue_wvalid_i),
      .hci_resp_wready_o(hci_resp_queue_wready_o),
      .hci_resp_wdata_i(hci_resp_queue_wdata_i),

      // HCI Command queue
      .hci_cmd_full_o(hci_cmd_queue_full_o),
      .hci_cmd_ready_thld_o(hci_cmd_queue_ready_thld_o),
      .hci_cmd_ready_thld_trig_o(hci_cmd_queue_ready_thld_trig_o),
      .hci_cmd_empty_o(hci_cmd_queue_empty_o),
      .hci_cmd_rvalid_o(hci_cmd_queue_rvalid_o),
      .hci_cmd_rready_i(hci_cmd_queue_rready_i),
      .hci_cmd_rdata_o(hci_cmd_queue_rdata_o),

      // HCI RX queue
      .hci_rx_full_o(hci_rx_queue_full_o),
      .hci_rx_start_thld_o(hci_rx_queue_start_thld_o),
      .hci_rx_ready_thld_o(hci_rx_queue_ready_thld_o),
      .hci_rx_start_thld_trig_o(hci_rx_queue_start_thld_trig_o),
      .hci_rx_ready_thld_trig_o(hci_rx_queue_ready_thld_trig_o),
      .hci_rx_empty_o(hci_rx_queue_empty_o),
      .hci_rx_wvalid_i(hci_rx_queue_wvalid_i),
      .hci_rx_wready_o(hci_rx_queue_wready_o),
      .hci_rx_wdata_i(hci_rx_queue_wdata_i),

      // HCI TX queue
      .hci_tx_full_o(hci_tx_queue_full_o),
      .hci_tx_start_thld_o(hci_tx_queue_start_thld_o),
      .hci_tx_ready_thld_o(hci_tx_queue_ready_thld_o),
      .hci_tx_start_thld_trig_o(hci_tx_queue_start_thld_trig_o),
      .hci_tx_ready_thld_trig_o(hci_tx_queue_ready_thld_trig_o),
      .hci_tx_empty_o(hci_tx_queue_empty_o),
      .hci_tx_rvalid_o(hci_tx_queue_rvalid_o),
      .hci_tx_rready_i(hci_tx_queue_rready_i),
      .hci_tx_rdata_o(hci_tx_queue_rdata_o),

      .hci_ibi_queue_full_o,
      .hci_ibi_queue_ready_thld_o,
      .hci_ibi_queue_ready_thld_trig_o,
      .hci_ibi_queue_empty_o,
      .hci_ibi_queue_wvalid_i,
      .hci_ibi_queue_wready_o,
      .hci_ibi_queue_wdata_i,

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

      .phy_en_o(unused_phy_en_o),
      .phy_mux_select_o(unused_phy_mux_select_o),
      .i2c_active_en_o(unused_i2c_active_en_o),
      .i2c_standby_en_o(unused_i2c_standby_en_o),
      .i3c_active_en_o(unused_i3c_active_en_o),
      .i3c_standby_en_o(unused_i3c_standby_en_o),
      .t_hd_dat_o(unused_t_hd_dat_o),
      .t_r_o(unused_t_r_o),
      .t_bus_free_o(unused_t_bus_free_o),
      .t_bus_idle_o(unused_t_bus_idle_o),
      .t_bus_available_o(unused_t_bus_available_o)
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

  tti #() xtti (
      .clk_i (hclk),
      .rst_ni(hreset_n),

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
  recovery_handler #() xrecovery_handler (
      .clk_i (hclk),
      .rst_ni(hreset_n),

      // Recovery CSR interface
      .hwif_rec_i(hwif_rec_out),
      .hwif_rec_o(hwif_rec_inp),

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

      // ...........................
      // TTI controller interface

      // TTI RX descriptors queue
      .ctl_tti_rx_desc_queue_full_o(tti_rx_desc_queue_full_o),
      .ctl_tti_rx_desc_queue_empty_o(tti_rx_desc_queue_empty_o),
      .ctl_tti_rx_desc_queue_wvalid_i(tti_rx_desc_queue_wvalid_i),
      .ctl_tti_rx_desc_queue_wready_o(tti_rx_desc_queue_wready_o),
      .ctl_tti_rx_desc_queue_wdata_i(tti_rx_desc_queue_wdata_i),
      .ctl_tti_rx_desc_queue_ready_thld_o(tti_rx_desc_queue_ready_thld_o),
      .ctl_tti_rx_desc_queue_ready_thld_trig_o(tti_rx_desc_queue_ready_thld_trig_o),

      // TTI TX descriptors queue
      .ctl_tti_tx_desc_queue_full_o(tti_tx_desc_queue_full_o),
      .ctl_tti_tx_desc_queue_empty_o(tti_tx_desc_queue_empty_o),
      .ctl_tti_tx_desc_queue_rvalid_o(tti_tx_desc_queue_rvalid_o),
      .ctl_tti_tx_desc_queue_rready_i(tti_tx_desc_queue_rready_i),
      .ctl_tti_tx_desc_queue_rdata_o(tti_tx_desc_queue_rdata_o),
      .ctl_tti_tx_desc_queue_ready_thld_o(tti_tx_desc_queue_ready_thld_o),
      .ctl_tti_tx_desc_queue_ready_thld_trig_o(tti_tx_desc_queue_ready_thld_trig_o),

      // TTI RX data queue
      .ctl_tti_rx_data_queue_full_o(tti_rx_queue_full_o),
      .ctl_tti_rx_data_queue_empty_o(tti_rx_queue_empty_o),
      .ctl_tti_rx_data_queue_wvalid_i(tti_rx_queue_wvalid_i),
      .ctl_tti_rx_data_queue_wready_o(tti_rx_queue_wready_o),
      .ctl_tti_rx_data_queue_wdata_i(tti_rx_queue_wdata_i),
      .ctl_tti_rx_data_queue_start_thld_o(tti_rx_queue_start_thld_o),
      .ctl_tti_rx_data_queue_start_thld_trig_o(tti_rx_queue_start_thld_trig_o),
      .ctl_tti_rx_data_queue_ready_thld_o(tti_rx_queue_ready_thld_o),
      .ctl_tti_rx_data_queue_ready_thld_trig_o(tti_rx_queue_ready_thld_trig_o),

      // TTI TX data queue
      .ctl_tti_tx_data_queue_full_o(tti_tx_queue_full_o),
      .ctl_tti_tx_data_queue_empty_o(tti_tx_queue_empty_o),
      .ctl_tti_tx_data_queue_rvalid_o(tti_tx_queue_rvalid_o),
      .ctl_tti_tx_data_queue_rready_i(tti_tx_queue_rready_i),
      .ctl_tti_tx_data_queue_rdata_o(tti_tx_queue_rdata_o),
      .ctl_tti_tx_data_queue_start_thld_o(tti_tx_queue_start_thld_o),
      .ctl_tti_tx_data_queue_start_thld_trig_o(tti_tx_queue_start_thld_trig_o),
      .ctl_tti_tx_data_queue_ready_thld_o(tti_tx_queue_ready_thld_o),
      .ctl_tti_tx_data_queue_ready_thld_trig_o(tti_tx_queue_ready_thld_trig_o),

      // TTI In-band Interrupt (IBI) queue
      .ctl_tti_ibi_queue_full_o(tti_ibi_queue_full_o),
      .ctl_tti_ibi_queue_empty_o(tti_ibi_queue_empty_o),
      .ctl_tti_ibi_queue_rvalid_o(tti_ibi_queue_rvalid_o),
      .ctl_tti_ibi_queue_rready_i(tti_ibi_queue_rready_i),
      .ctl_tti_ibi_queue_rdata_o(tti_ibi_queue_rdata_o),
      .ctl_tti_ibi_queue_ready_thld_o(tti_ibi_queue_ready_thld_o),
      .ctl_tti_ibi_queue_ready_thld_trig_o(tti_ibi_queue_ready_thld_trig_o)
  );

endmodule
