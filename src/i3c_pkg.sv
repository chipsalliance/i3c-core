// SPDX-License-Identifier: Apache-2.0

package i3c_pkg;
  `include "i3c_defines.svh"

  localparam int unsigned RespErrIdWidth = 4;
  localparam int unsigned DatAw = $clog2(`DAT_DEPTH);
  localparam int unsigned DctAw = $clog2(`DCT_DEPTH);

  // I3C Packet
  typedef struct packed {
    logic [6:0] address;
    logic rnw;
    logic ack;
  } i3c_ah_t;

  // Table 15 CCC Frame Field definitions
  typedef struct packed {
    logic s;
    i3c_ah_t addr_header;

    byte cmd_code;  // followed by t-bit
    byte defining_byte;  // followed by t-bit
    byte subcmd_byte;
    byte data;  // TODO: this field changes per CCC
    logic stop;
    logic sr;
  } i3c_ccc_t;

  // Broadcast vs direct CCCs
  // Broadcast: code: 0x00 to 0x7E
  // Direct: code: 0x80 to 0xFE
  // is_direct(ccc.cmd_code[7] == 1'b1)
  // Command code 0xFF is reserved

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
    C = 4'b1100,
    D = 4'b1101,
    E = 4'b1110,
    F = 4'b1111
  } i3c_resp_err_status_e;

  // Response descriptor (See TCRI 7.1.3 Table 11)
  typedef struct packed {
    i3c_resp_err_status_e err_status;
    logic [3:0] tid;
    logic [7:0] __rsvd23_16;
    logic [15:0] data_length;
  } i3c_response_desc_t;

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
    logic rnw;  // Direction transfer; Read iff 1b'1 else write
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
endpackage
