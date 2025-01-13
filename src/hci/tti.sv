// SPDX-License-Identifier: Apache-2.0

// I3C Target Transaction Interface
module tti
  import i3c_pkg::*;
#(
    parameter int unsigned CsrDataWidth = 32,

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
    input  logic                       rx_desc_queue_ready_thld_trig_i,
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
    input  logic                   rx_data_queue_ready_thld_trig_i,
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
    input  logic                    ibi_queue_reg_rst_data_i,

    // IBI status
    input logic [1:0] ibi_status_i,
    input logic ibi_status_we_i,

    input logic enec_ibi_i,
    input logic enec_crr_i,
    input logic enec_hj_i,

    input logic disec_ibi_i,
    input logic disec_crr_i,
    input logic disec_hj_i,

    input logic err_i,

    // Interrupt
    output logic irq_o
);

  logic tx_desc_ready_thld_swmod_q, tx_desc_ready_thld_we;
  logic rx_desc_ready_thld_swmod_q, rx_desc_ready_thld_we;

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
    hwif_tti_o.RESET_CONTROL.RX_DESC_RST.we = rx_desc_queue_reg_rst_we_i;
    hwif_tti_o.RESET_CONTROL.RX_DESC_RST.next = rx_desc_queue_reg_rst_data_i;

    tx_desc_queue_req_o  = hwif_tti_i.TX_DESC_QUEUE_PORT.req & hwif_tti_i.TX_DESC_QUEUE_PORT.req_is_wr;
    tx_desc_queue_data_o = hwif_tti_i.TX_DESC_QUEUE_PORT.wr_data;
    hwif_tti_o.TX_DESC_QUEUE_PORT.wr_ack = tx_desc_queue_ack_i;
    hwif_tti_o.RESET_CONTROL.TX_DESC_RST.we = tx_desc_queue_reg_rst_we_i;
    hwif_tti_o.RESET_CONTROL.TX_DESC_RST.next = tx_desc_queue_reg_rst_data_i;

    rx_data_queue_req_o = hwif_tti_i.RX_DATA_PORT.req;
    hwif_tti_o.RX_DATA_PORT.rd_ack = rx_data_queue_ack_i;
    hwif_tti_o.RX_DATA_PORT.rd_data = rx_data_queue_data_i;
    hwif_tti_o.RESET_CONTROL.RX_DATA_RST.we = rx_data_queue_reg_rst_we_i;
    hwif_tti_o.RESET_CONTROL.RX_DATA_RST.next = rx_data_queue_reg_rst_data_i;

    tx_data_queue_req_o = hwif_tti_i.TX_DATA_PORT.req & hwif_tti_i.TX_DATA_PORT.req_is_wr;
    tx_data_queue_data_o = hwif_tti_i.TX_DATA_PORT.wr_data;
    hwif_tti_o.TX_DATA_PORT.wr_ack = tx_data_queue_ack_i;
    hwif_tti_o.RESET_CONTROL.TX_DATA_RST.we = tx_data_queue_reg_rst_we_i;
    hwif_tti_o.RESET_CONTROL.TX_DATA_RST.next = tx_data_queue_reg_rst_data_i;

    ibi_queue_req_o = hwif_tti_i.IBI_PORT.req & hwif_tti_i.IBI_PORT.req_is_wr;
    ibi_queue_data_o = hwif_tti_i.IBI_PORT.wr_data;
    hwif_tti_o.IBI_PORT.wr_ack = ibi_queue_ack_i;
    hwif_tti_o.RESET_CONTROL.IBI_QUEUE_RST.we = ibi_queue_reg_rst_we_i;
    hwif_tti_o.RESET_CONTROL.IBI_QUEUE_RST.next = ibi_queue_reg_rst_data_i;
  end : wire_hwif_xfer

  always_comb begin : wire_hwif_rst
    rx_desc_queue_reg_rst_o = hwif_tti_i.RESET_CONTROL.RX_DESC_RST.value;
    tx_desc_queue_reg_rst_o = hwif_tti_i.RESET_CONTROL.TX_DESC_RST.value;
    rx_data_queue_reg_rst_o = hwif_tti_i.RESET_CONTROL.RX_DATA_RST.value;
    tx_data_queue_reg_rst_o = hwif_tti_i.RESET_CONTROL.TX_DATA_RST.value;
    ibi_queue_reg_rst_o     = hwif_tti_i.RESET_CONTROL.IBI_QUEUE_RST.value;
  end : wire_hwif_rst

  always_comb begin
    hwif_tti_o.STATUS.LAST_IBI_STATUS.next = ibi_status_i;
    hwif_tti_o.STATUS.LAST_IBI_STATUS.we   = ibi_status_we_i;
  end

  always_comb begin : wire_enec_disec
    hwif_tti_o.CONTROL.IBI_EN.we = enec_ibi_i | disec_ibi_i;
    hwif_tti_o.CONTROL.IBI_EN.next = enec_ibi_i;
    hwif_tti_o.CONTROL.CRR_EN.we = enec_crr_i | disec_crr_i;
    hwif_tti_o.CONTROL.CRR_EN.next = enec_crr_i;
    hwif_tti_o.CONTROL.HJ_EN.we = enec_hj_i | disec_hj_i;
    hwif_tti_o.CONTROL.HJ_EN.next = enec_hj_i;
  end

  always_comb begin : wire_unconnected_regs
    hwif_tti_o.RESET_CONTROL.SOFT_RST.we = '0;
    hwif_tti_o.RESET_CONTROL.SOFT_RST.next = '0;

    hwif_tti_o.INTERRUPT_STATUS.PENDING_INTERRUPT.we = '0;
    hwif_tti_o.INTERRUPT_STATUS.PENDING_INTERRUPT.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.RX_DESC_STAT.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.TX_DESC_STAT.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.RX_DESC_TIMEOUT.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.TX_DESC_TIMEOUT.next = '0;
