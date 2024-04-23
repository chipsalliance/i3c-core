// SPDX-License-Identifier: Apache-2.0
// This wrapper module provides compliance to cocotb-AHB
// AHB signal naming convention
module ahb_if_wrapper
  import I3CCSR_pkg::I3CCSR_DATA_WIDTH;
  import I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
  import I3CCSR_pkg::I3CCSR__in_t;
  import I3CCSR_pkg::I3CCSR__out_t;
#(
    parameter int unsigned AHB_DATA_WIDTH = 64,
    parameter int unsigned AHB_ADDR_WIDTH = 32
) (
    // AHB-Lite interface
    input  logic                      hclk,
    input  logic                      hreset_n,
    input  logic [AHB_ADDR_WIDTH-1:0] haddr,
    input  logic [               2:0] hsize,
    input  logic [               1:0] htrans,
    input  logic [AHB_DATA_WIDTH-1:0] hwdata,
    input  logic                      hwrite,
    output logic [AHB_DATA_WIDTH-1:0] hrdata,
    output logic                      hreadyout,
    output logic                      hresp,
    input  logic                      hsel,
    input  logic                      hready
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

  ahb_if #(
      .AHB_DATA_WIDTH (AHB_DATA_WIDTH),
      .AHB_ADDR_WIDTH (AHB_ADDR_WIDTH)
  ) i3c_ahb_if (
      .hclk_i(hclk),
      .hreset_n_i(hreset_n),
      .haddr_i(haddr),
      .hsize_i(hsize),
      .htrans_i(htrans),
      .hwdata_i(hwdata),
      .hwrite_i(hwrite),
      .hrdata_o(hrdata),
      .hreadyout_o(hreadyout),
      .hresp_o(hresp),
      .hsel_i(hsel),
      .hready_i(hready),
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
      .clk(hclk),
      .rst(~hreset_n),

      .s_cpuif_req(s_cpuif_req),
      .s_cpuif_req_is_wr(s_cpuif_req_is_wr),
      .s_cpuif_addr(s_cpuif_addr),
      .s_cpuif_wr_data(s_cpuif_wr_data),
      .s_cpuif_wr_biten(s_cpuif_wr_biten),  // Write strobes not handled by AHB-Lite interface
      .s_cpuif_req_stall_wr(s_cpuif_req_stall_wr),
      .s_cpuif_req_stall_rd(s_cpuif_req_stall_rd),
      .s_cpuif_rd_ack(s_cpuif_rd_ack),  // Ignored by AHB component
      .s_cpuif_rd_err(s_cpuif_rd_err),
      .s_cpuif_rd_data(s_cpuif_rd_data),
      .s_cpuif_wr_ack(s_cpuif_wr_ack),  // Ignored by AHB component
      .s_cpuif_wr_err(s_cpuif_wr_err),

      .hwif_in (hwif_in),
      .hwif_out(hwif_out)
  );
endmodule
