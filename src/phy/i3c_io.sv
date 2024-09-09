// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

/*
  This module provides IO definition for the I3C Core.

  The I3C IO might require different models, depending on
  the desired use case (silicon, fpga, simulation). For that
  reason, this module is not included in the i3c module, but
  is instantiated in the i3c_wrapper.
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
    inout logic scl_io,
    inout logic sda_io
);

  wire scl_io_int;
  wire sda_io_int;

  // SCL buffers
  bufs xbufs_scl (
      .phy_data_i (scl_i),
      .sel_od_pp_i(sel_od_pp_i),
      .phy_data_io(scl_io_int)
  );

  // SDA buffers
  bufs xbufs_sda (
      .phy_data_i (sda_i),
      .sel_od_pp_i(sel_od_pp_i),
      .phy_data_io(sda_io_int)
  );

  // Model pull-up resistor
  // The pull-up strength should be:
  //   - weak compared to PP buffer
  //   - weak compared to 0 driven by the OD buffer
  //   - strong enough to pull-up 'z' state
  assign (weak0, weak1) scl_io_int = 1;
  assign (weak0, weak1) sda_io_int = 1;
  assign scl_io = scl_io_int;
  assign sda_io = sda_io_int;

  // Bus state is read to provide feedback to the controller
  // Used to resolve bus arbitration and detect bus error conditions
  assign scl_o = scl_io;
  assign sda_o = sda_io;


endmodule
