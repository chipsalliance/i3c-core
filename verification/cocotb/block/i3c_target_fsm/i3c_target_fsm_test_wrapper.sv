// SPDX-License-Identifier: Apache-2.0
module i3c_target_fsm_test_wrapper
  import controller_pkg::*;
#(
    parameter int unsigned RxDataWidth = 8,
    parameter int unsigned TxDataWidth = 8
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

    input logic scl_i,
    input logic sda_i,

    // I3C bus timings
    input logic [12:0] t_r_i,      // rise time of both SDA and SCL in clock units
    input logic [12:0] t_f_i,      // rise time of both SDA and SCL in clock units
    input logic [12:0] t_hd_dat_i,

    input logic target_enable_i,  // enable target functionality

    // Bus monitor interface
    input logic bus_start_det_i,
    input logic bus_stop_det_i,
    input logic bus_timeout_i,  // The bus timed out, with SCL held low for too long.

    output logic target_idle_o,  // indicates the target is idle
    output logic target_transmitting_o,  // Target is transmitting SDA (disambiguates high sda_o)

    // Bus TX interface
    input logic bus_tx_req_err_i,
    input logic bus_tx_done_i,
    input logic bus_tx_idle_i,
    output logic bus_tx_req_byte_o,
    output logic bus_tx_req_bit_o,
    output logic [TxDataWidth-1:0] bus_tx_req_value_o,

    // Bus RX interface
    output logic bus_rx_req_bit_o,
    output logic bus_rx_req_byte_o,
    input logic bus_rx_done_i,
    input logic bus_rx_idle_i,
    input logic [RxDataWidth-1:0] bus_rx_data_i,
    input logic bus_rx_error_i,

    // TX FIFO used for Target Read
    input  logic                   tx_fifo_rvalid_i,  // indicates there is valid data in tx_fifo
    output logic                   tx_fifo_rready_o,  // pop entry from tx_fifo
    input  logic [TxFifoWidth-1:0] tx_fifo_rdata_i,   // byte in tx_fifo to be sent to host
    output logic                   tx_host_nack_o,    // NACK has been received during transmission

    // RX FIFO used for Target Write
    output logic                   rx_fifo_wvalid_o,  // high if there is valid data in rx_fifo
    output logic [RxFifoWidth-1:0] rx_fifo_wdata_o,   // data to write to rx_fifo from target
    input  logic                   rx_fifo_wready_i,
    output logic                   rx_last_byte_o,

    // IBI FIFO
    input  logic                    ibi_fifo_rvalid_i,
    output logic                    ibi_fifo_rready_o,
    input  logic [IbiFifoWidth-1:0] ibi_fifo_rdata_i,

    // IBI address
    input logic [6:0] target_sta_address_i,
    input logic target_sta_address_valid_i,
    input logic [6:0] target_dyn_address_i,
    input logic target_dyn_address_valid_i,
    input logic [6:0] target_ibi_address_i,
    input logic target_ibi_address_valid_i,

    output logic event_target_nack_o,  // this target sent a NACK (this is used to keep count)
    output logic event_cmd_complete_o,  // Command is complete
    output logic event_unexp_stop_o,  // target received an unexpected stop
    output logic event_tx_arbitration_lost_o,  // Arbitration was lost during a read transfer
    output logic event_tx_bus_timeout_o,  // Bus timed out during a read transfer
    output logic event_read_cmd_received_o,  // A read awaits confirmation for TX FIFO release

    input logic        target_reset_detect_i,
    input  logic       hdr_exit_detect_i,
    output logic [7:0] rst_action_o,
    output logic       is_in_hdr_mode_o,

    // Interfacing with subFSMs
    input logic is_ibi_done_i,
    input logic is_ccc_done_i,
    input logic is_hotjoin_done_i,

    input logic scl_negedge_i,
    input logic scl_posedge_i,
    input logic sda_negedge_i,
    input logic sda_posedge_i,

    output logic parity_err_o,
    output logic rx_overflow_err_o
);

  i3c_target_fsm xi3c_target_fsm (.*);
endmodule
