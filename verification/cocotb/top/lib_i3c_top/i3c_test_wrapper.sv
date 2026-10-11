// SPDX-License-Identifier: Apache-2.0
module i3c_test_wrapper #(
    parameter bit UseAxi = i3c_tb_cfg_pkg::UseAxi,
    parameter int unsigned AhbDataWidth = i3c_tb_cfg_pkg::AhbDataWidth,
    parameter int unsigned AhbAddrWidth = i3c_tb_cfg_pkg::AhbAddrWidth,
    parameter int unsigned AxiDataWidth = i3c_tb_cfg_pkg::AxiDataWidth,
    parameter int unsigned AxiAddrWidth = i3c_tb_cfg_pkg::AxiAddrWidth,
    parameter int unsigned AxiUserWidth = i3c_tb_cfg_pkg::AxiUserWidth,
    parameter int unsigned AxiIdWidth = i3c_tb_cfg_pkg::AxiIdWidth,
    parameter int unsigned NumPrivIds = i3c_tb_cfg_pkg::NumPrivIds,
    parameter int unsigned DatAw = i3c_pkg::DatAw,
    parameter int unsigned DctAw = i3c_pkg::DctAw,

    parameter int unsigned CsrAddrWidth = I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH,
    parameter int unsigned CsrDataWidth = I3CCSR_pkg::I3CCSR_DATA_WIDTH
)(
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
    input  logic [             3:0] arcache,
    input  logic [             2:0] arprot,
    input  logic [             3:0] arqos,
    input  logic [             3:0] arregion,
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
    input  logic [             3:0] awcache,
    input  logic [             2:0] awprot,
    input  logic [             3:0] awqos,
    input  logic [             3:0] awregion,
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

    input logic disable_id_filtering_i,
    input logic [AxiUserWidth-1:0] priv_ids_i [NumPrivIds],
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

assign clk_i = UseAxi ? aclk : hclk;
assign rst_ni = UseAxi ? areset_n : hreset_n;

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

// AXI4 subordinate interface of the DUT; cocotb drives the discrete
// AXI pins of this wrapper, so they are wired onto the interface here
axi_if #(
    .AW(AxiAddrWidth),
    .DW(AxiDataWidth),
    .UW(AxiUserWidth),
    .IW(AxiIdWidth)
) s_axi_if (
    .clk  (clk_i),
    .rst_n(rst_ni)
);

// AXI Read Channels
assign s_axi_if.araddr  = UseAxi ? araddr : '0;
assign s_axi_if.arburst = UseAxi ? arburst : '0;
assign s_axi_if.arsize  = UseAxi ? arsize : '0;
assign s_axi_if.arlen   = UseAxi ? arlen : '0;
assign s_axi_if.aruser  = UseAxi ? aruser : '0;
assign s_axi_if.arid    = UseAxi ? arid : '0;
assign s_axi_if.arlock  = UseAxi ? arlock : '0;
assign s_axi_if.arcache = UseAxi ? arcache : '0;
assign s_axi_if.arprot  = UseAxi ? arprot : '0;
assign s_axi_if.arqos   = UseAxi ? arqos : '0;
assign s_axi_if.arregion = UseAxi ? arregion : '0;
assign s_axi_if.arvalid = UseAxi ? arvalid : '0;
assign arready          = s_axi_if.arready;

assign rdata            = s_axi_if.rdata;
assign rresp            = s_axi_if.rresp;
assign rid              = s_axi_if.rid;
assign rlast            = s_axi_if.rlast;
assign rvalid           = s_axi_if.rvalid;
assign s_axi_if.rready  = UseAxi ? rready : '0;

