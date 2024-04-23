// SPDX-License-Identifier: Apache-2.0

module i3c_phy_integration_wrapper
  import i2c_pkg::*;
  import I3CCSR_pkg::I3CCSR_DATA_WIDTH;
  import I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
#(
    parameter int unsigned AHB_DATA_WIDTH = 64,
    parameter int unsigned AHB_ADDR_WIDTH = 32,
    parameter int unsigned AHB_BURST_WIDTH = 3
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

    input        i3c_scl_i,    // serial clock input from i3c bus
    output logic i3c_scl_o,    // serial clock output to i3c bus
    output logic i3c_scl_en_o, // serial clock output to i3c bus

    input        i3c_sda_i,    // serial data input from i3c bus
    output logic i3c_sda_o,    // serial data output to i3c bus
    output logic i3c_sda_en_o, // serial data output to i3c bus

    // AHB-Lite interface
    input logic hclk,
    input logic hreset_n,
    input logic [AHB_ADDR_WIDTH-1:0] haddr,
    input logic [AHB_BURST_WIDTH-1:0] hburst,
    input logic [3:0] hprot,
    input logic [2:0] hsize,
    input logic [1:0] htrans,
    input logic [AHB_DATA_WIDTH-1:0] hwdata,
    input logic [AHB_DATA_WIDTH/8-1:0] hwstrb,
    input logic hwrite,
    output logic [AHB_DATA_WIDTH-1:0] hrdata,
    output logic hreadyout,
    output logic hresp,
    input logic hsel,
    input logic hready
);
  logic i3c_scl_int_o;
  logic i3c_sda_int_o;

  assign i3c_scl_o = i3c_scl_en_o ? i3c_scl_int_o : i3c_scl_i;
  assign i3c_sda_o = i3c_sda_en_o ? i3c_sda_int_o : i3c_sda_i;

  i3c i3c (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .i3c_scl_io(),  // Unsupported by Cocotb
      .i3c_sda_io(),  // Unsupported by Cocotb

      .i3c_scl_i(i3c_scl_i),
      .i3c_scl_o(i3c_scl_int_o),
      .i3c_scl_en_o(i3c_scl_en_o),

      .i3c_sda_i(i3c_sda_i),
      .i3c_sda_o(i3c_sda_int_o),
      .i3c_sda_en_o(i3c_sda_en_o),

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
