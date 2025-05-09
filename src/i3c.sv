// SPDX-License-Identifier: Apache-2.0

`include "i3c_defines.svh"

/*
    This module is the top level view of the I3C Controller without the I3C bus I/O integration.

    The interfaces of this module are:
      - configurable frontend bus: either AXI or AHB
      - I3C bus connections
      - DCT/DAT Memory interfaces
      - interrupts

    The I3C IO connections are modeled by pins:
      - i3c_{scl|sda}_i: Input from the bus
      - i3c_{scl|sda}_o: Output to the bus
      - sel_od_pp_o: Select driver

      The sel_od_pp_o signal is synchronized with the {scl,sda} pins.
*/
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
`ifdef AXI_ID_FILTERING
    parameter int unsigned NumPrivIds = `NUM_PRIV_IDS,
`endif
`endif
    parameter int unsigned DatAw = i3c_pkg::DatAw,
    parameter int unsigned DctAw = i3c_pkg::DctAw,

    parameter int unsigned CsrAddrWidth = I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH,
    parameter int unsigned CsrDataWidth = I3CCSR_pkg::I3CCSR_DATA_WIDTH,

`ifdef CONTROLLER_SUPPORT
    parameter int unsigned HciRespFifoDepth = `RESP_FIFO_DEPTH,
    parameter int unsigned HciCmdFifoDepth = `CMD_FIFO_DEPTH,
    parameter int unsigned HciRxFifoDepth = `RX_FIFO_DEPTH,
    parameter int unsigned HciTxFifoDepth = `TX_FIFO_DEPTH,
`ifdef IBI_FIFO_EXT_SIZE
    parameter int unsigned HciIbiFifoDepth = 8 * `IBI_FIFO_DEPTH,
`else
    parameter int unsigned HciIbiFifoDepth = `IBI_FIFO_DEPTH,
`endif

    localparam int unsigned HciRespFifoDepthWidth = $clog2(HciRespFifoDepth + 1),
    localparam int unsigned HciCmdFifoDepthWidth  = $clog2(HciCmdFifoDepth + 1),
    localparam int unsigned HciTxFifoDepthWidth   = $clog2(HciTxFifoDepth + 1),
    localparam int unsigned HciRxFifoDepthWidth   = $clog2(HciRxFifoDepth + 1),
    localparam int unsigned HciIbiFifoDepthWidth  = $clog2(HciIbiFifoDepth + 1),

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
`endif // CONTROLLER_SUPPORT
`ifdef TARGET_SUPPORT
    parameter int unsigned TtiRxDescFifoDepth = `RESP_FIFO_DEPTH,
    parameter int unsigned TtiTxDescFifoDepth = `CMD_FIFO_DEPTH,
    parameter int unsigned TtiRxFifoDepth = `RX_FIFO_DEPTH,
    parameter int unsigned TtiTxFifoDepth = `TX_FIFO_DEPTH,
`ifdef IBI_FIFO_EXT_SIZE
    parameter int unsigned TtiIbiFifoDepth = 8 * `IBI_FIFO_DEPTH,
`else
    parameter int unsigned TtiIbiFifoDepth = `IBI_FIFO_DEPTH,
`endif
    localparam int unsigned TtiTxDescFifoDepthWidth = $clog2(TtiTxDescFifoDepth + 1),
    localparam int unsigned TtiRxDescFifoDepthWidth = $clog2(TtiRxDescFifoDepth + 1),
    localparam int unsigned TtiTxFifoDepthWidth = $clog2(TtiTxFifoDepth + 1),
    localparam int unsigned TtiRxFifoDepthWidth = $clog2(TtiRxFifoDepth + 1),
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
    parameter int unsigned TtiIbiThldWidth = 8,
`endif // TARGET_SUPPORT
    parameter int unsigned IndirectFifoDepth = 64
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
    output logic [AxiUserWidth-1:0] ruser_o,
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

    input  logic [  AxiDataWidth-1:0] wdata_i,
    input  logic [AxiDataWidth/8-1:0] wstrb_i,
    input  logic [  AxiUserWidth-1:0] wuser_i,
    input  logic                      wlast_i,
    input  logic                      wvalid_i,
    output logic                      wready_o,

    output logic [             1:0] bresp_o,
    output logic [  AxiIdWidth-1:0] bid_o,
    output logic [AxiUserWidth-1:0] buser_o,
    output logic                    bvalid_o,
    input  logic                    bready_i,
`ifdef AXI_ID_FILTERING
    // ID Filtering
    input logic disable_id_filtering_i,
    input logic [AxiUserWidth-1:0] priv_ids_i [NumPrivIds],
`endif
`endif

    // I3C bus IO

    // Level of the {scl,sda} pins is equal to the level on the bus.
    // For example, to pull down the bus in OD mode, the {scl,sda} should be set to 0.
    input  logic i3c_scl_i,  // serial clock input from i3c bus
    output logic i3c_scl_o,  // serial clock output to i3c bus

    input  logic i3c_sda_i,  // serial data input from i3c bus
    output logic i3c_sda_o,  // serial data output to i3c bus

    output logic sel_od_pp_o,  // 0 - Open Drain, 1 - Push Pull

`ifdef CONTROLLER_SUPPORT
    // DAT memory export interface
    input  dat_mem_src_t  dat_mem_src_i,
    output dat_mem_sink_t dat_mem_sink_o,

    // DCT memory export interface
    input  dct_mem_src_t  dct_mem_src_i,
    output dct_mem_sink_t dct_mem_sink_o,
`endif // CONTROLLER_SUPPORT

    // Recovery interface signals
    output logic recovery_payload_available_o,
    output logic recovery_image_activated_o,

    output logic peripheral_reset_o,
    input  logic peripheral_reset_done_i,
    output logic escalated_reset_o,

    // Interrupt output
    output logic irq_o
);

  // I3C SW CSR IF
  logic                    s_cpuif_req;
  logic                    s_cpuif_req_is_wr;
  logic [CsrAddrWidth-1:0] s_cpuif_addr;
  logic [CsrDataWidth-1:0] s_cpuif_wr_data;
  logic [CsrDataWidth-1:0] s_cpuif_wr_biten;
  logic                    s_cpuif_req_stall_wr;
  logic                    s_cpuif_req_stall_rd;
  logic                    s_cpuif_rd_ack;
  logic                    s_cpuif_rd_err;
  logic [CsrDataWidth-1:0] s_cpuif_rd_data;
  logic                    s_cpuif_wr_ack;
  logic                    s_cpuif_wr_err;

