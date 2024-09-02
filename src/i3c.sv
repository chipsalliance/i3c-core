// SPDX-License-Identifier: Apache-2.0

`include "i3c_defines.svh"

module i3c
  import i3c_pkg::*;
  import controller_pkg::*;
#(
`ifdef I3C_USE_AHB
    parameter int unsigned AhbDataWidth = `AHB_DATA_WIDTH,
    parameter int unsigned AhbAddrWidth = `AHB_ADDR_WIDTH,
`elsif I3C_USE_AXI
    parameter int unsigned AxiDataWidth = `AXI_DATA_WIDTH,
    parameter int unsigned AxiAddrWidth = `AXI_ADDR_WIDTH,
    parameter int unsigned AxiUserWidth = `AXI_USER_WIDTH,
    parameter int unsigned AxiIdWidth = `AXI_ID_WIDTH,
`endif
    parameter int unsigned DatAw = i3c_pkg::DatAw,
    parameter int unsigned DctAw = i3c_pkg::DctAw,

    parameter int unsigned CsrAddrWidth = I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH,
    parameter int unsigned CsrDataWidth = I3CCSR_pkg::I3CCSR_DATA_WIDTH,

    parameter int unsigned HciRespFifoDepth = `RESP_FIFO_DEPTH,
    parameter int unsigned HciCmdFifoDepth = `CMD_FIFO_DEPTH,
    parameter int unsigned HciRxFifoDepth = `RX_FIFO_DEPTH,
    parameter int unsigned HciTxFifoDepth = `TX_FIFO_DEPTH,
    parameter int unsigned HciIbiFifoDepth = (`IBI_FIFO_EXT_SIZE)
                                                ? (8 * `IBI_FIFO_DEPTH)
                                                : (`IBI_FIFO_DEPTH),

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

    parameter int unsigned TtiRespFifoDepth = `RESP_FIFO_DEPTH,
    parameter int unsigned TtiCmdFifoDepth = `CMD_FIFO_DEPTH,
    parameter int unsigned TtiRxFifoDepth = `RX_FIFO_DEPTH,
    parameter int unsigned TtiTxFifoDepth = `TX_FIFO_DEPTH,
    parameter int unsigned TtiIbiFifoDepth = (`IBI_FIFO_EXT_SIZE)
                                                ? (8 * `IBI_FIFO_DEPTH)
                                                : (`IBI_FIFO_DEPTH),

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
    input clk_i,  // clock
    input rst_ni, // active low reset

