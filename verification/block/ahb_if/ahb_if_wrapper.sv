// SPDX-License-Identifier: Apache-2.0
// This wrapper module provides compliance to cocotb-AHB
// AHB signal naming convention
module ahb_if_wrapper #(
    parameter int unsigned AHB_DATA_WIDTH  = 64,
    parameter int unsigned AHB_ADDR_WIDTH  = 32,
    parameter int unsigned AHB_BURST_WIDTH = 3
) (
    // AHB-Lite interface
    input  logic                        hclk,
    input  logic                        hreset_n,
    input  logic [  AHB_ADDR_WIDTH-1:0] haddr,
    input  logic [ AHB_BURST_WIDTH-1:0] hburst,
    input  logic [                 3:0] hprot,
    input  logic [                 2:0] hsize,
    input  logic [                 1:0] htrans,
    input  logic [  AHB_DATA_WIDTH-1:0] hwdata,
    input  logic [AHB_DATA_WIDTH/8-1:0] hwstrb,
    input  logic                        hwrite,
    output logic [  AHB_DATA_WIDTH-1:0] hrdata,
    output logic                        hreadyout,
    output logic                        hresp,
    input  logic                        hsel,
    input  logic                        hready
);
  ahb_if #(
      .AHB_DATA_WIDTH (AHB_DATA_WIDTH),
      .AHB_ADDR_WIDTH (AHB_ADDR_WIDTH),
      .AHB_BURST_WIDTH(AHB_BURST_WIDTH)
  ) i3c_ahb_if (
      .hclk_i(hclk),
      .hreset_n_i(hreset_n),
      .haddr_i(haddr),
      .hburst_i(hburst),
      .hprot_i(hprot),
      .hsize_i(hsize),
      .htrans_i(htrans),
      .hwdata_i(hwdata),
      .hwstrb_i(hwstrb),
      .hwrite_i(hwrite),
      .hrdata_o(hrdata),
      .hreadyout_o(hreadyout),
      .hresp_o(hresp),
      .hsel_i(hsel),
      .hready_i(hready)
  );
endmodule
