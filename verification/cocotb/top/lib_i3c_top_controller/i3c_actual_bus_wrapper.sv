// SPDX-License-Identifier: Apache-2.0
`include "i3c_defines.svh"


///////////////////////////////////////////////////////////////
//                       Expected BUS                        //
///////////////////////////////////////////////////////////////


`define VERILATOR
/*
    This module is used only for simulation with Verilator
*/

module i3c_actual_bus_wrapper #(
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
`ifdef I3C_USE_AHB
    input  logic                      hclk     [2],
    input  logic                      hreset_n [2],
    // AHB-Lite interface
    input  logic [  AhbAddrWidth-1:0] haddr    [2],
    input  logic [               2:0] hburst   [2],
    input  logic [               3:0] hprot    [2],
    input  logic [               2:0] hsize    [2],
    input  logic [               1:0] htrans   [2],
    input  logic [  AhbDataWidth-1:0] hwdata   [2],
    input  logic [AhbDataWidth/8-1:0] hwstrb   [2],
    input  logic                      hwrite   [2],
    output logic [  AhbDataWidth-1:0] hrdata   [2],
    output logic                      hreadyout[2],
    output logic                      hresp    [2],
    input  logic                      hsel     [2],
    input  logic                      hready   [2],
`elsif I3C_USE_AXI
    input  logic                      aclk     [2],
    input  logic                      areset_n [2],
    // AXI4 Interface
    // AXI Read Channels
    input  logic [  AxiAddrWidth-1:0] araddr   [2],
    input  logic [               1:0] arburst  [2],
    input  logic [               2:0] arsize   [2],
    input  logic [               7:0] arlen    [2],
    input  logic [  AxiUserWidth-1:0] aruser   [2],
    input  logic [    AxiIdWidth-1:0] arid     [2],
    input  logic                      arlock   [2],
    input  logic                      arvalid  [2],
    output logic                      arready  [2],

    output logic [AxiDataWidth-1:0] rdata [2],
    output logic [             1:0] rresp [2],
    output logic [  AxiIdWidth-1:0] rid   [2],
    output logic [AxiUserWidth-1:0] ruser [2],
    output logic                    rlast [2],
    output logic                    rvalid[2],
    input  logic                    rready[2],

    // AXI Write Channels
    input  logic [AxiAddrWidth-1:0] awaddr [2],
    input  logic [             1:0] awburst[2],
    input  logic [             2:0] awsize [2],
    input  logic [             7:0] awlen  [2],
    input  logic [AxiUserWidth-1:0] awuser [2],
    input  logic [  AxiIdWidth-1:0] awid   [2],
    input  logic                    awlock [2],
    input  logic                    awvalid[2],
    output logic                    awready[2],

    input  logic [  AxiDataWidth-1:0] wdata [2],
    input  logic [AxiDataWidth/8-1:0] wstrb [2],
    input  logic [  AxiUserWidth-1:0] wuser [2],
    input  logic                      wlast [2],
    input  logic                      wvalid[2],
    output logic                      wready[2],

    output logic [             1:0] bresp [2],
    output logic [  AxiIdWidth-1:0] bid   [2],
    output logic [AxiUserWidth-1:0] buser [2],
    output logic                    bvalid[2],
    input  logic                    bready[2],

`ifdef AXI_ID_FILTERING
    input logic disable_id_filtering_i[2],
    input logic [AxiUserWidth-1:0] priv_ids_i[2][NumPrivIds],
`endif
`endif
    // I3C Bus signals
    output logic bus_sda_o,
    output logic bus_scl_o,
    output logic phy_sel_od_pp_o,

    output logic recovery_payload_available_o[2],
    output logic recovery_image_activated_o  [2],

    output logic peripheral_reset_o[2],
    input logic peripheral_reset_done_i[2],
    output logic escalated_reset_o[2],

    output irq_o[2]
);

  logic clk_i;
  logic rst_ni;

`ifdef I3C_USE_AHB
  assign clk_i  = hclk;
  assign rst_ni = hreset_n;
