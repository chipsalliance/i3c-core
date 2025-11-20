// SPDX-License-Identifier: Apache-2.0

/*
  This module extracts fields related to addressing from CSRs.
*/

module configuration (
    input logic clk_i,
    input logic rst_ni,

    input I3CCSR_pkg::I3CCSR__out_t hwif_out_i,

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
    output logic [19:0] t_f_o,

    // Bus timers
    output logic [19:0] t_bus_free_o,
    output logic [19:0] t_bus_idle_o,
    output logic [19:0] t_bus_available_o,

    output logic [15:0] get_mwl_o,  // Get Max Write Length
    output logic [15:0] get_mrl_o,  // Get Max Read Length
    output logic [15:0] get_status_fmt1_o,  // Get Status Format 1

    output logic [47:0] pid_o,  // Target ID
    output logic [ 7:0] bcr_o,  // Bus Characteristics Register
    output logic [ 7:0] dcr_o,  // Device Characteristics Register
    output logic [47:0] virtual_pid_o,  // Target ID
    output logic [ 7:0] virtual_bcr_o,  // Bus Characteristics Register
    output logic [ 7:0] virtual_dcr_o,  // Device Characteristics Register

    // Output effective target address (static or dynamic or recovery)
    output logic [6:0] target_sta_addr_o,
    output logic target_sta_addr_valid_o,
    output logic [6:0] target_dyn_addr_o,
    output logic target_dyn_addr_valid_o,
    output logic [6:0] virtual_target_sta_addr_o,
    output logic virtual_target_sta_addr_valid_o,
    output logic [6:0] virtual_target_dyn_addr_o,
    output logic virtual_target_dyn_addr_valid_o,
    output logic [6:0] target_ibi_addr_o,
    output logic target_ibi_addr_valid_o,

    // Hot-Join address is always valid
    output logic [6:0] target_hot_join_addr_o,

    // Response for ENTDAA
    output logic [63:0] daa_unique_response_o,

    // Target IBI
    output logic ibi_enable_o,
    output logic [2:0] ibi_retry_num_o,

    input logic set_mwl_i,
    input logic set_mrl_i,
    input logic [15:0] mwl_i,
    input logic [15:0] mrl_i
);

  // Mode of operation
  // 00 - DISABLED
  // 01 - ACM_INIT
  // 10 - SCM_RUNNING
  // 11 - SCM_HOT_JOIN
  logic [1:0] stby_cr_enable_init;
  assign stby_cr_enable_init =
    hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.STBY_CR_ENABLE_INIT.value;

  assign i3c_active_en_o = (stby_cr_enable_init == 2'b01) | (stby_cr_enable_init == 2'b11);
  assign i3c_standby_en_o = stby_cr_enable_init == 2'b10;

  // Bus Configuration
  logic i2c_dev_present;
`ifdef CONTROLLER_SUPPORT
  assign i2c_dev_present = hwif_out_i.I3CBase.HC_CONTROL.I2C_DEV_PRESENT.value;
`else
  assign i2c_dev_present = '0;
`endif // CONTROLLER_SUPPORT

  // Disables the TTI
  logic target_xact_enable;
  assign target_xact_enable =
    hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.TARGET_XACT_ENABLE.value;

  // Define state: running, idle, waiting, halted, etc.
  logic bus_enable;
  logic resume;
  logic abort;
`ifdef CONTROLLER_SUPPORT
  assign bus_enable = hwif_out_i.I3CBase.HC_CONTROL.BUS_ENABLE.value;
  assign resume = hwif_out_i.I3CBase.HC_CONTROL.RESUME.value;
  assign abort = hwif_out_i.I3CBase.HC_CONTROL.ABORT.value;
`else
  assign bus_enable = 1'b1;
  assign resume = '0;
  assign abort = '0;
`endif // CONTROLLER_SUPPORT

  // These affect queue ctrl logic
  logic pio_enable;
  logic pio_abort;
  logic pio_rs;
`ifdef CONTROLLER_SUPPORT
  assign pio_enable = hwif_out_i.PIOControl.PIO_CONTROL.ENABLE.value;
  assign pio_abort = hwif_out_i.PIOControl.PIO_CONTROL.ABORT.value;
  assign pio_rs = hwif_out_i.PIOControl.PIO_CONTROL.RS.value;
`else
  assign pio_enable = '0;
  assign pio_abort = '0;
  assign pio_rs = '0;
