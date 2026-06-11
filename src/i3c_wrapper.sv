// SPDX-License-Identifier: Apache-2.0
`include "i3c_defines.svh"

module i3c_wrapper #(
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
    parameter int unsigned CsrDataWidth = I3CCSR_pkg::I3CCSR_DATA_WIDTH
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
    // AXI4 subordinate interface
    // Must be parameterized with AW=AxiAddrWidth, DW=AxiDataWidth,
    // UW=AxiUserWidth and IW=AxiIdWidth
    axi_if s_axi_if,

`ifdef AXI_ID_FILTERING
    input logic disable_id_filtering_i,
    input logic [AxiUserWidth-1:0] priv_ids_i [NumPrivIds],
`endif
`endif

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
`ifdef I3C_USE_AHB
      .AhbDataWidth(AhbDataWidth),
      .AhbAddrWidth(AhbAddrWidth),
`elsif I3C_USE_AXI
      .AxiDataWidth(AxiDataWidth),
      .AxiAddrWidth(AxiAddrWidth),
      .AxiUserWidth(AxiUserWidth),
      .AxiIdWidth(AxiIdWidth),
`endif
`ifdef AXI_ID_FILTERING
      .NumPrivIds(NumPrivIds),
`endif
      .CsrDataWidth(CsrDataWidth),
      .CsrAddrWidth(CsrAddrWidth),
      .DatAw(DatAw),
      .DctAw(DctAw)
  ) i3c (
      .clk_i,
      .rst_ni,

`ifdef I3C_USE_AHB
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
`elsif I3C_USE_AXI
      // AXI4 subordinate interface
      .s_axi_if(s_axi_if),
`ifdef AXI_ID_FILTERING
      .disable_id_filtering_i(disable_id_filtering_i),
      .priv_ids_i(priv_ids_i),
`endif
`endif

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
      .Depth(`DAT_DEPTH),
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
      .Depth(`DCT_DEPTH),
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
