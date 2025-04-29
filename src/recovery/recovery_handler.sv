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

    parameter int unsigned CsrDataWidth = 32,

    parameter int unsigned IndirectFifoDepth = 64

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
    output logic                          csr_tti_rx_desc_queue_ready_thld_trig_o,

    // TX Descriptor queue
    output logic                          csr_tti_tx_desc_queue_full_o,
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
    output logic                          csr_tti_rx_data_queue_ready_thld_trig_o,

    // TX data queue
    output logic                          csr_tti_tx_data_queue_full_o,
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
    // SoC Managment CSR interface
    input  I3CCSR_pkg::I3CCSR__I3C_EC__SoCMgmtIf__out_t hwif_socmgmt_i,
    output I3CCSR_pkg::I3CCSR__I3C_EC__SoCMgmtIf__in_t  hwif_socmgmt_o,

    // Recovery CSR interface
    input  I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__out_t hwif_rec_i,
    output I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__in_t  hwif_rec_o,

    input logic bypass_i3c_core_i,

    // ....................................................

    // Interrupt
    output logic irq_o,

    // Recovery status
    output logic payload_available_o,
    output logic image_activated_o,
    output logic recovery_mode_enter_o,
    output logic recovery_mode_enabled_o,
    input  logic virtual_device_sel_i,
    input  logic xfer_in_progress_i
);

  // The recovery mode does not support interrupts
  assign irq_o = '0;

  // ....................................................

  logic recovery_enable;
  logic recovery_mode_enabled;  //recovery globally enabled in the csr
  logic recovery_xfer_pending;
  logic recovery_exec_pending;
  logic recovery_pending;
  logic [1:0] recovery_mode_enter_shreg;
  localparam int unsigned RecoveryMode = 'h3;

  assign recovery_mode_enabled = (hwif_rec_i.DEVICE_STATUS_0.DEV_STATUS.value == RecoveryMode);
  assign recovery_enable = virtual_device_sel_i;

  // Output recovery mode enable state. Either via DEVICE_STATUS or via access through virtual target address
  assign recovery_mode_enabled_o = recovery_enable;

  // poke cec module to inlude addr data when we trigger recovery logic from virtual device interface
  logic [1:0] virtual_device_cec_shreg;
  always @(posedge clk_i or negedge rst_ni)
    if (~rst_ni) begin
      virtual_device_cec_shreg <= 2'b10;
    end else if (recovery_enable) begin
      virtual_device_cec_shreg <= {1'b0, virtual_device_cec_shreg[1]};
    end else begin
      virtual_device_cec_shreg <= 2'b10;
    end

  // generate recovery enter pulse
  assign recovery_mode_enter_o = recovery_mode_enter_shreg[0];
  always @(posedge clk_i or negedge rst_ni)
    if (~rst_ni) begin
      recovery_mode_enter_shreg <= 2'b10;
    end else if (recovery_enable) begin
      recovery_mode_enter_shreg <= {1'b0, recovery_mode_enter_shreg[1]};
    end else begin
      recovery_mode_enter_shreg <= 2'b10;
    end

  // Recovery transfer pending signal
  assign recovery_xfer_pending = xfer_in_progress_i && virtual_device_sel_i;

  // Recovery execution pending signal
  logic recv_cmd_valid;
  logic cmd_done;

  always @(posedge clk_i or negedge rst_ni)
    if (~rst_ni) begin
      recovery_exec_pending <= '0;
    end else if (recv_cmd_valid) begin
      recovery_exec_pending <= '1;
    end else if (cmd_done) begin
      recovery_exec_pending <= '0;
    end

  // Recovery transfer and execution pending
  assign recovery_pending = recovery_xfer_pending | recovery_exec_pending;

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
  logic [                       31:0] tti_tx_data_queue_rdata;
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

  // 8toN Converter -> TTI RX Data Queue
  logic                          tti_rx_data_queue_wvalid_q;
  logic                          tti_rx_data_queue_wready_q;
  logic [TtiRxDataDataWidth-1:0] tti_rx_data_queue_wdata_q;

  // TTI TX Data Queue -> Nto8 Converter
  logic                          tti_tx_data_queue_rvalid_conv_sink;
  logic                          tti_tx_data_queue_rready_conv_sink;
  logic [TtiTxDataDataWidth-1:0] tti_tx_data_queue_rdata_conv_sink;

  // Nto8 Converter -> I3C Controller
  logic                          tti_tx_data_queue_rvalid_conv_source;
  logic                          tti_tx_data_queue_rready_conv_source;
  logic [                   7:0] tti_tx_data_queue_rdata_conv_source;
  logic                          tti_tx_data_queue_flush_conv_source;

  width_converter_8toN #(
      .Width(TtiRxDataDataWidth)

  ) tti_conv_8toN (
      .clk_i,
      .rst_ni(rst_ni),
      .soft_reset_ni(~bypass_i3c_core_i),

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
      .rst_ni(rst_ni),
      .soft_reset_ni(~bypass_i3c_core_i),

      .sink_valid_i(tti_tx_data_queue_rvalid_conv_sink),
      .sink_ready_o(tti_tx_data_queue_rready_conv_sink),
      .sink_data_i (tti_tx_data_queue_rdata_conv_sink),

      .source_valid_o(tti_tx_data_queue_rvalid_conv_source),
      .source_ready_i(tti_tx_data_queue_rready_conv_source),
      .source_data_o (tti_tx_data_queue_rdata_conv_source),
      .source_flush_i(tti_tx_data_queue_flush_conv_source)
  );

  logic allow_indirect_write, allow_indirect_read;
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
      .tx_rvalid_o(tti_tx_data_queue_rvalid),
      .tx_rready_i(tti_tx_data_queue_rready),
      .tx_rdata_o(tti_tx_data_queue_rdata),
      .tx_req_i(tti_tx_data_queue_req & allow_indirect_write),
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
      .depth_o(ctl_tti_ibi_queue_depth_o),
      .start_thld_trig_o(unused_ibi_queue_start_thld_trig),
      .ready_thld_trig_o(ctl_tti_ibi_queue_ready_thld_trig_o),
      .empty_o(ctl_tti_ibi_queue_empty_o),
      .rvalid_o(ctl_tti_ibi_queue_rvalid_o),
      .rready_i(ctl_tti_ibi_queue_rready_i),
      .rdata_o(ctl_tti_ibi_queue_rdata_o),

      .req_i (csr_tti_ibi_queue_req_i),
      .ack_o (csr_tti_ibi_queue_ack_o),
      .data_i(csr_tti_ibi_queue_data_i),

      .start_thld_i('0),  // The IBI queue does not support start threshold
      .ready_thld_i(csr_tti_ibi_queue_ready_thld_i),
      .ready_thld_o(ctl_tti_ibi_queue_ready_thld_o),

      .reg_rst_i(csr_tti_ibi_queue_reg_rst_i),
      .reg_rst_we_o(csr_tti_ibi_queue_reg_rst_we_o),
      .reg_rst_data_o(csr_tti_ibi_queue_reg_rst_data_o)
  );

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
    if (recovery_pending) begin
      recv_tti_rx_desc_valid                  = ctl_tti_rx_desc_queue_wvalid_i;
      tti_rx_desc_queue_wvalid                = '0;
      ctl_tti_rx_desc_queue_full_o            = '0;
      ctl_tti_rx_desc_queue_depth_o           = '0;
      ctl_tti_rx_desc_queue_empty_o           = '0;
      ctl_tti_rx_desc_queue_wready_o          = recv_tti_rx_desc_ready;
      csr_tti_rx_desc_queue_ready_thld_trig_o = '0;
    end else begin
      recv_tti_rx_desc_valid                  = '0;
      tti_rx_desc_queue_wvalid                = ctl_tti_rx_desc_queue_wvalid_i;
      ctl_tti_rx_desc_queue_full_o            = tti_rx_desc_queue_full;
      ctl_tti_rx_desc_queue_depth_o           = tti_rx_desc_queue_depth;
      ctl_tti_rx_desc_queue_empty_o           = tti_rx_desc_queue_empty;
      ctl_tti_rx_desc_queue_wready_o          = tti_rx_desc_queue_wready;
      csr_tti_rx_desc_queue_ready_thld_trig_o = tti_rx_desc_queue_ready_thld_trig;
    end

    tti_rx_desc_queue_wdata                   = ctl_tti_rx_desc_queue_wdata_i; // Don't mux data, disabling valid is enough
    recv_tti_rx_desc_data = ctl_tti_rx_desc_queue_wdata_i;
  end

  // Threshold
  assign ctl_tti_rx_desc_queue_ready_thld_o = tti_rx_desc_queue_ready_thld_o;
  assign ctl_tti_rx_desc_queue_ready_thld_trig_o = tti_rx_desc_queue_ready_thld_trig;

  // TX descriptor queue
  always_comb begin : T1MUX
    if (recovery_pending) begin
      send_tti_tx_desc_ready                  = ctl_tti_tx_desc_queue_rready_i;
      tti_tx_desc_queue_rready                = '0;
      ctl_tti_tx_desc_queue_full_o            = '0;
      ctl_tti_tx_desc_queue_depth_o           = '1;  // Always maximum data count available
      ctl_tti_tx_desc_queue_empty_o           = '1;  // Never empty
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
    if (recovery_pending & recv_tti_rx_data_queue_select) begin
      recv_tti_rx_data_valid                  = ctl_tti_rx_data_queue_wvalid_i;
      tti_rx_data_queue_wvalid                = '0;
      tti_rx_data_queue_flush                 = recv_tti_rx_data_queue_flush;
      ctl_tti_rx_data_queue_full_o            = tti_rx_data_queue_full;
      ctl_tti_rx_data_queue_depth_o           = tti_rx_data_queue_depth;
      ctl_tti_rx_data_queue_empty_o           = tti_rx_data_queue_empty;
      ctl_tti_rx_data_queue_wready_o          = recv_tti_rx_data_ready;
      ctl_tti_rx_data_queue_start_thld_trig_o = '0;
      csr_tti_rx_data_queue_ready_thld_trig_o = '0;
    end else begin
      recv_tti_rx_data_valid                  = '0;
      tti_rx_data_queue_wvalid                = ctl_tti_rx_data_queue_wvalid_i;
      tti_rx_data_queue_flush                 = ctl_tti_rx_data_queue_flush_i;
      ctl_tti_rx_data_queue_full_o            = tti_rx_data_queue_full;
      ctl_tti_rx_data_queue_depth_o           = tti_rx_data_queue_depth;
      ctl_tti_rx_data_queue_empty_o           = tti_rx_data_queue_empty;
      ctl_tti_rx_data_queue_wready_o          = tti_rx_data_queue_wready;
      ctl_tti_rx_data_queue_start_thld_trig_o = tti_rx_data_queue_start_thld_trig;
      csr_tti_rx_data_queue_ready_thld_trig_o = tti_rx_data_queue_ready_thld_trig;
    end

    tti_rx_data_queue_wdata                   = ctl_tti_rx_data_queue_wdata_i; // Don't mux data, disabling valid is enough
    recv_tti_rx_data_data = ctl_tti_rx_data_queue_wdata_i;
  end

  // Thresholds
  assign ctl_tti_rx_data_queue_start_thld_o = tti_rx_data_queue_start_thld;
  assign ctl_tti_rx_data_queue_ready_thld_o = tti_rx_data_queue_ready_thld_o;
  assign ctl_tti_rx_data_queue_ready_thld_trig_o = tti_rx_data_queue_ready_thld_trig;

  // ......................

  logic       send_tti_tx_data_valid;
  logic       send_tti_tx_data_ready;
  logic [7:0] send_tti_tx_data_data;

  logic       send_tti_tx_data_queue_select;
  logic       send_tti_tx_start_trig;

  // TX data queue
  always_comb begin : T2MUX
    if (bypass_i3c_core_i) begin
      tti_tx_data_queue_rready_conv_source    = '0;
      send_tti_tx_data_ready                  = '0;
      tti_tx_data_queue_flush_conv_source     = '0;
      ctl_tti_tx_data_queue_full_o            = '0;
      ctl_tti_tx_data_queue_depth_o           = '0;
      ctl_tti_tx_data_queue_empty_o           = '0;
      ctl_tti_tx_data_queue_rvalid_o          = '0;
      ctl_tti_tx_data_queue_rdata_o           = '0;
      ctl_tti_tx_data_queue_start_thld_trig_o = '0;
      ctl_tti_tx_data_queue_ready_thld_trig_o = '0;
    end else if (recovery_pending & send_tti_tx_data_queue_select) begin
      tti_tx_data_queue_rready_conv_source    = '0;
      send_tti_tx_data_ready                  = ctl_tti_tx_data_queue_rready_i;
      tti_tx_data_queue_flush_conv_source     = '0;
      ctl_tti_tx_data_queue_full_o            = '0;
      ctl_tti_tx_data_queue_depth_o           = '1;  // Always maximum data count available
      ctl_tti_tx_data_queue_empty_o           = '1;  // Never empty
      ctl_tti_tx_data_queue_rvalid_o          = send_tti_tx_data_valid;
      ctl_tti_tx_data_queue_rdata_o           = send_tti_tx_data_data;
      ctl_tti_tx_data_queue_start_thld_trig_o = send_tti_tx_start_trig;
      ctl_tti_tx_data_queue_ready_thld_trig_o = '0;

    end else begin
      tti_tx_data_queue_rready_conv_source    = ctl_tti_tx_data_queue_rready_i;
      tti_tx_data_queue_flush_conv_source     = ctl_tti_tx_data_queue_flush_i;
      send_tti_tx_data_ready                  = '0;
      ctl_tti_tx_data_queue_full_o            = tti_tx_data_queue_full;
      ctl_tti_tx_data_queue_depth_o           = tti_tx_data_queue_depth;
      ctl_tti_tx_data_queue_empty_o           = tti_tx_data_queue_empty;
      ctl_tti_tx_data_queue_rvalid_o          = tti_tx_data_queue_rvalid_conv_source;
      ctl_tti_tx_data_queue_rdata_o           = tti_tx_data_queue_rdata_conv_source;
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
    if (recovery_pending) begin
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

  assign csr_tti_tx_desc_queue_full_o = tti_tx_desc_queue_full;
  assign csr_tti_tx_desc_queue_ack_o = tti_tx_desc_queue_ack;
  assign csr_tti_tx_desc_queue_reg_rst_we_o = tti_tx_desc_queue_reg_rst_we;
  assign csr_tti_tx_desc_queue_reg_rst_data_o = tti_tx_desc_queue_reg_rst_data;
  assign tti_tx_desc_queue_data = csr_tti_tx_desc_queue_data_i;
  assign tti_tx_desc_queue_req = csr_tti_tx_desc_queue_req_i;
  assign tti_tx_desc_queue_reg_rst = csr_tti_tx_desc_queue_reg_rst_i | exec_tti_tx_desc_queue_clr;

  // Threshold
  assign tti_tx_desc_queue_ready_thld_i = csr_tti_tx_desc_queue_ready_thld_i;
  assign csr_tti_tx_desc_queue_ready_thld_o = tti_tx_desc_queue_ready_thld_o;

  // ......................

  logic exec_tti_rx_data_req;
  logic exec_tti_rx_data_ack;
  logic [TtiRxDataDataWidth-1:0] exec_tti_rx_data_data;
  logic exec_tti_rx_queue_sel;
  logic exec_tti_rx_data_queue_clr;

  // RX data queue
  always_comb begin : R3MUX
    if (bypass_i3c_core_i) begin
      exec_tti_rx_data_ack = tti_tx_data_queue_rvalid;
      exec_tti_rx_data_data = tti_tx_data_queue_rdata;
      csr_tti_rx_data_queue_ack_o = '0;
      csr_tti_rx_data_queue_reg_rst_we_o = '0;
      csr_tti_rx_data_queue_reg_rst_data_o = '0;
      tti_rx_data_queue_req = '0;  // exec_tti_rx_data_req is connected to tti_tx_data_queue_req
      tti_rx_data_queue_reg_rst = exec_tti_rx_data_queue_clr;
    end else if (recovery_pending & exec_tti_rx_queue_sel) begin
      csr_tti_rx_data_queue_ack_o          = '0;
      csr_tti_rx_data_queue_reg_rst_we_o   = '0;
      csr_tti_rx_data_queue_reg_rst_data_o = '0;
      tti_rx_data_queue_req                = exec_tti_rx_data_req;
      tti_rx_data_queue_reg_rst            = exec_tti_rx_data_queue_clr;
      exec_tti_rx_data_ack                 = tti_rx_data_queue_ack;
      exec_tti_rx_data_data                = tti_rx_data_queue_data;
    end else begin
      csr_tti_rx_data_queue_ack_o          = tti_rx_data_queue_ack;
      csr_tti_rx_data_queue_reg_rst_we_o   = tti_rx_data_queue_reg_rst_we;
      csr_tti_rx_data_queue_reg_rst_data_o = tti_rx_data_queue_reg_rst_next;
      tti_rx_data_queue_req                = csr_tti_rx_data_queue_req_i;
      tti_rx_data_queue_reg_rst            = csr_tti_rx_data_queue_reg_rst_i;
      exec_tti_rx_data_ack                 = '0;
      exec_tti_rx_data_data                = tti_rx_data_queue_data;
    end

    // No need to mux data
    csr_tti_rx_data_queue_data_o = tti_rx_data_queue_data;
  end

  // Threshold
  assign tti_rx_data_queue_start_thld       = csr_tti_rx_data_queue_start_thld_i;
  assign tti_rx_data_queue_ready_thld_i     = csr_tti_rx_data_queue_ready_thld_i;
  assign csr_tti_rx_data_queue_ready_thld_o = tti_rx_data_queue_ready_thld_o;

  // ......................
  // TX data queue is always connected. The recovery logic does not use it
  logic exec_tti_tx_data_queue_clr;
  logic indirect_rx_full;

  assign csr_tti_tx_data_queue_full_o = bypass_i3c_core_i ? indirect_rx_full : tti_tx_data_queue_full;
  assign csr_tti_tx_data_queue_ack_o = tti_tx_data_queue_ack;
  assign csr_tti_tx_data_queue_reg_rst_we_o = tti_tx_data_queue_reg_rst_we;
  assign csr_tti_tx_data_queue_reg_rst_data_o = tti_tx_data_queue_reg_rst_next;
  assign tti_tx_data_queue_data = csr_tti_tx_data_queue_data_i;
  assign tti_tx_data_queue_req = csr_tti_tx_data_queue_req_i;
  assign tti_tx_data_queue_reg_rst = csr_tti_tx_data_queue_reg_rst_i | exec_tti_tx_data_queue_clr;

  // Threshold
  assign tti_tx_data_queue_start_thld = csr_tti_tx_data_queue_start_thld_i;
  assign tti_tx_data_queue_ready_thld_i = csr_tti_tx_data_queue_ready_thld_i;
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

  logic recv_cmd_is_rd;
  logic [7:0] recv_cmd_cmd;
  logic [15:0] recv_cmd_len;
  logic recv_cmd_error;

  // RX PEC calculator
  logic rx_pec_clear;
  logic rx_pec_valid;
  logic rx_pec_init;
  logic [7:0] rx_pec_data;

  logic [7:0] recv_pec_crc;
  logic recv_pec_enable;

  recovery_pec xrecovery_rx_pec (
      .clk_i,
      .rst_ni(rst_ni),
      .soft_reset_ni(!rx_pec_clear & recovery_enable & ~bypass_i3c_core_i),

      .dat_i  (rx_pec_data),
      .valid_i(rx_pec_valid | virtual_device_cec_shreg[0]),
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
      .rst_ni(rst_ni),
      .recovery_enable_i(recovery_enable),
      .bypass_i3c_core_i(bypass_i3c_core_i),

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

      .cmd_valid_o(recv_cmd_valid),
      .cmd_is_rd_o(recv_cmd_is_rd),
      .cmd_cmd_o  (recv_cmd_cmd),
      .cmd_len_o  (recv_cmd_len),
      .cmd_error_o(recv_cmd_error),
      .cmd_done_i (cmd_done),

      .virtual_device_tx_i(recovery_pending)
  );

  // ....................................................

  logic        xmit_res_ready;
  logic        xmit_res_dready;
  logic        exec_res_ready;
  logic        exec_res_dready;

  logic        res_valid;
  logic [15:0] res_len;

  logic        res_dvalid;
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
      .rst_ni(rst_ni),
      .soft_reset_ni(!tx_pec_clear & recovery_enable & ~bypass_i3c_core_i),

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
      .rst_ni(rst_ni),
      .soft_reset_ni(recovery_enable & ~bypass_i3c_core_i),

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
      .res_ready_o(xmit_res_ready),
      .res_len_i  (res_len),

      .res_dvalid_i(res_dvalid),
      .res_dready_o(xmit_res_dready),
      .res_data_i  (res_data),
      .res_dlast_i (res_dlast)
  );

  // ....................................................

  logic                          indirect_rx_wvalid;
  logic                          indirect_rx_wready;
  logic [TtiRxDataDataWidth-1:0] indirect_rx_wdata;

  logic                          indirect_rx_rreq;
  logic                          indirect_rx_rack;
  logic [      CsrDataWidth-1:0] indirect_rx_rdata;

  logic                          indirect_rx_clr;

  logic                          indirect_rx_empty;

  // Indirect FIFO (RX only)
  read_queue #(
      .Depth    (IndirectFifoDepth),
      .DataWidth(CsrDataWidth)
  ) xindirect_rx_fifo (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      // Write port
      .wvalid_i(indirect_rx_wvalid),
      .wready_o(indirect_rx_wready),
      .wdata_i (indirect_rx_wdata),

      // Read port
      .req_i (indirect_rx_rreq & allow_indirect_read),
      .ack_o (indirect_rx_rack),
      .data_o(indirect_rx_rdata),

      // Clear port
      .reg_rst_i     (indirect_rx_clr),
      .reg_rst_we_o  (),
      .reg_rst_data_o(),

      // Status
      .full_o (indirect_rx_full),
      .empty_o(indirect_rx_empty),

      // Threshold logic (unused)
      .start_thld_i     ('0),
      .ready_thld_i     ('0),
      .ready_thld_o     (),
      .start_thld_trig_o(),
      .ready_thld_trig_o(),
      .depth_o          ()
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin : indirect_fifo_access_permissions
    if (~rst_ni) begin
      allow_indirect_write <= '0;
      allow_indirect_read <= '0;
    end else begin
      if (bypass_i3c_core_i) begin
        if (indirect_rx_empty) begin
          allow_indirect_write <= 1'b1;
          allow_indirect_read <= 1'b0;
        end else if (indirect_rx_full | payload_available_o) begin
          allow_indirect_write <= 1'b0;
          allow_indirect_read <= 1'b1;
        end
      end else begin
        allow_indirect_write <= 1'b1;
        allow_indirect_read <= 1'b1;
      end
    end
  end

  // ....................................................

  logic exec_tti_rx_data_ready;

  logic exec_cmd_valid;
  logic exec_cmd_is_rd;
  logic [7:0] exec_cmd_cmd;
  logic [15:0] exec_cmd_len;
  logic exec_cmd_error;

  always_ff @(posedge clk_i or negedge rst_ni) begin : convert_req_to_ready
    if (~rst_ni) begin
      exec_tti_rx_data_ready <= '0;
    end else if (exec_tti_rx_data_req) begin
      exec_tti_rx_data_ready <= 1'b1;
    end else if (tti_tx_data_queue_rvalid) begin
      exec_tti_rx_data_ready <= 1'b0;
    end
  end

  always_comb begin : tti_tx_queue_converter_sink
    if (bypass_i3c_core_i) begin
      tti_tx_data_queue_rvalid_conv_sink = '0;
      tti_tx_data_queue_rready = exec_tti_rx_data_ready;
      tti_tx_data_queue_rdata_conv_sink = '0;
    end else begin
      tti_tx_data_queue_rvalid_conv_sink = tti_tx_data_queue_rvalid;
      tti_tx_data_queue_rready = tti_tx_data_queue_rready_conv_sink;
      tti_tx_data_queue_rdata_conv_sink = tti_tx_data_queue_rdata;
    end
  end

  always_comb begin : disconnect_executor_from_receiver
    if (bypass_i3c_core_i) begin
      exec_res_ready  = '0;
      exec_res_dready = '0;
    end else begin
      exec_res_ready  = xmit_res_ready;
      exec_res_dready = xmit_res_dready;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_cmd_for_bypass
    if (~rst_ni) begin
      exec_cmd_valid <= '0;
      exec_cmd_is_rd <= '0;
      exec_cmd_cmd   <= '0;
      exec_cmd_len   <= '0;
      exec_cmd_error <= '0;
    end else begin
      if (bypass_i3c_core_i) begin
        exec_cmd_valid <= 1'b1;
        exec_cmd_is_rd <= 1'b0;
        exec_cmd_cmd   <= 8'd47;  // CMD_INDIRECT_FIFO_DATA
        exec_cmd_len   <= 16'd256;  // Fixed 256 bytes per transaction specified by Caliptra SS Recovery Sequence
        exec_cmd_error <= '0;
      end else begin
        exec_cmd_valid <= recv_cmd_valid;
        exec_cmd_is_rd <= recv_cmd_is_rd;
        exec_cmd_cmd   <= recv_cmd_cmd;
        exec_cmd_len   <= recv_cmd_len;
        exec_cmd_error <= recv_cmd_error;
      end
    end
  end

  // Command executor
  recovery_executor #(
      .IndirectFifoDepth (IndirectFifoDepth),
      .TtiRxDataDataWidth(TtiRxDataDataWidth),
      .CsrDataWidth      (CsrDataWidth)
  ) xrecovery_executor (
      .clk_i,
      .rst_ni(rst_ni),
      .recovery_enable_i(recovery_enable),

      .cmd_valid_i(exec_cmd_valid),
      .cmd_is_rd_i(exec_cmd_is_rd),
      .cmd_cmd_i  (exec_cmd_cmd),
      .cmd_len_i  (exec_cmd_len),
      .cmd_error_i(exec_cmd_error),
      .cmd_done_o (cmd_done),

      .res_valid_o(res_valid),
      .res_ready_i(exec_res_ready),
      .res_len_o  (res_len),

      .res_dvalid_o(res_dvalid),
      .res_dready_i(exec_res_dready),
      .res_data_o  (res_data),
      .res_dlast_o (res_dlast),

      .rx_data_queue_clr_o(exec_tti_rx_data_queue_clr),
      .rx_desc_queue_clr_o(exec_tti_rx_desc_queue_clr),
      .tx_data_queue_clr_o(exec_tti_tx_data_queue_clr),
      .tx_desc_queue_clr_o(exec_tti_tx_desc_queue_clr),

      .tti_rx_rreq_o (exec_tti_rx_data_req),
      .tti_rx_rack_i (exec_tti_rx_data_ack),
      .tti_rx_rdata_i(exec_tti_rx_data_data),

      .tti_rx_sel_o(exec_tti_rx_queue_sel),

      .indirect_rx_wvalid_o(indirect_rx_wvalid),
      .indirect_rx_wready_i(indirect_rx_wready),
      .indirect_rx_wdata_o (indirect_rx_wdata),

      .indirect_rx_rreq_o (indirect_rx_rreq),
      .indirect_rx_rack_i (indirect_rx_rack),
      .indirect_rx_rdata_i(indirect_rx_rdata),

      .indirect_rx_full_i (indirect_rx_full),
      .indirect_rx_empty_i(indirect_rx_empty),
      .indirect_rx_clr_o  (indirect_rx_clr),

      .host_abort_i(ctl_tti_tx_host_nack_i | ctl_bus_stop_i),

      .bypass_i3c_core_i,

      .payload_available_o(payload_available_o),
      .image_activated_o  (image_activated_o),

      .hwif_socmgmt_i,
      .hwif_socmgmt_o,

      .hwif_rec_i(hwif_rec_i),
      .hwif_rec_o(hwif_rec_o),

      .recovery_mode_enabled_i(recovery_mode_enabled)
  );

endmodule
