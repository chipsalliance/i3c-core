// SPDX-License-Identifier: Apache-2.0

/*
  This module handles CCC (Common Command Codes) processing for an I3C Target.

  This FSM is secondary to the target_fsm. The handoff occurs after target_fsm
  detects {S|SR, 7'h7E, W, ACK} and receives the Command Code byte.

  Between I3C bytes, there is a short period when the Target does not know if
  the next symbol will be a Repeated Start or a data bit. This occurs after
  ACK/NACK or T-bit transmission. In the CCC flow, some decisions depend on
  whether the next symbol is SR or data.

  CCCs are categorized as:
  - Retrieve values from CSRs (GET commands)
  - Set values in CSRs (SET commands)

  CCCs without additional data:
    - I3C_BCAST_RSTDAA
    - I3C_BCAST_SETAASA
    - I3C_DIRECT_RSTGRPA
    - I3C_BCAST_ENTAS0-3
    - I3C_DIRECT_ENTAS0-3
    - I3C_BCAST_ENTHDR0-7

  CCCs with 1 additional byte of data:
    - I3C_BCAST_ENEC
    - I3C_BCAST_DISEC
    - I3C_BCAST_ENTTM
    - I3C_BCAST_ENDXFER
    - I3C_BCAST_SETXTIME
    - I3C_BCAST_RSTACT
    - I3C_BCAST_RSTGRPA
    - I3C_DIRECT_ENEC
    - I3C_DIRECT_DISEC
    - I3C_DIRECT_SETDASA
    - I3C_DIRECT_SETNEWDA
    - I3C_DIRECT_GETBCR
    - I3C_DIRECT_GETDCR
    - I3C_DIRECT_GETACCCR
    - I3C_DIRECT_ENDXFER
    - I3C_DIRECT_RSTACT
    - I3C_DIRECT_SETGRPA

  CCCs with 2-6 number of bytes:
    - I3C_BCAST_SETMWL     2
    - I3C_DIRECT_SETMWL    2
    - I3C_DIRECT_GETMWL    2
    - I3C_DIRECT_GETSTATUS 2
    - I3C_BCAST_SETMRL     3
    - I3C_DIRECT_SETMRL    3
    - I3C_DIRECT_GETMRL    3
    - I3C_DIRECT_GETXTIME  4
    - I3C_DIRECT_GETMXDS   5
    - I3C_DIRECT_GETPID    6

  CCCs, which require variable N data bytes:
    - I3C_BCAST_DEFTGTS
    - I3C_DIRECT_GETCAPS
    - I3C_BCAST_DEFGRPA
    - I3C_BCAST_SETBUSCON

  ENTDAA CCC is unique and must be handled separately:
    - I3C_BCAST_ENTDAA

  CCCs not supported:
    - I3C_BCAST_MLANE, I3C_DIRECT_MLANE; multi-lane configuration is not yet supported
    - I3C_DIRECT_SETBRGTGT; this is not a Bridging Device
    - I3C_DIRECT_SETROUTE; this is not a Routing Device
    - I3C_DIRECT_D2DXFER; HDR is not yet supported

  Deprecated CCCs (should detect and NACK):
    - I3C_DIRECT_RSTDAA
*/

module ccc
  import controller_pkg::*;
  import i3c_pkg::*;
