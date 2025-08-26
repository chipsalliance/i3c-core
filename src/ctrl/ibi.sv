// SPDX-License-Identifier: Apache-2.0

/*
    The module begins IBI sequence upon assertion of begin_i and asserts
    done_o for one cycle when it is complete.

    This module handles target IBIs. IBI data (MDB + optional data) comes
    through the ibi_byte_* interface. Data to be sent over I3C comes out
    through bus_tx_* interface whereas ACK/NACK response comes in through
    bus_rx_* interface.

    IBI address is set via target_ibi_addr_i. When the address isnt valid
    (target_ibi_addr_valid_i == 0) then the module does not respond to
    begin_i.
*/
module ibi (

    input logic clk_i,
    input logic rst_ni,

    // Control / status
    input logic [2:0] ibi_retry_num_i,  // TTI.CONTROL.IBI_RETRY_NUM
    input logic       ibi_abort_i,      // Aborts IBI and flushes TTI IBI Queue

    output logic [1:0] ibi_status_o,    // TTI.STATUS.LAST_IBI_STATUS
    output logic       ibi_status_we_o, // IBI status write enable

    input  logic begin_i,  // Begin driving the IBI
    output logic done_o,   // FSM is done with the IBI

    // IBI address
    input logic [6:0] target_ibi_addr_i,
    input logic       target_ibi_addr_valid_i,

    // IBI data interface
    input  logic       ibi_byte_valid_i,
    output logic       ibi_byte_ready_o,
    input  logic [7:0] ibi_byte_i,
    input  logic       ibi_byte_last_i,
    output logic       ibi_byte_err_o,

    // Bus Monitor interface
    input logic scl_negedge_i,
    input logic scl_posedge_i,
    input logic bus_available_i,
    input logic bus_stop_i,
    input logic bus_rstart_i,

    // Bus TX interface
    input logic bus_tx_done_i,
    output logic bus_tx_req_byte_o,
    output logic bus_tx_req_bit_o,
    output logic [7:0] bus_tx_req_value_o,
    output logic bus_tx_sel_od_pp_o,

    // Bus RX interface
    input logic bus_rx_done_i,
    output logic bus_rx_req_byte_o,
    output logic bus_rx_req_bit_o,
    input logic [7:0] bus_rx_req_value_i,

    // Bus drive interface
    input  logic [19:0] t_hd_dat_i,
    input logic arbitration_lost_i,
    output logic sda_o
);

  // IBI status codes
  typedef enum logic [1:0] {
    IbiSuccess            = 2'b00,
    IbiFailureNack        = 2'b01,
    IbiFailurePartialData = 2'b10,
    IbiFailureRetry       = 2'b11
  } ibi_status_e;

  ibi_status_e       ibi_status;
  logic        [2:0] ibi_retry_cnt;
  logic              ibi_can_retry;

  logic [19:0] tcount;

  // NACK
  logic              bus_rx_req_nack;
  assign bus_rx_req_nack = bus_rx_req_value_i[0];

  // Unconnected
  always_comb begin
    ibi_byte_err_o = '0;
  end

  // FSM
  typedef enum logic [7:0] {
    // Wait state
    Idle,
    // Wait for the bus to become available
    WaitAvail,
    // Force start by pulling SDA low
    DriveStart,
    // Transmitt target address
    DriveAddr,
    // Receive ACK/NACK
    ReadAck,
    // Wait for falling SCL (do not change sel_od_pp_o when SCL is high)
    WaitForSclNegedgeAfterAck,
    // Transmitt data byte
    SendData,
    // Transmitt T bit
    SendTbit,
    // Wait for stop condition
    WaitStopOrRstart,
    // Flush remaining IBI data bytes
    Flush,
    // Signal to primary FSM that IBI is done
    Done
  } state_e;

  state_e state_q;

  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) state_q <= Idle;
    else
      case (state_q)
        Idle:
        if (begin_i && target_ibi_addr_valid_i)
          if (ibi_can_retry) state_q <= WaitAvail;
          else state_q <= Flush;

        WaitAvail:
        if (bus_stop_i) state_q <= Done;
        else if (bus_available_i) state_q <= DriveStart;

        DriveStart:
        if (bus_stop_i) state_q <= Done;
        else begin
          if (t_hd_dat_i == 20'd0 && scl_negedge_i)
              state_q <= DriveAddr;
          if (tcount == 20'd0)
              state_q <= DriveAddr;
        end

        DriveAddr:
        if (bus_stop_i) state_q <= Done;
        else if (bus_tx_done_i) state_q <= ReadAck;
        else if (arbitration_lost_i) state_q <= WaitStopOrRstart;

        ReadAck:
        if (bus_stop_i) state_q <= Done;
        else if (bus_rx_done_i)
          if (bus_rx_req_nack)  // NACK
            state_q <= WaitStopOrRstart;
          else  // ACK
            state_q <= WaitForSclNegedgeAfterAck;

        WaitForSclNegedgeAfterAck:
        if (scl_negedge_i) state_q <= SendData;

        SendData:
        if (bus_stop_i) state_q <= Flush;
        else if (bus_tx_done_i) state_q <= SendTbit;

        SendTbit:
        if (bus_stop_i) state_q <= Flush;
        else if (bus_tx_done_i) state_q <= ibi_byte_last_i ? Done : SendData;

        WaitStopOrRstart: if (bus_stop_i | bus_rstart_i) state_q <= Idle;

        Flush: if (!ibi_byte_valid_i) state_q <= Done;

        Done:    state_q <= Idle;
        default: state_q <= Idle;
      endcase

  // SDA pull
  assign sda_o = !(state_q == DriveStart);

  // SCL fall time counter
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni)
      tcount <= 20'(-1);
    else begin
      if (state_q == DriveStart && scl_negedge_i)
        tcount <= t_hd_dat_i - 20'd1;
      else if (tcount != 20'(-1))
        tcount <= tcount - 20'd1;
    end

  // Bus tx and rx control
  always_comb begin
    bus_tx_req_byte_o  = '0;
    bus_tx_req_bit_o   = '0;
    bus_tx_req_value_o = '0;
    bus_tx_sel_od_pp_o = '0;

    bus_rx_req_byte_o  = '0;
    bus_rx_req_bit_o   = '0;

    case (state_q)
      DriveAddr: begin
        bus_tx_req_byte_o  = 1'b1;
        bus_tx_req_value_o = {target_ibi_addr_i, 1'b1};
      end
      ReadAck: begin
        bus_rx_req_bit_o = 1'b1;
      end
      SendData: begin
        bus_tx_req_byte_o  = 1'b1;
        bus_tx_req_value_o = ibi_byte_i;
        bus_tx_sel_od_pp_o = 1'b1;
      end
      SendTbit: begin
        bus_tx_req_bit_o   = 1'b1;
        bus_tx_req_value_o = 8'(!ibi_byte_last_i);
        bus_tx_sel_od_pp_o = 1'b1;
      end
      default: begin
        bus_tx_req_byte_o  = '0;
        bus_tx_req_value_o = '0;
        bus_tx_sel_od_pp_o = '0;
      end
    endcase
  end

  // Data FIFO control
  always_comb begin
    ibi_byte_ready_o = '0;

    case (state_q)
      SendTbit: if (bus_tx_done_i) ibi_byte_ready_o = 1'b1;
      Flush: ibi_byte_ready_o = 1'b1;
      default: begin
        ibi_byte_ready_o = '0;
      end
    endcase
  end

  // IBI status
  always_ff @(posedge clk_i or negedge rst_ni)
    if (~rst_ni) ibi_status <= IbiSuccess;
    else
      case (state_q)

        SendData:
        if (bus_stop_i) begin
          if (ibi_status == IbiSuccess) ibi_status <= IbiFailurePartialData;
          else ibi_status <= IbiFailureRetry;
        end

        SendTbit:
        if (bus_stop_i) begin
          if (ibi_status == IbiSuccess) ibi_status <= IbiFailurePartialData;
          else ibi_status <= IbiFailureRetry;
        end else if (bus_tx_done_i && ibi_byte_last_i) ibi_status <= IbiSuccess;

        ReadAck:
        if (bus_rx_done_i && bus_rx_req_nack) begin
          if (ibi_status == IbiSuccess) ibi_status <= IbiFailureNack;
          else ibi_status <= IbiFailureRetry;
        end
        default: begin
          ibi_status <= ibi_status;
        end
      endcase

  // Retry counter
  always_ff @(posedge clk_i or negedge rst_ni)
    if (~rst_ni) ibi_retry_cnt <= 3'd7;
    else if (state_q == Done)
      if (ibi_status == IbiFailureNack) ibi_retry_cnt <= ibi_retry_cnt + 1'b1;
      else ibi_retry_cnt <= 3'd7;

  // Retry allowed
  assign ibi_can_retry = (ibi_retry_num_i == 3'd7) ||
                           (ibi_retry_num_i != ibi_retry_cnt);


  assign done_o = (state_q == Done || (state_q == DriveAddr && arbitration_lost_i && ~bus_tx_done_i));

  assign ibi_status_o    = ibi_status;
  assign ibi_status_we_o = (state_q == Done) | ((state_q == WaitStopOrRstart) & bus_stop_i);

endmodule
