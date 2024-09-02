// SPDX-License-Identifier: Apache-2.0
`include "i3c_defines.svh"

module i3c_wrapper #(
`ifdef I3C_USE_AHB
    parameter int unsigned AhbDataWidth = `AHB_DATA_WIDTH,
    parameter int unsigned AhbAddrWidth = `AHB_ADDR_WIDTH,
`elsif I3C_USE_AXI
    parameter int unsigned AxiDataWidth = `AXI_DATA_WIDTH,
    parameter int unsigned AxiAddrWidth = `AXI_ADDR_WIDTH,
    parameter int unsigned AxiUserWidth = `AXI_USER_WIDTH,
    parameter int unsigned AxiIdWidth = `AXI_ID_WIDTH,
`endif
    parameter int unsigned DatAw = i3c_pkg::DatAw,
    parameter int unsigned DctAw = i3c_pkg::DctAw,

    parameter int unsigned CsrAddrWidth = I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH,
    parameter int unsigned CsrDataWidth = I3CCSR_pkg::I3CCSR_DATA_WIDTH
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

`ifdef I3C_USE_AHB
    // AHB-Lite interface
    // Byte address of the transfer
    input  logic [  AhbAddrWidth-1:0] haddr_i,
    // Indicates the number of bursts in a transfer
    input  logic [               2:0] hburst_i,     // Unhandled
    // Protection control; provides information on the access type
    input  logic [               3:0] hprot_i,      // Unhandled
    // Indicates the size of the transfer
    input  logic [               2:0] hsize_i,
    // Indicates the transfer type
    input  logic [               1:0] htrans_i,
    // Data for the write operation
    input  logic [  AhbDataWidth-1:0] hwdata_i,
    // Write strobes; Deasserted when write data lanes do not contain valid data
    input  logic [AhbDataWidth/8-1:0] hwstrb_i,     // Unhandled
    // Indicates write operation when asserted
    input  logic                      hwrite_i,
    // Read data
    output logic [  AhbDataWidth-1:0] hrdata_o,
    // Asserted indicates a finished transfer; Can be driven low to extend a transfer
    output logic                      hreadyout_o,
    // Transfer response, high when error occurred
    output logic                      hresp_o,
    // Indicates the subordinate is selected for the transfer
    input  logic                      hsel_i,
    // Indicates all subordinates have finished transfers
    input  logic                      hready_i,

`elsif I3C_USE_AXI
    // AXI4 Interface
    // AXI Read Channels
    input  logic [AxiAddrWidth-1:0] araddr_i,
    input  logic [             1:0] arburst_i,
    input  logic [             2:0] arsize_i,
    input  logic [             7:0] arlen_i,
    input  logic [AxiUserWidth-1:0] aruser_i,
    input  logic [  AxiIdWidth-1:0] arid_i,
    input  logic                    arlock_i,
    input  logic                    arvalid_i,
    output logic                    arready_o,

    output logic [AxiDataWidth-1:0] rdata_o,
    output logic [             1:0] rresp_o,
    output logic [  AxiIdWidth-1:0] rid_o,
    output logic                    rlast_o,
    output logic                    rvalid_o,
    input  logic                    rready_i,

    // AXI Write Channels
    input  logic [AxiAddrWidth-1:0] awaddr_i,
    input  logic [             1:0] awburst_i,
    input  logic [             2:0] awsize_i,
    input  logic [             7:0] awlen_i,
    input  logic [AxiUserWidth-1:0] awuser_i,
    input  logic [  AxiIdWidth-1:0] awid_i,
    input  logic                    awlock_i,
    input  logic                    awvalid_i,
    output logic                    awready_o,

    input  logic [AxiDataWidth-1:0] wdata_i,
    input  logic [             7:0] wstrb_i,
    input  logic                    wlast_i,
    input  logic                    wvalid_i,
    output logic                    wready_o,

    output logic [           1:0] bresp_o,
    output logic [AxiIdWidth-1:0] bid_o,
    output logic                  bvalid_o,
    input  logic                  bready_i,

`endif

    // I3C bus IO
    input  logic i3c_scl_i,    // serial clock input from i3c bus
    output logic i3c_scl_o,    // serial clock output to i3c bus
    output logic i3c_scl_en_o, // serial clock output to i3c bus

    input  logic i3c_sda_i,    // serial data input from i3c bus
    output logic i3c_sda_o,    // serial data output to i3c bus
    output logic i3c_sda_en_o, // serial data output to i3c bus

    input  logic i3c_fsm_en_i,
    output logic i3c_fsm_idle_o,

    inout logic i3c_scl_io,
    inout logic i3c_sda_io

    // TODO: Check if anything missing; Interrupts?
);

  `define REPORT_INCOMPATIBLE_PARAM(param_name, received, expected) \
    `ifdef DEBUG \
      $warning("%s: %0d doesn't match the I3C config: %0d (instance %m).", \
        param_name, received, expected); \
      $info("Overriding %s to %0d.", param_name, expected); \
    `else \
      $fatal(0, "%s: %0d doesn't match the I3C config: %0d (instance %m).", \
      param_name, received, expected); \
    `endif

  // Check widths match the I3C configuration
  initial begin : clptra_vs_i3c_config_param_check
`ifdef I3C_USE_AHB
    if (AhbAddrWidth != `AHB_ADDR_WIDTH) begin : clptra_ahb_addr_w_check
      `REPORT_INCOMPATIBLE_PARAM("AHB address width", AhbAddrWidth, `AHB_ADDR_WIDTH)
    end
    if (AhbDataWidth != `AHB_DATA_WIDTH) begin : clptra_ahb_data_w_check
      `REPORT_INCOMPATIBLE_PARAM("AHB data width", AhbDataWidth, `AHB_DATA_WIDTH)
    end
