// SPDX-License-Identifier: Apache-2.0

// TODO: Consider arbitration difference from i2c:
// Section 5.1.4
// 48b provisioned id and bcr, dcr are used.
// This is to enable dynamic addressing.

module controller
  import controller_pkg::*;
  import i3c_pkg::*;
  import hci_pkg::*;
(
    input  logic clk_i,
    input  logic rst_ni,
    // Interface to SDA/SCL
    input  logic ctrl_scl_i[4],
    input  logic ctrl_sda_i[4],
    output logic ctrl_scl_o[4],
    output logic ctrl_sda_o[4],

    // HCI queues
    // Command FIFO
    input logic [HciCmdThldWidth-1:0] cmd_queue_thld_i,
    input logic cmd_queue_full_i,
    input logic cmd_queue_below_thld_i,
    input logic cmd_queue_empty_i,
    input logic cmd_queue_rvalid_i,
    output logic cmd_queue_rready_o,
    input logic [HciCmdDataWidth-1:0] cmd_queue_rdata_i,
    // RX FIFO
    input logic [HciRxThldWidth-1:0] rx_queue_thld_i,
    input logic rx_queue_full_i,
    input logic rx_queue_above_thld_i,
    input logic rx_queue_empty_i,
    output logic rx_queue_wvalid_o,
    input logic rx_queue_wready_i,
    output logic [HciRxDataWidth-1:0] rx_queue_wdata_o,
    // TX FIFO
    input logic [HciTxThldWidth-1:0] tx_queue_thld_i,
    input logic tx_queue_full_i,
    input logic tx_queue_below_thld_i,
    input logic tx_queue_empty_i,
    input logic tx_queue_rvalid_i,
    output logic tx_queue_rready_o,
    input logic [HciTxDataWidth-1:0] tx_queue_rdata_i,
    // Response FIFO
    input logic [HciRespThldWidth-1:0] resp_queue_thld_i,
    input logic resp_queue_full_i,
    input logic resp_queue_above_thld_i,
    input logic resp_queue_empty_i,
    output logic resp_queue_wvalid_o,
    input logic resp_queue_wready_i,
    output logic [HciRespDataWidth-1:0] resp_queue_wdata_o,

    // Target Transaction Interface

    // TTI: RX Descriptor
    input logic tti_rx_desc_queue_full_i,
    input logic [TtiRxDescThldWidth-1:0] tti_rx_desc_queue_thld_i,
    input logic tti_rx_desc_queue_above_thld_i,
    input logic tti_rx_desc_queue_empty_i,
    output logic tti_rx_desc_queue_wvalid_o,
    input logic tti_rx_desc_queue_wready_i,
    output logic [TtiRxDescDataWidth-1:0] tti_rx_desc_queue_wdata_o,

    // TTI: TX Descriptor
    input logic tti_tx_desc_queue_full_i,
    input logic [TtiTxDescThldWidth-1:0] tti_tx_desc_queue_thld_i,
    input logic tti_tx_desc_queue_below_thld_i,
    input logic tti_tx_desc_queue_empty_i,
    input logic tti_tx_desc_queue_rvalid_i,
    output logic tti_tx_desc_queue_rready_o,
    input logic [TtiTxDescDataWidth-1:0] tti_tx_desc_queue_rdata_i,

    // TTI: RX Data
    input logic tti_rx_queue_full_i,
    input logic [TtiRxThldWidth-1:0] tti_rx_queue_thld_i,
    input logic tti_rx_queue_above_thld_i,
    input logic tti_rx_queue_empty_i,
    output logic tti_rx_queue_wvalid_o,
    input logic tti_rx_queue_wready_i,
    output logic [TtiRxDataWidth-1:0] tti_rx_queue_wdata_o,

    // TTI: TX Data
    input logic tti_tx_queue_full_i,
    input logic [TtiTxThldWidth-1:0] tti_tx_queue_thld_i,
    input logic tti_tx_queue_below_thld_i,
    input logic tti_tx_queue_empty_i,
    input logic tti_tx_queue_rvalid_i,
    output logic tti_tx_queue_rready_o,
    input logic [TtiTxDataWidth-1:0] tti_tx_queue_rdata_i,

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
    output i3c_irq_t irq,
    input i3c_config_t core_config
);

  controller_active xcontroller_active (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .core_config(core_config),
      .ctrl_scl_i(ctrl_scl_i[0:1]),
      .ctrl_sda_i(ctrl_sda_i[0:1]),
      .ctrl_scl_o(ctrl_scl_o[0:1]),
      .ctrl_sda_o(ctrl_sda_o[0:1]),
      .cmd_queue_thld_i(cmd_queue_thld_i),
      .cmd_queue_full_i(cmd_queue_full_i),
      .cmd_queue_below_thld_i(cmd_queue_below_thld_i),
      .cmd_queue_empty_i(cmd_queue_empty_i),
      .cmd_queue_rvalid_i(cmd_queue_rvalid_i),
      .cmd_queue_rready_o(cmd_queue_rready_o),
      .cmd_queue_rdata_i(cmd_queue_rdata_i),
      .rx_queue_thld_i(rx_queue_thld_i),
      .rx_queue_full_i(rx_queue_full_i),
      .rx_queue_above_thld_i(rx_queue_above_thld_i),
      .rx_queue_empty_i(rx_queue_empty_i),
      .rx_queue_wvalid_o(rx_queue_wvalid_o),
      .rx_queue_wready_i(rx_queue_wready_i),
      .rx_queue_wdata_o(rx_queue_wdata_o),
      .tx_queue_thld_i(tx_queue_thld_i),
      .tx_queue_full_i(tx_queue_full_i),
      .tx_queue_below_thld_i(tx_queue_below_thld_i),
      .tx_queue_empty_i(tx_queue_empty_i),
      .tx_queue_rvalid_i(tx_queue_rvalid_i),
      .tx_queue_rready_o(tx_queue_rready_o),
      .tx_queue_rdata_i(tx_queue_rdata_i),
      .resp_queue_thld_i(resp_queue_thld_i),
      .resp_queue_full_i(resp_queue_full_i),
      .resp_queue_above_thld_i(resp_queue_above_thld_i),
      .resp_queue_empty_i(resp_queue_empty_i),
      .resp_queue_wvalid_o(resp_queue_wvalid_o),
      .resp_queue_wready_i(resp_queue_wready_i),
      .resp_queue_wdata_o(resp_queue_wdata_o),
      .dat_read_valid_hw_o(dat_read_valid_hw_o),
      .dat_index_hw_o(dat_index_hw_o),
      .dat_rdata_hw_i(dat_rdata_hw_i),
      .dct_write_valid_hw_o(dct_write_valid_hw_o),
      .dct_read_valid_hw_o(dct_read_valid_hw_o),
      .dct_index_hw_o(dct_index_hw_o),
      .dct_wdata_hw_o(dct_wdata_hw_o),
      .dct_rdata_hw_i(dct_rdata_hw_i),
      .i3c_fsm_en_i(i3c_fsm_en_i),
      .i3c_fsm_idle_o(i3c_fsm_idle_o),
      .err(err),
      .irq(irq)
  );

  controller_standby xcontroller_standby (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .core_config(core_config),
      .ctrl_scl_i(ctrl_scl_i[2:3]),
      .ctrl_sda_i(ctrl_sda_i[2:3]),
      .ctrl_scl_o(ctrl_scl_o[2:3]),
      .ctrl_sda_o(ctrl_sda_o[2:3]),
      .tti_rx_desc_queue_full_i(tti_rx_desc_queue_full_i),
      .tti_rx_desc_queue_thld_i(tti_rx_desc_queue_thld_i),
      .tti_rx_desc_queue_above_thld_i(tti_rx_desc_queue_above_thld_i),
      .tti_rx_desc_queue_empty_i(tti_rx_desc_queue_empty_i),
      .tti_rx_desc_queue_wvalid_o(tti_rx_desc_queue_wvalid_o),
      .tti_rx_desc_queue_wready_i(tti_rx_desc_queue_wready_i),
      .tti_rx_desc_queue_wdata_o(tti_rx_desc_queue_wdata_o),
      .tti_tx_desc_queue_full_i(tti_tx_desc_queue_full_i),
      .tti_tx_desc_queue_thld_i(tti_tx_desc_queue_thld_i),
      .tti_tx_desc_queue_below_thld_i(tti_tx_desc_queue_below_thld_i),
      .tti_tx_desc_queue_empty_i(tti_tx_desc_queue_empty_i),
      .tti_tx_desc_queue_rvalid_i(tti_tx_desc_queue_rvalid_i),
      .tti_tx_desc_queue_rready_o(tti_tx_desc_queue_rready_o),
      .tti_tx_desc_queue_rdata_i(tti_tx_desc_queue_rdata_i),
      .tti_rx_queue_full_i(tti_rx_queue_full_i),
      .tti_rx_queue_thld_i(tti_rx_queue_thld_i),
      .tti_rx_queue_above_thld_i(tti_rx_queue_above_thld_i),
      .tti_rx_queue_empty_i(tti_rx_queue_empty_i),
      .tti_rx_queue_wvalid_o(tti_rx_queue_wvalid_o),
      .tti_rx_queue_wready_i(tti_rx_queue_wready_i),
      .tti_rx_queue_wdata_o(tti_rx_queue_wdata_o),
      .tti_tx_queue_full_i(tti_tx_queue_full_i),
      .tti_tx_queue_thld_i(tti_tx_queue_thld_i),
      .tti_tx_queue_below_thld_i(tti_tx_queue_below_thld_i),
      .tti_tx_queue_empty_i(tti_tx_queue_empty_i),
      .tti_tx_queue_rvalid_i(tti_tx_queue_rvalid_i),
      .tti_tx_queue_rready_o(tti_tx_queue_rready_o),
      .tti_tx_queue_rdata_i(tti_tx_queue_rdata_i)
  );

endmodule
