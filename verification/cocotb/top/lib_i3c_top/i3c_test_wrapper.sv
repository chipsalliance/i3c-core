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
`ifdef AXI_ID_FILTERING
    parameter int unsigned NumPrivIds = `NUM_PRIV_IDS,
`endif
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

`ifdef AXI_ID_FILTERING
    input logic disable_id_filtering_i,
    input logic [AxiUserWidth-1:0] priv_ids_i [NumPrivIds],
`endif
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
    output logic bus_scl,

    // I3C Core DUT SDA signals (exposed for bus monitor)
    output logic i3c_sda_o,
    output logic i3c_sda_oe,
    output logic i3c_sel_od_pp,

    output logic peripheral_reset_o,
    input  logic peripheral_reset_done_i,
    output logic escalated_reset_o
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

localparam int unsigned NumDevices = 3; // 2 BFMs (Controller, Target), 1 DUT (I3C Core)

// SDA/SCL data signals per device
logic [NumDevices-1:0] sda_data;
logic [NumDevices-1:0] scl_data;

// SDA/SCL output enable signals per device
logic [NumDevices-1:0] sda_oe;
logic [NumDevices-1:0] scl_oe;

// OD/PP mode per device
logic [NumDevices-1:0] sel_od_pp;

// Device 0: Controller BFM (simulation model, always OD mode)
// BFMs don't have explicit OE, so derive it: in OD mode, driving when output is 0
assign sda_data[0] = sda_sim_ctrl_i;
assign scl_data[0] = scl_sim_ctrl_i;
assign sda_oe[0]   = !sda_sim_ctrl_i;  // OD: driving low when sda=0
assign scl_oe[0]   = !scl_sim_ctrl_i;  // OD: driving low when scl=0
assign sel_od_pp[0] = 1'b0;            // Controller BFM always OD

// Device 1: Target BFM (simulation model, always OD mode)
assign sda_data[1] = sda_sim_target_i;
assign scl_data[1] = scl_sim_target_i;
assign sda_oe[1]   = !sda_sim_target_i; // OD: driving low when sda=0
assign scl_oe[1]   = !scl_sim_target_i; // OD: driving low when scl=0
assign sel_od_pp[1] = 1'b0;             // Target BFM always OD

// Device 2: I3C Core DUT (has proper OE and OD/PP mode signals)
// sda_data[2], scl_data[2], sda_oe[2], sel_od_pp[2] connected below from i3c_wrapper

// I3C Core output signals (i3c_sda_o, i3c_sda_oe, i3c_sel_od_pp are module ports)
logic i3c_scl_o;
logic i3c_scl_oe;

assign sda_data[2]  = i3c_sda_o;
assign scl_data[2]  = i3c_scl_o;
assign sda_oe[2]    = i3c_sda_oe;
assign scl_oe[2]    = !i3c_scl_o;      // SCL from core is OD (driving when low)
assign sel_od_pp[2] = i3c_sel_od_pp;

i3c_bus_harness #(
    .NumDevices(NumDevices)
) xi3_bus_harness (
    .sda_i     (sda_data),
    .sda_oe_i  (sda_oe),
    .sel_od_pp_i(sel_od_pp),
    .scl_i     (scl_data),
    .scl_oe_i  (scl_oe),
    .sda_o     (bus_sda),
    .scl_o     (bus_scl)
);

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
    .ruser_o(),

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
    .wuser_i('0),

    .bresp_o(bresp),
    .bid_o(bid),
    .bvalid_o(bvalid),
    .bready_i(bready),
    .buser_o(),

`ifdef AXI_ID_FILTERING
      .disable_id_filtering_i(disable_id_filtering_i),
      .priv_ids_i(priv_ids_i),
`endif
`endif

    .scl_i(bus_scl),
    .sda_i(bus_sda),
    .scl_o(i3c_scl_o),
    .sda_o(i3c_sda_o),
    .scl_oe(i3c_scl_oe),
    .sda_oe(i3c_sda_oe),
    .sel_od_pp_o(i3c_sel_od_pp),

    .recovery_payload_available_o(),
    .recovery_image_activated_o(),

    .peripheral_reset_o,
    .peripheral_reset_done_i,
    .escalated_reset_o,

    .irq_o()
);

endmodule