`ifdef CONTROLLER_SUPPORT
  // Response queue
  logic                             hci_resp_full;
  logic [HciRespFifoDepthWidth-1:0] hci_resp_depth;
  logic [     HciRespThldWidth-1:0] hci_resp_ready_thld;
  logic                             hci_resp_ready_thld_trig;
  logic                             hci_resp_empty;
  logic                             hci_resp_wvalid;
  logic                             hci_resp_wready;
  logic [     HciRespDataWidth-1:0] hci_resp_wdata;

  // Command queue
  logic                             hci_cmd_full;
  logic [ HciCmdFifoDepthWidth-1:0] hci_cmd_depth;
  logic [      HciCmdThldWidth-1:0] hci_cmd_ready_thld;
  logic                             hci_cmd_ready_thld_trig;
  logic                             hci_cmd_empty;
  logic                             hci_cmd_rvalid;
  logic                             hci_cmd_rready;
  logic [      HciCmdDataWidth-1:0] hci_cmd_rdata;

  // RX queue
  logic                             hci_rx_full;
  logic [  HciRxFifoDepthWidth-1:0] hci_rx_depth;
  logic [       HciRxThldWidth-1:0] hci_rx_start_thld;
  logic                             hci_rx_start_thld_trig;
  logic [       HciRxThldWidth-1:0] hci_rx_ready_thld;
  logic                             hci_rx_ready_thld_trig;
  logic                             hci_rx_empty;
  logic                             hci_rx_wvalid;
  logic                             hci_rx_wready;
  logic [       HciRxDataWidth-1:0] hci_rx_wdata;

  // TX queue
  logic                             hci_tx_full;
  logic [  HciTxFifoDepthWidth-1:0] hci_tx_depth;
  logic [       HciTxThldWidth-1:0] hci_tx_start_thld;
  logic                             hci_tx_start_thld_trig;
  logic [       HciTxThldWidth-1:0] hci_tx_ready_thld;
  logic                             hci_tx_ready_thld_trig;
  logic                             hci_tx_empty;
  logic                             hci_tx_rvalid;
  logic                             hci_tx_rready;
  logic [       HciTxDataWidth-1:0] hci_tx_rdata;

  // IBI queue
  logic                             hci_ibi_full;
  logic [ HciIbiFifoDepthWidth-1:0] hci_ibi_depth;
  logic [      HciIbiThldWidth-1:0] hci_ibi_ready_thld;
  logic                             hci_ibi_ready_thld_trig;
  logic                             hci_ibi_empty;
  logic                             hci_ibi_wvalid;
  logic                             hci_ibi_wready;
  logic [      HciIbiDataWidth-1:0] hci_ibi_wdata;

`ifdef CONTROLLER_SUPPORT
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
`endif // CONTROLLER_SUPPORT

`endif  // CONTROLLER_SUPPORT
`ifdef TARGET_SUPPORT
  // TTI TX descriptors queue
  logic                               tti_tx_desc_full;
  logic [TtiRxDescFifoDepthWidth-1:0] tti_tx_desc_depth;
  logic [     TtiRxDescThldWidth-1:0] tti_tx_desc_ready_thld;
  logic                               tti_tx_desc_ready_thld_trig;
  logic                               tti_tx_desc_empty;
  logic                               tti_tx_desc_rvalid;
  logic                               tti_tx_desc_rready;
  logic [     TtiRxDescDataWidth-1:0] tti_tx_desc_rdata;

  // TTI RX descriptors queue
  logic                               tti_rx_desc_full;
  logic [TtiTxDescFifoDepthWidth-1:0] tti_rx_desc_depth;
  logic [     TtiTxDescThldWidth-1:0] tti_rx_desc_ready_thld;
  logic                               tti_rx_desc_ready_thld_trig;
  logic                               tti_rx_desc_empty;
  logic                               tti_rx_desc_wvalid;
  logic                               tti_rx_desc_wready;
  logic [     TtiTxDescDataWidth-1:0] tti_rx_desc_wdata;

  // TTI RX queue
  logic                               tti_rx_full;
  logic [    TtiRxFifoDepthWidth-1:0] tti_rx_depth;
  logic [         TtiRxThldWidth-1:0] tti_rx_start_thld;
  logic                               tti_rx_start_thld_trig;
  logic [         TtiRxThldWidth-1:0] tti_rx_ready_thld;
  logic                               tti_rx_ready_thld_trig;
  logic                               tti_rx_empty;
  logic                               tti_rx_wvalid;
  logic                               tti_rx_wready;
  logic [                        7:0] tti_rx_wdata;
  logic                               tti_rx_flush;

  // TTI TX queue
  logic                               tti_tx_full;
  logic [    TtiTxFifoDepthWidth-1:0] tti_tx_depth;
  logic [         TtiTxThldWidth-1:0] tti_tx_start_thld;
  logic                               tti_tx_start_thld_trig;
  logic [         TtiTxThldWidth-1:0] tti_tx_ready_thld;
  logic                               tti_tx_ready_thld_trig;
  logic                               tti_tx_empty;
  logic                               tti_tx_rvalid;
  logic                               tti_tx_rready;
  logic [                        7:0] tti_tx_rdata;
  logic                               tti_tx_flush;

  logic                               tti_tx_host_nack;
  logic                               tti_tx_pr_end;
  logic                               tti_tx_pr_start;

  // In-band Interrupt queue
  logic                               tti_ibi_full;
  logic [   TtiIbiFifoDepthWidth-1:0] tti_ibi_depth;
  logic [        TtiIbiThldWidth-1:0] tti_ibi_ready_thld;
  logic                               tti_ibi_ready_thld_trig;
  //   logic [        TtiIbiDataWidth-1:0] tti_ibi_wr_data;
  logic                               tti_ibi_empty;
  logic                               tti_ibi_rvalid;
  logic                               tti_ibi_rready;
  logic [        TtiIbiDataWidth-1:0] tti_ibi_rdata;
`endif  // TARGET_SUPPORT

  // TODO: Fix these signals
  // Originally only used in active, should be removed and replaced with signal from CSR
  logic i3c_fsm_en_i;
  assign i3c_fsm_en_i = 1'b0;
  // This signal should only be used on level of fsm/flow modules. Expose it via CSR, if needed.
  logic i3c_fsm_idle_o;

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
`ifdef AXI_ID_FILTERING,
      .NumPrivIds  (NumPrivIds)
`endif
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
      .ruser_o(ruser_o),

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
      .wuser_i (wuser_i),
      .wlast_i (wlast_i),
      .wvalid_i(wvalid_i),
      .wready_o(wready_o),

      .bresp_o(bresp_o),
      .bid_o(bid_o),
      .bvalid_o(bvalid_o),
      .bready_i(bready_i),
      .buser_o(buser_o),