`elsif I3C_USE_AXI
    if (AxiAddrWidth != `AXI_ADDR_WIDTH) begin : clptra_axi_addr_w_check
      `REPORT_INCOMPATIBLE_PARAM("AXI address width", AxiAddrWidth, `AXI_ADDR_WIDTH)
    end
    if (AxiDataWidth != `AXI_DATA_WIDTH) begin : clptra_axi_data_w_check
      `REPORT_INCOMPATIBLE_PARAM("AXI data width", AxiDataWidth, `AXI_DATA_WIDTH)
    end
    if (AxiUserWidth != `AXI_USER_WIDTH) begin : clptra_axi_user_w_check
      `REPORT_INCOMPATIBLE_PARAM("AXI user width", AxiUserWidth, `AXI_USER_WIDTH)
    end
    if (AxiIdWidth != `AxiIdWidth) begin : clptra_axi_id_w_check
      `REPORT_INCOMPATIBLE_PARAM("AXI ID width", AxiIdWidth, `AxiIdWidth)
    end
`endif
  end

`ifdef I3C_USE_AXI
  initial begin : axi_data_user_w_check
    if (AxiUserWidth != AxiDataWidth) begin
      $fatal(0, {"AxiUserWidth (%0d) != AxiDataWidth (%0d): Current AXI doesn't support ",
                 "different USER and DATA widths. (instance %m)."}, AxiUserWidth, AxiDataWidth);
      `REPORT_INCOMPATIBLE_PARAM("AXI ID width", AxiIdWidth, `AxiIdWidth)
    end
  end
`endif

  // DAT memory export interface
  i3c_pkg::dat_mem_src_t  dat_mem_src;
  i3c_pkg::dat_mem_sink_t dat_mem_sink;

  // DCT memory export interface
  i3c_pkg::dct_mem_src_t  dct_mem_src;
  i3c_pkg::dct_mem_sink_t dct_mem_sink;

  i3c #(
`ifdef I3C_USE_AHB
      .AhbDataWidth,
      .AhbAddrWidth,
`endif
      .CsrDataWidth,
      .CsrAddrWidth
  ) i3c (
      .clk_i,
      .rst_ni,

`ifdef I3C_USE_AHB
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
`elsif I3C_USE_AXI
      // AXI Read Channels
      .araddr_i(araddr_i),
      .arburst_i(arburst_i),
      .arsize_i(arsize_i),
      .arlen_i(arlen_i),
      .aruser_i(aruser_i),
      .arid_i(arid_i),
      .arlock_i(arlock_i),
      .arvalid_i(arvalid_i),
      .arready_o(arready_o),

      .rdata_o(rdata_o),
      .rresp_o(rresp_o),
      .rid_o(rid_o),
      .rlast_o(rlast_o),
      .rvalid_o(rvalid_o),
      .rready_i(rready_i),

      // AXI Write Channels
      .awaddr_i(awaddr_i),
      .awburst_i(awburst_i),
      .awsize_i(awsize_i),
      .awlen_i(awlen_i),
      .awuser_i(awuser_i),
      .awid_i(awid_i),
      .awlock_i(awlock_i),
      .awvalid_i(awvalid_i),
      .awready_o(awready_o),

      .wdata_i (wdata_i),
      .wstrb_i (wstrb_i),
      .wlast_i (wlast_i),
      .wvalid_i(wvalid_i),
      .wready_o(wready_o),

      .bresp_o(bresp_o),
      .bid_o(bid_o),
      .bvalid_o(bvalid_o),
      .bready_i(bready_i),
`endif

      .i3c_scl_i,
      .i3c_scl_o,
      .i3c_scl_en_o,

      .i3c_sda_i,
      .i3c_sda_o,
      .i3c_sda_en_o,

      .dat_mem_src_i (dat_mem_src),
      .dat_mem_sink_o(dat_mem_sink),

      .dct_mem_src_i (dct_mem_src),
      .dct_mem_sink_o(dct_mem_sink),

      .i3c_fsm_en_i,
      .i3c_fsm_idle_o
  );

  prim_ram_1p_adv #(
      .Depth(`DAT_DEPTH),
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
      .Depth(`DCT_DEPTH),
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

  i3c_io phy_io (
      .scl_io(i3c_scl_io),
      .scl_i(i3c_scl_o),
      .scl_en_i(i3c_scl_en_o),

      .sda_io(i3c_sda_io),
      .sda_i(i3c_sda_o),
      .sda_en_i(i3c_sda_en_o)
  );

endmodule
