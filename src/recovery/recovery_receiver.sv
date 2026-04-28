// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//==============================================================================
// Module: recovery_receiver
//
// Description:
//   OCP Secure Firmware Recovery Protocol Receiver and Transmitter.
//   Implements the OCP Recovery Interface v1.1 protocol for secure firmware
//   recovery over I3C. Handles both WRITE and READ commands, including
//   protocol parsing, PEC validation, command execution, and response
//   generation.
//
// OCP Recovery Protocol Frame Formats:
//
//   WRITE (Controller to Target):
//     S/Sr + Addr+W + CMD + LEN_L + LEN_H + DATA[0..N-1] + PEC + Sr/P
//     |     |        |     |       |       |              |     |
//     |     |        |     |       |       |              |     +-- Stop or Repeated Start
//     |     |        |     |       |       |              +-- CRC-8 over CMD+LEN+DATA
//     |     |        |     |       |       +-- N bytes of payload data
//     |     |        |     |       +-- Length MSB (bits 15:8)
//     |     |        |     +-- Length LSB (bits 7:0)
//     |     |        +-- Command code (34-47)
//     |     +-- Virtual target address with Write bit (RnW=0)
//     +-- Start or Repeated Start condition
//
//   READ (Controller to Target, then Target to Controller):
//     S/Sr + Addr+W + CMD + PEC + Sr + Addr+R + (T) LEN_L + (T) LEN_H + (T) DATA[0..N-1] + (T) PEC + Sr/P
//     |     |        |     |      |    |        |          |          |                   |          |
//     |     |        |     |      |    |        |          |          |                   |          +-- Stop or Sr
//     |     |        |     |      |    |        |          |          |                   +-- (T) CRC-8 over LEN+DATA
//     |     |        |     |      |    |        |          |          +-- (T) N bytes of response data
//     |     |        |     |      |    |        |          +-- (T) Length MSB
//     |     |        |     |      |    |        +-- (T) Length LSB
//     |     |        |     |      |    +-- Virtual target address with Read bit (RnW=1)
//     |     |        |     |      +-- Repeated Start (triggers target to respond)
//     |     |        |     +-- CRC-8 over CMD only (no length bytes in write phase)
//     |     |        +-- Command code (34-47)
//     |     +-- Virtual target address with Write bit (RnW=0)
//     +-- Start or Repeated Start condition
//     Note: (T) indicates bytes transmitted by Target
//
// FSM State Flow:
//
//   WRITE Command:
//     Idle ─(S/Sr+Addr+W)─> RxCmd ─(CMD)─> RxLenL ─(LEN_L)─> RxLenH ─(LEN_H)─> RxData
//                                                                                 │
//       ┌─────────────────────────────────────────────────────────────────────────┘
//       │
//       └─(all data received)─> RxPec ─(PEC+last)─> CmdDispatch ─> ExecCsrWrite ─> Done
//                                                               └─> ExecFifoWrite ─> Done
//
//   READ Command:
//     Idle ─(S/Sr+Addr+W)─> RxCmd ─(CMD)─> RxLenL ─(PEC*)─> RxLenH ─(Sr detected)─> CmdDispatch
//                                                                                        │
//       ┌────────────────────────────────────────────────────────────────────────────────┘
//       │
//       └─> TxDesc ─(desc queued)─> TxLenL ─(LEN_L sent)─> TxLenH ─(LEN_H sent)─> TxData
//                                                                                     │
//       ┌─────────────────────────────────────────────────────────────────────────────┘
//       │
//       └─(all data sent)─> TxPec ─(PEC sent)─> Done
//
//     * For READ: PEC byte is received in RxLenL state (stored as len_lsb) and latched
//       as the actual PEC when Sr is detected in RxLenH via latch_pec_from_len signal.
//
// Supported Commands (OCP Recovery v1.1):
//   34: PROT_CAP           (R)  - Protocol capabilities
//   35: DEVICE_ID          (R)  - Device identification
//   36: DEVICE_STATUS      (R)  - Device status
//   37: DEVICE_RESET       (W)  - Device reset control
//   38: RECOVERY_CTRL      (W)  - Recovery control
//   39: RECOVERY_STATUS    (R)  - Recovery status
//   40: HW_STATUS          (R)  - Hardware status
//   45: INDIRECT_FIFO_CTRL (W)  - Indirect FIFO control
//   46: INDIRECT_FIFO_STATUS(R) - Indirect FIFO status
//   47: INDIRECT_FIFO_DATA (W)  - Firmware data to FIFO
//
//==============================================================================

module recovery_receiver
  import i3c_pkg::*;
  import I3CCSR_pkg::*;
