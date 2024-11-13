// SPDX-License-Identifier: Apache-2.0

/*
  This module is responsible for parsing and generating descriptors.
*/
module flow_standby_i3c
  import controller_pkg::*;
  import i3c_pkg::*;
#(
    parameter int unsigned TtiRxDescDataWidth = 32,
    parameter int unsigned TtiTxDescDataWidth = 32,
    parameter int unsigned TtiRxDataWidth = 8,
    parameter int unsigned TtiTxDataWidth = 8,
    parameter int unsigned TtiIbiDataWidth = 32,

    parameter int unsigned TtiRxDescThldWidth = 8,
    parameter int unsigned TtiTxDescThldWidth = 8,
    parameter int unsigned TtiRxThldWidth = 3,
    parameter int unsigned TtiTxThldWidth = 3
) (
    input logic clk_i,
    input logic rst_ni,

    // TTI: RX Descriptor
    input logic tti_rx_desc_queue_full_i,
    input logic [TtiRxDescThldWidth-1:0] tti_rx_desc_queue_ready_thld_i,
    input logic tti_rx_desc_queue_ready_thld_trig_i,
    input logic tti_rx_desc_queue_empty_i,
    output logic tti_rx_desc_queue_wvalid_o,
    input logic tti_rx_desc_queue_wready_i,
    output logic [TtiRxDescDataWidth-1:0] tti_rx_desc_queue_wdata_o,

    // TTI: TX Descriptor
    input logic tti_tx_desc_queue_full_i,
    input logic [TtiTxDescThldWidth-1:0] tti_tx_desc_queue_ready_thld_i,
    input logic tti_tx_desc_queue_ready_thld_trig_i,
    input logic tti_tx_desc_queue_empty_i,
    input logic tti_tx_desc_queue_rvalid_i,
    output logic tti_tx_desc_queue_rready_o,
    input logic [TtiTxDescDataWidth-1:0] tti_tx_desc_queue_rdata_i,

    // TTI: RX Data
    input logic tti_rx_queue_full_i,
    input logic [TtiRxThldWidth-1:0] tti_rx_queue_start_thld_i,
    input logic tti_rx_queue_start_thld_trig_i,
    input logic [TtiRxThldWidth-1:0] tti_rx_queue_ready_thld_i,
    input logic tti_rx_queue_ready_thld_trig_i,
    input logic tti_rx_queue_empty_i,
    output logic tti_rx_queue_wvalid_o,
    input logic tti_rx_queue_wready_i,
    output logic [TtiRxDataWidth-1:0] tti_rx_queue_wdata_o,
    output logic tti_rx_queue_wflush_o,

    // TTI: TX Data
    input logic tti_tx_queue_full_i,
    input logic [TtiTxThldWidth-1:0] tti_tx_queue_start_thld_i,
    input logic tti_tx_queue_start_thld_trig_i,
    input logic [TtiTxThldWidth-1:0] tti_tx_queue_ready_thld_i,
    input logic tti_tx_queue_ready_thld_trig_i,
    input logic tti_tx_queue_empty_i,
    input logic tti_tx_queue_rvalid_i,
    output logic tti_tx_queue_rready_o,
    input logic [TtiTxDataWidth-1:0] tti_tx_queue_rdata_i,
    output logic tti_tx_host_nack_o,

    // In-band Interrupt queue
    input logic ibi_queue_full_i,
    input logic [HciIbiThldWidth-1:0] ibi_queue_thld_i,
    input logic ibi_queue_above_thld_i,
    input logic ibi_queue_empty_i,
    input logic ibi_queue_rvalid_i,
    output logic ibi_queue_rready_o,
    input logic [TtiIbiDataWidth-1:0] ibi_queue_rdata_i,

    // Interface to the target FSM
    input logic private_read_begin_i,
    input logic private_read_end_i,

    input logic private_write_begin_i,
    input logic private_write_end_i,

    // Receive byte from the bus
    input logic rx_byte_valid_i,
    input logic [7:0] rx_byte_i,
    output logic rx_byte_ready_o,

    // Transmit byte onto the bus
    output logic tx_byte_valid_o,
    output logic [7:0] tx_byte_o,
    input logic tx_byte_ready_i

);

  // Read descriptor
  logic [31:0] tx_descriptor;
  logic tx_descriptor_valid;
  always_ff @( posedge clk_ni or negedge rst_ni ) begin : proc_read_tx_descriptor
    if (~rst_ni) begin
        tx_descriptor <= '0;
        tx_descriptor_valid <= '0;
    end else begin
        if(tti_tx_desc_queue_rvalid_o) begin
          if(tti_tx_desc_queue_rready_i) begin
            tti_tx_desc_queue_rvalid_o <= '0;
            tx_descriptor <= tti_tx_desc_queue_rdata_i;
          end
        end else begin
          if(state_q == ReadDescriptor)
            tti_tx_desc_queue_rvalid_o <= '1;
        end

        if (tti_tx_desc_queue_rvalid_o && tti_tx_desc_queue_rready_i)
          tx_descriptor_valid <= '1;
        else if(state_q == ReadIdle)
          tx_descriptor_valid <= '0;
    end
  end

  logic [16:0] tx_desc_num_bytes;
  assign tx_desc_num_bytes = tx_descriptor[15:0];


  // Read Data
  logic [7:0] curr_byte;
  logic [7:0] tx_byte_id;
  always_ff @( posedge clk_i or negedge rst_ni ) begin : proc_read_data
    if (~rst_ni) begin
        tx_byte_valid_o <= '0;
        tx_byte_id <= '0;
    end else begin
        if(tx_byte_valid_o) begin
          tx_byte_valid_o <= '0;
          tx_byte_id <= tx_byte_id + 1'b1;
        end else begin
          if (tti_tx_queue_rvalid_o) begin
            if (tti_tx_queue_rready_i)
                tx_byte_valid_o <= '1;
          end else begin
            if (tx_byte_ready_i) begin
              tti_tx_queue_rvalid_o <= '1;
            end
          end
        end
    end
  end

  typedef enum logic [7:0] {
    // Generic wait state
    ReadIdle,
    // Read the descriptor
    // Respond with N data bytes
    ReadDescriptor,
    ReadData
  } pread_state_e;

  pread_state_e state_q, state_d;


  // Simplified RX/TX transfer handler
  assign rx_byte_ready_o = rx_byte_valid_i;  //TODO: temporarily always accept transfers

  always_comb begin : state_functions
    case (state_q)
      ReadIdle: begin
          if(private_read_begin_i)
            state_d = ReadDescriptor;
      end
      ReadDescriptor: begin
          if(tti_tx_desc_queue_empty || tti_tx_data_queue_empty) begin
              state_d = Idle;
          end else if(descriptor_valid)
            state_d = ReadData;
      end
      ReadData: begin
          if(private_read_end_i)
            state_d = ReadIdle;
      end
      default: begin
        state_d = state_q;
      end
    endcase
  end

  // Pass through TX data from the queue
  assign tx_byte_o = tx_queue_rdata_i;
  assign tx_byte_valid_o = tx_queue_rvalid_i;
  assign tx_queue_rready_o = tx_byte_ready_i;

  // Pass data to TTI RX queue

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_tti_rx
    if (~rst_ni) begin
      rx_queue_wdata_o  <= '0;
      rx_queue_wvalid_o <= '0;
    end else begin
      if (rx_byte_valid_i && rx_byte_ready_o) begin
        rx_queue_wdata_o  <= rx_byte_i;
        rx_queue_wvalid_o <= '1;
      end else begin
        rx_queue_wdata_o  <= '0;
        rx_queue_wvalid_o <= '0;
      end
    end
  end

  assign rx_queue_wflush_o = transfer_stop_i;

endmodule
