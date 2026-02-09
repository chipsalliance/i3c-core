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
    input  logic                       rx_desc_queue_empty_i,
    input  logic                       rx_desc_queue_full_i,
    input  logic                       rx_desc_queue_write_i,

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
    input  logic                   rx_data_queue_empty_i,
    input  logic                   rx_data_queue_full_i,
    input  logic                   rx_data_queue_write_i,

    // TX descriptors queue
    output logic                       tx_desc_queue_req_o,
    input  logic                       tx_desc_queue_ack_i,
    output logic [RxDescDataWidth-1:0] tx_desc_queue_data_o,
    output logic [RxDescThldWidth-1:0] tx_desc_queue_ready_thld_o,
    input  logic [RxDescThldWidth-1:0] tx_desc_queue_ready_thld_i,
    output logic                       tx_desc_queue_reg_rst_o,
    input  logic                       tx_desc_queue_reg_rst_we_i,
    input  logic                       tx_desc_queue_reg_rst_data_i,
    input  logic                       tx_desc_queue_full_i,

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
    input  logic                   tx_data_queue_full_i,

    // In-band Interrupt queue
    input  logic                    ibi_queue_full_i,
    input  logic                    ibi_queue_empty_i,
    output logic                    ibi_queue_req_o,
    input  logic                    ibi_queue_ack_i,
    output logic [CsrDataWidth-1:0] ibi_queue_data_o,
    output logic [IbiThldWidth-1:0] ibi_queue_ready_thld_o,
    output logic                    ibi_queue_reg_rst_o,
    input  logic                    ibi_queue_reg_rst_we_i,
    input  logic                    ibi_queue_reg_rst_data_i,

    // Queue depth inputs for status registers
    input  logic [7:0] rx_desc_queue_depth_i,
    input  logic [7:0] tx_desc_queue_depth_i,
    input  logic [7:0] rx_data_queue_depth_i,
    input  logic [7:0] tx_data_queue_depth_i,
    input  logic [7:0] ibi_queue_depth_i,
    input  logic       tx_desc_queue_empty_i,
    input  logic       tx_data_queue_empty_i,

    input logic bypass_i3c_core_i,

    // IBI status
    input logic [1:0] ibi_status_i,
    input logic ibi_status_we_i,
    // Virtual recovery target selection - gates TTI interrupts during recovery transactions
    input logic virtual_device_sel_i,
    // Private read status
    input logic tx_pr_end_i,
    input logic tx_pr_start_i,

    input logic enec_ibi_i,
    input logic enec_crr_i,
    input logic enec_hj_i,

    input logic disec_ibi_i,
    input logic disec_crr_i,
    input logic disec_hj_i,

    input logic err_i,

    // TE error inputs for interrupt reporting
    input logic te0_err_i,
    input logic te1_err_i,
    input logic te2_err_i,
    input logic te3_err_i,
    input logic te4_err_i,
    input logic te5_err_i,
    input logic framing_err_i,
    input logic ri_pec_err_i,
    input logic ri_length_err_i,
    input logic ri_readonly_err_i,
    input logic ri_unsupported_err_i,
    input logic ri_rx_fifo_overflow_err_i,
    input logic ri_indirect_fifo_overflow_err_i,

    // Interrupt
    output logic irq_o
);

  // TODO: undriven logic
  always_comb begin : undriven_logic
    hwif_tti_o.INTERRUPT_STATUS.IBI_THLD_STAT.we = '0;
    hwif_tti_o.INTERRUPT_STATUS.TRANSFER_ERR_STAT.we = '0;
    hwif_tti_o.INTERRUPT_STATUS.TRANSFER_ABORT_STAT.we = '0;
    hwif_tti_o.INTERRUPT_STATUS.TX_DESC_THLD_STAT.we = '0;
    hwif_tti_o.INTERRUPT_STATUS.TX_DATA_THLD_STAT.we = '0;
    hwif_tti_o.INTERRUPT_STATUS.TX_DESC_TIMEOUT.we = '0;
    hwif_tti_o.INTERRUPT_STATUS.RX_DESC_TIMEOUT.we = '0;
    hwif_tti_o.QUEUE_THLD_CTRL.IBI_THLD.next = '0;
  end

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

    // RX_DESC_QUEUE_PORT
    hwif_tti_o.RESET_CONTROL.RX_DESC_RST.we = rx_desc_queue_reg_rst_we_i;
    hwif_tti_o.RESET_CONTROL.RX_DESC_RST.next = rx_desc_queue_reg_rst_data_i;
    if (rx_desc_queue_empty_i && hwif_tti_i.RX_DESC_QUEUE_PORT.req) begin
      hwif_tti_o.RX_DESC_QUEUE_PORT.rd_ack = hwif_tti_i.RX_DESC_QUEUE_PORT.req & ~hwif_tti_i.RX_DESC_QUEUE_PORT.req_is_wr;
      hwif_tti_o.RX_DESC_QUEUE_PORT.rd_data = '0;
      rx_desc_queue_req_o = '0;
    end else begin
      hwif_tti_o.RX_DESC_QUEUE_PORT.rd_ack = rx_desc_queue_ack_i;
      hwif_tti_o.RX_DESC_QUEUE_PORT.rd_data = rx_desc_queue_data_i;
      rx_desc_queue_req_o = hwif_tti_i.RX_DESC_QUEUE_PORT.req;
    end

    // TX_DESC_QUEUE_PORT
    hwif_tti_o.RESET_CONTROL.TX_DESC_RST.we = tx_desc_queue_reg_rst_we_i;
    hwif_tti_o.RESET_CONTROL.TX_DESC_RST.next = tx_desc_queue_reg_rst_data_i;
    if (tx_desc_queue_full_i && hwif_tti_i.TX_DESC_QUEUE_PORT.req) begin
      hwif_tti_o.TX_DESC_QUEUE_PORT.wr_ack = hwif_tti_i.TX_DESC_QUEUE_PORT.req & hwif_tti_i.TX_DESC_QUEUE_PORT.req_is_wr;
      tx_desc_queue_req_o  = '0;
      tx_desc_queue_data_o = '0;
    end else begin
      hwif_tti_o.TX_DESC_QUEUE_PORT.wr_ack = tx_desc_queue_ack_i;
      tx_desc_queue_req_o  = hwif_tti_i.TX_DESC_QUEUE_PORT.req & hwif_tti_i.TX_DESC_QUEUE_PORT.req_is_wr;
      tx_desc_queue_data_o = hwif_tti_i.TX_DESC_QUEUE_PORT.wr_data;
    end

    // RX_DATA_PORT
    hwif_tti_o.RESET_CONTROL.RX_DATA_RST.we = rx_data_queue_reg_rst_we_i;
    hwif_tti_o.RESET_CONTROL.RX_DATA_RST.next = rx_data_queue_reg_rst_data_i;
    if (rx_data_queue_empty_i && hwif_tti_i.RX_DATA_PORT.req) begin
      hwif_tti_o.RX_DATA_PORT.rd_ack = hwif_tti_i.RX_DATA_PORT.req & ~hwif_tti_i.RX_DATA_PORT.req_is_wr;
      hwif_tti_o.RX_DATA_PORT.rd_data = '0;
      rx_data_queue_req_o = '0;
    end else begin
      hwif_tti_o.RX_DATA_PORT.rd_ack = rx_data_queue_ack_i;
      hwif_tti_o.RX_DATA_PORT.rd_data = rx_data_queue_data_i;
      rx_data_queue_req_o = hwif_tti_i.RX_DATA_PORT.req;
    end

    // TX_DATA_PORT
    hwif_tti_o.RESET_CONTROL.TX_DATA_RST.we = tx_data_queue_reg_rst_we_i;
    hwif_tti_o.RESET_CONTROL.TX_DATA_RST.next = tx_data_queue_reg_rst_data_i;
    if (tx_data_queue_full_i && hwif_tti_i.TX_DATA_PORT.req) begin
      tx_data_queue_req_o = '0;
      tx_data_queue_data_o = '0;
      hwif_tti_o.TX_DATA_PORT.wr_ack = hwif_tti_i.TX_DATA_PORT.req & hwif_tti_i.TX_DATA_PORT.req_is_wr;
    end else begin
      tx_data_queue_req_o = hwif_tti_i.TX_DATA_PORT.req & hwif_tti_i.TX_DATA_PORT.req_is_wr;
      tx_data_queue_data_o = hwif_tti_i.TX_DATA_PORT.wr_data;
      hwif_tti_o.TX_DATA_PORT.wr_ack = tx_data_queue_ack_i;
    end

    // IBI_PORT
    hwif_tti_o.RESET_CONTROL.IBI_QUEUE_RST.we = ibi_queue_reg_rst_we_i;
    hwif_tti_o.RESET_CONTROL.IBI_QUEUE_RST.next = ibi_queue_reg_rst_data_i;
    if (ibi_queue_full_i && hwif_tti_i.IBI_PORT.req) begin
      ibi_queue_req_o = '0;
      ibi_queue_data_o = '0;
      hwif_tti_o.IBI_PORT.wr_ack = hwif_tti_i.IBI_PORT.req & hwif_tti_i.IBI_PORT.req_is_wr;
    end else begin
      ibi_queue_req_o = hwif_tti_i.IBI_PORT.req & hwif_tti_i.IBI_PORT.req_is_wr;
      ibi_queue_data_o = hwif_tti_i.IBI_PORT.wr_data;
      hwif_tti_o.IBI_PORT.wr_ack = ibi_queue_ack_i;
    end
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
    hwif_tti_o.INTERRUPT_STATUS.RX_DESC_TIMEOUT.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.TX_DESC_TIMEOUT.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.TX_DATA_THLD_STAT.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.TX_DESC_THLD_STAT.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.IBI_THLD_STAT.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.TRANSFER_ABORT_STAT.next = '0;
    hwif_tti_o.INTERRUPT_STATUS.TRANSFER_ERR_STAT.next = '0;

    hwif_tti_o.QUEUE_THLD_CTRL.IBI_THLD.we = '0;
    hwif_tti_o.QUEUE_THLD_CTRL.IBI_THLD.we = '0;
  end

  // Wire queue status and depth registers
  always_comb begin : wire_queue_status
    // QUEUE_STATUS - full/empty flags
    hwif_tti_o.QUEUE_STATUS.RX_DESC_QUEUE_FULL.next  = rx_desc_queue_full_i;
    hwif_tti_o.QUEUE_STATUS.RX_DESC_QUEUE_EMPTY.next = rx_desc_queue_empty_i;
    hwif_tti_o.QUEUE_STATUS.TX_DESC_QUEUE_FULL.next  = tx_desc_queue_full_i;
    hwif_tti_o.QUEUE_STATUS.TX_DESC_QUEUE_EMPTY.next = tx_desc_queue_empty_i;
    hwif_tti_o.QUEUE_STATUS.RX_DATA_QUEUE_FULL.next  = rx_data_queue_full_i;
    hwif_tti_o.QUEUE_STATUS.RX_DATA_QUEUE_EMPTY.next = rx_data_queue_empty_i;
    hwif_tti_o.QUEUE_STATUS.TX_DATA_QUEUE_FULL.next  = tx_data_queue_full_i;
    hwif_tti_o.QUEUE_STATUS.TX_DATA_QUEUE_EMPTY.next = tx_data_queue_empty_i;
    hwif_tti_o.QUEUE_STATUS.IBI_QUEUE_FULL.next      = ibi_queue_full_i;
    hwif_tti_o.QUEUE_STATUS.IBI_QUEUE_EMPTY.next     = ibi_queue_empty_i;

    // DESC_QUEUE_DEPTH
    hwif_tti_o.DESC_QUEUE_DEPTH.RX_DESC_QUEUE_DEPTH.next = rx_desc_queue_depth_i;
    hwif_tti_o.DESC_QUEUE_DEPTH.TX_DESC_QUEUE_DEPTH.next = tx_desc_queue_depth_i;

    // DATA_QUEUE_DEPTH
    hwif_tti_o.DATA_QUEUE_DEPTH.RX_DATA_QUEUE_DEPTH.next = rx_data_queue_depth_i;
    hwif_tti_o.DATA_QUEUE_DEPTH.TX_DATA_QUEUE_DEPTH.next = tx_data_queue_depth_i;

    // IBI_QUEUE_DEPTH
    hwif_tti_o.IBI_QUEUE_DEPTH.IBI_QUEUE_DEPTH.next = ibi_queue_depth_i;
  end

  assign hwif_tti_o.STATUS.PROTOCOL_ERROR.next = err_i;

  // Interrupts: [5:0] = TTI queue interrupts, [12:6] = TE error interrupts + framing,
  //             [16:13] = Recovery errors (PEC, LENGTH, READONLY, UNSUPPORTED),
  //             [18:17] = Recovery FIFO overflow errors (TX_FIFO, INDIRECT_FIFO)
  logic [18:0] irqs;

  // Delay queue write monitor signals by 1 cycle to align them with
  // full/empty/threshold trigger update.
  logic rx_desc_queue_write_r;
  logic rx_data_queue_write_r;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      rx_desc_queue_write_r <= '0;
      rx_data_queue_write_r <= '0;
    end else begin
      rx_desc_queue_write_r <= rx_desc_queue_write_i & ~virtual_device_sel_i;
      rx_data_queue_write_r <= rx_data_queue_write_i & ~virtual_device_sel_i;
    end
  end

  // RX_DESC_STAT
  // set: any write to the RX desc queue
  // clr: any read from the RX desc queue
  interrupt xintr0 (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (rx_desc_queue_write_r),
    .clr_i          (rx_desc_queue_ack_i),
    .irq_force_i    (hwif_tti_i.INTERRUPT_FORCE.RX_DESC_STAT_FORCE.value),
    .sts_o          (hwif_tti_o.INTERRUPT_STATUS.RX_DESC_STAT.next),
    .sts_we_o       (hwif_tti_o.INTERRUPT_STATUS.RX_DESC_STAT.we),
    .sts_i          (hwif_tti_i.INTERRUPT_STATUS.RX_DESC_STAT.value),
    .sts_ena_i      (hwif_tti_i.INTERRUPT_ENABLE.RX_DESC_STAT_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[0])
  );

  // RX_DESC_THLD_STAT
  // set: a write to the RX desc queue an threshold exceeded
  // clr: any read from the RX desc queue
  interrupt xintr1 (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (rx_desc_queue_write_r & rx_desc_queue_ready_thld_trig_i),
    .clr_i          (rx_desc_queue_ack_i),
    .irq_force_i    (hwif_tti_i.INTERRUPT_FORCE.RX_DESC_THLD_FORCE.value),
    .sts_o          (hwif_tti_o.INTERRUPT_STATUS.RX_DESC_THLD_STAT.next),
    .sts_we_o       (hwif_tti_o.INTERRUPT_STATUS.RX_DESC_THLD_STAT.we),
    .sts_i          (hwif_tti_i.INTERRUPT_STATUS.RX_DESC_THLD_STAT.value),
    .sts_ena_i      (hwif_tti_i.INTERRUPT_ENABLE.RX_DESC_THLD_STAT_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[1])
  );

  // RX_DATA_THLD_STAT
  // set: a write to the RX data queue an threshold exceeded
  // clr: any read from the RX data queue
  interrupt xintr2 (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (rx_data_queue_write_r & rx_data_queue_ready_thld_trig_i),
    .clr_i          (rx_data_queue_ack_i),
    .irq_force_i    (hwif_tti_i.INTERRUPT_FORCE.RX_DATA_THLD_FORCE.value),
    .sts_o          (hwif_tti_o.INTERRUPT_STATUS.RX_DATA_THLD_STAT.next),
    .sts_we_o       (hwif_tti_o.INTERRUPT_STATUS.RX_DATA_THLD_STAT.we),
    .sts_i          (hwif_tti_i.INTERRUPT_STATUS.RX_DATA_THLD_STAT.value),
    .sts_ena_i      (hwif_tti_i.INTERRUPT_ENABLE.RX_DATA_THLD_STAT_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[2])
  );

  // IBI_DONE
  // set: an IBI has been transmitter to the host
  // clr: read LAST_IBI_STATUS
  interrupt xintr3 (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (ibi_status_we_i),
    .clr_i          (hwif_tti_i.STATUS.LAST_IBI_STATUS.swacc),
    .irq_force_i    (hwif_tti_i.INTERRUPT_FORCE.IBI_DONE_FORCE.value),
    .sts_o          (hwif_tti_o.INTERRUPT_STATUS.IBI_DONE.next),
    .sts_we_o       (hwif_tti_o.INTERRUPT_STATUS.IBI_DONE.we),
    .sts_i          (hwif_tti_i.INTERRUPT_STATUS.IBI_DONE.value),
    .sts_ena_i      (hwif_tti_i.INTERRUPT_ENABLE.IBI_DONE_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[3])
  );

  // TX_DESC_COMPLETE
  // set: A private read transfer has completed
  // clr: None, need to clear via INTERRUPT_STATUS
  interrupt xintr4 (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (~virtual_device_sel_i & tx_pr_end_i),
    .clr_i          ('0),
    .irq_force_i    (hwif_tti_i.INTERRUPT_FORCE.TX_DESC_COMPLETE_FORCE.value),
    .sts_o          (hwif_tti_o.INTERRUPT_STATUS.TX_DESC_COMPLETE.next),
    .sts_we_o       (hwif_tti_o.INTERRUPT_STATUS.TX_DESC_COMPLETE.we),
    .sts_i          (hwif_tti_i.INTERRUPT_STATUS.TX_DESC_COMPLETE.value),
    .sts_ena_i      (hwif_tti_i.INTERRUPT_ENABLE.TX_DESC_COMPLETE_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[4])
  );

  // TX_DESC_STAT
  // set: A private read transfer has started
  // clr: None, need to clear via INTERRUPT_STATUS
  interrupt xintr5 (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (~virtual_device_sel_i & tx_pr_start_i),
    .clr_i          ('0),
    .irq_force_i    (hwif_tti_i.INTERRUPT_FORCE.TX_DESC_STAT_FORCE.value),
    .sts_o          (hwif_tti_o.INTERRUPT_STATUS.TX_DESC_STAT.next),
    .sts_we_o       (hwif_tti_o.INTERRUPT_STATUS.TX_DESC_STAT.we),
    .sts_i          (hwif_tti_i.INTERRUPT_STATUS.TX_DESC_STAT.value),
    .sts_ena_i      (hwif_tti_i.INTERRUPT_ENABLE.TX_DESC_STAT_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[5])
  );

  // ===========================================================================
  // Target Error Interrupts (TE0-TE5, Framing, PEC)
  // ===========================================================================
  // Per I3C v1.1.1 spec, these are Target Errors that should be reported to SW.
  // Error signals are already gated at the source with detection enable bits.
  // Detection enables are extracted directly from hwif_tti_out in i3c.sv.

  // TE0_ERR: Invalid reserved address + RnW combination
  interrupt xintr_te0 (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (te0_err_i),
    .clr_i          ('0),
    .irq_force_i    (hwif_tti_i.TARGET_ERR_INTR_FORCE.TE0_ERR_FORCE.value),
    .sts_o          (hwif_tti_o.TARGET_ERR_INTR_STATUS.TE0_ERR_STAT.next),
    .sts_we_o       (hwif_tti_o.TARGET_ERR_INTR_STATUS.TE0_ERR_STAT.we),
    .sts_i          (hwif_tti_i.TARGET_ERR_INTR_STATUS.TE0_ERR_STAT.value),
    .sts_ena_i      (hwif_tti_i.TARGET_ERR_INTR_ENABLE.TE0_ERR_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[6])
  );

  // TE1_ERR: CCC command parity error
  interrupt xintr_te1 (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (te1_err_i),
    .clr_i          ('0),
    .irq_force_i    (hwif_tti_i.TARGET_ERR_INTR_FORCE.TE1_ERR_FORCE.value),
    .sts_o          (hwif_tti_o.TARGET_ERR_INTR_STATUS.TE1_ERR_STAT.next),
    .sts_we_o       (hwif_tti_o.TARGET_ERR_INTR_STATUS.TE1_ERR_STAT.we),
    .sts_i          (hwif_tti_i.TARGET_ERR_INTR_STATUS.TE1_ERR_STAT.value),
    .sts_ena_i      (hwif_tti_i.TARGET_ERR_INTR_ENABLE.TE1_ERR_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[7])
  );

  // TE2_ERR: CCC or Private Write data parity error
  interrupt xintr_te2 (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (te2_err_i),
    .clr_i          ('0),
    .irq_force_i    (hwif_tti_i.TARGET_ERR_INTR_FORCE.TE2_ERR_FORCE.value),
    .sts_o          (hwif_tti_o.TARGET_ERR_INTR_STATUS.TE2_ERR_STAT.next),
    .sts_we_o       (hwif_tti_o.TARGET_ERR_INTR_STATUS.TE2_ERR_STAT.we),
    .sts_i          (hwif_tti_i.TARGET_ERR_INTR_STATUS.TE2_ERR_STAT.value),
    .sts_ena_i      (hwif_tti_i.TARGET_ERR_INTR_ENABLE.TE2_ERR_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[8])
  );

  // TE3_ERR: ENTDAA PID mismatch
  interrupt xintr_te3 (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (te3_err_i),
    .clr_i          ('0),
    .irq_force_i    (hwif_tti_i.TARGET_ERR_INTR_FORCE.TE3_ERR_FORCE.value),
    .sts_o          (hwif_tti_o.TARGET_ERR_INTR_STATUS.TE3_ERR_STAT.next),
    .sts_we_o       (hwif_tti_o.TARGET_ERR_INTR_STATUS.TE3_ERR_STAT.we),
    .sts_i          (hwif_tti_i.TARGET_ERR_INTR_STATUS.TE3_ERR_STAT.value),
    .sts_ena_i      (hwif_tti_i.TARGET_ERR_INTR_ENABLE.TE3_ERR_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[9])
  );

  // TE4_ERR: ENTDAA BCR/DCR mismatch
  interrupt xintr_te4 (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (te4_err_i),
    .clr_i          ('0),
    .irq_force_i    (hwif_tti_i.TARGET_ERR_INTR_FORCE.TE4_ERR_FORCE.value),
    .sts_o          (hwif_tti_o.TARGET_ERR_INTR_STATUS.TE4_ERR_STAT.next),
    .sts_we_o       (hwif_tti_o.TARGET_ERR_INTR_STATUS.TE4_ERR_STAT.we),
    .sts_i          (hwif_tti_i.TARGET_ERR_INTR_STATUS.TE4_ERR_STAT.value),
    .sts_ena_i      (hwif_tti_i.TARGET_ERR_INTR_ENABLE.TE4_ERR_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[10])
  );

  // TE5_ERR: Broadcast/Direct CCC wrong R/W direction
  interrupt xintr_te5 (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (te5_err_i),
    .clr_i          ('0),
    .irq_force_i    (hwif_tti_i.TARGET_ERR_INTR_FORCE.TE5_ERR_FORCE.value),
    .sts_o          (hwif_tti_o.TARGET_ERR_INTR_STATUS.TE5_ERR_STAT.next),
    .sts_we_o       (hwif_tti_o.TARGET_ERR_INTR_STATUS.TE5_ERR_STAT.we),
    .sts_i          (hwif_tti_i.TARGET_ERR_INTR_STATUS.TE5_ERR_STAT.value),
    .sts_ena_i      (hwif_tti_i.TARGET_ERR_INTR_ENABLE.TE5_ERR_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[11])
  );

  // FRAMING_ERR: DA padding error (Bit[0] != 0 in SETDASA/SETNEWDA)
  interrupt xintr_framing (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (framing_err_i),
    .clr_i          ('0),
    .irq_force_i    (hwif_tti_i.TARGET_ERR_INTR_FORCE.FRAMING_ERR_FORCE.value),
    .sts_o          (hwif_tti_o.TARGET_ERR_INTR_STATUS.FRAMING_ERR_STAT.next),
    .sts_we_o       (hwif_tti_o.TARGET_ERR_INTR_STATUS.FRAMING_ERR_STAT.we),
    .sts_i          (hwif_tti_i.TARGET_ERR_INTR_STATUS.FRAMING_ERR_STAT.value),
    .sts_ena_i      (hwif_tti_i.TARGET_ERR_INTR_ENABLE.FRAMING_ERR_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[12])
  );

  // RI_PEC_ERR: Recovery Interface PEC/CRC error
  interrupt xintr_ri_pec (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (ri_pec_err_i),
    .clr_i          ('0),
    .irq_force_i    (hwif_tti_i.TARGET_ERR_INTR_FORCE.RI_PEC_ERR_FORCE.value),
    .sts_o          (hwif_tti_o.TARGET_ERR_INTR_STATUS.RI_PEC_ERR_STAT.next),
    .sts_we_o       (hwif_tti_o.TARGET_ERR_INTR_STATUS.RI_PEC_ERR_STAT.we),
    .sts_i          (hwif_tti_i.TARGET_ERR_INTR_STATUS.RI_PEC_ERR_STAT.value),
    .sts_ena_i      (hwif_tti_i.TARGET_ERR_INTR_ENABLE.RI_PEC_ERR_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[13])
  );

  // RI_LENGTH_ERR: Recovery Interface length mismatch error
  interrupt xintr_ri_length (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (ri_length_err_i),
    .clr_i          ('0),
    .irq_force_i    (hwif_tti_i.TARGET_ERR_INTR_FORCE.RI_LENGTH_ERR_FORCE.value),
    .sts_o          (hwif_tti_o.TARGET_ERR_INTR_STATUS.RI_LENGTH_ERR_STAT.next),
    .sts_we_o       (hwif_tti_o.TARGET_ERR_INTR_STATUS.RI_LENGTH_ERR_STAT.we),
    .sts_i          (hwif_tti_i.TARGET_ERR_INTR_STATUS.RI_LENGTH_ERR_STAT.value),
    .sts_ena_i      (hwif_tti_i.TARGET_ERR_INTR_ENABLE.RI_LENGTH_ERR_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[14])
  );

  // RI_READONLY_ERR: Recovery Interface write-to-read-only error
  interrupt xintr_ri_readonly (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (ri_readonly_err_i),
    .clr_i          ('0),
    .irq_force_i    (hwif_tti_i.TARGET_ERR_INTR_FORCE.RI_READONLY_ERR_FORCE.value),
    .sts_o          (hwif_tti_o.TARGET_ERR_INTR_STATUS.RI_READONLY_ERR_STAT.next),
    .sts_we_o       (hwif_tti_o.TARGET_ERR_INTR_STATUS.RI_READONLY_ERR_STAT.we),
    .sts_i          (hwif_tti_i.TARGET_ERR_INTR_STATUS.RI_READONLY_ERR_STAT.value),
    .sts_ena_i      (hwif_tti_i.TARGET_ERR_INTR_ENABLE.RI_READONLY_ERR_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[15])
  );

  // RI_UNSUPPORTED_ERR: Recovery Interface unsupported command error
  interrupt xintr_ri_unsupported (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (ri_unsupported_err_i),
    .clr_i          ('0),
    .irq_force_i    (hwif_tti_i.TARGET_ERR_INTR_FORCE.RI_UNSUPPORTED_ERR_FORCE.value),
    .sts_o          (hwif_tti_o.TARGET_ERR_INTR_STATUS.RI_UNSUPPORTED_ERR_STAT.next),
    .sts_we_o       (hwif_tti_o.TARGET_ERR_INTR_STATUS.RI_UNSUPPORTED_ERR_STAT.we),
    .sts_i          (hwif_tti_i.TARGET_ERR_INTR_STATUS.RI_UNSUPPORTED_ERR_STAT.value),
    .sts_ena_i      (hwif_tti_i.TARGET_ERR_INTR_ENABLE.RI_UNSUPPORTED_ERR_EN.value),
    .sig_ena_i      ('1),
    .irq_o          (irqs[16])
  );

  // RI_RX_FIFO_OVERFLOW_ERR: Recovery Interface RX FIFO overflow error
  // DET_EN controls whether the FSM transitions to Error state (via recovery_receiver).
  // Status is recorded when DET_EN allows it; interrupt enable controls IRQ output.
  interrupt xintr_ri_rx_fifo_overflow (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (ri_rx_fifo_overflow_err_i),
    .clr_i          ('0),
    .irq_force_i    (hwif_tti_i.TARGET_ERR_INTR_FORCE.RI_RX_FIFO_OVERFLOW_ERR_FORCE.value),
    .sts_o          (hwif_tti_o.TARGET_ERR_INTR_STATUS.RI_RX_FIFO_OVERFLOW_ERR_STAT.next),
    .sts_we_o       (hwif_tti_o.TARGET_ERR_INTR_STATUS.RI_RX_FIFO_OVERFLOW_ERR_STAT.we),
    .sts_i          (hwif_tti_i.TARGET_ERR_INTR_STATUS.RI_RX_FIFO_OVERFLOW_ERR_STAT.value),
    .sts_ena_i      (hwif_tti_i.TARGET_ERR_CTRL.RI_RX_FIFO_OVERFLOW_ERR_DET_EN.value),
    .sig_ena_i      (hwif_tti_i.TARGET_ERR_INTR_ENABLE.RI_RX_FIFO_OVERFLOW_ERR_EN.value),
    .irq_o          (irqs[17])
  );

  // RI_INDIRECT_FIFO_OVERFLOW_ERR: Recovery Interface INDIRECT FIFO overflow error
  // DET_EN controls whether the FSM transitions to Error state (via recovery_receiver).
  // Status is recorded when DET_EN allows it; interrupt enable controls IRQ output.
  interrupt xintr_ri_indirect_fifo_overflow (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .irq_i          (ri_indirect_fifo_overflow_err_i),
    .clr_i          ('0),
    .irq_force_i    (hwif_tti_i.TARGET_ERR_INTR_FORCE.RI_INDIRECT_FIFO_OVERFLOW_ERR_FORCE.value),
    .sts_o          (hwif_tti_o.TARGET_ERR_INTR_STATUS.RI_INDIRECT_FIFO_OVERFLOW_ERR_STAT.next),
    .sts_we_o       (hwif_tti_o.TARGET_ERR_INTR_STATUS.RI_INDIRECT_FIFO_OVERFLOW_ERR_STAT.we),
    .sts_i          (hwif_tti_i.TARGET_ERR_INTR_STATUS.RI_INDIRECT_FIFO_OVERFLOW_ERR_STAT.value),
    .sts_ena_i      (hwif_tti_i.TARGET_ERR_CTRL.RI_INDIRECT_FIFO_OVERFLOW_ERR_DET_EN.value),
    .sig_ena_i      (hwif_tti_i.TARGET_ERR_INTR_ENABLE.RI_INDIRECT_FIFO_OVERFLOW_ERR_EN.value),
    .irq_o          (irqs[18])
  );

  // =========================================================================
  // Target Error Counters - 8-bit saturating counters
  // CSR holds the register value. HW increments on error (if not saturated).
  // SW can write 0 (or any value) to clear/set the counter.
  // =========================================================================

  // TE0 counter - increment on error if not saturated
  assign hwif_tti_o.TARGET_ERR_CNT_TE0.CNT.next = hwif_tti_i.TARGET_ERR_CNT_TE0.CNT.value + 8'h01;
  assign hwif_tti_o.TARGET_ERR_CNT_TE0.CNT.we   = te0_err_i && (hwif_tti_i.TARGET_ERR_CNT_TE0.CNT.value != 8'hFF);

  // TE1 counter
  assign hwif_tti_o.TARGET_ERR_CNT_TE1.CNT.next = hwif_tti_i.TARGET_ERR_CNT_TE1.CNT.value + 8'h01;
  assign hwif_tti_o.TARGET_ERR_CNT_TE1.CNT.we   = te1_err_i && (hwif_tti_i.TARGET_ERR_CNT_TE1.CNT.value != 8'hFF);

  // TE2 counter
  assign hwif_tti_o.TARGET_ERR_CNT_TE2.CNT.next = hwif_tti_i.TARGET_ERR_CNT_TE2.CNT.value + 8'h01;
  assign hwif_tti_o.TARGET_ERR_CNT_TE2.CNT.we   = te2_err_i && (hwif_tti_i.TARGET_ERR_CNT_TE2.CNT.value != 8'hFF);

  // TE3 counter
  assign hwif_tti_o.TARGET_ERR_CNT_TE3.CNT.next = hwif_tti_i.TARGET_ERR_CNT_TE3.CNT.value + 8'h01;
  assign hwif_tti_o.TARGET_ERR_CNT_TE3.CNT.we   = te3_err_i && (hwif_tti_i.TARGET_ERR_CNT_TE3.CNT.value != 8'hFF);

  // TE4 counter
  assign hwif_tti_o.TARGET_ERR_CNT_TE4.CNT.next = hwif_tti_i.TARGET_ERR_CNT_TE4.CNT.value + 8'h01;
  assign hwif_tti_o.TARGET_ERR_CNT_TE4.CNT.we   = te4_err_i && (hwif_tti_i.TARGET_ERR_CNT_TE4.CNT.value != 8'hFF);

  // TE5 counter
  assign hwif_tti_o.TARGET_ERR_CNT_TE5.CNT.next = hwif_tti_i.TARGET_ERR_CNT_TE5.CNT.value + 8'h01;
  assign hwif_tti_o.TARGET_ERR_CNT_TE5.CNT.we   = te5_err_i && (hwif_tti_i.TARGET_ERR_CNT_TE5.CNT.value != 8'hFF);

  // Framing error counter
  assign hwif_tti_o.TARGET_ERR_CNT_FRAMING.CNT.next = hwif_tti_i.TARGET_ERR_CNT_FRAMING.CNT.value + 8'h01;
  assign hwif_tti_o.TARGET_ERR_CNT_FRAMING.CNT.we   = framing_err_i && (hwif_tti_i.TARGET_ERR_CNT_FRAMING.CNT.value != 8'hFF);

  // Recovery Interface PEC error counter
  assign hwif_tti_o.TARGET_ERR_CNT_RI_PEC.CNT.next = hwif_tti_i.TARGET_ERR_CNT_RI_PEC.CNT.value + 8'h01;
  assign hwif_tti_o.TARGET_ERR_CNT_RI_PEC.CNT.we   = ri_pec_err_i && (hwif_tti_i.TARGET_ERR_CNT_RI_PEC.CNT.value != 8'hFF);

  // Recovery Interface Length error counter
  assign hwif_tti_o.TARGET_ERR_CNT_RI_LENGTH.CNT.next = hwif_tti_i.TARGET_ERR_CNT_RI_LENGTH.CNT.value + 8'h01;
  assign hwif_tti_o.TARGET_ERR_CNT_RI_LENGTH.CNT.we   = ri_length_err_i && (hwif_tti_i.TARGET_ERR_CNT_RI_LENGTH.CNT.value != 8'hFF);

  // Recovery Interface Read-only error counter
  assign hwif_tti_o.TARGET_ERR_CNT_RI_READONLY.CNT.next = hwif_tti_i.TARGET_ERR_CNT_RI_READONLY.CNT.value + 8'h01;
  assign hwif_tti_o.TARGET_ERR_CNT_RI_READONLY.CNT.we   = ri_readonly_err_i && (hwif_tti_i.TARGET_ERR_CNT_RI_READONLY.CNT.value != 8'hFF);

  // Recovery Interface Unsupported error counter
  assign hwif_tti_o.TARGET_ERR_CNT_RI_UNSUPPORTED.CNT.next = hwif_tti_i.TARGET_ERR_CNT_RI_UNSUPPORTED.CNT.value + 8'h01;
  assign hwif_tti_o.TARGET_ERR_CNT_RI_UNSUPPORTED.CNT.we   = ri_unsupported_err_i && (hwif_tti_i.TARGET_ERR_CNT_RI_UNSUPPORTED.CNT.value != 8'hFF);

  // Recovery Interface RX FIFO Overflow error counter
  assign hwif_tti_o.TARGET_ERR_CNT_RI_RX_FIFO_OVERFLOW.CNT.next = hwif_tti_i.TARGET_ERR_CNT_RI_RX_FIFO_OVERFLOW.CNT.value + 8'h01;
  assign hwif_tti_o.TARGET_ERR_CNT_RI_RX_FIFO_OVERFLOW.CNT.we   = ri_rx_fifo_overflow_err_i && (hwif_tti_i.TARGET_ERR_CNT_RI_RX_FIFO_OVERFLOW.CNT.value != 8'hFF);

  // Recovery Interface INDIRECT FIFO Overflow error counter
  assign hwif_tti_o.TARGET_ERR_CNT_RI_INDIRECT_FIFO_OVERFLOW.CNT.next = hwif_tti_i.TARGET_ERR_CNT_RI_INDIRECT_FIFO_OVERFLOW.CNT.value + 8'h01;
  assign hwif_tti_o.TARGET_ERR_CNT_RI_INDIRECT_FIFO_OVERFLOW.CNT.we   = ri_indirect_fifo_overflow_err_i && (hwif_tti_i.TARGET_ERR_CNT_RI_INDIRECT_FIFO_OVERFLOW.CNT.value != 8'hFF);

  // Interrupt output
  assign irq_o = |irqs;

endmodule : tti

