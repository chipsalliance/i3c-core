// SPDX-License-Identifier: Apache-2.0
`include "i3c_defines.svh"

module i3c_controller_error_test_wrapper #(
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
    input  logic                    aclk,
    input  logic                    areset_n,
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
    input logic disable_id_filtering_i,
    input logic [AxiUserWidth-1:0] priv_ids_i[NumPrivIds],
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
    input wire [4:0] debug_state_target_i,

    // Recovery interface signals
    output logic recovery_payload_available_o,
    output logic recovery_image_activated_o,

    output logic peripheral_reset_o,
    input  logic peripheral_reset_done_i,
    output logic escalated_reset_o,

    output irq_o
);

  localparam int unsigned NumDevices = 2;  // 1 Target, 1 Controller

  logic [NumDevices-1:0] sda;
  logic [NumDevices-1:0] scl;
  assign sda[0] = sda_i;
  assign scl[0] = scl_i;

  i3c_bus_harness #(
      .NumDevices(NumDevices)
  ) xi3_bus_harness (
      .sda_i(sda),
      .scl_i(scl),
      .sda_o(sda_o),
      .scl_o(scl_o)
  );

`ifdef CONTROLLER_SUPPORT
  // DAT memory export interface
  i3c_pkg::dat_mem_src_t  dat_mem_src;
  i3c_pkg::dat_mem_sink_t dat_mem_sink;

  // DCT memory export interface
  i3c_pkg::dct_mem_src_t  dct_mem_src;
  i3c_pkg::dct_mem_sink_t dct_mem_sink;
`endif  // CONTROLLER_SUPPORT

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
      .clk_i (aclk),
      .rst_ni(areset_n),

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
      .ruser_o(ruser),

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
      .bvalid_o(bvalid),
      .bready_i(bready),
      .buser_o(buser),

`ifdef AXI_ID_FILTERING
      .disable_id_filtering_i(disable_id_filtering_i),
      .priv_ids_i(priv_ids_i),
`endif
`endif

      .i3c_scl_i  (scl_o),
      .i3c_scl_o  (scl[1]),
      .i3c_sda_i  (sda_o),
      .i3c_sda_o  (sda[1]),
      .sel_od_pp_o(sel_od_pp_o),

`ifdef CONTROLLER_SUPPORT
      .dat_mem_src_i (dat_mem_src),
      .dat_mem_sink_o(dat_mem_sink),

      .dct_mem_src_i (dct_mem_src),
      .dct_mem_sink_o(dct_mem_sink),
`endif  // CONTROLLER_SUPPORT

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
      .clk_i(aclk),
      .rst_ni(areset_n),
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
      .clk_i(aclk),
      .rst_ni(areset_n),
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
`endif  // CONTROLLER_SUPPORT

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