`ifdef I3C_USE_AHB
    // AHB-Lite interface
    // Byte address of the transfer
    input  logic [  AhbAddrWidth-1:0] haddr_i,
    // Indicates the number of bursts in a transfer
    input  logic [               2:0] hburst_i,     // Unhandled
    // Protection control; provides information on the access type
    input  logic [               3:0] hprot_i,      // Unhandled
    // Indicates the size of the transfer
    input  logic [               2:0] hsize_i,
    // Indicates the transfer type
    input  logic [               1:0] htrans_i,
    // Data for the write operation
    input  logic [  AhbDataWidth-1:0] hwdata_i,
    // Write strobes; Deasserted when write data lanes do not contain valid data
    input  logic [AhbDataWidth/8-1:0] hwstrb_i,     // Unhandled
    // Indicates write operation when asserted
    input  logic                      hwrite_i,
    // Read data
    output logic [  AhbDataWidth-1:0] hrdata_o,
    // Asserted indicates a finished transfer; Can be driven low to extend a transfer
    output logic                      hreadyout_o,
    // Transfer response, high when error occurred
    output logic                      hresp_o,
    // Indicates the subordinate is selected for the transfer
    input  logic                      hsel_i,
    // Indicates all subordinates have finished transfers
    input  logic                      hready_i,

`elsif I3C_USE_AXI
    // AXI4 Interface
    // AXI Read Channels
    input  logic [AxiAddrWidth-1:0] araddr_i,
    input  logic [             1:0] arburst_i,
    input  logic [             2:0] arsize_i,
    input  logic [             7:0] arlen_i,
    input  logic [AxiUserWidth-1:0] aruser_i,
    input  logic [  AxiIdWidth-1:0] arid_i,
    input  logic                    arlock_i,
    input  logic                    arvalid_i,
    output logic                    arready_o,

    output logic [AxiDataWidth-1:0] rdata_o,
    output logic [             1:0] rresp_o,
    output logic [  AxiIdWidth-1:0] rid_o,
    output logic                    rlast_o,
    output logic                    rvalid_o,
    input  logic                    rready_i,

    // AXI Write Channels
    input  logic [AxiAddrWidth-1:0] awaddr_i,
    input  logic [             1:0] awburst_i,
    input  logic [             2:0] awsize_i,
    input  logic [             7:0] awlen_i,
    input  logic [AxiUserWidth-1:0] awuser_i,
    input  logic [  AxiIdWidth-1:0] awid_i,
    input  logic                    awlock_i,
    input  logic                    awvalid_i,
    output logic                    awready_o,

    input  logic [AxiDataWidth-1:0] wdata_i,
    input  logic [             7:0] wstrb_i,
    input  logic                    wlast_i,
    input  logic                    wvalid_i,
    output logic                    wready_o,

    output logic [           1:0] bresp_o,
    output logic [AxiIdWidth-1:0] bid_o,
    output logic                  bvalid_o,
    input  logic                  bready_i,

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
  // IOs between PHY and I3C bus
  logic                          scl_o;
  logic                          scl_en_o;

  logic                          sda_o;
  logic                          sda_en_o;

  // I3C SW CSR IF
  logic                          s_cpuif_req;
  logic                          s_cpuif_req_is_wr;
  logic [      CsrAddrWidth-1:0] s_cpuif_addr;
  logic [      CsrDataWidth-1:0] s_cpuif_wr_data;
  logic [      CsrDataWidth-1:0] s_cpuif_wr_biten;
  logic                          s_cpuif_req_stall_wr;
  logic                          s_cpuif_req_stall_rd;
  logic                          s_cpuif_rd_ack;
  logic                          s_cpuif_rd_err;
  logic [      CsrDataWidth-1:0] s_cpuif_rd_data;
  logic                          s_cpuif_wr_ack;
  logic                          s_cpuif_wr_err;

  // Response queue
  logic                          hci_resp_queue_full;
  logic [  HciRespThldWidth-1:0] hci_resp_queue_ready_thld;
  logic                          hci_resp_queue_ready_thld_trig;
  logic                          hci_resp_queue_empty;
  logic                          hci_resp_queue_wvalid;
  logic                          hci_resp_queue_wready;
  logic [  HciRespDataWidth-1:0] hci_resp_queue_wdata;

  // Command queue
  logic                          hci_cmd_queue_full;
  logic [   HciCmdThldWidth-1:0] hci_cmd_queue_ready_thld;
  logic                          hci_cmd_queue_ready_thld_trig;
  logic                          hci_cmd_queue_empty;
  logic                          hci_cmd_queue_rvalid;
  logic                          hci_cmd_queue_rready;
  logic [   HciCmdDataWidth-1:0] hci_cmd_queue_rdata;

  // RX queue
  logic                          hci_rx_queue_full;
  logic [    HciRxThldWidth-1:0] hci_rx_queue_start_thld;
  logic                          hci_rx_queue_start_thld_trig;
  logic [    HciRxThldWidth-1:0] hci_rx_queue_ready_thld;
  logic                          hci_rx_queue_ready_thld_trig;
  logic                          hci_rx_queue_empty;
  logic                          hci_rx_queue_wvalid;
  logic                          hci_rx_queue_wready;
  logic [    HciRxDataWidth-1:0] hci_rx_queue_wdata;

  // TX queue
  logic                          hci_tx_queue_full;
  logic [    HciTxThldWidth-1:0] hci_tx_queue_start_thld;
  logic                          hci_tx_queue_start_thld_trig;
  logic [    HciTxThldWidth-1:0] hci_tx_queue_ready_thld;
  logic                          hci_tx_queue_ready_thld_trig;
  logic                          hci_tx_queue_empty;
  logic                          hci_tx_queue_rvalid;
  logic                          hci_tx_queue_rready;
  logic [    HciTxDataWidth-1:0] hci_tx_queue_rdata;

  // IBI queue
  logic                          ibi_queue_full;
  logic [   HciIbiThldWidth-1:0] ibi_queue_ready_thld;
  logic                          ibi_queue_ready_thld_trig;
  logic                          ibi_queue_empty;
  logic                          ibi_queue_wvalid;
  logic                          ibi_queue_wready;
  logic [   HciIbiDataWidth-1:0] ibi_queue_wdata;

  // DAT <-> Controller interface
  logic                          dat_read_valid_hw;
  logic [$clog2(`DAT_DEPTH)-1:0] dat_index_hw;
  logic [                  63:0] dat_rdata_hw;

  // DCT <-> Controller interface
  logic                          dct_write_valid_hw;
  logic                          dct_read_valid_hw;
  logic [$clog2(`DCT_DEPTH)-1:0] dct_index_hw;
  logic [                 127:0] dct_wdata_hw;
  logic [                 127:0] dct_rdata_hw;

  // TTI RX descriptors queue
  logic                          tti_tx_desc_queue_full;
  logic [TtiRxDescThldWidth-1:0] tti_tx_desc_queue_ready_thld;
  logic                          tti_tx_desc_queue_ready_thld_trig;
  logic                          tti_tx_desc_queue_empty;
  logic                          tti_tx_desc_queue_rvalid;
  logic                          tti_tx_desc_queue_rready;
  logic [TtiRxDescDataWidth-1:0] tti_tx_desc_queue_rdata;

  // TTI TX descriptors queue
  logic                          tti_rx_desc_queue_full;
  logic [TtiTxDescThldWidth-1:0] tti_rx_desc_queue_ready_thld;
  logic                          tti_rx_desc_queue_ready_thld_trig;
  logic                          tti_rx_desc_queue_empty;
  logic                          tti_rx_desc_queue_wvalid;
  logic                          tti_rx_desc_queue_wready;
  logic [TtiTxDescDataWidth-1:0] tti_rx_desc_queue_wdata;

  // TTI RX queue
  logic                          tti_rx_queue_full;
  logic [    TtiRxThldWidth-1:0] tti_rx_queue_start_thld;
  logic                          tti_rx_queue_start_thld_trig;
  logic [    TtiRxThldWidth-1:0] tti_rx_queue_ready_thld;
  logic                          tti_rx_queue_ready_thld_trig;
  logic                          tti_rx_queue_empty;
  logic                          tti_rx_queue_wvalid;
  logic                          tti_rx_queue_wready;
  logic [    TtiRxDataWidth-1:0] tti_rx_queue_wdata;

  // TTI TX queue
  logic                          tti_tx_queue_full;
  logic [    TtiTxThldWidth-1:0] tti_tx_queue_start_thld;
  logic                          tti_tx_queue_start_thld_trig;
  logic [    TtiTxThldWidth-1:0] tti_tx_queue_ready_thld;
  logic                          tti_tx_queue_ready_thld_trig;
  logic                          tti_tx_queue_empty;
  logic                          tti_tx_queue_rvalid;
  logic                          tti_tx_queue_rready;
  logic [    TtiTxDataWidth-1:0] tti_tx_queue_rdata;

  // In-band Interrupt queue
  logic                          tti_ibi_queue_full;
  logic [   TtiIbiThldWidth-1:0] tti_ibi_queue_ready_thld;
  logic                          tti_ibi_queue_ready_thld_trig;
  logic                          tti_ibi_queue_empty;
  logic                          tti_ibi_queue_rvalid;
  logic                          tti_ibi_queue_rready;
  logic [   TtiIbiDataWidth-1:0] tti_ibi_queue_rdata;

