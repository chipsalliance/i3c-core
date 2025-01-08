// SPDX-License-Identifier: Apache-2.0

module recovery_handler
  import i3c_pkg::*;
#(

    parameter int unsigned TtiRxDescDataWidth = 32,
    parameter int unsigned TtiRxDescThldWidth = 8,
    parameter int unsigned TtiRxDescFifoDepth = 64,
    localparam int unsigned TtiRxDescFifoDepthWidth = $clog2(TtiRxDescFifoDepth + 1),

    parameter int unsigned TtiTxDescDataWidth = 32,
    parameter int unsigned TtiTxDescThldWidth = 8,
    parameter int unsigned TtiTxDescFifoDepth = 64,
    localparam int unsigned TtiTxDescFifoDepthWidth = $clog2(TtiTxDescFifoDepth + 1),

    parameter int unsigned TtiRxDataDataWidth = 32,
    parameter int unsigned TtiRxDataThldWidth = 3,
    parameter int unsigned TtiRxDataFifoDepth = 64,
    localparam int unsigned TtiRxDataFifoDepthWidth = $clog2(TtiRxDataFifoDepth + 1),

    parameter int unsigned TtiTxDataDataWidth = 32,
    parameter int unsigned TtiTxDataThldWidth = 3,
    parameter int unsigned TtiTxDataFifoDepth = 64,
    localparam int unsigned TtiTxDataFifoDepthWidth = $clog2(TtiTxDataFifoDepth + 1),

    parameter int unsigned TtiIbiDataWidth = 32,
    parameter int unsigned TtiIbiThldWidth = 8,
    parameter int unsigned TtiIbiFifoDepth = 64,
    localparam int unsigned TtiIbiFifoDepthWidth = $clog2(TtiIbiFifoDepth + 1),

    parameter int unsigned CsrDataWidth = 32

) (
    input logic clk_i,  // Clock
    input logic rst_ni, // Reset (active low)

    // ....................................................
    // TTI interface (controller side)

    // RX Descriptor queue
    output logic                               ctl_tti_rx_desc_queue_full_o,
    output logic [TtiRxDescFifoDepthWidth-1:0] ctl_tti_rx_desc_queue_depth_o,
    output logic                               ctl_tti_rx_desc_queue_empty_o,
    input  logic                               ctl_tti_rx_desc_queue_wvalid_i,
    output logic                               ctl_tti_rx_desc_queue_wready_o,
    input  logic [     TtiRxDescDataWidth-1:0] ctl_tti_rx_desc_queue_wdata_i,
    output logic [     TtiRxDescThldWidth-1:0] ctl_tti_rx_desc_queue_ready_thld_o,
    output logic                               ctl_tti_rx_desc_queue_ready_thld_trig_o,

    // TX Descriptor queue
    output logic                               ctl_tti_tx_desc_queue_full_o,
    output logic [TtiTxDescFifoDepthWidth-1:0] ctl_tti_tx_desc_queue_depth_o,
    output logic                               ctl_tti_tx_desc_queue_empty_o,
    output logic                               ctl_tti_tx_desc_queue_rvalid_o,
    input  logic                               ctl_tti_tx_desc_queue_rready_i,
    output logic [     TtiTxDescDataWidth-1:0] ctl_tti_tx_desc_queue_rdata_o,
    output logic [     TtiTxDescThldWidth-1:0] ctl_tti_tx_desc_queue_ready_thld_o,
    output logic                               ctl_tti_tx_desc_queue_ready_thld_trig_o,

    // RX Data queue
    output logic                               ctl_tti_rx_data_queue_full_o,
    output logic [TtiRxDataFifoDepthWidth-1:0] ctl_tti_rx_data_queue_depth_o,
    output logic                               ctl_tti_rx_data_queue_empty_o,
    input  logic                               ctl_tti_rx_data_queue_wvalid_i,
    output logic                               ctl_tti_rx_data_queue_wready_o,
    input  logic [                        7:0] ctl_tti_rx_data_queue_wdata_i,
    input  logic                               ctl_tti_rx_data_queue_flush_i,
    output logic [     TtiRxDataThldWidth-1:0] ctl_tti_rx_data_queue_start_thld_o,
    output logic                               ctl_tti_rx_data_queue_start_thld_trig_o,
    output logic [     TtiRxDataThldWidth-1:0] ctl_tti_rx_data_queue_ready_thld_o,
    output logic                               ctl_tti_rx_data_queue_ready_thld_trig_o,

    // TX Data queue
    output logic                               ctl_tti_tx_data_queue_full_o,
    output logic [TtiTxDataFifoDepthWidth-1:0] ctl_tti_tx_data_queue_depth_o,
    output logic                               ctl_tti_tx_data_queue_empty_o,
    output logic                               ctl_tti_tx_data_queue_rvalid_o,
    input  logic                               ctl_tti_tx_data_queue_rready_i,
    output logic [                        7:0] ctl_tti_tx_data_queue_rdata_o,
    input  logic                               ctl_tti_tx_data_queue_flush_i,
    output logic [     TtiTxDataThldWidth-1:0] ctl_tti_tx_data_queue_start_thld_o,
    output logic                               ctl_tti_tx_data_queue_start_thld_trig_o,
    output logic [     TtiTxDataThldWidth-1:0] ctl_tti_tx_data_queue_ready_thld_o,
    output logic                               ctl_tti_tx_data_queue_ready_thld_trig_o,
    input  logic                               ctl_tti_tx_host_nack_i,

    // In-band Interrupt (IBI) queue
    output logic                            ctl_tti_ibi_queue_full_o,
    output logic [TtiIbiFifoDepthWidth-1:0] ctl_tti_ibi_queue_depth_o,
    output logic                            ctl_tti_ibi_queue_empty_o,
    output logic                            ctl_tti_ibi_queue_rvalid_o,
    input  logic                            ctl_tti_ibi_queue_rready_i,
    output logic [     TtiIbiDataWidth-1:0] ctl_tti_ibi_queue_rdata_o,
    output logic [     TtiIbiThldWidth-1:0] ctl_tti_ibi_queue_ready_thld_o,
    output logic                            ctl_tti_ibi_queue_ready_thld_trig_o,

    // S/Sr and P bus condition
    input logic ctl_bus_start_i,
    input logic ctl_bus_stop_i,

    // Received I2C/I3C address along with RnW# bit
    input logic [7:0] ctl_bus_addr_i,
    input logic ctl_bus_addr_valid_i,

    // ....................................................
    // TTI interface (CSR side)

    // RX Descriptor queue
    input  logic                          csr_tti_rx_desc_queue_req_i,
    output logic                          csr_tti_rx_desc_queue_ack_o,
    output logic [TtiRxDescDataWidth-1:0] csr_tti_rx_desc_queue_data_o,
    input  logic [TtiRxDescThldWidth-1:0] csr_tti_rx_desc_queue_ready_thld_i,
    output logic [TtiRxDescThldWidth-1:0] csr_tti_rx_desc_queue_ready_thld_o,
    input  logic                          csr_tti_rx_desc_queue_reg_rst_i,
    output logic                          csr_tti_rx_desc_queue_reg_rst_we_o,
    output logic                          csr_tti_rx_desc_queue_reg_rst_data_o,

    // TX Descriptor queue
    input  logic                          csr_tti_tx_desc_queue_req_i,
    output logic                          csr_tti_tx_desc_queue_ack_o,
    input  logic [      CsrDataWidth-1:0] csr_tti_tx_desc_queue_data_i,
    input  logic [TtiTxDescThldWidth-1:0] csr_tti_tx_desc_queue_ready_thld_i,
    output logic [TtiTxDescThldWidth-1:0] csr_tti_tx_desc_queue_ready_thld_o,
    input  logic                          csr_tti_tx_desc_queue_reg_rst_i,
    output logic                          csr_tti_tx_desc_queue_reg_rst_we_o,
    output logic                          csr_tti_tx_desc_queue_reg_rst_data_o,

    // RX data queue
    input  logic                          csr_tti_rx_data_queue_req_i,
    output logic                          csr_tti_rx_data_queue_ack_o,
    output logic [TtiRxDataDataWidth-1:0] csr_tti_rx_data_queue_data_o,
    input  logic [TtiRxDataThldWidth-1:0] csr_tti_rx_data_queue_start_thld_i,
    input  logic [TtiRxDataThldWidth-1:0] csr_tti_rx_data_queue_ready_thld_i,
    output logic [TtiRxDataThldWidth-1:0] csr_tti_rx_data_queue_ready_thld_o,
    input  logic                          csr_tti_rx_data_queue_reg_rst_i,
    output logic                          csr_tti_rx_data_queue_reg_rst_we_o,
    output logic                          csr_tti_rx_data_queue_reg_rst_data_o,

    // TX data queue
    input  logic                          csr_tti_tx_data_queue_req_i,
    output logic                          csr_tti_tx_data_queue_ack_o,
    input  logic [      CsrDataWidth-1:0] csr_tti_tx_data_queue_data_i,
    input  logic [TtiTxDataThldWidth-1:0] csr_tti_tx_data_queue_start_thld_i,
    input  logic [TtiTxDataThldWidth-1:0] csr_tti_tx_data_queue_ready_thld_i,
    output logic [TtiTxDataThldWidth-1:0] csr_tti_tx_data_queue_ready_thld_o,
    input  logic                          csr_tti_tx_data_queue_reg_rst_i,
    output logic                          csr_tti_tx_data_queue_reg_rst_we_o,
    output logic                          csr_tti_tx_data_queue_reg_rst_data_o,

    // In-band Interrupt (IBI) queue
    input  logic                       csr_tti_ibi_queue_req_i,
    output logic                       csr_tti_ibi_queue_ack_o,
    input  logic [   CsrDataWidth-1:0] csr_tti_ibi_queue_data_i,
    input  logic [TtiIbiThldWidth-1:0] csr_tti_ibi_queue_ready_thld_i,
    input  logic                       csr_tti_ibi_queue_reg_rst_i,
    output logic                       csr_tti_ibi_queue_reg_rst_we_o,
    output logic                       csr_tti_ibi_queue_reg_rst_data_o,

    // ....................................................
    // Recovery CSR interface

    // CSR
    input  I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__out_t hwif_rec_i,
    output I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__in_t  hwif_rec_o,

    // ....................................................

    // Interrupt
    output logic irq_o,

    // Recovery status
    output logic payload_available_o,
    output logic image_activated_o
);
  assign irq_o = '0;

  // ....................................................

  logic recovery_enable;
  localparam int unsigned RecoveryMode = 'h3;

  assign recovery_enable = hwif_rec_i.DEVICE_STATUS_0.PLACEHOLDER.value[7:0] == RecoveryMode;

  // ....................................................
  // TTI Queues

  // RX descriptor
  logic                               tti_rx_desc_queue_full;
  logic [TtiRxDescFifoDepthWidth-1:0] tti_rx_desc_queue_depth;
  logic                               unused_tti_rx_desc_start_thld_trig;
  logic                               tti_rx_desc_queue_empty;
  logic                               tti_rx_desc_queue_wvalid;
  logic                               tti_rx_desc_queue_wready;
  logic [     TtiRxDescDataWidth-1:0] tti_rx_desc_queue_wdata;
  logic                               tti_rx_desc_queue_ready_thld_trig;

  logic                               tti_rx_desc_queue_req;
  logic                               tti_rx_desc_queue_ack;
  logic [     TtiRxDescDataWidth-1:0] tti_rx_desc_queue_data;
  logic [     TtiRxDescThldWidth-1:0] tti_rx_desc_queue_ready_thld_i;
  logic [     TtiRxDescThldWidth-1:0] tti_rx_desc_queue_ready_thld_o;
  logic                               tti_rx_desc_queue_reg_rst;
  logic                               tti_rx_desc_queue_reg_rst_we;
  logic                               tti_rx_desc_queue_reg_rst_data;

  // TX descriptor
  logic                               tti_tx_desc_queue_full;
  logic [TtiTxDescFifoDepthWidth-1:0] tti_tx_desc_queue_depth;
  logic                               tti_tx_desc_queue_empty;
  logic                               tti_tx_desc_queue_rvalid;
  logic                               tti_tx_desc_queue_rready;
  logic [     TtiTxDescDataWidth-1:0] tti_tx_desc_queue_rdata;
  logic                               tti_tx_desc_queue_ready_thld_trig;

  logic                               tti_tx_desc_queue_req;
  logic                               tti_tx_desc_queue_ack;
  logic [     TtiTxDescDataWidth-1:0] tti_tx_desc_queue_data;
  logic [     TtiTxDescThldWidth-1:0] tti_tx_desc_queue_ready_thld_i;
  logic [     TtiTxDescThldWidth-1:0] tti_tx_desc_queue_ready_thld_o;
  logic                               tti_tx_desc_queue_reg_rst;
  logic                               tti_tx_desc_queue_reg_rst_we;
  logic                               tti_tx_desc_queue_reg_rst_data;

  // RX Data queue
  logic                               tti_rx_data_queue_full;
  logic [TtiRxDataFifoDepthWidth-1:0] tti_rx_data_queue_depth;
  logic                               tti_rx_data_queue_empty;
  logic                               tti_rx_data_queue_wvalid;
  logic                               tti_rx_data_queue_wready;
  logic [                        7:0] tti_rx_data_queue_wdata;
  logic                               tti_rx_data_queue_flush;  // For data width conv.
  logic                               tti_rx_data_queue_start_thld_trig;
  logic                               tti_rx_data_queue_ready_thld_trig;

  logic                               tti_rx_data_queue_req;
  logic                               tti_rx_data_queue_ack;
  logic [     TtiRxDataDataWidth-1:0] tti_rx_data_queue_data;
  logic [     TtiRxDataThldWidth-1:0] tti_rx_data_queue_start_thld;
  logic [     TtiRxDataThldWidth-1:0] tti_rx_data_queue_ready_thld_i;
  logic [     TtiRxDataThldWidth-1:0] tti_rx_data_queue_ready_thld_o;
  logic                               tti_rx_data_queue_reg_rst;
  logic                               tti_rx_data_queue_reg_rst_we;
  logic                               tti_rx_data_queue_reg_rst_next;

  // TX Data queue
  logic                               tti_tx_data_queue_full;
  logic [TtiTxDataFifoDepthWidth-1:0] tti_tx_data_queue_depth;
  logic                               tti_tx_data_queue_empty;
  logic                               tti_tx_data_queue_rvalid;
  logic                               tti_tx_data_queue_rready;
  logic [                        7:0] tti_tx_data_queue_rdata;
  logic                               tti_tx_data_queue_flush;
  logic                               tti_tx_data_queue_start_thld_trig;
  logic                               tti_tx_data_queue_ready_thld_trig;

  logic                               tti_tx_data_queue_req;
  logic                               tti_tx_data_queue_ack;
  logic [     TtiTxDataDataWidth-1:0] tti_tx_data_queue_data;
  logic [     TtiTxDataThldWidth-1:0] tti_tx_data_queue_start_thld;
  logic [     TtiTxDataThldWidth-1:0] tti_tx_data_queue_ready_thld_i;
  logic [     TtiTxDataThldWidth-1:0] tti_tx_data_queue_ready_thld_o;
  logic                               tti_tx_data_queue_reg_rst;
  logic                               tti_tx_data_queue_reg_rst_we;
  logic                               tti_tx_data_queue_reg_rst_next;

  // IBI
  logic                               tti_ibi_queue_req;
  logic                               tti_ibi_queue_ack;

  // Unused
  logic
      unused_rx_desc_start_thld_trig,
      unused_tx_desc_start_thld_trig,
      unused_ibi_queue_start_thld_trig;

  // Data width converters
  logic                          tti_rx_data_queue_wvalid_q;
  logic                          tti_rx_data_queue_wready_q;
  logic [TtiRxDataDataWidth-1:0] tti_rx_data_queue_wdata_q;

  logic                          tti_tx_data_queue_rvalid_q;
  logic                          tti_tx_data_queue_rready_q;
  logic [TtiTxDataDataWidth-1:0] tti_tx_data_queue_rdata_q;

  width_converter_8toN #(
      .Width(TtiRxDataDataWidth)

  ) tti_conv_8toN (
      .clk_i,
      .rst_ni,

      .sink_valid_i(tti_rx_data_queue_wvalid),
      .sink_ready_o(tti_rx_data_queue_wready),
      .sink_data_i (tti_rx_data_queue_wdata),
      .sink_flush_i(tti_rx_data_queue_flush),

      .source_valid_o(tti_rx_data_queue_wvalid_q),
      .source_ready_i(tti_rx_data_queue_wready_q),
      .source_data_o (tti_rx_data_queue_wdata_q)
  );

  width_converter_Nto8 #(
      .Width(TtiRxDataDataWidth)

  ) tti_conv_Nto8 (
      .clk_i,
      .rst_ni,

      .sink_valid_i(tti_tx_data_queue_rvalid_q),
      .sink_ready_o(tti_tx_data_queue_rready_q),
      .sink_data_i (tti_tx_data_queue_rdata_q),

      .source_valid_o(tti_tx_data_queue_rvalid),
      .source_ready_i(tti_tx_data_queue_rready),
      .source_data_o (tti_tx_data_queue_rdata),
      .source_flush_i(tti_tx_data_queue_flush)
  );

  // Data queues
  queues #(

      .CsrDataWidth(CsrDataWidth),

      .TxDescFifoDepth(TtiTxDescFifoDepth),
      .RxDescFifoDepth(TtiRxDescFifoDepth),
      .TxFifoDepth    (TtiTxDataFifoDepth),
      .RxFifoDepth    (TtiRxDataFifoDepth),

      .TxDescFifoDataWidth(TtiTxDescDataWidth),
      .RxDescFifoDataWidth(TtiRxDescDataWidth),
      .TxFifoDataWidth    (TtiTxDataDataWidth),
      .RxFifoDataWidth    (TtiRxDataDataWidth),

      .TxDescFifoThldWidth(TtiTxDescThldWidth),
      .RxDescFifoThldWidth(TtiRxDescThldWidth),
      .TxFifoThldWidth    (TtiTxDataThldWidth),
      .RxFifoThldWidth    (TtiRxDataThldWidth)

  ) tti_queues (

      .clk_i,
      .rst_ni,

      // RX descriptor queue
      .rx_desc_full_o(tti_rx_desc_queue_full),
      .rx_desc_depth_o(tti_rx_desc_queue_depth),
      .rx_desc_start_thld_trig_o(unused_tti_rx_desc_start_thld_trig),  // Intentionally left hanging, unsupported by TTI RX Desc Queue
      .rx_desc_ready_thld_trig_o(tti_rx_desc_queue_ready_thld_trig),
      .rx_desc_empty_o(tti_rx_desc_queue_empty),
      .rx_desc_wvalid_i(tti_rx_desc_queue_wvalid),
      .rx_desc_wready_o(tti_rx_desc_queue_wready),
      .rx_desc_wdata_i(tti_rx_desc_queue_wdata),

      .rx_desc_req_i(tti_rx_desc_queue_req),
      .rx_desc_ack_o(tti_rx_desc_queue_ack),
      .rx_desc_data_o(tti_rx_desc_queue_data),
      .rx_desc_start_thld_i('0),  // Unsupported by RX Desc Queue
      .rx_desc_ready_thld_i(tti_rx_desc_queue_ready_thld_i),
      .rx_desc_ready_thld_o(tti_rx_desc_queue_ready_thld_o),
      .rx_desc_reg_rst_i(tti_rx_desc_queue_reg_rst),
      .rx_desc_reg_rst_we_o(tti_rx_desc_queue_reg_rst_we),
      .rx_desc_reg_rst_data_o(tti_rx_desc_queue_reg_rst_data),

      // TX descriptor queue
      .tx_desc_full_o(tti_tx_desc_queue_full),
      .tx_desc_depth_o(tti_tx_desc_queue_depth),
      .tx_desc_start_thld_trig_o(unused_tx_desc_start_thld_trig),  // Intentionally left hanging, unsupported by TTI TX Desc Queue
      .tx_desc_ready_thld_trig_o(tti_tx_desc_queue_ready_thld_trig),
      .tx_desc_empty_o(tti_tx_desc_queue_empty),
      .tx_desc_rvalid_o(tti_tx_desc_queue_rvalid),
      .tx_desc_rready_i(tti_tx_desc_queue_rready),
      .tx_desc_rdata_o(tti_tx_desc_queue_rdata),

      .tx_desc_req_i(tti_tx_desc_queue_req),
      .tx_desc_ack_o(tti_tx_desc_queue_ack),
      .tx_desc_data_i(tti_tx_desc_queue_data),
      .tx_desc_start_thld_i('0),  // Unsupported by TX Desc Queue
      .tx_desc_ready_thld_i(tti_tx_desc_queue_ready_thld_i),
      .tx_desc_ready_thld_o(tti_tx_desc_queue_ready_thld_o),
      .tx_desc_reg_rst_i(tti_tx_desc_queue_reg_rst),
      .tx_desc_reg_rst_we_o(tti_tx_desc_queue_reg_rst_we),
      .tx_desc_reg_rst_data_o(tti_tx_desc_queue_reg_rst_data),

      // RX data queue
      .rx_full_o(tti_rx_data_queue_full),
      .rx_depth_o(tti_rx_data_queue_depth),
      .rx_start_thld_trig_o(tti_rx_data_queue_start_thld_trig),
      .rx_ready_thld_trig_o(tti_rx_data_queue_ready_thld_trig),
      .rx_empty_o(tti_rx_data_queue_empty),
      .rx_wvalid_i(tti_rx_data_queue_wvalid_q),
      .rx_wready_o(tti_rx_data_queue_wready_q),
      .rx_wdata_i(tti_rx_data_queue_wdata_q),
      .rx_req_i(tti_rx_data_queue_req),
      .rx_ack_o(tti_rx_data_queue_ack),
      .rx_data_o(tti_rx_data_queue_data),
      .rx_start_thld_i(tti_rx_data_queue_start_thld),
      .rx_ready_thld_i(tti_rx_data_queue_ready_thld_i),
      .rx_ready_thld_o(tti_rx_data_queue_ready_thld_o),
      .rx_reg_rst_i(tti_rx_data_queue_reg_rst),
      .rx_reg_rst_we_o(tti_rx_data_queue_reg_rst_we),
      .rx_reg_rst_data_o(tti_rx_data_queue_reg_rst_next),

      // TX data queue
      .tx_full_o(tti_tx_data_queue_full),
      .tx_depth_o(tti_tx_data_queue_depth),
      .tx_start_thld_trig_o(tti_tx_data_queue_start_thld_trig),
      .tx_ready_thld_trig_o(tti_tx_data_queue_ready_thld_trig),
      .tx_empty_o(tti_tx_data_queue_empty),
      .tx_rvalid_o(tti_tx_data_queue_rvalid_q),
      .tx_rready_i(tti_tx_data_queue_rready_q),
      .tx_rdata_o(tti_tx_data_queue_rdata_q),
      .tx_req_i(tti_tx_data_queue_req),
      .tx_ack_o(tti_tx_data_queue_ack),
      .tx_data_i(tti_tx_data_queue_data),
      .tx_start_thld_i(tti_tx_data_queue_start_thld),
      .tx_ready_thld_i(tti_tx_data_queue_ready_thld_i),
      .tx_ready_thld_o(tti_tx_data_queue_ready_thld_o),
      .tx_reg_rst_i(tti_tx_data_queue_reg_rst),
      .tx_reg_rst_we_o(tti_tx_data_queue_reg_rst_we),
      .tx_reg_rst_data_o(tti_tx_data_queue_reg_rst_next)
  );

  // Recovery data available signal.
  // assign payload_available_o = recovery_enable & !tti_rx_data_queue_empty;

  // IBI
  write_queue #(

      .CsrDataWidth  (CsrDataWidth),
      .Depth         (TtiIbiFifoDepth),
      .DataWidth     (TtiIbiDataWidth),
      .ThldWidth     (TtiIbiThldWidth),
      .LimitReadyThld(0),
      .ThldIsPow     (0)

  ) ibi_queue (

      .clk_i,
      .rst_ni,

      .full_o(ctl_tti_ibi_queue_full_o),
      .depth_o(ctl_tti_ibi_queue_depth_o),
      .start_thld_trig_o(unused_ibi_queue_start_thld_trig),
      .ready_thld_trig_o(ctl_tti_ibi_queue_ready_thld_trig_o),
      .empty_o(ctl_tti_ibi_queue_empty_o),
      .rvalid_o(ctl_tti_ibi_queue_rvalid_o),
      .rready_i(ctl_tti_ibi_queue_rready_i),
      .rdata_o(ctl_tti_ibi_queue_rdata_o),

      .req_i (tti_ibi_queue_req),
      .ack_o (tti_ibi_queue_ack),
      .data_i(csr_tti_ibi_queue_data_i),

      .start_thld_i('0),  // The IBI queue does not support start threshold
      .ready_thld_i(csr_tti_ibi_queue_ready_thld_i),
      .ready_thld_o(ctl_tti_ibi_queue_ready_thld_o),

      .reg_rst_i(csr_tti_ibi_queue_reg_rst_i),
      .reg_rst_we_o(csr_tti_ibi_queue_reg_rst_we_o),
      .reg_rst_data_o(csr_tti_ibi_queue_reg_rst_data_o)
  );

  // Prevent CSR writes to IBI queue in recovery mode
  // Make writes from CSR side seem as always accepted
  // TODO: Consult TTI and recovery specification and verify if it is a
  //       legitimate behavior.
  always_comb begin
    if (recovery_enable) begin
      tti_ibi_queue_req       = 1'b0;
      csr_tti_ibi_queue_ack_o = csr_tti_ibi_queue_req_i;
    end else begin
      tti_ibi_queue_req       = csr_tti_ibi_queue_req_i;
      csr_tti_ibi_queue_ack_o = tti_ibi_queue_ack;
    end
  end

  // ....................................................
  // TTI Queues <-> controller mux

  logic recv_tti_rx_desc_valid;
  logic recv_tti_rx_desc_ready;
  logic [TtiRxDescDataWidth-1:0] recv_tti_rx_desc_data;

  logic send_tti_tx_desc_valid;
  logic send_tti_tx_desc_ready;
  logic [TtiTxDescDataWidth-1:0] send_tti_tx_desc_data;

  // RX descriptor queue
  always_comb begin : R1MUX
    if (recovery_enable) begin
      recv_tti_rx_desc_valid                  = ctl_tti_rx_desc_queue_wvalid_i;
      tti_rx_desc_queue_wvalid                = '0;
      ctl_tti_rx_desc_queue_full_o            = '0;
      ctl_tti_rx_desc_queue_depth_o           = '0;
      ctl_tti_rx_desc_queue_empty_o           = '0;
      ctl_tti_rx_desc_queue_wready_o          = recv_tti_rx_desc_ready;
      ctl_tti_rx_desc_queue_ready_thld_trig_o = '0;
    end else begin
      recv_tti_rx_desc_valid                  = '0;
      tti_rx_desc_queue_wvalid                = ctl_tti_rx_desc_queue_wvalid_i;
      ctl_tti_rx_desc_queue_full_o            = tti_rx_desc_queue_full;
      ctl_tti_rx_desc_queue_depth_o           = tti_rx_desc_queue_depth;
      ctl_tti_rx_desc_queue_empty_o           = tti_rx_desc_queue_empty;
      ctl_tti_rx_desc_queue_wready_o          = tti_rx_desc_queue_wready;
      ctl_tti_rx_desc_queue_ready_thld_trig_o = tti_rx_desc_queue_ready_thld_trig;
    end

    tti_rx_desc_queue_wdata                   = ctl_tti_rx_desc_queue_wdata_i; // Don't mux data, disabling valid is enough
    recv_tti_rx_desc_data = ctl_tti_rx_desc_queue_wdata_i;
  end

  // Threshold
  assign ctl_tti_rx_desc_queue_ready_thld_o = tti_rx_desc_queue_ready_thld_o;

  // TX descriptor queue
  always_comb begin : T1MUX
    if (recovery_enable) begin
      send_tti_tx_desc_ready                  = ctl_tti_tx_desc_queue_rready_i;
      tti_tx_desc_queue_rready                = '0;
      ctl_tti_tx_desc_queue_full_o            = '0;
      ctl_tti_tx_desc_queue_depth_o           = '1; // Always maximum data count available
      ctl_tti_tx_desc_queue_empty_o           = '1; // Never empty
      ctl_tti_tx_desc_queue_rvalid_o          = send_tti_tx_desc_valid;
      ctl_tti_tx_desc_queue_rdata_o           = send_tti_tx_desc_data;
      ctl_tti_tx_desc_queue_ready_thld_trig_o = '0;
    end else begin
      send_tti_tx_desc_ready                  = '0;
      tti_tx_desc_queue_rready                = ctl_tti_tx_desc_queue_rready_i;
      ctl_tti_tx_desc_queue_full_o            = tti_tx_desc_queue_full;
      ctl_tti_tx_desc_queue_depth_o           = tti_tx_desc_queue_depth;
      ctl_tti_tx_desc_queue_empty_o           = tti_tx_desc_queue_empty;
      ctl_tti_tx_desc_queue_rvalid_o          = tti_tx_desc_queue_rvalid;
      ctl_tti_tx_desc_queue_rdata_o           = tti_tx_desc_queue_rdata;
      ctl_tti_tx_desc_queue_ready_thld_trig_o = tti_tx_desc_queue_ready_thld_trig;
    end
  end

  // Threshold
  assign ctl_tti_tx_desc_queue_ready_thld_o = tti_tx_desc_queue_ready_thld_o;

  // ......................

  logic       recv_tti_rx_data_valid;
  logic       recv_tti_rx_data_ready;
  logic [7:0] recv_tti_rx_data_data;

  logic       recv_tti_rx_data_queue_select;
  logic       recv_tti_rx_data_queue_flush;

  // RX data queue
  always_comb begin : R2MUX
    if (recovery_enable & recv_tti_rx_data_queue_select) begin
      recv_tti_rx_data_valid                  = ctl_tti_rx_data_queue_wvalid_i;
      tti_rx_data_queue_wvalid                = '0;
      tti_rx_data_queue_flush                 = recv_tti_rx_data_queue_flush;
      ctl_tti_rx_data_queue_full_o            = tti_rx_data_queue_full;
      ctl_tti_rx_data_queue_depth_o           = tti_rx_data_queue_depth;
      ctl_tti_rx_data_queue_empty_o           = tti_rx_data_queue_empty;
      ctl_tti_rx_data_queue_wready_o          = recv_tti_rx_data_ready;
      ctl_tti_rx_data_queue_start_thld_trig_o = '0;
      ctl_tti_rx_data_queue_ready_thld_trig_o = '0;
    end else begin
      recv_tti_rx_data_valid                  = '0;
      tti_rx_data_queue_wvalid                = ctl_tti_rx_data_queue_wvalid_i;
      tti_rx_data_queue_flush                 = ctl_tti_rx_data_queue_flush_i;
      ctl_tti_rx_data_queue_full_o            = tti_rx_data_queue_full;
      ctl_tti_rx_data_queue_depth_o           = tti_rx_data_queue_depth;
      ctl_tti_rx_data_queue_empty_o           = tti_rx_data_queue_empty;
      ctl_tti_rx_data_queue_wready_o          = tti_rx_data_queue_wready;
      ctl_tti_rx_data_queue_start_thld_trig_o = tti_rx_data_queue_start_thld_trig;
      ctl_tti_rx_data_queue_ready_thld_trig_o = tti_rx_data_queue_ready_thld_trig;
    end

    tti_rx_data_queue_wdata                   = ctl_tti_rx_data_queue_wdata_i; // Don't mux data, disabling valid is enough
    recv_tti_rx_data_data = ctl_tti_rx_data_queue_wdata_i;
  end

  // Thresholds
  assign ctl_tti_rx_data_queue_start_thld_o = tti_rx_data_queue_start_thld;
  assign ctl_tti_rx_data_queue_ready_thld_o = tti_rx_data_queue_ready_thld_o;

  // ......................

  logic       send_tti_tx_data_valid;
  logic       send_tti_tx_data_ready;
  logic [7:0] send_tti_tx_data_data;
  logic       send_tti_tx_data_flush;

  logic       send_tti_tx_data_queue_select;
  logic       send_tti_tx_start_trig;

  // TX data queue
  always_comb begin : T2MUX
    if (recovery_enable & send_tti_tx_data_queue_select) begin
      tti_tx_data_queue_rready                = '0;
      send_tti_tx_data_ready                  = ctl_tti_tx_data_queue_rready_i;
      tti_tx_data_queue_flush                 = send_tti_tx_data_flush;
      ctl_tti_tx_data_queue_full_o            = '0;
      ctl_tti_tx_data_queue_depth_o           = '1; // Always maximum data count available
      ctl_tti_tx_data_queue_empty_o           = '1; // Never empty
      ctl_tti_tx_data_queue_rvalid_o          = send_tti_tx_data_valid;
      ctl_tti_tx_data_queue_rdata_o           = send_tti_tx_data_data;
      ctl_tti_tx_data_queue_start_thld_trig_o = send_tti_tx_start_trig;
      ctl_tti_tx_data_queue_ready_thld_trig_o = '0;
    end else begin
      tti_tx_data_queue_rready                = ctl_tti_tx_data_queue_rready_i;
      tti_tx_data_queue_flush                 = ctl_tti_tx_data_queue_flush_i;
      send_tti_tx_data_ready                  = '0;
      ctl_tti_tx_data_queue_full_o            = tti_tx_data_queue_full;
      ctl_tti_tx_data_queue_depth_o           = tti_tx_data_queue_depth;
      ctl_tti_tx_data_queue_empty_o           = tti_tx_data_queue_empty;
      ctl_tti_tx_data_queue_rvalid_o          = tti_tx_data_queue_rvalid;
      ctl_tti_tx_data_queue_rdata_o           = tti_tx_data_queue_rdata;
      ctl_tti_tx_data_queue_start_thld_trig_o = tti_tx_data_queue_start_thld_trig;
      ctl_tti_tx_data_queue_ready_thld_trig_o = tti_tx_data_queue_ready_thld_trig;
    end
  end

  // Thresholds
  assign ctl_tti_tx_data_queue_start_thld_o = tti_tx_data_queue_start_thld;
  assign ctl_tti_tx_data_queue_ready_thld_o = tti_tx_data_queue_ready_thld_o;

  // ....................................................
  // TTI Queues <-> CSR mux

  logic exec_tti_rx_desc_queue_clr;
  // RX descriptor queue
  always_comb begin : R4SW
    if (recovery_enable) begin
      csr_tti_rx_desc_queue_ack_o          = '0;
      csr_tti_rx_desc_queue_data_o         = '0;
      csr_tti_rx_desc_queue_reg_rst_we_o   = '0;
      csr_tti_rx_desc_queue_reg_rst_data_o = '0;
      tti_rx_desc_queue_req                = '0;
      tti_rx_desc_queue_reg_rst            = exec_tti_rx_desc_queue_clr;
    end else begin
      csr_tti_rx_desc_queue_ack_o          = tti_rx_desc_queue_ack;
      csr_tti_rx_desc_queue_data_o         = tti_rx_desc_queue_data;
      csr_tti_rx_desc_queue_reg_rst_we_o   = tti_rx_desc_queue_reg_rst_we;
      csr_tti_rx_desc_queue_reg_rst_data_o = tti_rx_desc_queue_reg_rst_data;
      tti_rx_desc_queue_req                = csr_tti_rx_desc_queue_req_i;
      tti_rx_desc_queue_reg_rst            = csr_tti_rx_desc_queue_reg_rst_i;
    end
  end

  // Threshold
  assign tti_rx_desc_queue_ready_thld_i     = csr_tti_rx_desc_queue_ready_thld_i;
  assign csr_tti_rx_desc_queue_ready_thld_o = tti_rx_desc_queue_ready_thld_o;

  // ......................
  // TX desc is always connected, recovery logic generates its own descriptors
  // T1MUX disconnects this FIFO from TTI logic
  logic exec_tti_tx_desc_queue_clr;

  assign csr_tti_tx_desc_queue_ack_o          = tti_tx_desc_queue_ack;
  assign csr_tti_tx_desc_queue_reg_rst_we_o   = tti_tx_desc_queue_reg_rst_we;
  assign csr_tti_tx_desc_queue_reg_rst_data_o = tti_tx_desc_queue_reg_rst_data;
  assign tti_tx_desc_queue_data               = csr_tti_tx_desc_queue_data_i;
  assign tti_tx_desc_queue_req                = csr_tti_tx_desc_queue_req_i;
  assign tti_tx_desc_queue_reg_rst            = csr_tti_tx_desc_queue_reg_rst_i | exec_tti_tx_desc_queue_clr;

  // Threshold
  assign tti_tx_desc_queue_ready_thld_i     = csr_tti_tx_desc_queue_ready_thld_i;
  assign csr_tti_tx_desc_queue_ready_thld_o = tti_tx_desc_queue_ready_thld_o;

  // ......................

  logic exec_tti_rx_data_req;
  logic exec_tti_rx_data_ack;
  logic [TtiRxDataDataWidth-1:0] exec_tti_rx_data_data;
  logic exec_tti_rx_queue_sel;
  logic exec_tti_rx_data_queue_clr;

  // RX data queue
  always_comb begin : R3MUX
    if (recovery_enable & exec_tti_rx_queue_sel) begin
      csr_tti_rx_data_queue_ack_o          = '0;
      csr_tti_rx_data_queue_reg_rst_we_o   = '0;
      csr_tti_rx_data_queue_reg_rst_data_o = '0;
      tti_rx_data_queue_req                = exec_tti_rx_data_req;
      tti_rx_data_queue_reg_rst            = exec_tti_rx_data_queue_clr;
      exec_tti_rx_data_ack                 = tti_rx_data_queue_ack;
    end else begin
      csr_tti_rx_data_queue_ack_o          = tti_rx_data_queue_ack;
      csr_tti_rx_data_queue_reg_rst_we_o   = tti_rx_data_queue_reg_rst_we;
      csr_tti_rx_data_queue_reg_rst_data_o = tti_rx_data_queue_reg_rst_next;
      tti_rx_data_queue_req                = csr_tti_rx_data_queue_req_i;
      tti_rx_data_queue_reg_rst            = csr_tti_rx_data_queue_reg_rst_i;
      exec_tti_rx_data_ack                 = '0;
    end

    // No need to mux data
    csr_tti_rx_data_queue_data_o = tti_rx_data_queue_data;
    exec_tti_rx_data_data        = tti_rx_data_queue_data;
  end

  // Threshold
  assign tti_rx_data_queue_start_thld       = csr_tti_rx_data_queue_start_thld_i;
  assign tti_rx_data_queue_ready_thld_i     = csr_tti_rx_data_queue_ready_thld_i;
  assign csr_tti_rx_data_queue_ready_thld_o = tti_rx_data_queue_ready_thld_o;

  // ......................

  logic exec_tti_tx_data_queue_clr;
  // TX data queue
  always_comb begin : T4MUX
    if (recovery_enable) begin
      csr_tti_tx_data_queue_ack_o          = '0;
      csr_tti_tx_data_queue_reg_rst_we_o   = '0;
      csr_tti_tx_data_queue_reg_rst_data_o = '0;
      tti_tx_data_queue_data               = '0;
      tti_tx_data_queue_req                = '0;
      tti_tx_data_queue_reg_rst            = exec_tti_tx_data_queue_clr;
    end else begin
      csr_tti_tx_data_queue_ack_o          = tti_tx_data_queue_ack;
      csr_tti_tx_data_queue_reg_rst_we_o   = tti_tx_data_queue_reg_rst_we;
      csr_tti_tx_data_queue_reg_rst_data_o = tti_tx_data_queue_reg_rst_next;
      tti_tx_data_queue_data               = csr_tti_tx_data_queue_data_i;
      tti_tx_data_queue_req                = csr_tti_tx_data_queue_req_i;
      tti_tx_data_queue_reg_rst            = csr_tti_tx_data_queue_reg_rst_i;
    end
  end

  // Threshold
  assign tti_tx_data_queue_start_thld       = csr_tti_tx_data_queue_start_thld_i;
  assign tti_tx_data_queue_ready_thld_i     = csr_tti_tx_data_queue_ready_thld_i;
  assign csr_tti_tx_data_queue_ready_thld_o = tti_tx_data_queue_ready_thld_o;

  // ....................................................

  // PEC init
  logic bus_addr_valid;
  logic pec_init;

  always @(posedge clk_i or negedge rst_ni)
    if (~rst_ni) begin
      bus_addr_valid <= '0;
    end else if (ctl_bus_start_i) begin
      bus_addr_valid <= '0;
    end else if (~bus_addr_valid && ctl_bus_addr_valid_i) begin
      bus_addr_valid <= '1;
    end

  assign pec_init = ctl_bus_addr_valid_i & ~bus_addr_valid;

  // ....................................................

  logic cmd_valid;
  logic cmd_is_rd;
  logic [7:0] cmd_cmd;
  logic [15:0] cmd_len;
  logic cmd_error;
  logic        cmd_done; // TODO: Consider replacing this with rx_cmd_ready and making the executor not ready rather than pulsing done.

  // RX PEC calculator
  logic rx_pec_clear;
  logic rx_pec_valid;
  logic rx_pec_init;
  logic [7:0] rx_pec_data;

  logic [7:0] recv_pec_crc;
  logic recv_pec_enable;

  recovery_pec xrecovery_rx_pec (
      .clk_i,
      .rst_ni(rst_ni & !rx_pec_clear & recovery_enable),

      .dat_i  (rx_pec_data),
      .valid_i(rx_pec_valid),
      .init_i (rx_pec_init),
      .crc_o  (recv_pec_crc)
  );

  // RX PEC mux for initializing it with I2C/I3C address byte
  always_comb begin
    rx_pec_data  = pec_init ? ctl_bus_addr_i : tti_rx_data_queue_wdata;
    rx_pec_valid = pec_init ? 1'b1 : recv_pec_enable;
    rx_pec_init  = pec_init ? 1'b1 : 1'b0;
  end

  // Clear PEC on start
  assign rx_pec_clear = ctl_bus_start_i;

  // Recovery packet reception handler
  recovery_receiver xrecovery_receiver (
      .clk_i,
      .rst_ni(rst_ni & recovery_enable),

      .desc_valid_i(recv_tti_rx_desc_valid),
      .desc_ready_o(recv_tti_rx_desc_ready),
      .desc_data_i (recv_tti_rx_desc_data),

      .data_valid_i(recv_tti_rx_data_valid),
      .data_ready_o(recv_tti_rx_data_ready),
      .data_data_i (recv_tti_rx_data_data),

      .data_queue_select_o(recv_tti_rx_data_queue_select),
      .data_queue_flush_o (recv_tti_rx_data_queue_flush),
      .data_queue_flow_i  (tti_rx_data_queue_wvalid & tti_rx_data_queue_wready),

      .bus_start_i(ctl_bus_start_i),
      .bus_stop_i (ctl_bus_stop_i),

      .pec_crc_i   (recv_pec_crc),
      .pec_enable_o(recv_pec_enable),

      .cmd_valid_o(cmd_valid),
      .cmd_is_rd_o(cmd_is_rd),
      .cmd_cmd_o  (cmd_cmd),
      .cmd_len_o  (cmd_len),
      .cmd_error_o(cmd_error),
      .cmd_done_i (cmd_done)
  );

  // ....................................................

  logic        res_valid;
  logic        res_ready;
  logic [15:0] res_len;

  logic        res_dvalid;
  logic        res_dready;
  logic [ 7:0] res_data;
  logic        res_dlast;

  // TX PEC calculator
  logic        tx_pec_clear;
  logic        tx_pec_valid;
  logic        tx_pec_init;
  logic [ 7:0] tx_pec_data;

  logic [ 7:0] xmit_pec_crc;
  logic        xmit_pec_enable;

  recovery_pec xrecovery_tx_pec (
      .clk_i,
      .rst_ni(rst_ni & !tx_pec_clear & recovery_enable),

      .dat_i  (tx_pec_data),
      .valid_i(tx_pec_valid),
      .init_i (tx_pec_init),
      .crc_o  (xmit_pec_crc)
  );

  // TX PEC mux for initializing it with I2C/I3C address byte
  always_comb begin
    tx_pec_data  = pec_init ? ctl_bus_addr_i : ctl_tti_tx_data_queue_rdata_o;
    tx_pec_valid = pec_init ? 1'b1 : xmit_pec_enable;
    tx_pec_init  = pec_init ? 1'b1 : 1'b0;
  end

  // Clear PEC on start
  assign tx_pec_clear = ctl_bus_start_i;

  // Recovery packet transmitter
  recovery_transmitter xrecovery_transmitter (
      .clk_i,
      .rst_ni(rst_ni & recovery_enable),

      .desc_valid_o(send_tti_tx_desc_valid),
      .desc_ready_i(send_tti_tx_desc_ready),
      .desc_data_o (send_tti_tx_desc_data),

      .data_valid_o(send_tti_tx_data_valid),
      .data_ready_i(send_tti_tx_data_ready),
      .data_data_o (send_tti_tx_data_data),

      .data_queue_select_o(send_tti_tx_data_queue_select),
      .start_trig_o(send_tti_tx_start_trig),

      .host_abort_i(ctl_tti_tx_host_nack_i | ctl_bus_stop_i),

      .pec_crc_i   (xmit_pec_crc),
      .pec_enable_o(xmit_pec_enable),

      .res_valid_i(res_valid),
      .res_ready_o(res_ready),
      .res_len_i  (res_len),

      .res_dvalid_i(res_dvalid),
      .res_dready_o(res_dready),
      .res_data_i  (res_data),
      .res_dlast_i (res_dlast)
  );

  // ....................................................

  // Command executor
  recovery_executor xrecovery_executor (
      .clk_i,
      .rst_ni(rst_ni & recovery_enable),

      .cmd_valid_i(cmd_valid),
      .cmd_is_rd_i(cmd_is_rd),
      .cmd_cmd_i  (cmd_cmd),
      .cmd_len_i  (cmd_len),
      .cmd_error_i(cmd_error),
      .cmd_done_o (cmd_done),

      .res_valid_o(res_valid),
      .res_ready_i(res_ready),
      .res_len_o  (res_len),

      .res_dvalid_o(res_dvalid),
      .res_dready_i(res_dready),
      .res_data_o  (res_data),
      .res_dlast_o (res_dlast),

      .rx_req_o      (exec_tti_rx_data_req),
      .rx_ack_i      (exec_tti_rx_data_ack),
      .rx_data_i     (exec_tti_rx_data_data),
      .rx_queue_sel_o(exec_tti_rx_queue_sel),

      .rx_data_queue_clr_o(exec_tti_rx_data_queue_clr),
      .rx_desc_queue_clr_o(exec_tti_rx_desc_queue_clr),
      .tx_data_queue_clr_o(exec_tti_tx_data_queue_clr),
      .tx_desc_queue_clr_o(exec_tti_tx_desc_queue_clr),

      .rx_queue_full_i (tti_rx_data_queue_full),
      .rx_queue_empty_i(tti_rx_data_queue_empty),

      .host_abort_i(ctl_tti_tx_host_nack_i | ctl_bus_stop_i),

      .payload_available_o(payload_available_o),
      .image_activated_o  (image_activated_o),

      .hwif_rec_i(hwif_rec_i),
      .hwif_rec_o(hwif_rec_o)
  );

endmodule
