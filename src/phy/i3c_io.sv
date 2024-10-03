// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

/*
  This module provides IO definition for the I3C Core.

  The Core provides a few IO models, which can be used for different use cases:
   - simulation
   - FPGA emulation
   - silicon synthesis
*/

module i3c_io (

    // {SCL, SDA} from the controller
    input logic scl_i,
    input logic sda_i,

    // {SCL, SDA} to the controller
    output logic scl_o,
    output logic sda_o,

    // Open-Drain / Push-Pull control
    input logic sel_od_pp_i,

    // Bus {SCL, SDA}
    inout wire scl_io,
    inout wire sda_io
);

  // SCL buffers
  bufs xbufs_scl (
      .phy_data_i (scl_i),
      .sel_od_pp_i(sel_od_pp_i),
      .phy_data_io(scl_io)
  );

  // SDA buffers
  bufs xbufs_sda (
      .phy_data_i (sda_i),
      .sel_od_pp_i(sel_od_pp_i),
      .phy_data_io(sda_io)
  );

  // Bus state is read to provide feedback to the controller
  // Used to resolve bus arbitration and detect bus error conditions
  assign scl_o = scl_io;
  assign sda_o = sda_io;


endmodule