`ifdef I3C_USE_AHB
  ahb_if #(
      .AhbDataWidth(AhbDataWidth),
      .AhbAddrWidth(AhbAddrWidth)
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
      .AxiDataWidth(AxiDataWidth),
      .AxiAddrWidth(AxiAddrWidth),
      .AxiUserWidth(AxiUserWidth),
      .AxiIdWidth  (AxiIdWidth)
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

  logic phy2ctrl_scl[4];
  logic phy2ctrl_sda[4];
  logic ctrl2phy_scl[4];
  logic ctrl2phy_sda[4];

  // Configuration
  logic phy_en;
  logic [1:0] phy_mux_select;
  logic i2c_active_en;
  logic i2c_standby_en;
  logic i3c_active_en;
  logic i3c_standby_en;
  logic [19:0] t_hd_dat;
  logic [19:0] t_r;
  logic [19:0] t_bus_free;
  logic [19:0] t_bus_idle;
  logic [19:0] t_bus_available;

  controller #(
      .DatAw,
      .DctAw
  ) xcontroller (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .ctrl_scl_i(phy2ctrl_scl),
      .ctrl_sda_i(phy2ctrl_sda),
      .ctrl_scl_o(ctrl2phy_scl),
      .ctrl_sda_o(ctrl2phy_sda),

      // HCI Response queue
      .hci_resp_queue_empty_i(hci_resp_queue_empty),
      .hci_resp_queue_full_i(hci_resp_queue_full),
      .hci_resp_queue_ready_thld_i(hci_resp_queue_ready_thld),
      .hci_resp_queue_ready_thld_trig_i(hci_resp_queue_ready_thld_trig),
      .hci_resp_queue_wvalid_o(hci_resp_queue_wvalid),
      .hci_resp_queue_wready_i(hci_resp_queue_wready),
      .hci_resp_queue_wdata_o(hci_resp_queue_wdata),

      // HCI Command queue
      .hci_cmd_queue_empty_i(hci_cmd_queue_empty),
      .hci_cmd_queue_full_i(hci_cmd_queue_full),
      .hci_cmd_queue_ready_thld_i(hci_cmd_queue_ready_thld),
      .hci_cmd_queue_ready_thld_trig_i(hci_cmd_queue_ready_thld_trig),
      .hci_cmd_queue_rvalid_i(hci_cmd_queue_rvalid),
      .hci_cmd_queue_rready_o(hci_cmd_queue_rready),
      .hci_cmd_queue_rdata_i(hci_cmd_queue_rdata),

      // HCI RX queue
      .hci_rx_queue_empty_i(hci_rx_queue_empty),
      .hci_rx_queue_full_i(hci_rx_queue_full),
      .hci_rx_queue_ready_thld_i(hci_rx_queue_ready_thld),
      .hci_rx_queue_ready_thld_trig_i(hci_rx_queue_ready_thld_trig),
      .hci_rx_queue_wvalid_o(hci_rx_queue_wvalid),
      .hci_rx_queue_wready_i(hci_rx_queue_wready),
      .hci_rx_queue_wdata_o(hci_rx_queue_wdata),

      // HCI TX queue
      .hci_tx_queue_empty_i(hci_tx_queue_empty),
      .hci_tx_queue_full_i(hci_tx_queue_full),
      .hci_tx_queue_ready_thld_i(hci_tx_queue_ready_thld),
      .hci_tx_queue_ready_thld_trig_i(hci_tx_queue_ready_thld_trig),
      .hci_tx_queue_rvalid_i(hci_tx_queue_rvalid),
      .hci_tx_queue_rready_o(hci_tx_queue_rready),
      .hci_tx_queue_rdata_i(hci_tx_queue_rdata),

      // TTI: RX Descriptor
      .tti_rx_desc_queue_full_i(tti_rx_desc_queue_full),
      .tti_rx_desc_queue_ready_thld_i(tti_rx_desc_queue_ready_thld),
      .tti_rx_desc_queue_ready_thld_trig_i(tti_rx_desc_queue_ready_thld_trig),
      .tti_rx_desc_queue_empty_i(tti_rx_desc_queue_empty),
      .tti_rx_desc_queue_wvalid_o(tti_rx_desc_queue_wvalid),
      .tti_rx_desc_queue_wready_i(tti_rx_desc_queue_wready),
      .tti_rx_desc_queue_wdata_o(tti_rx_desc_queue_wdata),

      // TTI: RX Data
      .tti_rx_queue_full_i(tti_rx_queue_full),
      .tti_rx_queue_start_thld_i(tti_rx_queue_start_thld),
      .tti_rx_queue_start_thld_trig_i(tti_rx_queue_start_thld_trig),
      .tti_rx_queue_ready_thld_i(tti_rx_queue_ready_thld),
      .tti_rx_queue_ready_thld_trig_i(tti_rx_queue_ready_thld_trig),
      .tti_rx_queue_empty_i(tti_rx_queue_empty),
      .tti_rx_queue_wvalid_o(tti_rx_queue_wvalid),
      .tti_rx_queue_wready_i(tti_rx_queue_wready),
      .tti_rx_queue_wdata_o(tti_rx_queue_wdata),

      // TTI: TX Descriptor
      .tti_tx_desc_queue_full_i(tti_tx_desc_queue_full),
      .tti_tx_desc_queue_ready_thld_i(tti_tx_desc_queue_ready_thld),
      .tti_tx_desc_queue_ready_thld_trig_i(tti_tx_desc_queue_ready_thld),
      .tti_tx_desc_queue_empty_i(tti_tx_desc_queue_empty),
      .tti_tx_desc_queue_rvalid_i(tti_tx_desc_queue_rvalid),
      .tti_tx_desc_queue_rready_o(tti_tx_desc_queue_rready),
      .tti_tx_desc_queue_rdata_i(tti_tx_desc_queue_rdata),

      // TTI: TX Data
      .tti_tx_queue_full_i(tti_tx_queue_full),
      .tti_tx_queue_start_thld_i(tti_tx_queue_start_thld),
      .tti_tx_queue_start_thld_trig_i(tti_tx_queue_start_thld_trig),
      .tti_tx_queue_ready_thld_i(tti_tx_queue_ready_thld),
      .tti_tx_queue_ready_thld_trig_i(tti_tx_queue_ready_thld_trig),
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
      .phy_en_i(phy_en_i),
      .phy_mux_select_i(phy_mux_select),
      .i2c_active_en_i(i2c_active_en),
      .i2c_standby_en_i(i2c_standby_en),
      .i3c_active_en_i(i3c_active_en),
      .i3c_standby_en_i(i3c_standby_en),
      .t_hd_dat_i(t_hd_dat),
      .t_r_i(t_r),
      .t_bus_free_i(t_bus_free),
      .t_bus_idle_i(t_bus_idle),
      .t_bus_available_i(t_bus_available)
  );

  hci #(
      .CsrAddrWidth,
      .CsrDataWidth,
      .HciRespFifoDepth,
      .HciCmdFifoDepth,
      .HciRxFifoDepth,
      .HciTxFifoDepth,
      .HciIbiFifoDepth,
      .HciRespDataWidth,
      .HciCmdDataWidth,
      .HciRxDataWidth,
      .HciTxDataWidth,
      .HciRespThldWidth,
      .HciCmdThldWidth,
      .HciRxThldWidth,
      .HciTxThldWidth,
      .TtiRespFifoDepth,
      .TtiCmdFifoDepth,
      .TtiRxFifoDepth,
      .TtiTxFifoDepth,
      .TtiIbiFifoDepth,
      .TtiRxDescDataWidth,
      .TtiTxDescDataWidth,
      .TtiRxDataWidth,
      .TtiTxDataWidth,
      .TtiRxDescThldWidth,
      .TtiTxDescThldWidth,
      .TtiRxThldWidth,
      .TtiTxThldWidth
  ) xhci (
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
      .hci_resp_full_o(hci_resp_queue_full),
      .hci_resp_ready_thld_o(hci_resp_queue_ready_thld),
      .hci_resp_ready_thld_trig_o(hci_resp_queue_ready_thld_trig),
      .hci_resp_empty_o(hci_resp_queue_empty),
      .hci_resp_wvalid_i(hci_resp_queue_wvalid),
      .hci_resp_wready_o(hci_resp_queue_wready),
      .hci_resp_wdata_i(hci_resp_queue_wdata),

      // HCI Command queue
      .hci_cmd_full_o(hci_cmd_queue_full),
      .hci_cmd_ready_thld_o(hci_cmd_queue_ready_thld),
      .hci_cmd_ready_thld_trig_o(hci_cmd_queue_ready_thld_trig),
      .hci_cmd_empty_o(hci_cmd_queue_empty),
      .hci_cmd_rvalid_o(hci_cmd_queue_rvalid),
      .hci_cmd_rready_i(hci_cmd_queue_rready),
      .hci_cmd_rdata_o(hci_cmd_queue_rdata),

      // HCI RX queue
      .hci_rx_full_o(hci_rx_queue_full),
      .hci_rx_start_thld_o(hci_rx_queue_start_thld),
      .hci_rx_start_thld_trig_o(hci_rx_queue_start_thld_trig),
      .hci_rx_ready_thld_o(hci_rx_queue_ready_thld),
      .hci_rx_ready_thld_trig_o(hci_rx_queue_ready_thld_trig),
      .hci_rx_empty_o(hci_rx_queue_empty),
      .hci_rx_wvalid_i(hci_rx_queue_wvalid),
      .hci_rx_wready_o(hci_rx_queue_wready),
      .hci_rx_wdata_i(hci_rx_queue_wdata),

      // HCI TX queue
      .hci_tx_full_o(hci_tx_queue_full),
      .hci_tx_start_thld_o(hci_tx_queue_start_thld),
      .hci_tx_start_thld_trig_o(hci_tx_queue_start_thld_trig),
      .hci_tx_ready_thld_o(hci_tx_queue_ready_thld),
      .hci_tx_ready_thld_trig_o(hci_tx_queue_ready_thld_trig),
      .hci_tx_empty_o(hci_tx_queue_empty),
      .hci_tx_rvalid_o(hci_tx_queue_rvalid),
      .hci_tx_rready_i(hci_tx_queue_rready),
      .hci_tx_rdata_o(hci_tx_queue_rdata),

      .hci_ibi_queue_full_o(ibi_queue_full),
      .hci_ibi_queue_ready_thld_o(ibi_queue_ready_thld),
      .hci_ibi_queue_ready_thld_trig_o(ibi_queue_ready_thld_trig),
      .hci_ibi_queue_empty_o(ibi_queue_empty),
      .hci_ibi_queue_wvalid_i(ibi_queue_wvalid),
      .hci_ibi_queue_wready_o(ibi_queue_wready),
      .hci_ibi_queue_wdata_i(ibi_queue_wdata),

      // TTI RX descriptors queue
      .tti_rx_desc_queue_full_o(tti_rx_desc_queue_full),
      .tti_rx_desc_queue_ready_thld_o(tti_rx_desc_queue_ready_thld),
      .tti_rx_desc_queue_ready_thld_trig_o(tti_rx_desc_queue_above_thld_trig),
      .tti_rx_desc_queue_empty_o(tti_rx_desc_queue_empty),
      .tti_rx_desc_queue_wvalid_i(tti_rx_desc_queue_wvalid),
      .tti_rx_desc_queue_wready_o(tti_rx_desc_queue_wready),
      .tti_rx_desc_queue_wdata_i(tti_rx_desc_queue_wdata),

      // TTI TX descriptors queue
      .tti_tx_desc_queue_full_o(tti_tx_desc_queue_full),
      .tti_tx_desc_queue_ready_thld_o(tti_tx_desc_queue_ready_thld),
      .tti_tx_desc_queue_ready_thld_trig_o(tti_tx_desc_queue_ready_thld_trig),
      .tti_tx_desc_queue_empty_o(tti_tx_desc_queue_empty),
      .tti_tx_desc_queue_rvalid_o(tti_tx_desc_queue_rvalid),
      .tti_tx_desc_queue_rready_i(tti_tx_desc_queue_rready),
      .tti_tx_desc_queue_rdata_o(tti_tx_desc_queue_rdata),

      // TTI RX queue
      .tti_rx_queue_full_o(tti_rx_queue_full),
      .tti_rx_queue_start_thld_o(tti_rx_queue_start_thld),
      .tti_rx_queue_start_thld_trig_o(tti_rx_queue_start_thld_trig),
      .tti_rx_queue_ready_thld_o(tti_rx_queue_ready_thld),
      .tti_rx_queue_ready_thld_trig_o(tti_rx_queue_ready_thld_trig),
      .tti_rx_queue_empty_o(tti_rx_queue_empty),
      .tti_rx_queue_wvalid_i(tti_rx_queue_wvalid),
      .tti_rx_queue_wready_o(tti_rx_queue_wready),
      .tti_rx_queue_wdata_i(tti_rx_queue_wdata),

      // TTI TX queue
      .tti_tx_queue_full_o(tti_tx_queue_full),
      .tti_tx_queue_start_thld_o(tti_tx_queue_start_thld),
      .tti_tx_queue_start_thld_trig_o(tti_tx_queue_start_thld_trig),
      .tti_tx_queue_ready_thld_o(tti_tx_queue_ready_thld),
      .tti_tx_queue_ready_thld_trig_o(tti_tx_queue_ready_thld_trig),
      .tti_tx_queue_empty_o(tti_tx_queue_empty),
      .tti_tx_queue_rvalid_o(tti_tx_queue_rvalid),
      .tti_tx_queue_rready_i(tti_tx_queue_rready),
      .tti_tx_queue_rdata_o(tti_tx_queue_rdata),

      // In-band Interrupt queue
      .tti_ibi_queue_full_o(tti_ibi_queue_full),
      .tti_ibi_queue_ready_thld_o(tti_ibi_queue_ready_thld),
      .tti_ibi_queue_ready_thld_trig_o(tti_ibi_queue_ready_thld_trig),
      .tti_ibi_queue_empty_o(tti_ibi_queue_empty),
      .tti_ibi_queue_rvalid_o(tti_ibi_queue_rvalid),
      .tti_ibi_queue_rready_i(tti_ibi_queue_rready),
      .tti_ibi_queue_rdata_o(tti_ibi_queue_rdata),

      .phy_en_o(phy_en),
      .phy_mux_select_o(phy_mux_select),
      .i2c_active_en_o(i2c_active_en),
      .i2c_standby_en_o(i2c_standby_en),
      .i3c_active_en_o(i3c_active_en),
      .i3c_standby_en_o(i3c_standby_en),
      .t_hd_dat_o(t_hd_dat),
      .t_r_o(t_r),
      .t_bus_free_o(t_bus_free),
      .t_bus_idle_o(t_bus_idle),
      .t_bus_available_o(t_bus_available)
  );

  // I3C muxed PHY
  i3c_muxed_phy xi3c_muxed_phy (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .select_i(phy_mux_select),

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