//    hwif_tti_o.INTERRUPT_STATUS.RX_DATA_THLD_STAT.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.TX_DATA_THLD_STAT.next = '0;
//    hwif_tti_o.INTERRUPT_STATUS.RX_DESC_THLD_STAT.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.TX_DESC_THLD_STAT.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.IBI_THLD_STAT.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.IBI_DONE.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.TRANSFER_ABORT_STAT.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.TRANSFER_ERR_STAT.next = '0;

    hwif_tti_o.QUEUE_THLD_CTRL.IBI_THLD.we = '0;
    hwif_tti_o.QUEUE_THLD_CTRL.IBI_THLD.we = '0;
  end

  assign hwif_tti_o.STATUS.PROTOCOL_ERROR.next = err_i;

  // Interrupts
  logic [1:0] irqs;

  interrupt xintr0 (
    .irq_i          (rx_desc_queue_ready_thld_trig_i),
    .clr_i          (rx_desc_queue_ack_i),
    .irq_force_i    (hwif_tti_i.INTERRUPT_FORCE.RX_DESC_THLD_FORCE.value),
    .sts_o          (hwif_tti_o.INTERRUPT_STATUS.RX_DESC_THLD_STAT.next),
    .sts_we_o       (hwif_tti_o.INTERRUPT_STATUS.RX_DESC_THLD_STAT.we),
    .sts_i          (hwif_tti_i.INTERRUPT_STATUS.RX_DESC_THLD_STAT.value),
    .sts_ena_i      (hwif_tti_i.INTERRUPT_ENABLE.RX_DESC_THLD_STAT_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[0])
  );

  interrupt xintr1 (
    .irq_i          (rx_data_queue_ready_thld_trig_i),
    .clr_i          (rx_data_queue_ack_i),
    .irq_force_i    (hwif_tti_i.INTERRUPT_FORCE.RX_DATA_THLD_FORCE.value),
    .sts_o          (hwif_tti_o.INTERRUPT_STATUS.RX_DATA_THLD_STAT.next),
    .sts_we_o       (hwif_tti_o.INTERRUPT_STATUS.RX_DATA_THLD_STAT.we),
    .sts_i          (hwif_tti_i.INTERRUPT_STATUS.RX_DATA_THLD_STAT.value),
    .sts_ena_i      (hwif_tti_i.INTERRUPT_ENABLE.RX_DATA_THLD_STAT_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[1])
  );

  // Interrupt output
  assign irq_o = |irqs;

endmodule : tti