`ifdef AXI_ID_FILTERING
      .disable_id_filtering_i(disable_id_filtering_i),
      .priv_ids_i(priv_ids_i),
`endif

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

  logic phy2ctrl_scl;
  logic phy2ctrl_sda;
  logic ctrl2phy_scl;
  logic ctrl2phy_sda;
  logic ctrl_sel_od_pp;

  // Configuration
  logic phy_en;
  logic [1:0] phy_mux_select;
  logic i2c_active_en;
  logic i2c_standby_en;
  logic i3c_active_en;
  logic i3c_standby_en;
  logic [19:0] t_hd_dat;
  logic [19:0] t_su_dat;
  logic [19:0] t_r;
  logic [19:0] t_f;
  logic [19:0] t_bus_free;
  logic [19:0] t_bus_idle;
  logic [19:0] t_bus_available;
  logic [31:0] stby_cr_device_addr_reg;
  logic [31:0] stby_cr_device_char_reg;
  logic [31:0] stby_cr_device_pid_lo_reg;

  // Interrupts
  logic ctl_irq;
  logic tti_irq;
  logic recovery_irq;

  logic bus_start;
  logic bus_rstart;
  logic bus_stop;

  logic [7:0] rx_bus_addr;
  logic rx_bus_addr_valid;
  logic [6:0] set_dasa;
  logic set_dasa_valid;
  logic set_dasa_virtual_device;
  logic set_newda;
  logic set_newda_virtual_device;
  logic [6:0] newda;
  logic rstdaa;

  logic enec_ibi;
  logic enec_crr;
  logic enec_hj;
  logic disec_ibi;
  logic disec_crr;
  logic disec_hj;

  logic [7:0] rst_action;
  logic rst_action_valid;


  // Status
  logic [1:0] ibi_status;
  logic ibi_status_we;

  logic controller_error;

  logic recovery_mode_enter;
  logic recovery_mode_enabled;
  logic virtual_device_sel;
  logic xfer_in_progress;

  logic arbitration_lost;

  assign arbitration_lost = i3c_sda_i != i3c_sda_o;

  // CSR Interface
`ifdef TARGET_SUPPORT
  // Target Transaction CSR Interface
  I3CCSR_pkg::I3CCSR__I3C_EC__TTI__in_t hwif_tti_in;
  I3CCSR_pkg::I3CCSR__I3C_EC__TTI__out_t hwif_tti_out;

  // Recovery CSR Interface
  I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__in_t hwif_rec_in;
  I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__out_t hwif_rec_out;

  // SoC Management CSR Interface
  I3CCSR_pkg::I3CCSR__I3C_EC__SoCMgmtIf__in_t hwif_soc_mgmt_in;
  I3CCSR_pkg::I3CCSR__I3C_EC__SoCMgmtIf__out_t hwif_soc_mgmt_out;
`endif  // TARGET_SUPPORT

`ifdef CONTROLLER_SUPPORT
  // PIO CONTROL CSR interface
  I3CCSR_pkg::I3CCSR__PIOControl__in_t hwif_pio_control_in;
  I3CCSR_pkg::I3CCSR__PIOControl__out_t hwif_pio_control_out;

  // I3C BASE CSR interface
  I3CCSR_pkg::I3CCSR__I3CBase__in_t hwif_base_in;
  I3CCSR_pkg::I3CCSR__I3CBase__out_t hwif_base_out;

  // DAT CSR interface
  I3CCSR_pkg::I3CCSR__DAT__in_t dat_in;
  I3CCSR_pkg::I3CCSR__DAT__out_t dat_out;

  // DCT CSR interface
  I3CCSR_pkg::I3CCSR__DCT__in_t dct_in;
  I3CCSR_pkg::I3CCSR__DCT__out_t dct_out;
`endif  // CONTROLLER_SUPPORT

  I3CCSR_pkg::I3CCSR__out_t hwif_out;

  logic bypass_i3c_core;
`ifndef DISABLE_LOOPBACK
  assign bypass_i3c_core = hwif_out.I3C_EC.SoCMgmtIf.REC_INTF_CFG.REC_INTF_BYPASS.value;
`else
  assign bypass_i3c_core = '0;
`endif
  logic unused_err;

  controller #(
      .DatAw(DatAw),
      .DctAw(DctAw)
  ) xcontroller (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .scl_i(phy2ctrl_scl),
      .sda_i(phy2ctrl_sda),
      .scl_o(ctrl2phy_scl),
      .sda_o(ctrl2phy_sda),
      .sel_od_pp_o(ctrl_sel_od_pp),
      .arbitration_lost_i(arbitration_lost),

`ifdef CONTROLLER_SUPPORT
      // HCI Response queue
      .hci_resp_queue_empty_i(hci_resp_empty),
      .hci_resp_queue_full_i(hci_resp_full),
      .hci_resp_queue_depth_i(hci_resp_depth),
      .hci_resp_queue_ready_thld_i(hci_resp_ready_thld),
      .hci_resp_queue_ready_thld_trig_i(hci_resp_ready_thld_trig),
      .hci_resp_queue_wvalid_o(hci_resp_wvalid),
      .hci_resp_queue_wready_i(hci_resp_wready),
      .hci_resp_queue_wdata_o(hci_resp_wdata),

      // HCI Command queue
      .hci_cmd_queue_empty_i(hci_cmd_empty),
      .hci_cmd_queue_full_i(hci_cmd_full),
      .hci_cmd_queue_depth_i(hci_cmd_depth),
      .hci_cmd_queue_ready_thld_i(hci_cmd_ready_thld),
      .hci_cmd_queue_ready_thld_trig_i(hci_cmd_ready_thld_trig),
      .hci_cmd_queue_rvalid_i(hci_cmd_rvalid),
      .hci_cmd_queue_rready_o(hci_cmd_rready),
      .hci_cmd_queue_rdata_i(hci_cmd_rdata),

      // HCI RX queue
      .hci_rx_queue_empty_i(hci_rx_empty),
      .hci_rx_queue_full_i(hci_rx_full),
      .hci_rx_queue_depth_i(hci_rx_depth),
      .hci_rx_queue_start_thld_i(hci_rx_start_thld),
      .hci_rx_queue_start_thld_trig_i(hci_rx_start_thld_trig),
      .hci_rx_queue_ready_thld_i(hci_rx_ready_thld),
      .hci_rx_queue_ready_thld_trig_i(hci_rx_ready_thld_trig),
      .hci_rx_queue_wvalid_o(hci_rx_wvalid),
      .hci_rx_queue_wready_i(hci_rx_wready),
      .hci_rx_queue_wdata_o(hci_rx_wdata),

      // HCI TX queue
      .hci_tx_queue_empty_i(hci_tx_empty),
      .hci_tx_queue_full_i(hci_tx_full),
      .hci_tx_queue_depth_i(hci_tx_depth),
      .hci_tx_queue_start_thld_i(hci_tx_start_thld),
      .hci_tx_queue_start_thld_trig_i(hci_tx_start_thld_trig),
      .hci_tx_queue_ready_thld_i(hci_tx_ready_thld),
      .hci_tx_queue_ready_thld_trig_i(hci_tx_ready_thld_trig),
      .hci_tx_queue_rvalid_i(hci_tx_rvalid),
      .hci_tx_queue_rready_o(hci_tx_rready),
      .hci_tx_queue_rdata_i(hci_tx_rdata),

      // In-band Interrupt queue
      .hci_ibi_queue_full_i(hci_ibi_full),
      .hci_ibi_queue_depth_i(hci_ibi_depth),
      .hci_ibi_queue_ready_thld_i(hci_ibi_ready_thld),
      .hci_ibi_queue_ready_thld_trig_i(hci_ibi_ready_thld_trig),
      .hci_ibi_queue_empty_i(hci_ibi_empty),
      .hci_ibi_queue_wvalid_o(hci_ibi_wvalid),
      .hci_ibi_queue_wready_i(hci_ibi_wready),
      .hci_ibi_queue_wdata_o(hci_ibi_wdata),
