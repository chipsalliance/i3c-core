// SPDX-License-Identifier: Apache-2.0
`include "i3c_defines.svh"

module hci_queues_wrapper
  import i3c_pkg::*;
  import I3CCSR_pkg::I3CCSR_DATA_WIDTH;
  import I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
#(
`ifdef I3C_USE_AHB
    parameter int unsigned AhbAddrWidth = 18,
    parameter int unsigned AhbDataWidth = 64,
`elsif I3C_USE_AXI
    parameter int unsigned AxiAddrWidth = 12,
    parameter int unsigned AxiDataWidth = 32,
    parameter int unsigned AxiUserWidth = 32,
    parameter int unsigned AxiIdWidth = 2,
`ifdef AXI_ID_FILTERING
    parameter int unsigned NumPrivIds = 4,
`endif
`endif
    parameter int unsigned DatAw = i3c_pkg::DatAw,
    parameter int unsigned DctAw = i3c_pkg::DctAw,

    localparam int unsigned CsrAddrWidth = I3CCSR_MIN_ADDR_WIDTH,
    localparam int unsigned CsrDataWidth = I3CCSR_DATA_WIDTH

`ifdef CONTROLLER_SUPPORT,
    parameter int unsigned HciRespFifoDepth = 64,
    parameter int unsigned HciCmdFifoDepth  = 64,
    parameter int unsigned HciRxFifoDepth   = 64,
    parameter int unsigned HciTxFifoDepth   = 64,
    parameter int unsigned HciIbiFifoDepth  = 64,

    localparam int unsigned HciRespFifoDepthWidth = $clog2(HciRespFifoDepth + 1),
    localparam int unsigned HciCmdFifoDepthWidth  = $clog2(HciCmdFifoDepth + 1),
    localparam int unsigned HciRxFifoDepthWidth   = $clog2(HciRxFifoDepth + 1),
    localparam int unsigned HciTxFifoDepthWidth   = $clog2(HciTxFifoDepth + 1),
    localparam int unsigned HciIbiFifoDepthWidth  = $clog2(HciIbiFifoDepth + 1),

    parameter int unsigned HciRespDataWidth = 32,
    parameter int unsigned HciCmdDataWidth  = 64,
    parameter int unsigned HciRxDataWidth   = 32,
    parameter int unsigned HciTxDataWidth   = 32,
    parameter int unsigned HciIbiDataWidth  = 32,

    parameter int unsigned HciRespThldWidth = 8,
    parameter int unsigned HciCmdThldWidth = 8,
    parameter int unsigned HciRxThldWidth = 3,
    parameter int unsigned HciTxThldWidth = 3,
    parameter int unsigned HciIbiThldWidth = 8
`endif  // CONTROLLER_SUPPORT
`ifdef TARGET_SUPPORT,
    parameter int unsigned TtiRxDescFifoDepth = 64,
    parameter int unsigned TtiTxDescFifoDepth = 64,
    parameter int unsigned TtiRxDataFifoDepth = 64,
    parameter int unsigned TtiTxDataFifoDepth = 64,
    parameter int unsigned TtiIbiFifoDepth = 64,

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
`endif  // TARGET_SUPPORT
) (
`ifdef I3C_USE_AHB
    // AHB-Lite interface
    input  logic                      hclk,
    input  logic                      hreset_n,
    input  logic [  AhbAddrWidth-1:0] haddr,
    input  logic [               2:0] hburst,
    input  logic [               3:0] hprot,
    input  logic [               2:0] hsize,
    input  logic [               1:0] htrans,
    input  logic [  AhbDataWidth-1:0] hwdata,
    input  logic [AhbDataWidth/8-1:0] hwstrb,
    input  logic                      hwrite,
    output logic [  AhbDataWidth-1:0] hrdata,
    output logic                      hreadyout,
    output logic                      hresp,
    input  logic                      hsel,
    input  logic                      hready,

`elsif I3C_USE_AXI
    // AXI4 Interface
    input                           aclk,      // clock
    input                           areset_n,  // active low reset
    // AXI Read Channels
    input  logic [AxiAddrWidth-1:0] araddr,
    input  logic [             1:0] arburst,
    input  logic [             2:0] arsize,
    input  logic [             7:0] arlen,
    input  logic [AxiUserWidth-1:0] aruser,
    input  logic [  AxiIdWidth-1:0] arid,
    input  logic                    arlock,
    input  logic                    arvalid,
    output logic                    arready,

    output logic [AxiDataWidth-1:0] rdata,
    output logic [             1:0] rresp,
    output logic [  AxiIdWidth-1:0] rid,
    output logic [AxiUserWidth-1:0] ruser,
    output logic                    rlast,
    output logic                    rvalid,
    input  logic                    rready,

    // AXI Write Channels
    input  logic [AxiAddrWidth-1:0] awaddr,
    input  logic [             1:0] awburst,
    input  logic [             2:0] awsize,
    input  logic [             7:0] awlen,
    input  logic [AxiUserWidth-1:0] awuser,
    input  logic [  AxiIdWidth-1:0] awid,
    input  logic                    awlock,
    input  logic                    awvalid,
    output logic                    awready,

    input  logic [  AxiDataWidth-1:0] wdata,
    input  logic [AxiDataWidth/8-1:0] wstrb,
    input  logic [  AxiUserWidth-1:0] wuser,
    input  logic                      wlast,
    input  logic                      wvalid,
    output logic                      wready,

    output logic [             1:0] bresp,
    output logic [  AxiIdWidth-1:0] bid,
    output logic [AxiUserWidth-1:0] buser,
    output logic                    bvalid,
    input  logic                    bready,

`ifdef AXI_ID_FILTERING
    input  logic                             disable_id_filtering_i,
    input  logic [         AxiUserWidth-1:0] priv_ids_i                [NumPrivIds],
`endif  // AXI_ID_FILTERING
`endif  // I3C_USE_AXI
    // HCI queues (FSM side)
`ifdef CONTROLLER_SUPPORT
    // Response queue
    output logic [     HciRespThldWidth-1:0] hci_resp_ready_thld_o,
    output logic                             hci_resp_full_o,
    output logic [HciRespFifoDepthWidth-1:0] hci_resp_depth_o,
    output logic                             hci_resp_ready_thld_trig_o,
    output logic                             hci_resp_empty_o,
    input  logic                             hci_resp_wvalid_i,
    output logic                             hci_resp_wready_o,
    input  logic [     HciRespDataWidth-1:0] hci_resp_wdata_i,

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
`endif  // CONTROLLER_SUPPORT
    // Target Transaction Interface
`ifdef TARGET_SUPPORT
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
    input logic tti_rx_flush_i,

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
    input logic tti_tx_flush_i,

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

    input logic bypass_i3c_core_i,

    // S/Sr and P bus condition
    input logic bus_start_i,
    input logic bus_stop_i,

    // Received I2C/I3C address along with RnW# bit
    input logic [7:0] bus_addr_i,
    input logic bus_addr_valid_i,

    output logic payload_available_o,
    output logic image_activated_o,
    output logic irq_o,
`endif  // TARGET_SUPPORT

    input logic [7:0] rst_action_i
);

  logic clk_i, rst_ni;

  always_comb begin : wire_clk
`ifdef I3C_USE_AHB
    clk_i  = hclk;
    rst_ni = hreset_n;
`elsif I3C_USE_AXI
    clk_i  = aclk;
    rst_ni = areset_n;
`endif
  end

  // CSR Interface
`ifdef TARGET_SUPPORT
  // Target Transaction CSR Interface
  I3CCSR_pkg::I3CCSR__I3C_EC__TTI__out_t hwif_tti_out;
  I3CCSR_pkg::I3CCSR__I3C_EC__TTI__in_t hwif_tti_in;

  // Recovery CSR Interface
  I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__out_t hwif_rec_out;
  I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__in_t hwif_rec_in;

  // SoC Management CSR Interface
  I3CCSR_pkg::I3CCSR__I3C_EC__SoCMgmtIf__in_t hwif_soc_mgmt_in;
  I3CCSR_pkg::I3CCSR__I3C_EC__SoCMgmtIf__out_t hwif_soc_mgmt_out;
`endif  // TARGET_SUPPORT

`ifdef CONTROLLER_SUPPORT
  // PIO CONTROL CSR interface
  I3CCSR_pkg::I3CCSR__PIOControl__out_t hwif_pio_control_out;
  I3CCSR_pkg::I3CCSR__PIOControl__in_t hwif_pio_control_in;

  // I3C BASE CSR interface
  I3CCSR_pkg::I3CCSR__I3CBase__out_t hwif_base_out;
  I3CCSR_pkg::I3CCSR__I3CBase__in_t hwif_base_in;

  // DAT CSR interface
  I3CCSR_pkg::I3CCSR__DAT__out_t dat_out;
  I3CCSR_pkg::I3CCSR__DAT__in_t dat_in;

  // DCT CSR interface
  I3CCSR_pkg::I3CCSR__DCT__out_t dct_out;
  I3CCSR_pkg::I3CCSR__DCT__in_t dct_in;
`endif  // CONTROLLER_SUPPORT
  I3CCSR_pkg::I3CCSR__out_t unused_hwif_out;

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

`ifdef I3C_USE_AHB
  ahb_if #(
      .AhbDataWidth(AhbDataWidth),
      .AhbAddrWidth(AhbAddrWidth)
  ) i3c_ahb_if (
      .hclk_i(clk_i),
      .hreset_n_i(rst_ni),
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
`elsif I3C_USE_AXI
  axi_adapter #(
      .AxiDataWidth(AxiDataWidth),
      .AxiAddrWidth(AxiAddrWidth),
      .AxiUserWidth(AxiUserWidth),
      .AxiIdWidth  (AxiIdWidth)
  ) i3c_axi_if (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

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
      .ruser_o(ruser),
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
      .wuser_i (wuser),
      .wlast_i (wlast),
      .wvalid_i(wvalid),
      .wready_o(wready),

      .bresp_o(bresp),
      .bid_o(bid),
      .buser_o(buser),
      .bvalid_o(bvalid),
      .bready_i(bready),

`ifdef AXI_ID_FILTERING
      .disable_id_filtering_i(disable_id_filtering_i),
      .priv_ids_i(priv_ids_i),
`endif
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
      .s_cpuif_wr_err
  );