`elsif I3C_USE_AXI
  assign clk_i  = aclk[0];
  assign rst_ni = areset_n[0];
`endif

  localparam int unsigned NumDevices = 2;  // 1 Target, 1 Controller

  logic [NumDevices-1:0] sda;
  logic [NumDevices-1:0] scl;
  logic [1:0] sel_od_pp;
  assign phy_sel_od_pp_o = sel_od_pp[0];

  i3c_bus_harness #(
      .NumDevices(NumDevices)
  ) xi3_bus_harness (
      .sda_i(sda),
      .scl_i(scl),
      .sda_o(bus_sda_o),
      .scl_o(bus_scl_o)
  );

  ///////////////////////////////////////////////////////////////
  //                        Controller                         //
  ///////////////////////////////////////////////////////////////

  i3c_wrapper #(
`ifdef I3C_USE_AHB
      .AhbDataWidth(AhbDataWidth),
      .AhbAddrWidth(AhbAddrWidth),
`elsif I3C_USE_AXI
      .AxiDataWidth(AxiDataWidth),
      .AxiAddrWidth(AxiAddrWidth),
      .AxiUserWidth(AxiUserWidth),
      .AxiIdWidth(AxiIdWidth),
`ifdef AXI_ID_FILTERING
      .NumPrivIds(NumPrivIds),
`endif
`endif
      .DatAw(DatAw),
      .DctAw(DctAw),
      .CsrAddrWidth(CsrAddrWidth),
      .CsrDataWidth(CsrDataWidth)
  ) i_controller_i3c_wrapper (
      .clk_i,
      .rst_ni,

`ifdef I3C_USE_AHB
      .haddr_i(haddr[0]),
      .hburst_i(hburst[0]),
      .hprot_i(hprot[0]),
      .hsize_i(hsize[0]),
      .htrans_i(htrans[0]),
      .hwdata_i(hwdata[0]),
      .hwstrb_i(hwstrb[0]),
      .hwrite_i(hwrite[0]),
      .hrdata_o(hrdata[0]),
      .hreadyout_o(hreadyout[0]),
      .hresp_o(hresp[0]),
      .hsel_i(hsel[0]),
      .hready_i(hready[0]),
`elsif I3C_USE_AXI
      .araddr_i(araddr[0]),
      .arburst_i(arburst[0]),
      .arsize_i(arsize[0]),
      .arlen_i(arlen[0]),
      .aruser_i(aruser[0]),
      .arid_i(arid[0]),
      .arlock_i(arlock[0]),
      .arvalid_i(arvalid[0]),
      .arready_o(arready[0]),

      .rdata_o(rdata[0]),
      .rresp_o(rresp[0]),
      .rid_o(rid[0]),
      .ruser_o(ruser[0]),
      .rlast_o(rlast[0]),
      .rvalid_o(rvalid[0]),
      .rready_i(rready[0]),

      .awaddr_i(awaddr[0]),
      .awburst_i(awburst[0]),
      .awsize_i(awsize[0]),
      .awlen_i(awlen[0]),
      .awuser_i(awuser[0]),
      .awid_i(awid[0]),
      .awlock_i(awlock[0]),
      .awvalid_i(awvalid[0]),
      .awready_o(awready[0]),

      .wdata_i (wdata[0]),
      .wstrb_i (wstrb[0]),
      .wuser_i (wuser[0]),
      .wlast_i (wlast[0]),
      .wvalid_i(wvalid[0]),
      .wready_o(wready[0]),

      .bresp_o(bresp[0]),
      .bid_o(bid[0]),
      .buser_o(buser[0]),
      .bvalid_o(bvalid[0]),
      .bready_i(bready[0]),

`ifdef AXI_ID_FILTERING
      .disable_id_filtering_i(disable_id_filtering_i[0]),
      .priv_ids_i(priv_ids_i[0]),
