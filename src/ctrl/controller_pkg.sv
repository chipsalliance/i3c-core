// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.

// SPDX-License-Identifier: Apache-2.0

package controller_pkg;

  parameter int unsigned I2cAcqByteIdWidth = 3;

  // TODO(#22028) encode this more efficiently in the ACQ FIFO. Each entry in the
  // ACQ FIFO does not need to contain both an 8 bit data field and a 3 bit
  // identifier. We should have the ACQ FIFO be 9 bits wide where the MSB
  // indicates whether it is a data byte or a control byte. This way we can
  // add more values to this enum without having to widen the ACQ FIFO width.
  typedef enum logic [I2cAcqByteIdWidth-1:0] {
    AcqData      = 3'b000,
    AcqStart     = 3'b001,
    AcqStop      = 3'b010,
    AcqRestart   = 3'b011,
    // AcqNack means one of two things:
    // 1. We received a read request to our address, but had to NACK the
    // address because our ACQ FIFO is full.
    // 2. We received too many bytes in a write request and had to NACK a data
    // byte. The NACK'ed data byte is still in the data field for inspection.
    AcqNack      = 3'b100,
    // AcqNackStart means that we got a write request to our address, we sent
    // an ACK to back to the host so that we can be compatible with SMBus, but
    // now we must unconditionally NACK the next byte. We cannot record that
    // NACK'ed byte because there is no space in the ACQ FIFO. The OpenTitan
    // software must know this distinction from a normal AcqNack because the
    // state machine must still continue through the AcquireByte and Nack*
    // states.
    AcqNackStart = 3'b101,
    AcqNackStop  = 3'b110
  } i2c_acq_byte_id_e;

  // Width of each entry in the FMT FIFO with enough space for an 8-bit data
  // byte and 5 flags.
  parameter int unsigned FmtFifoWidth = 8 + 5;

  // Width of each entry in the RX and TX FIFO: just an 8-bit data byte.
  parameter int unsigned RxFifoWidth = 8;
  parameter int unsigned TxFifoWidth = 8;

  // Width of each entry in the ACQ FIFO with enough space for an 8-bit data
  // byte and an identifier defined by i2c_acq_byte_id_e.
  parameter int unsigned AcqFifoWidth = I2cAcqByteIdWidth + 8;

  parameter int I2CFifoDepth = 64;
  localparam int I2CFifoDepthWidth = $clog2(I2CFifoDepth + 1);

  // To raise errors
  typedef struct packed {logic err_0;} i3c_err_t;

  // To raise interrupts
  typedef struct packed {logic irq_0;} i3c_irq_t;

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
