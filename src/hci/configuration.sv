// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

module configuration (
    input clk_i,  // clock
    input rst_ni, // active low reset

    input I3CCSR_pkg::I3CCSR__out_t hwif_out,
    output i3c_pkg::i3c_config_t core_config
);

  // If we want to do R/W from/to CSRs:
  // resprst = hwif_out.I3CBase.RESET_CONTROL.RESP_QUEUE_RST.value;
  // hwif_in.I3CBase.RESET_CONTROL.CMD_QUEUE_RST.we = cmd_reset_ctrl_we;

  // Define Mode of operation
  // Sources:
  logic [1:0] stby_cr_enable_init;
  assign stby_cr_enable_init =
    hwif_out.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.STBY_CR_ENABLE_INIT.value;

  logic i2c_dev_present;
  assign i2c_dev_present = hwif_out.I3CBase.HC_CONTROL.I2C_DEV_PRESENT.value;

  // This disables TTI for software
  logic target_xact_enable;
  assign target_xact_enable =
    hwif_out.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.TARGET_XACT_ENABLE.value;

  // Note, this field is a capability, not a mode selector, do not use to make decisions
  // assign operation_mode = hwif_out.I3C_EC.StandbyControllerModeRegisters.CONTROLLER_CONFIG.OPERATION_MODE.value;

  // Output: what mode are we in?

  // Define state: running, idle, waiting, halted, etc.
  logic bus_enable;
  logic resume;
  logic abort;
  assign bus_enable = hwif_out.I3CBase.HC_CONTROL.BUS_ENABLE.value;
  assign resume = hwif_out.I3CBase.HC_CONTROL.RESUME.value;
  assign abort = hwif_out.I3CBase.HC_CONTROL.ABORT.value;

  // These affect queue ctrl logic
  logic pio_enable;
  logic pio_abort;
  logic pio_rs;
  assign pio_enable = hwif_out.PIOControl.PIO_CONTROL.ENABLE.value;
  assign pio_abort = hwif_out.PIOControl.PIO_CONTROL.ABORT.value;
  assign pio_rs = hwif_out.PIOControl.PIO_CONTROL.RS.value;

  // TODO: Assert that these 4 are not 1 at the same time
  assign core_config.i2c_active_en = 1'b0;
  assign core_config.i3c_active_en = 1'b0;
  assign core_config.i2c_standby_en = 1'b0;
  assign core_config.i3c_standby_en = 1'b1;

  // Phy select:
  // 00 - i2c controller
  // 01 - i3c controller
  // 10 - i2c target
  // 11 - i3c target
  // TODO: Fix latch
  // verilator lint_off LATCH
  always_comb begin
    if (core_config.i2c_active_en) core_config.phy_mux_select = 2'b00;
    if (core_config.i3c_active_en) core_config.phy_mux_select = 2'b01;
    if (core_config.i2c_standby_en) core_config.phy_mux_select = 2'b10;
    if (core_config.i3c_standby_en) core_config.phy_mux_select = 2'b11;
  end
  // verilator lint_on LATCH

endmodule
