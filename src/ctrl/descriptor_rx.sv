// SPDX-License-Identifier: Apache-2.0

/*
  This module is responsible for handling the RX descriptors.

  * The target FSM produces data during Private Writes
  * This data is written to the RX queue
  * Target FSM notifies that the last byte was written
  * This module generates an RX descriptor

  Handshake between RX descriptor and target FSM:
  * If the RX queue has enough space, then ready is set
  * Ready is set throughout the whole transfer
  * The target FSM sets the valid to HIGH for exactly 1 cycle
    * A data byte is available
  * If during the transfer, the queue becomes full, then the
  ready will be deasserted.

  If the target FSM detects that:
    * RX queue is full
    * there are more bytes to write
  , then it will assert an error signal.

  There is no way to signal to the controller about this error,
  except for bit error in the GETSTATUS CCC.
*/
module descriptor_rx #(
    parameter int unsigned TtiRxDescDataWidth = 32,
    parameter int unsigned TtiRxDataWidth = 8
) (
    input logic clk_i,
    input logic rst_ni,

    // TTI: RX Descriptor
    output logic tti_rx_desc_queue_wvalid_o,
    output logic [TtiRxDescDataWidth-1:0] tti_rx_desc_queue_wdata_o,

    // TTI: RX Data
    input logic tti_rx_queue_wready_i,
    output logic tti_rx_queue_wvalid_o,
    output logic tti_rx_queue_flush_o,
    output logic [TtiRxDataWidth-1:0] tti_rx_queue_wdata_o,

    // Interface to the target FSM
    input logic [7:0] rx_byte_i,
    input logic rx_byte_last_i,
    input logic rx_byte_valid_i,
    output logic rx_byte_ready_o,
    input logic rx_byte_err_i
);

  logic [31:0] rx_descriptor;
  logic [15:0] byte_counter;
  logic [15:0] byte_counter_q;
  logic [3:0] rx_error;

  logic transfer_ended;
  logic transfer_ended_q;

  assign transfer_ended = rx_byte_last_i | rx_byte_err_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_byte_counter
    if (!rst_ni) begin
      byte_counter <= '0;
    end else begin
      if (transfer_ended) begin
        byte_counter <= '0;
      end else if (rx_byte_ready_o && rx_byte_valid_i) begin
        byte_counter <= byte_counter + 1'b1;
      end else begin
        byte_counter <= byte_counter;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_error
    if (!rst_ni) begin
      byte_counter_q <= '0;
      transfer_ended_q <= '0;
      rx_error <= '0;
    end else begin
      transfer_ended_q <= transfer_ended;
      if (transfer_ended) begin
        byte_counter_q <= byte_counter;
      end
      if (transfer_ended) begin
        if (rx_byte_err_i) rx_error <= 4'b0001;
        else rx_error <= 4'b0000;
      end
    end
  end

  assign tti_rx_queue_wvalid_o = rx_byte_valid_i;
  assign rx_byte_ready_o = tti_rx_queue_wready_i;
  assign tti_rx_queue_wdata_o = rx_byte_i;

  assign rx_descriptor = {rx_error, {12{1'b0}}, byte_counter_q};
  assign tti_rx_desc_queue_wdata_o = rx_descriptor;
  assign tti_rx_desc_queue_wvalid_o = transfer_ended_q;
  assign tti_rx_queue_flush_o = transfer_ended_q;

endmodule
