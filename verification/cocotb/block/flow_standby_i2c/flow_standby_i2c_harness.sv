// SPDX-License-Identifier: Apache-2.0

module flow_standby_i2c_harness
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

    input logic rnw_i,

    output logic tx_fifo_rvalid_o,
    input logic tx_fifo_rready_i,
    output logic [TxFifoWidth-1:0] tx_fifo_rdata_o,

    // TTI
    input logic [31:0] cmd_fifo_rdata_i,
    input logic cmd_fifo_rvalid_i,
    output logic cmd_fifo_rready_o,

    // FIFO
    output logic [31:0] response_fifo_wdata_o,
    output logic response_fifo_wvalid_o,
    input logic response_fifo_wready_i,

    // TX FIFO
    input logic [31:0] tx_fifo_rdata_i,
    input logic tx_fifo_rvalid_i,
    output logic tx_fifo_rready_o,

    // RX FIFO
    output logic [31:0] rx_fifo_wdata_o,
    output logic rx_fifo_wvalid_o,
    input logic rx_fifo_wready_i,

    output logic err_o
);

  i3c_tti_command_desc_t cmd_fifo_rdata;
  i3c_response_desc_t response_fifo_wdata;

  assign cmd_fifo_rdata.data_length = cmd_fifo_rdata_i[31:16];
  assign cmd_fifo_rdata.end_of_transfer = cmd_fifo_rdata_i[15];

  assign response_fifo_wdata_o[15:0] = response_fifo_wdata.data_length;
  assign response_fifo_wdata_o[23:16] = '0;
  assign response_fifo_wdata_o[27:24] = response_fifo_wdata.tid;
  assign response_fifo_wdata_o[31:28] = response_fifo_wdata.err_status;

  flow_standby_i2c flow_standby_i2c (
      .cmd_fifo_rdata_i(cmd_fifo_rdata),
      .response_fifo_wdata_o(response_fifo_wdata),
      .*
  );
endmodule
