// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

/*
    This module is a wrapper for phy and io modules.
*/
module i3c_phy_io_wrapper (
    input logic clk_i,
    input logic rst_ni,

    // I3C controller IO
    input logic ctrl_scl_i,
    input logic ctrl_sda_i,

    output logic ctrl_scl_o,
    output logic ctrl_sda_o,

    // Open-Drain / Push-Pull control
    input  logic sel_od_pp_i,

    // I3C bus IO
    inout  logic scl_io,
    inout  logic sda_io
);

    logic scl_phy2io;
    logic scl_io2phy;
    logic sda_phy2io;
    logic sda_io2phy;
    logic sel_od_pp;

    i3c_phy xphy(
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .scl_i(scl_io2phy),
        .scl_o(scl_phy2io),
        .sda_i(sda_io2phy),
        .sda_o(sda_phy2io),
        .ctrl_scl_i(ctrl_scl_i),
        .ctrl_sda_i(ctrl_sda_i),
        .ctrl_scl_o(ctrl_scl_o),
        .ctrl_sda_o(ctrl_sda_o),
        .sel_od_pp_i(sel_od_pp_i),
        .sel_od_pp_o(sel_od_pp)
    );

    i3c_io xio(
        .scl_i(scl_phy2io),
        .sda_i(sda_phy2io),
        .scl_o(scl_io2phy),
        .sda_o(sda_io2phy),
        .sel_od_pp_i(sel_od_pp),
        .scl_io(scl_io),
        .sda_io(sda_io)
    );


    initial
    begin
        $dumpfile("dump.vcd");
        $dumpvars(0,i3c_phy_io_wrapper);
    end

endmodule
