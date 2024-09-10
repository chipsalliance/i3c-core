// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

module configuration (
    input clk_i,  // clock
    input rst_ni, // active low reset

    input I3CCSR_pkg::I3CCSR__out_t hwif_out,

    output logic phy_en_o,
    output logic [1:0] phy_mux_select_o,
    output logic i2c_active_en_o,
    output logic i2c_standby_en_o,
    output logic i3c_active_en_o,
    output logic i3c_standby_en_o,

    // Bus monitor
    output logic [19:0] t_su_dat_o,
    output logic [19:0] t_hd_dat_o,
    output logic [19:0] t_r_o,

    // Bus timers
    output logic [19:0] t_bus_free_o,
    output logic [19:0] t_bus_idle_o,
    output logic [19:0] t_bus_available_o
);

  // Mode of operation
  // 00 - DISABLED
  // 01 - ACM_INIT
  // 10 - SCM_RUNNING
  // 11 - SCM_HOT_JOIN
  logic [1:0] stby_cr_enable_init;
  assign stby_cr_enable_init =
    hwif_out.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.STBY_CR_ENABLE_INIT.value;

  assign i3c_active_en_o = (stby_cr_enable_init == 2'b01) | (stby_cr_enable_init == 2'b11);
  assign i3c_standby_en_o = stby_cr_enable_init == 2'b10;

  // Bus Configuration
  logic i2c_dev_present;
  assign i2c_dev_present = hwif_out.I3CBase.HC_CONTROL.I2C_DEV_PRESENT.value;

  // Disables the TTI
  logic target_xact_enable;
  assign target_xact_enable =
    hwif_out.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.TARGET_XACT_ENABLE.value;

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
  assign i2c_active_en_o = 1'b0;
  assign i2c_standby_en_o = 1'b0;

  // Configuration : PHY
  assign phy_en_o = bus_enable;

  // Phy select:
  // 00 - i2c active controller
  // 01 - i3c active controller
  // 10 - i2c standby controller (target)
  // 11 - i3c standby controller (target)
  assign phy_mux_select_o[0] = i3c_active_en_o | i3c_standby_en_o;
  assign phy_mux_select_o[1] = i2c_standby_en_o | i3c_standby_en_o;

  // Configuration: bus_monitor
  assign t_su_dat_o = 20'(hwif_out.I3C_EC.SoCMgmtIf.T_SU_DAT_REG.T_SU_DAT.value);
  assign t_hd_dat_o = 20'(hwif_out.I3C_EC.SoCMgmtIf.T_HD_DAT_REG.T_HD_DAT.value);
  assign t_r_o = 20'(hwif_out.I3C_EC.SoCMgmtIf.T_R_REG.T_R.value);

  // Configuration: bus_timers
  // 20 bits is enough to measure 1ms for clock speed 1GHz.
  // See width_timing_csr function in tools/timing.py
  assign t_bus_free_o = 20'(hwif_out.I3C_EC.SoCMgmtIf.T_FREE_REG.T_FREE.value);
  assign t_bus_idle_o = 20'(hwif_out.I3C_EC.SoCMgmtIf.T_IDLE_REG.T_IDLE.value);
  assign t_bus_available_o = 20'(hwif_out.I3C_EC.SoCMgmtIf.T_AVAL_REG.T_AVAL.value);

endmodule