`endif
`endif

      .scl_i(bus_scl_o),
      .sda_i(bus_sda_o),
      .scl_o(scl[0]),
      .sda_o(sda[0]),
      .sel_od_pp_o(sel_od_pp[0]),

      .recovery_payload_available_o(recovery_payload_available_o[0]),
      .recovery_image_activated_o(recovery_image_activated_o[0]),
      .peripheral_reset_o(peripheral_reset_o[0]),
      .peripheral_reset_done_i(peripheral_reset_done_i[0]),
      .escalated_reset_o(escalated_reset_o[0]),
      .irq_o(irq_o[0])
  );


  ///////////////////////////////////////////////////////////////
  //                          Target                           //
  ///////////////////////////////////////////////////////////////

  i3c_wrapper #(
`ifdef I3C_USE_AHB
      .AhbDataWidth(AhbDataWidth),
      .AhbAddrWidth(AhbAddrWidth),
`elsif I3C_USE_AXI
      .AxiDataWidth(AxiDataWidth),
      .AxiAddrWidth(AxiAddrWidth),
      .AxiUserWidth(AxiUserWidth),
      .AxiIdWidth(AxiIdWidth),
`ifdef AXI_ID_FILTERING
      .NumPrivIds(NumPrivIds),
`endif
`endif
      .DatAw(DatAw),
      .DctAw(DctAw),
      .CsrAddrWidth(CsrAddrWidth),
      .CsrDataWidth(CsrDataWidth)
  ) i_target_i3c_wrapper (
      .clk_i,
      .rst_ni,

`ifdef I3C_USE_AHB
      .haddr_i(haddr[1]),
      .hburst_i(hburst[1]),
      .hprot_i(hprot[1]),
      .hsize_i(hsize[1]),
      .htrans_i(htrans[1]),
      .hwdata_i(hwdata[1]),
      .hwstrb_i(hwstrb[1]),
      .hwrite_i(hwrite[1]),
      .hrdata_o(hrdata[1]),
      .hreadyout_o(hreadyout[1]),
      .hresp_o(hresp[1]),
      .hsel_i(hsel[1]),
      .hready_i(hready[1]),
`elsif I3C_USE_AXI
      .araddr_i(araddr[1]),
      .arburst_i(arburst[1]),
      .arsize_i(arsize[1]),
      .arlen_i(arlen[1]),
      .aruser_i(aruser[1]),
      .arid_i(arid[1]),
      .arlock_i(arlock[1]),
      .arvalid_i(arvalid[1]),
      .arready_o(arready[1]),

      .rdata_o(rdata[1]),
      .rresp_o(rresp[1]),
      .rid_o(rid[1]),
      .ruser_o(ruser[1]),
      .rlast_o(rlast[1]),
      .rvalid_o(rvalid[1]),
      .rready_i(rready[1]),

      .awaddr_i(awaddr[1]),
      .awburst_i(awburst[1]),
      .awsize_i(awsize[1]),
      .awlen_i(awlen[1]),
      .awuser_i(awuser[1]),
      .awid_i(awid[1]),
      .awlock_i(awlock[1]),
      .awvalid_i(awvalid[1]),
      .awready_o(awready[1]),

      .wdata_i (wdata[1]),
      .wstrb_i (wstrb[1]),
      .wuser_i (wuser[1]),
      .wlast_i (wlast[1]),
      .wvalid_i(wvalid[1]),
      .wready_o(wready[1]),

      .bresp_o(bresp[1]),
      .bid_o(bid[1]),
      .buser_o(buser[1]),
      .bvalid_o(bvalid[1]),
      .bready_i(bready[1]),

`ifdef AXI_ID_FILTERING
      .disable_id_filtering_i(disable_id_filtering_i[1]),
      .priv_ids_i(priv_ids_i[1]),
`endif
`endif

      .scl_i(bus_scl_o),
      .sda_i(bus_sda_o),
      .scl_o(scl[1]),
      .sda_o(sda[1]),
      .sel_od_pp_o(sel_od_pp[1]),

      .recovery_payload_available_o(recovery_payload_available_o[1]),
      .recovery_image_activated_o(recovery_image_activated_o[1]),
      .peripheral_reset_o(peripheral_reset_o[1]),
      .peripheral_reset_done_i(peripheral_reset_done_i[1]),
      .escalated_reset_o(escalated_reset_o[1]),
      .irq_o(irq_o[1])
  );


endmodule
