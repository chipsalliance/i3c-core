module csri
  import i3c_pkg::*;
#(
    parameter int unsigned CsrDataWidth = 32,
    parameter int unsigned CsrAddrWidth = 12
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

`ifdef TARGET_SUPPORT
    // Target Transaction Interface CSRs
    input  I3CCSR_pkg::I3CCSR__I3C_EC__TTI__in_t  hwif_tti_i,
    output I3CCSR_pkg::I3CCSR__I3C_EC__TTI__out_t hwif_tti_o,

    // Recovery interface CSRs
    input  I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__in_t  hwif_rec_i,
    output I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__out_t hwif_rec_o,

    // SoC Management CSR Interface
    input I3CCSR_pkg::I3CCSR__I3C_EC__SoCMgmtIf__in_t hwif_socmgmt_i,
    output I3CCSR_pkg::I3CCSR__I3C_EC__SoCMgmtIf__out_t hwif_socmgmt_o,
`endif  // TARGET_SUPPORT

`ifdef CONTROLLER_SUPPORT
    // PIO CONTROL CSR interface
    input  I3CCSR_pkg::I3CCSR__PIOControl__in_t  hwif_pio_control_i,
    output I3CCSR_pkg::I3CCSR__PIOControl__out_t hwif_pio_control_o,

    // I3C BASE CSR interface
    input  I3CCSR_pkg::I3CCSR__I3CBase__in_t  hwif_base_i,
    output I3CCSR_pkg::I3CCSR__I3CBase__out_t hwif_base_o,

    // DAT CSR interface
    input  I3CCSR_pkg::I3CCSR__DAT__in_t  dat_i,
    output I3CCSR_pkg::I3CCSR__DAT__out_t dat_o,

    // DCT CSR interface
    input  I3CCSR_pkg::I3CCSR__DCT__in_t  dct_i,
    output I3CCSR_pkg::I3CCSR__DCT__out_t dct_o,
`endif  // CONTROLLER_SUPPORT

    output I3CCSR_pkg::I3CCSR__out_t hwif_out_o,

    // I3C SW CSR access interface
    input  logic                    s_cpuif_req,
    input  logic                    s_cpuif_req_is_wr,
    input  logic [CsrAddrWidth-1:0] s_cpuif_addr,
    input  logic [CsrDataWidth-1:0] s_cpuif_wr_data,
    input  logic [CsrDataWidth-1:0] s_cpuif_wr_biten,
    output logic                    s_cpuif_req_stall_wr,
    output logic                    s_cpuif_req_stall_rd,
    output logic                    s_cpuif_rd_ack,
    output logic                    s_cpuif_rd_err,
    output logic [CsrDataWidth-1:0] s_cpuif_rd_data,
    output logic                    s_cpuif_wr_ack,
    output logic                    s_cpuif_wr_err,

    // Controller configuration (shared with target)
    input logic [6:0] set_dasa_i,
    input logic       set_dasa_valid_i,
    input logic       set_dasa_virtual_device_i,
    input logic       rstdaa_i,

    input logic [6:0] newda_i,
    input logic       set_newda_i,
    input logic       set_newda_virtual_device_i,

    input logic [7:0] rst_action_i,
    input logic rst_action_valid_i
);

  I3CCSR_pkg::I3CCSR__in_t hwif_in;

  // Propagate reset to CSRs
  assign hwif_in.rst_ni = rst_ni;

  always_comb begin : connect_hwif
`ifdef CONTROLLER_SUPPORT
    hwif_in.I3CBase = hwif_base_i;
    hwif_in.PIOControl = hwif_pio_control_i;
    hwif_in.DAT = dat_i;
    hwif_in.DCT = dct_i;

    hwif_base_o = hwif_out_o.I3CBase;
    hwif_pio_control_o = hwif_out_o.PIOControl;
    dat_o = hwif_out_o.DAT;
    dct_o = hwif_out_o.DCT;
`endif  // CONTROLLER_SUPPORT

