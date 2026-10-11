// SPDX-License-Identifier: Apache-2.0

/*
    Testbench
*/

module tb ();

    import i3c_tb_cfg_pkg::*;

localparam int unsigned DatAw = i3c_pkg::DatAw;
localparam int unsigned DctAw = i3c_pkg::DctAw;

localparam int unsigned CsrAddrWidth = I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
localparam int unsigned CsrDataWidth = I3CCSR_pkg::I3CCSR_DATA_WIDTH;

logic clk;
logic rst_n;

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

    logic disable_id_filtering_i;
    logic [AxiUserWidth-1:0] priv_ids_i [NumPrivIds];

// I3C Bus signals
logic bus_sda;
logic bus_scl;
logic scl_i;
logic sda_i;
logic sel_od_pp;

i3c_wrapper #(
    .UseAxi(UseAxi),
    .AhbDataWidth(AhbDataWidth),
    .AhbAddrWidth(AhbAddrWidth),
    .AxiDataWidth(AxiDataWidth),
    .AxiAddrWidth(AxiAddrWidth),
    .AxiUserWidth(AxiUserWidth),
    .AxiIdWidth(AxiIdWidth),
    .EnableIdFiltering(EnableIdFiltering),
    .NumPrivIds(NumPrivIds),
    .CmdFifoDepth(CmdFifoDepth),
    .RespFifoDepth(RespFifoDepth),
    .RxFifoDepth(RxFifoDepth),
    .TxFifoDepth(TxFifoDepth),
    .IbiFifoDepth(IbiFifoDepth),
    .IbiFifoExtSize(IbiFifoExtSize),
    .DatDepth(DatDepth),
    .DctDepth(DctDepth),
    .DisableLoopback(DisableLoopback),
    .DatAw(DatAw),
    .DctAw(DctAw),
    .CsrAddrWidth(CsrAddrWidth),
    .CsrDataWidth(CsrDataWidth)
) xi3c_wrapper (
    .clk_i(clk),
    .rst_ni(rst_n),
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
    .s_axi_w_if(s_axi_if.w_sub),
    .s_axi_r_if(s_axi_if.r_sub),

    .disable_id_filtering_i(disable_id_filtering_i),
    .priv_ids_i(priv_ids_i),

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
