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

  TODO: Consider if the retry model requires implementation updates
  TODO: Repeating with additional targets

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
  import I3CCSR_pkg::*;
(
    input logic clk_i, // Clock
    input logic rst_ni, // Async reset, active low

    // CC is decoded from the frame by the primary FSM
    input logic [7:0] ccc_i,
    // Assert valid when you want to give control to this FSM
    input logic ccc_valid_i,

    output logic done_fsm_o,

    // Bus Monitor interface
    input logic bus_start_det_i,
    input logic bus_stop_det_i,

    // Bus TX interface
    input logic bus_tx_req_err_i,
    input logic bus_tx_done_i,
    input logic bus_tx_idle_i,
    output logic bus_tx_req_byte_o,
    output logic bus_tx_req_bit_o,
    output logic [7:0] bus_tx_req_value_o,

    // Bus RX interface
    input logic [7:0] bus_rx_data_i,
    input logic bus_rx_done_i,
    input logic bus_rx_idle_i,
    output logic bus_rx_req_bit_o,
    output logic bus_rx_req_byte_o,

    // Configuration and status interface
    // Reads from CSRs (inputs) are continuous assignments
    //
    // Writes to CSRs (outputs) need generation of WE signal
    // outside of this module
    //

    // Enable Target event driven interrupts
    output logic enec_o,

    // Disable Target event driven interrupts
    output logic disec_o,

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

    // Set All Addresses to Static Addresses
    output logic set_dasa_o,

    // Target Reset Action
    // I3C_BCAST_RSTACT
    output logic [7:0] rst_action_o,

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
    // TODO: GETSTATUS: Format 2

    // Get Accept Controller Role
    // I3C_DIRECT_GETACCCR
    input logic get_acccr_i,

    // Set Bridge Targets
    // I3C_DIRECT_SETBRGTGT
    output logic set_brgtgt_o,

    // Get Max Data Speed
    // I3C_DIRECT_GETMXDS
    input logic get_mxds_i

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
);

  // Data structure for any CCC
  logic [7:0] command_code;
  logic       command_code_valid;
  logic [7:0] defining_byte;
  logic       defining_byte_valid;
  logic [7:0] subcommand_byte;
  logic       subcommand_byte_valid;
  logic [7:0] command_data[6];
  logic       command_data_valid[6];

  // Data structures
  logic [7:0] data_id;
  logic [7:0] data_max;

  always_ff @( posedge clk_i or negedge rst_ni ) begin : register_ccc
    if (~rst_ni) begin
      command_code <= '0;
    end else begin
      if (ccc_valid_i)begin
        command_code <= ccc_i;
      end
    end
  end

  // TODO: Handle Bcast CCCs
  typedef enum logic [7:0] {
    Idle,
    WaitCCC,
    RxTbit,
    RxByte,
    RxDirectDefByteTbit,
    RxDirectAddr,
    TxDirectAddrAck,
    RxSubCmdByte,
    RxData,
    RxDataTbit,
    TxData,
    TxDataTbit,
    DoneCCC
  } state_e;

  state_e state_q, state_d;

  logic is_direct_cmd;
  assign is_direct_cmd = command_code[7];  // 0 - BCast, 1 - Direct

  logic is_byte_rsvd_addr;
  // TODO
  assign is_byte_rsvd_addr = {8'h00} == {7'h7E,1'b0};

  // TODO
  logic is_byte_our_addr;
  assign is_byte_our_addr = '1;

  logic is_xfer_rnw;
  assign is_xfer_rnw = '1;

  always_comb begin : state_functions
    state_d = state_q;
    unique case (state_q)
      Idle: begin
          state_d = WaitCCC;
      end
      WaitCCC: begin
          if(ccc_valid_i)
            state_d = RxTbit;
      end
      RxTbit: begin
          if(bus_rx_done_i)
            state_d = RxByte;
      end
      RxByte: begin
          if(bus_start_det_i)
            state_d = RxDirectAddr;
          else if (bus_rx_done_i)
            state_d = RxDirectDefByteTbit;
      end
      RxDirectDefByteTbit: begin
          if(bus_rx_done_i) begin
            state_d = RxByte;
          end
      end
      RxDirectAddr: begin
          if(bus_rx_done_i) begin
            state_d = TxDirectAddrAck;
          end
      end
      TxDirectAddrAck: begin
        if(bus_tx_done_i) begin
          if (is_byte_rsvd_addr)
            state_d = DoneCCC;
          else if (is_byte_our_addr && is_xfer_rnw)
            state_d = TxData;
          else if (is_byte_our_addr && ~is_xfer_rnw) begin
              if(command_code == `I3C_DIRECT_SETXTIME)
                state_d = RxSubCmdByte;
              else
                state_d = RxData;
          end
        end
      end

      // TODO: Add support for Sub Cmd Byte
      RxSubCmdByte: begin
        state_d = Idle;
      end

      RxData: begin
        if(bus_start_det_i)
          state_d = RxDirectAddr;
        else if(bus_rx_done_i)
          state_d = RxDataTbit;
      end
      RxDataTbit: begin
        if(bus_rx_done_i)
          state_d = RxData;
      end

      TxData: begin
        if(bus_start_det_i)
          state_d = RxDirectAddr;
        else if(bus_tx_done_i)
          state_d = TxDataTbit;
      end
      TxDataTbit: begin
        if(bus_tx_done_i)
          state_d = TxData;
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

    done_fsm_o = '0;
    unique case (state_q)
      Idle: begin

      end
      WaitCCC: begin

      end
      RxTbit: begin
        bus_rx_req_bit_o = '1;
        bus_rx_req_byte_o = '0;
      end
      RxByte: begin
        bus_rx_req_bit_o = '0;
        bus_rx_req_byte_o = '1;
        if(bus_start_det_i)
          bus_rx_req_byte_o = '0;
      end
      RxDirectDefByteTbit: begin
        bus_rx_req_bit_o = '1;
        bus_rx_req_byte_o = '0;
      end
      RxDirectAddr: begin
        bus_rx_req_bit_o = '0;
        bus_rx_req_byte_o = '1;
      end
      TxDirectAddrAck: begin
        bus_tx_req_byte_o = '0;
        bus_tx_req_bit_o = '1;
        bus_tx_req_value_o = '0;
      end
      RxSubCmdByte: begin
      end
      RxData: begin
        bus_rx_req_bit_o = '0;
        bus_rx_req_byte_o = '1;
      end
      RxDataTbit: begin
        bus_rx_req_bit_o = '1;
        bus_rx_req_byte_o = '0;
      end
      TxData: begin
        bus_tx_req_byte_o = '1;
        bus_tx_req_bit_o = '0;
        // bus_tx_req_value_o = tx_data;
        bus_tx_req_value_o = 8'h45;
      end
      TxDataTbit: begin
        bus_tx_req_byte_o = '0;
        bus_tx_req_bit_o = '1;
        bus_tx_req_value_o = {7'h00,~tx_data_done};
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
      if (bus_stop_det_i)
        state_q <= Idle;
      else
        state_q <= state_d;
    end
  end

  // GET interface handler
  logic [7:0] tx_data;

  logic [7:0] tx_data_id; // This register must hold the maximum number of bytes used by a CCC
  logic [7:0] tx_data_id_init;
  logic tx_data_done;

  always_ff @( posedge clk_i or negedge rst_ni ) begin : proc_tx_data_id
    if (~rst_ni) begin
      tx_data_id <= '0;
    end else begin
      if (state_q == TxDataTbit && bus_tx_done_i)
        tx_data_id <= tx_data_id - 1'b1;
      else if (state_q == RxTbit)
        tx_data_id <= tx_data_id_init;
      else
        tx_data_id <= tx_data_id;
    end
  end

  // Done, no more bytes to send in this CCC
  assign tx_data_done = tx_data_id == 8'h00;

  // Handle all DIRECT GET CCCs
  always_comb begin : proc_get
    case (command_code)
      `I3C_DIRECT_GETMRL: begin
          tx_data_id_init = 8'h02;
          if ( tx_data_id == 8'h02)
            tx_data = get_mrl_i[15:8];
          else if ( tx_data_id == 8'h01)
            tx_data = get_mrl_i[7:0];
      end
      `I3C_DIRECT_GETMWL: begin
          tx_data_id_init = 8'h02;
          if ( tx_data_id == 8'h02)
            tx_data = get_mwl_i[15:8];
          else if ( tx_data_id == 8'h01)
            tx_data = get_mwl_i[7:0];
      end
      `I3C_DIRECT_GETSTATUS: begin
          tx_data_id_init = 8'h02;
          if ( tx_data_id == 8'h02)
            tx_data = get_status_fmt1_i[15:8];
          else if ( tx_data_id == 8'h01)
            tx_data = get_status_fmt1_i[7:0];
      end
      `I3C_DIRECT_RSTACT, `I3C_BCAST_RSTACT: begin
      end
      default: begin
        tx_data = '0;
        rst_action_o = '0;
      end
    endcase
  end

endmodule
