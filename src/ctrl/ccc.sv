// SPDX-License-Identifier: Apache-2.0

/*
  This module is responsible for taking actions based on incoming CCC.

  This module implements an FSM which is secondary to the target_fsm.
  The handoff occurs as soon as the target_fsm detected the Command Code.
  All CCC transfers begin with {S|SR, Rsvd Byte, ACK, Command Code}.

  In this context there are references to a "not SR" bus state.
  Between I3C bytes, there is a short period when the Target Device
  does not know if the next symbol will be a Repeated Start or a first
  bit in the next data byte. More specifically, this occurs just after
  ACK/NACK bit or the T-bit transmission.
  In the CCC processing flow, there are a few decisions, which
  depend on whether the next symbol is the SR or the data bit.
  Appearance of the data bit is sometimes referred to as the "not SR"
  bus condition. Signal `det_first_bit` represents this condition.

  Most of the functions of the CCCs can be divided into:
  - retrieve value from CSRs
  - set values in CSRs

  On the lists below, the maximum number of bytes is written down,
  some CCCs are configurable.

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
    - I3C_DIRECT_SETXTIME
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
    input logic clk_i,  // Clock
    input logic rst_ni, // Async reset, active low

    // CC is decoded from the frame by the primary FSM
    input logic [7:0] ccc_i,
    // Assert valid when you want to give control to this FSM
    input logic ccc_valid_i,

    output logic done_fsm_o,

    // Bus Monitor interface
    input logic bus_start_det_i,
    input logic bus_rstart_det_i,
    input logic bus_stop_det_i,

    // Bus TX interface
    input logic bus_tx_done_i,
    output logic bus_tx_req_byte_o,
    output logic bus_tx_req_bit_o,
    output logic [7:0] bus_tx_req_value_o,
    output logic bus_tx_sel_od_pp_o,

    // Bus RX interface
    input logic [7:0] bus_rx_data_i,
    input logic bus_rx_done_i,
    output logic bus_rx_req_bit_o,
    output logic bus_rx_req_byte_o,

    // Addr match interface
    input logic [6:0] target_sta_address_i,
    input logic target_sta_address_valid_i,
    input logic [6:0] target_dyn_address_i,
    input logic target_dyn_address_valid_i,

    // Configuration and status interface
    // Reads from CSRs (inputs) are continuous assignments
    //
    // Writes to CSRs (outputs) need generation of WE signal
    // outside of this module
    //

    // Enable Target event driven interrupts
    output logic enec_ibi_o,
    output logic enec_crr_o,
    output logic enec_hj_o,

    // Disable Target event driven interrupts
    output logic disec_ibi_o,
    output logic disec_crr_o,
    output logic disec_hj_o,

    // Set Activity state 0-3
    output logic entas0_o,
    output logic entas1_o,
    output logic entas2_o,
    output logic entas3_o,

    // Forget current Dynamic Address and wait for new assignment
    output logic rstdaa_o,

    // Controller has started the Dynamic Address Assignment procedure.
    output logic entdaa_o,

    // Define List of Targets
    // I3C_BCAST_DEFTGTS

    // Set Max Write Length
    output logic set_mwl_o,
    output logic [15:0] mwl_o,

    // Set Max Read Length
    output logic set_mrl_o,
    output logic [15:0] mrl_o,

    // Enter Test Mode
    output logic ent_tm_o,
    output logic [7:0] tm_o,

    // Set Bus Context
    // I3C_BCAST_SETBUSCON

    // Data Transfer Ending Procedure Control
    // I3C_BCAST_ENDXFER

    // Enter HDR Mode 0-7
    output logic ent_hdr_0_o,
    output logic ent_hdr_1_o,
    output logic ent_hdr_2_o,
    output logic ent_hdr_3_o,
    output logic ent_hdr_4_o,
    output logic ent_hdr_5_o,
    output logic ent_hdr_6_o,
    output logic ent_hdr_7_o,

    // Exchange Timing Information
    // I3C_BCAST_SETXTIME

    // Set Dynamic Address from Static Address
    output logic [6:0] set_dasa_o,
    output logic set_dasa_valid_o,

    // Target Reset Action
    // I3C_BCAST_RSTACT
    // I3C_DIRECT_RSTACT
    output logic [7:0] rst_action_o,
    output logic       rst_action_valid_o,

    // Define List of Group Address
    // I3C_BCAST_DEFGRPA

    // Reset Group Address
    // I3C_BCAST_RSTGRPA

    // Set Group Address
    // I3C_DIRECT_SETGRPA 8'h9B

    // Multi-Lane Data Transfer Control
    // I3C_BCAST_MLANE

    // Set New Dynamic Address
    // I3C_DIRECT_SETNEWDA
    output logic set_newda_o,
    output logic [6:0] newda_o,

    // Get Max Write Length
    // I3C_DIRECT_GETMWL
    input logic [15:0] get_mwl_i,

    // Get Max Read Length
    // I3C_DIRECT_GETMRL
    input logic [15:0] get_mrl_i,

    // Get Provisioned ID
    // I3C_DIRECT_GETPID
    input logic [47:0] get_pid_i,

    // Get Bus Characteristics Register
    // I3C_DIRECT_GETBCR
    input logic [7:0] get_bcr_i,

    // Get Device Characteristics Register
    // I3C_DIRECT_GETDCR
    input logic [7:0] get_dcr_i,

    // Get Device Status
    // [15:8] Reserved for vendor-specific meaning, expected to be unused.
    // TODO: Bits 7:6 are tied to '11 until the Handoff procedure is fully implemented.
    // TODO: Bit 5: connect to protocol error
    // TODO: Bits 3:0: connect to number of pending interrupts
    input logic [15:0] get_status_fmt1_i,
    output logic get_status_done_o,
    // TODO: GETSTATUS: Format 2

    // Get Accept Controller Role
    // I3C_DIRECT_GETACCCR
    input logic get_acccr_i,

    // Set Bridge Targets
    // I3C_DIRECT_SETBRGTGT
    output logic set_brgtgt_o,

    // Get Max Data Speed
    // I3C_DIRECT_GETMXDS
    input logic get_mxds_i,

    // (formerly GETHDRCAPS) Get Optional Feature Capabilities
    // I3C_DIRECT_GETCAPS

    // Set Route
    // I3C_DIRECT_SETROUTE

    // Device to Device(s) Tunneling Control
    // I3C_DIRECT_D2DXFER

    // Set Exchange Timing Information
    // I3C_DIRECT_SETXTIME

    // Get Exchange Timing Information
    // I3C_DIRECT_GETXTIME

    input  logic target_reset_detect_i,
    input  logic peripheral_reset_done_i,
    output logic rstact_armed_o,
    output logic escalate_reset_o
);
  logic [7:0] rst_action;
  logic       rst_action_valid;

  // Data structure for any CCC
  logic [7:0] command_code;
  // logic [7:0] defining_byte;
  // logic       defining_byte_valid;
  // logic [7:0] subcommand_byte;
  // logic       subcommand_byte_valid;
  // logic [7:0] command_data[6];
  // logic       command_data_valid[6];
  logic [6:0] command_addr;
  logic       command_rnw;
  logic       command_valid;

  logic [7:0] tx_data;
  logic [7:0] tx_data_id;  // This register must hold the maximum number of bytes used by a CCC
  logic [7:0] tx_data_id_init;
  logic       tx_data_done;

  logic [7:0] rx_data;

  logic       last_tbit;
  logic       last_tbit_valid;

  logic       set_dasa_valid;
  logic [6:0] set_dasa_addr;
  logic       set_aasa_valid;
  logic [6:0] set_aasa_addr;

  logic       get_status_in_progress;

  always_ff @(posedge clk_i or negedge rst_ni) begin : report_get_status_done
    if (~rst_ni) begin
      get_status_in_progress <= '0;
      get_status_done_o <= '0;
    end else begin
      if (done_fsm_o) get_status_in_progress <= 1'b0;
      else if ((command_code == `I3C_DIRECT_GETSTATUS) && ccc_valid_i)
        get_status_in_progress <= 1'b1;

      if (get_status_in_progress & done_fsm_o) get_status_done_o <= 1'b1;
      else get_status_done_o <= 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : register_ccc
    if (~rst_ni) begin
      command_code <= '0;
    end else begin
      if (ccc_valid_i) begin
        command_code <= ccc_i;
      end
    end
  end

  logic have_defining_byte;
  always_comb begin : defining_byte_ccc
    case (command_code)
      `I3C_BCAST_ENDXFER: have_defining_byte = 1'b1;
      `I3C_BCAST_RSTACT: have_defining_byte = 1'b1;
      `I3C_BCAST_MLANE: have_defining_byte = 1'b1;
      `I3C_DIRECT_ENDXFER: have_defining_byte = 1'b1;
      `I3C_DIRECT_RSTACT: have_defining_byte = 1'b1;
      default: have_defining_byte = '0;
    endcase
  end

  // TODO: Handle Bcast CCCs
  typedef enum logic [7:0] {
    Idle,
    WaitCCC,
    RxTbit,
    RxDefByte,
    RxDefByteTbit,
    RxByte,
    RxDirectDefByteTbit,
    RxDirectAddr,
    TxDirectAddrAck,
    RxSubCmdByte,
    RxData,
    RxDataTbit,
    TxData,
    TxDataTbit,
    WaitForBusCond,
    WaitForStop,
    DoneCCC
  } state_e;

  state_e state_q, state_d;

  assign last_tbit_valid = (state_q == RxTbit || state_q == RxDataTbit) && bus_rx_done_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin : register_tbit
    if (~rst_ni) begin
      last_tbit <= '0;
    end else begin
      if (last_tbit_valid) begin
        last_tbit <= rx_data[7];
      end
    end
  end

  logic [7:0] defining_byte;
  always_ff @(posedge clk_i or negedge rst_ni) begin : register_defining_byte
    if (~rst_ni) defining_byte <= '0;
    else if (state_q == RxDefByte && bus_rx_done_i) begin
      defining_byte <= bus_rx_data_i;
    end
  end

  logic is_direct_cmd;
  assign is_direct_cmd = command_code[7];  // 0 - BCast, 1 - Direct

  logic is_byte_rsvd_addr;
  assign is_byte_rsvd_addr = (rx_data == {7'h7E, 1'b0}) | (command_addr == 7'h7E);

  logic is_byte_our_addr;

  logic [7:0] rx_data_count;

  always_comb begin : addr_matching
    if (target_dyn_address_valid_i) begin
      is_byte_our_addr = command_addr == target_dyn_address_i;
    end else if (target_sta_address_valid_i) begin
      is_byte_our_addr = command_addr == target_sta_address_i;
    end else begin
      is_byte_our_addr = '0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_addr
    if (~rst_ni) begin
      command_addr  <= '0;
      command_rnw   <= '0;
      command_valid <= '0;
    end else begin
      if (state_q == RxDirectAddr && bus_rx_done_i) begin
        command_addr  <= bus_rx_data_i[7:1];
        command_rnw   <= bus_rx_data_i[0];
        command_valid <= 1'b1;
      end else begin
        command_valid <= 1'b0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_rx_data
    if (~rst_ni) begin
      rx_data <= '0;
    end else begin
      if (state_q == RxData && bus_rx_done_i) begin
        rx_data <= bus_rx_data_i;
      end
    end
  end

  always_comb begin : state_functions
    state_d = state_q;
    unique case (state_q)
      Idle: begin
        state_d = WaitCCC;
      end
      WaitCCC: begin
        if (ccc_valid_i) state_d = RxTbit;
      end
      RxTbit: begin
        if (bus_rx_done_i) begin
          // have defining byte
          if (have_defining_byte) state_d = RxDefByte;
          else begin
            // broadcast CCCs
            if (~is_direct_cmd) state_d = RxData;
            // direct CCCs
            else
              state_d = RxByte;
          end
        end
      end
      RxDefByte: begin
        if (bus_rx_done_i) state_d = RxDefByteTbit;
      end
      RxDefByteTbit: begin
        if (bus_rx_done_i) begin
          // broadcast CCCs
          if (~is_direct_cmd) state_d = RxData;
          // direct CCCs
          else
            state_d = RxByte;
        end
      end
      RxByte: begin
        if (bus_rstart_det_i) state_d = RxDirectAddr;
        else if (bus_rx_done_i) state_d = RxDirectDefByteTbit;
      end
      RxDirectDefByteTbit: begin
        if (bus_rx_done_i) begin
          state_d = RxByte;
        end
      end
      RxDirectAddr: begin
        if (bus_rx_done_i) begin
          state_d = TxDirectAddrAck;
        end
      end
      TxDirectAddrAck: begin
        if (bus_tx_done_i) begin
          if (is_byte_rsvd_addr) state_d = WaitForStop;
          else if (is_byte_our_addr && command_rnw) state_d = TxData;
          else if (is_byte_our_addr && ~command_rnw) begin
            if (command_code == `I3C_DIRECT_SETXTIME) state_d = RxSubCmdByte;
            else state_d = RxData;
          end else state_d = WaitForBusCond;
        end
      end

      // TODO: Add support for Sub Cmd Byte
      RxSubCmdByte: begin
        state_d = Idle;
      end

      RxData: begin
        if (bus_rstart_det_i) state_d = RxDirectAddr;
        else if (bus_rx_done_i) state_d = RxDataTbit;
      end
      RxDataTbit: begin
        if (bus_rx_done_i) state_d = RxData;
      end

      TxData: begin
        if (bus_rstart_det_i) state_d = RxDirectAddr;
        else if (bus_tx_done_i) state_d = TxDataTbit;
      end
      TxDataTbit: begin
        if (bus_tx_done_i)
          if (tx_data_done) state_d = WaitForBusCond;
          else state_d = TxData;
      end
      WaitForBusCond: begin
        if (bus_rstart_det_i) state_d = RxDirectAddr;
      end
      WaitForStop: begin
        state_d = WaitForStop; // Bus stop always goes to DoneCCC
      end
      DoneCCC: begin
        state_d = Idle;
      end
      default: begin
      end
    endcase
  end


  always_comb begin : state_outputs
    bus_rx_req_bit_o = '0;
    bus_rx_req_byte_o = '0;

    bus_tx_req_byte_o = '0;
    bus_tx_req_bit_o = '0;
    bus_tx_req_value_o = '0;
    bus_tx_sel_od_pp_o = '0;

    done_fsm_o = '0;
    unique case (state_q)
      Idle: begin

      end
      WaitCCC: begin

      end
      RxTbit: begin
        bus_rx_req_bit_o  = '1;
        bus_rx_req_byte_o = '0;
      end
      RxDefByte: begin
        bus_rx_req_bit_o  = '0;
        bus_rx_req_byte_o = '1;
      end
      RxDefByteTbit: begin
        bus_rx_req_bit_o  = '1;
        bus_rx_req_byte_o = '0;
      end
      RxByte: begin
        bus_rx_req_bit_o  = '0;
        bus_rx_req_byte_o = '1;
        if (bus_rstart_det_i) bus_rx_req_byte_o = '0;
      end
      RxDirectDefByteTbit: begin
        bus_rx_req_bit_o  = '1;
        bus_rx_req_byte_o = '0;
      end
      RxDirectAddr: begin
        bus_rx_req_bit_o  = '0;
        bus_rx_req_byte_o = '1;
      end
      TxDirectAddrAck: begin
        bus_tx_req_byte_o  = '0;
        bus_tx_req_bit_o   = '1;
        bus_tx_req_value_o = {7'h00, ~(is_byte_our_addr | is_byte_rsvd_addr)};
      end
      RxSubCmdByte: begin
      end
      RxData: begin
        bus_rx_req_bit_o  = '0;
        bus_rx_req_byte_o = '1;
        if (bus_rstart_det_i) bus_rx_req_byte_o = '0;
      end
      RxDataTbit: begin
        bus_rx_req_bit_o  = '1;
        bus_rx_req_byte_o = '0;
      end
      TxData: begin
        bus_tx_req_byte_o  = '1;
        bus_tx_req_bit_o   = '0;
        bus_tx_req_value_o = tx_data;
        bus_tx_sel_od_pp_o = '1;
      end
      TxDataTbit: begin
        bus_tx_req_byte_o  = '0;
        bus_tx_req_bit_o   = '1;
        bus_tx_req_value_o = {7'h00, ~tx_data_done};
        bus_tx_sel_od_pp_o = '1;
      end
      DoneCCC: begin
        done_fsm_o = '1;
      end
      default: begin
      end
    endcase
  end
  // Synchronous state transition
  always_ff @(posedge clk_i or negedge rst_ni) begin : state_transition
    if (!rst_ni) begin
      state_q <= Idle;
    end else begin
      if (bus_stop_det_i) state_q <= DoneCCC;
      else state_q <= state_d;
    end
  end

  // GET interface handler
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_tx_data_id
    if (~rst_ni) begin
      tx_data_id <= '0;
    end else begin
      if (state_q == TxDirectAddrAck) tx_data_id <= tx_data_id_init;
      else if (state_q == TxData && bus_tx_done_i) tx_data_id <= tx_data_id - 1'b1;
      else if (state_q == RxTbit) tx_data_id <= tx_data_id_init;
      else tx_data_id <= tx_data_id;
    end
  end

  // GET data counter
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      rx_data_count <= '0;
    end else if (state_q == WaitCCC && ccc_valid_i) begin
      rx_data_count <= '0;
    end else if (state_q == RxDirectAddr && bus_rx_done_i) begin
      rx_data_count <= '0;
    end else if (state_q == RxDataTbit && bus_rx_done_i) begin
      rx_data_count <= rx_data_count + 1'b1;
    end
  end

  // Done, no more bytes to send in this CCC
  assign tx_data_done = tx_data_id == 8'h00;

  // Handle all DIRECT GET CCCs
  always_comb begin : proc_get
    case (command_code)
      // 1 Byte
      `I3C_DIRECT_GETBCR: begin
        tx_data_id_init = 8'h01;
        if (tx_data_id == 8'h01) tx_data = get_bcr_i;
      end
      `I3C_DIRECT_GETDCR: begin
        tx_data_id_init = 8'h01;
        if (tx_data_id == 8'h01) tx_data = get_dcr_i;
      end
      // 2 Bytes
      `I3C_DIRECT_GETSTATUS: begin
        tx_data_id_init = 8'h02;
        if (tx_data_id == 8'h02) tx_data = get_status_fmt1_i[15:8];
        else if (tx_data_id == 8'h01) tx_data = get_status_fmt1_i[7:0];
      end
      `I3C_DIRECT_GETMWL: begin
        tx_data_id_init = 8'h02;
        if (tx_data_id == 8'h02) tx_data = get_mwl_i[15:8];
        else if (tx_data_id == 8'h01) tx_data = get_mwl_i[7:0];
      end
      // 3 Bytes
      `I3C_DIRECT_GETMRL: begin
        tx_data_id_init = 8'h03;
        if (tx_data_id == 8'h03) tx_data = get_mrl_i[15:8];
        else if (tx_data_id == 8'h02) tx_data = get_mrl_i[7:0];
        else if (tx_data_id == 8'h01)
          // Maximum IBI payload size is 256 Bytes
          tx_data = '1;
      end
      `I3C_DIRECT_GETPID: begin
        tx_data_id_init = 8'h06;
        if (tx_data_id == 8'h06) tx_data = get_pid_i[47:40];
        else if (tx_data_id == 8'h05) tx_data = get_pid_i[39:32];
        else if (tx_data_id == 8'h04) tx_data = get_pid_i[31:24];
        else if (tx_data_id == 8'h03) tx_data = get_pid_i[23:16];
        else if (tx_data_id == 8'h02) tx_data = get_pid_i[15:8];
        else if (tx_data_id == 8'h01) tx_data = get_pid_i[7:0];
      end
      default: begin
        tx_data_id_init = 8'h00;
        tx_data = '0;
      end
    endcase
  end

  // Connect dynamic address setter mux
  always_comb begin : dyn_addr_set_mux
    set_dasa_valid_o = set_aasa_valid ? set_aasa_valid : set_dasa_valid;
    set_dasa_o = set_aasa_valid ? set_aasa_addr : set_dasa_addr;
  end

  // Handle DIRECT SET CCCs
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_set_direct
    if (~rst_ni) begin
      set_dasa_valid <= 1'b0;
      set_dasa_addr  <= '0;
    end else begin
      case (command_code)
        // setdasa has only one data byte - dynamic address
        `I3C_DIRECT_SETDASA: begin
          if (state_q == RxDataTbit && bus_rx_done_i && ~is_byte_rsvd_addr &&
              rx_data_count == 8'd0) begin
            set_dasa_addr  <= rx_data[7:1];
            set_dasa_valid <= 1'b1;
          end else begin
            set_dasa_valid <= 1'b0;
          end
        end
        default: begin
        end
      endcase
    end
  end

  logic enec_ibi;
  logic enec_crr;
  logic enec_hj;

  logic disec_ibi;
  logic disec_crr;
  logic disec_hj;

  // Handle Broadcast/Direct SET CCCs
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_set_direct_bcast
    if (~rst_ni) begin
      set_mrl_o        <= 1'b0;
      mrl_o            <= '0;
      set_mwl_o        <= 1'b0;
      mwl_o            <= '0;
      enec_ibi         <= '0;
      enec_crr         <= '0;
      enec_hj          <= '0;
      disec_ibi        <= '0;
      disec_crr        <= '0;
      disec_hj         <= '0;
      rst_action_valid <= 1'b0;
    end else begin
      case (command_code)
        // setmwl
        `I3C_DIRECT_SETMWL, `I3C_BCAST_SETMWL: begin
          if (state_q == RxDataTbit && bus_rx_done_i && ~is_byte_rsvd_addr) begin
            if (rx_data_count == 8'd0) begin
              mwl_o[15:8] <= rx_data;
              set_mwl_o   <= 1'b0;
            end else if (rx_data_count == 8'd1) begin
              mwl_o[7:0] <= rx_data;
              set_mwl_o  <= 1'b1;
            end else begin
              set_mwl_o <= 1'b0;
            end
          end else begin
            set_mwl_o <= 1'b0;
          end
        end
        // setmrl
        `I3C_DIRECT_SETMRL, `I3C_BCAST_SETMRL: begin
          if (state_q == RxDataTbit && bus_rx_done_i && ~is_byte_rsvd_addr) begin
            if (rx_data_count == 8'd0) begin
              mrl_o[15:8] <= rx_data;
              set_mrl_o   <= 1'b0;
            end else if (rx_data_count == 8'd1) begin
              mrl_o[7:0] <= rx_data;
              set_mrl_o  <= 1'b1;
            end else begin
              set_mrl_o <= 1'b0;
            end
          end else begin
            set_mrl_o <= 1'b0;
          end
        end
        // enec
        `I3C_DIRECT_ENEC, `I3C_BCAST_ENEC: begin
          if (state_q == RxDataTbit && bus_rx_done_i && ~is_byte_rsvd_addr) begin
            if (rx_data_count == 8'd0) begin
              enec_ibi <= rx_data[0];
              enec_crr <= rx_data[1];
              enec_hj  <= rx_data[3];
            end
          end
        end
        // disec
        `I3C_DIRECT_DISEC, `I3C_BCAST_DISEC: begin
          if (state_q == RxDataTbit && bus_rx_done_i && ~is_byte_rsvd_addr) begin
            if (rx_data_count == 8'd0) begin
              disec_ibi <= rx_data[0];
              disec_crr <= rx_data[1];
              disec_hj  <= rx_data[3];
            end
          end
        end
        // rstact (direct)
        `I3C_DIRECT_RSTACT: begin
          if (command_valid && is_byte_our_addr) begin
            rst_action_valid <= 1'b1;
          end else begin
            rst_action_valid <= 1'b0;
          end
        end
        // rstact (broadcast)
        `I3C_BCAST_RSTACT: begin
          if (state_q == RxDefByteTbit && bus_rx_done_i && ~is_byte_rsvd_addr) begin
            rst_action_valid <= 1'b1;
          end else begin
            rst_action_valid <= 1'b0;
          end
        end
        default: begin
        end
      endcase
    end
  end

  // Handle Broadcast CCCs without data
  always_ff @(posedge clk_i or negedge rst_ni) begin : bcast_ccc
    if (~rst_ni) begin
      rstdaa_o <= '0;
      set_aasa_addr <= '0;
      set_aasa_valid <= 1'b0;
    end else begin
      case (command_code)
        `I3C_BCAST_RSTDAA: begin
          if (state_q == RxTbit && bus_rx_done_i) begin
            rstdaa_o <= '1;
          end else begin
            rstdaa_o <= '0;
          end
        end
        // set static address as dynamic
        // we reuse the SETDASA path here, just set static addr as the one to
        // be set
        `I3C_BCAST_SETAASA: begin
          if (state_q == RxTbit && bus_rx_done_i) begin
            set_aasa_addr  <= target_sta_address_i;
            set_aasa_valid <= 1'b1;
          end else begin
            set_aasa_valid <= 1'b0;
          end
        end
        default: begin
        end
      endcase
    end
  end

  logic rstact_armed;
  always_ff @(posedge clk_i or negedge rst_ni) begin : rst_action_internal
    if (~rst_ni) begin
      rstact_armed <= '0;
      rst_action   <= '0;
    end else begin
      if (rst_action_valid) begin
        rstact_armed <= 1'b1;
        rst_action   <= defining_byte;
      end

      if (bus_start_det_i) begin
        rstact_armed <= '0;
        rst_action   <= '0;
      end
    end
  end

  assign rstact_armed_o = rstact_armed;
  always_ff @(posedge clk_i or negedge rst_ni) begin : rst_action_outputs
    if (~rst_ni) begin
      rst_action_valid_o <= '0;
      rst_action_o <= '0;
    end else begin
      if (rstact_armed & target_reset_detect_i) begin
        rst_action_valid_o <= 1'b1;
        rst_action_o <= rst_action;
      end

      if (bus_start_det_i) begin
        rst_action_valid_o <= '0;
        rst_action_o <= '0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : choose_reset_type
    if (~rst_ni) begin
      escalate_reset_o <= '0;
    end else begin
      if (peripheral_reset_done_i) escalate_reset_o <= '1;
      if (command_code inside {`I3C_DIRECT_RSTACT, `I3C_BCAST_RSTACT, `I3C_DIRECT_GETSTATUS} &
          ccc_valid_i)
        escalate_reset_o <= '0;
    end
  end

  // Enable Target event driven interrupts
  assign enec_ibi_o = enec_ibi;
  assign enec_crr_o = enec_crr;
  assign enec_hj_o = enec_hj;

  // Disable Target event driven interrupts
  assign disec_ibi_o = disec_ibi;
  assign disec_crr_o = disec_crr;
  assign disec_hj_o = disec_hj;

  // FIXME: Implement outputs
  assign set_brgtgt_o = '0;
  assign entas0_o = '0;
  assign entas1_o = '0;
  assign entas2_o = '0;
  assign entas3_o = '0;
  assign entdaa_o = '0;
  assign ent_tm_o = '0;
  assign tm_o = '0;
  assign ent_hdr_0_o = '0;
  assign ent_hdr_1_o = '0;
  assign ent_hdr_2_o = '0;
  assign ent_hdr_3_o = '0;
  assign ent_hdr_4_o = '0;
  assign ent_hdr_5_o = '0;
  assign ent_hdr_6_o = '0;
  assign ent_hdr_7_o = '0;
  assign set_newda_o = '0;
  assign newda_o = '0;

endmodule