`endif  // CONTROLLER_SUPPORT

`ifdef TARGET_SUPPORT
      // TTI: RX Descriptor
      .tti_rx_desc_queue_full_i(tti_rx_desc_full),
      .tti_rx_desc_queue_depth_i(tti_rx_desc_depth),
      .tti_rx_desc_queue_ready_thld_i(tti_rx_desc_ready_thld),
      .tti_rx_desc_queue_ready_thld_trig_i(tti_rx_desc_ready_thld_trig),
      .tti_rx_desc_queue_empty_i(tti_rx_desc_empty),
      .tti_rx_desc_queue_wvalid_o(tti_rx_desc_wvalid),
      .tti_rx_desc_queue_wready_i(tti_rx_desc_wready),
      .tti_rx_desc_queue_wdata_o(tti_rx_desc_wdata),

      // TTI: RX Data
      .tti_rx_queue_full_i(tti_rx_full),
      .tti_rx_queue_depth_i(tti_rx_depth),
      .tti_rx_queue_start_thld_i(tti_rx_start_thld),
      .tti_rx_queue_start_thld_trig_i(tti_rx_start_thld_trig),
      .tti_rx_queue_ready_thld_i(tti_rx_ready_thld),
      .tti_rx_queue_ready_thld_trig_i(tti_rx_ready_thld_trig),
      .tti_rx_queue_empty_i(tti_rx_empty),
      .tti_rx_queue_wvalid_o(tti_rx_wvalid),
      .tti_rx_queue_wready_i(tti_rx_wready),
      .tti_rx_queue_wdata_o(tti_rx_wdata),
      .tti_rx_queue_flush_o(tti_rx_flush),

      // TTI: TX Descriptor
      .tti_tx_desc_queue_full_i(tti_tx_desc_full),
      .tti_tx_desc_queue_depth_i(tti_tx_desc_depth),
      .tti_tx_desc_queue_ready_thld_i(tti_tx_desc_ready_thld),
      .tti_tx_desc_queue_ready_thld_trig_i(tti_tx_desc_ready_thld_trig),
      .tti_tx_desc_queue_empty_i(tti_tx_desc_empty),
      .tti_tx_desc_queue_rvalid_i(tti_tx_desc_rvalid),
      .tti_tx_desc_queue_rready_o(tti_tx_desc_rready),
      .tti_tx_desc_queue_rdata_i(tti_tx_desc_rdata),

      // TTI: TX Data
      .tti_tx_queue_full_i(tti_tx_full),
      .tti_tx_queue_depth_i(tti_tx_depth),
      .tti_tx_queue_start_thld_i(tti_tx_start_thld),
      .tti_tx_queue_start_thld_trig_i(tti_tx_start_thld_trig),
      .tti_tx_queue_ready_thld_i(tti_tx_ready_thld),
      .tti_tx_queue_ready_thld_trig_i(tti_tx_ready_thld_trig),
      .tti_tx_queue_empty_i(tti_tx_empty),
      .tti_tx_queue_rvalid_i(tti_tx_rvalid),
      .tti_tx_queue_rready_o(tti_tx_rready),
      .tti_tx_queue_rdata_i(tti_tx_rdata),
      .tti_tx_queue_flush_o(tti_tx_flush),
      .tti_tx_host_nack_o(tti_tx_host_nack),
      .tti_tx_pr_end_o(tti_tx_pr_end),
      .tti_tx_pr_start_o(tti_tx_pr_start),

      // TTI: In-band Interrupt queue
      .tti_ibi_queue_full_i(tti_ibi_full),
      .tti_ibi_queue_depth_i(tti_ibi_depth),
      .tti_ibi_queue_ready_thld_i(tti_ibi_ready_thld),
      .tti_ibi_queue_ready_thld_trig_i(tti_ibi_ready_thld_trig),
      .tti_ibi_queue_empty_i(tti_ibi_empty),
      .tti_ibi_queue_rvalid_i(tti_ibi_rvalid),
      .tti_ibi_queue_rready_o(tti_ibi_rready),
      .tti_ibi_queue_rdata_i(tti_ibi_rdata),
