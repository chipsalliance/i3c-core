// SPDX-License-Identifier: Apache-2.0

/*
    Recovery command execution module. Responds to commands decoded from I3C
    transactions by recovery_receiver and controls data frow to/from CSRs and
    TTI data queues.

    FIXME: Check if cmd_len_i is valid w.r.t. cmd_cmd_i
*/
module recovery_executor
  import i3c_pkg::*;
# (
    parameter int unsigned IndirectFifoDepth = 64,
    parameter int unsigned TtiRxDataDataWidth = 32,
    parameter int unsigned CsrDataWidth = 32
)
(
    input logic clk_i,  // Clock
    input logic rst_ni, // Reset (active low)

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
    output logic pending_o,
    input logic host_abort_i,

    // queues clr signals
    output logic rx_data_queue_clr_o,
    output logic tx_data_queue_clr_o,
    output logic rx_desc_queue_clr_o,
    output logic tx_desc_queue_clr_o,

    // Recovery status signals
    output logic payload_available_o,
    output logic image_activated_o,

    // Recovery CSR interface
    input  I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__out_t hwif_rec_i,
    output I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__in_t  hwif_rec_o,

    // Recovery mode enabled via a CSR
    input  recovery_mode_enabled_i
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
    CSR_DEVICE_ID_6            = 'd10,
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

  logic payload_available_d, payload_available_q;
  logic payload_available_write;
  assign payload_available_o = payload_available_q;

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

  // State transition
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) state_q <= Idle;
    else state_q <= state_d;

  // Next state
  always_comb begin
    state_d = state_q;
    unique case (state_q)
      Idle: begin
        if (cmd_valid_i) begin
          // check if we're accessed in regular mode and error if requested command is not accessible
          // also, check for illegal commands
          if (cmd_error_i || (~recovery_mode_enabled_i && (cmd_cmd_i > 8'h27)) || ((cmd_cmd_i > 8'h2f) || (cmd_cmd_i < 8'h22))) state_d = Error;
          else if (!cmd_is_rd_i) begin
            if (cmd_cmd_i == CMD_INDIRECT_FIFO_DATA)
              state_d = FifoWrite;
            else
              state_d = CsrWrite;
          end else state_d = CsrRead;
        end
      end

      CsrWrite, FifoWrite: begin
        if (tti_rx_rack_i & (dcnt == 1)) state_d = Done;
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
  assign dcnt_next = (|cmd_len_i[1:0]) ? (cmd_len_i / 4 + 1) : (cmd_len_i / 4);  // Divide by 4, round up

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
          CMD_DEVICE_STATUS:        csr_length <= 'd8;
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

  always_ff @(posedge clk_i)
    unique case (csr_sel)
      CSR_PROT_CAP_0:      csr_data <= hwif_rec_i.PROT_CAP_0.PLACEHOLDER.value;
      CSR_PROT_CAP_1:      csr_data <= hwif_rec_i.PROT_CAP_1.PLACEHOLDER.value;
      CSR_PROT_CAP_2:      csr_data <= hwif_rec_i.PROT_CAP_2.PLACEHOLDER.value;
      CSR_PROT_CAP_3:      csr_data <= hwif_rec_i.PROT_CAP_3.PLACEHOLDER.value;
      CSR_DEVICE_ID_0:     csr_data <= hwif_rec_i.DEVICE_ID_0.PLACEHOLDER.value;
      CSR_DEVICE_ID_1:     csr_data <= hwif_rec_i.DEVICE_ID_1.PLACEHOLDER.value;
      CSR_DEVICE_ID_2:     csr_data <= hwif_rec_i.DEVICE_ID_2.PLACEHOLDER.value;
      CSR_DEVICE_ID_3:     csr_data <= hwif_rec_i.DEVICE_ID_3.PLACEHOLDER.value;
      CSR_DEVICE_ID_4:     csr_data <= hwif_rec_i.DEVICE_ID_4.PLACEHOLDER.value;
      CSR_DEVICE_ID_5:     csr_data <= hwif_rec_i.DEVICE_ID_5.PLACEHOLDER.value;
      CSR_DEVICE_ID_6:     csr_data <= hwif_rec_i.DEVICE_ID_6.PLACEHOLDER.value;
      CSR_DEVICE_STATUS_0: csr_data <= hwif_rec_i.DEVICE_STATUS_0.PLACEHOLDER.value;
      CSR_DEVICE_STATUS_1: csr_data <= hwif_rec_i.DEVICE_STATUS_1.PLACEHOLDER.value;
      CSR_DEVICE_RESET:    csr_data <= hwif_rec_i.DEVICE_RESET.PLACEHOLDER.value;
      CSR_RECOVERY_CTRL:   csr_data <= hwif_rec_i.RECOVERY_CTRL.PLACEHOLDER.value;
      CSR_RECOVERY_STATUS: csr_data <= hwif_rec_i.RECOVERY_STATUS.PLACEHOLDER.value;
      CSR_HW_STATUS:       csr_data <= hwif_rec_i.HW_STATUS.PLACEHOLDER.value;

      CSR_INDIRECT_FIFO_CTRL_0:   csr_data <= hwif_rec_i.INDIRECT_FIFO_CTRL_0.PLACEHOLDER.value;
      CSR_INDIRECT_FIFO_CTRL_1:   csr_data <= hwif_rec_i.INDIRECT_FIFO_CTRL_1.PLACEHOLDER.value;
      CSR_INDIRECT_FIFO_STATUS_0: csr_data <= indirect_fifo_status_0;
      CSR_INDIRECT_FIFO_STATUS_1: csr_data <= hwif_rec_i.INDIRECT_FIFO_STATUS_1.WRITE_INDEX.value;
      CSR_INDIRECT_FIFO_STATUS_2: csr_data <= hwif_rec_i.INDIRECT_FIFO_STATUS_2.READ_INDEX.value;
      CSR_INDIRECT_FIFO_STATUS_3: csr_data <= hwif_rec_i.INDIRECT_FIFO_STATUS_3.FIFO_SIZE.value;
      CSR_INDIRECT_FIFO_STATUS_4: csr_data <= hwif_rec_i.INDIRECT_FIFO_STATUS_4.MAX_TRANSFER_SIZE.value;

      default: csr_data <= '0;
    endcase

  // INDIRECT_FIFO_STATUS_0 as a 32-bit word
  assign indirect_fifo_status_0 = {
    // b3,b2
    16'd0,
    // b1
    5'd0,
    hwif_rec_i.INDIRECT_FIFO_STATUS_0.REGION.value,
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
    hwif_rec_o.DEVICE_STATUS_0.PLACEHOLDER.we =
            status_device_we | status_protocol_we | status_reason_we;
  end

  always_comb begin
    hwif_rec_o.DEVICE_STATUS_0.PLACEHOLDER.next[ 7: 0] = status_device_we   ? status_device   : hwif_rec_i.DEVICE_STATUS_0.PLACEHOLDER.value[ 7: 0];
    hwif_rec_o.DEVICE_STATUS_0.PLACEHOLDER.next[15: 8] = status_protocol_we ? status_protocol : hwif_rec_i.DEVICE_STATUS_0.PLACEHOLDER.value[15: 8];
    hwif_rec_o.DEVICE_STATUS_0.PLACEHOLDER.next[31:16] = status_reason_we   ? status_reason   : hwif_rec_i.DEVICE_STATUS_0.PLACEHOLDER.value[31:16];
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
      fifo_full_r  <= indirect_rx_full_i;
      fifo_empty_r <= indirect_rx_empty_i;
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
    fifo_ptr_top <= fifo_size - 32'b1;
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
  assign hwif_rec_o.INDIRECT_FIFO_STATUS_1.WRITE_INDEX.we =
    (fifo_wrptr_inc | fifo_ptr_clr);

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
  assign hwif_rec_o.INDIRECT_FIFO_STATUS_2.READ_INDEX.we =
    (fifo_rdptr_inc | fifo_ptr_clr);

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
  assign fifo_ptr_clr = tti_rx_rack_i &
    (csr_sel == CSR_INDIRECT_FIFO_CTRL_0) & (tti_rx_rdata_i[15:8] == 8'd1);

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

  // CSR write. Only applicable for writable CSRs as per the OCP
  // recovery spec.
  always_comb begin
    hwif_rec_o.PROT_CAP_0.PLACEHOLDER.we = '0;
    hwif_rec_o.PROT_CAP_1.PLACEHOLDER.we = '0;
    hwif_rec_o.PROT_CAP_2.PLACEHOLDER.we = '0;
    hwif_rec_o.PROT_CAP_3.PLACEHOLDER.we = '0;
    hwif_rec_o.DEVICE_ID_0.PLACEHOLDER.we = '0;
    hwif_rec_o.DEVICE_ID_1.PLACEHOLDER.we = '0;
    hwif_rec_o.DEVICE_ID_2.PLACEHOLDER.we = '0;
    hwif_rec_o.DEVICE_ID_3.PLACEHOLDER.we = '0;
    hwif_rec_o.DEVICE_ID_4.PLACEHOLDER.we = '0;
    hwif_rec_o.DEVICE_ID_5.PLACEHOLDER.we = '0;
    hwif_rec_o.DEVICE_ID_6.PLACEHOLDER.we = '0;
    hwif_rec_o.DEVICE_STATUS_1.PLACEHOLDER.we = '0;
    hwif_rec_o.DEVICE_RESET.PLACEHOLDER.we = tti_rx_rack_i & (csr_sel == CSR_DEVICE_RESET);
    hwif_rec_o.RECOVERY_CTRL.PLACEHOLDER.we = tti_rx_rack_i & (csr_sel == CSR_RECOVERY_CTRL);
    hwif_rec_o.RECOVERY_STATUS.PLACEHOLDER.we = '0;
    hwif_rec_o.HW_STATUS.PLACEHOLDER.we = '0;
    hwif_rec_o.INDIRECT_FIFO_CTRL_0.PLACEHOLDER.we = tti_rx_rack_i & (csr_sel == CSR_INDIRECT_FIFO_CTRL_0);
    hwif_rec_o.INDIRECT_FIFO_CTRL_1.PLACEHOLDER.we = tti_rx_rack_i & (csr_sel == CSR_INDIRECT_FIFO_CTRL_1);
    hwif_rec_o.INDIRECT_FIFO_STATUS_0.REGION.we = '0;
    hwif_rec_o.INDIRECT_FIFO_STATUS_4.MAX_TRANSFER_SIZE.we  = '0;
    hwif_rec_o.INDIRECT_FIFO_STATUS_5.PLACEHOLDER.we = '0;
  end

  always_comb begin
    hwif_rec_o.DEVICE_RESET.PLACEHOLDER.next         = tti_rx_rdata_i;
    hwif_rec_o.RECOVERY_CTRL.PLACEHOLDER.next        = tti_rx_rdata_i;
    hwif_rec_o.INDIRECT_FIFO_CTRL_0.PLACEHOLDER.next = tti_rx_rdata_i;
    hwif_rec_o.INDIRECT_FIFO_CTRL_1.PLACEHOLDER.next = tti_rx_rdata_i;
  end

  // Force the value of FIFO_STATUS.FIFO_SIZE to IndirectFifoDepth.
  always_comb begin
    hwif_rec_o.INDIRECT_FIFO_STATUS_3.FIFO_SIZE.next = IndirectFifoDepth;
    hwif_rec_o.INDIRECT_FIFO_STATUS_3.FIFO_SIZE.we   = '1;
  end

  // ....................................................

  // Connect CSR logic to indirect FIFO rx data port
  always_comb begin
    indirect_rx_rreq_o = hwif_rec_i.INDIRECT_FIFO_DATA.req & !hwif_rec_i.INDIRECT_FIFO_DATA.req_is_wr;
    hwif_rec_o.INDIRECT_FIFO_DATA.rd_data = indirect_rx_rdata_i;
    hwif_rec_o.INDIRECT_FIFO_DATA.rd_ack  = indirect_rx_rack_i;
    hwif_rec_o.INDIRECT_FIFO_DATA.wr_ack  = '0; // TODO: support writes
  end

  // tie unused signals
  always_comb begin
    hwif_rec_o.PROT_CAP_3.PLACEHOLDER.next = '0;
    hwif_rec_o.DEVICE_ID_6.PLACEHOLDER.next = '0;
    hwif_rec_o.PROT_CAP_1.PLACEHOLDER.next = '0;
    hwif_rec_o.INDIRECT_FIFO_STATUS_4.MAX_TRANSFER_SIZE.next = '0;
    hwif_rec_o.DEVICE_ID_4.PLACEHOLDER.next = '0;
    hwif_rec_o.PROT_CAP_2.PLACEHOLDER.next = '0;
    hwif_rec_o.DEVICE_ID_1.PLACEHOLDER.next = '0;
    hwif_rec_o.DEVICE_ID_2.PLACEHOLDER.next = '0;
    hwif_rec_o.HW_STATUS.PLACEHOLDER.next = '0;
    hwif_rec_o.DEVICE_STATUS_1.PLACEHOLDER.next = '0;
    hwif_rec_o.RECOVERY_STATUS.PLACEHOLDER.next = '0;
    hwif_rec_o.INDIRECT_FIFO_STATUS_0.REGION.next = '0;
    hwif_rec_o.PROT_CAP_0.PLACEHOLDER.next = '0;
    hwif_rec_o.DEVICE_ID_3.PLACEHOLDER.next = '0;
    hwif_rec_o.INDIRECT_FIFO_STATUS_5.PLACEHOLDER.next = '0;
    hwif_rec_o.DEVICE_ID_5.PLACEHOLDER.next = '0;
    hwif_rec_o.DEVICE_ID_0.PLACEHOLDER.next = '0;
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
  // Assert payload_available_o upon reception of a complete recovery write
  // packet targeting CSR_INDIRECT_FIFO_DATA.
  always_comb begin : payload_available
    payload_available_d = 1'b0;
    payload_available_write = 1'b0;
    if (state_q == Idle & cmd_valid_i & !cmd_error_i & !cmd_is_rd_i &
        cmd_cmd_i == CMD_INDIRECT_FIFO_DATA)
    begin
      payload_available_d = 1'b1;
      payload_available_write = 1'b1;
    end
    if (hwif_rec_i.INDIRECT_FIFO_DATA.req && !hwif_rec_i.INDIRECT_FIFO_DATA.req_is_wr) begin
      payload_available_d = 1'b0;
      payload_available_write = 1'b1;
    end
  end : payload_available
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) payload_available_q <= '0;
    else payload_available_q <= payload_available_write ? payload_available_d : payload_available_q;

  // Image activation logic.
  assign image_activated_o = (hwif_rec_i.RECOVERY_CTRL.PLACEHOLDER.value[23:16] == 8'h0F);

endmodule
