// SPDX-License-Identifier: Apache-2.0

package i3c_pkg;

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

endpackage