`endif  // TARGET_SUPPORT

      // I2C/I3C bus condition detection
      .bus_start_o (bus_start),
      .bus_rstart_o(bus_rstart),
      .bus_stop_o  (bus_stop),

      // I2C/I3C received address (with RnW# bit) for the recovery handler
      .bus_addr_o(rx_bus_addr),
      .bus_addr_valid_o(rx_bus_addr_valid),
`ifdef CONTROLLER_SUPPORT
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
`endif
      //TODO: Rename
      .i3c_fsm_en_i  (i3c_fsm_en_i),
      .i3c_fsm_idle_o(i3c_fsm_idle_o),

      .err(unused_err),  // TODO: Handle errors
      .irq(ctl_irq),
      .hwif_out_i(hwif_out),
      .hwif_rec_i(hwif_rec_out),

      .ibi_status_o(ibi_status),
      .ibi_status_we_o(ibi_status_we),

      .set_dasa_o(set_dasa),
      .set_dasa_valid_o(set_dasa_valid),
      .set_dasa_virtual_device_o(set_dasa_virtual_device),
      .rstdaa_o(rstdaa),
      .set_newda_o(set_newda),
      .set_newda_virtual_device_o(set_newda_virtual_device),
      .newda_o(newda),

      .rst_action_o(rst_action),
      .rst_action_valid_o(rst_action_valid),

      .enec_ibi_o (enec_ibi),
      .enec_crr_o (enec_crr),
      .enec_hj_o  (enec_hj),
      .disec_ibi_o(disec_ibi),
      .disec_crr_o(disec_crr),
      .disec_hj_o (disec_hj),

      .peripheral_reset_o,
      .peripheral_reset_done_i,
      .escalated_reset_o,

      .err_o(controller_error),
      .recovery_mode_enter_i(recovery_mode_enter),
      .virtual_device_sel_o(virtual_device_sel),
      .xfer_in_progress_o(xfer_in_progress)
  );

  // HCI
`ifdef CONTROLLER_SUPPORT
  hci #(
      .CsrAddrWidth(CsrAddrWidth),
      .CsrDataWidth(CsrDataWidth),
      .DatAw(DatAw),
      .DctAw(DctAw),
      .HciRespFifoDepth(HciRespFifoDepth),
      .HciCmdFifoDepth(HciCmdFifoDepth),
      .HciRxFifoDepth(HciRxFifoDepth),
      .HciTxFifoDepth(HciTxFifoDepth),
      .HciIbiFifoDepth(HciIbiFifoDepth),
      .HciRespDataWidth(HciRespDataWidth),
      .HciCmdDataWidth(HciCmdDataWidth),
      .HciRxDataWidth(HciRxDataWidth),
      .HciTxDataWidth(HciTxDataWidth),
      .HciRespThldWidth(HciRespThldWidth),
      .HciCmdThldWidth(HciCmdThldWidth),
      .HciRxThldWidth(HciRxThldWidth),
      .HciTxThldWidth(HciTxThldWidth)
  ) xhci (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .dat_read_valid_hw_i(dat_read_valid_hw),
      .dat_index_hw_i(dat_index_hw),
      .dat_rdata_hw_o(dat_rdata_hw),

      .dct_write_valid_hw_i(dct_write_valid_hw),
      .dct_read_valid_hw_i(dct_read_valid_hw),
      .dct_index_hw_i(dct_index_hw),
      .dct_wdata_hw_i(dct_wdata_hw),
      .dct_rdata_hw_o(dct_rdata_hw),

      .dat_mem_src_i (dat_mem_src_i),
      .dat_mem_sink_o(dat_mem_sink_o),

      .dct_mem_src_i (dct_mem_src_i),
      .dct_mem_sink_o(dct_mem_sink_o),

      // CSR Interface
      .hwif_pio_control_i(hwif_pio_control_out),
      .hwif_pio_control_o(hwif_pio_control_in),
      .hwif_base_i(hwif_base_out),
      .hwif_base_o(hwif_base_in),
      .dat_i(dat_out),
      .dat_o(dat_in),
      .dct_i(dct_out),
      .dct_o(dct_in),

      // HCI Response queue
      .hci_resp_full_o(hci_resp_full),
      .hci_resp_depth_o(hci_resp_depth),
      .hci_resp_ready_thld_o(hci_resp_ready_thld),
      .hci_resp_ready_thld_trig_o(hci_resp_ready_thld_trig),
      .hci_resp_empty_o(hci_resp_empty),
      .hci_resp_wvalid_i(hci_resp_wvalid),
      .hci_resp_wready_o(hci_resp_wready),
      .hci_resp_wdata_i(hci_resp_wdata),

      // HCI Command queue
      .hci_cmd_full_o(hci_cmd_full),
      .hci_cmd_depth_o(hci_cmd_depth),
      .hci_cmd_ready_thld_o(hci_cmd_ready_thld),
      .hci_cmd_ready_thld_trig_o(hci_cmd_ready_thld_trig),
      .hci_cmd_empty_o(hci_cmd_empty),
      .hci_cmd_rvalid_o(hci_cmd_rvalid),
      .hci_cmd_rready_i(hci_cmd_rready),
      .hci_cmd_rdata_o(hci_cmd_rdata),

      // HCI RX queue
      .hci_rx_full_o(hci_rx_full),
      .hci_rx_depth_o(hci_rx_depth),
      .hci_rx_start_thld_o(hci_rx_start_thld),
      .hci_rx_start_thld_trig_o(hci_rx_start_thld_trig),
      .hci_rx_ready_thld_o(hci_rx_ready_thld),
      .hci_rx_ready_thld_trig_o(hci_rx_ready_thld_trig),
      .hci_rx_empty_o(hci_rx_empty),
      .hci_rx_wvalid_i(hci_rx_wvalid),
      .hci_rx_wready_o(hci_rx_wready),
      .hci_rx_wdata_i(hci_rx_wdata),

      // HCI TX queue
      .hci_tx_full_o(hci_tx_full),
      .hci_tx_depth_o(hci_tx_depth),
      .hci_tx_start_thld_o(hci_tx_start_thld),
      .hci_tx_start_thld_trig_o(hci_tx_start_thld_trig),
      .hci_tx_ready_thld_o(hci_tx_ready_thld),
      .hci_tx_ready_thld_trig_o(hci_tx_ready_thld_trig),
      .hci_tx_empty_o(hci_tx_empty),
      .hci_tx_rvalid_o(hci_tx_rvalid),
      .hci_tx_rready_i(hci_tx_rready),
      .hci_tx_rdata_o(hci_tx_rdata),

      .hci_ibi_full_o(hci_ibi_full),
      .hci_ibi_depth_o(hci_ibi_depth),
      .hci_ibi_ready_thld_o(hci_ibi_ready_thld),
      .hci_ibi_ready_thld_trig_o(hci_ibi_ready_thld_trig),
      .hci_ibi_empty_o(hci_ibi_empty),
      .hci_ibi_wvalid_i(hci_ibi_wvalid),
      .hci_ibi_wready_o(hci_ibi_wready),
      .hci_ibi_wdata_i(hci_ibi_wdata),

      .rst_action_i(rst_action),
      .rst_action_valid_i(rst_action_valid)
  );
`endif  // CONTROLLER_SUPPORT

`ifdef TARGET_SUPPORT
  // TTI RX Descriptor queue
  logic                          csr_tti_rx_desc_req;
  logic                          csr_tti_rx_desc_ack;
  logic [TtiRxDescDataWidth-1:0] csr_tti_rx_desc_data;
  logic [TtiRxDescThldWidth-1:0] csr_tti_rx_desc_ready_thld_i;
  logic [TtiRxDescThldWidth-1:0] csr_tti_rx_desc_ready_thld_o;
  logic                          csr_tti_rx_desc_ready_trig;
  logic                          csr_tti_rx_desc_reg_rst;
  logic                          csr_tti_rx_desc_reg_rst_we;
  logic                          csr_tti_rx_desc_reg_rst_data;

  logic                          csr_tti_rx_desc_empty;
  logic                          csr_tti_rx_desc_full;
  logic                          csr_tti_rx_desc_write;

  // TTI TX Descriptor queue
  logic                          csr_tti_tx_desc_req;
  logic                          csr_tti_tx_desc_ack;
  logic [      CsrDataWidth-1:0] csr_tti_tx_desc_data;
  logic [TtiTxDescThldWidth-1:0] csr_tti_tx_desc_ready_thld_i;
  logic [TtiTxDescThldWidth-1:0] csr_tti_tx_desc_ready_thld_o;
  logic                          csr_tti_tx_desc_reg_rst;
  logic                          csr_tti_tx_desc_reg_rst_we;
  logic                          csr_tti_tx_desc_reg_rst_data;
  logic                          csr_tti_tx_desc_full;

  // TTI RX data queue
  logic                          csr_tti_rx_data_req;
  logic                          csr_tti_rx_data_ack;
  logic [    TtiRxDataWidth-1:0] csr_tti_rx_data_data;
  logic [    TtiRxThldWidth-1:0] csr_tti_rx_data_start_thld;
  logic [    TtiRxThldWidth-1:0] csr_tti_rx_data_ready_thld_i;
  logic [    TtiRxThldWidth-1:0] csr_tti_rx_data_ready_thld_o;
  logic                          csr_tti_rx_data_ready_trig;
  logic                          csr_tti_rx_data_reg_rst;
  logic                          csr_tti_rx_data_reg_rst_we;
  logic                          csr_tti_rx_data_reg_rst_data;

  logic                          csr_tti_rx_data_empty;
  logic                          csr_tti_rx_data_full;
  logic                          csr_tti_rx_data_write;

  // TTI TX data queue
  logic                          csr_tti_tx_data_req;
  logic                          csr_tti_tx_data_ack;
  logic [      CsrDataWidth-1:0] csr_tti_tx_data_data;
  logic [    TtiTxThldWidth-1:0] csr_tti_tx_data_start_thld;
  logic [    TtiTxThldWidth-1:0] csr_tti_tx_data_ready_thld_i;
  logic [    TtiTxThldWidth-1:0] csr_tti_tx_data_ready_thld_o;
  logic                          csr_tti_tx_data_reg_rst;
  logic                          csr_tti_tx_data_reg_rst_we;
  logic                          csr_tti_tx_data_reg_rst_data;
  logic                          csr_tti_tx_data_full;

  // TTI In-band Interrupt (IBI) queue
  logic                          csr_tti_ibi_req;
  logic                          csr_tti_ibi_ack;
  logic [      CsrDataWidth-1:0] csr_tti_ibi_data;
  logic [   TtiIbiThldWidth-1:0] csr_tti_ibi_ready_thld;
  logic                          csr_tti_ibi_reg_rst;
  logic                          csr_tti_ibi_reg_rst_we;
  logic                          csr_tti_ibi_reg_rst_data;