(
    input  logic clk_i,  // Clock
    input  logic rst_ni, // Async reset, active low

    // =========================================================================
    // CCC Command Input Interface
    // =========================================================================
    // CCC data is extracted from the frame by the main FSM (target_fsm)
    // The target_fsm detects {S|SR, 7'h7E, W, ACK} and then receives the
    // command code byte before handing off to this module.
    input  ccc_cmd_e ccc_data_i,
    // Level signal giving control to CCC FSM
    input  logic ccc_valid_i,

    // =========================================================================
    // FSM Control Outputs
    // =========================================================================
    // Asserted when CCC processing is complete (on STOP condition)
    output logic done_fsm_o,
    // Asserted when ready to process next CCC in a chained sequence
    output logic next_ccc_o,
  
    // =========================================================================
    // Target Error Signals 
    // =========================================================================
    output logic te0_enable_o,
    input  logic te0_err_i,
    output logic te1_err_o,      // CCC command parity error (TE1)
    output logic te2_err_ccc_o,  // CCC data parity error (TE2)
    output logic te3_err_o,      // ENTDAA PID mismatch (TE3)
    output logic te4_err_o,      // ENTDAA BCR/DCR mismatch (TE4)
    output logic te5_err_o,      // Broadcast/Direct DA mismatch (TE5)
    output logic framing_err_o,  // DA padding errors (for Protocol Error Report)

    // Target Error Detection Enables (from TTI CSR)
    input  logic te0_err_det_en_i,
    input  logic te1_err_det_en_i,
    input  logic te2_err_det_en_i,
    input  logic te3_err_det_en_i,
    input  logic te4_err_det_en_i,
    input  logic te5_err_det_en_i,
    input  logic framing_err_det_en_i,

    // =========================================================================
    // Bus Monitor Interface
    // =========================================================================
    input  logic bus_start_det_i,
    input  logic bus_rstart_det_i,
    input  logic bus_stop_det_i,
    input  logic arbitration_lost_i,

    // =========================================================================
    // Bus Tx/Rx Interface
    // =========================================================================
    // bus_rx_rsp_i.done is asserted on the positive edge of SCL after the
    // stable SDA value has been captured. It indicates that a complete bit
    // or byte has been received and the data in bus_rx_rsp_i.data is valid.
    output bus_tx_req_t bus_tx_req_o,
    input  bus_tx_rsp_t bus_tx_rsp_i,

    output bus_rx_req_t bus_rx_req_o,
    input  bus_rx_rsp_t bus_rx_rsp_i,

    // =========================================================================
    // Address Match Interface
    // =========================================================================
    input logic [6:0] target_sta_address_i,
    input logic target_sta_address_valid_i,
    input logic [6:0] target_dyn_address_i,
    input logic target_dyn_address_valid_i,
    input logic [6:0] virtual_target_sta_address_i,
    input logic virtual_target_sta_address_valid_i,
    input logic [6:0] virtual_target_dyn_address_i,
    input logic virtual_target_dyn_address_valid_i,

    // =========================================================================
    // Configuration and Status Interface - CSR Reads/Writes
    // =========================================================================
    // Reads from CSRs (inputs) are continuous assignments
    // Writes to CSRs (outputs) need generation of WE signal outside this module

    // -------------------------------------------------------------------------
    // ENEC/DISEC: Enable/Disable Target Event-Driven Interrupts
    // -------------------------------------------------------------------------
    output logic enec_ibi_o,
    output logic enec_crr_o,
    output logic enec_hj_o,

    output logic disec_ibi_o,
    output logic disec_crr_o,
    output logic disec_hj_o,

    // -------------------------------------------------------------------------
    // ENTAS0-3: Set Activity State
    // -------------------------------------------------------------------------
    output logic entas0_o,
    output logic entas1_o,
    output logic entas2_o,
    output logic entas3_o,

    // -------------------------------------------------------------------------
    // RSTDAA: Reset Dynamic Address Assignment
    // -------------------------------------------------------------------------
    // Forget current Dynamic Address and wait for new assignment
    output logic rstdaa_o,

    // -------------------------------------------------------------------------
    // ENTDAA: Enter Dynamic Address Assignment
    // -------------------------------------------------------------------------
    // Controller has started the Dynamic Address Assignment procedure
    output logic entdaa_o,

    // -------------------------------------------------------------------------
    // SETMWL/SETMRL: Set Max Write/Read Length
    // -------------------------------------------------------------------------
    output logic set_mwl_o,
    output logic [15:0] mwl_o,

    output logic set_mrl_o,
    output logic [15:0] mrl_o,

    output logic set_ibil_o,
    output logic [7:0] ibil_o,

    // -------------------------------------------------------------------------
    // ENTTM: Enter Test Mode
    // -------------------------------------------------------------------------
    output logic ent_tm_o,
    output logic [7:0] tm_o,

    // -------------------------------------------------------------------------
    // ENTHDR0-7: Enter HDR Mode
    // -------------------------------------------------------------------------
    input  logic exit_hdr_i,       // Asserted when exit HDR pattern detected
    output logic in_hdr_mode_o,    // Asserted while in HDR mode
    output logic in_hdr_err_mode_o, // Asserted while in HDR mode due to TE0/TE1 error

    // -------------------------------------------------------------------------
    // SETDASA/SETAASA: Set Dynamic Address from Static Address
    // -------------------------------------------------------------------------
    output logic [6:0] set_dasa_o,
    output logic set_dasa_valid_o,
    output logic set_dasa_virtual_device_o,
    output logic set_aasa_o,
    output logic set_aasa_virt_o,

    // -------------------------------------------------------------------------
    // RSTACT: Target Reset Action
    // -------------------------------------------------------------------------
    output logic [7:0] rst_action_o,
    output logic       rst_action_valid_o,

    // -------------------------------------------------------------------------
    // SETNEWDA: Set New Dynamic Address (also used by ENTDAA)
    // -------------------------------------------------------------------------
    output logic set_newda_o,
    output logic set_newda_virtual_device_o,
    output logic [6:0] newda_o,

    // -------------------------------------------------------------------------
    // GETMWL/GETMRL: Get Max Write/Read Length
    // -------------------------------------------------------------------------
    input logic [15:0] get_mwl_i,
    input logic [15:0] get_mrl_i,
    input logic [7:0] get_ibil_i,

    // -------------------------------------------------------------------------
    // GETPID/GETBCR/GETDCR: Get Device Identification
    // -------------------------------------------------------------------------
    input logic [47:0] get_pid_i,
    input logic [7:0] get_bcr_i,
    input logic [7:0] get_dcr_i,

    // Virtual device identification
    input logic [47:0] virtual_get_pid_i,
    input logic [7:0] virtual_get_bcr_i,
    input logic [7:0] virtual_get_dcr_i,

    // -------------------------------------------------------------------------
    // GETSTATUS: Get Device Status
    // -------------------------------------------------------------------------
    // Format 1 status word:
    //   [15:8] Vendor-specific
    //   [7:6]  Activity Mode (00=Normal, 11=Handoff not supported)
    //   [5]    Protocol Error
    //   [4]    Reserved
    //   [3:0]  Pending Interrupt count
    input logic [15:0] get_status_fmt1_i,
    output logic get_status_done_o,

    // -------------------------------------------------------------------------
    // GETACCCR: Get Accept Controller Role
    // -------------------------------------------------------------------------
    input logic get_acccr_i,

    // -------------------------------------------------------------------------
    // SETBRGTGT: Set Bridge Targets (not supported - not a bridging device)
    // -------------------------------------------------------------------------
    output logic set_brgtgt_o,

    // -------------------------------------------------------------------------
    // GETMXDS: Get Max Data Speed
    // -------------------------------------------------------------------------
    input logic get_mxds_i,

    // -------------------------------------------------------------------------
    // Reset Control Interface
    // -------------------------------------------------------------------------
    input  logic target_reset_detect_i,
    input  logic peripheral_reset_done_i,
    output logic peripheral_reset_o,
    output logic escalated_reset_o
);


  // ===========================================================================
  // INTERNAL SIGNAL DECLARATIONS
  // ===========================================================================
  // Organized by CCC frame structure:
  //
  // Broadcast CCC Frame:
  //   [Command Code (8b)] [T-Bit (1b)] [Defining Byte (8b)?] [T-Bit (1b)?]
  //   [Data (8b+)?] [STOP | Repeated Start]
  //
  // Direct CCC Frame:
  //   [Command Code (8b)] [T-Bit (1b)] [Defining Byte (8b)?] [T-Bit (1b)?]
  //   [Repeated Start] [Target Addr (7b)] [RnW (1b)] [ACK/NACK (1b)]
  //   [Data (8b+)?] [T-Bit per byte]
  //   [STOP | Repeated Start -> 7'h7E ends CCC | Repeated Start -> next target]
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // Frame 1: Command Code (8 bits)
  // ---------------------------------------------------------------------------
  // The command code determines broadcast vs direct and the specific CCC action
  ccc_cmd_e command_code;
  logic     command_code_valid;  // Asserted when command_code is valid

  // ---------------------------------------------------------------------------
  // Frame 2: T-Bit after Command Code (1 bit - odd parity)
  // ---------------------------------------------------------------------------
  logic       tbit_rx_state;              // FSM is in any T-bit receiving state
  logic       tbit_cmd_rx_state;          // FSM is specifically in command code T-bit state
  logic       capture_tbit_data;          // Trigger to capture data byte for T-bit check
  logic       tbit_rx_value;              // The received T-bit value
  logic       tbit_rx_expected_value;     // Expected T-bit value (odd parity of preceding data byte)
  logic       tbit_parity_err;            // Parity error flag
  logic       tbit_check_en;              // Enable for parity checking
  logic       cmd_tbit_valid;             // Command code T-bit complete (set by FSM)
  logic       def_byte_tbit_valid;        // Defining byte T-bit complete (set by FSM)

  // ---------------------------------------------------------------------------
  // Frame 3: Defining Byte (8 bits, optional based on command)
  // ---------------------------------------------------------------------------
  logic [7:0] defining_byte;
  logic       defining_byte_valid;   // Asserted when defining_byte contains valid data
  logic       have_defining_byte;    // This command requires a defining byte
  logic       capture_defining_byte; // Trigger to capture defining byte (set by FSM)
  logic       clear_defining_byte;   // Trigger to clear defining byte (set by FSM)

  // ---------------------------------------------------------------------------
  // Frame 5: Target Address + RnW (Direct CCC only, 7+1 bits)
  // ---------------------------------------------------------------------------
  logic [6:0] target_addr;           // 7-bit target address from direct CCC
  logic       target_rnw;            // Read (1) / Write (0) bit
  logic       capture_target_addr;   // Trigger to capture target address (set by FSM)

  // ---------------------------------------------------------------------------
  // Frame 6: ACK/NACK Response (1 bit, Direct CCC only)
  // ---------------------------------------------------------------------------
  logic       addr_ack;              // We should ACK this address (it matches us)
  logic       addr_ack_setdasa;      // SETDASA ACKs if static address matches
  logic       addr_ack_target;       // Other CCCs ACK if address matches, cmd supported, dir valid
  logic       addr_ack_rsvd;         // Reserved address (7'h7E) always ACKed to end CCC frame
  logic       target_addr_ack_done;  // Pulses when ACK/NACK transmitted (set by FSM)

  // ---------------------------------------------------------------------------
  // Frame 7+: Data Bytes (8 bits each, with T-bit after each)
  // ---------------------------------------------------------------------------
  logic [7:0] rx_data;               // Last received data byte
  logic [1:0] rx_byte_num;           // Current RX byte number (0-indexed, counts up)
  logic [1:0] rx_byte_total;         // Total bytes to receive for this command
  logic       rx_data_last_byte;     // This is the last byte to receive
  logic       capture_rx_data;       // Trigger to capture rx data byte (set by FSM)
  logic       clear_rx_byte_num;     // Reset rx_byte_num to 0 (set by FSM)
  logic       inc_rx_byte_num;       // Increment rx_byte_num (set by FSM)
  logic       rx_data_valid;         // RX data byte with T-bit complete (set by FSM)

  logic [7:0] tx_data;               // Data byte to transmit
  logic [2:0] tx_byte_num;           // Current TX byte number (0-indexed, counts up)
  logic [2:0] tx_byte_total;         // Total bytes to transmit for this command
  logic       tx_data_last_byte;     // This is the last byte to transmit
  logic       tx_data_complete;      // All TX bytes sent successfully (for GET completion)
  logic       clear_tx_byte_num;     // Reset tx_byte_num to 0 (set by FSM)
  logic       inc_tx_byte_num;       // Increment tx_byte_num (set by FSM)
  logic       set_tx_data_complete;  // Mark TX complete (set by FSM when last byte T-bit done)

  // ---------------------------------------------------------------------------
  // Command Type Classification
  // ---------------------------------------------------------------------------
  logic is_direct_cmd;                    // 1 = Direct CCC, 0 = Broadcast CCC
  logic is_enthdr_cmd;                    // 1 = ENTHDR0-7 command (enter HDR mode)
  logic supported_direct_command_code;    // Command code is in our supported list
  logic unsupported_defining_byte;        // Defining byte value is not supported
  logic supported_direct_command;         // Command is supported (code valid, defining byte valid)

  // ---------------------------------------------------------------------------
  // CCC Direction Requirements (for TE5 detection)
  // ---------------------------------------------------------------------------
  logic is_rstact;            // Command is RSTACT (special: both directions valid)
  logic ccc_requires_read;    // Command requires Read direction (R/W = 1)
  logic ccc_requires_write;   // Command requires Write direction (R/W = 0)
  logic ccc_direction_valid;  // Received R/W matches command's required direction

  // ---------------------------------------------------------------------------
  // Address Matching Logic
  // ---------------------------------------------------------------------------
  logic target_addr_matches_rsvd;      // Address is reserved (7'h7E)
  logic target_addr_matches_main_dyn;  // Address matches main target dynamic address
  logic target_addr_matches_main_sta;  // Address matches main target static address
  logic target_addr_matches_main;      // Address matches main target (dyn or sta)
  logic target_addr_matches_virt_dyn;  // Address matches virtual target dynamic address
  logic target_addr_matches_virt_sta;  // Address matches virtual target static address
  logic target_addr_matches_virt;      // Address matches virtual target (dyn or sta)
  logic target_addr_matches_any;       // Address matches main OR virtual target

  // ---------------------------------------------------------------------------
  // FSM Next-State Helper Signals (pre-computed for cleaner FSM logic)
  // ---------------------------------------------------------------------------
  logic entdaa_needs_main_addr;        // Main target needs dynamic address assignment
  logic entdaa_needs_virt_addr;        // Virtual target needs dynamic address assignment
  logic target_addr_matches_any_get_cmd;   // Address matches and this is a GET command (or RSTACT read)

  // ---------------------------------------------------------------------------
  // Bus TX/RX Interface (CCC vs ENTDAA mux)
  // ---------------------------------------------------------------------------
  bus_tx_req_t tx_req_ccc;
  bus_tx_req_t tx_req_entdaa;
  bus_rx_req_t rx_req_ccc;
  bus_rx_req_t rx_req_entdaa;

  // ---------------------------------------------------------------------------
  // ENTDAA Handling (Special CCC with its own sub-FSM)
  // ---------------------------------------------------------------------------
  logic       in_entdaa_mode;
  logic       entdaa_done;
  logic       entdaa_address_valid;
  logic [6:0] entdaa_address;
  logic       entdaa_process_virtual;
  logic       entdaa_set_newda;       // FSM signal: ENTDAA completed with valid address
  logic       entdaa_is_virtual;      // FSM signal: ENTDAA was for virtual target

  // ---------------------------------------------------------------------------
  // SETDASA/SETNEWDA Handling
  // ---------------------------------------------------------------------------
  logic       set_dasa_valid;
  logic [6:0] set_dasa_addr;
  logic       set_aasa_valid;
  logic       set_aasa_virt_valid;
  logic       set_newda_valid;
  logic [6:0] set_newda_addr;

  // ---------------------------------------------------------------------------
  // RSTACT Handling
  // ---------------------------------------------------------------------------
  logic [7:0] rst_action_q;
  logic [7:0] rst_action_d;
  logic       rstact_armed_q;
  logic       rstact_armed_d;
  logic       escalate_rst_arm_q;
  logic       escalate_rst_arm_d;
  logic       set_peripheral_reset;
  logic       set_escalate_reset;

  // ---------------------------------------------------------------------------
  // HDR Mode Handling
  // ---------------------------------------------------------------------------
  logic       in_hdr_mode;           // Currently in HDR mode
  logic       in_hdr_err_mode;       // In HDR mode due to TE0/TE1 error (not CCC-commanded)
  logic       enter_hdr_mode;        // Trigger to enter HDR mode (set when valid ENTHDR received)

  // ---------------------------------------------------------------------------
  // ENEC/DISEC Handling
  // ---------------------------------------------------------------------------
  logic enec_ibi;
  logic enec_crr;
  logic enec_hj;
  logic disec_ibi;
  logic disec_crr;
  logic disec_hj;

  // ---------------------------------------------------------------------------
  // I3C TE0-5 Error Pulses (asserted in FSM for one cycle when error detected)
  // ---------------------------------------------------------------------------
  // Error pulses are gated at the source by detection enable bits.
  // When detection is disabled, the error is never detected and the FSM continues normally.
  
  // TE0: Invalid reserved address + RnW combination (asserted in TxTargetAddrAck)
  logic       te0_err;          // Combined TE0 error (CCC module + target FSM)
  logic       te0_err_ccc;      // TE0 from CCC module (direct CCC target address)
  logic       is_te0_err_condition;  // Helper: reserved address has invalid RnW (gated with enable)
  // TE1: Parity error on CCC command code T-bit (asserted in RxCmdTbit)
  logic       te1_err;
  // TE2: Parity error on CCC data byte T-bit (asserted in RxDefByteTbit, RxDirectDefByteTbit, RxDataTbit)
  logic       te2_err;
  // TE3/TE4: Detected in ccc_entdaa submodule (gated there with enables)
  logic       te3_err;
  logic       te4_err;
  // TE5: Wrong R/W direction for Direct CCC (asserted in TxTargetAddrAck)
  logic       te5_err;
  logic       is_te5_err_condition;  // Helper: addressed with supported cmd but wrong direction (gated with enable)

  // ---------------------------------------------------------------------------
  // Framing Error Signals
  // ---------------------------------------------------------------------------
  // Dynamic Address padding error: Bit[0] must be 0 for SETDASA/SETNEWDA/SETGRPA
  // Per I3C spec: incorrect padding (Bit[0] = 1) is a protocol error
  logic       da_padding_err;

  // ---------------------------------------------------------------------------
  // SET CCC Handler Next-State Signals
  // ---------------------------------------------------------------------------
  logic        set_dasa_valid_next;
  logic [6:0]  set_dasa_addr_next;
  logic        set_newda_valid_next;
  logic [6:0]  set_newda_addr_next;
  logic        set_mrl_next;
  logic [15:0] mrl_next;
  logic        set_ibil_next;
  logic [7:0]  ibil_next;
  logic        set_mwl_next;
  logic [15:0] mwl_next;
  logic        enec_ibi_next;
  logic        enec_crr_next;
  logic        enec_hj_next;
  logic        disec_ibi_next;
  logic        disec_crr_next;
  logic        disec_hj_next;

  // ---------------------------------------------------------------------------
  // Broadcast CCC Handler Next-State Signals
  // ---------------------------------------------------------------------------
  logic        rstdaa_next;
  logic        set_aasa_valid_next;
  logic        set_aasa_virt_valid_next;

  // ===========================================================================
  // COMMAND CODE REGISTRATION
  // ===========================================================================
  always_ff @(posedge clk_i or negedge rst_ni) begin : register_command_code
    if (~rst_ni) begin
      command_code <= ccc_cmd_e'('0);
      command_code_valid <= 1'b0;
    end else begin
      if (ccc_valid_i) begin
        command_code <= ccc_data_i;
        command_code_valid <= 1'b1;
      end else if (done_fsm_o) begin
        command_code <= ccc_cmd_e'('0);
        command_code_valid <= 1'b0;
      end
    end
  end

  // Determine if this is a direct (vs broadcast) command
  // Bit[7] = 1 means Direct CCC, Bit[7] = 0 means Broadcast CCC
  assign is_direct_cmd = command_code[7];

  // Determine if this is an ENTHDR command (enter HDR mode)
  // ENTHDR0-7 are broadcast CCCs: 0x20-0x27
  assign is_enthdr_cmd = command_code inside {
    CCC_BCAST_ENTHDR0, CCC_BCAST_ENTHDR1, CCC_BCAST_ENTHDR2, CCC_BCAST_ENTHDR3,
    CCC_BCAST_ENTHDR4, CCC_BCAST_ENTHDR5, CCC_BCAST_ENTHDR6, CCC_BCAST_ENTHDR7
  };

  // ===========================================================================
  // BUS TX/RX MUX: Regular CCC vs ENTDAA
  // ===========================================================================
  // ENTDAA has its own sub-FSM that takes over the bus interface
  assign bus_tx_req_o = entdaa_o ? tx_req_entdaa : tx_req_ccc;
  assign bus_rx_req_o = entdaa_o ? rx_req_entdaa : rx_req_ccc;

  // ===========================================================================
  // DEFINING BYTE DETERMINATION (used by FSM)
  // ===========================================================================
  // Certain CCCs require a defining byte after the command code T-bit
  assign have_defining_byte = command_code inside {
    CCC_BCAST_ENDXFER, CCC_BCAST_RSTACT, CCC_BCAST_MLANE,
    CCC_DIRECT_GETCAPS, CCC_DIRECT_ENDXFER, CCC_DIRECT_RSTACT
  };
  // ===========================================================================
  // FSM STATE DEFINITIONS
  // ===========================================================================
  // States organized by CCC frame processing sequence
  typedef enum logic [7:0] {
    // Initial/Idle state
    WaitCCC,                 // Ready to receive command code from target_fsm

    // Frame 2: T-bit after command code
    RxCmdTbit,               // Receive T-bit after command code

    // Frame 3-4: Defining byte handling
    RxDefByte,               // Receive defining byte (mandatory path)
    RxDefByteOrBusCond,      // Receive defining byte OR detect repeated start
    RxDefByteTbit,           // Receive T-bit after defining byte

    // Direct CCC: Wait for repeated start before target address
    WaitDirectRstart,        // Wait for repeated start (direct CCC)
    RxDirectDefByteTbit,     // Receive T-bit in direct mode before address phase

    // Frame 5-6: Target address handling (Direct CCC)
    RxTargetAddr,            // Receive 7-bit address + RnW bit
    TxTargetAddrAck,         // Transmit ACK/NACK response

    // Sub-command byte
    RxSubCmdByte,            // Receive sub-command byte - unused today

    // Frame 7+: Data phase
    RxData,                  // Receive data byte
    RxDataTbit,              // Receive T-bit after data byte
    TxData,                  // Transmit data byte (GET commands)
    TxDataTbitCont,          // Transmit T-bit after data byte with more to send
    TxDataTbitEnd,           // Transmit T-bit after last data byte

    // Bus condition handling
    WaitForBusCond,          // Wait for STOP or Repeated Start
    WaitForENTDAAEnd,        // Wait for ENTDAA to end (STOP or new CCC via SR+7'h7E/W)

    // CCC completion
    NextCCC,                 // Signal ready for next CCC in chain
    DoneCCC,                 // CCC processing complete

    // ENTDAA special handling
    HandleTargetENTDAA,      // Process ENTDAA for primary target
    HandleVirtualTargetENTDAA // Process ENTDAA for virtual target
  } state_e;

  state_e state_q, state_d;

  // ===========================================================================
  // T-BIT PARITY CHECKING
  // ===========================================================================
  // T-bit is odd parity over preceding data byte. Used for TE1/TE2 error detection.

  assign tbit_rx_state = state_q inside {RxCmdTbit, RxDataTbit, 
                                         RxDirectDefByteTbit, RxDefByteTbit};
  assign tbit_cmd_rx_state = state_q == RxCmdTbit;

  // Capture data bytes for parity calculation (fires when byte received, not T-bit)
  assign capture_tbit_data = bus_rx_rsp_i.done && !tbit_rx_state;

  // Compute expected T-bit (odd parity)
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      tbit_rx_expected_value <= '0;
    end else begin
      if (tbit_cmd_rx_state) begin
        tbit_rx_expected_value <= ~^ccc_data_i;
      end else if (capture_tbit_data) begin
        tbit_rx_expected_value <= ~^bus_rx_rsp_i.data;
      end
    end
  end

  assign tbit_rx_value = (tbit_rx_state && bus_rx_rsp_i.done) ? bus_rx_rsp_i.data[0] : 1'b0;
  assign tbit_check_en = tbit_rx_state && bus_rx_rsp_i.done;
  assign tbit_parity_err = tbit_check_en && (tbit_rx_expected_value != tbit_rx_value);

  // ===========================================================================
  // ENTDAA STATE TRACKING
  // ===========================================================================
  // entdaa_o: ENTDAA sub-FSM is actively processing (used for bus mux and sub-FSM start)
  assign entdaa_o = (state_q == HandleTargetENTDAA || 
                     state_q == HandleVirtualTargetENTDAA);
  assign entdaa_process_virtual = (state_q == HandleVirtualTargetENTDAA);
  
  // in_entdaa_mode: We are in ENTDAA mode (including waiting for it to end)
  // Used to disable TE0 checking since 7'h7E/R is valid during ENTDAA
  assign in_entdaa_mode = entdaa_o || (state_q == WaitForENTDAAEnd);

  // ===========================================================================
  // DEFINING BYTE REGISTRATION
  // ===========================================================================
  always_ff @(posedge clk_i or negedge rst_ni) begin : register_defining_byte
    if (~rst_ni) begin
      defining_byte <= '0;
      defining_byte_valid <= '0;
    end else if (capture_defining_byte) begin
      defining_byte <= bus_rx_rsp_i.data;
      defining_byte_valid <= 1'b1;
    end else if (clear_defining_byte || done_fsm_o) begin
      defining_byte <= '0;
      defining_byte_valid <= 1'b0;
    end
  end

  // ===========================================================================
  // COMMAND TYPE AND ADDRESS MATCHING
  // ===========================================================================

  // Reserved address detection (7'h7E used for broadcast and CCC termination)
  assign target_addr_matches_rsvd = target_addr == 7'h7E;

  // Primary target address matching
  // Per I3C spec: Once a target has a dynamic address, it stops responding to its static address
  assign target_addr_matches_main_dyn = ((target_addr == target_dyn_address_i) && target_dyn_address_valid_i);
  assign target_addr_matches_main_sta = ((target_addr == target_sta_address_i) && target_sta_address_valid_i && ~target_dyn_address_valid_i);
  assign target_addr_matches_main = target_addr_matches_main_dyn | target_addr_matches_main_sta;

  // Virtual target address matching
  // Per I3C spec: Once a target has a dynamic address, it stops responding to its static address
  assign target_addr_matches_virt_dyn = ((target_addr == virtual_target_dyn_address_i) && virtual_target_dyn_address_valid_i);
  assign target_addr_matches_virt_sta = ((target_addr == virtual_target_sta_address_i) && virtual_target_sta_address_valid_i && ~virtual_target_dyn_address_valid_i);
  assign target_addr_matches_virt = target_addr_matches_virt_dyn | target_addr_matches_virt_sta;

  // Combined: Address matches either main target or virtual target
  assign target_addr_matches_any = target_addr_matches_main | target_addr_matches_virt;

  // ===========================================================================
  // FSM NEXT-STATE HELPER SIGNALS
  // ===========================================================================
  assign entdaa_needs_main_addr = ~target_dyn_address_valid_i;
  assign entdaa_needs_virt_addr = ~virtual_target_dyn_address_valid_i;

  // Determines if we should enter TxData phase after ACK.
  // Only used when addr_ack is true, so direction is already validated.
  // - GET commands (ccc_requires_read): Target transmits data
  // - RSTACT with R/W=1: Target transmits timing data
  // All other ACKed commands (SET, SETDASA, RSTACT with R/W=0) go to RxData.
  assign target_addr_matches_any_get_cmd = target_addr_matches_any && 
                                           (ccc_requires_read || (is_rstact && target_rnw));

  // ===========================================================================
  // SUPPORTED COMMAND AND DIRECTION VALIDATION
  // ===========================================================================
  // Per I3C spec, each Direct CCC has a required R/W direction.
  // Wrong direction triggers TE5 error.

  // CCCs that require Read direction (target transmits, R/W = 1)
  assign ccc_requires_read = command_code inside {
    CCC_DIRECT_GETBCR,
    CCC_DIRECT_GETDCR,
    CCC_DIRECT_GETSTATUS,
    CCC_DIRECT_GETMWL,
    CCC_DIRECT_GETMRL,
    CCC_DIRECT_GETPID,
    CCC_DIRECT_GETCAPS
  };

  // CCCs that require Write direction (target receives, R/W = 0)
  assign ccc_requires_write = command_code inside {
    CCC_DIRECT_SETDASA,
    CCC_DIRECT_SETNEWDA,
    CCC_DIRECT_SETMWL,
    CCC_DIRECT_SETMRL,
    CCC_DIRECT_ENEC,
    CCC_DIRECT_DISEC
  };

  // RSTACT: Both directions valid; 0x00-0x7F arms action, 0x80-0xFF returns timing
  assign is_rstact = (command_code == CCC_DIRECT_RSTACT);

  assign supported_direct_command_code = ccc_requires_read | ccc_requires_write | is_rstact;

  assign unsupported_defining_byte = have_defining_byte & defining_byte_valid & (
        (command_code == CCC_DIRECT_RSTACT) & ~(defining_byte inside {8'h00, 8'h01, 8'h02, 8'h81, 8'h82})
      | (command_code == CCC_DIRECT_GETCAPS) & ~(defining_byte inside {8'h00, 8'h93}));

  assign supported_direct_command = supported_direct_command_code & ~unsupported_defining_byte;

  assign ccc_direction_valid = 
    (ccc_requires_read && target_rnw) ||
    (ccc_requires_write && ~target_rnw) ||
    is_rstact;

  // ===========================================================================
  // TE ERROR DETECTION HELPERS
  // ===========================================================================
  // Error detection is gated at the source by detection enable bits.
  // When a detection enable is 0, the corresponding error condition evaluates to 0,
  // so the FSM never sees the error and continues normal operation.
  // This is the same pattern used by te0_enable_o.

  // TE0 helper: Check if reserved address has invalid RnW
  // - Disabled during ENTDAA mode (since 7'h7E/R is valid)
  // - Gated with te0_err_det_en_i
  assign te0_enable_o = te0_err_det_en_i && !in_entdaa_mode && 
                        (target_dyn_address_valid_i || virtual_target_dyn_address_valid_i);
  assign is_te0_err_condition = te0_enable_o && is_te0_rsvd_addr_err(target_addr, target_rnw);

  // TE5 helper: Check if direction is wrong for this command
  // - Gated with te5_err_det_en_i
  assign is_te5_err_condition = te5_err_det_en_i && target_addr_matches_any && supported_direct_command;

  // Combined TE0 error (CCC module + target FSM)
  // te0_err_i from target FSM is already gated with te0_enable_o (which includes detection enable)
  assign te0_err = te0_err_ccc || te0_err_i;

  // Protocol Error outputs for interrupt reporting
  // These pass through the error pulses (already gated by detection enables in FSM)
  assign te1_err_o = te1_err;
  assign te2_err_ccc_o = te2_err;
  assign te3_err_o = te3_err;
  assign te4_err_o = te4_err;
  assign te5_err_o = te5_err;

  // Framing error for Protocol Error Report (GETSTATUS Format 1):
  // Per I3C FAQ Q16.10: Incorrect framing for DA assignment CCCs should be reported.
  // da_padding_err: Bit[0] != 0 in SETDASA/SETNEWDA address byte.
  // Detection is gated with framing_err_det_en_i in fsm_ccc_main
  assign framing_err_o = da_padding_err;

  // ===========================================================================
  // TARGET ADDRESS CAPTURE (Direct CCC Frame 5)
  // ===========================================================================
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_target_addr
    if (~rst_ni) begin
      target_addr <= '0;
      target_rnw  <= '0;
    end else begin
      if (capture_target_addr) begin
        target_addr <= bus_rx_rsp_i.data[7:1];
        target_rnw  <= bus_rx_rsp_i.data[0];
      end
    end
  end

  // ===========================================================================
  // ADDRESS ACK DETERMINATION
  // ===========================================================================
  assign addr_ack_setdasa = (command_code == CCC_DIRECT_SETDASA) &
                            (target_addr_matches_main_sta | target_addr_matches_virt_sta);
  assign addr_ack_target  = (command_code != CCC_DIRECT_SETDASA) &
                            target_addr_matches_any & supported_direct_command & ccc_direction_valid;
  assign addr_ack_rsvd    = target_addr_matches_rsvd & ~target_rnw;  // Only ACK 7E/W

  assign addr_ack = addr_ack_setdasa | addr_ack_target | addr_ack_rsvd;

  // ===========================================================================
  // DATA RECEPTION
  // ===========================================================================
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_rx_data
    if (~rst_ni) begin
      rx_data <= '0;
    end else if (capture_rx_data) begin
      rx_data <= bus_rx_rsp_i.data;
    end
  end

  // ===========================================================================
  // BUS RX REQUEST GENERATION
  // ===========================================================================
  // Request bytes or bits based on current state
  assign rx_req_ccc = '{
    req_byte: (state_q inside {RxDefByte, RxTargetAddr}) ||
              (state_q inside {RxDefByteOrBusCond, WaitDirectRstart, RxData} && !bus_rstart_det_i),
    req_bit:  (state_q inside {RxCmdTbit, RxDefByteTbit, RxDirectDefByteTbit, RxDataTbit})
  };

  // ===========================================================================
  // MAIN FSM: CCC FRAME PROCESSING
  // ===========================================================================
  always_comb begin : fsm_ccc_main
    done_fsm_o = 1'b0;
    next_ccc_o = 1'b0;

    // Default, safe tx request values
    tx_req_ccc = '{
      req_valid:  1'b0,
      req_type:   RawBit,
      drive_type: OpenDrain,
      data:       '1
    };

    // Defining byte capture/clear control
    capture_defining_byte = 1'b0;
    clear_defining_byte   = 1'b0;

    // T-bit completion signals
    cmd_tbit_valid      = 1'b0;
    def_byte_tbit_valid = 1'b0;

    // Target address capture control
    capture_target_addr = 1'b0;

    // RX data capture control
    capture_rx_data = 1'b0;
    rx_data_valid   = 1'b0;

    // Target address ACK done control
    target_addr_ack_done = 1'b0;

    // RX byte counter control
    clear_rx_byte_num = 1'b0;
    inc_rx_byte_num   = 1'b0;

    // TX byte counter control
    clear_tx_byte_num = 1'b0;
    inc_tx_byte_num   = 1'b0;
    set_tx_data_complete = 1'b0;

    // ENTDAA output control
    entdaa_set_newda = 1'b0;
    entdaa_is_virtual = 1'b0;

    // HDR mode control
    enter_hdr_mode = 1'b0;

    // TE error outputs (single-cycle pulses)
    te0_err_ccc = 1'b0;
    te1_err     = 1'b0;
    te2_err     = 1'b0;
    te5_err     = 1'b0;

    // Dynamic Address padding error (single-cycle pulse)
    da_padding_err = 1'b0;

    state_d = state_q;
    unique case (state_q)
      // ---------------------------------------------------------------------
      // Initial State
      // ---------------------------------------------------------------------
      WaitCCC: begin
        if (ccc_valid_i) begin
          // Clear byte counters at start of every CCC (broadcast and direct)
          clear_rx_byte_num = 1'b1;
          clear_tx_byte_num = 1'b1;
          state_d = RxCmdTbit;
        end
      end
      
      // ---------------------------------------------------------------------
      // Frame 2: T-bit after Command Code
      // ---------------------------------------------------------------------
      RxCmdTbit: begin
        if (bus_rx_rsp_i.done) begin
          if (tbit_parity_err && te1_err_det_en_i) begin
            // TE1: CCC command parity error - signal done and enter HDR mode (deaf mode)
            te1_err = 1'b1;  // Assert TE1 error pulse
            state_d = DoneCCC;
          end
          else begin
            cmd_tbit_valid = 1'b1;  // Command T-bit complete (only if no parity error)
            if (have_defining_byte) begin
              // GETCAPS: defining byte is optional (may get repeated start instead)
              state_d = (command_code == CCC_DIRECT_GETCAPS) ? RxDefByteOrBusCond : RxDefByte;
            end
            else if (command_code == CCC_BCAST_ENTDAA) begin
              if (entdaa_needs_main_addr)       state_d = HandleTargetENTDAA;
              else if (entdaa_needs_virt_addr)  state_d = HandleVirtualTargetENTDAA;
              else                              state_d = WaitForENTDAAEnd;  // Already have addresses, wait for ENTDAA to end
            end
            else if (is_enthdr_cmd) begin
              // ENTHDR0-7: Enter HDR mode (no defining byte, no data phase)
              // HDR mode state machine handles the rest
              enter_hdr_mode = 1'b1;
              state_d = DoneCCC;  // Signal done so i3c_target_fsm exits DoCCC -> InHDRMode
            end
            else if (~is_direct_cmd) begin
              state_d = RxData;  // Broadcast CCCs receive data
            end
            else begin
              state_d = WaitDirectRstart;  // Direct CCCs wait for target address
            end
          end
        end
      end
      
      // ---------------------------------------------------------------------
      // ENTDAA Special Handling
      // ---------------------------------------------------------------------
      HandleTargetENTDAA: begin
        // Signal to set new address when ENTDAA sub-FSM provides valid address
        entdaa_set_newda = entdaa_address_valid;
        
        if (entdaa_done) begin
          // After main target, check if virtual target also needs address
          // Go to WaitForENTDAAEnd to wait for STOP (ENTDAA may continue for other targets)
          state_d = entdaa_needs_virt_addr ? HandleVirtualTargetENTDAA : WaitForENTDAAEnd;
        end
      end
      
      HandleVirtualTargetENTDAA: begin
        // Signal to set new address when ENTDAA sub-FSM provides valid address
        entdaa_set_newda = entdaa_address_valid;
        entdaa_is_virtual = 1'b1;
        
        if (entdaa_done) begin
          // Go to WaitForENTDAAEnd to wait for STOP (ENTDAA may continue for other targets)
          state_d = WaitForENTDAAEnd;
        end
      end
      
      // ---------------------------------------------------------------------
      // Frame 3-4: Defining Byte Handling
      // ---------------------------------------------------------------------
      RxDefByte: begin
        if (bus_rx_rsp_i.done) begin
          capture_defining_byte = 1'b1;
          state_d = RxDefByteTbit;
        end
      end
      
      RxDefByteOrBusCond: begin
        // Either receive defining byte OR detect repeated start (for direct CCC)
        if (bus_rstart_det_i) begin
          // No defining byte received - clear any stale data
          clear_defining_byte = 1'b1;
          state_d = RxTargetAddr;
        end else if (bus_rx_rsp_i.done) begin
          capture_defining_byte = 1'b1;
          state_d = RxDefByteTbit;
        end
      end
      
      RxDefByteTbit: begin
        if (bus_rx_rsp_i.done) begin
          if (tbit_parity_err && te2_err_det_en_i) begin
            // TE2: Defining byte parity error - abort this CCC
            te2_err = 1'b1;  // Assert TE2 error pulse
            state_d = DoneCCC;
          end else begin
            def_byte_tbit_valid = 1'b1;  // Defining byte T-bit complete (only if no parity error)
            // broadcast CCCs proceed to data
            if (~is_direct_cmd) state_d = RxData;
            // direct CCCs wait for repeated start
            else state_d = WaitDirectRstart;
          end
        end
      end
      
      // ---------------------------------------------------------------------
      // Direct CCC: Wait for Target Address
      // ---------------------------------------------------------------------
      WaitDirectRstart: begin
        // Wait for repeated start before target address
        if (bus_rstart_det_i) state_d = RxTargetAddr;
        else if (bus_rx_rsp_i.done) state_d = RxDirectDefByteTbit;
      end
      
      RxDirectDefByteTbit: begin
        if (bus_rx_rsp_i.done) begin
          if (tbit_parity_err && te2_err_det_en_i) begin
            // TE2: Parity error on additional data byte before target address
            te2_err = 1'b1;  // Assert TE2 error pulse
            state_d = DoneCCC;
          end else begin
            state_d = WaitDirectRstart;
          end
        end
      end
      
      // ---------------------------------------------------------------------
      // Frame 5-6: Target Address and ACK
      // ---------------------------------------------------------------------
      RxTargetAddr: begin
        if (bus_rx_rsp_i.done) begin
          capture_target_addr = 1'b1;
          state_d = TxTargetAddrAck;
        end
      end
      
      // After sending ACK/NACK, determine next state based on error conditions and addr_ack:
      //   - TE0: Invalid reserved address - signal done and enter HDR mode
      //   - TE5: Wrong R/W direction - NACK and wait for recovery
      //   - Reserved address (7'h7E/W): End of CCC frame, ready for next CCC
      //   - ACKed: Proceed to appropriate data phase (GET → TxData, SET → RxData)
      //   - NACKed: Wait for bus condition (not addressed, unsupported cmd)
      TxTargetAddrAck: begin
        tx_req_ccc.req_valid = 1'b1;
        tx_req_ccc.req_type  = RawBit;
        tx_req_ccc.data[7]   = ~addr_ack;  // Send ACK (0) or NACK (1)

        if (bus_tx_rsp_i.done) begin
          target_addr_ack_done = 1'b1;
          clear_rx_byte_num = 1'b1;  // Reset RX byte counter for upcoming data phase
          clear_tx_byte_num = 1'b1;  // Reset TX byte counter for upcoming data phase

          if (is_te0_err_condition) begin
            // TE0: Invalid reserved address - enter HDR mode (deaf mode)
            te0_err_ccc = 1'b1;  // Assert TE0 error pulse
            state_d = DoneCCC;
          end else if (target_addr_matches_rsvd) begin
            // Reserved address (7'h7E/W): End of Direct CCC frame
            state_d = NextCCC;
          end else if (~addr_ack) begin
            if (is_te5_err_condition) begin
              // TE5: Wrong R/W direction - already NACKed, wait for recovery
              te5_err = 1'b1;  // Assert TE5 error pulse
            end
            // NACKed: Not addressed to us or unsupported command
            state_d = WaitForBusCond;
          end else if (target_addr_matches_any_get_cmd) begin
            // ACKed GET command: Target transmits data
            state_d = TxData;
          end else if (is_rstact) begin
            // RSTACT write: no data phase (defining byte already captured)
            state_d = WaitForBusCond;
          end else begin
            // ACKed SET command (including SETDASA): Target receives data
            state_d = RxData;
          end
        end
      end

      // ---------------------------------------------------------------------
      // Sub-command Byte
      // ---------------------------------------------------------------------
      // Unused state because none of our commands utilize Sub Cmd Byte
      RxSubCmdByte: begin
        state_d = WaitCCC;
      end

      // ---------------------------------------------------------------------
      // Frame 7+: Data Phase
      // ---------------------------------------------------------------------
      RxData: begin
        if (bus_rx_rsp_i.done) begin
          capture_rx_data = 1'b1;
          state_d = RxDataTbit;
        end
      end
      RxDataTbit: begin
        if (bus_rx_rsp_i.done) begin
          if (tbit_parity_err && te2_err_det_en_i) begin
            // TE2: Data byte parity error - abort this CCC
            te2_err = 1'b1;  // Assert TE2 error pulse
            state_d = DoneCCC;
          end else begin
            inc_rx_byte_num = 1'b1;   // Move to next byte
            // Check for DA padding bit error (Bit[0] must be 0 for DA assignment CCCs)
            // Gated with framing_err_det_en_i - when disabled, proceed normally
            if (framing_err_det_en_i &&
                rx_byte_num == 2'd0 &&
                (command_code == CCC_DIRECT_SETDASA || command_code == CCC_DIRECT_SETNEWDA) &&
                rx_data[0] == 1'b1) begin
              // DA padding bit error: Don't set rx_data_valid - address won't be applied
              da_padding_err = 1'b1;
            end else begin
              rx_data_valid = 1'b1;   // Data byte with T-bit complete
            end
            // After last byte, wait for SR/STOP; otherwise receive more bytes
            if (rx_data_last_byte) begin
              state_d = WaitForBusCond;
            end else begin
              state_d = RxData;
            end
          end
        end
      end
      
      TxData: begin
        tx_req_ccc.drive_type = PushPull;
        tx_req_ccc.req_valid  = 1'b1;
        tx_req_ccc.req_type   = RawByte;
        tx_req_ccc.data       = tx_data;

        if (bus_tx_rsp_i.done) begin
          // Increment byte counter as we need the next data byte for the Tbit request
          inc_tx_byte_num = 1'b1;
          // Handle last byte in a dedicated state
          state_d = tx_data_last_byte ? TxDataTbitEnd : TxDataTbitCont;
        end
      end

      TxDataTbitEnd: begin
        tx_req_ccc.req_valid = 1'b1;
        tx_req_ccc.req_type  = TReadEnd;

        if (bus_tx_rsp_i.done) begin
          // Target complete: Target sent T=0, wait for Sr or STOP
          set_tx_data_complete = 1'b1;
          state_d = WaitForBusCond;
        end
      end

      TxDataTbitCont: begin
        tx_req_ccc.req_valid = 1'b1;
        tx_req_ccc.req_type  = TReadCont;
        tx_req_ccc.data      = tx_data;

        if (bus_tx_rsp_i.abort) begin
          // Controller abort: Sr during T-bit means the transfer is
          // incomplete — do NOT mark tx_data_complete. This prevents
          // get_status_done_o from falsely firing on an aborted GETSTATUS,
          // which would prematurely clear the Protocol Error in err_o.
          state_d = RxTargetAddr;
        end else if (bus_tx_rsp_i.done) begin
          state_d = TxData;
        end
      end
      
      // ---------------------------------------------------------------------
      // Bus Condition Handling
      // ---------------------------------------------------------------------
      WaitForBusCond: begin
        // Wait repeat start. Stop condition is handled below
        // for all of this logic and takes us to DoneCCC
        if (bus_rstart_det_i) state_d = RxTargetAddr;
      end
      
      WaitForENTDAAEnd: begin
        // After our target(s) complete ENTDAA, wait for the Controller to finish
        // assigning addresses to other targets on the bus.
        // 
        // The Controller will continue sending SR + 7'h7E/R for other targets.
        // We must ignore these sequences and only exit on STOP.
        // ENTDAA always ends with STOP - a new CCC cannot start until after STOP.
        //
        // The bus_stop_det_i override at the end of the FSM will handle 
        // transitioning to DoneCCC when STOP is detected.
      end
      
      // ---------------------------------------------------------------------
      // CCC Completion
      // ---------------------------------------------------------------------
      NextCCC: begin
        // Ready for next CCC in chain
        next_ccc_o = 1'b1;
        state_d    = WaitCCC;
      end
      
      DoneCCC: begin
        // CCC processing complete
        done_fsm_o = 1'b1;
        state_d    = WaitCCC;
      end
      
      default: begin
      end
    endcase

    // Overwrite decision on bus STOP - terminates CCC processing
    if (bus_stop_det_i) begin
      state_d = DoneCCC;
    end
  end

  // ===========================================================================
  // FSM STATE REGISTER
  // ===========================================================================
  always_ff @(posedge clk_i or negedge rst_ni) begin : state_transition
    if (!rst_ni) begin
      state_q <= WaitCCC;
    end else begin
      state_q <= state_d;
    end
  end

  // ===========================================================================
  // TX BYTE COUNTER (for multi-byte GET responses)
  // ===========================================================================
  // Counts up from 0: byte 0 is first byte sent, byte (tx_byte_total-1) is last
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_tx_byte_num
    if (~rst_ni) begin
      tx_byte_num <= '0;
    end else begin
      if (clear_tx_byte_num)    tx_byte_num <= '0;
      else if (inc_tx_byte_num) tx_byte_num <= tx_byte_num + 1'b1;
    end
  end

  // Last byte when we've reached (tx_byte_total - 1)
  assign tx_data_last_byte = (tx_byte_num == tx_byte_total - 1);

  // TX complete tracking: set by FSM when last T-bit completes normally
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_tx_data_complete
    if (~rst_ni) begin
      tx_data_complete <= 1'b0;
    end else if (clear_tx_byte_num) begin
      tx_data_complete <= 1'b0;
    end else if (set_tx_data_complete) begin
      tx_data_complete <= 1'b1;
    end
  end

  // ===========================================================================
  // RX BYTE COUNTER (for multi-byte SET commands)
  // ===========================================================================
  // Counts up from 0: byte 0 is first byte received, byte 1 is second, etc.
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_rx_byte_num
    if (~rst_ni) begin
      rx_byte_num <= '0;
    end else begin
      if (clear_rx_byte_num)    rx_byte_num <= '0;
      else if (inc_rx_byte_num) rx_byte_num <= rx_byte_num + 1'b1;
    end
  end

  // Last RX byte when we've reached (rx_byte_total - 1)
  assign rx_data_last_byte = (rx_byte_num == rx_byte_total - 1);

  // ===========================================================================
  // CCC HANDLERS
  // ===========================================================================

  // GETSTATUS completion: pulse when GETSTATUS completes with all bytes sent.
  assign get_status_done_o = done_fsm_o && command_code_valid && 
                             (command_code == CCC_DIRECT_GETSTATUS) && tx_data_complete;

  // ---------------------------------------------------------------------------
  // DIRECT GET CCC HANDLER
  // ---------------------------------------------------------------------------
  // Determines TX data and byte count for GET CCCs.
  // tx_byte_num counts up from 0: byte 0 is first byte sent.
  always_comb begin : proc_get_ccc_handler
    // Default values
    tx_byte_total = 3'd0;
    tx_data = '0;
    case (command_code)
      // ---------------------------------------------------------------------
      // 1 Byte Responses
      // ---------------------------------------------------------------------
      CCC_DIRECT_GETBCR: begin
        tx_byte_total = 3'd1;
        tx_data = target_addr_matches_virt ? virtual_get_bcr_i : get_bcr_i;
      end
      
      CCC_DIRECT_GETDCR: begin
        tx_byte_total = 3'd1;
        tx_data = target_addr_matches_virt ? virtual_get_dcr_i : get_dcr_i;
      end
      
      CCC_DIRECT_RSTACT: begin
        tx_byte_total = 3'd1;
        // If no defining byte then tx_data gets default value from above. 
        if (defining_byte == 8'h81 || defining_byte == 8'h82) begin
          // 0x81/0x82: Return reset recovery time (0xFF = worst case ~1s)
          tx_data = 8'hFF;
        end else if (defining_byte inside {8'h00, 8'h01, 8'h02}) begin
          // 0x00-0x02: Return armed action, or 0x80 if not armed
          tx_data = rstact_armed_q ? rst_action_q : 8'h80;
        end
      end
      
      // ---------------------------------------------------------------------
      // 2 Byte Responses
      // ---------------------------------------------------------------------
      CCC_DIRECT_GETSTATUS: begin
        tx_byte_total = 3'd2;
        case (tx_byte_num)
          3'd0:    tx_data = get_status_fmt1_i[15:8];
          // Virtual target: Activity Mode=3, pass through Protocol Error, no pending interrupts
          // (virtual target cannot send IBIs, so PENDING_INTERRUPT is always 0)
          3'd1:    tx_data = target_addr_matches_virt ? 
                             {2'b11, get_status_fmt1_i[5], 5'b0} : get_status_fmt1_i[7:0];
        endcase
      end
      
      CCC_DIRECT_GETMWL: begin
        tx_byte_total = 3'd2;
        case (tx_byte_num)
          3'd0:    tx_data = get_mwl_i[15:8];
          3'd1:    tx_data = get_mwl_i[7:0];
        endcase
      end
      
      // ---------------------------------------------------------------------
      // 3 Byte Responses
      // ---------------------------------------------------------------------
      CCC_DIRECT_GETMRL: begin
        tx_byte_total = 3'd3;
        case (tx_byte_num)
          3'd0:    tx_data = get_mrl_i[15:8];
          3'd1:    tx_data = get_mrl_i[7:0];
          // Virtual target cannot send IBIs, so IBI payload length is 0
          3'd2:    tx_data = target_addr_matches_virt ? 8'h00 : get_ibil_i;
        endcase
      end
      
      // ---------------------------------------------------------------------
      // 6 Byte Responses
      // ---------------------------------------------------------------------
      CCC_DIRECT_GETPID: begin
        tx_byte_total = 3'd6;
        case (tx_byte_num)
          3'd0:    tx_data = target_addr_matches_virt ? virtual_get_pid_i[47:40] : get_pid_i[47:40];
          3'd1:    tx_data = target_addr_matches_virt ? virtual_get_pid_i[39:32] : get_pid_i[39:32];
          3'd2:    tx_data = target_addr_matches_virt ? virtual_get_pid_i[31:24] : get_pid_i[31:24];
          3'd3:    tx_data = target_addr_matches_virt ? virtual_get_pid_i[23:16] : get_pid_i[23:16];
          3'd4:    tx_data = target_addr_matches_virt ? virtual_get_pid_i[15:8]  : get_pid_i[15:8];
          3'd5:    tx_data = target_addr_matches_virt ? virtual_get_pid_i[7:0]   : get_pid_i[7:0];
        endcase
      end

      // ---------------------------------------------------------------------
      // Variable Length Responses
      // ---------------------------------------------------------------------
      CCC_DIRECT_GETCAPS: begin
        if (!defining_byte_valid || defining_byte == 8'h00) begin
          // Default GETCAPS response (3 bytes)
          tx_byte_total = 3'd3;
          case (tx_byte_num)
            3'd0:    tx_data = 8'h00;  // No HDR Modes supported
            3'd1:    tx_data = 8'h01;  // I3C Basic v1.1.1
            // CRCAP1: 0x48 = IBI MDB (bit 6) + IBI Payload (bit 3) + GETCAPS defining bytes
            // Virtual target cannot send IBIs, so clear IBI-related bits (0x48 -> 0x00)
            3'd2:    tx_data = target_addr_matches_virt ? 8'h00 : 8'h48;
          endcase
        end else if (defining_byte_valid && defining_byte == 8'h93) begin
          // GETCAPS 0x93: TESTCAP byte - device test capabilities
          tx_byte_total = 3'd1;
          tx_data = 8'h35;  // Share peripheral logic with side effects
        end 
      end
      
      default: begin
      end
    endcase
  end

  // ---------------------------------------------------------------------------
  // SET CCC RX BYTE COUNT (Broadcast and Direct)
  // ---------------------------------------------------------------------------
  // Determines expected RX byte count for SET CCCs.
  // rx_byte_num counts up from 0: byte 0 is first byte received.
  always_comb begin : proc_set_ccc_rx_byte_total
    // Default value
    rx_byte_total = 2'd1;
    case (command_code)
      // 1 Byte Commands
      CCC_BCAST_ENEC,
      CCC_BCAST_DISEC,
      CCC_DIRECT_ENEC,
      CCC_DIRECT_DISEC,
      CCC_DIRECT_SETDASA,
      CCC_DIRECT_SETNEWDA:   rx_byte_total = 2'd1;
      // 2 Byte Commands
      CCC_BCAST_SETMWL,
      CCC_DIRECT_SETMWL:     rx_byte_total = 2'd2;
      // 3 Byte Commands
      CCC_BCAST_SETMRL,
      CCC_DIRECT_SETMRL:     rx_byte_total = 2'd3;
      default: begin end
    endcase
  end

  // ===========================================================================
  // SETDASA/SETAASA OUTPUT ASSIGNMENTS
  // ===========================================================================
  assign set_dasa_o = set_dasa_addr;
  assign set_dasa_valid_o = set_dasa_valid;
  assign set_dasa_virtual_device_o = target_addr_matches_virt ? set_dasa_valid : 1'b0;
  assign set_aasa_o = set_aasa_valid;
  assign set_aasa_virt_o = set_aasa_virt_valid;

  // ===========================================================================
  // SETNEWDA/ENTDAA OUTPUT MUX
  // ===========================================================================
  // Both SETNEWDA (direct CCC) and ENTDAA (broadcast with sub-FSM) set a new dynamic address.
  // SETNEWDA takes priority since it can't happen simultaneously with ENTDAA.
  assign set_newda_o                = set_newda_valid | entdaa_set_newda;
  assign set_newda_virtual_device_o = set_newda_valid ? target_addr_matches_virt_dyn : entdaa_is_virtual;
  assign newda_o                    = set_newda_valid ? set_newda_addr : entdaa_address;

  // ===========================================================================
  // SET CCC HANDLERS (Broadcast and Direct)
  // ===========================================================================
  // Handles: SETDASA, SETNEWDA, SETMWL, SETMRL, ENEC, DISEC, RSTACT
  // For broadcast CCCs: always process
  // For direct CCCs: only process if addressed to us (not reserved byte)

  // ---------------------------------------------------------------------------
  // Combinational logic: Compute next values for SET CCC registers
  // ---------------------------------------------------------------------------
  always_comb begin : proc_set_ccc_next
    // Default: pulse signals clear, data signals hold
    set_dasa_valid_next   = 1'b0;
    set_dasa_addr_next    = set_dasa_addr;
    set_newda_valid_next  = 1'b0;
    set_newda_addr_next   = set_newda_addr;
    set_mrl_next          = 1'b0;
    mrl_next              = mrl_o;
    set_ibil_next         = 1'b0;
    ibil_next             = ibil_o;
    set_mwl_next          = 1'b0;
    mwl_next              = mwl_o;
    enec_ibi_next         = 1'b0;
    enec_crr_next         = 1'b0;
    enec_hj_next          = 1'b0;
    disec_ibi_next        = 1'b0;
    disec_crr_next        = 1'b0;
    disec_hj_next         = 1'b0;

    // Process received data bytes
    // Note: For Direct CCCs, rx_data_valid only fires when target address matched
    // AND padding bit is valid for DA assignment CCCs.
    // Reserved address (7'h7E) and non-matching addresses never reach the data phase.
    if (rx_data_valid) begin
      case (command_code)
        // -----------------------------------------------------------------
        // Direct CCCs (require target address match)
        // -----------------------------------------------------------------
        CCC_DIRECT_SETDASA: begin
          if (rx_byte_num == 2'd0) begin
            // DA is in Bits[7:1] (Bit[0] padding already validated by FSM)
            set_dasa_addr_next  = rx_data[7:1];
            set_dasa_valid_next = 1'b1;
          end
        end
        CCC_DIRECT_SETNEWDA: begin
          if (rx_byte_num == 2'd0) begin
            // DA is in Bits[7:1] (Bit[0] padding already validated by FSM)
            set_newda_addr_next  = rx_data[7:1];
            set_newda_valid_next = 1'b1;
          end
        end
        CCC_DIRECT_SETMWL: begin
          case (rx_byte_num)
            2'd0: mwl_next[15:8] = rx_data;
            2'd1: begin
              mwl_next[7:0] = rx_data;
              set_mwl_next  = 1'b1;
            end
            default: begin end
          endcase
        end
        CCC_DIRECT_SETMRL: begin
          case (rx_byte_num)
            2'd0: mrl_next[15:8] = rx_data;
            2'd1: begin
              mrl_next[7:0] = rx_data;
              set_mrl_next  = 1'b1;
            end
            2'd2: begin
              ibil_next     = rx_data;
              set_ibil_next = 1'b1;
            end
            default: begin end
          endcase
        end
        CCC_DIRECT_ENEC: begin
          if (rx_byte_num == 2'd0) begin
            enec_ibi_next = rx_data[0];
            enec_crr_next = rx_data[1];
            enec_hj_next  = rx_data[3];
          end
        end
        CCC_DIRECT_DISEC: begin
          if (rx_byte_num == 2'd0) begin
            disec_ibi_next = rx_data[0];
            disec_crr_next = rx_data[1];
            disec_hj_next  = rx_data[3];
          end
        end
        // -----------------------------------------------------------------
        // Broadcast CCCs (always process)
        // -----------------------------------------------------------------
        CCC_BCAST_SETMWL: begin
          case (rx_byte_num)
            2'd0: mwl_next[15:8] = rx_data;
            2'd1: begin
              mwl_next[7:0] = rx_data;
              set_mwl_next  = 1'b1;
            end
            default: begin end
          endcase
        end
        CCC_BCAST_SETMRL: begin
          case (rx_byte_num)
            2'd0: mrl_next[15:8] = rx_data;
            2'd1: begin
              mrl_next[7:0] = rx_data;
              set_mrl_next  = 1'b1;
            end
            2'd2: begin
              ibil_next     = rx_data;
              set_ibil_next = 1'b1;
            end
            default: begin end
          endcase
        end
        CCC_BCAST_ENEC: begin
          if (rx_byte_num == 2'd0) begin
            enec_ibi_next = rx_data[0];
            enec_crr_next = rx_data[1];
            enec_hj_next  = rx_data[3];
          end
        end
        CCC_BCAST_DISEC: begin
          if (rx_byte_num == 2'd0) begin
            disec_ibi_next = rx_data[0];
            disec_crr_next = rx_data[1];
            disec_hj_next  = rx_data[3];
          end
        end
        default: begin end
      endcase
    end

  end

  // ---------------------------------------------------------------------------
  // Sequential logic: Register the next values
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_set_ccc
    if (~rst_ni) begin
      set_dasa_valid   <= 1'b0;
      set_dasa_addr    <= '0;
      set_newda_valid  <= 1'b0;
      set_newda_addr   <= '0;
      set_mrl_o        <= 1'b0;
      mrl_o            <= '0;
      set_ibil_o       <= 1'b0;
      ibil_o           <= '1;
      set_mwl_o        <= 1'b0;
      mwl_o            <= '0;
      enec_ibi         <= '0;
      enec_crr         <= '0;
      enec_hj          <= '0;
      disec_ibi        <= '0;
      disec_crr        <= '0;
      disec_hj         <= '0;
    end else begin
      set_dasa_valid   <= set_dasa_valid_next;
      set_dasa_addr    <= set_dasa_addr_next;
      set_newda_valid  <= set_newda_valid_next;
      set_newda_addr   <= set_newda_addr_next;
      set_mrl_o        <= set_mrl_next;
      mrl_o            <= mrl_next;
      set_ibil_o       <= set_ibil_next;
      ibil_o           <= ibil_next;
      set_mwl_o        <= set_mwl_next;
      mwl_o            <= mwl_next;
      enec_ibi         <= enec_ibi_next;
      enec_crr         <= enec_crr_next;
      enec_hj          <= enec_hj_next;
      disec_ibi        <= disec_ibi_next;
      disec_crr        <= disec_crr_next;
      disec_hj         <= disec_hj_next;
    end
  end

  // ===========================================================================
  // BROADCAST CCC HANDLERS (without data)
  // ===========================================================================
  // Handles RSTDAA, SETAASA (CCCs that complete on command T-bit, no data phase)

  // ---------------------------------------------------------------------------
  // Combinational logic: Compute next values for broadcast CCC registers
  // ---------------------------------------------------------------------------
  always_comb begin : proc_bcast_no_data_ccc_next
    // Default: all pulse signals clear
    rstdaa_next             = 1'b0;
    set_aasa_valid_next     = 1'b0;
    set_aasa_virt_valid_next = 1'b0;

    case (command_code)
      CCC_BCAST_RSTDAA: begin
        // RSTDAA completes after receiving the command T-bit
        if (cmd_tbit_valid) begin
          rstdaa_next = 1'b1;
        end
      end
      // SETAASA: Set All Addresses from Static Address
      // Sets dynamic address = static address if not already assigned
      CCC_BCAST_SETAASA: begin
        if (cmd_tbit_valid) begin
          // Only set if we don't already have a dynamic address
          // and the static address is not in the reserved range
          if (~target_dyn_address_valid_i && ~is_i3c_rsvd_addr(target_sta_address_i)) begin
            set_aasa_valid_next = 1'b1;
          end
          if (~virtual_target_dyn_address_valid_i && ~is_i3c_rsvd_addr(virtual_target_sta_address_i)) begin
            set_aasa_virt_valid_next = 1'b1;
          end
        end
      end
      default: begin end
    endcase
  end

  // ---------------------------------------------------------------------------
  // Sequential logic: Register the next values
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_bcast_no_data_ccc
    if (~rst_ni) begin
      rstdaa_o            <= 1'b0;
      set_aasa_valid      <= 1'b0;
      set_aasa_virt_valid <= 1'b0;
    end else begin
      rstdaa_o            <= rstdaa_next;
      set_aasa_valid      <= set_aasa_valid_next;
      set_aasa_virt_valid <= set_aasa_virt_valid_next;
    end
  end

  // ===========================================================================
  // RSTACT
  // ===========================================================================

  always_comb begin : proc_rstact_comb
    rstact_armed_d    = rstact_armed_q;
    rst_action_d      = rst_action_q;

    // --- Arming: Clear on START (not Repeated START) ---
    // Spec: "Any reset action configured via the RSTACT CCC shall be cleared
    // by the next SCL falling edge following a START (but not by the next
    // Repeated START)."
    if (bus_start_det_i) begin
      rstact_armed_d = 1'b0;
      rst_action_d   = 8'h00;
    end else begin

      case(command_code) 
        CCC_BCAST_RSTACT: begin
          if (def_byte_tbit_valid && (defining_byte inside {8'h00, 8'h01, 8'h02})) begin
            rstact_armed_d = 1'b1;
            rst_action_d   = defining_byte;
          end
        end

        CCC_DIRECT_RSTACT: begin
          if (target_addr_ack_done && addr_ack && ~target_rnw &&
             (defining_byte inside {8'h00, 8'h01, 8'h02})) begin
            rstact_armed_d = 1'b1;
            rst_action_d   = defining_byte;
          end
        end
      endcase

    end
  end


  always_comb begin : proc_escalate_rst_arm_comb
    escalate_rst_arm_d = escalate_rst_arm_q;

    // --- Escalation: Clear on any RSTACT CCC (any format) or GETSTATUS ---
    // FAQ: "receiving the RSTACT CCC in any format will cause the Target to
    // clear any escalation operation that might be in progress even if the
    // Target does not support that Defining Byte value or if the Target NACKs"
    // FAQ: "This state is cleared if the Target sees either any RSTACT CCC, or a
    //       GETSTATUS CCC addressed to it."
    if ((command_code_valid && (command_code == CCC_BCAST_RSTACT)) ||
        (target_addr_ack_done && target_addr_matches_any &&
            ((command_code == CCC_DIRECT_RSTACT) || 
             (command_code == CCC_DIRECT_GETSTATUS)))) begin 
      escalate_rst_arm_d = 1'b0;
    // --- Escalation: Arm after default peripheral reset ---
    // First reset pattern with no armed RSTACT action sets the escalation flag.
    // A second reset pattern (still without RSTACT/GETSTATUS) will then escalate.
    end else if (target_reset_detect_i && ~rstact_armed_q && ~escalate_rst_arm_q) begin
      escalate_rst_arm_d = 1'b1;
    end
  end

  // Armed path, 0x01: peripheral reset on Target Reset Pattern
  // Default path, first reset pattern without RSTACT: peripheral reset
  assign set_peripheral_reset = target_reset_detect_i && (
                                  (rstact_armed_q && (rst_action_q == 8'h01)) ||
                                  (~rstact_armed_q && ~escalate_rst_arm_q));

  // Armed path, 0x02: whole-target reset on Target Reset Pattern
  // Default path, second reset pattern without intervening RSTACT/GETSTATUS: escalate
  assign set_escalate_reset = target_reset_detect_i && (
                                (rstact_armed_q && (rst_action_q == 8'h02)) ||
                                (~rstact_armed_q && escalate_rst_arm_q));
                                

  // ---------------------------------------------------------------------------
  // Sequential logic: RSTACT registers
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_rstact_seq
    if (~rst_ni) begin
      rstact_armed_q     <= 1'b0;
      rst_action_q       <= 8'h00;
      escalate_rst_arm_q <= 1'b0;
      peripheral_reset_o <= 1'b0;
      escalated_reset_o   <= 1'b0;
    end else begin
      rstact_armed_q     <= rstact_armed_d;
      rst_action_q       <= rst_action_d;
      escalate_rst_arm_q <= escalate_rst_arm_d;

      if (set_peripheral_reset) begin
        peripheral_reset_o <= 1'b1;
      end else if (peripheral_reset_done_i) begin
        peripheral_reset_o <= 1'b0;
      end

      if (set_escalate_reset) begin
        escalated_reset_o <= 1'b1;
      end
    end
  end

  assign rst_action_o       = rst_action_q;
  assign rst_action_valid_o = rstact_armed_q;

  // ===========================================================================
  // ENEC/DISEC OUTPUT ASSIGNMENTS
  // ===========================================================================
  // Enable Target event driven interrupts
  assign enec_ibi_o = enec_ibi;
  assign enec_crr_o = enec_crr;
  assign enec_hj_o = enec_hj;

  // Disable Target event driven interrupts
  assign disec_ibi_o = disec_ibi;
  assign disec_crr_o = disec_crr;
  assign disec_hj_o = disec_hj;

  // ===========================================================================
  // UNSUPPORTED/OPTIONAL CCC OUTPUTS (tied to defaults)
  // ===========================================================================
  // FUTUREFIX: Implement these when the following optional CCCs are added:
  // * ENTTM - Enter Test Mode
  // * SETBRGTGT - Set Bridge Targets
  // * ENTAS[0-3] - Enter Activity State
  assign set_brgtgt_o = '0;
  assign entas0_o = '0;
  assign entas1_o = '0;
  assign entas2_o = '0;
  assign entas3_o = '0;
  assign ent_tm_o = '0;
  assign tm_o = '0;

  // ===========================================================================
  // HDR MODE STATE MACHINE
  // ===========================================================================
  // Enter HDR mode when:
  //   - A valid ENTHDR command is received, OR
  //   - TE0 error (invalid reserved address), OR
  //   - TE1 error (CCC command parity error)
  // Exit HDR mode when the exit HDR pattern is detected on the bus.
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_hdr_mode
    if (~rst_ni) begin
      in_hdr_mode <= 1'b0;
    end else begin
      if (enter_hdr_mode || te0_err || te1_err) begin
        in_hdr_mode <= 1'b1;
      end else if (exit_hdr_i) begin
        in_hdr_mode <= 1'b0;
      end
    end
  end

  assign in_hdr_mode_o = in_hdr_mode;

  // Track whether HDR mode was entered due to TE0/TE1 error (not CCC command).
  // Used to gate the optional 60µs recovery timer (I3C spec §5.1.10.1.9).
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_hdr_err_mode
    if (~rst_ni) begin
      in_hdr_err_mode <= 1'b0;
    end else begin
      if (te0_err || te1_err) begin
        in_hdr_err_mode <= 1'b1;
      end else if (exit_hdr_i) begin
        in_hdr_err_mode <= 1'b0;
      end
    end
  end

  assign in_hdr_err_mode_o = in_hdr_err_mode;

  // ===========================================================================
  // ENTDAA SUB-MODULE INSTANTIATION
  // ===========================================================================
  ccc_entdaa xccc_entdaa (
    .clk_i,
    .rst_ni,

    // Device identification
    .id_i (get_pid_i),
    .bcr_i(get_bcr_i),
    .dcr_i(get_dcr_i),

    // Virtual device identification  
    .virtual_id_i (virtual_get_pid_i),
    .virtual_bcr_i(virtual_get_bcr_i),
    .virtual_dcr_i(virtual_get_dcr_i),

    // Control signals
    .start_daa_i(entdaa_o),
    .done_daa_o (entdaa_done),
    .process_virtual_i(entdaa_process_virtual),

    // Bus RX interface
    .bus_rx_req_o(rx_req_entdaa),
    .bus_rx_rsp_i,

    // Bus TX interface
    .bus_tx_req_o(tx_req_entdaa),
    .bus_tx_rsp_i,

    // Bus Monitor interface
    .bus_rstart_det_i,
    .bus_stop_det_i,

    // bus access
    .arbitration_lost_i,

    // addr
    .address_o      (entdaa_address),
    .address_valid_o(entdaa_address_valid),

    // TE3/TE4 detection enables
    .te3_err_det_en_i(te3_err_det_en_i),
    .te4_err_det_en_i(te4_err_det_en_i),

    // TE3 Error: Parity error on dynamic address during ENTDAA
    .te3_err_o(te3_err),

    // TE4 Error: Invalid reserved byte during ENTDAA
    .te4_err_o(te4_err)
  );

`ifndef SYNTHESIS
`ifndef VERILATOR
  // Detect each SETDASA CCC targeted to us while we don't have dynamic address set
  property cover_first_both_dyn_setdasa;
    @(posedge clk_i) ($rose(addr_ack) && (command_code == CCC_DIRECT_SETDASA)) |=>
    ##1 @(posedge bus_rx_rsp_i.done) ##1
    ##1 @(posedge clk_i) ##2
    (
      ($rose(virtual_target_dyn_address_valid_i) ##0 $changed(virtual_target_dyn_address_i)) or
      ($rose(target_dyn_address_valid_i) ##0 $changed(target_dyn_address_i))
    );
  endproperty : cover_first_both_dyn_setdasa
  covprop_first_both_dyn_setdasa: cover property (cover_first_both_dyn_setdasa);

  // Detect each SETDASA CCC targeted to us while we have dynamic address set
  property cover_not_first_both_dyn_setdasa;
    @(posedge clk_i)
    (
      $rose(bus_rx_rsp_i.done) && (command_code == CCC_DIRECT_SETDASA) && command_code_valid &&
      $stable(bus_rx_req_o.req_byte) && bus_rx_req_o.req_byte ##1
      $rose(target_addr_matches_main_sta) || $rose(target_addr_matches_virt_sta)
    ) |=>
    @(posedge bus_rx_rsp_i.done) ##1
    ##1 @(posedge clk_i) ##2
    (
      ($stable(addr_ack) && ~addr_ack) and
      (
        ($stable(virtual_target_dyn_address_valid_i) && virtual_target_dyn_address_valid_i ##0 $stable(virtual_target_dyn_address_i) && virtual_target_dyn_address_i) or
        ($stable(target_dyn_address_valid_i) && target_dyn_address_valid_i ##0 $stable(target_dyn_address_i) && target_dyn_address_i)
      )
    );
  endproperty : cover_not_first_both_dyn_setdasa
  covprop_not_first_both_dyn_setdasa: cover property (cover_not_first_both_dyn_setdasa);

  // Detect each SETAASA CCC while we don't have dynamic address set
  property cover_first_both_dyn_setaasa;
    @(posedge clk_i) $rose(ccc_valid_i) ##1 (command_code == CCC_BCAST_SETAASA) && ~(virtual_target_dyn_address_valid_i & target_dyn_address_valid_i)|=>
    ##1 @(posedge bus_rx_rsp_i.done)
    ##1 @(posedge clk_i) ##2
    (
      ($rose(virtual_target_dyn_address_valid_i) ##0 $changed(virtual_target_dyn_address_i)) or
      ($rose(target_dyn_address_valid_i) ##0 $changed(target_dyn_address_i))
    );
  endproperty : cover_first_both_dyn_setaasa
  covprop_first_both_dyn_setaasa: cover property (cover_first_both_dyn_setaasa);

  // Detect each SETAASA CCC while we have dynamic address set
  property cover_not_first_both_dyn_setaasa;
    @(posedge clk_i) $rose(ccc_valid_i) ##1 (command_code == CCC_BCAST_SETAASA) && (virtual_target_dyn_address_valid_i & target_dyn_address_valid_i)|=>
    ##1 @(posedge bus_rx_rsp_i.done)
    ##1 @(posedge clk_i) ##2
    (
      ($stable(virtual_target_dyn_address_valid_i) ##0 $stable(virtual_target_dyn_address_i)) and
      ($stable(target_dyn_address_valid_i) ##0 $stable(target_dyn_address_i))
    );
  endproperty : cover_not_first_both_dyn_setaasa
  covprop_not_first_both_dyn_setaasa: cover property (cover_not_first_both_dyn_setaasa);

  // Detect each SETDASA CCC targeted to us
  property cover_recv_setdasa;
    @(posedge clk_i)
    (
      command_code_valid && (command_code == CCC_DIRECT_SETDASA) &&
      ($rose(target_addr_matches_main) || $rose(target_addr_matches_virt))
    );
  endproperty : cover_recv_setdasa
  covprop_recv_setdasa: cover property (cover_recv_setdasa);

  // Detect each SETAASA CCC
  property cover_recv_setaasa;
    @(posedge clk_i) ($rose(ccc_valid_i) ##1 (command_code == CCC_BCAST_SETAASA));
  endproperty : cover_recv_setaasa
  covprop_recv_setaasa: cover property (cover_recv_setaasa);
`endif
`endif
endmodule
