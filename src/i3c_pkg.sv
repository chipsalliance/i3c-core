// SPDX-License-Identifier: Apache-2.0

package i3c_pkg;
  `include "i3c_defines.svh"
  `include "ccc.svh"
  `define I3C_RSVD_ADDR 7'h7E
  `define I3C_RSVD_BYTE 8'hFC

  // ===========================================================================
  // TE0 HDR Exit Condition: Invalid Reserved Address + RnW Combinations
  // ===========================================================================
  // Per I3C spec, these address+RnW combinations are invalid and trigger TE0:
  //   7'h3E / W, 7'h5E / W, 7'h6E / W, 7'h76 / W,
  //   7'h7A / W, 7'h7C / W, 7'h7F / W, 7'h7E / R
  //
  // Reserved addresses that are invalid with Write (RnW=0)
  localparam logic [6:0] TE0_RSVD_ADDR_W [7] = '{
    7'h3E,  // Reserved for Device Type Group Address
    7'h5E,  // Reserved for Device Type Group Address
    7'h6E,  // Reserved for Device Type Group Address
    7'h76,  // Reserved for Device Type Group Address
    7'h7A,  // Reserved for Device Type Group Address
    7'h7C,  // Reserved for Device Type Group Address
    7'h7F   // Reserved for Device Type Group Address
  };

  // Reserved address that is invalid with Read (RnW=1)
  localparam logic [6:0] TE0_RSVD_ADDR_R = 7'h7E;  // I3C Broadcast Address

  // Function to check if an address+RnW combination is a TE0 error
  // Returns 1 if the combination is invalid per I3C spec
  function automatic logic is_te0_rsvd_addr_err(
    input logic [6:0] addr,
    input logic       rnw
  );
    // Check for 7'h7E with Read
    if (addr == TE0_RSVD_ADDR_R && rnw) begin
      return 1'b1;
    end
    // Check for reserved addresses with Write
    if (!rnw) begin
      for (int i = 0; i < 7; i++) begin
        if (addr == TE0_RSVD_ADDR_W[i]) begin
          return 1'b1;
        end
      end
    end
    return 1'b0;
  endfunction : is_te0_rsvd_addr_err

  // ===========================================================================
  // I3C Reserved Address Check for Dynamic Address Assignment
  // ===========================================================================
  // Per I3C spec Table 8, certain addresses cannot be assigned as Dynamic Addresses.
  // This function returns 1 if the address is reserved and cannot be used.
  // Reserved ranges:
  //   7'h00-7'h07: Reserved for I3C broadcast and special purposes
  //   7'h3E, 7'h5E, 7'h6E, 7'h76: Reserved for Device Type Group Address
  //   7'h78-7'h7F: Reserved for I3C special addresses
  function automatic logic is_i3c_rsvd_addr(
    input logic [6:0] addr
  );
    return addr inside {[7'h00:7'h07], 7'h3E, 7'h5E, 7'h6E, 7'h76, [7'h78:7'h7F]};
  endfunction : is_i3c_rsvd_addr

  localparam int unsigned RespErrIdWidth = 4;
  localparam int unsigned DatAw = $clog2(`DAT_DEPTH);
  localparam int unsigned DctAw = $clog2(`DCT_DEPTH);

  localparam int unsigned I3cDataWidth = 8;
  localparam int unsigned I3cAddrWidth = 7;
  localparam int unsigned I3cTimeParamWidth = 20;

  typedef logic      [I3cDataWidth-1:0] i3c_byte_t;
  typedef logic      [I3cAddrWidth-1:0] i3c_addr_t;
  typedef logic [I3cTimeParamWidth-1:0] i3c_timeparam_t;

  // CCC Command Code enum for better waveform visibility
  typedef enum logic [7:0] {
    // Broadcast Commands
    CCC_BCAST_ENEC      = 8'h00,  // Enable Events Command
    CCC_BCAST_DISEC     = 8'h01,  // Disable Events Command
    CCC_BCAST_ENTAS0    = 8'h02,  // Enter Activity State 0
    CCC_BCAST_ENTAS1    = 8'h03,  // Enter Activity State 1
    CCC_BCAST_ENTAS2    = 8'h04,  // Enter Activity State 2
    CCC_BCAST_ENTAS3    = 8'h05,  // Enter Activity State 3
    CCC_BCAST_RSTDAA    = 8'h06,  // Reset Dynamic Address Assignment
    CCC_BCAST_ENTDAA    = 8'h07,  // Enter Dynamic Address Assignment
    CCC_BCAST_DEFTGTS   = 8'h08,  // Define List of Targets
    CCC_BCAST_SETMWL    = 8'h09,  // Set Max Write Length
    CCC_BCAST_SETMRL    = 8'h0A,  // Set Max Read Length
    CCC_BCAST_ENTTM     = 8'h0B,  // Enter Test Mode
    CCC_BCAST_SETBUSCON = 8'h0C,  // Set Bus Context
    CCC_BCAST_ENDXFER   = 8'h12,  // Data Transfer Ending Procedure Control
    CCC_BCAST_ENTHDR0   = 8'h20,  // Enter HDR Mode 0
    CCC_BCAST_ENTHDR1   = 8'h21,  // Enter HDR Mode 1
    CCC_BCAST_ENTHDR2   = 8'h22,  // Enter HDR Mode 2
    CCC_BCAST_ENTHDR3   = 8'h23,  // Enter HDR Mode 3
    CCC_BCAST_ENTHDR4   = 8'h24,  // Enter HDR Mode 4
    CCC_BCAST_ENTHDR5   = 8'h25,  // Enter HDR Mode 5
    CCC_BCAST_ENTHDR6   = 8'h26,  // Enter HDR Mode 6
    CCC_BCAST_ENTHDR7   = 8'h27,  // Enter HDR Mode 7
    CCC_BCAST_SETXTIME  = 8'h28,  // Exchange Timing Information
    CCC_BCAST_SETAASA   = 8'h29,  // Set All Addresses to Static Addresses
    CCC_BCAST_RSTACT    = 8'h2A,  // Target Reset Action
    CCC_BCAST_DEFGRPA   = 8'h2B,  // Define List of Group Address
    CCC_BCAST_RSTGRPA   = 8'h2C,  // Reset Group Address
    CCC_BCAST_MLANE     = 8'h2D,  // Multi-Lane Data Transfer Control
    // Direct Commands
    CCC_DIRECT_ENEC     = 8'h80,  // Enable Events Command
    CCC_DIRECT_DISEC    = 8'h81,  // Disable Events Command
    CCC_DIRECT_ENTAS0   = 8'h82,  // Enter Activity State 0
    CCC_DIRECT_ENTAS1   = 8'h83,  // Enter Activity State 1
    CCC_DIRECT_ENTAS2   = 8'h84,  // Enter Activity State 2
    CCC_DIRECT_ENTAS3   = 8'h85,  // Enter Activity State 3
    CCC_DIRECT_RSTDAA   = 8'h86,  // Direct Reset Dynamic Address Assignment
    CCC_DIRECT_SETDASA  = 8'h87,  // Set Dynamic Address from Static Address
    CCC_DIRECT_SETNEWDA = 8'h88,  // Set New Dynamic Address
    CCC_DIRECT_SETMWL   = 8'h89,  // Set Max Write Length
    CCC_DIRECT_SETMRL   = 8'h8A,  // Set Max Read Length
    CCC_DIRECT_GETMWL   = 8'h8B,  // Get Max Write Length
    CCC_DIRECT_GETMRL   = 8'h8C,  // Get Max Read Length
    CCC_DIRECT_GETPID   = 8'h8D,  // Get Provisioned ID
    CCC_DIRECT_GETBCR   = 8'h8E,  // Get Bus Characteristics Register
    CCC_DIRECT_GETDCR   = 8'h8F,  // Get Device Characteristics Register
    CCC_DIRECT_GETSTATUS = 8'h90, // Get Device Status
    CCC_DIRECT_GETACCCR = 8'h91,  // Get Accept Controller Role
    CCC_DIRECT_ENDXFER  = 8'h92,  // Data Transfer Ending Procedure Control
    CCC_DIRECT_SETBRGTGT = 8'h93, // Set Bridge Targets
    CCC_DIRECT_GETMXDS  = 8'h94,  // Get Max Data Speed
    CCC_DIRECT_GETCAPS  = 8'h95,  // Get Optional Feature Capabilities
    CCC_DIRECT_SETROUTE = 8'h96,  // Set Route
    CCC_DIRECT_D2DXFER  = 8'h97,  // Device to Device Tunneling Control
    CCC_DIRECT_SETXTIME = 8'h98,  // Set Exchange Timing Information
    CCC_DIRECT_GETXTIME = 8'h99,  // Get Exchange Timing Information
    CCC_DIRECT_RSTACT   = 8'h9A,  // Target Reset Action
    CCC_DIRECT_SETGRPA  = 8'h9B,  // Set Group Address
    CCC_DIRECT_RSTGRPA  = 8'h9C,  // Reset Group Address
    CCC_DIRECT_MLANE    = 8'h9D   // Multi-Lane Data Transfer Control
  } ccc_cmd_e;

  typedef enum logic {
    OpenDrain = 1'b0,
    PushPull  = 1'b1
  } i3c_drive_e;

  // Bus signal state
  typedef struct packed {
    logic value;
    logic pos_edge;
    logic neg_edge;
    logic stable_high;
    logic stable_low;
  } signal_state_t;

  // I2C/I3C bus state
  typedef struct packed {
    signal_state_t sda;
    signal_state_t scl;
    logic start_det;
    logic rstart_det;
    logic stop_det;
  } bus_state_t;

  // Tx transfer types
  typedef enum logic [2:0] {
    RawByte,
    RawBit,
    InitIbi,
    AckRegular,
    AckWrite,
    AckIbi,
    TReadCont,
    TReadEnd
  } i3c_tx_req_e;

  // Tx descriptor
  typedef struct packed {
    logic        req_valid;
    i3c_tx_req_e req_type;
    i3c_drive_e  drive_type;
    i3c_byte_t   data;
  } bus_tx_req_t;

  typedef struct packed {
    logic error;
    logic idle;
    logic abort;
    logic done;
  } bus_tx_rsp_t;

  // Rx descriptor
  typedef struct packed {
    logic req_byte;
    logic req_bit;
  } bus_rx_req_t;

  typedef struct packed {
    logic      idle;
    logic      done;
    i3c_byte_t data;
  } bus_rx_rsp_t;

  // Memory port to DAT table
  typedef struct packed {
    logic             req;
    logic             write;
    logic [DatAw-1:0] addr;
    logic [63:0]      wdata;
    logic [63:0]      wmask;
  } dat_mem_sink_t;

  typedef struct packed {
    logic [63:0] rdata;
    logic        rvalid;
    logic [1:0]  rerror;
  } dat_mem_src_t;

  // Memory port to DCT table
  typedef struct packed {
    logic             req;
    logic             write;
    logic [DctAw-1:0] addr;
    logic [127:0]     wdata;
    logic [127:0]     wmask;
  } dct_mem_sink_t;

  typedef struct packed {
    logic [127:0] rdata;
    logic         rvalid;
    logic [1:0]   rerror;
  } dct_mem_src_t;

  // Response error status (See TCRI 7.1.3 Table 11 field ERR_STATUS)
  typedef enum logic [RespErrIdWidth-1:0] {
    Success = 4'b0000,
    Crc = 4'b0001,
    Parity = 4'b0010,
    Frame = 4'b0011,
    AddrHeader = 4'b0100,
    // Address was NACK'ed or Dynamic Address Assignment was NACK'ed
    Nack = 4'b0101,
    // Receive overflow or transfer underflow error
    Ovl = 4'b0110,
    // Target returned fewer bytes than requested in DATA_LENGTH field
    // of a transfer command where short read was not permitted
    I3cShortReadErr = 4'b0111,
    // Terminated by host controller due to internal error or Abort operation
    HcAborted = 4'b1000,
    // Transfer terminated by due to bus action
    // * for I2C transfers: I2C_WR_DATA_NACK
    // * for I3C transfers: BUS_ABORTED
    I2cDataNackOrI3cBusAborted = 4'b1001,
    // Command not supported by the Host Controller implementation
    NotSupported = 4'b1010,
    Reserved = 4'b1011,
    // Transfer Type Specific Errors
    ErrorC = 4'b1100,
    ErrorD = 4'b1101,
    ErrorE = 4'b1110,
    ErrorF = 4'b1111
  } i3c_resp_err_status_e;

  // Response descriptor (See TCRI 7.1.3 Table 11)
  typedef struct packed {
    i3c_resp_err_status_e err_status;
    logic [3:0] tid;
    logic [7:0] __rsvd23_16;
    logic [15:0] data_length;
  } i3c_response_desc_t;

  typedef struct packed {
    logic [31:16] data_length;
    logic [15:0]  __rsvd15_0;
  } i3c_tti_response_desc_t;

  typedef struct packed {
    logic [31:16] data_length;
    logic end_of_transfer;
    logic [14:0] __rsvd14_0;
  } i3c_tti_command_desc_t;

  // Defined command types (See TCRI 7.1.2 Table 6)
  typedef enum logic [2:0] {
    RegularTransfer = 3'b000,
    ImmediateDataTransfer = 3'b001,
    AddressAssignment = 3'b010,
    ComboTransfer = 3'b011,
    InternalControl = 3'b111
  } i3c_cmd_attr_e;

  // Data transfer speed and mode (See TCRI 7.1.1.1)
  // I2C valid sdr0 - sdr4
  typedef enum logic [2:0] {
    sdr0 = 3'b000,  // Standard SDR speed (up to 12.5 MHZ)
    sdr1 = 3'b001,
    sdr2 = 3'b010,
    sdr3 = 3'b011,
    sdr4 = 3'b100,
    hdr_tsx = 3'b101,  // HDR ternary mode
    hdr_ddr = 3'b110,  // HDR double data rate mode
    __reserved = 3'b111
  } i3c_trans_mode_e;


  // Command descriptors (See TCRI 7.1.2 Figure 11 for visualization)

  // Immediate transfer command descriptor (See TCRI 7.1.2.1)
  // Provides a short type of transfer, contains the data to be send in the descriptor
  // itself (as opposed to via TX channel)
  typedef struct packed {
    // DWORD 1
    logic [7:0] data_byte4;
    logic [7:0] data_byte3;
    logic [7:0] data_byte2;
    logic [7:0] def_or_data_byte1;  // Direct argument or defining byte

    // DWORD 0
    logic toc;  // Terminate on completion
    logic wroc;  // Response on completion
    logic rnw;  // Direction; Immediate transfer is write-only
    i3c_trans_mode_e mode;
    logic [2:0] dtt;  // Number of valid data bytes
    logic [1:0] __rsvd22_21;
    logic [4:0] dev_idx;
    logic cp;  // Command present
    logic [7:0] cmd;  // CCC / HDR command code
    logic [3:0] tid;  // Transaction ID
    i3c_cmd_attr_e attr;
  } immediate_data_trans_desc_t;

  // Regular transfer command descriptor (See TCRI 7.1.2.2)
  typedef struct packed {
    // DWORD 1
    logic [15:0] data_length;
    logic [7:0] __rsvd47_40;
    logic [7:0] def_byte;  // Defining byte for present CCC; valid if dbp == 1'b1

    // DWORD 0
    logic toc;  // Terminate on completion
    logic wroc;  // Response on completion
    logic rnw;  // Direction transfer; Read if 1b'1 else write
    i3c_trans_mode_e mode;
    logic dbp;  // Defining byte for CCC present
    logic sre;  // iff 0'b0 permits short reads
    logic [2:0] __rsvd23_21;
    logic [4:0] dev_idx;
    logic cp;  // Command present
    logic [7:0] cmd;  // CCC / HDR command code
    logic [3:0] tid;  // Transaction ID
    i3c_cmd_attr_e attr;
  } regular_trans_desc_t;

  // Combo transfer command descriptor (See TCRI 7.1.2.3)
  typedef struct packed {
    // DWORD 1
    logic [15:0] data_length;
    logic [15:0] offset;

    // DWORD 0
    logic toc;  // Terminate on completion
    logic wroc;  // Response on completion
    logic rnw;  // Direction transfer; Read iff 1b'1 else write
    i3c_trans_mode_e mode;
    logic sub_16_off;  // Set sub-offset to 16 iff 1'b1 else 8
    logic fpm;  // First phase mode
    logic [1:0] dlp;  // Data length position
    logic __rsvd21;
    logic [4:0] dev_idx;
    logic cp;
    logic [7:0] cmd;
    logic [3:0] tid;  // Transaction ID
    i3c_cmd_attr_e attr;
  } combo_trans_desc_t;

  // Address assignment command descriptor (See TCRI 7.1.2.3)
  typedef struct packed {
    // DWORD 1
    logic [31:0] __rsvd63_32;

    // DWORD 0
    logic toc;  // Terminate on completion
    logic wroc;  // Response on completion
    logic [3:0] dev_count;
    logic [4:0] __rsvd25_21;
    logic [4:0] dev_idx;
    logic __rsvd15;
    logic [7:0] cmd;  // CCC
    logic [3:0] tid;  // Transaction ID
    i3c_cmd_attr_e attr;
  } addr_assign_desc_t;

  // MIPI command code (See HCI 8.4.2)
  // Sub-commands for the internal control command
  typedef enum logic [3:0] {
    Noop = 4'b0000,
    RingBundleLock = 4'b0001,
    BrodcastAddressEnable = 4'b0010,
    DeviceContextUpdate = 4'b0011,
    TargetResetPattern = 4'b0100,
    CtrlSDARecoveryOrBusReset = 4'b0101,
    EnableETTAndHDRModeConfiguration = 4'b0110,
    CtrlRoleHandoff = 4'b0111,
    DeadBusRecovery = 4'b1101
  } mipi_cmd_e;

  // Internal control command (See HCI 8.4.2)
  // See HCI 8.4 Figure 51 for visualization
  typedef struct packed {
    // DWORD 1
    logic [31:0] vendor_specific;

    // DWORD 0
    logic [19:0] mipi_rsvd;  // Command dependent area
    mipi_cmd_e mipi_cmd;
    logic vip;  // Vendor info present
    logic [3:0] tid;  // Transaction ID
    i3c_cmd_attr_e attr;
  } internal_control_desc_t;

  // Target Device 48-bit Provisioned ID
  // Section 5.1.4.1.1 I3C Basic
  typedef struct packed {
    logic [15:0] part_id;
    logic [3:0]  instance_id;
    logic [11:0] generic_value;
  } target_dev_id_value_t;

  typedef struct packed {
    logic [15:0] mipi_manufacturer_id;
    logic id_type_selector;
    target_dev_id_value_t vendor_random_value;
  } target_dev_provisioned_id_t;

endpackage
