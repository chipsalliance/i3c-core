// SPDX-License-Identifier: Apache-2.0

module i3c_test_wrapper
  import i3c_pkg::*;
#(
    parameter int unsigned AhbDataWidth = `AHB_DATA_WIDTH,
    parameter int unsigned AhbAddrWidth = `AHB_ADDR_WIDTH
) (
    input hclk,  // clock
    input hreset_n,  // active low reset

    // AHB-Lite interface
    input logic [AhbAddrWidth-1:0] haddr,
    input logic [2:0] hburst,
    input logic [3:0] hprot,
    input logic [2:0] hsize,
    input logic [1:0] htrans,
    input logic [AhbDataWidth-1:0] hwdata,
    input logic [AhbDataWidth/8-1:0] hwstrb,
    input logic hwrite,
    output logic [AhbDataWidth-1:0] hrdata,
    output logic hreadyout,
    output logic hresp,
    input logic hsel,
    input logic hready,

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
      .AhbDataWidth,
      .AhbAddrWidth
  ) i3c (
      .clk_i (hclk),
      .rst_ni(hreset_n),

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
      .hready_i(hready),

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