`ifdef TARGET_SUPPORT
    hwif_tti_o = hwif_out_o.I3C_EC.TTI;
    hwif_rec_o = hwif_out_o.I3C_EC.SecFwRecoveryIf;
    hwif_socmgmt_o = hwif_out_o.I3C_EC.SoCMgmtIf;

    hwif_in.I3C_EC.TTI = hwif_tti_i;
    hwif_in.I3C_EC.SecFwRecoveryIf = hwif_rec_i;
    hwif_in.I3C_EC.SoCMgmtIf = hwif_socmgmt_i;

`endif  // TARGET_SUPPORT
  end

  // Update Standby Controller mode based on the controller configuration status
  always_comb begin : wire_hwif_rstact
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_RSTACT_PARAMS.RST_ACTION.next = rst_action_valid_i ? rst_action_i : '0;
  end

  // Update Standby Controller mode based on the controller configuration status
  always_comb begin : wire_address_setting
    // Target address
    if (set_dasa_valid_i | rstdaa_i) begin
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID.we = (set_dasa_valid_i | rstdaa_i) && ~(set_dasa_virtual_device_i);
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID.next = (rstdaa_i && ~(set_dasa_virtual_device_i)) ? '0: set_dasa_valid_i;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR.we = (set_dasa_valid_i | rstdaa_i) && ~(set_dasa_virtual_device_i);
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR.next = (rstdaa_i && ~(set_dasa_virtual_device_i)) ? '0 : set_dasa_i;
      // Virtual device address
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID.we = (set_dasa_valid_i | rstdaa_i) && (set_dasa_virtual_device_i);
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID.next = rstdaa_i && set_dasa_virtual_device_i ? '0: set_dasa_valid_i;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR.we = (set_dasa_valid_i | rstdaa_i) && (set_dasa_virtual_device_i);
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR.next = rstdaa_i && set_dasa_virtual_device_i ? '0 : set_dasa_i;
    end else if (set_newda_i | set_newda_virtual_device_i) begin
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID.we = set_newda_i && ~(set_newda_virtual_device_i);
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID.next = 1'b1;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR.we = set_newda_i && ~(set_newda_virtual_device_i);
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR.next = newda_i;
      // Virtual device address
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID.we = set_newda_i && set_newda_virtual_device_i;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID.next = 1'b1;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR.we = set_newda_i && set_newda_virtual_device_i;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR.next = newda_i;
    end else begin
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID.we = 1'b0;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID.next = '0;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR.we = 1'b0;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR.next = '0;
      // Virtual device address
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID.we = 1'b0;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID.next = '0;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR.we = 1'b0;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR.next = '0;
    end
  end

  I3CCSR i3c_csr (
      .clk(clk_i),
      .rst('0),  // Unused, CSRs are reset through hwif_in.rst_ni

      .s_cpuif_req(s_cpuif_req),
      .s_cpuif_req_is_wr(s_cpuif_req_is_wr),
      .s_cpuif_addr(s_cpuif_addr),
      .s_cpuif_wr_data(s_cpuif_wr_data),
      .s_cpuif_wr_biten(s_cpuif_wr_biten),  // Write strobes not handled by AHB-Lite interface
      .s_cpuif_req_stall_wr(s_cpuif_req_stall_wr),
      .s_cpuif_req_stall_rd(s_cpuif_req_stall_rd),
      .s_cpuif_rd_ack(s_cpuif_rd_ack),  // Ignored by AHB component
      .s_cpuif_rd_err(s_cpuif_rd_err),
      .s_cpuif_rd_data(s_cpuif_rd_data),
      .s_cpuif_wr_ack(s_cpuif_wr_ack),  // Ignored by AHB component
      .s_cpuif_wr_err(s_cpuif_wr_err),

      .hwif_in (hwif_in),
      .hwif_out(hwif_out_o)
  );

  always_comb begin : wire_unconnected_regs
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR_VALID.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.__rsvd_3.__rsvd.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_RSTACT_PARAMS.RST_ACTION.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.STBY_CR_OP_RSTACT_SIGNAL_EN.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR.next = '0;
    hwif_in.I3C_EC.CtrlCfg.CONTROLLER_CONFIG.OPERATION_MODE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.STBY_CR_OP_RSTACT_STAT.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.STBY_CR_OP_RSTACT_FORCE.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_ENTDAA_ENABLE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.HANDOFF_DEEP_SLEEP.hwclr = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.STATIC_ADDR_VALID.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.STATIC_ADDR.next = '0;

    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.STATIC_ADDR_VALID.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.STATIC_ADDR.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR_VALID.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.PENDING_RX_NACK.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.HANDOFF_DELAY_NACK.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.ACR_FSM_OP_SELECT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.PRIME_ACCEPT_GETACCCR.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.HANDOFF_DEEP_SLEEP.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.HANDOFF_DEEP_SLEEP.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.TARGET_XACT_ENABLE.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.TARGET_XACT_ENABLE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_SETAASA_ENABLE.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_SETAASA_ENABLE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_SETDASA_ENABLE.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_SETDASA_ENABLE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_ENTDAA_ENABLE.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_STATUS.AC_CURRENT_OWN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_STATUS.SIMPLE_CRR_STATUS.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_STATUS.HJ_REQ_STATUS.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.ACR_HANDOFF_OK_REMAIN_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.ACR_HANDOFF_OK_PRIMED_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.ACR_HANDOFF_ERR_FAIL_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.ACR_HANDOFF_ERR_M3_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.CRR_RESPONSE_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.STBY_CR_DYN_ADDR_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.STBY_CR_ACCEPT_NACKED_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.STBY_CR_ACCEPT_OK_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.STBY_CR_ACCEPT_ERR_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.STBY_CR_OP_RSTACT_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.CCC_PARAM_MODIFIED_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.CCC_UNHANDLED_NACK_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.CCC_FATAL_RSTDAA_ERR_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.ACR_HANDOFF_OK_REMAIN_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.ACR_HANDOFF_OK_PRIMED_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.ACR_HANDOFF_ERR_FAIL_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.ACR_HANDOFF_ERR_M3_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.CRR_RESPONSE_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.STBY_CR_DYN_ADDR_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.STBY_CR_ACCEPT_NACKED_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.STBY_CR_ACCEPT_OK_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.STBY_CR_ACCEPT_ERR_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.STBY_CR_OP_RSTACT_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.CCC_PARAM_MODIFIED_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.CCC_UNHANDLED_NACK_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.CCC_FATAL_RSTDAA_ERR_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.CRR_RESPONSE_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.STBY_CR_DYN_ADDR_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.STBY_CR_ACCEPT_NACKED_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.STBY_CR_ACCEPT_OK_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.STBY_CR_ACCEPT_ERR_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.STBY_CR_OP_RSTACT_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.CCC_PARAM_MODIFIED_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.CCC_UNHANDLED_NACK_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.CCC_FATAL_RSTDAA_ERR_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_GETCAPS.F2_CRCAP1_BUS_CONFIG.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_GETCAPS.F2_CRCAP2_DEV_INTERACT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_RSTACT_PARAMS.RESET_TIME_PERIPHERAL.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_RSTACT_PARAMS.RESET_TIME_TARGET.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_RSTACT_PARAMS.RESET_DYNAMIC_ADDR.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_RSTACT_PARAMS.RESET_DYNAMIC_ADDR.we = '0;

    hwif_in.I3C_EC.CtrlCfg.CONTROLLER_CONFIG.OPERATION_MODE.we = '0;
  end

endmodule : csri
