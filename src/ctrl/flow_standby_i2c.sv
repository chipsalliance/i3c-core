// SPDX-License-Identifier: Apache-2.0

module flow_standby_i2c
  import controller_pkg::*;
  import i3c_pkg::*;
#(
    parameter int AcqFifoDepth = 64,
    localparam int AcqFifoDepthWidth = $clog2(AcqFifoDepth + 1)
) (
    input logic clk_i,
    input logic rst_ni,

    // I2C controller side
    input logic acq_fifo_wvalid_i,
    input logic [AcqFifoWidth-1:0] acq_fifo_wdata_i,
    output logic [AcqFifoDepthWidth-1:0] acq_fifo_depth_o,
    input logic acq_fifo_wready_i,

    output logic tx_fifo_rvalid_o,
    input logic tx_fifo_rready_i,
    output logic [TxFifoWidth-1:0] tx_fifo_rdata_o,

    // TTI
    input i3c_tti_command_desc_t cmd_fifo_rdata_i,
    input logic cmd_fifo_rvalid_i,
    output logic cmd_fifo_rready_o,

    // FIFO
    output i3c_response_desc_t response_fifo_wdata_o,
    output logic response_fifo_wvalid_o,
    input logic response_fifo_wready_i,

    // TX FIFO
    input logic [7:0] tx_fifo_rdata_i,
    input logic tx_fifo_rvalid_i,
    output logic tx_fifo_rready_o,

    // RX FIFO
    output logic [7:0] rx_fifo_wdata_o,
    output logic rx_fifo_wvalid_o,
    input logic rx_fifo_wready_i,

    output logic err_o
);
  typedef enum logic [3:0] {
    AwaitStart = 0,
    ReceiveByte = 1,
    PushDWordToTTIQueue = 2,
    ReportError = 3,
    PushResponseToTTIQueue = 4,
    PopCommandFromTTIQueue = 5,
    PopDWordFromTTIQueue = 6,
    SendByte = 7,
    SwitchByteToSend = 8,
    AwaitStopOrRestart = 9
  } state_t;

  // FSM STATE
  state_t state_d, state_q;
  // Buffer for holding elements returned by I2C target FSM
  logic [AcqFifoWidth-1:0] fifo_buf[AcqFifoDepth];
  // Are we currently mid-transfer?
  logic transfer_active;
  // Number of data bytes held in `fifo_buf`
  logic [1:0] byte_count;  // Note: We handle only 4 entries of `fifo_buf`
  // Total number of bytes processed in transaction
  logic [15:0] transaction_byte_count;
  // Read transaction length
  logic [15:0] read_transaction_length;

  // Input combo

  // Identifier of the type of the pending I2C target flow message
  i2c_acq_byte_id_e acq_fifo_wdata_byte_id;

  // Control signals for internal register FF inputs
  logic push_byte;
  logic reset_byte_count;
  logic activate_transfer;
  logic deactivate_transfer;
  logic start_detected;
  logic stop_detected;
  logic data_detected;
  logic nack_detected;
  logic restart_detected;
  logic is_start_read;
  logic xfer_read;
  logic pop_command_from_tti;
  logic pop_data_from_tti;

  assign rx_fifo_wdata_o = fifo_buf[0][7:0];
  assign byte_count = transaction_byte_count[1:0];

  assign acq_fifo_wdata_byte_id = i2c_acq_byte_id_e'(acq_fifo_wdata_i[AcqFifoWidth-1:8]);
  assign start_detected = acq_fifo_wvalid_i & (acq_fifo_wdata_byte_id == AcqStart);
  assign stop_detected = acq_fifo_wvalid_i & (acq_fifo_wdata_byte_id == AcqStop);
  assign data_detected = acq_fifo_wvalid_i & (acq_fifo_wdata_byte_id == AcqData);
  assign nack_detected = acq_fifo_wvalid_i & (acq_fifo_wdata_byte_id == AcqNack);
  assign restart_detected = acq_fifo_wvalid_i & (acq_fifo_wdata_byte_id == AcqRestart);
  assign is_start_read = acq_fifo_wvalid_i &
    ( acq_fifo_wdata_byte_id == AcqStart ||
      acq_fifo_wdata_byte_id == AcqRestart ||
      acq_fifo_wdata_byte_id == AcqNackStart );

  // TODO: Bug: Set proper ACQ FIFO depth
  assign acq_fifo_depth_o = xfer_read ? 0 : {{(AcqFifoDepthWidth - 3){1'b0}},
                                             state_d == PushDWordToTTIQueue,
                                             transaction_byte_count[1:0]};

  always_ff @(posedge clk_i or negedge rst_ni) begin : state_transition
    if (!rst_ni) state_q <= AwaitStart;
    else state_q <= state_d;
  end : state_transition

  always_ff @(posedge clk_i or negedge rst_ni) begin : accumulate_bytes_in_dword
    if (!rst_ni) begin
      for (integer i = 0; i < AcqFifoDepth; i = i + 1) begin : gen_clear_buf
        fifo_buf[i] <= 0;
      end
    end else begin
      if (!xfer_read) begin
        // Write transfer
        if (data_detected) begin
          fifo_buf[byte_count] <= acq_fifo_wdata_i;
        end
      end else begin
        // Read transfer
        if (pop_data_from_tti) begin
          // TODO(verilator) fails to consftify loop variable for AstSelExtract
          fifo_buf[0] <= {AcqData, tx_fifo_rdata_i[7:0]};
        end
      end
    end
  end : accumulate_bytes_in_dword

  always_ff @(posedge clk_i or negedge rst_ni) begin : change_byte_count
    if (!rst_ni) begin
      transaction_byte_count <= 0;
    end else if (reset_byte_count) begin
      transaction_byte_count <= 0;
    end else begin
      if (push_byte) begin
        transaction_byte_count <= transaction_byte_count + 1;
      end
    end
  end : change_byte_count

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_transfer_active
    if (!rst_ni) begin
      transfer_active <= 0;
    end else begin
      if (activate_transfer) transfer_active <= 1;
      else if (deactivate_transfer) transfer_active <= 0;
    end
  end : update_transfer_active


  always_ff @(posedge clk_i or negedge rst_ni) begin : undriven_update_resp_data_length
    response_fifo_wdata_o.__rsvd23_16 <= '0;
    // TODO: Implement, controller functionality skipped for now
    response_fifo_wdata_o.err_status <= i3c_resp_err_status_e'(0);
    response_fifo_wdata_o.tid <= '0;
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_resp_data_length
    if (!rst_ni) begin
      response_fifo_wdata_o.data_length <= 0;
    end
    else if (deactivate_transfer) response_fifo_wdata_o.data_length <= transaction_byte_count;
  end : update_resp_data_length

  always_ff @(posedge clk_i or negedge rst_ni) begin : get_command_from_tti
    if (!rst_ni) begin
      read_transaction_length <= 0;
    end else begin
      if (pop_command_from_tti) read_transaction_length <= cmd_fifo_rdata_i.data_length;
    end
  end : get_command_from_tti

  // State combo logic

  always_comb begin : state_outputs
    err_o = 0;
    rx_fifo_wvalid_o = 0;
    push_byte = 0;
    reset_byte_count = 0;
    activate_transfer = 0;
    deactivate_transfer = 0;
    response_fifo_wvalid_o = 0;
    xfer_read = 0;
    cmd_fifo_rready_o = 0;
    tx_fifo_rready_o = 0;
    tx_fifo_rvalid_o = 0;
    pop_command_from_tti = 0;
    pop_data_from_tti = 0;

    unique case (state_q)
      AwaitStart: begin
        reset_byte_count = 1;
      end
      ReceiveByte: begin
        push_byte = data_detected;
      end
      ReportError: begin
        err_o = 1;
      end
      PushDWordToTTIQueue: begin
        rx_fifo_wvalid_o = 1;
      end
      PushResponseToTTIQueue: begin
        response_fifo_wvalid_o = 1;
      end
      PopCommandFromTTIQueue: begin
        cmd_fifo_rready_o = 1;
        tx_fifo_rready_o = 1;
        pop_command_from_tti = cmd_fifo_rvalid_i;
        pop_data_from_tti = tx_fifo_rvalid_i;
        xfer_read = 1;
      end
      PopDWordFromTTIQueue: begin
        tx_fifo_rready_o = 1;
        pop_data_from_tti = tx_fifo_rvalid_i;
        xfer_read = 1;
      end
      SendByte: begin
        xfer_read = 1;
        push_byte = tx_fifo_rready_i;
        tx_fifo_rvalid_o = 1;
      end
      SwitchByteToSend: begin
        xfer_read = 1;
      end
      AwaitStopOrRestart: begin
      end
      default: begin
      end
    endcase

    activate_transfer   = start_detected;
    deactivate_transfer = stop_detected | restart_detected;

    if (xfer_read) tx_fifo_rdata_o = fifo_buf[byte_count][7:0];
    else tx_fifo_rdata_o = 0;
  end : state_outputs

  always_comb begin : state_function

    unique case (state_q)
      AwaitStart:
      if (start_detected) begin
        state_d = is_start_read ? PopCommandFromTTIQueue : ReceiveByte;
      end else  // TODO: Assert that acq_fifo_wdata_byte_id != i2c_pkg::AcqNackStart
        state_d = AwaitStart;
      ReceiveByte: begin
        state_d = ReceiveByte;
        if (stop_detected | restart_detected) begin
          state_d = (byte_count != 0) ? PushDWordToTTIQueue : PushResponseToTTIQueue;
        end else if (data_detected) state_d = (byte_count == 3) ? PushDWordToTTIQueue : ReceiveByte;
        else if (acq_fifo_wvalid_i) state_d = ReportError;
      end
      PushDWordToTTIQueue:
      if (rx_fifo_wready_i) state_d = transfer_active ? ReceiveByte : PushResponseToTTIQueue;
      else
      // We can't wait any longer if there's a new byte, because we might be full
      // TODO: We need to handle stop/restart that was received in `ReceiveByte`,
      // but invalidated one cycle later.
      if (stop_detected | restart_detected)
        state_d = PushDWordToTTIQueue;
      else state_d = acq_fifo_wvalid_i ? ReportError : PushDWordToTTIQueue;
      PushResponseToTTIQueue: begin
        state_d = PushResponseToTTIQueue;
        if (response_fifo_wready_i) state_d = AwaitStart;
        // We can't wait any longer if there's a new byte, because we might be full
        else if (acq_fifo_wvalid_i) state_d = ReportError;
      end
      PopCommandFromTTIQueue: begin
        state_d = PopCommandFromTTIQueue;
        if (cmd_fifo_rvalid_i) begin
          if (cmd_fifo_rdata_i.data_length == 0) state_d = ReportError;
          else state_d = tx_fifo_rvalid_i ? SendByte : PopDWordFromTTIQueue;
        end
        if (nack_detected) state_d = ReportError;
      end
      PopDWordFromTTIQueue: begin
        state_d = PopDWordFromTTIQueue;
        if (tx_fifo_rvalid_i) state_d = SendByte;
        if (nack_detected) state_d = ReportError;
      end
      SendByte: begin
        state_d = SendByte;
        if (tx_fifo_rready_i)
          if (transaction_byte_count + 1 == read_transaction_length) state_d = AwaitStopOrRestart;
          else
            // Let the counter increment in a another cycle, so we hold tx_fifo_rvalid
            // with the correct byte set
            state_d = SwitchByteToSend;
        if (nack_detected) state_d = ReportError;
      end
      SwitchByteToSend: begin
        state_d = SendByte;
        if ((byte_count == 0) & (transaction_byte_count != read_transaction_length))
          state_d = PopDWordFromTTIQueue;
        if (nack_detected) state_d = ReportError;
      end
      AwaitStopOrRestart: begin
        state_d = AwaitStopOrRestart;
        if (stop_detected | restart_detected) state_d = AwaitStart;
        else if (nack_detected) state_d = ReportError;
      end
      default: state_d = ReportError;
    endcase
  end : state_function

endmodule
