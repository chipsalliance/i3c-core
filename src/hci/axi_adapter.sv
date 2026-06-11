// SPDX-License-Identifier: Apache-2.0
`include "i3c_defines.svh"

module axi_adapter #(
    localparam int unsigned CsrAddrWidth = 12,
    localparam int unsigned CsrDataWidth = 32,

    parameter int unsigned AxiDataWidth = 64,
    parameter int unsigned AxiAddrWidth = 32,
    parameter int unsigned AxiUserWidth = 32,
    parameter int unsigned AxiIdWidth   = 8
`ifdef AXI_ID_FILTERING,
    parameter int unsigned NumPrivIds   = 4
`endif
) (
    input logic clk_i,
    input logic rst_ni,

    // AXI4 subordinate interface
    // Must be parameterized with AW=AxiAddrWidth, DW=AxiDataWidth,
    // UW=AxiUserWidth and IW=AxiIdWidth
    axi_if s_axi_if,

`ifdef AXI_ID_FILTERING
    input logic disable_id_filtering_i,
    input logic [AxiUserWidth-1:0] priv_ids_i[NumPrivIds],
`endif

    // I3C SW CSR access interface
    output logic                    s_cpuif_req,
    output logic                    s_cpuif_req_is_wr,
    output logic [CsrAddrWidth-1:0] s_cpuif_addr,
    output logic [CsrDataWidth-1:0] s_cpuif_wr_data,
    output logic [CsrDataWidth-1:0] s_cpuif_wr_biten,
    input  logic                    s_cpuif_req_stall_wr,
    input  logic                    s_cpuif_req_stall_rd,
    input  logic                    s_cpuif_rd_ack,
    input  logic                    s_cpuif_rd_err,
    input  logic [CsrDataWidth-1:0] s_cpuif_rd_data,
    input  logic                    s_cpuif_wr_ack,
    input  logic                    s_cpuif_wr_err
);

  localparam LowerAddrBits = $clog2(CsrDataWidth/8);
  localparam AxiCSRDataShift = $clog2(AxiDataWidth/CsrDataWidth);
  localparam UpperAddrBits = LowerAddrBits + AxiCSRDataShift;
  localparam ShiftWidth = $clog2(CsrDataWidth);

  logic rlegal;
  logic wlegal;

`ifdef AXI_ID_FILTERING
  logic [NumPrivIds-1:0] rsel;
  logic [NumPrivIds-1:0] wsel;

  always_ff @(posedge clk_i or negedge rst_ni) begin : axi_id_filter
    if (!rst_ni) begin
      rlegal <= '0;
      wlegal <= '0;
    end else begin
      if (s_axi_if.arready && s_axi_if.arvalid) begin
        rlegal <= disable_id_filtering_i | (|rsel);
      end

      if (s_axi_if.awready && s_axi_if.awvalid) begin
        wlegal <= disable_id_filtering_i | (|wsel);
      end
    end
  end

  genvar j;
  for (j = 0; j < NumPrivIds; j = j + 1) begin : g_match_id
    always_comb begin
      rsel[j] = s_axi_if.aruser == priv_ids_i[j];
      wsel[j] = s_axi_if.awuser == priv_ids_i[j];
    end
  end

