// SPDX-License-Identifier: Apache-2.0

// I3C Target Transaction Interface
module tti
  import i3c_pkg::*;
#(
    parameter int unsigned CsrDataWidth = 32,

    parameter int unsigned RxDescFifoDepth = 64,
    parameter int unsigned TxDescFifoDepth = 64,
    parameter int unsigned RxFifoDepth = 64,
    parameter int unsigned TxFifoDepth = 64,
    parameter int unsigned IbiFifoDepth = 64,

    parameter int unsigned RxDescDataWidth = 32,
    parameter int unsigned TxDescDataWidth = 32,
    parameter int unsigned RxDataWidth = 32,
    parameter int unsigned TxDataWidth = 32,
    parameter int unsigned IbiDataWidth = 32,

    parameter int unsigned RxDescThldWidth = 8,
    parameter int unsigned TxDescThldWidth = 8,
    parameter int unsigned RxThldWidth = 3,
    parameter int unsigned TxThldWidth = 3,
    parameter int unsigned IbiThldWidth = 8
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

    // I3C CSR access interface
    input  I3CCSR_pkg::I3CCSR__I3C_EC__TTI__out_t hwif_tti_i,
    output I3CCSR_pkg::I3CCSR__I3C_EC__TTI__in_t  hwif_tti_o,

    // RX descriptors queue
    output logic                       rx_desc_queue_req_o,
    input  logic                       rx_desc_queue_ack_i,
    input  logic [RxDescDataWidth-1:0] rx_desc_queue_data_i,
    output logic [RxDescThldWidth-1:0] rx_desc_queue_ready_thld_o,
    input  logic [RxDescThldWidth-1:0] rx_desc_queue_ready_thld_i,
    output logic                       rx_desc_queue_reg_rst_o,
    input  logic                       rx_desc_queue_reg_rst_we_i,
    input  logic                       rx_desc_queue_reg_rst_data_i,

    // RX data queue
    output logic                   rx_data_queue_req_o,
    input  logic                   rx_data_queue_ack_i,
    input  logic [RxDataWidth-1:0] rx_data_queue_data_i,
    output logic [RxThldWidth-1:0] rx_data_queue_start_thld_o,
    output logic [RxThldWidth-1:0] rx_data_queue_ready_thld_o,
    input  logic [RxThldWidth-1:0] rx_data_queue_ready_thld_i,
    output logic                   rx_data_queue_reg_rst_o,
    input  logic                   rx_data_queue_reg_rst_we_i,
    input  logic                   rx_data_queue_reg_rst_data_i,

    // TX descriptors queue
    output logic                       tx_desc_queue_req_o,
    input  logic                       tx_desc_queue_ack_i,
    output logic [RxDescDataWidth-1:0] tx_desc_queue_data_o,
    output logic [RxDescThldWidth-1:0] tx_desc_queue_ready_thld_o,
    input  logic [RxDescThldWidth-1:0] tx_desc_queue_ready_thld_i,
    output logic                       tx_desc_queue_reg_rst_o,
    input  logic                       tx_desc_queue_reg_rst_we_i,
    input  logic                       tx_desc_queue_reg_rst_data_i,

    // TX data queue
    output logic                   tx_data_queue_req_o,
    input  logic                   tx_data_queue_ack_i,
    output logic [RxDataWidth-1:0] tx_data_queue_data_o,
    output logic [RxThldWidth-1:0] tx_data_queue_start_thld_o,
    output logic [RxThldWidth-1:0] tx_data_queue_ready_thld_o,
    input  logic [RxThldWidth-1:0] tx_data_queue_ready_thld_i,
    output logic                   tx_data_queue_reg_rst_o,
    input  logic                   tx_data_queue_reg_rst_we_i,
    input  logic                   tx_data_queue_reg_rst_data_i,

    // In-band Interrupt queue
    output logic                    ibi_queue_req_o,
    input  logic                    ibi_queue_ack_i,
    output logic [CsrDataWidth-1:0] ibi_queue_data_o,
    output logic [IbiThldWidth-1:0] ibi_queue_ready_thld_o,
    output logic                    ibi_queue_reg_rst_o,
    input  logic                    ibi_queue_reg_rst_we_i,
    input  logic                    ibi_queue_reg_rst_data_i
);

  logic tx_desc_ready_thld_swmod_q, tx_desc_ready_thld_we;
  logic rx_desc_ready_thld_swmod_q, rx_desc_ready_thld_we;

  // TODO: Connect queue soft resets

  always_ff @(posedge clk_i or negedge rst_ni) begin : blockName
    if (!rst_ni) begin
      tx_desc_ready_thld_swmod_q <= '0;
      tx_desc_ready_thld_we <= '0;
      rx_desc_ready_thld_swmod_q <= '0;
      rx_desc_ready_thld_we <= '0;
    end else begin
      tx_desc_ready_thld_swmod_q <= hwif_tti_i.QUEUE_THLD_CTRL.TX_DESC_THLD.swmod;
      tx_desc_ready_thld_we <= tx_desc_ready_thld_swmod_q;
      rx_desc_ready_thld_swmod_q <= hwif_tti_i.QUEUE_THLD_CTRL.RX_DESC_THLD.swmod;
      rx_desc_ready_thld_we <= rx_desc_ready_thld_swmod_q;
    end
  end

  always_comb begin : wire_hwif_thld
    hwif_tti_o.QUEUE_THLD_CTRL.TX_DESC_THLD.we = tx_desc_ready_thld_we;
    hwif_tti_o.QUEUE_THLD_CTRL.RX_DESC_THLD.we = rx_desc_ready_thld_we;
    hwif_tti_o.QUEUE_THLD_CTRL.TX_DESC_THLD.next = tx_desc_queue_ready_thld_i;
    hwif_tti_o.QUEUE_THLD_CTRL.RX_DESC_THLD.next = rx_desc_queue_ready_thld_i;
    rx_desc_queue_ready_thld_o = RxDescThldWidth'(hwif_tti_i.QUEUE_THLD_CTRL.RX_DESC_THLD.value);
    tx_desc_queue_ready_thld_o = TxDescThldWidth'(hwif_tti_i.QUEUE_THLD_CTRL.TX_DESC_THLD.value);
    rx_data_queue_start_thld_o = RxThldWidth'(hwif_tti_i.DATA_BUFFER_THLD_CTRL.RX_START_THLD.value);
    rx_data_queue_ready_thld_o = RxThldWidth'(hwif_tti_i.DATA_BUFFER_THLD_CTRL.RX_DATA_THLD.value);
    tx_data_queue_start_thld_o = TxThldWidth'(hwif_tti_i.DATA_BUFFER_THLD_CTRL.TX_START_THLD.value);
    tx_data_queue_ready_thld_o = TxThldWidth'(hwif_tti_i.DATA_BUFFER_THLD_CTRL.TX_DATA_THLD.value);
    ibi_queue_ready_thld_o = IbiThldWidth'(hwif_tti_i.QUEUE_THLD_CTRL.IBI_THLD.value);
  end : wire_hwif_thld

  always_comb begin : wire_hwif_xfer
    rx_desc_queue_req_o = hwif_tti_i.RX_DESC_QUEUE_PORT.req;
    hwif_tti_o.RX_DESC_QUEUE_PORT.rd_ack = rx_desc_queue_ack_i;
    hwif_tti_o.RX_DESC_QUEUE_PORT.rd_data = rx_desc_queue_data_i;

    tx_desc_queue_req_o  = hwif_tti_i.TX_DESC_QUEUE_PORT.req & hwif_tti_i.TX_DESC_QUEUE_PORT.req_is_wr;
    tx_desc_queue_data_o = hwif_tti_i.TX_DESC_QUEUE_PORT.wr_data;
    hwif_tti_o.TX_DESC_QUEUE_PORT.wr_ack = tx_desc_queue_ack_i;

    rx_data_queue_req_o = hwif_tti_i.RX_DATA_PORT.req;
    hwif_tti_o.RX_DATA_PORT.rd_ack = rx_data_queue_ack_i;
    hwif_tti_o.RX_DATA_PORT.rd_data = rx_data_queue_data_i;

    tx_data_queue_req_o = hwif_tti_i.TX_DATA_PORT.req & hwif_tti_i.TX_DATA_PORT.req_is_wr;
    tx_data_queue_data_o = hwif_tti_i.TX_DATA_PORT.wr_data;
    hwif_tti_o.TX_DATA_PORT.wr_ack = tx_data_queue_ack_i;

    ibi_queue_req_o = hwif_tti_i.IBI_PORT.req & hwif_tti_i.IBI_PORT.req_is_wr;
    ibi_queue_data_o = hwif_tti_i.IBI_PORT.wr_data;
    hwif_tti_o.IBI_PORT.wr_ack = ibi_queue_ack_i;
  end : wire_hwif_xfer

  always_comb begin : wire_hwif_rst
    rx_desc_queue_reg_rst_o = hwif_tti_i.RESET_CONTROL.RX_DESC_RST.value;
    tx_desc_queue_reg_rst_o = hwif_tti_i.RESET_CONTROL.TX_DESC_RST.value;
    rx_data_queue_reg_rst_o = hwif_tti_i.RESET_CONTROL.RX_DATA_RST.value;
    tx_data_queue_reg_rst_o = hwif_tti_i.RESET_CONTROL.TX_DATA_RST.value;
    ibi_queue_reg_rst_o     = hwif_tti_i.RESET_CONTROL.IBI_QUEUE_RST.value;
  end : wire_hwif_rst

endmodule : tti
