// SPDX-License-Identifier: Apache-2.0
`include "i3c_defines.svh"

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
`ifdef AXI_ID_FILTERING
    localparam int unsigned NumPrivIds = `NUM_PRIV_IDS;
`endif
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
    // AXI4 subordinate interface
    axi_if #(
        .AW(AxiAddrWidth),
        .DW(AxiDataWidth),
        .UW(AxiUserWidth),
        .IW(AxiIdWidth)
    ) s_axi_if (
        .clk  (clk),
        .rst_n(rst_n)
    );

`ifdef AXI_ID_FILTERING
    logic disable_id_filtering_i;
    logic [AxiUserWidth-1:0] priv_ids_i [NumPrivIds];
`endif
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
`ifdef AXI_ID_FILTERING
    .NumPrivIds(NumPrivIds),
`endif
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
    .s_axi_if(s_axi_if),

`ifdef AXI_ID_FILTERING
    .disable_id_filtering_i(disable_id_filtering_i),
    .priv_ids_i(priv_ids_i),
`endif
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
