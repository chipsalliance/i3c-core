// SPDX-License-Identifier: Apache-2.0
// This wrapper module provides compliance to cocotbext-AXI
// with AXI standard signal naming convention
`include "i3c_defines.svh"

module axi_adapter_wrapper
  import I3CCSR_pkg::I3CCSR_DATA_WIDTH;
  import I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
  import I3CCSR_pkg::I3CCSR__in_t;
  import I3CCSR_pkg::I3CCSR__out_t;
  import i3c_pkg::*;
#(
    localparam int unsigned CsrAddrWidth = I3CCSR_MIN_ADDR_WIDTH,
    localparam int unsigned CsrDataWidth = I3CCSR_DATA_WIDTH,

    parameter int unsigned AxiAddrWidth = 12,
    parameter int unsigned AxiDataWidth = 32,
    parameter int unsigned AxiUserWidth = 32,
    parameter int unsigned AxiIdWidth   = 8
`ifdef AXI_ID_FILTERING,
    parameter int unsigned NumPrivIds = 4
`endif
) (
    input aclk,  // clock
    input areset_n,  // active low reset

    // AXI Read Channels
    input  logic [AxiAddrWidth-1:0] araddr,
    input  logic [             1:0] arburst,
    input  logic [             2:0] arsize,
    input  logic [             7:0] arlen,
    input  logic [AxiUserWidth-1:0] aruser,
    input  logic [  AxiIdWidth-1:0] arid,
    input  logic                    arlock,
    input  logic [             3:0] arcache,
    input  logic [             2:0] arprot,
    input  logic [             3:0] arqos,
    input  logic [             3:0] arregion,
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
    input  logic [             3:0] awcache,
    input  logic [             2:0] awprot,
    input  logic [             3:0] awqos,
    input  logic [             3:0] awregion,
    input  logic                    awvalid,
    output logic                    awready,

    input  logic [AxiDataWidth-1:0] wdata,
    input  logic [             3:0] wstrb,
    input  logic [AxiUserWidth-1:0] wuser,
    input  logic                    wlast,
    input  logic                    wvalid,
    output logic                    wready,

    output logic [             1:0] bresp,
    output logic [  AxiIdWidth-1:0] bid,
    output logic [AxiUserWidth-1:0] buser,
    output logic                    bvalid,
    input  logic                    bready,

    output logic [           7:0] fifo_depth_o,
    output logic                  fifo_full_o
`ifdef AXI_ID_FILTERING,
    input logic disable_id_filtering_i,
    input logic [AxiUserWidth-1:0] priv_ids_i [NumPrivIds]
`endif
);
  // I3C SW CSR access interface
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


  // AXI4 subordinate interface of the DUT; cocotb drives the discrete
  // AXI pins of this wrapper, so they are wired onto the interface here
  axi_if #(
      .AW(AxiAddrWidth),
      .DW(AxiDataWidth),
      .UW(AxiUserWidth),
      .IW(AxiIdWidth)
  ) s_axi_if (
      .clk  (aclk),
      .rst_n(areset_n)
  );

  // AXI Read Channels
  assign s_axi_if.araddr  = araddr;
  assign s_axi_if.arburst = arburst;
  assign s_axi_if.arsize  = arsize;
  assign s_axi_if.arlen   = arlen;
  assign s_axi_if.aruser  = aruser;
  assign s_axi_if.arid    = arid;
  assign s_axi_if.arlock  = arlock;
  assign s_axi_if.arcache = arcache;
  assign s_axi_if.arprot  = arprot;
  assign s_axi_if.arqos   = arqos;
  assign s_axi_if.arregion = arregion;
  assign s_axi_if.arvalid = arvalid;
  assign arready          = s_axi_if.arready;

  assign rdata            = s_axi_if.rdata;
  assign rresp            = s_axi_if.rresp;
  assign rid              = s_axi_if.rid;
  assign ruser            = s_axi_if.ruser;
  assign rlast            = s_axi_if.rlast;
  assign rvalid           = s_axi_if.rvalid;
  assign s_axi_if.rready  = rready;

  // AXI Write Channels
  assign s_axi_if.awaddr  = awaddr;
  assign s_axi_if.awburst = awburst;
  assign s_axi_if.awsize  = awsize;
  assign s_axi_if.awlen   = awlen;
  assign s_axi_if.awuser  = awuser;
  assign s_axi_if.awid    = awid;
  assign s_axi_if.awlock  = awlock;
  assign s_axi_if.awcache = awcache;
  assign s_axi_if.awprot  = awprot;
  assign s_axi_if.awqos   = awqos;
  assign s_axi_if.awregion = awregion;
  assign s_axi_if.awvalid = awvalid;
  assign awready          = s_axi_if.awready;

  assign s_axi_if.wdata   = wdata;
  assign s_axi_if.wstrb   = wstrb;
  assign s_axi_if.wuser   = wuser;
  assign s_axi_if.wlast   = wlast;
  assign s_axi_if.wvalid  = wvalid;
  assign wready           = s_axi_if.wready;

  assign bresp            = s_axi_if.bresp;
  assign bid              = s_axi_if.bid;
  assign buser            = s_axi_if.buser;
  assign bvalid           = s_axi_if.bvalid;
  assign s_axi_if.bready  = bready;

  axi_adapter #(
      .AxiDataWidth(AxiDataWidth),
      .AxiAddrWidth(AxiAddrWidth),
      .AxiUserWidth(AxiUserWidth),
      .AxiIdWidth(AxiIdWidth)
`ifdef AXI_ID_FILTERING,
      .NumPrivIds(NumPrivIds)
