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

    output logic [           1:0]   bresp_o,
    output logic [AxiIdWidth-1:0]   bid_o,
    output logic [AxiUserWidth-1:0] buser_o,
    output logic                    bvalid_o,
    input  logic                    bready_i,

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

`ifdef CONTROLLER_SUPPORT
  // DAT memory export interface
  i3c_pkg::dat_mem_src_t dat_mem_src;
  i3c_pkg::dat_mem_sink_t dat_mem_sink;

  // DCT memory export interface
  i3c_pkg::dct_mem_src_t dct_mem_src;
  i3c_pkg::dct_mem_sink_t dct_mem_sink;
`endif // CONTROLLER_SUPPORT

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
`endif

      .i3c_scl_i  (scl_i),
      .i3c_scl_o  (scl_o),
      .i3c_sda_i  (sda_i),
      .i3c_sda_o  (sda_o),
      .sel_od_pp_o(sel_od_pp_o),

`ifdef CONTROLLER_SUPPORT
      .dat_mem_src_i (dat_mem_src),
      .dat_mem_sink_o(dat_mem_sink),

      .dct_mem_src_i (dct_mem_src),
      .dct_mem_sink_o(dct_mem_sink),
`endif // CONTROLLER_SUPPORT

      .recovery_payload_available_o(recovery_payload_available_o),
      .recovery_image_activated_o  (recovery_image_activated_o),

      .peripheral_reset_o,
      .peripheral_reset_done_i,
      .escalated_reset_o,
      .irq_o
  );

`ifdef CONTROLLER_SUPPORT
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
`endif // CONTROLLER_SUPPORT

/*
  Truth table.

  sel_od_pp_o | sda_o  || sda_oe | IO state
  ------------+--------++--------+-----------
       0      |   0    ||   1    |    0
       0      |   1    ||   0    |   hi-z
       1      |   0    ||   1    |    0
       1      |   1    ||   1    |    1
*/

  assign sda_oe = sel_od_pp_o || !sda_o;
  assign scl_oe = 1'b0;

endmodule
