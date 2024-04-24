// SPDX-License-Identifier: Apache-2.0

module i3c_top
  import i3c_pkg::*;
  import i2c_pkg::*;
  import I3CCSR_pkg::*;
#(
    parameter int unsigned AHB_DATA_WIDTH  = 64,
    parameter int unsigned AHB_ADDR_WIDTH  = 32,
    parameter int unsigned AHB_BURST_WIDTH = 3
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

`ifdef I3C_USE_AHB
    // AHB-Lite interface
    // Byte address of the transfer
    input  logic [  AHB_ADDR_WIDTH-1:0] haddr_i,
    // Indicates the number of bursts in a transfer
    input  logic [ AHB_BURST_WIDTH-1:0] hburst_i,     // Unhandled
    // Protection control; provides information on the access type
    input  logic [                 3:0] hprot_i,      // Unhandled
    // Indicates the size of the transfer
    input  logic [                 2:0] hsize_i,
    // Indicates the transfer type
    input  logic [                 1:0] htrans_i,
    // Data for the write operation
    input  logic [  AHB_DATA_WIDTH-1:0] hwdata_i,
    // Write strobes; Deasserted when write data lanes do not contain valid data
    input  logic [AHB_DATA_WIDTH/8-1:0] hwstrb_i,     // Unhandled
    // Indicates write operation when asserted
    input  logic                        hwrite_i,
    // Read data
    output logic [  AHB_DATA_WIDTH-1:0] hrdata_o,
    // Assrted indicates a finished transfer; Can be driven low to extend a transfer
    output logic                        hreadyout_o,
    // Transfer response, high when error occured
    output logic                        hresp_o,
    // Indicates the subordinate is selected for the transfer
    input  logic                        hsel_i,
    // Indicates all subordiantes have finished transfers
    input  logic                        hready_i,

    // TODO: AXI4 I/O
    // `else

`endif

    // I3C controller IO
    inout i3c_scl_io,  // serial clock inout to/from i3c bus
    inout i3c_sda_io,  // serial data inout to/from i3c bus

    // I3C bus IO
    input        i3c_scl_i,    // serial clock input from i3c bus
    output logic i3c_scl_o,    // serial clock output to i3c bus
    output logic i3c_scl_en_o, // serial clock output to i3c bus

    input        i3c_sda_i,    // serial data input from i3c bus
    output logic i3c_sda_o,    // serial data output to i3c bus
    output logic i3c_sda_en_o  // serial data output to i3c bus

    // TODO: Check if anything missing; Interrupts?
);

  // I3C SW CSR IF
  logic s_cpuif_req;
  logic s_cpuif_req_is_wr;
  logic [I3CCSR_MIN_ADDR_WIDTH-1:0] s_cpuif_addr;
  logic [I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_data;
  logic [I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_biten;
  logic s_cpuif_req_stall_wr;
  logic s_cpuif_req_stall_rd;
  logic s_cpuif_rd_ack;
  logic s_cpuif_rd_err;
  logic [I3CCSR_DATA_WIDTH-1:0] s_cpuif_rd_data;
  logic s_cpuif_wr_ack;
  logic s_cpuif_wr_err;

`ifdef I3C_USE_AHB
  ahb_if #(
      .AHB_DATA_WIDTH (AHB_DATA_WIDTH),
      .AHB_ADDR_WIDTH (AHB_ADDR_WIDTH),
      .AHB_BURST_WIDTH(AHB_BURST_WIDTH)
  ) i3c_ahb_if (
      .hclk_i(clk_i),
      .hreset_n_i(rst_ni),
      .haddr_i(haddr_i),
      .hburst_i(hburst_i),
      .hprot_i(hprot_i),
      .hsize_i(hsize_i),
      .htrans_i(htrans_i),
      .hwdata_i(hwdata_i),
      .hwstrb_i(hwstrb_i),
      .hwrite_i(hwrite_i),
      .hrdata_o(hrdata_o),
      .hreadyout_o(hreadyout_o),
      .hresp_o(hresp_o),
      .hsel_i(hsel_i),
      .hready_i(hready_i),
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
  // TODO: AXI4 adapter to SW reg
  // `else
`endif

  i3c #(
      .AHB_DATA_WIDTH (AHB_DATA_WIDTH),
      .AHB_ADDR_WIDTH (AHB_ADDR_WIDTH),
      .AHB_BURST_WIDTH(AHB_BURST_WIDTH)
  ) i3c (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

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

      .i3c_scl_io(i3c_scl_io),
      .i3c_sda_io(i3c_sda_io),

      .i3c_scl_i(i3c_scl_i),
      .i3c_scl_o(i3c_scl_int_o),
      .i3c_scl_en_o(i3c_scl_en_o),

      .i3c_sda_i(i3c_sda_i),
      .i3c_sda_o(i3c_sda_int_o),
      .i3c_sda_en_o(i3c_sda_en_o)
  );

endmodule

