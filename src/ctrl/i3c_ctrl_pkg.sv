// SPDX-License-Identifier: Apache-2.0

package i3c_ctrl_pkg;

  parameter int I2CFifoDepth = 64;
  localparam int I2CFifoDepthWidth = $clog2(I2CFifoDepth + 1);

  // To raise errors
  typedef struct packed {logic err_0;} i3c_err_t;

  // To raise interrupts
  typedef struct packed {logic irq_0;} i3c_irq_t;

  // I3C Packet
  typedef struct packed {logic irq_0;} i3c_ah_t;

  // Communication flow FSM
  typedef enum logic [3:0] {
    Idle = 4'd0,
    WaitForCmd = 4'd1,
    FetchDAT = 4'd2,
    I2CWriteImmediate = 4'd3,
    I3CWriteImmediate = 4'd4,
    FetchTxData = 4'd5,
    FetchRxData = 4'd6,
    InitI2CWrite = 4'd7,
    InitI2CRead = 4'd8,
    StallWrite = 4'd9,
    StallRead = 4'd10,
    IssueCmd = 4'd11,
    WriteResp = 4'd12
  } flow_fsm_state_e;

  typedef enum logic {
    Write = 1'b0,
    Read  = 1'b1
  } cmd_transfer_dir_e;

  typedef struct packed {
    logic [4:0] __rsvd63_59;
    logic [7:0] autocmd_hdr_code;
    logic [2:0] autocmd_mode;
    logic [7:0] autocmd_value;
    logic [7:0] autocmd_mask;
    logic device;
    logic [1:0] dev_nack_retry_cnt;
    logic [2:0] ring_id;
    logic [1:0] __rsvd25_24;
    logic [7:0] dynamic_address;
    logic ts;
    logic crr_reject;
    logic ibi_reject;
    logic ibi_payload;
    logic [4:0] __rsvd11_7;
    logic [6:0] static_address;
  } dat_entry_t;

endpackage
