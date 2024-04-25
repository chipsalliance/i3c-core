// SPDX-License-Identifier: Apache-2.0

// TODO: Consider arbitration difference from i2c:
// Section 5.1.4
// 48b provisioned id and bcr, dcr are used.
// This is to enable dynamic addressing.

module i3c_ctrl
  import i3c_ctrl_pkg::*;
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
    input logic [CmdThldWidth-1:0] cmd_fifo_thld_i,
    input logic cmd_fifo_full_i,
    input logic cmd_fifo_apch_thld_i,
    input logic cmd_fifo_empty_i,
    input logic cmd_fifo_rvalid_i,
    output logic cmd_fifo_rready_o,
    input logic [CmdFifoWidth-1:0] cmd_fifo_rdata_i,
    // RX FIFO
    input logic [RxThldWidth-1:0] rx_fifo_thld_i,
    input logic rx_fifo_full_i,
    input logic rx_fifo_apch_thld_i,
    input logic rx_fifo_empty_i,
    output logic rx_fifo_wvalid_o,
    input logic rx_fifo_wready_i,
    output logic [RxFifoWidth-1:0] rx_fifo_wdata_o,
    // TX FIFO
    input logic [TxThldWidth-1:0] tx_fifo_thld_i,
    input logic tx_fifo_full_i,
    input logic tx_fifo_apch_thld_i,
    input logic tx_fifo_empty_i,
    input logic tx_fifo_rvalid_i,
    output logic tx_fifo_rready_o,
    input logic [TxFifoWidth-1:0] tx_fifo_rdata_i,
    // Response FIFO
    input logic [RespThldWidth-1:0] resp_fifo_thld_i,
    input logic resp_fifo_full_i,
    input logic resp_fifo_apch_thld_i,
    input logic resp_fifo_empty_i,
    output logic resp_fifo_wvalid_o,
    input logic resp_fifo_wready_i,
    output logic [RespFifoWidth-1:0] resp_fifo_wdata_o,

    // Errors and Interrupts
    output i3c_err_t err,
    output i3c_irq_t irq
);

  always_ff @(posedge clk or negedge rst_n) begin : proc_test
    if (!rst_n) begin
      sda_o <= '0;
    end else begin
      sda_o <= '1;
    end
  end

  i2c_controller_shim i2c_fsm (
      .clk_i (clk),
      .rst_ni(rst_n),
      .scl_i (),
      .scl_o (),
      .sda_i (),
      .sda_o ()
      // TODO: Remaining control / data signals
  );

  assign scl_o = '1;


  //

endmodule
