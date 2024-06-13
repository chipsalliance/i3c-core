// SPDX-License-Identifier: Apache-2.0

// TODO: Consider arbitration difference from i2c:
// Section 5.1.4
// 48b provisioned id and bcr, dcr are used.
// This is to enable dynamic addressing.

module i3c_ctrl
  import i3c_ctrl_pkg::*;
  import i2c_pkg::*;
  import i3c_pkg::*;
  import hci_pkg::*;
#(
    parameter int TEMP = 0
) (
    input  logic clk,
    input  logic rst_n,
    // Interface to SDA/SCL
    input  logic sda_i,
    output logic sda_o,
    input  logic scl_i,
    output logic scl_o,

    // HCI queues
    // Command FIFO
    input logic [CmdThldWidth-1:0] cmd_queue_thld_i,
    input logic cmd_queue_full_i,
    input logic cmd_queue_below_thld_i,
    input logic cmd_queue_empty_i,
    input logic cmd_queue_rvalid_i,
    output logic cmd_queue_rready_o,
    input logic [CmdFifoWidth-1:0] cmd_queue_rdata_i,
    // RX FIFO
    input logic [RxThldWidth-1:0] rx_queue_thld_i,
    input logic rx_queue_full_i,
    input logic rx_queue_above_thld_i,
    input logic rx_queue_empty_i,
    output logic rx_queue_wvalid_o,
    input logic rx_queue_wready_i,
    output logic [RxFifoWidth-1:0] rx_queue_wdata_o,
    // TX FIFO
    input logic [TxThldWidth-1:0] tx_queue_thld_i,
    input logic tx_queue_full_i,
    input logic tx_queue_below_thld_i,
    input logic tx_queue_empty_i,
    input logic tx_queue_rvalid_i,
    output logic tx_queue_rready_o,
    input logic [TxFifoWidth-1:0] tx_queue_rdata_i,
    // Response FIFO
    input logic [RespThldWidth-1:0] resp_queue_thld_i,
    input logic resp_queue_full_i,
    input logic resp_queue_above_thld_i,
    input logic resp_queue_empty_i,
    output logic resp_queue_wvalid_o,
    input logic resp_queue_wready_i,
    output logic [RespFifoWidth-1:0] resp_queue_wdata_o,

    // DAT <-> Controller interface
    output logic                          dat_read_valid_hw_o,
    output logic [$clog2(`DAT_DEPTH)-1:0] dat_index_hw_o,
    input  logic [                  63:0] dat_rdata_hw_i,

    // DCT <-> Controller interface
    output logic                          dct_write_valid_hw_o,
    output logic                          dct_read_valid_hw_o,
    output logic [$clog2(`DCT_DEPTH)-1:0] dct_index_hw_o,
    output logic [                 127:0] dct_wdata_hw_o,
    input  logic [                 127:0] dct_rdata_hw_i,

    input  logic i3c_fsm_en_i,
    output logic i3c_fsm_idle_o,

    // Errors and Interrupts
    output i3c_err_t err,
    output i3c_irq_t irq
);

  logic host_enable;
  logic fmt_fifo_rvalid;
  logic [I2CFifoDepthWidth-1:0] fmt_fifo_depth;
  logic fmt_fifo_rready;
  logic [7:0] fmt_byte;
  logic fmt_flag_start_before;
  logic fmt_flag_stop_after;
  logic fmt_flag_read_bytes;
  logic fmt_flag_read_continue;
  logic fmt_flag_nak_ok;
  logic unhandled_unexp_nak;
  logic unhandled_nak_timeout;
  logic rx_fifo_wvalid;
  logic [RX_FIFO_WIDTH-1:0] rx_fifo_wdata;

  // TODO: Connect I2C Controller SDA/SCL to I3C Flow FSM

  i2c_controller_fsm i2c_fsm (
      .clk_i (clk),
      .rst_ni(rst_n),
      .scl_i,
      .scl_o,
      .sda_i,
      .sda_o,

      // These should be controlled by the flow FSM
      .host_enable_i(host_enable),
      .fmt_fifo_rvalid_i(fmt_fifo_rvalid),
      .fmt_fifo_depth_i(fmt_fifo_depth),
      .fmt_fifo_rready_o(fmt_fifo_rready),
      .fmt_byte_i(fmt_byte),
      .fmt_flag_start_before_i(fmt_flag_start_before),
      .fmt_flag_stop_after_i(fmt_flag_stop_after),
      .fmt_flag_read_bytes_i(fmt_flag_read_bytes),
      .fmt_flag_read_continue_i(fmt_flag_read_continue),
      .fmt_flag_nak_ok_i(fmt_flag_nak_ok),
      .unhandled_unexp_nak_i(unhandled_unexp_nak),
      .unhandled_nak_timeout_i(unhandled_nak_timeout),
      .rx_fifo_wvalid_o(rx_fifo_wvalid),
      .rx_fifo_wdata_o(rx_fifo_wdata),
      .host_idle_o(),

      // TODO: Use calculated timing values
      .thigh_i(16'd10),
      .tlow_i(16'd10),
      .t_r_i(16'd1),
      .t_f_i(16'd1),
      .thd_sta_i(16'd1),
      .tsu_sta_i(16'd1),
      .tsu_sto_i(16'd1),
      .tsu_dat_i(16'd1),
      .thd_dat_i(16'd1),
      .t_buf_i(16'd1),

      // Clock stretch is not supported by I3C bus
      .stretch_timeout_i('0),
      .timeout_enable_i ('0),

      // TODO: Handle NACK on bus
      .host_nack_handler_timeout_i('0),
      .host_nack_handler_timeout_en_i('0),

      // TODO: Handle bus events
      .event_nak_o(),
      .event_unhandled_nak_timeout_o(),
      .event_scl_interference_o(),
      .event_sda_interference_o(),
      .event_stretch_timeout_o(),
      .event_sda_unstable_o(),
      .event_cmd_complete_o()
  );

  i3c_flow_fsm flow_fsm (
      .clk,
      .rst_n,
      .cmd_queue_thld_i,
      .cmd_queue_full_i,
      .cmd_queue_below_thld_i,
      .cmd_queue_empty_i,
      .cmd_queue_rvalid_i,
      .cmd_queue_rready_o,
      .cmd_queue_rdata_i,
      .rx_queue_thld_i,
      .rx_queue_full_i,
      .rx_queue_above_thld_i,
      .rx_queue_empty_i,
      .rx_queue_wvalid_o,
      .rx_queue_wready_i,
      .rx_queue_wdata_o,
      .tx_queue_thld_i,
      .tx_queue_full_i,
      .tx_queue_below_thld_i,
      .tx_queue_empty_i,
      .tx_queue_rvalid_i,
      .tx_queue_rready_o,
      .tx_queue_rdata_i,
      .resp_queue_thld_i,
      .resp_queue_full_i,
      .resp_queue_above_thld_i,
      .resp_queue_empty_i,
      .resp_queue_wvalid_o,
      .resp_queue_wready_i,
      .resp_queue_wdata_o,
      .dat_read_valid_hw_o,
      .dat_index_hw_o,
      .dat_rdata_hw_i,
      .dct_write_valid_hw_o,
      .dct_read_valid_hw_o,
      .dct_index_hw_o,
      .dct_wdata_hw_o,
      .dct_rdata_hw_i,
      .host_enable_o(host_enable),
      .fmt_fifo_rvalid_o(fmt_fifo_rvalid),
      .fmt_fifo_depth_o(fmt_fifo_depth),
      .fmt_fifo_rready_i(fmt_fifo_rready),
      .fmt_byte_o(fmt_byte),
      .fmt_flag_start_before_o(fmt_flag_start_before),
      .fmt_flag_stop_after_o(fmt_flag_stop_after),
      .fmt_flag_read_bytes_o(fmt_flag_read_bytes),
      .fmt_flag_read_continue_o(fmt_flag_read_continue),
      .fmt_flag_nak_ok_o(fmt_flag_nak_ok),
      .unhandled_unexp_nak_o(unhandled_unexp_nak),
      .unhandled_nak_timeout_o(unhandled_nak_timeout),
      .rx_fifo_wvalid_i(rx_fifo_wvalid),
      .rx_fifo_wdata_i(rx_fifo_wdata),
      .i3c_fsm_en_i,
      .i3c_fsm_idle_o,
      .err,
      .irq
  );

endmodule