// AXI Write Channels
assign s_axi_if.awaddr  = UseAxi ? awaddr : '0;
assign s_axi_if.awburst = UseAxi ? awburst : '0;
assign s_axi_if.awsize  = UseAxi ? awsize : '0;
assign s_axi_if.awlen   = UseAxi ? awlen : '0;
assign s_axi_if.awuser  = UseAxi ? awuser : '0;
assign s_axi_if.awid    = UseAxi ? awid : '0;
assign s_axi_if.awlock  = UseAxi ? awlock : '0;
assign s_axi_if.awcache = UseAxi ? awcache : '0;
assign s_axi_if.awprot  = UseAxi ? awprot : '0;
assign s_axi_if.awqos   = UseAxi ? awqos : '0;
assign s_axi_if.awregion = UseAxi ? awregion : '0;
assign s_axi_if.awvalid = UseAxi ? awvalid : '0;
assign awready          = s_axi_if.awready;

assign s_axi_if.wdata   = UseAxi ? wdata : '0;
assign s_axi_if.wstrb   = UseAxi ? wstrb : '0;
assign s_axi_if.wuser   = '0;
assign s_axi_if.wlast   = UseAxi ? wlast : '0;
assign s_axi_if.wvalid  = UseAxi ? wvalid : '0;
assign wready           = s_axi_if.wready;

assign bresp            = s_axi_if.bresp;
assign bid              = s_axi_if.bid;
assign bvalid           = s_axi_if.bvalid;
assign s_axi_if.bready  = UseAxi ? bready : '0;

i3c_wrapper #(
    .UseAxi(UseAxi),
    .AhbDataWidth(AhbDataWidth),
    .AhbAddrWidth(AhbAddrWidth),
    .AxiDataWidth(AxiDataWidth),
    .AxiAddrWidth(AxiAddrWidth),
    .AxiUserWidth(AxiUserWidth),
    .AxiIdWidth(AxiIdWidth),
    .EnableIdFiltering(i3c_tb_cfg_pkg::EnableIdFiltering),
    .NumPrivIds(NumPrivIds),
    .CmdFifoDepth(i3c_tb_cfg_pkg::CmdFifoDepth),
    .RespFifoDepth(i3c_tb_cfg_pkg::RespFifoDepth),
    .RxFifoDepth(i3c_tb_cfg_pkg::RxFifoDepth),
    .TxFifoDepth(i3c_tb_cfg_pkg::TxFifoDepth),
    .IbiFifoDepth(i3c_tb_cfg_pkg::IbiFifoDepth),
    .IbiFifoExtSize(i3c_tb_cfg_pkg::IbiFifoExtSize),
    .DatDepth(i3c_tb_cfg_pkg::DatDepth),
    .DctDepth(i3c_tb_cfg_pkg::DctDepth),
    .DatAw(DatAw),
    .DctAw(DctAw),
    .CsrAddrWidth(CsrAddrWidth),
    .CsrDataWidth(CsrDataWidth),
    .DisableLoopback(i3c_tb_cfg_pkg::DisableLoopback)
) xi3c_wrapper (
    .clk_i,
    .rst_ni,

    .haddr_i(UseAxi ? '0 : haddr),
    .hburst_i(UseAxi ? '0 : hburst),
    .hprot_i(UseAxi ? '0 : hprot),
    .hsize_i(UseAxi ? '0 : hsize),
    .htrans_i(UseAxi ? '0 : htrans),
    .hwdata_i(UseAxi ? '0 : hwdata),
    .hwstrb_i(UseAxi ? '0 : hwstrb),
    .hwrite_i(UseAxi ? '0 : hwrite),
    .hrdata_o(hrdata),
    .hreadyout_o(hreadyout),
    .hresp_o(hresp),
    .hsel_i(UseAxi ? '0 : hsel),
    .hready_i(UseAxi ? '0 : hready),
    .s_axi_w_if(s_axi_if.w_sub),
    .s_axi_r_if(s_axi_if.r_sub),
      .disable_id_filtering_i(UseAxi ? disable_id_filtering_i : 1'b1),
      .priv_ids_i(priv_ids_i),

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
