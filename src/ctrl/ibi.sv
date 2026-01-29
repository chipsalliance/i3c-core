// SPDX-License-Identifier: Apache-2.0

/*
  The module begins IBI sequence upon assertion of begin_i and asserts
  done_o for one cycle when it is complete.

  This module handles target IBIs. IBI data (MDB + optional data) comes
  through the ibi_byte_* interface. Data to be sent over I3C comes out
  through bus_tx_* interface whereas ACK/NACK response comes in through
  bus_rx_* interface.

  IBI address is set via target_ibi_addr_i.
*/

module ibi import i3c_pkg::*; (
  input  logic clk_i,
  input  logic rst_ni,

  // Control / status
  input  logic [2:0] ibi_retry_num_i,  // TTI.CONTROL.IBI_RETRY_NUM
  input  logic       ibi_abort_i,      // Aborts IBI and flushes TTI IBI Queue

  output logic [1:0] ibi_status_o,    // TTI.STATUS.LAST_IBI_STATUS
  output logic       ibi_status_we_o, // IBI status write enable

  input  logic begin_i,  // Begin driving the IBI
  output logic done_o,   // FSM is done with the IBI

  // IBI address
  input  logic [6:0] target_ibi_addr_i,

  // IBI data interface
  input  logic      ibi_byte_valid_i,
  output logic      ibi_byte_ready_o,
  input  i3c_byte_t ibi_byte_i,
  input  logic      ibi_byte_last_i,

  // Bus Monitor interface
  input  logic scl_negedge_i,
  input  logic scl_posedge_i,
  input  logic bus_available_i,
  input  logic bus_stop_i,
  input  logic bus_rstart_i,
  input  logic arbitration_lost_i,

  // Bus Tx interface
  output bus_tx_req_t bus_tx_req_o,
  input  bus_tx_rsp_t bus_tx_rsp_i,

  // Bus Rx interface
  output bus_rx_req_t bus_rx_req_o,
  input  bus_rx_rsp_t bus_rx_rsp_i
);

  // IBI status codes
  typedef enum logic [1:0] {
    IbiSuccess            = 2'b00,
    IbiFailureNack        = 2'b01,
    IbiFailurePartialData = 2'b10,
    IbiFailureRetry       = 2'b11
  } ibi_status_e;

  ibi_status_e ibi_status_q, ibi_status_d;

  logic [2:0] ibi_retry_cnt_q, ibi_retry_cnt_d;
  logic       ibi_can_retry;

  i3c_byte_t bus_tx_req_value;

  logic bus_rx_req_nack;

  // FSM
  typedef enum logic [7:0] {
    // Wait state
    Idle,
    // Request to drive SDA low and transmit target address
    DriveIbiAddr,
    // Receive ACK/NACK
    ReadAck,
    // Wait for falling SCL (do not change sel_od_pp_o when SCL is high)
    WaitForSclNegedgeAfterAck,
    // Transmit data byte
    SendData,
    // Transmit T bit
    SendTbit,
    // Wait for stop condition
    WaitStopOrRstart,
    // Flush remaining IBI data bytes
    Flush,
    // Signal to primary FSM that IBI is done
    Done
  } state_e;

  state_e state_q, state_d;

  // Retry counter
  always_comb begin
    ibi_retry_cnt_d = ibi_retry_cnt_q;

    if (ibi_status_q == IbiFailureNack) begin
      ibi_retry_cnt_d = ibi_retry_cnt_q + 1;
    end else begin
      ibi_retry_cnt_d = '1;
    end
  end

  // Nack by controller is LSB of received data
  assign bus_rx_req_nack = bus_rx_rsp_i.data[0];

  // Retry allowed if count not yet met or indefinite attempts allowed
  assign ibi_can_retry = (ibi_retry_num_i == 3'd7) || (ibi_retry_num_i != ibi_retry_cnt_q);

  assign bus_tx_req_o = '{
    drive_type: (state_q inside {SendData, SendTbit}) ? PushPull : OpenDrain,
    req_byte:   (state_q inside {SendData}),
    req_bit:    (state_q == SendTbit),
    req_ibi:    (state_q == DriveIbiAddr),
    data:       bus_tx_req_value
  };

  assign bus_rx_req_o = '{
    req_bit:  (state_q == ReadAck),
    req_byte: 1'b0
  };

  always_comb begin : fsm_ibi
    bus_tx_req_value = '0;
    ibi_byte_ready_o = 1'b0;
    ibi_status_we_o  = 1'b0;
    done_o = 1'b0;

    state_d      = state_q;
    ibi_status_d = ibi_status_q;
    case (state_q)
      Idle: begin
        if (bus_stop_i) begin
          state_d = Done;
        end else if (begin_i) begin
          state_d = ibi_can_retry ? DriveIbiAddr : Flush;
        end
      end
      DriveIbiAddr: begin
        // In this state, we send an IBI request to bus_tx_flow, which then first pulls SDA low and
        // subsequently transmits our IBI address, starting at the following negedge of SCL.
        bus_tx_req_value = {target_ibi_addr_i, 1'b1};

        if (bus_stop_i) begin
          state_d = Done;
        end else if (bus_tx_rsp_i.done) begin
          state_d = ReadAck;
        end else if (arbitration_lost_i) begin
          done_o  = 1'b1;
          state_d = WaitStopOrRstart;
        end
      end
      ReadAck: begin
        if (bus_stop_i) begin
          state_d = Done;
        end else if (bus_rx_rsp_i.done) begin
          if (bus_rx_req_nack) begin
            ibi_status_d = (ibi_status_q == IbiSuccess) ? IbiFailureNack : IbiFailureRetry;
            state_d = WaitStopOrRstart;
          end else begin
            state_d = WaitForSclNegedgeAfterAck;
          end
        end
      end
      WaitForSclNegedgeAfterAck: begin
        if (scl_negedge_i) state_d = SendData;
      end
      SendData: begin
        bus_tx_req_value = ibi_byte_i;

        if (bus_stop_i) begin
          ibi_status_d = (ibi_status_q == IbiSuccess) ? IbiFailurePartialData : IbiFailureRetry;
          state_d = Flush;
        end else if (bus_tx_rsp_i.done) begin
          if (ibi_byte_last_i) begin
            ibi_status_d = IbiSuccess;
          end
          state_d = SendTbit;
        end
      end
      SendTbit: begin
        bus_tx_req_value[7] = ~ibi_byte_last_i;
        ibi_byte_ready_o    = bus_tx_rsp_i.done;

        if (bus_stop_i) begin
          ibi_status_d = (ibi_status_q == IbiSuccess) ? IbiFailurePartialData : IbiFailureRetry;
          state_d = Flush;
        end else if (bus_tx_rsp_i.done) begin
          state_d = ibi_byte_last_i ? Done : SendData;
        end
      end
      WaitStopOrRstart: begin
        ibi_status_we_o = bus_stop_i;
        if (bus_stop_i || bus_rstart_i) state_d = Idle;
      end
      Flush: begin
        ibi_byte_ready_o = 1'b1;
        if (!ibi_byte_valid_i) state_d = Done;
      end
      Done: begin
        ibi_status_we_o = 1'b1;
        done_o = 1'b1;
        state_d = Idle;
      end
      default: ;
    endcase
  end

  assign ibi_status_o = ibi_status_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q         <= Idle;
      ibi_status_q    <= IbiSuccess;
      ibi_retry_cnt_q <= '1; // TODO
    end else begin
      state_q         <= state_d;
      ibi_status_q    <= ibi_status_d;
      ibi_retry_cnt_q <= ibi_retry_cnt_d;
    end
  end

endmodule