`endif

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

`ifdef CONTROLLER_SUPPORT
  hci #(
      .HciRespFifoDepth(HciRespFifoDepth),
      .HciCmdFifoDepth (HciCmdFifoDepth),
      .HciRxFifoDepth  (HciRxFifoDepth),
      .HciTxFifoDepth  (HciTxFifoDepth),
      .HciIbiFifoDepth (HciIbiFifoDepth),
      .HciRespDataWidth(HciRespDataWidth),
      .HciCmdDataWidth (HciCmdDataWidth),
      .HciRxDataWidth  (HciRxDataWidth),
      .HciTxDataWidth  (HciTxDataWidth),
      .HciIbiDataWidth (HciIbiDataWidth),
      .HciRespThldWidth(HciRespThldWidth),
      .HciCmdThldWidth (HciCmdThldWidth),
      .HciRxThldWidth  (HciRxThldWidth),
      .HciTxThldWidth  (HciTxThldWidth),
      .HciIbiThldWidth (HciIbiThldWidth)
  ) hci (
      .clk_i (clk_i),  // clock
      .rst_ni(rst_ni), // active low reset

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

      // CSR Interface
      .hwif_pio_control_i(hwif_pio_control_out),
      .hwif_pio_control_o(hwif_pio_control_in),
      .hwif_base_i(hwif_base_out),
      .hwif_base_o(hwif_base_in),
      .dat_i(dat_out),
      .dat_o(dat_in),
      .dct_i(dct_out),
      .dct_o(dct_in),

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

      .rst_action_i
  );
