// SPDX-License-Identifier: Apache-2.0

package i3c_pkg;

  localparam int unsigned DatDepth = 128;
  localparam int unsigned DctDepth = 128;
  localparam int unsigned DatAw = $clog2(DatDepth);
  localparam int unsigned DctAw = $clog2(DctDepth);

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
    logic              req;
    logic              write;
    logic [DatAw-1:0] addr;
    logic [63:0]       wdata;
    logic [63:0]       wmask;
  } dat_mem_sink_t;

  typedef struct packed {
    logic [63:0] rdata;
    logic        rvalid;
    logic [1:0]  rerror;
  } dat_mem_src_t;


  // Memory port to DCT table
  typedef struct packed {
    logic              req;
    logic              write;
    logic [DctAw-1:0] addr;
    logic [127:0]      wdata;
    logic [127:0]      wmask;
  } dct_mem_sink_t;

  typedef struct packed {
    logic [127:0] rdata;
    logic         rvalid;
    logic [1:0]   rerror;
  } dct_mem_src_t;

endpackage