`endif
  ) i3c_axi_if (
      .clk_i (aclk),
      .rst_ni(areset_n),

      // AXI4 subordinate interface
      .s_axi_w_if(s_axi_if.w_sub),
      .s_axi_r_if(s_axi_if.r_sub),

`ifdef AXI_ID_FILTERING
      .disable_id_filtering_i(disable_id_filtering_i),
      .priv_ids_i(priv_ids_i),
`endif

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

  logic fifo_wvalid;
  logic fifo_wready;
  logic [31:0] fifo_wdata;
  logic fifo_rvalid;
  logic fifo_rready;
  logic [31:0] fifo_rdata;

  logic unused_err;

  // FIFO for stress testing AXI
  caliptra_prim_fifo_sync #(
      .Width(32),
      .Pass (1'b0),
      .Depth(128)
  ) fifo (
      .clk_i(aclk),
      .rst_ni(areset_n),
      .clr_i('0),
      .wvalid_i(fifo_wvalid),
      .wready_o(fifo_wready),
      .wdata_i(fifo_wdata),
      .depth_o(fifo_depth_o),
      .rvalid_o(fifo_rvalid),
      .rready_i(fifo_rready),
      .rdata_o(fifo_rdata),
      .full_o(fifo_full_o),
      .err_o(unused_err)
  );

  logic wr_ack_q, rd_ack_q;
  logic fifo_rready_q, fifo_wvalid_q;
  logic [31:0] fifo_rdata_q, fifo_wdata_q;

  always_comb begin : connect_csr_hwif
    hwif_in = '0;
    hwif_in.rst_ni = areset_n;
    hwif_in.I3C_EC.TTI.TX_DATA_PORT.wr_ack = wr_ack_q;
    hwif_in.I3C_EC.SecFwRecoveryIf.INDIRECT_FIFO_DATA.rd_ack = rd_ack_q;
    hwif_in.I3C_EC.SecFwRecoveryIf.INDIRECT_FIFO_DATA.rd_data = rd_ack_q ? fifo_rdata_q : '0;
  end

  always_comb begin : connect_inidrect_fifo
    fifo_wvalid = fifo_wvalid_q;
    fifo_wdata = fifo_wdata_q;

    fifo_rready = fifo_rready_q;
  end

  always_ff @(posedge aclk or negedge areset_n) begin : stall_fifo_access
    if (~areset_n) begin
      wr_ack_q <= '0;
      rd_ack_q <= '0;
      fifo_rready_q <= '0;
      fifo_wvalid_q <= '0;
      fifo_rdata_q <= '0;
      fifo_wdata_q <= '0;
    end else begin
      wr_ack_q <= fifo_wvalid & fifo_wready;
      rd_ack_q <= fifo_rvalid & fifo_rready;
      fifo_rready_q <= hwif_out.I3C_EC.SecFwRecoveryIf.INDIRECT_FIFO_DATA.req & ~hwif_out.I3C_EC.SecFwRecoveryIf.INDIRECT_FIFO_DATA.req_is_wr;
      fifo_wvalid_q <= hwif_out.I3C_EC.TTI.TX_DATA_PORT.req & hwif_out.I3C_EC.TTI.TX_DATA_PORT.req_is_wr;
      fifo_rdata_q <= fifo_rdata;
      fifo_wdata_q <= hwif_out.I3C_EC.TTI.TX_DATA_PORT.wr_data;
    end
  end
endmodule