`endif  // CONTROLLER_SUPPORT
`ifdef TARGET_SUPPORT
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
  logic                          csr_tti_rx_desc_queue_ready_thld_trig;

  // TTI TX Descriptor queue
  logic                          csr_tti_tx_desc_queue_req;
  logic                          csr_tti_tx_desc_queue_ack;
  logic [      CsrDataWidth-1:0] csr_tti_tx_desc_queue_data;
  logic [TtiTxDescThldWidth-1:0] csr_tti_tx_desc_queue_ready_thld_i;
  logic [TtiTxDescThldWidth-1:0] csr_tti_tx_desc_queue_ready_thld_o;
  logic                          csr_tti_tx_desc_queue_reg_rst;
  logic                          csr_tti_tx_desc_queue_reg_rst_we;
  logic                          csr_tti_tx_desc_queue_reg_rst_data;
  logic                          csr_tti_tx_desc_full_o;
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
  logic                          csr_tti_rx_data_queue_ready_thld_trig;

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
  logic                          csr_tti_tx_data_queue_full;

  // TTI In-band Interrupt (IBI) queue
  logic                          csr_tti_ibi_queue_req;
  logic                          csr_tti_ibi_queue_ack;
  logic [      CsrDataWidth-1:0] csr_tti_ibi_queue_data;
  logic [   TtiIbiThldWidth-1:0] csr_tti_ibi_queue_ready_thld;
  logic                          csr_tti_ibi_queue_reg_rst;
  logic                          csr_tti_ibi_queue_reg_rst_we;
  logic                          csr_tti_ibi_queue_reg_rst_data;

  tti xtti (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .hwif_tti_i(hwif_tti_out),
      .hwif_tti_o(hwif_tti_in),

      // TTI RX descriptors queue
      .rx_desc_queue_req_o            (csr_tti_rx_desc_queue_req),
      .rx_desc_queue_ack_i            (csr_tti_rx_desc_queue_ack),
      .rx_desc_queue_data_i           (csr_tti_rx_desc_queue_data),
      .rx_desc_queue_ready_thld_o     (csr_tti_rx_desc_queue_ready_thld_i),
      .rx_desc_queue_ready_thld_i     (csr_tti_rx_desc_queue_ready_thld_o),
      .rx_desc_queue_reg_rst_o        (csr_tti_rx_desc_queue_reg_rst),
      .rx_desc_queue_reg_rst_we_i     (csr_tti_rx_desc_queue_reg_rst_we),
      .rx_desc_queue_reg_rst_data_i   (csr_tti_rx_desc_queue_reg_rst_data),
      .rx_desc_queue_ready_thld_trig_i(csr_tti_rx_desc_queue_ready_thld_trig),

      .rx_desc_queue_empty_i(tti_rx_desc_empty_o),
      .rx_desc_queue_full_i (tti_rx_desc_full_o),
      .rx_desc_queue_write_i(tti_rx_desc_wvalid_i & tti_rx_desc_wready_o),


      // TTI TX descriptors queue
      .tx_desc_queue_req_o         (csr_tti_tx_desc_queue_req),
      .tx_desc_queue_ack_i         (csr_tti_tx_desc_queue_ack),
      .tx_desc_queue_data_o        (csr_tti_tx_desc_queue_data),
      .tx_desc_queue_ready_thld_o  (csr_tti_tx_desc_queue_ready_thld_i),
      .tx_desc_queue_ready_thld_i  (csr_tti_tx_desc_queue_ready_thld_o),
      .tx_desc_queue_reg_rst_o     (csr_tti_tx_desc_queue_reg_rst),
      .tx_desc_queue_reg_rst_we_i  (csr_tti_tx_desc_queue_reg_rst_we),
      .tx_desc_queue_reg_rst_data_i(csr_tti_tx_desc_queue_reg_rst_data),
      .tx_desc_queue_full_i        (csr_tti_tx_desc_full_o),

      // TTI RX queue
      .rx_data_queue_req_o            (csr_tti_rx_data_queue_req),
      .rx_data_queue_ack_i            (csr_tti_rx_data_queue_ack),
      .rx_data_queue_data_i           (csr_tti_rx_data_queue_data),
      .rx_data_queue_start_thld_o     (csr_tti_rx_data_queue_start_thld),
      .rx_data_queue_ready_thld_o     (csr_tti_rx_data_queue_ready_thld_i),
      .rx_data_queue_ready_thld_i     (csr_tti_rx_data_queue_ready_thld_o),
      .rx_data_queue_reg_rst_o        (csr_tti_rx_data_queue_reg_rst),
      .rx_data_queue_reg_rst_we_i     (csr_tti_rx_data_queue_reg_rst_we),
      .rx_data_queue_reg_rst_data_i   (csr_tti_rx_data_queue_reg_rst_data),
      .rx_data_queue_ready_thld_trig_i(csr_tti_rx_data_queue_ready_thld_trig),

      .rx_data_queue_empty_i(tti_rx_empty_o),
      .rx_data_queue_full_i (tti_rx_full_o),
      .rx_data_queue_write_i(tti_rx_wvalid_i & tti_rx_wready_o),

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
      .tx_data_queue_full_i        (csr_tti_tx_data_queue_full),

      // TTI In-band Interrupt (IBI) queue
      .ibi_queue_req_o         (csr_tti_ibi_queue_req),
      .ibi_queue_ack_i         (csr_tti_ibi_queue_ack),
      .ibi_queue_data_o        (csr_tti_ibi_queue_data),
      .ibi_queue_ready_thld_o  (csr_tti_ibi_queue_ready_thld),
      .ibi_queue_reg_rst_o     (csr_tti_ibi_queue_reg_rst),
      .ibi_queue_reg_rst_we_i  (csr_tti_ibi_queue_reg_rst_we),
      .ibi_queue_reg_rst_data_i(csr_tti_ibi_queue_reg_rst_data),
      .ibi_queue_full_i        (tti_ibi_full_o),

      .bypass_i3c_core_i,

      .ibi_status_i('0),
      .ibi_status_we_i('0),
      .recovery_mode_enabled_i('0),
      .tx_pr_end_i('0),

      .enec_ibi_i('0),
      .enec_crr_i('0),
      .enec_hj_i ('0),

      .disec_ibi_i('0),
      .disec_crr_i('0),
      .disec_hj_i ('0),

      .err_i('0),

      // Interrupt
      .tx_pr_start_i('0),
      .irq_o(unused_irq)
  );
`endif  // TARGET_SUPPORT

  csri #(
      .CsrAddrWidth(CsrAddrWidth),
      .CsrDataWidth(CsrDataWidth)
  ) xcsri (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

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

      // CSR Interface
`ifdef TARGET_SUPPORT
      .hwif_tti_i(hwif_tti_in),
      .hwif_tti_o(hwif_tti_out),
      .hwif_rec_i(hwif_rec_in),
      .hwif_rec_o(hwif_rec_out),
      .hwif_socmgmt_i(hwif_soc_mgmt_in),
      .hwif_socmgmt_o(hwif_soc_mgmt_out),
`endif  // TARGET_SUPPORT
`ifdef CONTROLLER_SUPPORT
      .hwif_pio_control_i(hwif_pio_control_in),
      .hwif_pio_control_o(hwif_pio_control_out),
      .hwif_base_i(hwif_base_in),
      .hwif_base_o(hwif_base_out),
      .dat_i(dat_in),
      .dat_o(dat_out),
      .dct_i(dct_in),
      .dct_o(dct_out),
`endif  // CONTROLLER_SUPPORT
      .hwif_out_o(unused_hwif_out),

      // Controller configuration status
      .set_dasa_i('0),
      .set_dasa_valid_i('0),
      .set_dasa_virtual_device_i('0),
      .rstdaa_i('0),

      .rst_action_i,
      .rst_action_valid_i('0)
  );
`ifdef TARGET_SUPPORT
  logic unused_recovery_mode_enter;
  logic recovery_mode_enabled;

  // Recovery handler
  recovery_handler xrecovery_handler (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      // SoC Management CSR interface
      .hwif_socmgmt_i(hwif_soc_mgmt_out),
      .hwif_socmgmt_o(hwif_soc_mgmt_in),

      // Recovery CSR interface
      .hwif_rec_i(hwif_rec_out),
      .hwif_rec_o(hwif_rec_in),

      // I3C Core bypass
      .bypass_i3c_core_i,

      // Interrupt
      .irq_o(irq_o),

      // Recovery status
      .payload_available_o(payload_available_o),
      .image_activated_o  (image_activated_o),

      // ...........................
      // TTI CSR interface

      // TTI RX descriptors queue
      .csr_tti_rx_desc_queue_req_i            (csr_tti_rx_desc_queue_req),
      .csr_tti_rx_desc_queue_ack_o            (csr_tti_rx_desc_queue_ack),
      .csr_tti_rx_desc_queue_data_o           (csr_tti_rx_desc_queue_data),
      .csr_tti_rx_desc_queue_ready_thld_i     (csr_tti_rx_desc_queue_ready_thld_i),
      .csr_tti_rx_desc_queue_ready_thld_o     (csr_tti_rx_desc_queue_ready_thld_o),
      .csr_tti_rx_desc_queue_reg_rst_i        (csr_tti_rx_desc_queue_reg_rst),
      .csr_tti_rx_desc_queue_reg_rst_we_o     (csr_tti_rx_desc_queue_reg_rst_we),
      .csr_tti_rx_desc_queue_reg_rst_data_o   (csr_tti_rx_desc_queue_reg_rst_data),
      .csr_tti_rx_desc_queue_ready_thld_trig_o(csr_tti_rx_desc_queue_ready_thld_trig),

      // TTI TX descriptors queue
      .csr_tti_tx_desc_queue_req_i         (csr_tti_tx_desc_queue_req),
      .csr_tti_tx_desc_queue_ack_o         (csr_tti_tx_desc_queue_ack),
      .csr_tti_tx_desc_queue_data_i        (csr_tti_tx_desc_queue_data),
      .csr_tti_tx_desc_queue_ready_thld_i  (csr_tti_tx_desc_queue_ready_thld_i),
      .csr_tti_tx_desc_queue_ready_thld_o  (csr_tti_tx_desc_queue_ready_thld_o),
      .csr_tti_tx_desc_queue_reg_rst_i     (csr_tti_tx_desc_queue_reg_rst),
      .csr_tti_tx_desc_queue_reg_rst_we_o  (csr_tti_tx_desc_queue_reg_rst_we),
      .csr_tti_tx_desc_queue_reg_rst_data_o(csr_tti_tx_desc_queue_reg_rst_data),
      .csr_tti_tx_desc_queue_full_o        (csr_tti_tx_desc_full_o),

      // TTI RX queue
      .csr_tti_rx_data_queue_req_i            (csr_tti_rx_data_queue_req),
      .csr_tti_rx_data_queue_ack_o            (csr_tti_rx_data_queue_ack),
      .csr_tti_rx_data_queue_data_o           (csr_tti_rx_data_queue_data),
      .csr_tti_rx_data_queue_start_thld_i     (csr_tti_rx_data_queue_start_thld),
      .csr_tti_rx_data_queue_ready_thld_i     (csr_tti_rx_data_queue_ready_thld_i),
      .csr_tti_rx_data_queue_ready_thld_o     (csr_tti_rx_data_queue_ready_thld_o),
      .csr_tti_rx_data_queue_reg_rst_i        (csr_tti_rx_data_queue_reg_rst),
      .csr_tti_rx_data_queue_reg_rst_we_o     (csr_tti_rx_data_queue_reg_rst_we),
      .csr_tti_rx_data_queue_reg_rst_data_o   (csr_tti_rx_data_queue_reg_rst_data),
      .csr_tti_rx_data_queue_ready_thld_trig_o(csr_tti_rx_data_queue_ready_thld_trig),

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
      .csr_tti_tx_data_queue_full_o        (csr_tti_tx_data_queue_full),

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
      .ctl_bus_stop_i (bus_stop_i),

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
      .ctl_tti_rx_data_queue_flush_i(tti_rx_flush_i),
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
      .ctl_tti_tx_data_queue_flush_i(tti_tx_flush_i),
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
      .ctl_tti_ibi_queue_ready_thld_trig_o(tti_ibi_ready_thld_trig_o),

      .recovery_mode_enter_o  (unused_recovery_mode_enter),
      .recovery_mode_enabled_o(recovery_mode_enabled),

      .virtual_device_sel_i('0),
      .xfer_in_progress_i  ('0)
  );
`endif  // TARGET_SUPPORT
endmodule