`else
  always_comb begin
    rlegal = 1'b1;
    wlegal = 1'b1;
  end
`endif

  logic i3c_req_dv, i3c_req_hld, i3c_req_hld_ext;
  logic cpuif_req_stall;
  logic i3c_req_write;
  logic i3c_req_last;
  logic [AxiDataWidth-1:0] i3c_req_wdata;
  logic [AxiDataWidth-1:0] i3c_req_wbiten;
  logic [AxiDataWidth/8-1:0] i3c_req_wstrb;
  logic [2:0] i3c_req_size;
  logic [AxiAddrWidth-1:0] i3c_req_addr;
  logic [AxiDataWidth-1:0] i3c_req_rdata;
  logic [AxiIdWidth-1:0] i3c_req_id;
  logic [AxiUserWidth-1:0] i3c_req_user;
  logic i3c_rd_err, i3c_wr_err;

  // Instantiate AXI subordinate to component interface module
  axi_sub #(
      .AW(AxiAddrWidth),
      .DW(AxiDataWidth),
      .UW(AxiUserWidth),
      .IW(AxiIdWidth)
  ) axi_sif_i3c (
      .clk  (clk_i),
      .rst_n(rst_ni),

      // AXI interface
      .s_axi_r_if(s_axi_if.r_sub),
      .s_axi_w_if(s_axi_if.w_sub),

      // Component interface
      .dv(i3c_req_dv),
      .addr(i3c_req_addr),
      .write(i3c_req_write),
      .user(i3c_req_user),
      .id(i3c_req_id),
      .wdata(i3c_req_wdata),
      .wstrb(i3c_req_wstrb),
      .size(i3c_req_size),
      .rdata(i3c_req_rdata),
      .last(i3c_req_last),
      .hld(i3c_req_hld),
      .rd_err(i3c_rd_err),
      .wr_err(i3c_wr_err)
  );

  for (genvar i = 0; i < AxiDataWidth / 8; i = i + 1) begin : g_replicate_strb_bits
    always_comb begin
      i3c_req_wbiten[i*8+:8] = i3c_req_wstrb[i] ? 8'hFF : 8'h00;
    end
  end

  logic cpuif_no_ack, wr_hld, rd_hld;
  logic wr_hld_ext, rd_hld_ext, rd_req, wr_req, rd_req_legal, wr_req_legal;
  assign cpuif_no_ack = ~s_cpuif_wr_ack & ~s_cpuif_rd_ack;

  always_comb begin : axi_2_i3c_comp
    rd_req = i3c_req_dv & !i3c_req_write;
    wr_req = i3c_req_dv & i3c_req_write;
    // Operation is legal if ID of the request is on 'priv_ids_i'
    rd_req_legal = rd_req & rlegal;
    wr_req_legal = wr_req & wlegal;

    rd_hld = (rd_req_legal | rd_hld_ext | s_cpuif_req_stall_rd) & cpuif_no_ack;
    wr_hld = (wr_req_legal | wr_hld_ext | s_cpuif_req_stall_wr) & cpuif_no_ack;

    // Raise an error only when `hld` is deasserted
    i3c_rd_err = ((rd_req & !rlegal) | s_cpuif_rd_err) & !wr_hld;
    i3c_wr_err = ((wr_req & !wlegal) | s_cpuif_wr_err) & !rd_hld;

    i3c_req_hld_ext = wr_hld_ext | rd_hld_ext;
    i3c_req_hld = wr_hld | rd_hld;
    s_cpuif_req = (wr_req_legal | rd_req_legal) & ~i3c_req_hld_ext;
    s_cpuif_req_is_wr = i3c_req_write;
    s_cpuif_addr = i3c_req_addr[CsrAddrWidth-1:0];
  end

  if (AxiDataWidth == CsrDataWidth) begin : g_data_width_equal
    assign s_cpuif_wr_biten = i3c_req_wbiten;
    assign s_cpuif_wr_data = i3c_req_wdata;
    assign i3c_req_rdata = s_cpuif_rd_data;
  end else if (AxiDataWidth >= CsrDataWidth) begin : g_axi_data_width_geq
    assign s_cpuif_wr_biten = i3c_req_wbiten >> {i3c_req_addr[UpperAddrBits-1:LowerAddrBits],{ShiftWidth{1'b0}}};
    assign s_cpuif_wr_data = i3c_req_wdata >> {i3c_req_addr[UpperAddrBits-1:LowerAddrBits],{ShiftWidth{1'b0}}};
    assign i3c_req_rdata = s_cpuif_rd_data << {i3c_req_addr[UpperAddrBits-1:LowerAddrBits],{ShiftWidth{1'b0}}};
`ifndef SYNTHESIS
  end else begin
    $error("No implementation for CSR width > interface width");
`endif
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      wr_hld_ext <= 0;
      rd_hld_ext <= 0;
    end else begin
      wr_hld_ext <= cpuif_no_ack ? wr_req_legal : 1'b0;
      rd_hld_ext <= cpuif_no_ack ? rd_req_legal : 1'b0;
    end
  end

endmodule
