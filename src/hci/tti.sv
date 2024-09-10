// SPDX-License-Identifier: Apache-2.0

// I3C Target Transaction Interface
module tti
  import i3c_pkg::*;
#(
    parameter int unsigned CsrDataWidth = 32,

    parameter int unsigned RxDescFifoDepth = 64,
    parameter int unsigned TxDescFifoDepth = 64,
    parameter int unsigned RxDataFifoDepth = 64,
    parameter int unsigned TxDataFifoDepth = 64,
    parameter int unsigned IbiFifoDepth = 64,

    parameter int unsigned RxDescDataWidth = 32,
    parameter int unsigned TxDescDataWidth = 32,
    parameter int unsigned RxDataDataWidth = 32,
    parameter int unsigned TxDataDataWidth = 32,
    parameter int unsigned IbiDataWidth = 32,

    parameter int unsigned RxDescThldWidth = 8,
    parameter int unsigned TxDescThldWidth = 8,
    parameter int unsigned RxDataThldWidth = 3,
    parameter int unsigned TxDataThldWidth = 3,
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
    output logic                       rx_data_queue_req_o,
    input  logic                       rx_data_queue_ack_i,
    input  logic [RxDataDataWidth-1:0] rx_data_queue_data_i,
    output logic [RxDataThldWidth-1:0] rx_data_queue_start_thld_o,
    output logic [RxDataThldWidth-1:0] rx_data_queue_ready_thld_o,
    input  logic [RxDataThldWidth-1:0] rx_data_queue_ready_thld_i,
    output logic                       rx_data_queue_reg_rst_o,
    input  logic                       rx_data_queue_reg_rst_we_i,
    input  logic                       rx_data_queue_reg_rst_data_i,

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
    output logic                       rx_data_queue_req_o,
    input  logic                       rx_data_queue_ack_i,
    output logic [RxDataDataWidth-1:0] rx_data_queue_data_o,
    output logic [RxDataThldWidth-1:0] rx_data_queue_start_thld_o,
    output logic [RxDataThldWidth-1:0] rx_data_queue_ready_thld_o,
    input  logic [RxDataThldWidth-1:0] rx_data_queue_ready_thld_i,
    output logic                       rx_data_queue_reg_rst_o,
    input  logic                       rx_data_queue_reg_rst_we_i,
    input  logic                       rx_data_queue_reg_rst_data_i,

    // In-band Interrupt queue
    output logic                    ibi_queue_req_o,
    input  logic                    ibi_queue_ack_i,
    output logic [CsrDataWidth-1:0] ibi_queue_data_o,
    output logic                    ibi_queue_reg_rst_o,
    input  logic                    ibi_queue_reg_rst_we_i,
    input  logic                    ibi_queue_reg_rst_data_i
);
  //  // TTI queues thresholds
  //  logic [TxDescThldWidth-1:0] rx_desc_queue_ready_thld;
  //  logic [RxDescThldWidth-1:0] tx_desc_queue_ready_thld;
  //  logic [RxThldWidth-1:0] rx_queue_start_thld;
  //  logic [RxThldWidth-1:0] rx_queue_ready_thld;
  //  logic [TxThldWidth-1:0] tx_queue_start_thld;
  //  logic [TxThldWidth-1:0] tx_queue_ready_thld;
  //
  //  // TTI queues port control
  //  logic rx_desc_queue_req;
  //
  //  logic tx_desc_queue_req;
  //  logic tx_desc_queue_req_is_wr;
  //  logic [TxDescDataWidth-1:0] tx_desc_queue_wr_data;
  //
  //  logic rx_queue_req;
  //  logic [RxDataWidth-1:0] rx_queue_rd_data;
  //
  //  logic tx_queue_req;
  //  logic tx_queue_req_is_wr;
  //  logic [TxDataWidth-1:0] tx_queue_wr_data;
  //
  //  logic tx_desc_ready_thld_swmod_q, tx_desc_ready_thld_we;
  //  logic rx_desc_ready_thld_swmod_q, rx_desc_ready_thld_we;
  //
  //  logic rx_desc_queue_rst;
  //  logic tx_desc_queue_rst;
  //  logic rx_queue_rst;
  //  logic tx_queue_rst;
  //
  //  assign rx_queue_start_thld_o = rx_queue_start_thld;
  //  assign tx_queue_start_thld_o = tx_queue_start_thld;
  //
  //  // TODO: Connect queue soft resets
  //
  //  always_ff @(posedge clk_i or negedge rst_ni) begin : blockName
  //    if (!rst_ni) begin
  //      tx_desc_ready_thld_swmod_q <= '0;
  //      tx_desc_ready_thld_we <= '0;
  //      rx_desc_ready_thld_swmod_q <= '0;
  //      rx_desc_ready_thld_we <= '0;
  //    end else begin
  //      tx_desc_ready_thld_swmod_q <= hwif_tti_i.QUEUE_THLD_CTRL.TX_DESC_THLD.swmod;
  //      tx_desc_ready_thld_we <= tx_desc_ready_thld_swmod_q;
  //      rx_desc_ready_thld_swmod_q <= hwif_tti_i.QUEUE_THLD_CTRL.RX_DESC_THLD.swmod;
  //      rx_desc_ready_thld_we <= rx_desc_ready_thld_swmod_q;
  //    end
  //  end
  //
  //  always_comb begin : wire_hwif_thld
  //    hwif_tti_o.QUEUE_THLD_CTRL.TX_DESC_THLD.we = tx_desc_ready_thld_we;
  //    hwif_tti_o.QUEUE_THLD_CTRL.RX_DESC_THLD.we = rx_desc_ready_thld_we;
  //    hwif_tti_o.QUEUE_THLD_CTRL.TX_DESC_THLD.next = tx_desc_queue_ready_thld_o;
  //    hwif_tti_o.QUEUE_THLD_CTRL.RX_DESC_THLD.next = rx_desc_queue_ready_thld_o;
  //    rx_desc_queue_ready_thld = RxDescThldWidth'(hwif_tti_i.QUEUE_THLD_CTRL.RX_DESC_THLD.value);
  //    tx_desc_queue_ready_thld = TxDescThldWidth'(hwif_tti_i.QUEUE_THLD_CTRL.TX_DESC_THLD.value);
  //    rx_queue_start_thld = RxThldWidth'(hwif_tti_i.DATA_BUFFER_THLD_CTRL.RX_START_THLD.value);
  //    rx_queue_ready_thld = RxThldWidth'(hwif_tti_i.DATA_BUFFER_THLD_CTRL.RX_DATA_THLD.value);
  //    tx_queue_start_thld = TxThldWidth'(hwif_tti_i.DATA_BUFFER_THLD_CTRL.TX_START_THLD.value);
  //    tx_queue_ready_thld = TxThldWidth'(hwif_tti_i.DATA_BUFFER_THLD_CTRL.TX_DATA_THLD.value);
  //  end : wire_hwif_thld
  //
  //  always_comb begin : wire_hwif_xfer
  //    rx_desc_queue_req = hwif_tti_i.RX_DESC_QUEUE_PORT.req;
  //
  //    tx_desc_queue_req = hwif_tti_i.TX_DESC_QUEUE_PORT.req;
  //    tx_desc_queue_req_is_wr = hwif_tti_i.TX_DESC_QUEUE_PORT.req_is_wr;
  //    tx_desc_queue_wr_data = hwif_tti_i.TX_DESC_QUEUE_PORT.wr_data;
  //
  //    rx_queue_req = hwif_tti_i.RX_DATA_PORT.req;
  //
  //    tx_queue_req = hwif_tti_i.TX_DATA_PORT.req;
  //    tx_queue_req_is_wr = hwif_tti_i.TX_DATA_PORT.req_is_wr;
  //    tx_queue_wr_data = hwif_tti_i.TX_DATA_PORT.wr_data;
  //  end : wire_hwif_xfer
  //
  //  always_comb begin : wire_hwif_rst
  //    rx_desc_queue_rst = hwif_tti_i.RESET_CONTROL.RX_DESC_RST.value;
  //    tx_desc_queue_rst = hwif_tti_i.RESET_CONTROL.TX_DESC_RST.value;
  //    rx_queue_rst = hwif_tti_i.RESET_CONTROL.RX_DATA_RST.value;
  //    tx_queue_rst = hwif_tti_i.RESET_CONTROL.TX_DATA_RST.value;
  //  end : wire_hwif_rst

  // TODO TODO TODO: Remove below, refactor above

  //  logic
  //      unused_rx_desc_start_thld_trig,
  //      unused_rx_desc_reg_rst_we,
  //      unused_rx_desc_reg_rst_data,
  //      unused_tx_desc_start_thld_trig,
  //      unused_tx_desc_reg_rst_we,
  //      unused_tx_desc_reg_rst_data,
  //      unused_rx_reg_rst_we,
  //      unused_rx_reg_rst_data,
  //      unused_tx_reg_rst_we,
  //      unused_tx_reg_rst_data;
  //
  //  queues #(
  //      .CsrDataWidth,
  //
  //      .TxDescFifoDepth(TxDescFifoDepth),
  //      .RxDescFifoDepth(RxDescFifoDepth),
  //      .TxFifoDepth(TxFifoDepth),
  //      .RxFifoDepth(RxFifoDepth),
  //
  //      .TxDescFifoDataWidth(TxDescDataWidth),
  //      .RxDescFifoDataWidth(RxDescDataWidth),
  //      .TxFifoDataWidth(TxDataWidth),
  //      .RxFifoDataWidth(RxDataWidth),
  //
  //      .TxDescFifoThldWidth(TxDescThldWidth),
  //      .RxDescFifoThldWidth(RxDescThldWidth),
  //      .TxFifoThldWidth(TxThldWidth),
  //      .RxFifoThldWidth(RxThldWidth)
  //  ) tti_queues (
  //      .clk_i,
  //      .rst_ni,
  //
  //      .rx_desc_full_o(rx_desc_queue_full_o),
  //      .rx_desc_start_thld_trig_o(unused_rx_desc_start_thld_trig),  // Intentionally left hanging, unsupported by TTI RX Desc Queue
  //      .rx_desc_ready_thld_trig_o(rx_desc_queue_ready_thld_trig_o),
  //      .rx_desc_empty_o(rx_desc_queue_empty_o),
  //      .rx_desc_wvalid_i(rx_desc_queue_wvalid_i),
  //      .rx_desc_wready_o(rx_desc_queue_wready_o),
  //      .rx_desc_wdata_i(rx_desc_queue_wdata_i),
  //      .rx_desc_req_i(rx_desc_queue_req),
  //      .rx_desc_ack_o(hwif_tti_o.RX_DESC_QUEUE_PORT.rd_ack),
  //      .rx_desc_data_o(hwif_tti_o.RX_DESC_QUEUE_PORT.rd_data),
  //      .rx_desc_start_thld_i('0),  // Unsupported by RX Desc Queue
  //      .rx_desc_ready_thld_i(rx_desc_queue_ready_thld),
  //      .rx_desc_ready_thld_o(rx_desc_queue_ready_thld_o),
  //      .rx_desc_reg_rst_i(rx_desc_queue_rst),
  //      .rx_desc_reg_rst_we_o(hwif_tti_o.RESET_CONTROL.RX_DESC_RST.we),
  //      .rx_desc_reg_rst_data_o(hwif_tti_o.RESET_CONTROL.RX_DESC_RST.next),
  //
  //      .tx_desc_full_o(tx_desc_queue_full_o),
  //      .tx_desc_start_thld_trig_o(unused_tx_desc_start_thld_trig),  // Intentionally left hanging, unsupported by TTI TX Desc Queue
  //      .tx_desc_ready_thld_trig_o(tx_desc_queue_ready_thld_trig_o),
  //      .tx_desc_empty_o(tx_desc_queue_empty_o),
  //      .tx_desc_rvalid_o(tx_desc_queue_rvalid_o),
  //      .tx_desc_rready_i(tx_desc_queue_rready_i),
  //      .tx_desc_rdata_o(tx_desc_queue_rdata_o),
  //      .tx_desc_req_i(tx_desc_queue_req & tx_desc_queue_req_is_wr),
  //      .tx_desc_ack_o(hwif_tti_o.TX_DESC_QUEUE_PORT.wr_ack),
  //      .tx_desc_data_i(tx_desc_queue_wr_data),
  //      .tx_desc_start_thld_i('0),  // Unsupported by TX Desc Queue
  //      .tx_desc_ready_thld_i(tx_desc_queue_ready_thld),
  //      .tx_desc_ready_thld_o(tx_desc_queue_ready_thld_o),
  //      .tx_desc_reg_rst_i(tx_desc_queue_rst),
  //      .tx_desc_reg_rst_we_o(hwif_tti_o.RESET_CONTROL.TX_DESC_RST.we),
  //      .tx_desc_reg_rst_data_o(hwif_tti_o.RESET_CONTROL.TX_DESC_RST.next),
  //
  //      .rx_full_o(rx_queue_full_o),
  //      .rx_start_thld_trig_o(rx_queue_start_thld_trig_o),
  //      .rx_ready_thld_trig_o(rx_queue_ready_thld_trig_o),
  //      .rx_empty_o(rx_queue_empty_o),
  //      .rx_wvalid_i(rx_queue_wvalid_i),
  //      .rx_wready_o(rx_queue_wready_o),
  //      .rx_wdata_i(rx_queue_wdata_i),
  //      .rx_req_i(rx_queue_req),
  //      .rx_ack_o(hwif_tti_o.RX_DATA_PORT.rd_ack),
  //      .rx_data_o(hwif_tti_o.RX_DATA_PORT.rd_data),
  //      .rx_start_thld_i(rx_queue_start_thld),
  //      .rx_ready_thld_i(rx_queue_ready_thld),
  //      .rx_ready_thld_o(rx_queue_ready_thld_o),
  //      .rx_reg_rst_i(rx_queue_rst),
  //      .rx_reg_rst_we_o(hwif_tti_o.RESET_CONTROL.RX_DATA_RST.we),
  //      .rx_reg_rst_data_o(hwif_tti_o.RESET_CONTROL.RX_DATA_RST.next),
  //
  //      .tx_full_o(tx_queue_full_o),
  //      .tx_start_thld_trig_o(tx_queue_start_thld_trig_o),
  //      .tx_ready_thld_trig_o(tx_queue_ready_thld_trig_o),
  //      .tx_empty_o(tx_queue_empty_o),
  //      .tx_rvalid_o(tx_queue_rvalid_o),
  //      .tx_rready_i(tx_queue_rready_i),
  //      .tx_rdata_o(tx_queue_rdata_o),
  //      .tx_req_i(tx_queue_req & tx_queue_req_is_wr),
  //      .tx_ack_o(hwif_tti_o.TX_DATA_PORT.wr_ack),
  //      .tx_data_i(tx_queue_wr_data),
  //      .tx_start_thld_i(tx_queue_start_thld),
  //      .tx_ready_thld_i(tx_queue_ready_thld),
  //      .tx_ready_thld_o(tx_queue_ready_thld_o),
  //      .tx_reg_rst_i(tx_queue_rst),
  //      .tx_reg_rst_we_o(hwif_tti_o.RESET_CONTROL.TX_DATA_RST.we),
  //      .tx_reg_rst_data_o(hwif_tti_o.RESET_CONTROL.TX_DATA_RST.next)
  //  );
  //
  //  // In-band Interrupt queue
  //  logic unused_ibi_start_thld_trig;
  //  logic [IbiThldWidth-1:0] ibi_queue_ready_thld;
  //  logic ibi_queue_rst;
  //  logic ibi_queue_req;
  //  logic ibi_queue_req_is_wr;
  //  logic [IbiDataWidth-1:0] ibi_queue_wr_data;
  //  logic unused_ibi_queue_start_thld_trig;
  //
  //  always_comb begin
  //    ibi_queue_rst = hwif_tti_i.RESET_CONTROL.IBI_QUEUE_RST.value;
  //    ibi_queue_ready_thld = IbiThldWidth'(hwif_tti_i.QUEUE_THLD_CTRL.IBI_THLD.value);
  //    ibi_queue_req = hwif_tti_i.IBI_PORT.req;
  //    ibi_queue_req_is_wr = hwif_tti_i.IBI_PORT.req_is_wr;
  //    ibi_queue_wr_data = hwif_tti_i.IBI_PORT.wr_data;
  //  end
  //
  //  write_queue #(
  //      .CsrDataWidth,
  //      .Depth(IbiFifoDepth),
  //      .DataWidth(IbiDataWidth),
  //      .ThldWidth(IbiThldWidth),
  //      .LimitReadyThld(0),
  //      .ThldIsPow(0)
  //  ) ibi_queue (
  //      .clk_i,
  //      .rst_ni,
  //
  //      .full_o(ibi_queue_full_o),
  //      .start_thld_trig_o(unused_ibi_queue_start_thld_trig),
  //      .ready_thld_trig_o(ibi_queue_ready_thld_trig_o),
  //      .empty_o(ibi_queue_empty_o),
  //      .rvalid_o(ibi_queue_rvalid_o),
  //      .rready_i(ibi_queue_rready_i),
  //      .rdata_o(ibi_queue_rdata_o),
  //
  //      .req_i (ibi_queue_req & ibi_queue_req_is_wr),
  //      .ack_o (hwif_tti_o.IBI_PORT.wr_ack),
  //      .data_i(ibi_queue_wr_data),
  //
  //      .start_thld_i('0),
  //      .ready_thld_i(ibi_queue_ready_thld),
  //      .ready_thld_o(ibi_queue_ready_thld_o),
  //
  //      .reg_rst_i(ibi_queue_rst),
  //      .reg_rst_we_o(hwif_tti_o.RESET_CONTROL.IBI_QUEUE_RST.we),
  //      .reg_rst_data_o(hwif_tti_o.RESET_CONTROL.IBI_QUEUE_RST.next)
  //  );
endmodule : tti
