// SPDX-License-Identifier: Apache-2.0
`include "i3c_defines.svh"
`define DIGITAL_IO_I3C

/*
    Testbench
*/

module tb ();

`ifdef I3C_USE_AHB
    localparam int unsigned AhbDataWidth = `AHB_DATA_WIDTH;
    localparam int unsigned AhbAddrWidth = `AHB_ADDR_WIDTH;
`elsif I3C_USE_AXI
    localparam int unsigned AxiDataWidth = `AXI_DATA_WIDTH;
    localparam int unsigned AxiAddrWidth = `AXI_ADDR_WIDTH;
    localparam int unsigned AxiUserWidth = `AXI_USER_WIDTH;
    localparam int unsigned AxiIdWidth = `AXI_ID_WIDTH;
`endif

localparam int unsigned DatAw = i3c_pkg::DatAw;
localparam int unsigned DctAw = i3c_pkg::DctAw;

localparam int unsigned CsrAddrWidth = I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
localparam int unsigned CsrDataWidth = I3CCSR_pkg::I3CCSR_DATA_WIDTH;

logic clk;
logic rst_n;

`ifdef I3C_USE_AHB
    // AHB-Lite interface
    logic [  AhbAddrWidth-1:0] haddr;
    logic [               2:0] hburst;
    logic [               3:0] hprot;
    logic [               2:0] hsize;
    logic [               1:0] htrans;
    logic [  AhbDataWidth-1:0] hwdata;
    logic [AhbDataWidth/8-1:0] hwstrb;
    logic                      hwrite;
    logic [  AhbDataWidth-1:0] hrdata;
    logic                      hreadyout;
    logic                      hresp;
    logic                      hsel;
    logic                      hready;
`elsif I3C_USE_AXI
    // AXI4 Interface
    // AXI Read Channels
    logic [AxiAddrWidth-1:0] araddr;
    logic [             1:0] arburst;
    logic [             2:0] arsize;
    logic [             7:0] arlen;
    logic [AxiUserWidth-1:0] aruser;
    logic [  AxiIdWidth-1:0] arid;
    logic                    arlock;
    logic                    arvalid;
    logic                    arready;

    logic [AxiDataWidth-1:0] rdata;
    logic [             1:0] rresp;
    logic [  AxiIdWidth-1:0] rid;
    logic                    rlast;
    logic                    rvalid;
    logic                    rready;

    // AXI Write Channels
    logic [AxiAddrWidth-1:0] awaddr;
    logic [             1:0] awburst;
    logic [             2:0] awsize;
    logic [             7:0] awlen;
    logic [AxiUserWidth-1:0] awuser;
    logic [  AxiIdWidth-1:0] awid;
    logic                    awlock;
    logic                    awvalid;
    logic                    awready;

    logic [AxiDataWidth-1:0] wdata;
    logic [AxiDataWidth/8-1:0] wstrb;
    logic                    wlast;
    logic                    wvalid;
    logic                    wready;

    logic [           1:0] bresp;
    logic [AxiIdWidth-1:0] bid;
    logic                  bvalid;
    logic                  bready;
`endif

// I3C Bus signals
logic bus_sda;
logic bus_scl;
logic scl_i;
logic sda_i;
logic sel_od_pp;

i3c_wrapper #(
`ifdef I3C_USE_AHB
    .AhbDataWidth(AhbDataWidth),
    .AhbAddrWidth(AhbAddrWidth),
`elsif I3C_USE_AXI
    .AxiDataWidth(AxiDataWidth),
    .AxiAddrWidth(AxiAddrWidth),
    .AxiUserWidth(AxiUserWidth),
    .AxiIdWidth(AxiIdWidth),
`endif
    .DatAw(DatAw),
    .DctAw(DctAw),
    .CsrAddrWidth(CsrAddrWidth),
    .CsrDataWidth(CsrDataWidth)
) xi3c_wrapper (
    .clk_i(clk),
    .rst_ni(rst_n),
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

    .scl_i(bus_scl),
    .sda_i(bus_sda),
    .scl_o(scl_i),
    .sda_o(sda_i),
    .sel_od_pp_o(sel_od_pp),

    .recovery_payload_available_o(),
    .recovery_image_activated_o()
);

always begin
    #(1) clk = ~clk;
end

initial begin
    rst_n = '0;
    clk = '0;
    #(13)
        rst_n = '0;
    #(100)
        rst_n = '1;
    #(100)
        $finish("Testbench passsed.");
end

endmodule
