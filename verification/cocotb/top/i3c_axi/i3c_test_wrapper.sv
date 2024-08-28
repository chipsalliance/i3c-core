// SPDX-License-Identifier: Apache-2.0

module i3c_test_wrapper
  import i3c_pkg::*;
#(
    parameter int unsigned AxiDataWidth = 32,
    parameter int unsigned AxiAddrWidth = 12,
    parameter int unsigned AxiUserWidth = 32,
    parameter int unsigned AxiIdWidth   = 2
) (
    input aclk,  // clock
    input areset_n,  // active low reset

    // AXI4 Interface
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

    input  logic [AxiDataWidth-1:0] wdata,
    input  logic [AxiDataWidth/8-1:0] wstrb,
    input  logic                    wlast,
    input  logic                    wvalid,
    output logic                    wready,

    output logic [           1:0] bresp,
    output logic [AxiIdWidth-1:0] bid,
    output logic                  bvalid,
    input  logic                  bready,

    // I3C bus IO
    input        i3c_scl_i,    // serial clock input from i3c bus
    output logic i3c_scl_o,    // serial clock output to i3c bus
    output logic i3c_scl_en_o, // serial clock output to i3c bus

    input        i3c_sda_i,    // serial data input from i3c bus
    output logic i3c_sda_o,    // serial data output to i3c bus
    output logic i3c_sda_en_o, // serial data output to i3c bus

    input logic i3c_fsm_en_i,
    output logic i3c_fsm_idle_o,
    output logic [3:0] debug_state
);

  i3c_wrapper #(
      .AxiDataWidth,
      .AxiAddrWidth,
      .AxiUserWidth,
      .AxiIdWidth
  ) i3c (
      .clk_i (aclk),
      .rst_ni(areset_n),

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

      .awaddr_i(awaddr),
      .awburst_i(awburst),
      .awsize_i(awsize),
      .awlen_i(awlen),
      .awuser_i(awuser),
      .awid_i(awid),
      .awlock_i(awlock),
      .awvalid_i(awvalid),
      .awready_o(awready),
      .wdata_i(wdata),
      .wstrb_i(wstrb),
      .wlast_i(wlast),
      .wvalid_i(wvalid),
      .wready_o(wready),
      .bresp_o(bresp),
      .bid_o(bid),
      .bvalid_o(bvalid),
      .bready_i(bready),

      .i3c_scl_i,
      .i3c_scl_o,
      .i3c_scl_en_o,

      .i3c_sda_i,
      .i3c_sda_o,
      .i3c_sda_en_o,

      .i3c_fsm_en_i,
      .i3c_fsm_idle_o
  );

endmodule
