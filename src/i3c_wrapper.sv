// SPDX-License-Identifier: Apache-2.0

module i3c_wrapper
  import i3c_pkg::*;
#(
    parameter int unsigned AHB_DATA_WIDTH = 64,
    parameter int unsigned AHB_ADDR_WIDTH = 32,
    parameter int unsigned AHB_BURST_WIDTH = 3,
    parameter int unsigned FifoDepth = 64,
    parameter int unsigned AcqFifoDepth = 64,
    localparam int unsigned FifoDepthWidth = $clog2(FifoDepth + 1),
    localparam int unsigned AcqFifoDepthWidth = $clog2(AcqFifoDepth + 1)
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

    // I3C bus IO
    input        i3c_scl_i,    // serial clock input from i3c bus
    output logic i3c_scl_o,    // serial clock output to i3c bus
    output logic i3c_scl_en_o, // serial clock output to i3c bus

    input        i3c_sda_i,    // serial data input from i3c bus
    output logic i3c_sda_o,    // serial data output to i3c bus
    output logic i3c_sda_en_o  // serial data output to i3c bus

    // TODO: Check if anything missing; Interrupts?
);

  // DAT memory export interface
  dat_mem_src_t  dat_mem_src;
  dat_mem_sink_t dat_mem_sink;

  // DCT memory export interface
  dct_mem_src_t  dct_mem_src;
  dct_mem_sink_t dct_mem_sink;

  i3c i3c (
      .clk_i,
      .rst_ni,

      .haddr_i,
      .hburst_i,
      .hprot_i,
      .hsize_i,
      .htrans_i,
      .hwdata_i,
      .hwstrb_i,
      .hwrite_i,
      .hrdata_o,
      .hreadyout_o,
      .hresp_o,
      .hsel_i,
      .hready_i,

      .i3c_scl_i,
      .i3c_scl_o,
      .i3c_scl_en_o,

      .i3c_sda_i,
      .i3c_sda_o,
      .i3c_sda_en_o,

      .dat_mem_src_i (dat_mem_src),
      .dat_mem_sink_o(dat_mem_sink),

      .dct_mem_src_i (dct_mem_src),
      .dct_mem_sink_o(dct_mem_sink)
  );

  prim_ram_1p_adv #(
      .Depth(DatDepth),
      .Width(64),
      .DataBitsPerMask(32)
  ) dat_memory (
      .clk_i,
      .rst_ni,
      .req_i(dat_mem_sink.req),
      .write_i(dat_mem_sink.write),
      .addr_i(dat_mem_sink.addr),
      .wdata_i(dat_mem_sink.wdata),
      .wmask_i(dat_mem_sink.wmask),
      .rdata_o(dat_mem_src.rdata),
      .rvalid_o(),  // Unused
      .rerror_o(),  // Unused
      .cfg_i('0)  // Unused
  );

  prim_ram_1p_adv #(
      .Depth(DctDepth),
      .Width(128),
      .DataBitsPerMask(32)
  ) dct_memory (
      .clk_i,
      .rst_ni,
      .req_i(dct_mem_sink.req),
      .write_i(dct_mem_sink.write),
      .addr_i(dct_mem_sink.addr),
      .wdata_i(dct_mem_sink.wdata),
      .wmask_i(dct_mem_sink.wmask),
      .rdata_o(dct_mem_src.rdata),
      .rvalid_o(),  // Unused
      .rerror_o(),  // Unused
      .cfg_i('0)  // Unused
  );

endmodule