`endif // CONTROLLER_SUPPORT

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
  assign t_su_dat_o = 20'(hwif_out_i.I3C_EC.SoCMgmtIf.T_SU_DAT_REG.T_SU_DAT.value);
  assign t_hd_dat_o = 20'(hwif_out_i.I3C_EC.SoCMgmtIf.T_HD_DAT_REG.T_HD_DAT.value);
  assign t_r_o = 20'(hwif_out_i.I3C_EC.SoCMgmtIf.T_R_REG.T_R.value);
  assign t_f_o = 20'(hwif_out_i.I3C_EC.SoCMgmtIf.T_F_REG.T_F.value);

  // Configuration: bus_timers
  // 20 bits is enough to measure 1ms for clock speed 1GHz.
  // See width_timing_csr function in tools/timing.py
  assign t_bus_free_o = 20'(hwif_out_i.I3C_EC.SoCMgmtIf.T_FREE_REG.T_FREE.value);
  assign t_bus_idle_o = 20'(hwif_out_i.I3C_EC.SoCMgmtIf.T_IDLE_REG.T_IDLE.value);
  assign t_bus_available_o = 20'(hwif_out_i.I3C_EC.SoCMgmtIf.T_AVAL_REG.T_AVAL.value);


  assign target_sta_addr_valid_o =
    hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.STATIC_ADDR_VALID.value;
  assign target_sta_addr_o = hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.STATIC_ADDR.value;

  assign target_dyn_addr_valid_o =
    hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID.value;
  assign target_dyn_addr_o = hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR.value;

  assign virtual_target_sta_addr_valid_o =
    hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR_VALID.value;
  assign virtual_target_sta_addr_o = hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR.value;

  assign virtual_target_dyn_addr_valid_o =
    hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID.value;
  assign virtual_target_dyn_addr_o = hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR.value;

  logic [15:0] mwl_dword;
  logic [15:0] mrl_dword;

  assign mwl_dword = 1 << (hwif_out_i.I3C_EC.TTI.QUEUE_SIZE.TX_DATA_BUFFER_SIZE.value + 1'b1);
  assign mrl_dword = 1 << (hwif_out_i.I3C_EC.TTI.QUEUE_SIZE.RX_DATA_BUFFER_SIZE.value + 1'b1);

  always @(posedge clk_i) begin : mrl_mwl
    if (~rst_ni) begin
      get_mwl_o <= 16'd256;
      get_mrl_o <= 16'd256;
    end else begin
      if (set_mwl_i) get_mwl_o <= mwl_i;
      if (set_mrl_i) get_mrl_o <= mrl_i;
    end
  end

  assign get_status_fmt1_o = {
    8'h00,  // Vendor-specific meaning
    2'b11,  // Unable to do Handoff
    hwif_out_i.I3C_EC.TTI.STATUS.PROTOCOL_ERROR,
    hwif_out_i.I3C_EC.TTI.INTERRUPT_STATUS.PENDING_INTERRUPT
  };

  assign pid_o = {
    hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_CHAR.PID_HI.value,
    1'b0,
    hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_PID_LO.PID_LO.value
  };

  assign bcr_o = {
    hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_CHAR.BCR_FIXED.value,
    hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_CHAR.BCR_VAR.value
  };

  assign dcr_o = hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_CHAR.DCR.value;
  assign virtual_pid_o = {
    hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_VIRTUAL_DEVICE_CHAR.PID_HI.value,
    1'b0,
    hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_VIRTUAL_DEVICE_PID_LO.PID_LO.value
  };

  assign virtual_bcr_o = {
    hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_VIRTUAL_DEVICE_CHAR.BCR_FIXED.value,
    hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_VIRTUAL_DEVICE_CHAR.BCR_VAR.value
  };

  assign virtual_dcr_o = hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_VIRTUAL_DEVICE_CHAR.DCR.value;
  assign daa_unique_response_o = {pid_o, bcr_o, dcr_o};

  assign target_ibi_addr_o = target_dyn_addr_valid_o ? target_dyn_addr_o : target_sta_addr_o;
  assign target_ibi_addr_valid_o = target_sta_addr_valid_o || target_dyn_addr_valid_o;

  assign target_hot_join_addr_o = 7'h02;

  // Configuration: Target IBI
  assign ibi_enable_o = hwif_out_i.I3C_EC.TTI.CONTROL.IBI_EN.value;
  assign ibi_retry_num_o = hwif_out_i.I3C_EC.TTI.CONTROL.IBI_RETRY_NUM.value;

endmodule
