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
    output logic next_ccc_o,

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
    input logic arbitration_lost_i,

    // Addr match interface
    input logic [6:0] target_sta_address_i,
    input logic target_sta_address_valid_i,
    input logic [6:0] target_dyn_address_i,
    input logic target_dyn_address_valid_i,
    input logic [6:0] virtual_target_sta_address_i,
    input logic virtual_target_sta_address_valid_i,
    input logic [6:0] virtual_target_dyn_address_i,
    input logic virtual_target_dyn_address_valid_i,

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

    // Set Max Read Length
    output logic set_ibil_o,
    output logic [7:0] ibil_o,

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
    output logic set_dasa_virtual_device_o,
    output logic set_aasa_o,
    output logic set_aasa_virt_o,

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
    // those ouptuts are also used by ENTDAA
    output logic set_newda_o,
    output logic set_newda_virtual_device_o,
    output logic [6:0] newda_o,

    // Get Max Write Length
    // I3C_DIRECT_GETMWL
    input logic [15:0] get_mwl_i,

    // Get Max Read Length
    // I3C_DIRECT_GETMRL
    input logic [15:0] get_mrl_i,

    // Get Max IBI Length
    // I3C_DIRECT_GETMRL
    input logic [7:0] get_ibil_i,

    // Get Provisioned ID
    // I3C_DIRECT_GETPID
    input logic [47:0] get_pid_i,

    // Get Bus Characteristics Register
    // I3C_DIRECT_GETBCR
    input logic [7:0] get_bcr_i,

    // Get Device Characteristics Register
    // I3C_DIRECT_GETDCR
    input logic [7:0] get_dcr_i,

    // Get virtual device Provisioned ID
    // I3C_DIRECT_GETPID
    input logic [47:0] virtual_get_pid_i,

    // Get virtual device Bus Characteristics Register
    // I3C_DIRECT_GETBCR
    input logic [7:0] virtual_get_bcr_i,

    // Get virtual Device Characteristics Register
    // I3C_DIRECT_GETDCR
    input logic [7:0] virtual_get_dcr_i,

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
  logic       set_aasa_virt_valid;

  logic       set_newda_valid;
  logic [6:0] set_newda_addr;
  logic entdaa_addres_valid;
  logic [6:0] entdaa_address;
  logic entdaa_process_virtual;

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

  // Mux TX access between regular CCC and ENTDAA
  logic entdaa_tx_req_bit;
  logic entdaa_tx_req_byte;
  logic [7:0] entdaa_tx_req_value;
  logic entdaa_tx_sel_od_pp;
  logic entdaa_rx_req_bit;
  logic entdaa_rx_req_byte;
  logic ccc_tx_req_bit;
  logic ccc_tx_req_byte;
  logic [7:0] ccc_tx_req_value;
  logic ccc_tx_sel_od_pp;
  logic ccc_rx_req_bit;
  logic ccc_rx_req_byte;

  always_comb begin: mux_bus_access
    bus_tx_req_bit_o = entdaa_o ? entdaa_tx_req_bit : ccc_tx_req_bit;
    bus_tx_req_byte_o = entdaa_o ? entdaa_tx_req_byte : ccc_tx_req_byte;
    bus_tx_req_value_o = entdaa_o ? entdaa_tx_req_value : ccc_tx_req_value;
    bus_tx_sel_od_pp_o = entdaa_o ? entdaa_tx_sel_od_pp : ccc_tx_sel_od_pp;
    bus_rx_req_bit_o = entdaa_o ? entdaa_rx_req_bit : ccc_rx_req_bit;
    bus_rx_req_byte_o = entdaa_o ? entdaa_rx_req_byte : ccc_rx_req_byte;
  end

  logic have_defining_byte;
  always_comb begin : defining_byte_ccc
    case (command_code)
      `I3C_BCAST_ENDXFER: have_defining_byte = 1'b1;
      `I3C_BCAST_RSTACT: have_defining_byte = 1'b1;
      `I3C_BCAST_MLANE: have_defining_byte = 1'b1;
      `I3C_DIRECT_GETCAPS: have_defining_byte = 1'b1;
      `I3C_DIRECT_ENDXFER: have_defining_byte = 1'b1;
      `I3C_DIRECT_RSTACT: have_defining_byte = 1'b1;
      default: have_defining_byte = '0;
    endcase
  end

  typedef enum logic [7:0] {
    Idle,
    WaitCCC,
    RxTbit,
    RxDefByte,
    RxDefByteOrBusCond,
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
    NextCCC,
    DoneCCC,
    HandleENTDAA,
    HandleTargetENTDAA,
    HandleVirtualTargetENTDAA
  } state_e;

  state_e state_q, state_d;

  assign last_tbit_valid = (state_q == RxTbit || state_q == RxDataTbit) && bus_rx_done_i;
  assign entdaa_o = (state_q == HandleENTDAA || state_q == HandleTargetENTDAA || state_q == HandleVirtualTargetENTDAA);
  assign entdaa_process_virtual = (state_q == HandleVirtualTargetENTDAA);

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
  logic       valid_defining_byte;
  always_ff @(posedge clk_i or negedge rst_ni) begin : register_defining_byte
    if (~rst_ni) begin
      defining_byte <= '0;
      valid_defining_byte <= '0;
    end else if ((state_q == RxDefByte || state_q == RxDefByteOrBusCond) && bus_rx_done_i) begin
      defining_byte <= bus_rx_data_i;
      valid_defining_byte <= '1;
    end else if (state_q == RxDefByteOrBusCond && bus_rstart_det_i) begin
      defining_byte <= '0;
      valid_defining_byte <= '0;
    end
  end

  logic is_direct_cmd;
  assign is_direct_cmd = command_code[7];  // 0 - BCast, 1 - Direct

  logic is_byte_rsvd_addr;
  assign is_byte_rsvd_addr = (rx_data == {7'h7E, 1'b0}) | (command_addr == 7'h7E);

  logic is_byte_our_dynamic_addr;
  logic is_byte_our_virtual_dynamic_addr;
  logic is_byte_our_static_addr;
  logic is_byte_our_virtual_static_addr;
  logic is_byte_our_addr;
  logic is_byte_virtual_addr;

  logic [7:0] rx_data_count;

  logic entdaa_start, entdaa_done;

  assign is_byte_our_dynamic_addr = ((command_addr == target_dyn_address_i) && target_dyn_address_valid_i);
  assign is_byte_our_static_addr = ((command_addr == target_sta_address_i) && target_sta_address_valid_i);
  assign is_byte_our_addr = is_byte_our_dynamic_addr | is_byte_our_static_addr;

  assign is_byte_our_virtual_dynamic_addr = ((command_addr == virtual_target_dyn_address_i) && virtual_target_dyn_address_valid_i);
  assign is_byte_our_virtual_static_addr = ((command_addr == virtual_target_sta_address_i) && virtual_target_sta_address_valid_i);
  assign is_byte_virtual_addr = is_byte_our_virtual_dynamic_addr | is_byte_our_virtual_static_addr;

  logic supported_direct_command_code;

  assign supported_direct_command_code = command_code inside {
    // Setters
    `I3C_DIRECT_SETDASA,
    `I3C_DIRECT_SETNEWDA,
    `I3C_DIRECT_SETXTIME,
    `I3C_DIRECT_SETMWL,
    `I3C_DIRECT_SETMRL,
    `I3C_DIRECT_ENEC,
    `I3C_DIRECT_DISEC,
    // Getters
    `I3C_DIRECT_GETBCR,
    `I3C_DIRECT_GETDCR,
    `I3C_DIRECT_RSTACT,
    `I3C_DIRECT_GETSTATUS,
    `I3C_DIRECT_GETMWL,
    `I3C_DIRECT_GETMRL,
    `I3C_DIRECT_GETPID,
    `I3C_DIRECT_GETCAPS
  };

  logic unsupported_def_byte;

  assign unsupported_def_byte = have_defining_byte & valid_defining_byte & (
        (command_code == `I3C_DIRECT_RSTACT) & ~(defining_byte inside {8'h00, 8'h01, 8'h02, 8'h81, 8'h82})
      | (command_code == `I3C_DIRECT_GETCAPS));

  logic supported_direct_command;
  assign supported_direct_command = supported_direct_command_code & ~unsupported_def_byte;

  logic direct_addr_ack;

  assign direct_addr_ack = (command_code == `I3C_DIRECT_SETDASA) ?
      ((is_byte_our_static_addr && ~target_dyn_address_valid_i) | (is_byte_our_virtual_static_addr && ~virtual_target_dyn_address_valid_i)) :
      ((is_byte_our_addr | is_byte_virtual_addr) & supported_direct_command  | is_byte_rsvd_addr );

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
          if (have_defining_byte && command_code == `I3C_DIRECT_GETCAPS) state_d = RxDefByteOrBusCond;
          else if (have_defining_byte) state_d = RxDefByte;
          else begin
            // ENTDAA is special
            if (command_code == `I3C_BCAST_ENTDAA) begin
              // ignore ENTDAA if we already have dynamic addresses
              if (~target_dyn_address_valid_i || ~virtual_target_dyn_address_valid_i) begin
                state_d = HandleENTDAA;
              end else begin
                state_d = Idle;
              end
            end
            // broadcast CCCs
            else if (~is_direct_cmd) state_d = RxData;
            // direct CCCs
            else state_d = RxByte;
          end
        end
      end
      HandleENTDAA: begin
        // First get target dynamic address
        if (~target_dyn_address_valid_i) begin
          state_d = HandleTargetENTDAA;
        // then vitual device dynamic address
        end else if (~virtual_target_dyn_address_valid_i) begin
          state_d = HandleVirtualTargetENTDAA;
        end else begin
          state_d = Idle;
        end
      end
      HandleTargetENTDAA: begin
        if (entdaa_done) begin
          if (~virtual_target_dyn_address_valid_i) begin
            state_d = HandleVirtualTargetENTDAA;
          end else begin
            state_d = Idle;
          end
        end
      end
      HandleVirtualTargetENTDAA: begin
        if (entdaa_done) begin
          state_d = Idle;
        end
      end
      RxDefByte: begin
        if (bus_rx_done_i) state_d = RxDefByteTbit;
      end
      RxDefByteOrBusCond: begin
        if (bus_rstart_det_i) state_d = RxDirectAddr;
        else if (bus_rx_done_i) state_d = RxDefByteTbit;
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
          if (command_code == `I3C_DIRECT_SETDASA) begin
            if (is_byte_our_static_addr && target_dyn_address_valid_i) state_d = WaitForBusCond;
            else if (is_byte_our_virtual_static_addr && virtual_target_dyn_address_valid_i) state_d = WaitForBusCond;
            else if (is_byte_our_virtual_static_addr || is_byte_our_static_addr) state_d = RxData;
            else state_d = WaitForBusCond;
          end
          else begin
            if (is_byte_rsvd_addr) state_d = NextCCC;
            else if ((is_byte_our_addr || is_byte_virtual_addr) && command_rnw && supported_direct_command) state_d = TxData;
            else if ((is_byte_our_addr || is_byte_virtual_addr) && ~command_rnw && supported_direct_command) begin
              if (command_code == `I3C_DIRECT_SETXTIME) state_d = RxSubCmdByte;
              else state_d = RxData;
            end else state_d = WaitForBusCond;
          end
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
        if (bus_rstart_det_i) state_d = RxDirectAddr;
        else if (bus_tx_done_i)
          if (tx_data_done) state_d = WaitForBusCond;
          else state_d = TxData;
      end
      WaitForBusCond: begin
        if (bus_rstart_det_i) state_d = RxDirectAddr;
      end
      NextCCC: begin
        state_d = WaitCCC; // Bus stop always goes to DoneCCC
      end
      DoneCCC: begin
        state_d = Idle;
      end
      default: begin
      end
    endcase
  end


  always_comb begin : state_outputs
    ccc_rx_req_bit = '0;
    ccc_rx_req_byte = '0;

    ccc_tx_req_byte = '0;
    ccc_tx_req_bit = '0;
    ccc_tx_req_value = '0;
    ccc_tx_sel_od_pp = '0;

    done_fsm_o = '0;
    next_ccc_o = '0;
    unique case (state_q)
      Idle: begin

      end
      WaitCCC: begin

      end
      RxTbit: begin
        ccc_rx_req_bit  = '1;
        ccc_rx_req_byte = '0;
      end
      RxDefByte: begin
        ccc_rx_req_bit  = '0;
        ccc_rx_req_byte = '1;
      end
      RxDefByteOrBusCond: begin
        ccc_rx_req_bit  = '0;
        ccc_rx_req_byte = '1;
        if (bus_rstart_det_i) ccc_rx_req_byte = '0;
      end
      RxDefByteTbit: begin
        ccc_rx_req_bit  = '1;
        ccc_rx_req_byte = '0;
      end
      RxByte: begin
        ccc_rx_req_bit  = '0;
        ccc_rx_req_byte = '1;
        if (bus_rstart_det_i) ccc_rx_req_byte = '0;
      end
      RxDirectDefByteTbit: begin
        ccc_rx_req_bit  = '1;
        ccc_rx_req_byte = '0;
      end
      RxDirectAddr: begin
        ccc_rx_req_bit  = '0;
        ccc_rx_req_byte = '1;
      end
      TxDirectAddrAck: begin
        ccc_tx_req_byte  = '0;
        ccc_tx_req_bit   = '1;
        ccc_tx_req_value = {7'h00, ~direct_addr_ack};
      end
      RxSubCmdByte: begin
      end
      RxData: begin
        ccc_rx_req_bit  = '0;
        ccc_rx_req_byte = '1;
        if (bus_rstart_det_i) ccc_rx_req_byte = '0;
      end
      RxDataTbit: begin
        ccc_rx_req_bit  = '1;
        ccc_rx_req_byte = '0;
      end
      TxData: begin
        ccc_tx_req_byte  = '1;
        ccc_tx_req_bit   = '0;
        ccc_tx_req_value = tx_data;
        ccc_tx_sel_od_pp = '1;
      end
      TxDataTbit: begin
        ccc_tx_req_byte  = '0;
        ccc_tx_req_bit   = '1;
        ccc_tx_req_value = {7'h00, ~tx_data_done};
        ccc_tx_sel_od_pp = '1;
      end
      NextCCC: begin
        next_ccc_o = '1;
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
        else tx_data = '0;
      end
      `I3C_DIRECT_GETDCR: begin
        tx_data_id_init = 8'h01;
        if (tx_data_id == 8'h01) tx_data = get_dcr_i;
        else tx_data = '0;
      end
      `I3C_DIRECT_RSTACT: begin
        tx_data_id_init = 8'h01;
        if (defining_byte == 8'h81 || defining_byte == 8'h82) begin
            if (tx_data_id == 8'h01 && defining_byte == 8'h81) tx_data = 8'hFF; // Use worst case value for now
            else if (tx_data_id == 8'h01 && defining_byte == 8'h82) tx_data = 8'hFF; // Use worst case value for now
            else tx_data = '0;
        end else if (defining_byte == 8'h00 || defining_byte == 8'h01 || defining_byte == 8'h02) begin
            if (tx_data_id == 8'h01) tx_data = rst_action;
            else tx_data = '0;
        end else tx_data = '0;
      end
      // 2 Bytes
      `I3C_DIRECT_GETSTATUS: begin
        tx_data_id_init = 8'h02;
        if (tx_data_id == 8'h02) tx_data = get_status_fmt1_i[15:8];
        else if (tx_data_id == 8'h01) tx_data = get_status_fmt1_i[7:0];
        else tx_data = '0;
      end
      `I3C_DIRECT_GETMWL: begin
        tx_data_id_init = 8'h02;
        if (tx_data_id == 8'h02) tx_data = get_mwl_i[15:8];
        else if (tx_data_id == 8'h01) tx_data = get_mwl_i[7:0];
        else tx_data = '0;
      end
      // 3 Bytes
      `I3C_DIRECT_GETMRL: begin
        tx_data_id_init = 8'h03;
        if (tx_data_id == 8'h03) tx_data = get_mrl_i[15:8];
        else if (tx_data_id == 8'h02) tx_data = get_mrl_i[7:0];
        else if (tx_data_id == 8'h01) tx_data = get_ibil_i;
        else tx_data = '0;
      end
      `I3C_DIRECT_GETPID: begin
        tx_data_id_init = 8'h06;
        if (tx_data_id == 8'h06) tx_data = get_pid_i[47:40];
        else if (tx_data_id == 8'h05) tx_data = get_pid_i[39:32];
        else if (tx_data_id == 8'h04) tx_data = get_pid_i[31:24];
        else if (tx_data_id == 8'h03) tx_data = get_pid_i[23:16];
        else if (tx_data_id == 8'h02) tx_data = get_pid_i[15:8];
        else if (tx_data_id == 8'h01) tx_data = get_pid_i[7:0];
        else tx_data = '0;
      end
      // n Bytes
      `I3C_DIRECT_GETCAPS: begin
        tx_data_id_init = 8'h03;
        if (tx_data_id == 8'h03) tx_data = 8'h00; // We don't support HDR Modes
        else if (tx_data_id == 8'h02) tx_data = 8'h01; // We support I3C Basic v1.1.1
        else if (tx_data_id == 8'h01) tx_data = 8'h40; // We send IBI MDB
        else tx_data = '0;
      end
      default: begin
        tx_data_id_init = 8'h00;
        tx_data = '0;
      end
    endcase
  end

  assign set_dasa_valid_o = set_dasa_valid;
  assign set_dasa_o = set_dasa_addr;
  assign set_dasa_virtual_device_o = is_byte_virtual_addr ? set_dasa_valid : 1'b0;
  assign set_aasa_o = set_aasa_valid;
  assign set_aasa_virt_o = set_aasa_virt_valid;

  // connect entdaa/setnewda
  always_comb begin: entdaa_setnewda_mux
   set_newda_o = set_newda_valid | (entdaa_addres_valid && ((state_q == HandleTargetENTDAA) || (state_q == HandleVirtualTargetENTDAA)));
   set_newda_virtual_device_o = set_newda_valid ? is_byte_our_virtual_dynamic_addr : (entdaa_addres_valid && (state_q == HandleVirtualTargetENTDAA));
   newda_o = set_newda_valid ? set_newda_addr : entdaa_address;
  end

  // Handle DIRECT SET CCCs
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_set_direct
    if (~rst_ni) begin
      set_dasa_valid <= 1'b0;
      set_dasa_addr  <= '0;
      set_newda_valid <= 1'b0;
      set_newda_addr <= '0;
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
        `I3C_DIRECT_SETNEWDA: begin
          if (state_q == RxDataTbit && bus_rx_done_i && ~is_byte_rsvd_addr &&
              rx_data_count == 8'd0) begin
            set_newda_addr <= rx_data[7:1];
            set_newda_valid <= 1'b1;
          end else begin
            set_newda_valid <= 1'b0;
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
      rst_action_valid <= 1'b0;
    end else begin
      enec_ibi         <= '0;
      enec_crr         <= '0;
      enec_hj          <= '0;
      disec_ibi        <= '0;
      disec_crr        <= '0;
      disec_hj         <= '0;
      case (command_code)
        // setmwl
        `I3C_DIRECT_SETMWL, `I3C_BCAST_SETMWL: begin
          if (state_q == RxDataTbit && bus_rx_done_i && (~is_byte_rsvd_addr || command_code == `I3C_BCAST_SETMWL)) begin
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
          if (state_q == RxDataTbit && bus_rx_done_i && (~is_byte_rsvd_addr || command_code == `I3C_BCAST_SETMRL)) begin
            if (rx_data_count == 8'd0) begin
              mrl_o[15:8] <= rx_data;
              set_ibil_o   <= 1'b0;
              set_mrl_o   <= 1'b0;
            end else if (rx_data_count == 8'd1) begin
              mrl_o[7:0] <= rx_data;
              set_ibil_o  <= 1'b0;
              set_mrl_o  <= 1'b1;
            end else if (rx_data_count == 8'd2) begin
              ibil_o[7:0] <= rx_data;
              set_ibil_o  <= 1'b1;
              set_mrl_o  <= 1'b0;
            end else begin
              set_ibil_o  <= 1'b0;
              set_mrl_o <= 1'b0;
            end
          end else begin
            set_ibil_o  <= 1'b0;
            set_mrl_o <= 1'b0;
          end
        end
        // enec
        `I3C_DIRECT_ENEC, `I3C_BCAST_ENEC: begin
          if (state_q == RxDataTbit && bus_rx_done_i && (~is_byte_rsvd_addr || command_code == `I3C_BCAST_ENEC)) begin
            if (rx_data_count == 8'd0) begin
              enec_ibi <= rx_data[0];
              enec_crr <= rx_data[1];
              enec_hj  <= rx_data[3];
            end
          end
        end
        // disec
        `I3C_DIRECT_DISEC, `I3C_BCAST_DISEC: begin
          if (state_q == RxDataTbit && bus_rx_done_i && (~is_byte_rsvd_addr || command_code == `I3C_BCAST_DISEC)) begin
            if (rx_data_count == 8'd0) begin
              disec_ibi <= rx_data[0];
              disec_crr <= rx_data[1];
              disec_hj  <= rx_data[3];
            end
          end
        end
        // rstact (direct)
        `I3C_DIRECT_RSTACT: begin
          if (command_valid && is_byte_our_addr && ~command_rnw) begin
            rst_action_valid <= 1'b1;
          end else begin
            rst_action_valid <= 1'b0;
          end
        end
        // rstact (broadcast)
        `I3C_BCAST_RSTACT: begin
          if (state_q == RxDefByteTbit && bus_rx_done_i) begin
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
      set_aasa_valid <= 1'b0;
      set_aasa_virt_valid <= 1'b0;
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
            if (~target_dyn_address_valid_i && ~(target_sta_address_i inside {[7'h00:7'h07], 7'h3E, 7'h5E, 7'h6E, 7'h76, [7'h78:7'h7F]})) begin
                set_aasa_valid <= 1'b1;
              end
              if (~virtual_target_dyn_address_valid_i && ~(virtual_target_sta_address_i inside {[7'h00:7'h07], 7'h3E, 7'h5E, 7'h6E, 7'h76, [7'h78:7'h7F]})) begin
                set_aasa_virt_valid <= 1'b1;
              end
          end else begin
            set_aasa_valid <= 1'b0;
            set_aasa_virt_valid <= 1'b0;
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


  ccc_entdaa xccc_entdaa (
    .clk_i,  // Clock
    .rst_ni, // Async reset, active low
    .id_i(get_pid_i),
    .bcr_i(get_bcr_i),
    .dcr_i(get_dcr_i),

    .virtual_id_i(virtual_get_pid_i),
    .virtual_bcr_i(virtual_get_bcr_i),
    .virtual_dcr_i(virtual_get_dcr_i),

    .start_daa_i(entdaa_o),
    .done_daa_o(entdaa_done),

    .process_virtual_i(entdaa_process_virtual),

    // Bus RX interface
    .bus_rx_data_i,
    .bus_rx_done_i,
    .bus_rx_req_bit_o(entdaa_rx_req_bit),
    .bus_rx_req_byte_o(entdaa_rx_req_byte),

    // Bus TX interface
    .bus_tx_done_i(bus_tx_done_i),
    .bus_tx_req_byte_o(entdaa_tx_req_byte),
    .bus_tx_req_bit_o(entdaa_tx_req_bit),
    .bus_tx_req_value_o(entdaa_tx_req_value),
    .bus_tx_sel_od_pp_o(entdaa_tx_sel_od_pp),

    // Bus Monitor interface
    .bus_rstart_det_i,
    .bus_stop_det_i,

    // bus access
    .arbitration_lost_i,

    // addr
    .address_o(entdaa_address),
    .address_valid_o(entdaa_addres_valid)
  );

`ifndef SYNTHESIS
`ifndef VERILATOR
  // Detect each SETDASA CCC targeted to us while we don't have dynamic address set
  property cover_first_both_dyn_setdasa;
    @(posedge clk_i) ($rose(direct_addr_ack) && (command_code == `I3C_DIRECT_SETDASA)) |=>
    ##1 @(posedge bus_rx_done_i) ##1
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
      $rose(bus_rx_done_i) && (command_code == `I3C_DIRECT_SETDASA) && ccc_valid_i &&
      $stable(bus_rx_req_byte_o) && bus_rx_req_byte_o ##1
      $rose(is_byte_our_static_addr) || $rose(is_byte_our_virtual_static_addr)
    ) |=>
    @(posedge bus_rx_done_i) ##1
    ##1 @(posedge clk_i) ##2
    (
      ($stable(direct_addr_ack) && ~direct_addr_ack) and
      (
        ($stable(virtual_target_dyn_address_valid_i) && virtual_target_dyn_address_valid_i ##0 $stable(virtual_target_dyn_address_i) && virtual_target_dyn_address_i) or
        ($stable(target_dyn_address_valid_i) && target_dyn_address_valid_i ##0 $stable(target_dyn_address_i) && target_dyn_address_i)
      )
    );
  endproperty : cover_not_first_both_dyn_setdasa
  covprop_not_first_both_dyn_setdasa: cover property (cover_not_first_both_dyn_setdasa);

  // Detect each SETAASA CCC while we don't have dynamic address set
  property cover_first_both_dyn_setaasa;
    @(posedge clk_i) $rose(ccc_valid_i) ##1 (command_code == `I3C_BCAST_SETAASA) && ~(virtual_target_dyn_address_valid_i & target_dyn_address_valid_i)|=>
    ##1 @(posedge bus_rx_done_i)
    ##1 @(posedge clk_i) ##2
    (
      ($rose(virtual_target_dyn_address_valid_i) ##0 $changed(virtual_target_dyn_address_i)) or
      ($rose(target_dyn_address_valid_i) ##0 $changed(target_dyn_address_i))
    );
  endproperty : cover_first_both_dyn_setaasa
  covprop_first_both_dyn_setaasa: cover property (cover_first_both_dyn_setaasa);

  // Detect each SETAASA CCC while we have dynamic address set
  property cover_not_first_both_dyn_setaasa;
    @(posedge clk_i) $rose(ccc_valid_i) ##1 (command_code == `I3C_BCAST_SETAASA) && (virtual_target_dyn_address_valid_i & target_dyn_address_valid_i)|=>
    ##1 @(posedge bus_rx_done_i)
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
      ccc_valid_i && (command_code == `I3C_DIRECT_SETDASA) &&
      ($rose(is_byte_our_addr) || $rose(is_byte_virtual_addr))
    );
  endproperty : cover_recv_setdasa
  covprop_recv_setdasa: cover property (cover_recv_setdasa);

  // Detect each SETAASA CCC
  property cover_recv_setaasa;
    @(posedge clk_i) ($rose(ccc_valid_i) ##1 (command_code == `I3C_BCAST_SETAASA));
  endproperty : cover_recv_setaasa
  covprop_recv_setaasa: cover property (cover_recv_setaasa);
`endif
`endif
endmodule
