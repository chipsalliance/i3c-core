// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

module i3c_phy_tb ();
`ifdef SIM
  string simfile = {"dump_", `STRINGIFY(`SIM), ".vcd"};
`else
  string simfile = {"dump_rtl.vcd"};
`endif

  // RTL instantiation --------------------------------------------------------
  logic clk_i;
  logic rst_ni;

  // I3C bus IO
  logic scl_io;
  logic sda_io;

  // I3C controller IO
  logic ctrl_scl_i;
  logic ctrl_sda_i;

  logic ctrl_scl_o;
  logic ctrl_sda_o;

  // I3C PHY IO
  logic scl_i;
  logic scl_o;
  logic scl_en_o;

  logic sda_i;
  logic sda_o;
  logic sda_en_o;

  // Instantiate I3C PHY components
  i3c_phy phy (.*);

  i3c_io phy_io (
      .scl_io(scl_io),
      .scl_i(scl_o),
      .scl_en_i(scl_en_o),

      .sda_io(sda_io),
      .sda_i(sda_o),
      .sda_en_i(sda_en_o)
  );


  // TESTBENCH LOGIC ----------------------------------------------------------

  // Initialize waveform dump
  initial begin
    $dumpfile(simfile);
    $dumpvars(0, i3c_phy_tb);
    clk_i = 0;
    rst_ni = 0;
    scl_i = 1;
    sda_i = 1;
    ctrl_scl_i = 0;
    ctrl_sda_i = 0;
  end

  // Set initial signal values
  integer i;
  initial begin
    for (i = 0; i < 3; i = i + 1) begin
      #50 rst_ni = 1;
      // Controller requesting 1, bus pulled to 0 (High-Z) externally
      #50 ctrl_scl_i = 1;
      ctrl_sda_i = 1;
      scl_i = 0;
      sda_i = 0;
      #100 if (scl_io !== 1'bz) $error($sformatf("Expected scl_io=1'bz, got scl_io=1'b%b", scl_io));
      if (sda_io !== 1'bz) $error($sformatf("Expected sda_io=1'bz, got sda_io=1'b%b", sda_io));

      // Controller requesting 0, expected driven 0 on bus
      ctrl_scl_i = 0;
      ctrl_sda_i = 0;
      #100 if (scl_io !== 1'b0) $error($sformatf("Expected scl_io=1'b0, got scl_io=1'b%b", scl_io));
      if (sda_io !== 1'b0) $error($sformatf("Expected sda_io=1'b0, got sda_io=1'b%b", sda_io));

      // Controller requesting SDA=1, bus SDA pulled to 0 (High-Z) externally
      ctrl_sda_i = 1;
      sda_i = 0;
      #100 if (scl_io !== 1'b0) $error($sformatf("Expected scl_io=1'b0, got scl_io=1'b%b", scl_io));
      if (sda_io !== 1'bz) $error($sformatf("Expected sda_io=1'bz, got sda_io=1'b%b", sda_io));

      // Bus SDA pulled to 1, expect 1 (High-Z)
      sda_i = 1;
      #100 if (scl_io !== 1'b0) $error($sformatf("Expected scl_io=1'b0, got scl_io=1'b%b", scl_io));
      if (sda_io !== 1'bz) $error($sformatf("Expected sda_io=1'bz, got sda_io=1'b%b", sda_io));
      #50 rst_ni = 0;
      #100 ctrl_scl_i = 0;
      ctrl_sda_i = 0;
      #100;
    end
    $finish;
  end

  // Generate clock
  always #10 clk_i = ~clk_i;

endmodule
