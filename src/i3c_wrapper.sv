// SPDX-License-Identifier: Apache-2.0
module i3c_wrapper #(
    parameter bit UseAxi = 1'b1,
    parameter int unsigned AhbDataWidth = 64,
    parameter int unsigned AhbAddrWidth = 18,
    parameter int unsigned AxiDataWidth = 32,
    parameter int unsigned AxiAddrWidth = 12,
    parameter int unsigned AxiUserWidth = 32,
    parameter int unsigned AxiIdWidth = 8,
    parameter bit EnableIdFiltering = 1'b1,
    parameter int unsigned NumPrivIds = 4,
    parameter int unsigned CmdFifoDepth = 64,
    parameter int unsigned RespFifoDepth = 64,
    parameter int unsigned RxFifoDepth = 64,
    parameter int unsigned TxFifoDepth = 64,
    parameter int unsigned IbiFifoDepth = 64,
    parameter bit IbiFifoExtSize = 1'b0,
    parameter int unsigned DatDepth = 128,
    parameter int unsigned DctDepth = 128,
    parameter bit DisableLoopback = 1'b0,
    parameter int unsigned DatAw = $clog2(DatDepth),
    parameter int unsigned DctAw = $clog2(DctDepth),

    parameter int unsigned CsrAddrWidth = I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH,
    parameter int unsigned CsrDataWidth = I3CCSR_pkg::I3CCSR_DATA_WIDTH
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

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

    // AXI4 subordinate interface
    // Must be parameterized with AW=AxiAddrWidth, DW=AxiDataWidth,
    // UW=AxiUserWidth and IW=AxiIdWidth
    axi_if.w_sub s_axi_w_if,
    axi_if.r_sub s_axi_r_if,

    input logic disable_id_filtering_i,
    input logic [AxiUserWidth-1:0] priv_ids_i [NumPrivIds],

    // I3C bus driver signals
    input  logic scl_i,
    input  logic sda_i,
    output logic scl_o,
    output logic sda_o,
    output logic scl_oe,
    output logic sda_oe,

    output logic sel_od_pp_o,

    // Recovery interface signals
    output logic recovery_payload_available_o,
    output logic recovery_image_activated_o,

    output logic peripheral_reset_o,
    input  logic peripheral_reset_done_i,
    output logic escalated_reset_o,

    output irq_o
);

  // DAT memory export interface
  i3c_pkg::dat_mem_src_t dat_mem_src;
  i3c_pkg::dat_mem_sink_t dat_mem_sink;

  // DCT memory export interface
  i3c_pkg::dct_mem_src_t dct_mem_src;
  i3c_pkg::dct_mem_sink_t dct_mem_sink;

  i3c #(
      .UseAxi(UseAxi),
      .AhbDataWidth(AhbDataWidth),
      .AhbAddrWidth(AhbAddrWidth),
      .AxiDataWidth(AxiDataWidth),
      .AxiAddrWidth(AxiAddrWidth),
      .AxiUserWidth(AxiUserWidth),
      .AxiIdWidth(AxiIdWidth),
      .EnableIdFiltering(EnableIdFiltering),
      .NumPrivIds(NumPrivIds),
      .HciCmdFifoDepth(CmdFifoDepth),
      .HciRespFifoDepth(RespFifoDepth),
      .HciRxFifoDepth(RxFifoDepth),
      .HciTxFifoDepth(TxFifoDepth),
      .HciIbiFifoDepth(IbiFifoDepth * (IbiFifoExtSize ? 8 : 1)),
      .TtiTxDescFifoDepth(CmdFifoDepth),
      .TtiRxDescFifoDepth(RespFifoDepth),
      .TtiRxFifoDepth(RxFifoDepth),
      .TtiTxFifoDepth(TxFifoDepth),
      .TtiIbiFifoDepth(IbiFifoDepth * (IbiFifoExtSize ? 8 : 1)),
      .IbiFifoExtSize(IbiFifoExtSize),
      .DatDepth(DatDepth),
      .DctDepth(DctDepth),
      .DisableLoopback(DisableLoopback),
      .CsrDataWidth(CsrDataWidth),
      .CsrAddrWidth(CsrAddrWidth),
      .DatAw(DatAw),
      .DctAw(DctAw)
  ) i3c (
      .clk_i,
      .rst_ni,

      .haddr_i,
      .hburst_i,
      .hprot_i,
      .hsize_i,
      .htrans_i,
      .hwdata_i,
      .hwstrb_i,
      .hwrite_i,
      .hrdata_o,
      .hreadyout_o,
      .hresp_o,
      .hsel_i,
      .hready_i,
      // AXI4 subordinate interface
      .s_axi_w_if(s_axi_w_if),
      .s_axi_r_if(s_axi_r_if),
      .disable_id_filtering_i(disable_id_filtering_i),
      .priv_ids_i(priv_ids_i),

      .i3c_scl_i   (scl_i),
      .i3c_scl_o   (scl_o),
      .i3c_sda_i   (sda_i),
      .i3c_sda_o   (sda_o),
      .i3c_sda_oe_o(sda_oe),
      .sel_od_pp_o (sel_od_pp_o),

      .dat_mem_src_i (dat_mem_src),
      .dat_mem_sink_o(dat_mem_sink),

      .dct_mem_src_i (dct_mem_src),
      .dct_mem_sink_o(dct_mem_sink),

      .recovery_payload_available_o(recovery_payload_available_o),
      .recovery_image_activated_o  (recovery_image_activated_o),

      .peripheral_reset_o,
      .peripheral_reset_done_i,
      .escalated_reset_o,
      .irq_o
  );

  prim_ram_1p_adv #(
      .Depth(DatDepth),
      .Width(64),
      .DataBitsPerMask(32)
  ) dat_memory (
      .clk_i,
      .rst_ni,
      .req_i(dat_mem_sink.req),
      .write_i(dat_mem_sink.write),
      .addr_i(dat_mem_sink.addr),
      .wdata_i(dat_mem_sink.wdata),
      .wmask_i(dat_mem_sink.wmask),
      .rdata_o(dat_mem_src.rdata),
      .rvalid_o(dat_mem_src.rvalid),  // Unused
      .rerror_o(dat_mem_src.rerror),  // Unused
      .cfg_i('0)  // Unused
  );

  prim_ram_1p_adv #(
      .Depth(DctDepth),
      .Width(128),
      .DataBitsPerMask(32)
  ) dct_memory (
      .clk_i,
      .rst_ni,
      .req_i(dct_mem_sink.req),
      .write_i(dct_mem_sink.write),
      .addr_i(dct_mem_sink.addr),
      .wdata_i(dct_mem_sink.wdata),
      .wmask_i(dct_mem_sink.wmask),
      .rdata_o(dct_mem_src.rdata),
      .rvalid_o(dct_mem_src.rvalid),  // Unused
      .rerror_o(dct_mem_src.rerror),  // Unused
      .cfg_i('0)  // Unused
  );


  assign scl_oe = 1'b0;

endmodule
