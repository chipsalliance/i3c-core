// SPDX-License-Identifier: Apache-2.0

module recovery_handler
  import i3c_pkg::*;
#(

    parameter int unsigned TtiRxDescDataWidth = 32,
    parameter int unsigned TtiRxDescThldWidth = 8,
    parameter int unsigned TtiRxDescFifoDepth = 64,

    parameter int unsigned TtiTxDescDataWidth = 32,
    parameter int unsigned TtiTxDescThldWidth = 8,
    parameter int unsigned TtiTxDescFifoDepth = 64,

    parameter int unsigned TtiRxDataDataWidth = 32,
    parameter int unsigned TtiRxDataThldWidth = 3,
    parameter int unsigned TtiRxDataFifoDepth = 64,

    parameter int unsigned TtiTxDataDataWidth = 32,
    parameter int unsigned TtiTxDataThldWidth = 3,
    parameter int unsigned TtiTxDataFifoDepth = 64,

    parameter int unsigned TtiIbiDataWidth = 32,
    parameter int unsigned TtiIbiThldWidth = 8,
    parameter int unsigned TtiIbiFifoDepth = 64,

    parameter int unsigned CsrDataWidth = 32

) (
    input logic clk_i,  // Clock
    input logic rst_ni, // Reset (active low)

    // ....................................................
    // TTI interface (controller side)

    // RX Descriptor queue
    output logic                          ctl_tti_rx_desc_queue_full_o,
    output logic                          ctl_tti_rx_desc_queue_empty_o,
    input  logic                          ctl_tti_rx_desc_queue_wvalid_i,
    output logic                          ctl_tti_rx_desc_queue_wready_o,
    input  logic [TtiRxDescDataWidth-1:0] ctl_tti_rx_desc_queue_wdata_i,
    output logic [TtiRxDescThldWidth-1:0] ctl_tti_rx_desc_queue_ready_thld_o,
    output logic                          ctl_tti_rx_desc_queue_ready_thld_trig_o,

    // TX Descriptor queue
    output logic                          ctl_tti_tx_desc_queue_full_o,
    output logic                          ctl_tti_tx_desc_queue_empty_o,
    output logic                          ctl_tti_tx_desc_queue_rvalid_o,
    input  logic                          ctl_tti_tx_desc_queue_rready_i,
    output logic [TtiTxDescDataWidth-1:0] ctl_tti_tx_desc_queue_rdata_o,
    output logic [TtiTxDescThldWidth-1:0] ctl_tti_tx_desc_queue_ready_thld_o,
    output logic                          ctl_tti_tx_desc_queue_ready_thld_trig_o,

    // RX Data queue
    output logic                          ctl_tti_rx_data_queue_full_o,
    output logic                          ctl_tti_rx_data_queue_empty_o,
    input  logic                          ctl_tti_rx_data_queue_wvalid_i,
    output logic                          ctl_tti_rx_data_queue_wready_o,
    input  logic [                   7:0] ctl_tti_rx_data_queue_wdata_i,
    input  logic                          ctl_tti_rx_data_queue_wflush_i,
    output logic [TtiRxDataThldWidth-1:0] ctl_tti_rx_data_queue_start_thld_o,
    output logic                          ctl_tti_rx_data_queue_start_thld_trig_o,
    output logic [TtiRxDataThldWidth-1:0] ctl_tti_rx_data_queue_ready_thld_o,
    output logic                          ctl_tti_rx_data_queue_ready_thld_trig_o,

    // TX Data queue
    output logic                          ctl_tti_tx_data_queue_full_o,
    output logic                          ctl_tti_tx_data_queue_empty_o,
    output logic                          ctl_tti_tx_data_queue_rvalid_o,
    input  logic                          ctl_tti_tx_data_queue_rready_i,
    output logic [                   7:0] ctl_tti_tx_data_queue_rdata_o,
    output logic [TtiTxDataThldWidth-1:0] ctl_tti_tx_data_queue_start_thld_o,
    output logic                          ctl_tti_tx_data_queue_start_thld_trig_o,
    output logic [TtiTxDataThldWidth-1:0] ctl_tti_tx_data_queue_ready_thld_o,
    output logic                          ctl_tti_tx_data_queue_ready_thld_trig_o,

    // In-band Interrupt (IBI) queue
    output logic                       ctl_tti_ibi_queue_full_o,
    output logic                       ctl_tti_ibi_queue_empty_o,
    output logic                       ctl_tti_ibi_queue_rvalid_o,
    input  logic                       ctl_tti_ibi_queue_rready_i,
    output logic [TtiIbiDataWidth-1:0] ctl_tti_ibi_queue_rdata_o,
    output logic [TtiIbiThldWidth-1:0] ctl_tti_ibi_queue_ready_thld_o,
    output logic                       ctl_tti_ibi_queue_ready_thld_trig_o,

    // Received I2C/I3C address along with RnW# bit
    input  logic [7:0] ctl_bus_addr_i,
    input  logic ctl_bus_addr_valid_i,

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
    output logic irq_o
);

  // ....................................................

  logic recovery_enable;
  assign recovery_enable = 1'b0;

  // ....................................................
  // TTI Queues

  // RX descriptor
  logic                          tti_rx_desc_queue_full;
  logic                          unused_tti_rx_desc_start_thld_trig;
  logic                          tti_rx_desc_queue_empty;
  logic                          tti_rx_desc_queue_wvalid;
  logic                          tti_rx_desc_queue_wready;
  logic [TtiRxDescDataWidth-1:0] tti_rx_desc_queue_wdata;
  logic                          tti_rx_desc_queue_ready_thld_trig;

  logic                          tti_rx_desc_queue_req;
  logic                          tti_rx_desc_queue_ack;
  logic [TtiRxDescDataWidth-1:0] tti_rx_desc_queue_data;
  logic [TtiRxDescThldWidth-1:0] tti_rx_desc_queue_ready_thld_i;
  logic [TtiRxDescThldWidth-1:0] tti_rx_desc_queue_ready_thld_o;
  logic                          tti_rx_desc_queue_reg_rst;
  logic                          tti_rx_desc_queue_reg_rst_we;
  logic                          tti_rx_desc_queue_reg_rst_data;

  // TX descriptor
  logic                          tti_tx_desc_queue_full;
  logic                          tti_tx_desc_queue_empty;
  logic                          tti_tx_desc_queue_rvalid;
  logic                          tti_tx_desc_queue_rready;
  logic [TtiTxDescDataWidth-1:0] tti_tx_desc_queue_rdata;
  logic                          tti_tx_desc_queue_ready_thld_trig;

  logic                          tti_tx_desc_queue_req;
  logic                          tti_tx_desc_queue_ack;
  logic [TtiTxDescDataWidth-1:0] tti_tx_desc_queue_data;
  logic [TtiTxDescThldWidth-1:0] tti_tx_desc_queue_ready_thld_i;
  logic [TtiTxDescThldWidth-1:0] tti_tx_desc_queue_ready_thld_o;
  logic                          tti_tx_desc_queue_reg_rst;
  logic                          tti_tx_desc_queue_reg_rst_we;
  logic                          tti_tx_desc_queue_reg_rst_data;

  // RX Data queue
  logic                          tti_rx_data_queue_full;
  logic                          tti_rx_data_queue_empty;
  logic                          tti_rx_data_queue_wvalid;
  logic                          tti_rx_data_queue_wready;
  logic [                   7:0] tti_rx_data_queue_wdata;
  logic                          tti_rx_data_queue_wflush;  // For data width conv.
  logic                          tti_rx_data_queue_start_thld_trig;
  logic                          tti_rx_data_queue_ready_thld_trig;

  logic                          tti_rx_data_queue_req;
  logic                          tti_rx_data_queue_ack;
  logic [TtiRxDataDataWidth-1:0] tti_rx_data_queue_data;
  logic [TtiRxDataThldWidth-1:0] tti_rx_data_queue_start_thld;
  logic [TtiRxDataThldWidth-1:0] tti_rx_data_queue_ready_thld_i;
  logic [TtiRxDataThldWidth-1:0] tti_rx_data_queue_ready_thld_o;
  logic                          tti_rx_data_queue_reg_rst;
  logic                          tti_rx_data_queue_reg_rst_we;
  logic                          tti_rx_data_queue_reg_rst_next;

  // TX Data queue
  logic                          tti_tx_data_queue_full;
  logic                          tti_tx_data_queue_empty;
  logic                          tti_tx_data_queue_rvalid;
  logic                          tti_tx_data_queue_rready;
  logic [TtiTxDataDataWidth-1:0] tti_tx_data_queue_rdata;
  logic                          tti_tx_data_queue_start_thld_trig;
  logic                          tti_tx_data_queue_ready_thld_trig;

  logic                          tti_tx_data_queue_req;
  logic                          tti_tx_data_queue_ack;
  logic [TtiTxDataDataWidth-1:0] tti_tx_data_queue_data;
  logic [TtiTxDataThldWidth-1:0] tti_tx_data_queue_start_thld;
  logic [TtiTxDataThldWidth-1:0] tti_tx_data_queue_ready_thld_i;
  logic [TtiTxDataThldWidth-1:0] tti_tx_data_queue_ready_thld_o;
  logic                          tti_tx_data_queue_reg_rst;
  logic                          tti_tx_data_queue_reg_rst_we;
  logic                          tti_tx_data_queue_reg_rst_next;

  // IBI
  logic                          tti_ibi_queue_req;
  logic                          tti_ibi_queue_ack;

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

  width_converter_8toN # (
      .Width (TtiRxDataDataWidth)

  ) tti_conv_8toN (
      .clk_i,
      .rst_ni,

      .sink_valid_i   (tti_rx_data_queue_wvalid),
      .sink_ready_o   (tti_rx_data_queue_wready),
      .sink_data_i    (tti_rx_data_queue_wdata),
      .sink_flush_i   (tti_rx_data_queue_wflush),

      .source_valid_o  (tti_rx_data_queue_wvalid_q),
      .source_ready_i  (tti_rx_data_queue_wready_q),
      .source_data_o   (tti_rx_data_queue_wdata_q)
  );

  width_converter_Nto8 # (
      .Width (TtiRxDataDataWidth)

  ) tti_conv_Nto8 (
      .clk_i,
      .rst_ni,

      // Allow data flow between FIFO and width converter only if the downstream
      // port is ready.
      .sink_valid_i   (tti_tx_data_queue_rvalid_q & tti_tx_data_queue_rready),
      .sink_ready_o   (tti_tx_data_queue_rready_q),
      .sink_data_i    (tti_tx_data_queue_rdata_q),

      .source_valid_o  (tti_tx_data_queue_rvalid),
      .source_ready_i  (tti_tx_data_queue_rready),
      .source_data_o   (tti_tx_data_queue_rdata)
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
      .tx_start_thld_trig_o(tti_tx_data_queue_start_thld_trig),
      .tx_ready_thld_trig_o(tti_tx_data_queue_ready_thld_trig),
      .tx_empty_o(tti_tx_data_queue_empty),
      .tx_rvalid_o(tti_tx_data_queue_rvalid_q),
      .tx_rready_i(tti_tx_data_queue_rready_q & tti_tx_data_queue_rready), // Allow data flow between FIFO and width converter only if the downstream port is ready.
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

  // RX descriptor queue
  always_comb begin : R1MUX
    if (recovery_enable) begin
      tti_rx_desc_queue_wvalid                = '0;
      ctl_tti_rx_desc_queue_full_o            = '0;
      ctl_tti_rx_desc_queue_empty_o           = '0;
      ctl_tti_rx_desc_queue_wready_o          = '0;
      ctl_tti_rx_desc_queue_ready_thld_trig_o = '0;
    end else begin
      tti_rx_desc_queue_wvalid                = ctl_tti_rx_desc_queue_wvalid_i;
      ctl_tti_rx_desc_queue_full_o            = tti_rx_desc_queue_full;
      ctl_tti_rx_desc_queue_empty_o           = tti_rx_desc_queue_empty;
      ctl_tti_rx_desc_queue_wready_o          = tti_rx_desc_queue_wready;
      ctl_tti_rx_desc_queue_ready_thld_trig_o = tti_rx_desc_queue_ready_thld_trig;
    end

    tti_rx_desc_queue_wdata                   = ctl_tti_rx_desc_queue_wdata_i; // Don't mux data, disabling valid is enough
  end

  // Threshold
  assign ctl_tti_rx_desc_queue_ready_thld_o = tti_rx_desc_queue_ready_thld_o;

  // TX descriptor queue
  always_comb begin : T1MUX
    if (recovery_enable) begin
      tti_tx_desc_queue_rready                = '0;
      ctl_tti_tx_desc_queue_full_o            = '0;
      ctl_tti_tx_desc_queue_empty_o           = '0;
      ctl_tti_tx_desc_queue_rvalid_o          = '0;
      ctl_tti_tx_desc_queue_rdata_o           = '0;
      ctl_tti_tx_desc_queue_ready_thld_trig_o = '0;
    end else begin
      tti_tx_desc_queue_rready                = ctl_tti_tx_desc_queue_rready_i;
      ctl_tti_tx_desc_queue_full_o            = tti_tx_desc_queue_full;
      ctl_tti_tx_desc_queue_empty_o           = tti_tx_desc_queue_empty;
      ctl_tti_tx_desc_queue_rvalid_o          = tti_tx_desc_queue_rvalid;
      ctl_tti_tx_desc_queue_rdata_o           = tti_tx_desc_queue_rdata;
      ctl_tti_tx_desc_queue_ready_thld_trig_o = tti_tx_desc_queue_ready_thld_trig;
    end
  end

  // Threshold
  assign ctl_tti_tx_desc_queue_ready_thld_o = tti_tx_desc_queue_ready_thld_o;

  // ......................

  // RX data queue
  always_comb begin : R2MUX
    if (recovery_enable) begin
      tti_rx_data_queue_wvalid                = '0;
      tti_rx_data_queue_wdata                 = '0;
      tti_rx_data_queue_wflush                = '0;
      ctl_tti_rx_data_queue_full_o            = '0;
      ctl_tti_rx_data_queue_empty_o           = '0;
      ctl_tti_rx_data_queue_wready_o          = '0;
      ctl_tti_rx_data_queue_start_thld_trig_o = '0;
      ctl_tti_rx_data_queue_ready_thld_trig_o = '0;
    end else begin
      tti_rx_data_queue_wvalid                = ctl_tti_rx_data_queue_wvalid_i;
      tti_rx_data_queue_wdata                 = ctl_tti_rx_data_queue_wdata_i;
      tti_rx_data_queue_wflush                = ctl_tti_rx_data_queue_wflush_i;
      ctl_tti_rx_data_queue_full_o            = tti_rx_data_queue_full;
      ctl_tti_rx_data_queue_empty_o           = tti_rx_data_queue_empty;
      ctl_tti_rx_data_queue_wready_o          = tti_rx_data_queue_wready;
      ctl_tti_rx_data_queue_start_thld_trig_o = tti_rx_data_queue_start_thld_trig;
      ctl_tti_rx_data_queue_ready_thld_trig_o = tti_rx_data_queue_ready_thld_trig;
    end
  end

  // Thresholds
  assign ctl_tti_rx_data_queue_start_thld_o = tti_rx_data_queue_start_thld;
  assign ctl_tti_rx_data_queue_ready_thld_o = tti_rx_data_queue_ready_thld_o;

  // ......................

  // TX data queue
  always_comb begin : T2MUX
    if (recovery_enable) begin
      tti_tx_data_queue_rready                = '0;
      ctl_tti_tx_data_queue_full_o            = '0;
      ctl_tti_tx_data_queue_empty_o           = '0;
      ctl_tti_tx_data_queue_rvalid_o          = '0;
      ctl_tti_tx_data_queue_rdata_o           = '0;
      ctl_tti_tx_data_queue_start_thld_trig_o = '0;
      ctl_tti_tx_data_queue_ready_thld_trig_o = '0;
    end else begin
      tti_tx_data_queue_rready                = ctl_tti_tx_data_queue_rready_i;
      ctl_tti_tx_data_queue_full_o            = tti_tx_data_queue_full;
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

  // RX descriptor queue
  always_comb begin : R4SW
    if (recovery_enable) begin
      csr_tti_rx_desc_queue_ack_o          = '0;
      csr_tti_rx_desc_queue_data_o         = '0;
      csr_tti_rx_desc_queue_reg_rst_we_o   = '0;
      csr_tti_rx_desc_queue_reg_rst_data_o = '0;
      tti_rx_desc_queue_req                = '0;
      tti_rx_desc_queue_reg_rst            = '0;
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

  // TX descriptor queue
  always_comb begin : T4SW
    if (recovery_enable) begin
      csr_tti_tx_desc_queue_ack_o          = '0;
      csr_tti_tx_desc_queue_reg_rst_we_o   = '0;
      csr_tti_tx_desc_queue_reg_rst_data_o = '0;
      tti_tx_desc_queue_data               = '0;
      tti_tx_desc_queue_req                = '0;
      tti_tx_desc_queue_reg_rst            = '0;
    end else begin
      csr_tti_tx_desc_queue_ack_o          = tti_tx_desc_queue_ack;
      csr_tti_tx_desc_queue_reg_rst_we_o   = tti_tx_desc_queue_reg_rst_we;
      csr_tti_tx_desc_queue_reg_rst_data_o = tti_tx_desc_queue_reg_rst_data;
      tti_tx_desc_queue_data               = csr_tti_tx_desc_queue_data_i;
      tti_tx_desc_queue_req                = csr_tti_tx_desc_queue_req_i;
      tti_tx_desc_queue_reg_rst            = csr_tti_tx_desc_queue_reg_rst_i;
    end
  end

  // Threshold
  assign tti_tx_desc_queue_ready_thld_i     = csr_tti_tx_desc_queue_ready_thld_i;
  assign csr_tti_tx_desc_queue_ready_thld_o = tti_tx_desc_queue_ready_thld_o;

  // ......................

  // RX data queue
  always_comb begin : R4MUX
    if (recovery_enable) begin
      csr_tti_rx_data_queue_ack_o          = '0;
      csr_tti_rx_data_queue_data_o         = '0;
      csr_tti_rx_data_queue_reg_rst_we_o   = '0;
      csr_tti_rx_data_queue_reg_rst_data_o = '0;
      tti_rx_data_queue_req                = '0;
      tti_rx_data_queue_reg_rst            = '0;
    end else begin
      csr_tti_rx_data_queue_ack_o          = tti_rx_data_queue_ack;
      csr_tti_rx_data_queue_data_o         = tti_rx_data_queue_data;
      csr_tti_rx_data_queue_reg_rst_we_o   = tti_rx_data_queue_reg_rst_we;
      csr_tti_rx_data_queue_reg_rst_data_o = tti_rx_data_queue_reg_rst_next;
      tti_rx_data_queue_req                = csr_tti_rx_data_queue_req_i;
      tti_rx_data_queue_reg_rst            = csr_tti_rx_data_queue_reg_rst_i;
    end
  end

  // Threshold
  assign tti_rx_data_queue_start_thld       = csr_tti_rx_data_queue_start_thld_i;
  assign tti_rx_data_queue_ready_thld_i     = csr_tti_rx_data_queue_ready_thld_i;
  assign csr_tti_rx_data_queue_ready_thld_o = tti_rx_data_queue_ready_thld_o;

  // ......................

  // TX data queue
  always_comb begin : T4MUX
    if (recovery_enable) begin
      csr_tti_tx_data_queue_ack_o          = '0;
      csr_tti_tx_data_queue_reg_rst_we_o   = '0;
      csr_tti_tx_data_queue_reg_rst_data_o = '0;
      tti_tx_data_queue_data               = '0;
      tti_tx_data_queue_req                = '0;
      tti_tx_data_queue_reg_rst            = '0;
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
  //


endmodule
