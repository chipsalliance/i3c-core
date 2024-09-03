// SPDX-License-Identifier: Apache-2.0

/*
    I3C Bus Harness

    Model the tristate bus.
    Number of controllers and targets is configurable.

    Verilator does not simulate 'x' and 'z' natively.
    All inputs of the bus are ANDed to simulate the Open-Drain Driver behavior.

*/
module i3c_bus_harness #(
    parameter int unsigned NumDevices = 3 // Joint number of Controller and Target devices
) (
    input wire [NumDevices-1:0] sda_i,
    input wire [NumDevices-1:0] scl_i,

    output wire sda_o,
    output wire scl_o
);

  assign sda_o = &sda_i;
  assign scl_o = &scl_i;

  wire test;

  assign test = &sda_i;

endmodule