`endif  // TARGET_SUPPORT

`ifdef TARGET_SUPPORT
  tti xtti (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .hwif_tti_i(hwif_tti_out),
      .hwif_tti_o(hwif_tti_in),

      // TTI RX descriptors queue
      .rx_desc_queue_req_o            (csr_tti_rx_desc_req),
      .rx_desc_queue_ack_i            (csr_tti_rx_desc_ack),
      .rx_desc_queue_data_i           (csr_tti_rx_desc_data),
      .rx_desc_queue_ready_thld_o     (csr_tti_rx_desc_ready_thld_i),
      .rx_desc_queue_ready_thld_i     (csr_tti_rx_desc_ready_thld_o),
      .rx_desc_queue_reg_rst_o        (csr_tti_rx_desc_reg_rst),
      .rx_desc_queue_reg_rst_we_i     (csr_tti_rx_desc_reg_rst_we),
      .rx_desc_queue_reg_rst_data_i   (csr_tti_rx_desc_reg_rst_data),
      .rx_desc_queue_ready_thld_trig_i(csr_tti_rx_desc_ready_trig),

      .rx_desc_queue_empty_i(tti_rx_desc_empty),
      .rx_desc_queue_full_i (tti_rx_desc_full),
      .rx_desc_queue_write_i(tti_rx_desc_wvalid & tti_rx_desc_wready),

      // TTI TX descriptors queue
      .tx_desc_queue_req_o         (csr_tti_tx_desc_req),
      .tx_desc_queue_ack_i         (csr_tti_tx_desc_ack),
      .tx_desc_queue_data_o        (csr_tti_tx_desc_data),
      .tx_desc_queue_ready_thld_o  (csr_tti_tx_desc_ready_thld_i),
      .tx_desc_queue_ready_thld_i  (csr_tti_tx_desc_ready_thld_o),
      .tx_desc_queue_reg_rst_o     (csr_tti_tx_desc_reg_rst),
      .tx_desc_queue_reg_rst_we_i  (csr_tti_tx_desc_reg_rst_we),
      .tx_desc_queue_reg_rst_data_i(csr_tti_tx_desc_reg_rst_data),
      .tx_desc_queue_full_i        (csr_tti_tx_desc_full),

      // TTI RX queue
      .rx_data_queue_req_o            (csr_tti_rx_data_req),
      .rx_data_queue_ack_i            (csr_tti_rx_data_ack),
      .rx_data_queue_data_i           (csr_tti_rx_data_data),
      .rx_data_queue_start_thld_o     (csr_tti_rx_data_start_thld),
      .rx_data_queue_ready_thld_o     (csr_tti_rx_data_ready_thld_i),
      .rx_data_queue_ready_thld_i     (csr_tti_rx_data_ready_thld_o),
      .rx_data_queue_reg_rst_o        (csr_tti_rx_data_reg_rst),
      .rx_data_queue_reg_rst_we_i     (csr_tti_rx_data_reg_rst_we),
      .rx_data_queue_reg_rst_data_i   (csr_tti_rx_data_reg_rst_data),
      .rx_data_queue_ready_thld_trig_i(csr_tti_rx_data_ready_trig),

      .rx_data_queue_empty_i(tti_rx_empty),
      .rx_data_queue_full_i (tti_rx_full),
      .rx_data_queue_write_i(tti_rx_wvalid & tti_rx_wready),

      // TTI TX queue
      .tx_data_queue_req_o         (csr_tti_tx_data_req),
      .tx_data_queue_ack_i         (csr_tti_tx_data_ack),
      .tx_data_queue_data_o        (csr_tti_tx_data_data),
      .tx_data_queue_start_thld_o  (csr_tti_tx_data_start_thld),
      .tx_data_queue_ready_thld_o  (csr_tti_tx_data_ready_thld_i),
      .tx_data_queue_ready_thld_i  (csr_tti_tx_data_ready_thld_o),
      .tx_data_queue_reg_rst_o     (csr_tti_tx_data_reg_rst),
      .tx_data_queue_reg_rst_we_i  (csr_tti_tx_data_reg_rst_we),
      .tx_data_queue_reg_rst_data_i(csr_tti_tx_data_reg_rst_data),
      .tx_data_queue_full_i        (csr_tti_tx_data_full),

      // TTI In-band Interrupt (IBI) queue
      .ibi_queue_full_i        (tti_ibi_full),
      .ibi_queue_req_o         (csr_tti_ibi_req),
      .ibi_queue_ack_i         (csr_tti_ibi_ack),
      .ibi_queue_data_o        (csr_tti_ibi_data),
      .ibi_queue_ready_thld_o  (csr_tti_ibi_ready_thld),
      .ibi_queue_reg_rst_o     (csr_tti_ibi_reg_rst),
      .ibi_queue_reg_rst_we_i  (csr_tti_ibi_reg_rst_we),
      .ibi_queue_reg_rst_data_i(csr_tti_ibi_reg_rst_data),

      .bypass_i3c_core_i(bypass_i3c_core),

      .recovery_mode_enabled_i(recovery_mode_enabled),
      .ibi_status_i(ibi_status),
      .ibi_status_we_i(ibi_status_we),
      .tx_pr_end_i(tti_tx_pr_end),
      .tx_pr_start_i(tti_tx_pr_start),

      .enec_ibi_i (enec_ibi),
      .enec_crr_i (enec_crr),
      .enec_hj_i  (enec_hj),
      .disec_ibi_i(disec_ibi),
      .disec_crr_i(disec_crr),
      .disec_hj_i (disec_hj),

      .err_i(controller_error),

      .irq_o(tti_irq)
  );
