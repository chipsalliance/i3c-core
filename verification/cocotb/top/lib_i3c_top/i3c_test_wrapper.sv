// SPDX-License-Identifier: Apache-2.0
`include "i3c_defines.svh"

module i3c_test_wrapper #(
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
)(
`ifdef I3C_USE_AHB
    input logic hclk,
    input logic hreset_n,
    // AHB-Lite interface
    input  logic [  AhbAddrWidth-1:0] haddr,
    input  logic [               2:0] hburst,
    input  logic [               3:0] hprot,
    input  logic [               2:0] hsize,
    input  logic [               1:0] htrans,
    input  logic [  AhbDataWidth-1:0] hwdata,
    input  logic [AhbDataWidth/8-1:0] hwstrb,
    input  logic                      hwrite,
    output logic [  AhbDataWidth-1:0] hrdata,
    output logic                      hreadyout,
    output logic                      hresp,
    input  logic                      hsel,
    input  logic                      hready,
`elsif I3C_USE_AXI
    input logic aclk,
    input logic areset_n,
    // AXI4 Interface
    // AXI Read Channels
    input  logic [AxiAddrWidth-1:0] araddr,
    input  logic [             1:0] arburst,
    input  logic [             2:0] arsize,
    input  logic [             7:0] arlen,
    input  logic [AxiUserWidth-1:0] aruser,
    input  logic [  AxiIdWidth-1:0] arid,
    input  logic                    arlock,
    input  logic                    arvalid,
    output logic                    arready,

    output logic [AxiDataWidth-1:0] rdata,
    output logic [             1:0] rresp,
    output logic [  AxiIdWidth-1:0] rid,
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
    input  logic                    awvalid,
    output logic                    awready,

    input  logic [AxiDataWidth-1:0] wdata,
    input  logic [AxiDataWidth/8-1:0] wstrb,
    input  logic                    wlast,
    input  logic                    wvalid,
    output logic                    wready,

    output logic [           1:0] bresp,
    output logic [AxiIdWidth-1:0] bid,
    output logic                  bvalid,
    input  logic                  bready,
`endif
    // I3C Target Simulation model
    input logic sda_sim_target_i,
    input logic scl_sim_target_i,
    input wire [4:0] debug_state_controller_i,

    // I3C Target Controller model
    input logic sda_sim_ctrl_i,
    input logic scl_sim_ctrl_i,
    input wire [4:0] debug_state_target_i,
    input wire [3:0] debug_detected_header_i,

    // I3C Bus signals
    output logic bus_sda,
    output logic bus_scl
);

logic clk_i;
logic rst_ni;

`ifdef I3C_USE_AHB
assign clk_i = hclk;
assign rst_ni = hreset_n;
`elsif I3C_USE_AXI
assign clk_i = aclk;
assign rst_ni = areset_n;
`endif

localparam int unsigned NumDevices = 3; // 2 Targets, 1 Controller

logic [NumDevices-1:0] sda_i;
logic [NumDevices-1:0] scl_i;

assign sda_i[0] = sda_sim_ctrl_i;
assign scl_i[0] = scl_sim_ctrl_i;
assign sda_i[1] = sda_sim_target_i;
assign scl_i[1] = scl_sim_target_i;

// The {SDA,SCL} signals
logic not_sda;
logic not_scl;
assign sda_i[2] = ~not_sda;
assign scl_i[2] = ~not_scl;

i3c_bus_harness #(
    .NumDevices(NumDevices)
) xi3_bus_harness (
    .sda_i(sda_i),
    .scl_i(scl_i),
    .sda_o(bus_sda),
    .scl_o(bus_scl)
);

logic i3c_scl_en_o_unused;
logic i3c_sda_en_o_unused;
logic i3c_fsm_idle_o_unused;
logic i3c_scl_io_unused;
logic i3c_sda_io_unused;

i3c_wrapper xi3c_wrapper (
    .clk_i,
    .rst_ni,

`ifdef I3C_USE_AHB
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
`elsif I3C_USE_AXI
    .araddr_i(araddr),
    .arburst_i(arburst),
    .arsize_i(arsize),
    .arlen_i(arlen),
    .aruser_i(aruser),
    .arid_i(arid),
    .arlock_i(arlock),
    .arvalid_i(arvalid),
    .arready_o(arready),

    .rdata_o(rdata),
    .rresp_o(rresp),
    .rid_o(rid),
    .rlast_o(rlast),
    .rvalid_o(rvalid),
    .rready_i(rready),

    .awaddr_i(awaddr),
    .awburst_i(awburst),
    .awsize_i(awsize),
    .awlen_i(awlen),
    .awuser_i(awuser),
    .awid_i(awid),
    .awlock_i(awlock),
    .awvalid_i(awvalid),
    .awready_o(awready),

    .wdata_i(wdata),
    .wstrb_i(wstrb),
    .wlast_i(wlast),
    .wvalid_i(wvalid),
    .wready_o(wready),

    .bresp_o(bresp),
    .bid_o(bid),
    .bvalid_o(bvalid),
    .bready_i(bready),
`endif
    // I3C bus IO
    .i3c_scl_i(bus_scl),
    .i3c_scl_o(not_scl),
    .i3c_scl_en_o(i3c_scl_en_o_unused),

    .i3c_sda_i(bus_sda),
    .i3c_sda_o(not_sda),
    .i3c_sda_en_o(i3c_sda_en_o_unused),

    .i3c_fsm_en_i('0), // only used in i2c mode
    .i3c_fsm_idle_o(i3c_fsm_idle_o_unused),

    .i3c_scl_io(i3c_scl_io_unused),
    .i3c_sda_io(i3c_sda_io_unused)
);

endmodule