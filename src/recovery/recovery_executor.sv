// SPDX-License-Identifier: Apache-2.0

/*
    Recovery command execution module. Responds to commands decoded from I3C
    transactions by recovery_receiver and controls data frow to/from CSRs and
    TTI data queues.

    FIXME: Check if cmd_len_i is valid w.r.t. cmd_cmd_i
*/
module recovery_executor
  import i3c_pkg::*;
#(
    parameter int unsigned IndirectFifoDepth = 64,
    parameter int unsigned TtiRxDataDataWidth = 32,
    parameter int unsigned CsrDataWidth = 32
) (
    input logic clk_i,  // Clock
    input logic rst_ni, // Reset (active low)

    input logic recovery_enable_i,

    // Command interface
    input  logic        cmd_valid_i,
    input  logic        cmd_is_rd_i,
    input  logic [ 7:0] cmd_cmd_i,
    input  logic [15:0] cmd_len_i,
    input  logic        cmd_error_i,
    output logic        cmd_done_o,

    // Response interface
    output logic        res_valid_o,
    input  logic        res_ready_i,
    output logic [15:0] res_len_o,

    // Response data interface
    output logic       res_dvalid_o,
    input  logic       res_dready_i,
    output logic [7:0] res_data_o,
    output logic       res_dlast_o,

    // Input from TTI RX data FIFO
    output logic                          tti_rx_rreq_o,
    input  logic                          tti_rx_rack_i,
    input  logic [TtiRxDataDataWidth-1:0] tti_rx_rdata_i,

    // TTI RX queue control
    output logic tti_rx_sel_o,

    // Output to Indirect RX FIFO
    output logic                    indirect_rx_wvalid_o,
    input  logic                    indirect_rx_wready_i,
    output logic [CsrDataWidth-1:0] indirect_rx_wdata_o,

    // Input from Indirect RX FIFO (for CSR logic)
    output logic                    indirect_rx_rreq_o,
    input  logic                    indirect_rx_rack_i,
    input  logic [CsrDataWidth-1:0] indirect_rx_rdata_i,

    // Indirect FIFO control/status
    input  logic indirect_rx_full_i,
    input  logic indirect_rx_empty_i,
    output logic indirect_rx_clr_o,

    // Others
    input  logic host_abort_i,

    // queues clr signals
    output logic rx_data_queue_clr_o,
    output logic tx_data_queue_clr_o,
    output logic rx_desc_queue_clr_o,
    output logic tx_desc_queue_clr_o,

    // Recovery status signals
    input  logic bypass_i3c_core_i,
    output logic payload_available_o,
    output logic image_activated_o,

    // SoC Managment CSR interface
    input  I3CCSR_pkg::I3CCSR__I3C_EC__SoCMgmtIf__out_t hwif_socmgmt_i,
    output I3CCSR_pkg::I3CCSR__I3C_EC__SoCMgmtIf__in_t  hwif_socmgmt_o,

    // Recovery CSR interface
    input  I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__out_t hwif_rec_i,
    output I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__in_t  hwif_rec_o,

    // Recovery mode enabled via a CSR
    input recovery_mode_enabled_i
);

  // Commands
  typedef enum logic [7:0] {
    // always available commands
    CMD_PROT_CAP = 'd34,
    CMD_DEVICE_ID = 'd35,
    CMD_DEVICE_STATUS = 'd36,
    CMD_DEVICE_RESET = 'd37,
    CMD_RECOVERY_CTRL = 'd38,
    CMD_RECOVERY_STATUS = 'd39,
    // commands available only in recovery mode
    CMD_HW_STATUS = 'd40,
    CMD_INDIRECT_CTRL = 'd41,
    CMD_INDIRECT_STATUS = 'd42,
    CMD_INDIRECT_DATA = 'd43,
    CMD_VENDOR = 'd44,
    CMD_INDIRECT_FIFO_CTRL = 'd45,
    CMD_INDIRECT_FIFO_STATUS = 'd46,
    CMD_INDIRECT_FIFO_DATA = 'd47
  } command_e;

  // Protocol error codes
  typedef enum logic [7:0] {
    PROTOCOL_OK              = 'h0,
    PROTOCOL_ERROR_READ_ONLY = 'h1,
    PROTOCOL_ERROR_PARAMETER = 'h2,
    PROTOCOL_ERROR_LENGTH    = 'h3,
    PROTOCOL_ERROR_CRC       = 'h4
  } protocol_error_e;

  // Target CSR selector
  typedef enum logic [7:0] {
    CSR_PROT_CAP_0             = 'd0,
    CSR_PROT_CAP_1             = 'd1,
    CSR_PROT_CAP_2             = 'd2,
    CSR_PROT_CAP_3             = 'd3,
    CSR_DEVICE_ID_0            = 'd4,
    CSR_DEVICE_ID_1            = 'd5,
    CSR_DEVICE_ID_2            = 'd6,
    CSR_DEVICE_ID_3            = 'd7,
    CSR_DEVICE_ID_4            = 'd8,
    CSR_DEVICE_ID_5            = 'd9,
    CSR_DEVICE_STATUS_0        = 'd11,
    CSR_DEVICE_STATUS_1        = 'd12,
    CSR_DEVICE_RESET           = 'd13,
    CSR_RECOVERY_CTRL          = 'd14,
    CSR_RECOVERY_STATUS        = 'd15,
    CSR_HW_STATUS              = 'd16,
    CSR_INDIRECT_FIFO_CTRL_0   = 'd17,
    CSR_INDIRECT_FIFO_CTRL_1   = 'd18,
    CSR_INDIRECT_FIFO_STATUS_0 = 'd19,
    CSR_INDIRECT_FIFO_STATUS_1 = 'd20,
    CSR_INDIRECT_FIFO_STATUS_2 = 'd21,
    CSR_INDIRECT_FIFO_STATUS_3 = 'd22,
    CSR_INDIRECT_FIFO_STATUS_4 = 'd23,
    CSR_INDIRECT_FIFO_DATA     = 'd24,

    CSR_INVALID = 'hFF
  } csr_e;

  // Internal signals
  logic [15:0] dcnt;
  logic [15:0] dcnt_next;
  logic [ 1:0] bcnt;

  csr_e        csr_sel;
  logic [31:0] csr_data;
  logic [15:0] csr_length;
  logic        csr_writeable;

  logic payload_available_q;
  assign payload_available_o = payload_available_q;

  logic soft_reset;
  assign soft_reset = ~(recovery_enable_i | bypass_i3c_core_i);

  // Bypass of SW write to W1C registers
  logic sw_device_reset_ctrl_swmod;
  logic sw_recovery_ctrl_activate_rec_img_swmod;
  logic sw_indirect_fifo_ctrl_reset_swmod;
  logic [7:0] sw_device_reset_ctrl_value;
  logic [7:0] sw_recovery_ctrl_activate_rec_img_value;
  logic [7:0] sw_indirect_fifo_ctrl_reset_value;

  always_comb begin : blockName
    sw_device_reset_ctrl_value = hwif_socmgmt_i.REC_INTF_REG_W1C_ACCESS.DEVICE_RESET_CTRL.value;
    sw_recovery_ctrl_activate_rec_img_value = hwif_socmgmt_i.REC_INTF_REG_W1C_ACCESS.RECOVERY_CTRL_ACTIVATE_REC_IMG.value;
    sw_indirect_fifo_ctrl_reset_value = hwif_socmgmt_i.REC_INTF_REG_W1C_ACCESS.INDIRECT_FIFO_CTRL_RESET.value;
  end

  // swmod must be delayed by one cycle due to delayed propagation of value
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sw_device_reset_ctrl_swmod <= '0;
      sw_recovery_ctrl_activate_rec_img_swmod <= '0;
      sw_indirect_fifo_ctrl_reset_swmod <= '0;
    end else begin
      if (soft_reset) begin
          sw_device_reset_ctrl_swmod <= '0;
          sw_recovery_ctrl_activate_rec_img_swmod <= '0;
          sw_indirect_fifo_ctrl_reset_swmod <= '0;
      end else begin
          sw_device_reset_ctrl_swmod <= hwif_socmgmt_i.REC_INTF_REG_W1C_ACCESS.DEVICE_RESET_CTRL.swmod;
          sw_recovery_ctrl_activate_rec_img_swmod <= hwif_socmgmt_i.REC_INTF_REG_W1C_ACCESS.RECOVERY_CTRL_ACTIVATE_REC_IMG.swmod;
          sw_indirect_fifo_ctrl_reset_swmod <= hwif_socmgmt_i.REC_INTF_REG_W1C_ACCESS.INDIRECT_FIFO_CTRL_RESET.swmod;
      end
    end
  end

  always_comb begin : clear_bypassed_regs
    hwif_socmgmt_o.REC_INTF_REG_W1C_ACCESS.DEVICE_RESET_CTRL.we = sw_device_reset_ctrl_swmod;
    hwif_socmgmt_o.REC_INTF_REG_W1C_ACCESS.DEVICE_RESET_CTRL.next = '0;
    hwif_socmgmt_o.REC_INTF_REG_W1C_ACCESS.RECOVERY_CTRL_ACTIVATE_REC_IMG.we = sw_recovery_ctrl_activate_rec_img_swmod;
    hwif_socmgmt_o.REC_INTF_REG_W1C_ACCESS.RECOVERY_CTRL_ACTIVATE_REC_IMG.next = '0;
    hwif_socmgmt_o.REC_INTF_REG_W1C_ACCESS.INDIRECT_FIFO_CTRL_RESET.we = sw_indirect_fifo_ctrl_reset_swmod;
    hwif_socmgmt_o.REC_INTF_REG_W1C_ACCESS.INDIRECT_FIFO_CTRL_RESET.next = '0;
  end

  // ....................................................

  // FSM
  typedef enum logic [7:0] {
    Idle        = 'h00,
    CsrWrite    = 'h10,
    CsrRead     = 'h20,
    CsrReadLen  = 'h21,
    CsrReadData = 'h22,
    FifoWrite   = 'h30,
    Done        = 'hD0,
    Error       = 'hE0
  } state_e;

  state_e state_d, state_q;

  logic fifo_xfer_done;
  assign fifo_xfer_done = (indirect_rx_full_i | (image_activated_o && ~indirect_rx_empty_i));

  always_comb begin : set_payload_done_bypass
    hwif_socmgmt_o.REC_INTF_CFG.REC_PAYLOAD_DONE.we   = fifo_xfer_done;
    hwif_socmgmt_o.REC_INTF_CFG.REC_PAYLOAD_DONE.next = '0;
  end

  // State transition
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) state_q <= Idle;
    else begin
      if (soft_reset) state_q <= Idle;
      else state_q <= state_d;
    end

  // Next state
  always_comb begin
    state_d = state_q;
    unique case (state_q)
      Idle: begin
        if (cmd_valid_i) begin
          // check if we're accessed in regular mode and error if requested command is not accessible
          // also, check for illegal commands
          if (cmd_error_i || (~recovery_mode_enabled_i && (cmd_cmd_i > 8'h27)) || ((cmd_cmd_i > 8'h2f) || (cmd_cmd_i < 8'h22)))
            state_d = Error;
          else if (!cmd_is_rd_i) begin
            if (cmd_cmd_i == CMD_INDIRECT_FIFO_DATA) state_d = FifoWrite;
            else state_d = CsrWrite;
          end else state_d = CsrRead;
        end
      end

      CsrWrite: begin
        if (tti_rx_rack_i & (dcnt == 1)) state_d = Done;
      end
      FifoWrite: begin
        if ((tti_rx_rack_i & (dcnt == 1)) | (bypass_i3c_core_i & hwif_socmgmt_i.REC_INTF_CFG.REC_PAYLOAD_DONE.value & ~indirect_rx_empty_i))
          state_d = Done;
      end

      CsrRead: begin
        if (res_ready_i) state_d = CsrReadLen;
      end

      CsrReadLen: state_d = CsrReadData;

      CsrReadData: begin
        if (host_abort_i) state_d = Error;  // FIXME: Should we make this an error ?
        else if (res_dvalid_o & res_dready_i & (dcnt == 1)) state_d = Done;
      end

      Error: state_d = Done;
      Done:  state_d = Idle;

      default: state_d = Idle;
    endcase
  end

  // ....................................................

  // Data counter
  assign dcnt_next = (|cmd_len_i[1:0]) ? 16'(cmd_len_i / 4 + 1) : 16'(cmd_len_i / 4);  // Divide by 4, round up

  always_ff @(posedge clk_i)
    unique case (state_q)
      Idle: if (cmd_valid_i) dcnt <= dcnt_next;
      CsrWrite, FifoWrite: if (tti_rx_rack_i) dcnt <= dcnt - 1;
      CsrReadLen: dcnt <= csr_length;
      CsrReadData: if (res_dvalid_o & res_dready_i) dcnt <= dcnt - 1;
      default: dcnt <= dcnt;
    endcase

  // Byte counter
  always_ff @(posedge clk_i)
    unique case (state_q)
      Idle: bcnt <= '0;
      CsrReadData: if (res_dvalid_o & res_dready_i) bcnt <= bcnt + 1;
      default: bcnt <= bcnt;
    endcase

  // Target / source CSR
  always_ff @(posedge clk_i)
    unique case (state_q)
      Idle:
      if (cmd_valid_i)
        unique case (cmd_cmd_i)
          CMD_PROT_CAP:             csr_sel <= CSR_PROT_CAP_0;
          CMD_DEVICE_ID:            csr_sel <= CSR_DEVICE_ID_0;
          CMD_DEVICE_STATUS:        csr_sel <= CSR_DEVICE_STATUS_0;
          CMD_DEVICE_RESET:         csr_sel <= CSR_DEVICE_RESET;
          CMD_RECOVERY_CTRL:        csr_sel <= CSR_RECOVERY_CTRL;
          CMD_RECOVERY_STATUS:      csr_sel <= CSR_RECOVERY_STATUS;
          CMD_HW_STATUS:            csr_sel <= CSR_HW_STATUS;
          CMD_INDIRECT_FIFO_CTRL:   csr_sel <= CSR_INDIRECT_FIFO_CTRL_0;
          CMD_INDIRECT_FIFO_STATUS: csr_sel <= CSR_INDIRECT_FIFO_STATUS_0;
          CMD_INDIRECT_FIFO_DATA:   csr_sel <= CSR_INDIRECT_FIFO_DATA;

          default: csr_sel <= CSR_INVALID;
        endcase

      // FIXME: This will overflow resulting on overwriting unwanted CSRs if
      // a malicious packet with length > CSR length is received
      CsrWrite: if (tti_rx_rack_i) csr_sel <= csr_e'(csr_sel + 8'd1);
      CsrReadData: if (res_dvalid_o & res_dready_i & (bcnt == 3)) csr_sel <= csr_e'(csr_sel + 8'd1);
      default: csr_sel <= csr_sel;
    endcase

  // CSR writeable flag
  always_comb
    unique case (csr_sel)
      CSR_DEVICE_RESET:         csr_writeable = 1'b1;
      CSR_RECOVERY_CTRL:        csr_writeable = 1'b1;
      CSR_INDIRECT_FIFO_CTRL_0: csr_writeable = 1'b1;
      CSR_INDIRECT_FIFO_CTRL_1: csr_writeable = 1'b1;
      default:                  csr_writeable = '0;
    endcase

  // CSR length (in bytes)
  always_ff @(posedge clk_i)
    unique case (state_q)
      Idle:
      if (cmd_valid_i)
        unique case (cmd_cmd_i)
          CMD_PROT_CAP:             csr_length <= 'd15;
          CMD_DEVICE_ID:            csr_length <= 'd24;
          CMD_DEVICE_STATUS:        csr_length <= 'd7;
          CMD_DEVICE_RESET:         csr_length <= 'd3;
          CMD_RECOVERY_CTRL:        csr_length <= 'd3;
          CMD_RECOVERY_STATUS:      csr_length <= 'd2;
          CMD_HW_STATUS:            csr_length <= 'd4;
          CMD_INDIRECT_FIFO_CTRL:   csr_length <= 'd6;
          CMD_INDIRECT_FIFO_STATUS: csr_length <= 'd20;

          default: csr_length <= 'd4;  // This should never happen.
        endcase
      default: csr_length <= csr_length;
    endcase

  // CSR read data mux (registered)
  logic [31:0] indirect_fifo_status_0;
  logic [31:0] indirect_fifo_ctrl_0, indirect_fifo_ctrl_1;
  logic [31:0] prot_cap_2, prot_cap_3;
  logic [31:0] device_id_0;
  logic [31:0] device_status_0, device_status_1;
  logic [31:0] device_reset;
  logic [31:0] recovery_ctrl, recovery_status;
  logic [31:0] hw_status;

  always_ff @(posedge clk_i)
    unique case (csr_sel)
      CSR_PROT_CAP_0:      csr_data <= hwif_rec_i.PROT_CAP_0.REC_MAGIC_STRING_0.value;
      CSR_PROT_CAP_1:      csr_data <= hwif_rec_i.PROT_CAP_1.REC_MAGIC_STRING_1.value;
      CSR_PROT_CAP_2:      csr_data <= prot_cap_2;
      CSR_PROT_CAP_3:      csr_data <= prot_cap_3;
      CSR_DEVICE_ID_0:     csr_data <= device_id_0;
      CSR_DEVICE_ID_1:     csr_data <= hwif_rec_i.DEVICE_ID_1.DATA.value;
      CSR_DEVICE_ID_2:     csr_data <= hwif_rec_i.DEVICE_ID_2.DATA.value;
      CSR_DEVICE_ID_3:     csr_data <= hwif_rec_i.DEVICE_ID_3.DATA.value;
      CSR_DEVICE_ID_4:     csr_data <= hwif_rec_i.DEVICE_ID_4.DATA.value;
      CSR_DEVICE_ID_5:     csr_data <= hwif_rec_i.DEVICE_ID_5.DATA.value;
      CSR_DEVICE_STATUS_0: csr_data <= device_status_0;
      CSR_DEVICE_STATUS_1: csr_data <= device_status_1;
      CSR_DEVICE_RESET:    csr_data <= device_reset;
      CSR_RECOVERY_CTRL:   csr_data <= recovery_ctrl;
      CSR_RECOVERY_STATUS: csr_data <= recovery_status;
      CSR_HW_STATUS:       csr_data <= hw_status;

      CSR_INDIRECT_FIFO_CTRL_0: csr_data <= indirect_fifo_ctrl_0;
      CSR_INDIRECT_FIFO_CTRL_1: csr_data <= indirect_fifo_ctrl_1;
      CSR_INDIRECT_FIFO_STATUS_0: csr_data <= indirect_fifo_status_0;
      CSR_INDIRECT_FIFO_STATUS_1: csr_data <= hwif_rec_i.INDIRECT_FIFO_STATUS_1.WRITE_INDEX.value;
      CSR_INDIRECT_FIFO_STATUS_2: csr_data <= hwif_rec_i.INDIRECT_FIFO_STATUS_2.READ_INDEX.value;
      CSR_INDIRECT_FIFO_STATUS_3: csr_data <= hwif_rec_i.INDIRECT_FIFO_STATUS_3.FIFO_SIZE.value;
      CSR_INDIRECT_FIFO_STATUS_4:
      csr_data <= hwif_rec_i.INDIRECT_FIFO_STATUS_4.MAX_TRANSFER_SIZE.value;

      default: csr_data <= '0;
    endcase

  assign prot_cap_2 = {
    hwif_rec_i.PROT_CAP_2.AGENT_CAPS.value, hwif_rec_i.PROT_CAP_2.REC_PROT_VERSION.value
  };

  assign prot_cap_3 = {
    8'h0,
    hwif_rec_i.PROT_CAP_3.HEARTBEAT_PERIOD.value,
    hwif_rec_i.PROT_CAP_3.MAX_RESP_TIME.value,
    hwif_rec_i.PROT_CAP_3.NUM_OF_CMS_REGIONS.value
  };

  assign device_id_0 = {
    hwif_rec_i.DEVICE_ID_0.DATA.value,
    hwif_rec_i.DEVICE_ID_0.VENDOR_SPECIFIC_STR_LENGTH.value,
    hwif_rec_i.DEVICE_ID_0.DESC_TYPE.value
  };

  assign device_status_0 = {
    hwif_rec_i.DEVICE_STATUS_0.REC_REASON_CODE.value,
    hwif_rec_i.DEVICE_STATUS_0.PROT_ERROR.value,
    hwif_rec_i.DEVICE_STATUS_0.DEV_STATUS.value
  };

  assign device_status_1 = {
    hwif_rec_i.DEVICE_STATUS_1.VENDOR_STATUS.value,
    hwif_rec_i.DEVICE_STATUS_1.VENDOR_STATUS_LENGTH.value,
    hwif_rec_i.DEVICE_STATUS_1.HEARTBEAT.value
  };

  assign device_reset = {
    8'h0,
    hwif_rec_i.DEVICE_RESET.IF_CTRL.value,
    hwif_rec_i.DEVICE_RESET.FORCED_RECOVERY.value,
    hwif_rec_i.DEVICE_RESET.RESET_CTRL.value
  };

  assign recovery_ctrl = {
    8'h0,
    hwif_rec_i.RECOVERY_CTRL.ACTIVATE_REC_IMG.value,
    hwif_rec_i.RECOVERY_CTRL.REC_IMG_SEL.value,
    hwif_rec_i.RECOVERY_CTRL.CMS.value
  };

  assign recovery_status = {
    16'h0,
    hwif_rec_i.RECOVERY_STATUS.VENDOR_SPECIFIC_STATUS.value,
    hwif_rec_i.RECOVERY_STATUS.REC_IMG_INDEX.value,
    hwif_rec_i.RECOVERY_STATUS.DEV_REC_STATUS.value
  };

  assign hw_status = {
    hwif_rec_i.HW_STATUS.VENDOR_HW_STATUS_LEN.value,
    hwif_rec_i.HW_STATUS.CTEMP.value,
    hwif_rec_i.HW_STATUS.VENDOR_HW_STATUS.value,
    hwif_rec_i.HW_STATUS.RESERVED_7_3.value,
    hwif_rec_i.HW_STATUS.FATAL_ERR.value,
    hwif_rec_i.HW_STATUS.SOFT_ERR.value,
    hwif_rec_i.HW_STATUS.TEMP_CRITICAL.value
  };

  assign indirect_fifo_ctrl_0 = {
    hwif_rec_i.INDIRECT_FIFO_CTRL_1.IMAGE_SIZE.value[15:0],
    hwif_rec_i.INDIRECT_FIFO_CTRL_0.RESET.value,
    hwif_rec_i.INDIRECT_FIFO_CTRL_0.CMS.value
  };

  assign indirect_fifo_ctrl_1 = {
    16'h0,
    hwif_rec_i.INDIRECT_FIFO_CTRL_1.IMAGE_SIZE.value[31:16]
  };

  // INDIRECT_FIFO_STATUS_0 as a 32-bit word
  assign indirect_fifo_status_0 = {
    // b3,b2
    16'd0,
    // b1
    5'd0,
    hwif_rec_i.INDIRECT_FIFO_STATUS_0.REGION_TYPE.value,
    // b0
    6'd0,
    hwif_rec_i.INDIRECT_FIFO_STATUS_0.FULL.value,
    hwif_rec_i.INDIRECT_FIFO_STATUS_0.EMPTY.value
  };

  // ....................................................

  logic [7:0] status_device;
  logic [7:0] status_protocol;
  logic [15:0] status_reason;

  logic status_device_we;
  logic status_protocol_we;
  logic status_reason_we;

  // Device status CSR update
  always_comb begin
    hwif_rec_o.DEVICE_STATUS_0.REC_REASON_CODE.we = status_reason_we;
    hwif_rec_o.DEVICE_STATUS_0.PROT_ERROR.we = status_protocol_we;
    hwif_rec_o.DEVICE_STATUS_0.DEV_STATUS.we = status_device_we;
  end

  always_comb begin
    hwif_rec_o.DEVICE_STATUS_0.REC_REASON_CODE.next = status_reason;
    hwif_rec_o.DEVICE_STATUS_0.PROT_ERROR.next = status_protocol;
    hwif_rec_o.DEVICE_STATUS_0.DEV_STATUS.next = status_device;
  end

  // Protocol status
  always_ff @(posedge clk_i)
    unique case (state_q)
      Idle:
      if (cmd_valid_i & cmd_error_i) status_protocol <= PROTOCOL_ERROR_CRC;
      else status_protocol <= PROTOCOL_OK;
      default: status_protocol <= status_protocol;
    endcase

  // TODO: Implement reporting other statuses
  assign status_device_we = '0;
  assign status_reason_we = '0;
  assign status_device = '0;
  assign status_reason = '0;

  // Update status on command done
  assign status_protocol_we = (state_q == Done);

  // ....................................................

  // FIFO full/empty status
  logic fifo_full_r;
  logic fifo_empty_r;

  always_ff @(posedge clk_i or negedge rst_ni)
    if (~rst_ni) begin
      fifo_full_r  <= '0;
      fifo_empty_r <= '1;
    end else begin
      if (soft_reset) begin
        fifo_full_r  <= '0;
        fifo_empty_r <= '1;
      end else begin
        fifo_full_r  <= indirect_rx_full_i;
        fifo_empty_r <= indirect_rx_empty_i;
      end
    end

  always_comb begin
    hwif_rec_o.INDIRECT_FIFO_STATUS_0.EMPTY.we   = indirect_rx_empty_i ^ fifo_empty_r;
    hwif_rec_o.INDIRECT_FIFO_STATUS_0.EMPTY.next = indirect_rx_empty_i;

    hwif_rec_o.INDIRECT_FIFO_STATUS_0.FULL.we    = indirect_rx_full_i  ^ fifo_full_r;
    hwif_rec_o.INDIRECT_FIFO_STATUS_0.FULL.next  = indirect_rx_full_i;
  end

  // ....................................................

  // Top value of a FIFO pointer.
  // Make it a ff to cut a long combinational path.
  logic [31:0] fifo_size;
  logic [31:0] fifo_ptr_top;

  assign fifo_size = hwif_rec_i.INDIRECT_FIFO_STATUS_3.FIFO_SIZE.value;

  always_ff @(posedge clk_i) begin
    fifo_ptr_top <= fifo_size - 32'h1;
  end

  // ........................

  logic [31:0] fifo_wrptr;
  logic [31:0] fifo_rdptr;

  assign fifo_wrptr = hwif_rec_i.INDIRECT_FIFO_STATUS_1.WRITE_INDEX.value;
  assign fifo_rdptr = hwif_rec_i.INDIRECT_FIFO_STATUS_2.READ_INDEX.value;

  logic fifo_wrptr_inc;
  logic fifo_rdptr_inc;
  logic fifo_ptr_clr;

  // FIFO write pointer
  assign hwif_rec_o.INDIRECT_FIFO_STATUS_1.WRITE_INDEX.we = (fifo_wrptr_inc | fifo_ptr_clr);

  always_comb begin
    // Reset
    if (fifo_ptr_clr) begin
      hwif_rec_o.INDIRECT_FIFO_STATUS_1.WRITE_INDEX.next = '0;
      // Increment with wrap around
    end else begin
      hwif_rec_o.INDIRECT_FIFO_STATUS_1.WRITE_INDEX.next =
            (fifo_wrptr == fifo_ptr_top) ? '0 : (fifo_wrptr + 32'd1);
    end
  end

  // FIFO read pointer
  assign hwif_rec_o.INDIRECT_FIFO_STATUS_2.READ_INDEX.we = (fifo_rdptr_inc | fifo_ptr_clr);

  always_comb begin
    // Reset
    if (fifo_ptr_clr) begin
      hwif_rec_o.INDIRECT_FIFO_STATUS_2.READ_INDEX.next = '0;
      // Increment with wrap around
    end else begin
      hwif_rec_o.INDIRECT_FIFO_STATUS_2.READ_INDEX.next =
            (fifo_rdptr == fifo_ptr_top) ? '0 : (fifo_rdptr + 32'd1);
    end
  end

  // ..............

  // Increment FIFO write index on each word copied from TTI RX queue
  assign fifo_wrptr_inc = (state_q == FifoWrite) & tti_rx_rack_i;
  // Increment FIFO read index on INDIRECT_FIFO_DATA read from the CSR side
  assign fifo_rdptr_inc = indirect_rx_rack_i;

  // Clear FIFO indices on write of 0x1 to INDIRECT_FIFO_CTRL byte 1
  assign fifo_ptr_clr = hwif_rec_i.INDIRECT_FIFO_CTRL_0.RESET.value == 8'd1;

  // Clear the indirect FIFO itself along with the pointers
  assign indirect_rx_clr_o = fifo_ptr_clr;

  // ....................................................

  assign tti_rx_sel_o = 1'b1;
  assign rx_data_queue_clr_o = (state_q == Error);
  assign rx_desc_queue_clr_o = (state_q == Error);
  assign tx_data_queue_clr_o = '0;
  assign tx_desc_queue_clr_o = '0;

  // RX TTI FIFO data request
  always_ff @(posedge clk_i)
    unique case (state_q)
      Idle: tti_rx_rreq_o <= cmd_valid_i & !cmd_error_i & (cmd_len_i != 0);
      CsrWrite, FifoWrite: tti_rx_rreq_o <= tti_rx_rack_i & (dcnt != 1);
      default: tti_rx_rreq_o <= '0;
    endcase

  // RX Indirect FIFO data feed
  always_comb begin
    indirect_rx_wvalid_o = (state_q == FifoWrite) & tti_rx_rack_i;
    indirect_rx_wdata_o  = tti_rx_rdata_i;
  end

  logic [TtiRxDataDataWidth-1:0] prev_tti_rx_rdata;
  always_ff @(posedge clk_i or negedge rst_ni) begin : collect_prev_tti_rx_data
    if (~rst_ni) begin
      prev_tti_rx_rdata <= '0;
    end else begin
      if (soft_reset) begin
        prev_tti_rx_rdata <= '0;
      end else
        if (tti_rx_rack_i) begin
          prev_tti_rx_rdata <= tti_rx_rdata_i;
        end else begin
          prev_tti_rx_rdata <= prev_tti_rx_rdata;
        end
      end
    end

  // CSR write. Only applicable for writable CSRs as per the OCP
  // recovery spec.
  logic device_reset_we;
  logic indirect_fifo_ctrl_0_we;
  logic recovery_ctrl_we;
  logic indirect_fifo_ctrl_0_reset_we;

  assign device_reset_we = tti_rx_rack_i & (csr_sel == CSR_DEVICE_RESET);
  assign indirect_fifo_ctrl_0_we = tti_rx_rack_i & (csr_sel == CSR_INDIRECT_FIFO_CTRL_0);
  assign recovery_ctrl_we = tti_rx_rack_i & (csr_sel == CSR_RECOVERY_CTRL);

  always_comb begin
    hwif_rec_o.PROT_CAP_2.REC_PROT_VERSION.we = '0;
    hwif_rec_o.PROT_CAP_2.AGENT_CAPS.we = '0;
    hwif_rec_o.PROT_CAP_3.NUM_OF_CMS_REGIONS.we = '0;
    hwif_rec_o.PROT_CAP_3.MAX_RESP_TIME.we = '0;
    hwif_rec_o.PROT_CAP_3.HEARTBEAT_PERIOD.we = '0;
    hwif_rec_o.DEVICE_ID_0.DESC_TYPE.we = '0;
    hwif_rec_o.DEVICE_ID_0.VENDOR_SPECIFIC_STR_LENGTH.we = '0;
    hwif_rec_o.DEVICE_ID_0.DATA.we = '0;
    hwif_rec_o.DEVICE_ID_1.DATA.we = '0;
    hwif_rec_o.DEVICE_ID_2.DATA.we = '0;
    hwif_rec_o.DEVICE_ID_3.DATA.we = '0;
    hwif_rec_o.DEVICE_ID_4.DATA.we = '0;
    hwif_rec_o.DEVICE_ID_5.DATA.we = '0;
    hwif_rec_o.DEVICE_STATUS_1.HEARTBEAT.we = '0;
    hwif_rec_o.DEVICE_STATUS_1.VENDOR_STATUS_LENGTH.we = '0;
    hwif_rec_o.DEVICE_STATUS_1.VENDOR_STATUS.we = '0;
    hwif_rec_o.DEVICE_RESET.RESET_CTRL.we = bypass_i3c_core_i ? sw_device_reset_ctrl_swmod : device_reset_we;
    hwif_rec_o.DEVICE_RESET.FORCED_RECOVERY.we = device_reset_we;
    hwif_rec_o.DEVICE_RESET.IF_CTRL.we = device_reset_we;
    hwif_rec_o.RECOVERY_CTRL.ACTIVATE_REC_IMG.we = bypass_i3c_core_i ? sw_recovery_ctrl_activate_rec_img_swmod : recovery_ctrl_we;
    hwif_rec_o.RECOVERY_CTRL.REC_IMG_SEL.we = recovery_ctrl_we;
    hwif_rec_o.RECOVERY_CTRL.CMS.we = recovery_ctrl_we;
    hwif_rec_o.RECOVERY_STATUS.DEV_REC_STATUS.we = '0;
    hwif_rec_o.RECOVERY_STATUS.REC_IMG_INDEX.we = '0;
    hwif_rec_o.RECOVERY_STATUS.VENDOR_SPECIFIC_STATUS.we = '0;
    hwif_rec_o.HW_STATUS.TEMP_CRITICAL.we = '0;
    hwif_rec_o.HW_STATUS.SOFT_ERR.we = '0;
    hwif_rec_o.HW_STATUS.FATAL_ERR.we = '0;
    hwif_rec_o.HW_STATUS.RESERVED_7_3.we = '0;
    hwif_rec_o.HW_STATUS.VENDOR_HW_STATUS.we = '0;
    hwif_rec_o.HW_STATUS.CTEMP.we = '0;
    hwif_rec_o.HW_STATUS.VENDOR_HW_STATUS_LEN.we = '0;
    hwif_rec_o.INDIRECT_FIFO_CTRL_0.RESET.we = bypass_i3c_core_i ? sw_indirect_fifo_ctrl_reset_swmod : indirect_fifo_ctrl_0_we;
    hwif_rec_o.INDIRECT_FIFO_CTRL_0.CMS.we = indirect_fifo_ctrl_0_we;
    hwif_rec_o.INDIRECT_FIFO_CTRL_1.IMAGE_SIZE.we = tti_rx_rack_i & (csr_sel == CSR_INDIRECT_FIFO_CTRL_1);
    hwif_rec_o.INDIRECT_FIFO_STATUS_0.REGION_TYPE.we = '0;
    hwif_rec_o.INDIRECT_FIFO_RESERVED.DATA.we = '0;
  end

  always_comb begin
    hwif_rec_o.DEVICE_RESET.RESET_CTRL.next = bypass_i3c_core_i ? sw_device_reset_ctrl_value : tti_rx_rdata_i[7:0];
    hwif_rec_o.DEVICE_RESET.FORCED_RECOVERY.next = tti_rx_rdata_i[15:8];
    hwif_rec_o.DEVICE_RESET.IF_CTRL.next = tti_rx_rdata_i[23:16];
    hwif_rec_o.RECOVERY_CTRL.ACTIVATE_REC_IMG.next = bypass_i3c_core_i ? sw_recovery_ctrl_activate_rec_img_value : tti_rx_rdata_i[23:16];
    hwif_rec_o.RECOVERY_CTRL.REC_IMG_SEL.next = tti_rx_rdata_i[15:8];
    hwif_rec_o.RECOVERY_CTRL.CMS.next = tti_rx_rdata_i[7:0];
    hwif_rec_o.INDIRECT_FIFO_CTRL_0.RESET.next = bypass_i3c_core_i ? sw_indirect_fifo_ctrl_reset_value : tti_rx_rdata_i[15:8];
    hwif_rec_o.INDIRECT_FIFO_CTRL_0.CMS.next = tti_rx_rdata_i[7:0];
    hwif_rec_o.INDIRECT_FIFO_CTRL_1.IMAGE_SIZE.next = {
      tti_rx_rdata_i[15:0], prev_tti_rx_rdata[31:16]
    };
  end

  logic fifo_reg_reset_clear;

  assign hwif_rec_o.INDIRECT_FIFO_CTRL_0.RESET.hwclr = fifo_reg_reset_clear;

  always_ff @(posedge clk_i or negedge rst_ni) begin : fifo_reg_reset_on_write
    if (~rst_ni) begin
      fifo_reg_reset_clear <= '0;
    end else if (soft_reset) begin
      fifo_reg_reset_clear <= '0;
    end else begin
      if (|hwif_rec_i.INDIRECT_FIFO_CTRL_0.RESET.value) begin
        fifo_reg_reset_clear <= 1'b1;
      end else begin
        fifo_reg_reset_clear <= '0;
      end
    end
  end

  // Force the value of FIFO_STATUS.FIFO_SIZE to IndirectFifoDepth.
  always_comb begin
    hwif_rec_o.INDIRECT_FIFO_STATUS_3.FIFO_SIZE.next = IndirectFifoDepth;
    hwif_rec_o.INDIRECT_FIFO_STATUS_3.FIFO_SIZE.we   = '1;
  end

  // ....................................................

  // Connect CSR logic to indirect FIFO rx data port
  always_comb begin
    if (~fifo_empty_r) begin
      indirect_rx_rreq_o = hwif_rec_i.INDIRECT_FIFO_DATA.req & !hwif_rec_i.INDIRECT_FIFO_DATA.req_is_wr;
      hwif_rec_o.INDIRECT_FIFO_DATA.rd_data = indirect_rx_rdata_i;
      hwif_rec_o.INDIRECT_FIFO_DATA.rd_ack = indirect_rx_rack_i;
    end else begin
      indirect_rx_rreq_o = '0;
      hwif_rec_o.INDIRECT_FIFO_DATA.rd_data = '0;
      hwif_rec_o.INDIRECT_FIFO_DATA.rd_ack = hwif_rec_i.INDIRECT_FIFO_DATA.req & !hwif_rec_i.INDIRECT_FIFO_DATA.req_is_wr;
    end
  end

  // tie unused signals
  always_comb begin
    hwif_rec_o.PROT_CAP_3.NUM_OF_CMS_REGIONS.next = '0;
    hwif_rec_o.PROT_CAP_3.MAX_RESP_TIME.next = '0;
    hwif_rec_o.PROT_CAP_3.HEARTBEAT_PERIOD.next = '0;
    hwif_rec_o.PROT_CAP_2.REC_PROT_VERSION.next = '0;
    hwif_rec_o.PROT_CAP_2.AGENT_CAPS.next = '0;
    hwif_rec_o.HW_STATUS.TEMP_CRITICAL.next = '0;
    hwif_rec_o.HW_STATUS.SOFT_ERR.next = '0;
    hwif_rec_o.HW_STATUS.FATAL_ERR.next = '0;
    hwif_rec_o.HW_STATUS.RESERVED_7_3.next = '0;
    hwif_rec_o.HW_STATUS.VENDOR_HW_STATUS.next = '0;
    hwif_rec_o.HW_STATUS.CTEMP.next = '0;
    hwif_rec_o.HW_STATUS.VENDOR_HW_STATUS_LEN.next = '0;
    hwif_rec_o.DEVICE_STATUS_1.HEARTBEAT.next = '0;
    hwif_rec_o.DEVICE_STATUS_1.VENDOR_STATUS_LENGTH.next = '0;
    hwif_rec_o.DEVICE_STATUS_1.VENDOR_STATUS.next = '0;
    hwif_rec_o.RECOVERY_STATUS.DEV_REC_STATUS.next = '0;
    hwif_rec_o.RECOVERY_STATUS.REC_IMG_INDEX.next = '0;
    hwif_rec_o.RECOVERY_STATUS.VENDOR_SPECIFIC_STATUS.next = '0;
    hwif_rec_o.INDIRECT_FIFO_STATUS_0.REGION_TYPE.next = '0;
    hwif_rec_o.INDIRECT_FIFO_RESERVED.DATA.next = '0;
    hwif_rec_o.DEVICE_ID_1.DATA.next = '0;
    hwif_rec_o.DEVICE_ID_2.DATA.next = '0;
    hwif_rec_o.DEVICE_ID_3.DATA.next = '0;
    hwif_rec_o.DEVICE_ID_4.DATA.next = '0;
    hwif_rec_o.DEVICE_ID_5.DATA.next = '0;
    hwif_rec_o.DEVICE_ID_0.DESC_TYPE.next = '0;
    hwif_rec_o.DEVICE_ID_0.VENDOR_SPECIFIC_STR_LENGTH.next = '0;
    hwif_rec_o.DEVICE_ID_0.DATA.next = '0;
  end
  // ....................................................

  // Command response
  assign cmd_done_o = (state_q == Done);

  // ....................................................

  // Transmitt valid
  always_ff @(posedge clk_i)
    unique case (state_q)
      CsrReadLen: if (res_ready_i) res_valid_o <= 1'd1;
      default: res_valid_o <= '0;
    endcase

  // Transmitt length
  assign res_len_o = csr_length;

  // Transmitt data valid
  assign res_dvalid_o = (state_q == CsrReadData);

  // Transmitt data
  always_comb
    unique case (bcnt)
      'd0: res_data_o = csr_data[7:0];
      'd1: res_data_o = csr_data[15:8];
      'd2: res_data_o = csr_data[23:16];
      'd3: res_data_o = csr_data[31:24];
      default: res_data_o = '0;
    endcase

  // Transmitt data last
  always_ff @(posedge clk_i)
    unique case (state_q)
      CsrReadData: res_dlast_o <= (dcnt == 1);
      default:     res_dlast_o <= '0;
    endcase

  // ....................................................

  // Payload availability logic
  // Assertion:
  // The payload_available signal must assert if recovery FIFO indicates full (256B) or image
  // activation status is asserted (essentially indicating the last transfer is complete).
  //
  // De-assertion:
  // The payload_available signal must reset if recovery FIFO indicates empty.
  logic payload_high_en, bypass_xfer_done;
  assign payload_high_en = bypass_i3c_core_i ?
                            (bypass_xfer_done | hwif_socmgmt_i.REC_INTF_CFG.REC_PAYLOAD_DONE.value | image_activated_o) :
                            fifo_xfer_done;
  assign bypass_xfer_done = (state_q == FifoWrite) & (state_d == Done);

  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) payload_available_q <= 1'b0;
    else if (soft_reset) begin
      payload_available_q <= 1'b0;
    end else begin
      if (payload_high_en) payload_available_q <= 1'b1;
      else if (indirect_rx_empty_i) payload_available_q <= 1'b0;
      else payload_available_q <= payload_available_q;
    end

  // Image activation logic.
  assign image_activated_o = (hwif_rec_i.RECOVERY_CTRL.ACTIVATE_REC_IMG.value == 8'h0F);

endmodule