`else
  assign tti_irq = '0;
`endif  // TARGET_SUPPORT

  csri #(
      .CsrAddrWidth(CsrAddrWidth),
      .CsrDataWidth(CsrDataWidth)
  ) xcsri (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
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

      // CSR Interface
`ifdef TARGET_SUPPORT
      .hwif_tti_i(hwif_tti_in),
      .hwif_tti_o(hwif_tti_out),
      .hwif_rec_i(hwif_rec_in),
      .hwif_rec_o(hwif_rec_out),
      .hwif_socmgmt_i(hwif_soc_mgmt_in),
      .hwif_socmgmt_o(hwif_soc_mgmt_out),
`endif
`ifdef CONTROLLER_SUPPORT
      .hwif_pio_control_i(hwif_pio_control_in),
      .hwif_pio_control_o(hwif_pio_control_out),
      .hwif_base_i(hwif_base_in),
      .hwif_base_o(hwif_base_out),
      .dat_i(dat_in),
      .dat_o(dat_out),
      .dct_i(dct_in),
      .dct_o(dct_out),
`endif
      .hwif_out_o(hwif_out),

      // Controller configuration status
      .set_dasa_i(set_dasa),
      .set_dasa_valid_i(set_dasa_valid),
      .set_dasa_virtual_device_i(set_dasa_virtual_device),
      .rstdaa_i(rstdaa),
      .set_newda_i(set_newda),
      .set_newda_virtual_device_i(set_newda_virtual_device),
      .newda_i(newda),

      .rst_action_i(rst_action),
      .rst_action_valid_i(rst_action_valid)
  );