#(
    parameter int unsigned TtiRxDescDataWidth = 32,
    parameter int unsigned TtiTxDescDataWidth = 32,
    parameter int unsigned TtiRxDataDataWidth = 32,
    parameter int unsigned CsrDataWidth       = 32,
    parameter int unsigned IndirectFifoDepth  = 64
) (
    //--------------------------------------------------------------------------
    // Clock and Reset
    //--------------------------------------------------------------------------
    input  logic clk_i,
    input  logic rst_ni,

    //--------------------------------------------------------------------------
    // Configuration
    //--------------------------------------------------------------------------
    input  logic bypass_i3c_core_i,
    input  logic pec_err_det_en_i,
    input  logic length_err_det_en_i,
    input  logic readonly_err_det_en_i,
    input  logic unsupported_err_det_en_i,
    input  logic rx_fifo_overflow_err_det_en_i,
    input  logic rx_fifo_overflow_raw_i,  // Raw overflow signal from handler
    input  logic indirect_fifo_overflow_err_det_en_i,
    input  logic recovery_mode_csr_active_i,

    //--------------------------------------------------------------------------
    // TTI RX Data Interface (byte stream from controller)
    //--------------------------------------------------------------------------
    input  logic       rx_data_valid_i,
    output logic       rx_data_ready_o,
    input  logic [7:0] rx_data_i,
    input  logic       rx_data_last_i,

    //--------------------------------------------------------------------------
    // TTI RX Queue Control
    //--------------------------------------------------------------------------
    // Select=1: Receiver consumes bytes directly (header/PEC)
    // Select=0: Bytes go to queue (payload)
    output logic rx_data_queue_select_o, 
    output logic rx_data_queue_flush_o,
    output logic conv_soft_reset_o,  // Assert during Error to reset width converters
    input  logic rx_data_queue_flow_i,

    //--------------------------------------------------------------------------
    // TTI RX Data Queue (32-bit word interface for execution)
    //--------------------------------------------------------------------------
    output logic                          tti_rx_rreq_o,
    input  logic                          tti_rx_rack_i,
    input  logic [TtiRxDataDataWidth-1:0] tti_rx_rdata_i,
    output logic                          tti_rx_sel_o,
    output logic                          rx_data_queue_clr_o,
    output logic                          rx_desc_queue_clr_o,
    output logic                          tx_data_queue_clr_o,
    output logic                          tx_desc_queue_clr_o,

    //--------------------------------------------------------------------------
    // Indirect FIFO Interface
    //--------------------------------------------------------------------------
    output logic                    indirect_rx_wvalid_o,
    input  logic                    indirect_rx_wready_i,
    output logic [CsrDataWidth-1:0] indirect_rx_wdata_o,
    output logic                    indirect_rx_rreq_o,
    input  logic                    indirect_rx_rack_i,
    input  logic [CsrDataWidth-1:0] indirect_rx_rdata_i,
    input  logic                    indirect_rx_full_i,
    input  logic                    indirect_rx_empty_i,
    output logic                    indirect_rx_clr_o,

    //--------------------------------------------------------------------------
    // Bus Condition Signals
    //--------------------------------------------------------------------------
    input  logic bus_start_i,      // Start condition (S)
    input  logic bus_rstart_i,     // Repeated Start condition (Sr)
    input  logic bus_any_start_i,  // Any start (S or Sr) - from recovery_handler
    input  logic bus_stop_i,
    input  logic in_hdr_mode_i,
    input  logic [7:0] bus_addr_i, // Received I2C/I3C address with RnW bit (bit 0)

    //--------------------------------------------------------------------------
    // RX PEC Interface
    //--------------------------------------------------------------------------
    input  logic [7:0] pec_crc_i,
    output logic       pec_enable_o,
    output logic       pec_init_o,

    //--------------------------------------------------------------------------
    // TTI TX Descriptor Interface
    //--------------------------------------------------------------------------
    output logic                          tx_desc_valid_o,
    input  logic                          tx_desc_ready_i,
    output logic [TtiTxDescDataWidth-1:0] tx_desc_data_o,

    //--------------------------------------------------------------------------
    // TTI TX Data Interface
    //--------------------------------------------------------------------------
    output logic       tx_data_valid_o,
    input  logic       tx_data_ready_i,
    output logic [7:0] tx_data_o,

    //--------------------------------------------------------------------------
    // TTI TX Queue Control
    //--------------------------------------------------------------------------
    output logic tx_data_queue_select_o,
    output logic tx_start_trig_o,

    //--------------------------------------------------------------------------
    // TX PEC Interface
    //--------------------------------------------------------------------------
    input  logic [7:0] tx_pec_crc_i,
    output logic       tx_pec_enable_o,
    output logic       tx_pec_init_o,
    output logic       tx_pec_soft_rst_n_o,

    //--------------------------------------------------------------------------
    // Control Signals
    //--------------------------------------------------------------------------
    input  logic virtual_target_start_i,
    input  logic other_target_start_i,   // Pulse when different target addressed (Sr to other)

    //--------------------------------------------------------------------------
    // Status Outputs
    //--------------------------------------------------------------------------
    output logic payload_available_o,
    output logic image_activated_o,
    output logic pec_err_o,
    output logic length_err_o,
    output logic readonly_err_o,
    output logic unsupported_err_o,
    output logic exec_pending_o,
    output logic rx_fifo_overflow_err_o,       // RX FIFO overflow error (always reported)
    output logic indirect_fifo_overflow_err_o, // INDIRECT_FIFO overflow error

    // RX descriptor interface — monitored for bus-level parity errors
    input  logic                          rx_desc_wvalid_i,
    input  logic [TtiRxDescDataWidth-1:0] rx_desc_wdata_i,

    //--------------------------------------------------------------------------
    // Recovery CSR Interface
    //--------------------------------------------------------------------------
    input  I3CCSR__I3C_EC__SecFwRecoveryIf__out_t hwif_rec_i,
    output I3CCSR__I3C_EC__SecFwRecoveryIf__in_t  hwif_rec_o,

    //--------------------------------------------------------------------------
    // SoC Management CSR Interface (Bypass Mode)
    //--------------------------------------------------------------------------
    input  I3CCSR__I3C_EC__SoCMgmtIf__out_t hwif_socmgmt_i,
    output I3CCSR__I3C_EC__SoCMgmtIf__in_t  hwif_socmgmt_o
);

  //============================================================================
  //
  // SECTION 1: PARAMETERS AND TYPE DEFINITIONS
  //
  //============================================================================

  //----------------------------------------------------------------------------
  //----------------------------------------------------------------------------
  // Protocol Error Codes (OCP Secure Firmware Recovery spec v1.1)
  // Used in DEVICE_STATUS.PROT_ERROR field to report protocol violations
  //----------------------------------------------------------------------------
  typedef enum logic [7:0] {
    PROTOCOL_OK              = 8'h00,
    PROTOCOL_ERROR_READONLY  = 8'h01,  // Write to read-only command
    PROTOCOL_ERROR_PARAMETER = 8'h02,  // Parameter error (reserved for future use)
    PROTOCOL_ERROR_LENGTH    = 8'h03,  // Length write error
    PROTOCOL_ERROR_CRC       = 8'h04   // CRC/PEC error
  } protocol_error_e;

  //----------------------------------------------------------------------------
  // OCP Recovery Command Codes
  //----------------------------------------------------------------------------
  typedef enum logic [7:0] {
    CMD_PROT_CAP             = 8'd34,
    CMD_DEVICE_ID            = 8'd35,
    CMD_DEVICE_STATUS        = 8'd36,
    CMD_DEVICE_RESET         = 8'd37,
    CMD_RECOVERY_CTRL        = 8'd38,
    CMD_RECOVERY_STATUS      = 8'd39,
    CMD_HW_STATUS            = 8'd40,
    CMD_INDIRECT_CTRL        = 8'd41,
    CMD_INDIRECT_STATUS      = 8'd42,
    CMD_INDIRECT_DATA        = 8'd43,
    CMD_VENDOR               = 8'd44,
    CMD_INDIRECT_FIFO_CTRL   = 8'd45,
    CMD_INDIRECT_FIFO_STATUS = 8'd46,
    CMD_INDIRECT_FIFO_DATA   = 8'd47
  } command_e;

  //----------------------------------------------------------------------------
  // CSR Selector Enumeration
  //----------------------------------------------------------------------------
  typedef enum logic [7:0] {
    CSR_INVALID = 0,
    CSR_PROT_CAP_0,
    CSR_PROT_CAP_1,
    CSR_PROT_CAP_2,
    CSR_PROT_CAP_3,
    CSR_DEVICE_ID_0,
    CSR_DEVICE_ID_1,
    CSR_DEVICE_ID_2,
    CSR_DEVICE_ID_3,
    CSR_DEVICE_ID_4,
    CSR_DEVICE_ID_5,
    CSR_DEVICE_STATUS_0,
    CSR_DEVICE_STATUS_1,
    CSR_DEVICE_RESET,
    CSR_RECOVERY_CTRL,
    CSR_RECOVERY_STATUS,
    CSR_HW_STATUS,
    CSR_INDIRECT_FIFO_CTRL_0,
    CSR_INDIRECT_FIFO_CTRL_1,
    CSR_INDIRECT_FIFO_STATUS_0,
    CSR_INDIRECT_FIFO_STATUS_1,
    CSR_INDIRECT_FIFO_STATUS_2,
    CSR_INDIRECT_FIFO_STATUS_3,
    CSR_INDIRECT_FIFO_STATUS_4,
    CSR_INDIRECT_FIFO_DATA
  } csr_e;

  //----------------------------------------------------------------------------
  // FSM State Definitions
  //----------------------------------------------------------------------------
  typedef enum logic [7:0] {
    Idle          = 8'h00,
    RxCmd         = 8'h10,
    RxLenL        = 8'h11,
    RxLenH        = 8'h12,
    RxData        = 8'h20,
    RxPec         = 8'h30,
    CmdDispatch   = 8'h40,
    ExecCsrWrite  = 8'h41,
    ExecFifoWrite = 8'h50,
    TxDesc        = 8'h60,
    TxLenL        = 8'h61,
    TxLenH        = 8'h62,
    TxData        = 8'h63,
    TxPec         = 8'h64,
    Done          = 8'hD0,
    Error         = 8'hE1
  } state_e;

  //============================================================================
  //
  // SECTION 2: SIGNAL DECLARATIONS
  //
  //============================================================================

  //----------------------------------------------------------------------------
  // FSM Signals
  //----------------------------------------------------------------------------
  state_e state_q, state_d;
  
  // FSM trigger signals (active for one cycle)
  logic capture_cmd;
  logic capture_len_lsb;
  logic capture_len_msb;
  logic capture_pec;
  logic set_cmd_is_rd;
  logic latch_pec_from_len;
  logic load_csr_sel;    // Loads csr_sel/csr_end (CmdDispatch)
  logic inc_csr_sel;     // Advances csr_sel at DWORD boundaries
  logic load_csr_data;   // Delayed pulse: captures csr_data 1 cycle after csr_sel settles
  logic load_csr_length;

  //----------------------------------------------------------------------------
  // Command Header Signals
  //----------------------------------------------------------------------------
  command_e    cmd_cmd;           // Command code
  logic        cmd_is_rd;         // READ command flag

  logic [7:0]  len_lsb;           // Length LSB
  logic [7:0]  len_msb;           // Length MSB
  logic [15:0] cmd_len;           // Combined length

  //----------------------------------------------------------------------------
  // PEC Signals
  //----------------------------------------------------------------------------
  logic [7:0] pec_recv;           // Received PEC byte
  logic [7:0] pec_calc;           // Calculated PEC

  //----------------------------------------------------------------------------
  // Counter Signals
  //----------------------------------------------------------------------------
  logic [15:0] dcnt, dcnt_next;                     // Data word counter
  logic [1:0]  bcnt, bcnt_next;                     // Byte counter (0-3)
  logic [15:0] payload_byte_cnt, payload_byte_cnt_next;  // Payload byte counter
  logic [1:0]  pec_rx_byte_cnt;                     // PEC byte counter

  //----------------------------------------------------------------------------
  // Length Validation Signals
  //----------------------------------------------------------------------------
  logic        all_data_received;

  //----------------------------------------------------------------------------
  // Bus Condition Signals
  //----------------------------------------------------------------------------
  logic rx_flow;

  //----------------------------------------------------------------------------
  // CSR Access Signals
  //----------------------------------------------------------------------------
  csr_e        csr_sel, csr_end;
  csr_e        csr_sel_next, csr_end_next;
  logic [31:0] csr_data, csr_data_next;
  logic [15:0] csr_length, csr_length_next;
  logic        csr_writable;
  logic [TtiRxDataDataWidth-1:0] prev_tti_rx_rdata;

  //----------------------------------------------------------------------------
  // CSR Composite Data Signals
  //----------------------------------------------------------------------------
  logic [31:0] prot_cap_2, prot_cap_3;
  logic [31:0] device_id_0;
  logic [31:0] device_status_0, device_status_1;
  logic [31:0] device_reset;
  logic [31:0] recovery_ctrl, recovery_status;
  logic [31:0] hw_status;
  logic [31:0] indirect_fifo_ctrl_0, indirect_fifo_ctrl_1;
  logic [31:0] indirect_fifo_status_0;

  //----------------------------------------------------------------------------
  // CSR Write Enable Signals
  //----------------------------------------------------------------------------
  logic device_reset_we;
  logic indirect_fifo_ctrl_0_we;
  logic recovery_ctrl_we;

  //----------------------------------------------------------------------------
  // Indirect FIFO Signals
  //----------------------------------------------------------------------------
  logic [31:0] fifo_size;
  logic [31:0] fifo_wrptr, fifo_rdptr;
  logic        fifo_wrptr_inc, fifo_rdptr_inc;
  logic        fifo_ptr_clr;

  //----------------------------------------------------------------------------
  // Protocol Status Signals
  //----------------------------------------------------------------------------
  protocol_error_e status_protocol;
  logic            status_protocol_we;
  logic            entering_error;
  logic            entering_done_directly;

  //----------------------------------------------------------------------------
  // Payload and Transfer Signals
  //----------------------------------------------------------------------------
  logic payload_available_q;
  logic fifo_xfer_done;
  logic payload_high_en;
  logic bypass_xfer_done;

  //----------------------------------------------------------------------------
  // Bypass Mode Signals
  //----------------------------------------------------------------------------
  logic       sw_device_reset_ctrl_swmod;
  logic       sw_recovery_ctrl_activate_rec_img_swmod;
  logic       sw_indirect_fifo_ctrl_reset_swmod;
  logic [7:0] sw_device_reset_ctrl_value;
  logic [7:0] sw_recovery_ctrl_activate_rec_img_value;
  logic [7:0] sw_indirect_fifo_ctrl_reset_value;

  //----------------------------------------------------------------------------
  // Error Detection Signals
  //----------------------------------------------------------------------------
  // FSM-generated error signals (set when masked error detected in correct state)
  logic        pec_err;               // PEC error detected in CmdDispatch
  logic        length_underrun_err;   // Underrun detected in RxData
  logic        length_overrun_err;    // Overrun detected in RxPec
  logic        readonly_err;          // Read-only error detected in CmdDispatch
  logic        unsupported_err;       // Unsupported error detected in CmdDispatch
  logic        csr_length_err;        // CSR write length mismatch detected in CmdDispatch
  logic        premature_stop;        // Premature bus stop detected (combinational)
  logic        premature_stop_q;      // Registered premature stop for Error state exit
  
  // FIFO overflow error signals
  logic        rx_fifo_overflow_err;         // RX FIFO overflow detected in FSM
  logic        indirect_fifo_overflow_err;       // INDIRECT_FIFO overflow detected in FSM

  //============================================================================
  //
  // SECTION 3: STATIC ASSIGNMENTS
  //
  //============================================================================

  // RX interface
  assign rx_flow      = rx_data_valid_i & rx_data_ready_o;
  assign cmd_len      = {len_msb, len_lsb};
  assign tti_rx_sel_o = 1'b1;

  // TX queue control
  assign tx_data_queue_select_o = 1'b1;
  assign tx_start_trig_o        = 1'b0;

  // Queue clear signals
  assign rx_data_queue_clr_o = (state_q == Error);
  assign rx_desc_queue_clr_o = (state_q == Error);
  assign tx_data_queue_clr_o = 1'b0;
  assign tx_desc_queue_clr_o = 1'b0;

  // Status outputs
  assign payload_available_o = payload_available_q;
  // exec_pending is combinational - high during all execution states to prevent
  // recovery_pending from deasserting between xfer_pending and exec states
  assign exec_pending_o      = state_q inside {CmdDispatch, ExecCsrWrite, ExecFifoWrite,
                                                TxDesc, TxLenL, TxLenH, TxData, TxPec};
  assign image_activated_o   = (hwif_rec_i.RECOVERY_CTRL.ACTIVATE_REC_IMG.value == 8'h0F);

  // Length validation - Raw detection (always active, no state qualification)
  assign all_data_received       = (payload_byte_cnt == cmd_len);


  //============================================================================
  //
  // SECTION 4: FSM STATE MACHINE
  //
  //============================================================================

  //----------------------------------------------------------------------------
  // State Register
  //----------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= Idle;
    end else begin
      state_q <= state_d;
    end
  end

  //----------------------------------------------------------------------------
  // Premature Stop Register
  //----------------------------------------------------------------------------
  // Capture premature_stop for one cycle so Error state can see it and exit.
  // Clear when leaving Error state (entering Done).
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      premature_stop_q <= 1'b0;
    end else if (premature_stop) begin
      premature_stop_q <= 1'b1;
    end else if (state_q == Done) begin
      premature_stop_q <= 1'b0;
    end
  end

  //----------------------------------------------------------------------------
  // Next State Logic
  //----------------------------------------------------------------------------
  always_comb begin
    // Default values
    state_d                = state_q;
    capture_cmd            = 1'b0;
    capture_len_lsb        = 1'b0;
    capture_len_msb        = 1'b0;
    capture_pec            = 1'b0;
    set_cmd_is_rd          = 1'b0;
    latch_pec_from_len     = 1'b0;
    load_csr_sel           = 1'b0;
    inc_csr_sel            = 1'b0;
    load_csr_length        = 1'b0;
    rx_data_queue_select_o = 1'b0;
    rx_data_queue_flush_o  = 1'b0;
    pec_enable_o           = 1'b0;
    pec_init_o             = 1'b0;
    tx_pec_enable_o        = 1'b0;
    tx_pec_init_o          = 1'b0;
    tx_pec_soft_rst_n_o    = 1'b0; // Reset unless in certain states

    // Error signal defaults
    pec_err               = 1'b0;
    length_underrun_err   = 1'b0;
    length_overrun_err    = 1'b0;
    readonly_err          = 1'b0;
    unsupported_err       = 1'b0;
    csr_length_err        = 1'b0;
    rx_fifo_overflow_err  = 1'b0;
    indirect_fifo_overflow_err = 1'b0;
    premature_stop        = 1'b0;

    //--------------------------------------------------------------------------
    // Global HDR Mode Check
    // If HDR mode is entered unexpectedly (TE0/TE1) while in any active state,
    // immediately transition to Error. This handles cases like:
    // - TE0: Invalid address during Sr + Addr+R phase of READ command
    // - TE1: Parity error during CCC (should be idle, but defensive)
    //--------------------------------------------------------------------------
    if (in_hdr_mode_i && !(state_q inside {Idle, Error, Done})) begin
      state_d = Error;
    end else begin
      unique case (state_q)
        //------------------------------------------------------------------------
        // Idle: Wait for new transaction
        // OCP Recovery protocol requires a WRITE phase first (S + Addr+W + CMD...)
        // A READ directly from Idle (without prior command) is not supported.
        //------------------------------------------------------------------------
        Idle: begin
          if (virtual_target_start_i) begin
            if (bus_addr_i[0]) begin
              // RnW=1 (Read) directly from Idle - unsupported
              // Read transactions must be preceded by a write command phase
              unsupported_err = unsupported_err_det_en_i;
              state_d         = Error;
            end else begin
              // RnW=0 (Write) - valid start of recovery transaction
              state_d      = RxCmd;
              pec_enable_o = 1'b1;
              pec_init_o   = 1'b1;
            end
          end
        end

        //------------------------------------------------------------------------
        // RxCmd: Receive command byte
        //------------------------------------------------------------------------
        RxCmd: begin
          rx_data_queue_select_o = 1'b1;
          
          if (bus_stop_i || bus_rstart_i || rx_data_last_i)  begin
            // Premature Stop or Repeated Start detected
            premature_stop      = 1'b1;
            length_underrun_err = length_err_det_en_i;  // Report as length error (underrun)
            state_d             = Error;
          end else if (rx_flow) begin
            capture_cmd   = 1'b1;
            pec_enable_o  = 1'b1;
            state_d       = RxLenL;
          end
        end

        //------------------------------------------------------------------------
        // RxLenL: Receive length LSB (WRITE) or PEC byte (READ)
        //------------------------------------------------------------------------
        RxLenL: begin
          rx_data_queue_select_o = 1'b1;

          if (bus_stop_i || bus_rstart_i || rx_data_last_i)  begin
            // Premature Stop or Repeated Start detected
            premature_stop      = 1'b1;
            length_underrun_err = length_err_det_en_i;  // Report as length error (underrun)
            state_d             = Error;
          end else if (rx_flow) begin
            capture_len_lsb = 1'b1;
            pec_enable_o    = 1'b1;
            state_d         = RxLenH;
          end
        end

        //------------------------------------------------------------------------
        // RxLenH: Receive length MSB or detect restart for READ
        //------------------------------------------------------------------------
        RxLenH: begin
          rx_data_queue_select_o = 1'b1;

          if (bus_stop_i)  begin
            // Premature Stop detected
            premature_stop      = 1'b1;
            length_underrun_err = length_err_det_en_i;  // Report as length error (underrun)
            state_d             = Error;
          end else if (rx_desc_wvalid_i && |rx_desc_wdata_i[31:28] && pec_err_det_en_i) begin
            // RX descriptor reports bus-level error (T-bit parity) on write-phase PEC
            // rx_desc_wvalid_i will be asserted same clock cycle as
            // bus_rstart_i. If not assertion fires
            pec_err = 1'b1;
            state_d = Error;
          end else if (bus_rstart_i) begin
            // Repeated Start (Sr) indicates READ command - controller wants to read
            set_cmd_is_rd      = 1'b1;
            latch_pec_from_len = 1'b1;
            state_d = CmdDispatch;
          end else if (rx_flow) begin
            capture_len_msb = 1'b1;
            pec_enable_o    = 1'b1;
            state_d         = RxData;
          end
        end

        //------------------------------------------------------------------------
        // RxData: Collect payload bytes until expected length reached
        //------------------------------------------------------------------------
        RxData: begin
          if(rx_data_queue_flow_i) begin
            pec_enable_o    = 1'b1;
          end

          if (bus_stop_i || bus_rstart_i || rx_data_last_i)  begin
            // Premature Stop or Repeated Start detected
            premature_stop       = 1'b1;
            length_underrun_err  = (payload_byte_cnt < cmd_len) && length_err_det_en_i;
            rx_fifo_overflow_err = rx_fifo_overflow_raw_i && rx_fifo_overflow_err_det_en_i;
            state_d              = Error;
          end else if (all_data_received) begin
            state_d = RxPec;
          end
        end

        //------------------------------------------------------------------------
        // RxPec: Capture PEC byte (validation deferred to CmdDispatch)
        //------------------------------------------------------------------------
        RxPec: begin
          rx_data_queue_select_o = 1'b1;

          if (rx_flow) capture_pec = 1'b1;
          
          if ((pec_rx_byte_cnt > 1) && length_err_det_en_i) begin
            length_overrun_err = 1'b1;
            state_d = Error;
          end else if ((pec_rx_byte_cnt == '0) && (bus_stop_i || bus_rstart_i || rx_data_last_i)) begin
            // Premature Stop/Repeated Start/last before PEC byte received - length underrun
            premature_stop      = 1'b1;
            length_underrun_err = ((payload_byte_cnt < cmd_len) || pec_rx_byte_cnt == '0) && length_err_det_en_i;
            state_d             = Error;
          end else if (rx_data_last_i && |rx_desc_wdata_i[31:28] && pec_err_det_en_i) begin
            // RX descriptor reports bus-level error (T-bit parity or overflow)
            // rx_data_last_i should be asserted the same clock cycle
            // as rx_desc_wvalid_i if not an assertion will fire.
            pec_err        = 1'b1;
            state_d        = Error;
          end else if (rx_data_last_i) begin
              state_d = CmdDispatch;
              // Flush partial word from width converter before ExecCsrWrite reads
              rx_data_queue_flush_o = |(payload_byte_cnt[1:0]);
          end
        end

        //------------------------------------------------------------------------
        // CmdDispatch: Validate command and route to appropriate execution state
        // For WRITE commands: Transition immediately to execution state
        // For READ commands: Transition to TxDesc to queue descriptor before Sr+Addr+R
        //------------------------------------------------------------------------
        CmdDispatch: begin
          load_csr_sel    = 1'b1;
          load_csr_length = 1'b1;
          
          // Set error signals for masked errors detected in this state
          pec_err             = (pec_calc != pec_recv) && pec_err_det_en_i;
          readonly_err        = !cmd_is_rd && (cmd_cmd inside {
                                  CMD_PROT_CAP, CMD_DEVICE_ID, CMD_DEVICE_STATUS,
                                  CMD_HW_STATUS, CMD_INDIRECT_STATUS, CMD_INDIRECT_FIFO_STATUS
                                }) && readonly_err_det_en_i;

          unsupported_err     = (((cmd_cmd > CMD_INDIRECT_FIFO_DATA) || (cmd_cmd < CMD_PROT_CAP)) ||
                                 (~recovery_mode_csr_active_i && (cmd_cmd > CMD_RECOVERY_STATUS)))
                                && unsupported_err_det_en_i;

          csr_length_err      = !cmd_is_rd && (cmd_cmd != CMD_INDIRECT_FIFO_DATA) &&
                                (cmd_len != csr_length_next) && length_err_det_en_i;
          
          if (pec_err || readonly_err || unsupported_err || csr_length_err)
            state_d = Error;
          else if (!cmd_is_rd) begin
            // WRITE command - proceed to execution immediately
            state_d = (cmd_cmd == CMD_INDIRECT_FIFO_DATA) ? ExecFifoWrite : ExecCsrWrite;
          end else begin
            // READ command - go to TxDesc immediately to queue descriptor
            // This prepares the target FSM to ACK the upcoming Sr + Addr+R
            state_d = TxDesc;
          end
        end

        //------------------------------------------------------------------------
        // ExecCsrWrite: Write received data to target CSR
        // NOTE: No bus_stop/bus_rstart checks needed - the I3C WRITE transaction
        // is complete. We are writing buffered data from the RX queue to CSRs.
        //------------------------------------------------------------------------
        ExecCsrWrite: begin
          if (tti_rx_rack_i) inc_csr_sel = 1'b1;
          if (tti_rx_rack_i && (dcnt == 1)) state_d = Done;
        end

        //------------------------------------------------------------------------
        // ExecFifoWrite: Stream firmware data to indirect FIFO
        // NOTE: No bus_stop/bus_rstart checks needed - the I3C WRITE transaction
        // is complete. We are streaming buffered data from the RX queue to FIFO.
        //------------------------------------------------------------------------
        ExecFifoWrite: begin
          // Check for FIFO overflow - transition to Error if masked error active
          if (tti_rx_rack_i && !indirect_rx_wready_i && indirect_fifo_overflow_err_det_en_i) begin
            indirect_fifo_overflow_err = 1'b1;
            state_d = Error;
          end else if ((tti_rx_rack_i && (dcnt == 1)) ||
              (bypass_i3c_core_i && hwif_socmgmt_i.REC_INTF_CFG.REC_PAYLOAD_DONE.value && 
               ~indirect_rx_empty_i)) begin
            state_d = Done;
          end
        end

        //------------------------------------------------------------------------
        // TxDesc: Send TX descriptor and wait for Sr + Addr+R
        // The descriptor is queued so target FSM will ACK the read address.
        // Detect protocol errors: STOP, Sr to other target, Sr + Addr+W
        //------------------------------------------------------------------------
        TxDesc: begin
          tx_pec_soft_rst_n_o = 1'b1; 

          if (bus_stop_i || other_target_start_i || (virtual_target_start_i && !bus_addr_i[0])) begin
            // Protocol errors:
            // - STOP instead of Sr (incomplete read transaction)
            // - Sr + Addr to different target (abandoned our transaction)
            // - Sr + Addr+W (expected read but got write)
            unsupported_err = unsupported_err_det_en_i;
            state_d         = Error;
          end else if (tx_desc_ready_i) begin
            state_d = TxLenL;
            tx_pec_enable_o     = 1'b1;
            tx_pec_init_o       = 1'b1;
          end
        end

        //------------------------------------------------------------------------
        // TxLenL: Send response length LSB
        //------------------------------------------------------------------------
        TxLenL: begin
          tx_pec_soft_rst_n_o = 1'b1; 

          if (bus_rstart_i) begin        
            state_d = Done;  // Controller aborted read via Sr
          end else if (tx_data_ready_i) begin
            state_d = TxLenH;
            tx_pec_enable_o = 1'b1;
          end
        end

        //------------------------------------------------------------------------
        // TxLenH: Send response length MSB
        //------------------------------------------------------------------------
        TxLenH: begin
          tx_pec_soft_rst_n_o = 1'b1; 

          if (bus_rstart_i) begin
            state_d = Done;  // Controller aborted read via Sr
          end else if (tx_data_ready_i) begin
            state_d = TxData;
            tx_pec_enable_o = 1'b1;
          end
        end

        //------------------------------------------------------------------------
        // TxData: Send CSR data bytes
        //------------------------------------------------------------------------
        TxData: begin
          tx_pec_soft_rst_n_o = 1'b1; 

          if (bus_rstart_i) begin
            state_d = Done;  // Controller aborted read via Sr
          end else if (tx_data_ready_i) begin
            tx_pec_enable_o = 1'b1;

            if (tx_data_valid_o) begin
              if(bcnt == 3) begin
                inc_csr_sel = 1'b1;
              end

              if(dcnt == 1) begin
                state_d = TxPec;
              end
            end
          end
        end

        //------------------------------------------------------------------------
        // TxPec: Send PEC byte
        //------------------------------------------------------------------------
        TxPec: begin
          tx_pec_soft_rst_n_o = 1'b1; 

          if ((tx_data_ready_i && tx_data_valid_o) || bus_rstart_i) begin 
            state_d = Done;
          end
        end

        //------------------------------------------------------------------------
        // Error: Stay until bus transaction completes to drain remaining bytes
        //------------------------------------------------------------------------
        Error: begin
          // Wait for the I3C bus transaction to end before proceeding to Done.
          // This ensures we drain all incoming bytes during the error condition.
          // Converters are reset via conv_soft_reset_o which is asserted in Error.
          // Exit on Stop, any Start (S or Sr), HDR mode, or if we entered due to
          // premature stop (premature_stop_q is set since the stop pulse already occurred).
          if (bus_stop_i || bus_any_start_i || premature_stop_q || in_hdr_mode_i)
            state_d = Done;
          // else stay in Error, continue accepting and discarding bytes
        end

        //------------------------------------------------------------------------
        // Done/Default: Terminal states
        //------------------------------------------------------------------------
        Done:    state_d = Idle;
        default: state_d = Idle;
      endcase
    end
  end

  //============================================================================
  //
  // SECTION 5: RX PATH LOGIC
  //
  //============================================================================

  //----------------------------------------------------------------------------
  // RX Data Ready Control
  //----------------------------------------------------------------------------
  // Ready to receive during all RX states AND during Error (to drain bus).
  // During Error, bytes are accepted but discarded via converter soft reset.
  assign rx_data_ready_o = state_q inside {RxCmd, RxLenL, RxLenH, RxData, RxPec, Error};

  // Assert soft reset to width converters during Error state (combinational for immediate effect)
  assign conv_soft_reset_o = (state_q == Error);

  //============================================================================
  //
  // SECTION 6: COMMAND HEADER CAPTURE
  //
  //============================================================================

  //----------------------------------------------------------------------------
  // Command Byte
  //----------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cmd_cmd <= command_e'('0);
    end else if (capture_cmd) begin
      cmd_cmd <= command_e'(rx_data_i);
    end
  end

  //----------------------------------------------------------------------------
  // Length Bytes
  //----------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      len_lsb <= '0;
    end else if (latch_pec_from_len) begin
      len_lsb <= '0;
    end else if (capture_len_lsb) begin
      len_lsb <= rx_data_i;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      len_msb <= '0;
    end else if (latch_pec_from_len) begin
      len_msb <= '0;
    end else if (capture_len_msb) begin
      len_msb <= rx_data_i;
    end
  end

  //----------------------------------------------------------------------------
  // Command Type (READ/WRITE)
  //----------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cmd_is_rd <= 1'b0;
    end else if (state_q == Idle) begin
      cmd_is_rd <= 1'b0;
    end else if (set_cmd_is_rd) begin
      cmd_is_rd <= 1'b1;
    end
  end

  //============================================================================
  //
  // SECTION 7: COUNTERS
  //
  //============================================================================

  //----------------------------------------------------------------------------
  // Data Word Counter (dcnt)
  //----------------------------------------------------------------------------
  always_comb begin
    dcnt_next = dcnt;
    unique case (state_q)
      Idle: begin
        dcnt_next = '0;
      end
      CmdDispatch: begin
        dcnt_next = (|payload_byte_cnt[1:0]) ? 
                    16'(payload_byte_cnt / 4 + 1) : 
                    16'(payload_byte_cnt / 4);
      end
      ExecCsrWrite, ExecFifoWrite: begin
        dcnt_next = tti_rx_rack_i ? (dcnt - 16'h1) : dcnt;
      end
      TxDesc: begin
        dcnt_next = csr_length;
      end
      TxData: begin
        dcnt_next = (tx_data_valid_o && tx_data_ready_i) ? 
                    (dcnt - 16'h1) : dcnt;
      end
      default: begin
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dcnt <= '0;
    end else begin
      dcnt <= dcnt_next;
    end
  end

  //----------------------------------------------------------------------------
  // Byte Counter (bcnt)
  //----------------------------------------------------------------------------
  always_comb begin
    bcnt_next = bcnt;
    unique case (state_q)
      Idle: begin
        bcnt_next = '0;
      end
      TxData: begin
        bcnt_next = (tx_data_valid_o && tx_data_ready_i) ? (bcnt + 2'h1) : bcnt;
      end
      default: begin
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      bcnt <= '0;
    end else begin
      bcnt <= bcnt_next;
    end
  end

  //----------------------------------------------------------------------------
  // Payload Byte Counter
  //----------------------------------------------------------------------------
  always_comb begin
    payload_byte_cnt_next = payload_byte_cnt;
    unique case (state_q)
      Idle, RxCmd, RxLenL, RxLenH: begin
        payload_byte_cnt_next = '0;
      end
      RxData: begin
        payload_byte_cnt_next = rx_data_queue_flow_i ? 
                                (payload_byte_cnt + 16'h1) : payload_byte_cnt;
      end
      default: begin
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      payload_byte_cnt <= '0;
    end else begin
      payload_byte_cnt <= payload_byte_cnt_next;
    end
  end

  //----------------------------------------------------------------------------
  // PEC Byte Counter
  //----------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pec_rx_byte_cnt <= '0;
    end else if (state_q != RxPec) begin
      pec_rx_byte_cnt <= '0;
    end else if (rx_flow) begin
      pec_rx_byte_cnt <= pec_rx_byte_cnt + 2'h1;
    end
  end

  //============================================================================
  //
  // SECTION 8: PEC VALIDATION
  //
  //============================================================================

  //----------------------------------------------------------------------------
  // PEC Receive Capture
  //----------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pec_recv <= '0;
    end else if (latch_pec_from_len) begin
      pec_recv <= len_lsb;
    end else if (capture_pec) begin
      pec_recv <= rx_data_i;
    end
  end

  //----------------------------------------------------------------------------
  // PEC Calculated Value
  //----------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pec_calc <= '0;
    end else if (state_q == RxLenL && rx_flow) begin
      pec_calc <= pec_crc_i;
    end else if (state_q == RxPec && rx_flow) begin
      pec_calc <= pec_crc_i;
    end
  end

  //============================================================================
  //
  // SECTION 9: TX PATH LOGIC
  //
  //============================================================================

  //----------------------------------------------------------------------------
  // TX Descriptor
  //----------------------------------------------------------------------------
  assign tx_desc_valid_o = (state_q == TxDesc);
  assign tx_desc_data_o  = {{(TtiTxDescDataWidth-16){1'b0}}, csr_length + 16'd3};

  //----------------------------------------------------------------------------
  // TX Data Valid
  //----------------------------------------------------------------------------
  assign tx_data_valid_o = state_q inside {TxLenL, TxLenH, TxData, TxPec};

  //----------------------------------------------------------------------------
  // TX Data Mux
  //----------------------------------------------------------------------------
  always_comb begin
    tx_data_o = '0;
    unique case (state_q)
      TxLenL: begin
        tx_data_o = csr_length[7:0];
      end
      TxLenH: begin
        tx_data_o = csr_length[15:8];
      end
      TxPec: begin
        tx_data_o = tx_pec_crc_i;
      end
      TxData: begin
        unique case (bcnt)
          2'd0: begin
            tx_data_o = csr_data[7:0];
          end
          2'd1: begin
            tx_data_o = csr_data[15:8];
          end
          2'd2: begin
            tx_data_o = csr_data[23:16];
          end
          2'd3: begin
            tx_data_o = csr_data[31:24];
          end
          default: begin
          end
        endcase
      end
      default: begin
      end
    endcase
  end

  //============================================================================
  //
  // SECTION 10: CSR SELECTOR LOGIC
  //
  //============================================================================

  //----------------------------------------------------------------------------
  // CSR Selector Decode
  //----------------------------------------------------------------------------
  always_comb begin
    csr_sel_next = CSR_INVALID;
    csr_end_next = CSR_INVALID;
    
    unique case (cmd_cmd)
      CMD_PROT_CAP: begin
        csr_sel_next = CSR_PROT_CAP_0;
        csr_end_next = CSR_PROT_CAP_3;
      end
      CMD_DEVICE_ID: begin
        csr_sel_next = CSR_DEVICE_ID_0;
        csr_end_next = CSR_DEVICE_ID_5;
      end
      CMD_DEVICE_STATUS: begin
        csr_sel_next = CSR_DEVICE_STATUS_0;
        csr_end_next = CSR_DEVICE_STATUS_1;
      end
      CMD_DEVICE_RESET: begin
        csr_sel_next = CSR_DEVICE_RESET;
        csr_end_next = CSR_DEVICE_RESET;
      end
      CMD_RECOVERY_CTRL: begin
        csr_sel_next = CSR_RECOVERY_CTRL;
        csr_end_next = CSR_RECOVERY_CTRL;
      end
      CMD_RECOVERY_STATUS: begin
        csr_sel_next = CSR_RECOVERY_STATUS;
        csr_end_next = CSR_RECOVERY_STATUS;
      end
      CMD_HW_STATUS: begin
        csr_sel_next = CSR_HW_STATUS;
        csr_end_next = CSR_HW_STATUS;
      end
      CMD_INDIRECT_FIFO_CTRL: begin
        csr_sel_next = CSR_INDIRECT_FIFO_CTRL_0;
        csr_end_next = CSR_INDIRECT_FIFO_CTRL_1;
      end
      CMD_INDIRECT_FIFO_STATUS: begin
        csr_sel_next = CSR_INDIRECT_FIFO_STATUS_0;
        csr_end_next = CSR_INDIRECT_FIFO_STATUS_4;
      end
      CMD_INDIRECT_FIFO_DATA: begin
        csr_sel_next = CSR_INDIRECT_FIFO_DATA;
        csr_end_next = CSR_INDIRECT_FIFO_DATA;
      end
      default: begin
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      csr_sel <= CSR_INVALID;
      csr_end <= CSR_INVALID;
      load_csr_data <= '0;
    end else if (load_csr_sel) begin
      csr_sel <= csr_sel_next;
      csr_end <= csr_end_next;
      load_csr_data <= 1'b1;
    end else if (inc_csr_sel && (csr_sel < csr_end)) begin
      csr_sel <= csr_e'(csr_sel + 8'd1);
      load_csr_data <= 1'b1;
    end else begin
      load_csr_data <= '0;
    end
  end

  //----------------------------------------------------------------------------
  // CSR Length Decode
  //----------------------------------------------------------------------------
  always_comb begin
    csr_length_next = 16'd4;
    unique case (cmd_cmd)
      CMD_PROT_CAP: begin
        csr_length_next = 16'd15;
      end
      CMD_DEVICE_ID: begin
        csr_length_next = 16'd24;
      end
      CMD_DEVICE_STATUS: begin
        csr_length_next = 16'd7;
      end
      CMD_DEVICE_RESET: begin
        csr_length_next = 16'd3;
      end
      CMD_RECOVERY_CTRL: begin
        csr_length_next = 16'd3;
      end
      CMD_RECOVERY_STATUS: begin
        csr_length_next = 16'd2;
      end
      CMD_HW_STATUS: begin
        csr_length_next = 16'd4;
      end
      CMD_INDIRECT_FIFO_CTRL: begin
        csr_length_next = 16'd6;
      end
      CMD_INDIRECT_FIFO_STATUS: begin
        csr_length_next = 16'd20;
      end
      default: begin
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      csr_length <= '0;
    end else if (load_csr_length) begin
      csr_length <= csr_length_next;
    end
  end

  //----------------------------------------------------------------------------
  // CSR Writeable Flag
  //----------------------------------------------------------------------------
  assign csr_writable = csr_sel inside {CSR_DEVICE_RESET, CSR_RECOVERY_CTRL,CSR_INDIRECT_FIFO_CTRL_0, CSR_INDIRECT_FIFO_CTRL_1};

  //============================================================================
  //
  // SECTION 11: CSR READ DATA
  //
  //============================================================================

  //----------------------------------------------------------------------------
  // Composite CSR Values
  //----------------------------------------------------------------------------
  assign prot_cap_2 = {
    hwif_rec_i.PROT_CAP_2.AGENT_CAPS.value,
    hwif_rec_i.PROT_CAP_2.REC_PROT_VERSION.value
  };

  assign prot_cap_3 = {
    '0,
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
    '0,
    hwif_rec_i.DEVICE_RESET.IF_CTRL.value,
    hwif_rec_i.DEVICE_RESET.FORCED_RECOVERY.value,
    hwif_rec_i.DEVICE_RESET.RESET_CTRL.value
  };

  assign recovery_ctrl = {
    '0,
    hwif_rec_i.RECOVERY_CTRL.ACTIVATE_REC_IMG.value,
    hwif_rec_i.RECOVERY_CTRL.REC_IMG_SEL.value,
    hwif_rec_i.RECOVERY_CTRL.CMS.value
  };

  assign recovery_status = {
    '0,
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
    '0,
    hwif_rec_i.INDIRECT_FIFO_CTRL_1.IMAGE_SIZE.value[31:16]
  };

  assign indirect_fifo_status_0 = {
    '0,
    hwif_rec_i.INDIRECT_FIFO_STATUS_0.REGION_TYPE.value,
    6'd0,
    hwif_rec_i.INDIRECT_FIFO_STATUS_0.FULL.value,
    hwif_rec_i.INDIRECT_FIFO_STATUS_0.EMPTY.value
  };

  //----------------------------------------------------------------------------
  // CSR Data Mux
  //----------------------------------------------------------------------------
  always_comb begin
    csr_data_next = '0;
    unique case (csr_sel)
      CSR_PROT_CAP_0: begin
        csr_data_next = hwif_rec_i.PROT_CAP_0.REC_MAGIC_STRING_0.value;
      end
      CSR_PROT_CAP_1: begin
        csr_data_next = hwif_rec_i.PROT_CAP_1.REC_MAGIC_STRING_1.value;
      end
      CSR_PROT_CAP_2: begin
        csr_data_next = prot_cap_2;
      end
      CSR_PROT_CAP_3: begin
        csr_data_next = prot_cap_3;
      end
      CSR_DEVICE_ID_0: begin
        csr_data_next = device_id_0;
      end
      CSR_DEVICE_ID_1: begin
        csr_data_next = hwif_rec_i.DEVICE_ID_1.DATA.value;
      end
      CSR_DEVICE_ID_2: begin
        csr_data_next = hwif_rec_i.DEVICE_ID_2.DATA.value;
      end
      CSR_DEVICE_ID_3: begin
        csr_data_next = hwif_rec_i.DEVICE_ID_3.DATA.value;
      end
      CSR_DEVICE_ID_4: begin
        csr_data_next = hwif_rec_i.DEVICE_ID_4.DATA.value;
      end
      CSR_DEVICE_ID_5: begin
        csr_data_next = hwif_rec_i.DEVICE_ID_5.DATA.value;
      end
      CSR_DEVICE_STATUS_0: begin
        csr_data_next = device_status_0;
      end
      CSR_DEVICE_STATUS_1: begin
        csr_data_next = device_status_1;
      end
      CSR_DEVICE_RESET: begin
        csr_data_next = device_reset;
      end
      CSR_RECOVERY_CTRL: begin
        csr_data_next = recovery_ctrl;
      end
      CSR_RECOVERY_STATUS: begin
        csr_data_next = recovery_status;
      end
      CSR_HW_STATUS: begin
        csr_data_next = hw_status;
      end
      CSR_INDIRECT_FIFO_CTRL_0: begin
        csr_data_next = indirect_fifo_ctrl_0;
      end
      CSR_INDIRECT_FIFO_CTRL_1: begin
        csr_data_next = indirect_fifo_ctrl_1;
      end
      CSR_INDIRECT_FIFO_STATUS_0: begin
        csr_data_next = indirect_fifo_status_0;
      end
      CSR_INDIRECT_FIFO_STATUS_1: begin
        csr_data_next = hwif_rec_i.INDIRECT_FIFO_STATUS_1.WRITE_INDEX.value;
      end
      CSR_INDIRECT_FIFO_STATUS_2: begin
        csr_data_next = hwif_rec_i.INDIRECT_FIFO_STATUS_2.READ_INDEX.value;
      end
      CSR_INDIRECT_FIFO_STATUS_3: begin
        csr_data_next = hwif_rec_i.INDIRECT_FIFO_STATUS_3.FIFO_SIZE.value;
      end
      CSR_INDIRECT_FIFO_STATUS_4: begin
        csr_data_next = hwif_rec_i.INDIRECT_FIFO_STATUS_4.MAX_TRANSFER_SIZE.value;
      end
      default: begin
      end
    endcase
  end

  // Capture csr_data one cycle after csr_sel settles to ensure
  // csr_data_next (driven by case(csr_sel)) sees the correct selector.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      csr_data <= '0;
    end else if (load_csr_data) begin
      csr_data <= csr_data_next;
    end
  end

  //============================================================================
  //
  // SECTION 12: CSR WRITE PATH
  //
  //============================================================================

  //----------------------------------------------------------------------------
  // TTI RX Request
  // Deassert for one cycle after rack to allow dcnt to update (prevent underflow)
  //----------------------------------------------------------------------------
  assign tti_rx_rreq_o = (state_q inside {ExecCsrWrite, ExecFifoWrite}) && 
                         (dcnt != 0) && !tti_rx_rack_i;

  //----------------------------------------------------------------------------
  // Previous RX Data (for multi-word writes)
  //----------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      prev_tti_rx_rdata <= '0;
    end else if (tti_rx_rack_i) begin
      prev_tti_rx_rdata <= tti_rx_rdata_i;
    end
  end

  //----------------------------------------------------------------------------
  // CSR Write Enable Signals
  //----------------------------------------------------------------------------
  assign device_reset_we         = tti_rx_rack_i && (csr_sel == CSR_DEVICE_RESET);
  assign indirect_fifo_ctrl_0_we = tti_rx_rack_i && (csr_sel == CSR_INDIRECT_FIFO_CTRL_0);
  assign recovery_ctrl_we        = tti_rx_rack_i && (csr_sel == CSR_RECOVERY_CTRL);

  //============================================================================
  //
  // SECTION 13: INDIRECT FIFO LOGIC
  //
  //============================================================================

  //----------------------------------------------------------------------------
  // FIFO Write Interface
  //----------------------------------------------------------------------------
  always_comb begin
    // Only write to FIFO if not full - reject writes when full
    indirect_rx_wvalid_o = (state_q == ExecFifoWrite) && tti_rx_rack_i && indirect_rx_wready_i;
    indirect_rx_wdata_o  = tti_rx_rdata_i;
  end

  //----------------------------------------------------------------------------
  // FIFO Pointer Management
  //----------------------------------------------------------------------------
  assign fifo_size      = hwif_rec_i.INDIRECT_FIFO_STATUS_3.FIFO_SIZE.value;
  assign fifo_wrptr     = hwif_rec_i.INDIRECT_FIFO_STATUS_1.WRITE_INDEX.value;
  assign fifo_rdptr     = hwif_rec_i.INDIRECT_FIFO_STATUS_2.READ_INDEX.value;
  // Only increment write pointer if FIFO is not full - reject overflow writes
  assign fifo_wrptr_inc = indirect_rx_wvalid_o;
  assign fifo_rdptr_inc = indirect_rx_rack_i;
  assign fifo_ptr_clr   = (hwif_rec_i.INDIRECT_FIFO_CTRL_0.RESET.value == 8'd1);
  assign indirect_rx_clr_o = fifo_ptr_clr;

  //----------------------------------------------------------------------------
  // FIFO Reset Self-Clear
  //----------------------------------------------------------------------------
  assign hwif_rec_o.INDIRECT_FIFO_CTRL_0.RESET.hwclr = |hwif_rec_i.INDIRECT_FIFO_CTRL_0.RESET.value;

  //----------------------------------------------------------------------------
  // FIFO Read Port - synthetic ack when empty to reject reads immediately
  //----------------------------------------------------------------------------
  always_comb begin
    indirect_rx_rreq_o = hwif_rec_i.INDIRECT_FIFO_DATA.req && 
                         !hwif_rec_i.INDIRECT_FIFO_DATA.req_is_wr &&
                         !indirect_rx_empty_i;
    
    hwif_rec_o.INDIRECT_FIFO_DATA.rd_ack = indirect_rx_rack_i || 
                                            (indirect_rx_empty_i && 
                                             hwif_rec_i.INDIRECT_FIFO_DATA.req && 
                                             !hwif_rec_i.INDIRECT_FIFO_DATA.req_is_wr);
    
    hwif_rec_o.INDIRECT_FIFO_DATA.rd_data = indirect_rx_rdata_i;
  end

  //============================================================================
  //
  // SECTION 14: RECOVERY CSR INTERFACE
  //
  //============================================================================

  //----------------------------------------------------------------------------
  // Bypass Mode W1C Handling
  //----------------------------------------------------------------------------
  always_comb begin
    sw_device_reset_ctrl_value            = hwif_socmgmt_i.REC_INTF_REG_W1C_ACCESS.DEVICE_RESET_CTRL.value;
    sw_recovery_ctrl_activate_rec_img_value = hwif_socmgmt_i.REC_INTF_REG_W1C_ACCESS.RECOVERY_CTRL_ACTIVATE_REC_IMG.value;
    sw_indirect_fifo_ctrl_reset_value     = hwif_socmgmt_i.REC_INTF_REG_W1C_ACCESS.INDIRECT_FIFO_CTRL_RESET.value;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sw_device_reset_ctrl_swmod            <= 1'b0;
      sw_recovery_ctrl_activate_rec_img_swmod <= 1'b0;
      sw_indirect_fifo_ctrl_reset_swmod     <= 1'b0;
    end else begin
      sw_device_reset_ctrl_swmod            <= hwif_socmgmt_i.REC_INTF_REG_W1C_ACCESS.DEVICE_RESET_CTRL.swmod;
      sw_recovery_ctrl_activate_rec_img_swmod <= hwif_socmgmt_i.REC_INTF_REG_W1C_ACCESS.RECOVERY_CTRL_ACTIVATE_REC_IMG.swmod;
      sw_indirect_fifo_ctrl_reset_swmod     <= hwif_socmgmt_i.REC_INTF_REG_W1C_ACCESS.INDIRECT_FIFO_CTRL_RESET.swmod;
    end
  end

  always_comb begin : clear_bypassed_regs
    hwif_socmgmt_o.REC_INTF_REG_W1C_ACCESS.DEVICE_RESET_CTRL.we               = sw_device_reset_ctrl_swmod;
    hwif_socmgmt_o.REC_INTF_REG_W1C_ACCESS.DEVICE_RESET_CTRL.next             = '0;
    hwif_socmgmt_o.REC_INTF_REG_W1C_ACCESS.RECOVERY_CTRL_ACTIVATE_REC_IMG.we  = sw_recovery_ctrl_activate_rec_img_swmod;
    hwif_socmgmt_o.REC_INTF_REG_W1C_ACCESS.RECOVERY_CTRL_ACTIVATE_REC_IMG.next= '0;
    hwif_socmgmt_o.REC_INTF_REG_W1C_ACCESS.INDIRECT_FIFO_CTRL_RESET.we        = sw_indirect_fifo_ctrl_reset_swmod;
    hwif_socmgmt_o.REC_INTF_REG_W1C_ACCESS.INDIRECT_FIFO_CTRL_RESET.next      = '0;
  end

  //----------------------------------------------------------------------------
  // CSR Write Enables
  //----------------------------------------------------------------------------
  always_comb begin
    // Read-only registers - no write enable
    hwif_rec_o.PROT_CAP_2.REC_PROT_VERSION.we         = '0;
    hwif_rec_o.PROT_CAP_2.AGENT_CAPS.we               = '0;
    hwif_rec_o.PROT_CAP_3.NUM_OF_CMS_REGIONS.we       = '0;
    hwif_rec_o.PROT_CAP_3.MAX_RESP_TIME.we            = '0;
    hwif_rec_o.PROT_CAP_3.HEARTBEAT_PERIOD.we         = '0;
    hwif_rec_o.DEVICE_ID_0.DESC_TYPE.we               = '0;
    hwif_rec_o.DEVICE_ID_0.VENDOR_SPECIFIC_STR_LENGTH.we = '0;
    hwif_rec_o.DEVICE_ID_0.DATA.we                    = '0;
    hwif_rec_o.DEVICE_ID_1.DATA.we                    = '0;
    hwif_rec_o.DEVICE_ID_2.DATA.we                    = '0;
    hwif_rec_o.DEVICE_ID_3.DATA.we                    = '0;
    hwif_rec_o.DEVICE_ID_4.DATA.we                    = '0;
    hwif_rec_o.DEVICE_ID_5.DATA.we                    = '0;
    hwif_rec_o.DEVICE_STATUS_1.HEARTBEAT.we           = '0;
    hwif_rec_o.DEVICE_STATUS_1.VENDOR_STATUS_LENGTH.we = '0;
    hwif_rec_o.DEVICE_STATUS_1.VENDOR_STATUS.we       = '0;
    hwif_rec_o.RECOVERY_STATUS.DEV_REC_STATUS.we      = '0;
    hwif_rec_o.RECOVERY_STATUS.REC_IMG_INDEX.we       = '0;
    hwif_rec_o.RECOVERY_STATUS.VENDOR_SPECIFIC_STATUS.we = '0;
    hwif_rec_o.HW_STATUS.TEMP_CRITICAL.we             = '0;
    hwif_rec_o.HW_STATUS.SOFT_ERR.we                  = '0;
    hwif_rec_o.HW_STATUS.FATAL_ERR.we                 = '0;
    hwif_rec_o.HW_STATUS.RESERVED_7_3.we              = '0;
    hwif_rec_o.HW_STATUS.VENDOR_HW_STATUS.we          = '0;
    hwif_rec_o.HW_STATUS.CTEMP.we                     = '0;
    hwif_rec_o.HW_STATUS.VENDOR_HW_STATUS_LEN.we      = '0;
    hwif_rec_o.INDIRECT_FIFO_STATUS_0.REGION_TYPE.we  = '0;
    hwif_rec_o.INDIRECT_FIFO_RESERVED.DATA.we         = '0;

    // Writable registers
    hwif_rec_o.DEVICE_RESET.RESET_CTRL.we     = bypass_i3c_core_i ? sw_device_reset_ctrl_swmod : device_reset_we;
    hwif_rec_o.DEVICE_RESET.FORCED_RECOVERY.we = device_reset_we;
    hwif_rec_o.DEVICE_RESET.IF_CTRL.we        = device_reset_we;
    hwif_rec_o.RECOVERY_CTRL.ACTIVATE_REC_IMG.we = bypass_i3c_core_i ? sw_recovery_ctrl_activate_rec_img_swmod : recovery_ctrl_we;
    hwif_rec_o.RECOVERY_CTRL.REC_IMG_SEL.we   = recovery_ctrl_we;
    hwif_rec_o.RECOVERY_CTRL.CMS.we           = recovery_ctrl_we;
    hwif_rec_o.INDIRECT_FIFO_CTRL_0.RESET.we  = bypass_i3c_core_i ? sw_indirect_fifo_ctrl_reset_swmod : indirect_fifo_ctrl_0_we;
    hwif_rec_o.INDIRECT_FIFO_CTRL_0.CMS.we    = indirect_fifo_ctrl_0_we;
    hwif_rec_o.INDIRECT_FIFO_CTRL_1.IMAGE_SIZE.we = tti_rx_rack_i && (csr_sel == CSR_INDIRECT_FIFO_CTRL_1);
  end

  //----------------------------------------------------------------------------
  // CSR Write Values
  //----------------------------------------------------------------------------
  always_comb begin
    hwif_rec_o.DEVICE_RESET.RESET_CTRL.next     = bypass_i3c_core_i ? sw_device_reset_ctrl_value : tti_rx_rdata_i[7:0];
    hwif_rec_o.DEVICE_RESET.FORCED_RECOVERY.next = tti_rx_rdata_i[15:8];
    hwif_rec_o.DEVICE_RESET.IF_CTRL.next        = tti_rx_rdata_i[23:16];
    hwif_rec_o.RECOVERY_CTRL.ACTIVATE_REC_IMG.next = bypass_i3c_core_i ? sw_recovery_ctrl_activate_rec_img_value : tti_rx_rdata_i[23:16];
    hwif_rec_o.RECOVERY_CTRL.REC_IMG_SEL.next   = tti_rx_rdata_i[15:8];
    hwif_rec_o.RECOVERY_CTRL.CMS.next           = tti_rx_rdata_i[7:0];
    hwif_rec_o.INDIRECT_FIFO_CTRL_0.RESET.next  = bypass_i3c_core_i ? sw_indirect_fifo_ctrl_reset_value : tti_rx_rdata_i[15:8];
    hwif_rec_o.INDIRECT_FIFO_CTRL_0.CMS.next    = tti_rx_rdata_i[7:0];
    hwif_rec_o.INDIRECT_FIFO_CTRL_1.IMAGE_SIZE.next = {tti_rx_rdata_i[15:0], prev_tti_rx_rdata[31:16]};
  end

  //----------------------------------------------------------------------------
  // CSR Unused Next Values
  //----------------------------------------------------------------------------
  always_comb begin
    hwif_rec_o.PROT_CAP_3.NUM_OF_CMS_REGIONS.next     = '0;
    hwif_rec_o.PROT_CAP_3.MAX_RESP_TIME.next          = '0;
    hwif_rec_o.PROT_CAP_3.HEARTBEAT_PERIOD.next       = '0;
    hwif_rec_o.PROT_CAP_2.REC_PROT_VERSION.next       = '0;
    hwif_rec_o.PROT_CAP_2.AGENT_CAPS.next             = '0;
    hwif_rec_o.HW_STATUS.TEMP_CRITICAL.next           = '0;
    hwif_rec_o.HW_STATUS.SOFT_ERR.next                = '0;
    hwif_rec_o.HW_STATUS.FATAL_ERR.next               = '0;
    hwif_rec_o.HW_STATUS.RESERVED_7_3.next            = '0;
    hwif_rec_o.HW_STATUS.VENDOR_HW_STATUS.next        = '0;
    hwif_rec_o.HW_STATUS.CTEMP.next                   = '0;
    hwif_rec_o.HW_STATUS.VENDOR_HW_STATUS_LEN.next    = '0;
    hwif_rec_o.DEVICE_STATUS_1.HEARTBEAT.next         = '0;
    hwif_rec_o.DEVICE_STATUS_1.VENDOR_STATUS_LENGTH.next = '0;
    hwif_rec_o.DEVICE_STATUS_1.VENDOR_STATUS.next     = '0;
    hwif_rec_o.RECOVERY_STATUS.DEV_REC_STATUS.next    = '0;
    hwif_rec_o.RECOVERY_STATUS.REC_IMG_INDEX.next     = '0;
    hwif_rec_o.RECOVERY_STATUS.VENDOR_SPECIFIC_STATUS.next = '0;
    hwif_rec_o.INDIRECT_FIFO_STATUS_0.REGION_TYPE.next = '0;
    hwif_rec_o.INDIRECT_FIFO_RESERVED.DATA.next       = '0;
    hwif_rec_o.DEVICE_ID_1.DATA.next                  = '0;
    hwif_rec_o.DEVICE_ID_2.DATA.next                  = '0;
    hwif_rec_o.DEVICE_ID_3.DATA.next                  = '0;
    hwif_rec_o.DEVICE_ID_4.DATA.next                  = '0;
    hwif_rec_o.DEVICE_ID_5.DATA.next                  = '0;
    hwif_rec_o.DEVICE_ID_0.DESC_TYPE.next             = '0;
    hwif_rec_o.DEVICE_ID_0.VENDOR_SPECIFIC_STR_LENGTH.next = '0;
    hwif_rec_o.DEVICE_ID_0.DATA.next                  = '0;
  end

  //----------------------------------------------------------------------------
  // FIFO Status Updates
  //----------------------------------------------------------------------------
  always_comb begin
    hwif_rec_o.INDIRECT_FIFO_STATUS_0.EMPTY.next = indirect_rx_empty_i;
    hwif_rec_o.INDIRECT_FIFO_STATUS_0.FULL.next  = indirect_rx_full_i;
  end

  //----------------------------------------------------------------------------
  // FIFO Size
  //----------------------------------------------------------------------------
  always_comb begin
    hwif_rec_o.INDIRECT_FIFO_STATUS_3.FIFO_SIZE.next = IndirectFifoDepth;
  end

  //----------------------------------------------------------------------------
  // FIFO Pointer Updates
  //----------------------------------------------------------------------------
  assign hwif_rec_o.INDIRECT_FIFO_STATUS_1.WRITE_INDEX.we = fifo_wrptr_inc || fifo_ptr_clr;
  assign hwif_rec_o.INDIRECT_FIFO_STATUS_2.READ_INDEX.we  = fifo_rdptr_inc || fifo_ptr_clr;

  always_comb begin
    hwif_rec_o.INDIRECT_FIFO_STATUS_1.WRITE_INDEX.next = fifo_ptr_clr ? '0 :
      ((fifo_wrptr == (fifo_size - 32'h1)) ? '0 : (fifo_wrptr + 32'h1));
  end

  always_comb begin
    hwif_rec_o.INDIRECT_FIFO_STATUS_2.READ_INDEX.next = fifo_ptr_clr ? '0 :
      ((fifo_rdptr == (fifo_size - 32'h1)) ? '0 : (fifo_rdptr + 32'h1));
  end

  //============================================================================
  //
  // SECTION 15: PROTOCOL STATUS
  //
  //============================================================================

  // OCP spec error priority: CRC > Length > Readonly/Unsupported
  // FIFO overflow errors (RX FIFO and INDIRECT_FIFO) are reported as Length errors
  always_comb begin
    status_protocol = PROTOCOL_OK;
    if (pec_err)
      status_protocol = PROTOCOL_ERROR_CRC;
    else if (length_underrun_err || length_overrun_err || csr_length_err || 
             rx_fifo_overflow_err || indirect_fifo_overflow_err)
      status_protocol = PROTOCOL_ERROR_LENGTH;
    else if (readonly_err || unsupported_err)
      status_protocol = PROTOCOL_ERROR_READONLY;  // OCP: both map to "unsupported command error"
  end

  // Write PROT_ERROR CSR only ONCE per transaction:
  // - On transition INTO Error state (reports the error)
  // - On transition INTO Done state directly (clears to OK, but NOT if coming from Error)
  // This handles:
  // 1. Staying in Error for multiple cycles (only writes on entry)
  // 2. Error -> Done -> Idle (only writes on Error entry, Done doesn't overwrite)
  // 3. Direct Done (writes PROTOCOL_OK to clear any previous error)
  assign entering_error         = (state_q != Error) && (state_d == Error);
  assign entering_done_directly = (state_q != Error) && (state_q != Done) && (state_d == Done);
  assign status_protocol_we     = entering_error || entering_done_directly;

  always_comb begin
    hwif_rec_o.DEVICE_STATUS_0.REC_REASON_CODE.we   = '0;
    hwif_rec_o.DEVICE_STATUS_0.PROT_ERROR.we        = status_protocol_we;
    hwif_rec_o.DEVICE_STATUS_0.DEV_STATUS.we        = '0;
    hwif_rec_o.DEVICE_STATUS_0.REC_REASON_CODE.next = '0;
    hwif_rec_o.DEVICE_STATUS_0.PROT_ERROR.next      = status_protocol;
    hwif_rec_o.DEVICE_STATUS_0.DEV_STATUS.next      = '0;
  end

  //============================================================================
  //
  // SECTION 16: PAYLOAD AND EXECUTION TRACKING
  //
  //============================================================================

  //----------------------------------------------------------------------------
  // Payload Availability
  //----------------------------------------------------------------------------
  assign fifo_xfer_done   = indirect_rx_full_i || (image_activated_o && ~indirect_rx_empty_i);
  assign bypass_xfer_done = (state_q == ExecFifoWrite) && (state_d == Done);
  // In bypass mode: payload available when FIFO full, REC_PAYLOAD_DONE set, or image activated
  // In normal mode: payload available when fifo_xfer_done (full or image activated with data)
  assign payload_high_en  = bypass_i3c_core_i ?
    (indirect_rx_full_i || hwif_socmgmt_i.REC_INTF_CFG.REC_PAYLOAD_DONE.value || image_activated_o) :
    fifo_xfer_done;

  always_comb begin
    hwif_socmgmt_o.REC_INTF_CFG.REC_PAYLOAD_DONE.we   = fifo_xfer_done;
    hwif_socmgmt_o.REC_INTF_CFG.REC_PAYLOAD_DONE.next = 1'b0;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      payload_available_q <= 1'b0;
    end else if (payload_high_en) begin
      payload_available_q <= 1'b1;
    end else if (indirect_rx_empty_i) begin
      payload_available_q <= 1'b0;
    end
  end


  //============================================================================
  //
  // SECTION 17: ERROR OUTPUTS
  //
  //============================================================================

  assign pec_err_o         = pec_err;
  assign length_err_o      = length_underrun_err || length_overrun_err || csr_length_err;
  assign readonly_err_o    = readonly_err;
  assign unsupported_err_o = unsupported_err;
  
  // FIFO overflow error outputs
  // RX FIFO overflow: always reported (not gated by enable)
  assign rx_fifo_overflow_err_o = rx_fifo_overflow_err;
  // INDIRECT_FIFO overflow: reported on each overflow event
  assign indirect_fifo_overflow_err_o = indirect_fifo_overflow_err;

  // rx_desc_wvalid_i must align with rx_data_last_i (both driven by transfer_ended)
  `I3C_ASSERT(RxDescAlignedWithLast_A, rx_data_last_i |-> rx_desc_wvalid_i)

  // rx_desc_wvalid_i must fire on Sr in RxLenH (read-flow write-phase ends here)
  `I3C_ASSERT(RxDescAlignedWithRstart_A, (state_q == RxLenH) && bus_rstart_i |-> rx_desc_wvalid_i)

endmodule

