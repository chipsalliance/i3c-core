// SPDX-License-Identifier: Apache-2.0

module axi_adapter
  import I3CCSR_pkg::I3CCSR_DATA_WIDTH;
  import I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
#(
    parameter unsigned AXI_DATA_WIDTH = 64,
    parameter unsigned AXI_ADDR_WIDTH = 32,
    parameter unsigned AXI_USER_WIDTH = 32,
    parameter unsigned AXI_ID_WIDTH   = 2
) (
    input logic clk_i,
    input logic rst_ni,

    // AXI Read Channels
    input  logic [AXI_ADDR_WIDTH-1:0] araddr_i,
    input  logic [               1:0] arburst_i,
    input  logic [               2:0] arsize_i,
    input  logic [               7:0] arlen_i,
    input  logic [AXI_USER_WIDTH-1:0] aruser_i,
    input  logic [  AXI_ID_WIDTH-1:0] arid_i,
    input  logic                      arlock_i,
    input  logic                      arvalid_i,
    output logic                      arready_o,

    output logic [AXI_DATA_WIDTH-1:0] rdata_o,
    output logic [               1:0] rresp_o,
    output logic [  AXI_ID_WIDTH-1:0] rid_o,
    output logic                      rlast_o,
    output logic                      rvalid_o,
    input  logic                      rready_i,

    // AXI Write Channels
    input  logic [AXI_ADDR_WIDTH-1:0] awaddr_i,
    input  logic [               1:0] awburst_i,
    input  logic [               2:0] awsize_i,
    input  logic [               7:0] awlen_i,
    input  logic [AXI_USER_WIDTH-1:0] awuser_i,
    input  logic [  AXI_ID_WIDTH-1:0] awid_i,
    input  logic                      awlock_i,
    input  logic                      awvalid_i,
    output logic                      awready_o,

    input  logic [AXI_DATA_WIDTH-1:0] wdata_i,
    input  logic [               7:0] wstrb_i,
    input  logic                      wlast_i,
    input  logic                      wvalid_i,
    output logic                      wready_o,

    output logic [             1:0] bresp_o,
    output logic [AXI_ID_WIDTH-1:0] bid_o,
    output logic                    bvalid_o,
    input  logic                    bready_i,

    // I3C SW CSR access interface
    output logic                             s_cpuif_req,
    output logic                             s_cpuif_req_is_wr,
    output logic [I3CCSR_MIN_ADDR_WIDTH-1:0] s_cpuif_addr,
    output logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_data,
    output logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_biten,
    input  logic                             s_cpuif_req_stall_wr,
    input  logic                             s_cpuif_req_stall_rd,
    input  logic                             s_cpuif_rd_ack,
    input  logic                             s_cpuif_rd_err,
    input  logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_rd_data,
    input  logic                             s_cpuif_wr_ack,
    input  logic                             s_cpuif_wr_err
);

  axi_if #(
      .AW(I3CCSR_MIN_ADDR_WIDTH),
      .DW(I3CCSR_DATA_WIDTH),
      .UW(AXI_DATA_WIDTH),
      .IW(AXI_ID_WIDTH)
  ) axi ();

  // AXI Read Channels
  always_comb begin : axi_r
    axi.arvalid = arvalid_i;
    arready_o = axi.arready;
    axi.arid = arid_i;
    axi.araddr = araddr_i;
    axi.arsize = arsize_i;

    rvalid_o = axi.rvalid;
    axi.rready = rready_i;
    rid_o = axi.rid;
    rdata_o = axi.rdata;
    rresp_o = axi.rresp;
    rlast_o = axi.rlast;
  end

  // AXI Write Channels
  always_comb begin : axi_w
    axi.awvalid = awvalid_i;
    awready_o   = axi.awready;
    axi.awid    = awid_i;
    axi.awaddr  = awaddr_i;
    axi.awsize  = awsize_i;

    axi.wvalid  = wvalid_i;
    wready_o    = axi.wready;
    axi.wdata   = wdata_i;
    axi.wstrb   = wstrb_i;
    axi.wlast   = wlast_i;

    bvalid_o    = axi.bvalid;
    axi.bready  = bready_i;
    bresp_o     = axi.bresp;
    bid_o       = axi.bid;
  end

  logic i3c_req_dv, i3c_req_hld, i3c_req_hld_ext;
  logic cpuif_req_stall;
  logic i3c_req_err, i3c_req_write;
  logic i3c_req_last;
  logic [I3CCSR_DATA_WIDTH-1:0] i3c_req_wdata;
  logic [AXI_DATA_WIDTH/8-1:0] i3c_req_wstrb;
  logic [AXI_ADDR_WIDTH-1:0] i3c_req_addr;
  logic [I3CCSR_DATA_WIDTH-1:0] i3c_req_rdata;
  logic [AXI_ID_WIDTH-1:0] i3c_req_id;
  logic [I3CCSR_DATA_WIDTH-1:0] i3c_req_user;

  // Instantiate AXI subordinate to component interface module
  axi_sub #(
      .AW(I3CCSR_MIN_ADDR_WIDTH),
      .DW(I3CCSR_DATA_WIDTH),
      .UW(AXI_DATA_WIDTH),
      .IW(AXI_ID_WIDTH)
  ) axi_sif_i3c (
      .clk  (clk_i),
      .rst_n(rst_ni),

      // AXI interface
      .s_axi_r_if(axi.r_sub),
      .s_axi_w_if(axi.w_sub),

      // Component interface
      .dv(i3c_req_dv),
      .addr(i3c_req_addr),
      .write(i3c_req_write),
      .user(i3c_req_user),
      .id(i3c_req_id),
      .wdata(i3c_req_wdata),
      .wstrb(i3c_req_wstrb),
      .rdata(i3c_req_rdata),
      .last(i3c_req_last),
      .hld(i3c_req_hld),
      .err(i3c_req_err)
  );

  genvar i;
  for (i = 0; i < AXI_DATA_WIDTH / 8; i = i + 1) begin : g_replicate_strb_bits
    always_comb begin
      s_cpuif_wr_biten[i*8+:8] = i3c_req_wstrb[i] ? 8'hFF : 8'h00;
    end
  end

  logic cpuif_no_ack;
  assign cpuif_no_ack = ~s_cpuif_wr_ack & ~s_cpuif_rd_ack;

  always_comb begin : axi_2_i3c_comp
    cpuif_req_stall = i3c_req_write ? s_cpuif_req_stall_wr : s_cpuif_req_stall_rd;
    i3c_req_hld = (i3c_req_dv | cpuif_req_stall | i3c_req_hld_ext) & cpuif_no_ack;

    s_cpuif_req = i3c_req_dv & ~i3c_req_hld_ext;
    s_cpuif_req_is_wr = i3c_req_write;
    s_cpuif_addr = i3c_req_addr[I3CCSR_MIN_ADDR_WIDTH-1:0];
    s_cpuif_wr_data = i3c_req_wdata;
    i3c_req_err = s_cpuif_rd_err | s_cpuif_wr_err;
    i3c_req_rdata = s_cpuif_rd_data;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      i3c_req_hld_ext <= '0;
    end else begin
      i3c_req_hld_ext <= cpuif_no_ack ? i3c_req_dv : 1'b0;
    end
  end
endmodule