`ifdef TARGET_SUPPORT
  // Recovery handler
  recovery_handler #(
      .TtiRxDescDataWidth(TtiRxDescDataWidth),
      .TtiRxDescThldWidth(TtiRxDescThldWidth),
      .TtiRxDescFifoDepth(TtiRxDescFifoDepth),
      .TtiRxDataDataWidth(TtiRxDataWidth),
      .TtiRxDataThldWidth(TtiRxThldWidth),
      .TtiRxDataFifoDepth(TtiRxFifoDepth),
      .TtiTxDescDataWidth(TtiTxDescDataWidth),
      .TtiTxDescThldWidth(TtiTxDescThldWidth),
      .TtiTxDescFifoDepth(TtiTxDescFifoDepth),
      .TtiTxDataDataWidth(TtiTxDataWidth),
      .TtiTxDataThldWidth(TtiTxThldWidth),
      .TtiTxDataFifoDepth(TtiTxFifoDepth),
      .TtiIbiDataWidth(TtiIbiDataWidth),
      .TtiIbiThldWidth(TtiIbiThldWidth),
      .TtiIbiFifoDepth(TtiIbiFifoDepth),
      .CsrDataWidth(CsrDataWidth),
      .IndirectFifoDepth(IndirectFifoDepth)
  ) xrecovery_handler (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      // SoC Management CSR interface
      .hwif_socmgmt_i(hwif_soc_mgmt_out),
      .hwif_socmgmt_o(hwif_soc_mgmt_in),

      // Recovery CSR interface
      .hwif_rec_i(hwif_rec_out),
      .hwif_rec_o(hwif_rec_in),

      .bypass_i3c_core_i(bypass_i3c_core),

      // TTI RX descriptors queue
      .csr_tti_rx_desc_queue_req_i            (csr_tti_rx_desc_req),
      .csr_tti_rx_desc_queue_ack_o            (csr_tti_rx_desc_ack),
      .csr_tti_rx_desc_queue_data_o           (csr_tti_rx_desc_data),
      .csr_tti_rx_desc_queue_ready_thld_i     (csr_tti_rx_desc_ready_thld_i),
      .csr_tti_rx_desc_queue_ready_thld_o     (csr_tti_rx_desc_ready_thld_o),
      .csr_tti_rx_desc_queue_reg_rst_i        (csr_tti_rx_desc_reg_rst),
      .csr_tti_rx_desc_queue_reg_rst_we_o     (csr_tti_rx_desc_reg_rst_we),
      .csr_tti_rx_desc_queue_reg_rst_data_o   (csr_tti_rx_desc_reg_rst_data),
      .csr_tti_rx_desc_queue_ready_thld_trig_o(csr_tti_rx_desc_ready_trig),

      // TTI TX descriptors queue
      .csr_tti_tx_desc_queue_req_i         (csr_tti_tx_desc_req),
      .csr_tti_tx_desc_queue_ack_o         (csr_tti_tx_desc_ack),
      .csr_tti_tx_desc_queue_data_i        (csr_tti_tx_desc_data),
      .csr_tti_tx_desc_queue_ready_thld_i  (csr_tti_tx_desc_ready_thld_i),
      .csr_tti_tx_desc_queue_ready_thld_o  (csr_tti_tx_desc_ready_thld_o),
      .csr_tti_tx_desc_queue_reg_rst_i     (csr_tti_tx_desc_reg_rst),
      .csr_tti_tx_desc_queue_reg_rst_we_o  (csr_tti_tx_desc_reg_rst_we),
      .csr_tti_tx_desc_queue_reg_rst_data_o(csr_tti_tx_desc_reg_rst_data),
      .csr_tti_tx_desc_queue_full_o        (csr_tti_tx_desc_full),

      // TTI RX queue
      .csr_tti_rx_data_queue_req_i            (csr_tti_rx_data_req),
      .csr_tti_rx_data_queue_ack_o            (csr_tti_rx_data_ack),
      .csr_tti_rx_data_queue_data_o           (csr_tti_rx_data_data),
      .csr_tti_rx_data_queue_start_thld_i     (csr_tti_rx_data_start_thld),
      .csr_tti_rx_data_queue_ready_thld_i     (csr_tti_rx_data_ready_thld_i),
      .csr_tti_rx_data_queue_ready_thld_o     (csr_tti_rx_data_ready_thld_o),
      .csr_tti_rx_data_queue_reg_rst_i        (csr_tti_rx_data_reg_rst),
      .csr_tti_rx_data_queue_reg_rst_we_o     (csr_tti_rx_data_reg_rst_we),
      .csr_tti_rx_data_queue_reg_rst_data_o   (csr_tti_rx_data_reg_rst_data),
      .csr_tti_rx_data_queue_ready_thld_trig_o(csr_tti_rx_data_ready_trig),

      // TTI TX queue
      .csr_tti_tx_data_queue_req_i         (csr_tti_tx_data_req),
      .csr_tti_tx_data_queue_ack_o         (csr_tti_tx_data_ack),
      .csr_tti_tx_data_queue_data_i        (csr_tti_tx_data_data),
      .csr_tti_tx_data_queue_start_thld_i  (csr_tti_tx_data_start_thld),
      .csr_tti_tx_data_queue_ready_thld_i  (csr_tti_tx_data_ready_thld_i),
      .csr_tti_tx_data_queue_ready_thld_o  (csr_tti_tx_data_ready_thld_o),
      .csr_tti_tx_data_queue_reg_rst_i     (csr_tti_tx_data_reg_rst),
      .csr_tti_tx_data_queue_reg_rst_we_o  (csr_tti_tx_data_reg_rst_we),
      .csr_tti_tx_data_queue_reg_rst_data_o(csr_tti_tx_data_reg_rst_data),
      .csr_tti_tx_data_queue_full_o        (csr_tti_tx_data_full),

      // TTI In-band Interrupt (IBI) queue
      .csr_tti_ibi_queue_req_i         (csr_tti_ibi_req),
      .csr_tti_ibi_queue_ack_o         (csr_tti_ibi_ack),
      .csr_tti_ibi_queue_data_i        (csr_tti_ibi_data),
      .csr_tti_ibi_queue_ready_thld_i  (csr_tti_ibi_ready_thld),
      .csr_tti_ibi_queue_reg_rst_i     (csr_tti_ibi_reg_rst),
      .csr_tti_ibi_queue_reg_rst_we_o  (csr_tti_ibi_reg_rst_we),
      .csr_tti_ibi_queue_reg_rst_data_o(csr_tti_ibi_reg_rst_data),

      // TTI RX descriptors queue
      .ctl_tti_rx_desc_queue_full_o(tti_rx_desc_full),
      .ctl_tti_rx_desc_queue_depth_o(tti_rx_desc_depth),
      .ctl_tti_rx_desc_queue_empty_o(tti_rx_desc_empty),
      .ctl_tti_rx_desc_queue_wvalid_i(tti_rx_desc_wvalid),
      .ctl_tti_rx_desc_queue_wready_o(tti_rx_desc_wready),
      .ctl_tti_rx_desc_queue_wdata_i(tti_rx_desc_wdata),
      .ctl_tti_rx_desc_queue_ready_thld_o(tti_rx_desc_ready_thld),
      .ctl_tti_rx_desc_queue_ready_thld_trig_o(tti_rx_desc_ready_thld_trig),

      // TTI TX descriptors queue
      .ctl_tti_tx_desc_queue_full_o(tti_tx_desc_full),
      .ctl_tti_tx_desc_queue_depth_o(tti_tx_desc_depth),
      .ctl_tti_tx_desc_queue_empty_o(tti_tx_desc_empty),
      .ctl_tti_tx_desc_queue_rvalid_o(tti_tx_desc_rvalid),
      .ctl_tti_tx_desc_queue_rready_i(tti_tx_desc_rready),
      .ctl_tti_tx_desc_queue_rdata_o(tti_tx_desc_rdata),
      .ctl_tti_tx_desc_queue_ready_thld_o(tti_tx_desc_ready_thld),
      .ctl_tti_tx_desc_queue_ready_thld_trig_o(tti_tx_desc_ready_thld_trig),

      // TTI RX data queue
      .ctl_tti_rx_data_queue_full_o(tti_rx_full),
      .ctl_tti_rx_data_queue_depth_o(tti_rx_depth),
      .ctl_tti_rx_data_queue_empty_o(tti_rx_empty),
      .ctl_tti_rx_data_queue_wvalid_i(tti_rx_wvalid),
      .ctl_tti_rx_data_queue_wready_o(tti_rx_wready),
      .ctl_tti_rx_data_queue_wdata_i(tti_rx_wdata),
      .ctl_tti_rx_data_queue_flush_i(tti_rx_flush),
      .ctl_tti_rx_data_queue_start_thld_o(tti_rx_start_thld),
      .ctl_tti_rx_data_queue_start_thld_trig_o(tti_rx_start_thld_trig),
      .ctl_tti_rx_data_queue_ready_thld_o(tti_rx_ready_thld),
      .ctl_tti_rx_data_queue_ready_thld_trig_o(tti_rx_ready_thld_trig),

      // TTI TX data queue
      .ctl_tti_tx_data_queue_full_o(tti_tx_full),
      .ctl_tti_tx_data_queue_depth_o(tti_tx_depth),
      .ctl_tti_tx_data_queue_empty_o(tti_tx_empty),
      .ctl_tti_tx_data_queue_rvalid_o(tti_tx_rvalid),
      .ctl_tti_tx_data_queue_rready_i(tti_tx_rready),
      .ctl_tti_tx_data_queue_rdata_o(tti_tx_rdata),
      .ctl_tti_tx_data_queue_flush_i(tti_tx_flush),
      .ctl_tti_tx_data_queue_start_thld_o(tti_tx_start_thld),
      .ctl_tti_tx_data_queue_start_thld_trig_o(tti_tx_start_thld_trig),
      .ctl_tti_tx_data_queue_ready_thld_o(tti_tx_ready_thld),
      .ctl_tti_tx_data_queue_ready_thld_trig_o(tti_tx_ready_thld_trig),
      .ctl_tti_tx_host_nack_i(tti_tx_host_nack),

      // TTI In-band Interrupt (IBI) queue
      .ctl_tti_ibi_queue_full_o(tti_ibi_full),
      .ctl_tti_ibi_queue_depth_o(tti_ibi_depth),
      .ctl_tti_ibi_queue_empty_o(tti_ibi_empty),
      .ctl_tti_ibi_queue_rvalid_o(tti_ibi_rvalid),
      .ctl_tti_ibi_queue_rready_i(tti_ibi_rready),
      .ctl_tti_ibi_queue_rdata_o(tti_ibi_rdata),
      .ctl_tti_ibi_queue_ready_thld_o(tti_ibi_ready_thld),
      .ctl_tti_ibi_queue_ready_thld_trig_o(tti_ibi_ready_thld_trig),

      .irq_o(recovery_irq),

      // Recovery status signals
      .payload_available_o(recovery_payload_available_o),
      .image_activated_o  (recovery_image_activated_o),

      // I2C/I3C bus condition detection
      .ctl_bus_start_i(bus_start | bus_rstart),  // S/Sr are both used to reset PEC
      .ctl_bus_stop_i (bus_stop),

      // Received I2C/I3C address along with RnW# bit
      .ctl_bus_addr_i(rx_bus_addr),
      .ctl_bus_addr_valid_i(rx_bus_addr_valid),
      .recovery_mode_enter_o(recovery_mode_enter),
      .recovery_mode_enabled_o(recovery_mode_enabled),
      .virtual_device_sel_i(virtual_device_sel),
      .xfer_in_progress_i(xfer_in_progress)
  );
`else
  assign recovery_irq = '0;
`endif  // TARGET_SUPPORT

  // I3C PHY
  i3c_phy xphy (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .scl_i(i3c_scl_i),
      .scl_o(i3c_scl_o),
      .sda_i(i3c_sda_i),
      .sda_o(i3c_sda_o),
      .ctrl_scl_i(ctrl2phy_scl),
      .ctrl_sda_i(ctrl2phy_sda),
      .ctrl_scl_o(phy2ctrl_scl),
      .ctrl_sda_o(phy2ctrl_sda),
      .sel_od_pp_i(ctrl_sel_od_pp),
      .sel_od_pp_o(sel_od_pp_o)
  );

  // Aggregate interrupts
  assign irq_o = ctl_irq | tti_irq | recovery_irq;

endmodule
