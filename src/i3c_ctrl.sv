// Copyright (c) 2024 Antmicro <www.antmicro.com>
// SPDX-License-Identifier: Apache-2.0

module i3c_ctrl
  import i3c_ctrl_pkg::*;
#(
    parameter int TEMP = 0
) (
    input  logic clk,
    input  logic rst_n,
    // Interface to SDA/SCL
    input  logic sda_i,
    output logic sda_o,
    input  logic scl_i,
    output logic scl_o,

    // TODO: Interface to AHB FIFOs

    // Errors and Interrupts
    output i3c_err_t err,
    output i3c_irq_t irq
);

  always_ff @(posedge clk or negedge rst_n) begin : proc_test
    if (!rst_n) begin
      sda_o <= '0;
    end else begin
      sda_o <= '1;
    end
  end

  assign scl_o = '1;

endmodule
