// SPDX-License-Identifier: Apache-2.0
// This wrapper module provides compliance to cocotbext-AXI
// with AXI standard signal naming convention

module axi_adapter_wrapper
  import I3CCSR_pkg::I3CCSR_DATA_WIDTH;
  import I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
  import I3CCSR_pkg::I3CCSR__in_t;
  import I3CCSR_pkg::I3CCSR__out_t;
  import i3c_pkg::*;
#(
    parameter int unsigned AXI_ADDR_WIDTH = 12,
    parameter int unsigned AXI_DATA_WIDTH = 32,
    parameter unsigned AXI_USER_WIDTH = 32,
    parameter unsigned AXI_ID_WIDTH = 2
) (
    input aclk,  // clock
    input areset_n,  // active low reset

    // AXI Read Channels
    input  logic [AXI_ADDR_WIDTH-1:0] araddr,
    input  logic [               1:0] arburst,
    input  logic [               2:0] arsize,
    input  logic [               7:0] arlen,
    input  logic [AXI_USER_WIDTH-1:0] aruser,
    input  logic [  AXI_ID_WIDTH-1:0] arid,
    input  logic                      arlock,
    input  logic                      arvalid,
    output logic                      arready,

    output logic [AXI_DATA_WIDTH-1:0] rdata,
    output logic [               1:0] rresp,
    output logic [  AXI_ID_WIDTH-1:0] rid,
    output logic                      rlast,
    output logic                      rvalid,
    input  logic                      rready,

    // AXI Write Channels
    input  logic [AXI_ADDR_WIDTH-1:0] awaddr,
    input  logic [               1:0] awburst,
    input  logic [               2:0] awsize,
    input  logic [               7:0] awlen,
    input  logic [AXI_USER_WIDTH-1:0] awuser,
    input  logic [  AXI_ID_WIDTH-1:0] awid,
    input  logic                      awlock,
    input  logic                      awvalid,
    output logic                      awready,

    input  logic [AXI_DATA_WIDTH-1:0] wdata,
    input  logic [               3:0] wstrb,
    input  logic                      wlast,
    input  logic                      wvalid,
    output logic                      wready,

    output logic [             1:0] bresp,
    output logic [AXI_ID_WIDTH-1:0] bid,
    output logic                    bvalid,
    input  logic                    bready
);
  // I3C SW CSR access interface
  logic                             s_cpuif_req;
  logic                             s_cpuif_req_is_wr;
  logic [I3CCSR_MIN_ADDR_WIDTH-1:0] s_cpuif_addr;
  logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_data;
  logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_biten;
  logic                             s_cpuif_req_stall_wr;
  logic                             s_cpuif_req_stall_rd;
  logic                             s_cpuif_rd_ack;
  logic                             s_cpuif_rd_err;
  logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_rd_data;
  logic                             s_cpuif_wr_ack;
  logic                             s_cpuif_wr_err;

  axi_adapter #(
      .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
      .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
      .AXI_USER_WIDTH(AXI_USER_WIDTH),
      .AXI_ID_WIDTH  (AXI_ID_WIDTH)
  ) i3c_axi_if (
      .clk_i (aclk),
      .rst_ni(areset_n),

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
      .wlast_i (wlast),
      .wvalid_i(wvalid),
      .wready_o(wready),

      .bresp_o(bresp),
      .bid_o(bid),
      .bvalid_o(bvalid),
      .bready_i(bready),

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

  I3CCSR__in_t  hwif_in;
  I3CCSR__out_t hwif_out;

  assign hwif_in.rst_ni = areset_n;

  // Connect to I3C CSRs to test SW access
  I3CCSR i3c_csr (
      .clk(aclk),
      .rst(~areset_n),

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

      .hwif_in (hwif_in),
      .hwif_out(hwif_out)
  );
endmodule
