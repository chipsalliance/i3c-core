// SPDX-License-Identifier: Apache-2.0
`ifdef CONTROLLER_SUPPORT
// I3C Host Controller Interface
module hci
  import i3c_pkg::*;
#(
    parameter int unsigned DatAw = 7,
    parameter int unsigned DctAw = 7,

    parameter int unsigned CsrDataWidth = 32,
    parameter int unsigned CsrAddrWidth = 12,

    parameter int unsigned HciRespFifoDepth = 64,
    parameter int unsigned HciCmdFifoDepth  = 64,
    parameter int unsigned HciRxFifoDepth   = 64,
    parameter int unsigned HciTxFifoDepth   = 64,
    parameter int unsigned HciIbiFifoDepth  = 64,

    localparam int unsigned HciRespFifoDepthWidth = $clog2(HciRespFifoDepth + 1),
    localparam int unsigned HciCmdFifoDepthWidth  = $clog2(HciCmdFifoDepth + 1),
    localparam int unsigned HciTxFifoDepthWidth   = $clog2(HciTxFifoDepth + 1),
    localparam int unsigned HciRxFifoDepthWidth   = $clog2(HciRxFifoDepth + 1),
    localparam int unsigned HciIbiFifoDepthWidth  = $clog2(HciIbiFifoDepth + 1),

    parameter int unsigned HciRespDataWidth = 32,
    parameter int unsigned HciCmdDataWidth  = 64,
    parameter int unsigned HciRxDataWidth   = 32,
    parameter int unsigned HciTxDataWidth   = 32,
    parameter int unsigned HciIbiDataWidth  = 32,

    parameter int unsigned HciRespThldWidth = 8,
    parameter int unsigned HciCmdThldWidth  = 8,
    parameter int unsigned HciRxThldWidth   = 3,
    parameter int unsigned HciTxThldWidth   = 3,
    parameter int unsigned HciIbiThldWidth  = 8
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

    // DAT <-> Controller interface
    input  logic             dat_read_valid_hw_i,
    input  logic [DatAw-1:0] dat_index_hw_i,
    output logic [     63:0] dat_rdata_hw_o,

    // DCT <-> Controller interface
    input  logic             dct_write_valid_hw_i,
    input  logic             dct_read_valid_hw_i,
    input  logic [DctAw-1:0] dct_index_hw_i,
    input  logic [    127:0] dct_wdata_hw_i,
    output logic [    127:0] dct_rdata_hw_o,

    // DAT memory export interface
    input  dat_mem_src_t  dat_mem_src_i,
    output dat_mem_sink_t dat_mem_sink_o,

    // DCT memory export interface
    input  dct_mem_src_t  dct_mem_src_i,
    output dct_mem_sink_t dct_mem_sink_o,

    // Response queue
    output logic hci_resp_full_o,
    output logic [HciRespFifoDepthWidth-1:0] hci_resp_depth_o,
    output logic [HciRespThldWidth-1:0] hci_resp_ready_thld_o,
    output logic hci_resp_ready_thld_trig_o,
    output logic hci_resp_empty_o,
    input logic hci_resp_wvalid_i,
    output logic hci_resp_wready_o,
    input logic [CsrDataWidth-1:0] hci_resp_wdata_i,

    // Command queue
    output logic hci_cmd_full_o,
    output logic [HciCmdFifoDepthWidth-1:0] hci_cmd_depth_o,
    output logic [HciCmdThldWidth-1:0] hci_cmd_ready_thld_o,
    output logic hci_cmd_ready_thld_trig_o,
    output logic hci_cmd_empty_o,
    output logic hci_cmd_rvalid_o,
    input logic hci_cmd_rready_i,
    output logic [HciCmdDataWidth-1:0] hci_cmd_rdata_o,

    // RX queue
    output logic hci_rx_full_o,
    output logic [HciRxFifoDepthWidth-1:0] hci_rx_depth_o,
    output logic [HciRxThldWidth-1:0] hci_rx_start_thld_o,
    output logic [HciRxThldWidth-1:0] hci_rx_ready_thld_o,
    output logic hci_rx_start_thld_trig_o,
    output logic hci_rx_ready_thld_trig_o,
    output logic hci_rx_empty_o,
    input logic hci_rx_wvalid_i,
    output logic hci_rx_wready_o,
    input logic [CsrDataWidth-1:0] hci_rx_wdata_i,

    // TX queue
    output logic hci_tx_full_o,
    output logic [HciTxFifoDepthWidth-1:0] hci_tx_depth_o,
    output logic [HciTxThldWidth-1:0] hci_tx_start_thld_o,
    output logic [HciTxThldWidth-1:0] hci_tx_ready_thld_o,
    output logic hci_tx_start_thld_trig_o,
    output logic hci_tx_ready_thld_trig_o,
    output logic hci_tx_empty_o,
    output logic hci_tx_rvalid_o,
    input logic hci_tx_rready_i,
    output logic [HciTxDataWidth-1:0] hci_tx_rdata_o,

    // In-band Interrupt queue
    output logic hci_ibi_full_o,
    output logic [HciIbiFifoDepthWidth-1:0] hci_ibi_depth_o,
    output logic [HciIbiThldWidth-1:0] hci_ibi_ready_thld_o,
    output logic hci_ibi_ready_thld_trig_o,
    output logic hci_ibi_empty_o,
    input logic hci_ibi_wvalid_i,
    output logic hci_ibi_wready_o,
    input logic [HciIbiDataWidth-1:0] hci_ibi_wdata_i,

    // PIO CONTROL CSR interface
    input  I3CCSR_pkg::I3CCSR__PIOControl__out_t hwif_pio_control_i,
    output I3CCSR_pkg::I3CCSR__PIOControl__in_t  hwif_pio_control_o,

    // I3C BASE CSR interface
    input  I3CCSR_pkg::I3CCSR__I3CBase__out_t hwif_base_i,
    output I3CCSR_pkg::I3CCSR__I3CBase__in_t  hwif_base_o,

    // DAT CSR interface
    input  I3CCSR_pkg::I3CCSR__DAT__out_t dat_i,
    output I3CCSR_pkg::I3CCSR__DAT__in_t  dat_o,

    // DCT CSR interface
    input  I3CCSR_pkg::I3CCSR__DCT__out_t dct_i,
    output I3CCSR_pkg::I3CCSR__DCT__in_t  dct_o,

    input logic [6:0] set_dasa_i,
    input logic       set_dasa_valid_i,
    input logic       set_dasa_virtual_device_i,
    input logic       rstdaa_i,
    input logic [6:0] newda_i,
    input logic       set_newda_i,
    input logic       set_newda_virtual_device_i,

    input logic [7:0] rst_action_i,
    input logic rst_action_valid_i
);

  // Reset control
  logic cmd_reset_ctrl_we;
  logic cmd_reset_ctrl_next;

  logic rx_reset_ctrl_we;
  logic rx_reset_ctrl_next;

  logic tx_reset_ctrl_we;
  logic tx_reset_ctrl_next;

  logic resp_reset_ctrl_we;
  logic resp_reset_ctrl_next;

  // HCI queues' threshold
  logic [HciCmdThldWidth-1:0] cmd_ready_thld;
  logic [HciRxThldWidth-1:0] rx_ready_thld;
  logic [HciTxThldWidth-1:0] tx_ready_thld;
  logic [HciRespThldWidth-1:0] resp_ready_thld;

  // HCI queue port control
  logic cmd_req;  // Read DWORD from the COMMAND_PORT request
  logic cmd_wr_ack;  // Feedback to the COMMAND_PORT; command has been fetched
  logic [CsrDataWidth-1:0] cmd_wr_data;  // DWORD collected from the COMMAND_PORT

  logic xfer_req;  // RX / TX data write / read request
  logic xfer_req_is_wr;  // TX iff true, otherwise RX

  logic rx_req;  // Write RX data to the RX_PORT request
  logic rx_rd_ack;  // RX_DATA_PORT drives valid RX data
  logic [HciRxDataWidth-1:0] rx_rd_data;  // RX data read from the rx_fifo to be put to RX port

  logic tx_req;  // Read TX data from the TX_PORT request
  logic tx_wr_ack;  // Feedback to the TX_DATA_PORT; data has been read from TX port
  logic [CsrDataWidth-1:0] tx_wr_data;  // TX data to be put in tx_fifo

  logic resp_req;  // Write response to the RESPONSE_PORT request
  logic resp_rd_ack;  // resp_req is fulfilled; RESPONSE_PORT drives valid data
  logic [HciRespDataWidth-1:0] resp_rd_data;  // Response read from resp_fifo
                                              // placed in RESPONSE_PORT

  logic cmdrst, txrst, resprst, rxrst;

  logic cmd_ready_thld_swmod_q, cmd_ready_thld_we;
  logic resp_ready_thld_swmod_q, resp_ready_thld_we;

  always_ff @(posedge clk_i or negedge rst_ni) begin : blockName
    if (!rst_ni) begin
      cmd_ready_thld_we <= '0;
      resp_ready_thld_we <= '0;
      cmd_ready_thld_swmod_q <= '0;
      resp_ready_thld_swmod_q <= '0;
    end else begin
      cmd_ready_thld_swmod_q <= hwif_pio_control_i.QUEUE_THLD_CTRL.CMD_EMPTY_BUF_THLD.swmod;
      cmd_ready_thld_we <= cmd_ready_thld_swmod_q;
      resp_ready_thld_swmod_q <= hwif_pio_control_i.QUEUE_THLD_CTRL.RESP_BUF_THLD.swmod;
      resp_ready_thld_we <= resp_ready_thld_swmod_q;
    end
  end

  always_comb begin : wire_hwif
    // Reset control
    cmdrst = hwif_base_i.RESET_CONTROL.CMD_QUEUE_RST.value;
    rxrst = hwif_base_i.RESET_CONTROL.RX_FIFO_RST.value;
    txrst = hwif_base_i.RESET_CONTROL.TX_FIFO_RST.value;
    resprst = hwif_base_i.RESET_CONTROL.RESP_QUEUE_RST.value;

    hwif_base_o.RESET_CONTROL.CMD_QUEUE_RST.we = cmd_reset_ctrl_we;
    hwif_base_o.RESET_CONTROL.CMD_QUEUE_RST.next = cmd_reset_ctrl_next;

    hwif_base_o.RESET_CONTROL.RX_FIFO_RST.we = rx_reset_ctrl_we;
    hwif_base_o.RESET_CONTROL.RX_FIFO_RST.next = rx_reset_ctrl_next;

    hwif_base_o.RESET_CONTROL.TX_FIFO_RST.we = tx_reset_ctrl_we;
    hwif_base_o.RESET_CONTROL.TX_FIFO_RST.next = tx_reset_ctrl_next;

    hwif_base_o.RESET_CONTROL.RESP_QUEUE_RST.we = resp_reset_ctrl_we;
    hwif_base_o.RESET_CONTROL.RESP_QUEUE_RST.next = resp_reset_ctrl_next;

    // Threshold
    hwif_pio_control_o.QUEUE_THLD_CTRL.CMD_EMPTY_BUF_THLD.we = cmd_ready_thld_we;
    hwif_pio_control_o.QUEUE_THLD_CTRL.RESP_BUF_THLD.we = resp_ready_thld_we;
    hwif_pio_control_o.QUEUE_THLD_CTRL.CMD_EMPTY_BUF_THLD.next = hci_cmd_ready_thld_o;
    hwif_pio_control_o.QUEUE_THLD_CTRL.RESP_BUF_THLD.next = hci_resp_ready_thld_o;
    cmd_ready_thld = hwif_pio_control_i.QUEUE_THLD_CTRL.CMD_EMPTY_BUF_THLD.value;
    hci_rx_start_thld_o = hwif_pio_control_i.DATA_BUFFER_THLD_CTRL.RX_START_THLD.value;
    rx_ready_thld = hwif_pio_control_i.DATA_BUFFER_THLD_CTRL.RX_BUF_THLD.value;
    hci_tx_start_thld_o = hwif_pio_control_i.DATA_BUFFER_THLD_CTRL.TX_START_THLD.value;
    tx_ready_thld = hwif_pio_control_i.DATA_BUFFER_THLD_CTRL.TX_BUF_THLD.value;
    resp_ready_thld = hwif_pio_control_i.QUEUE_THLD_CTRL.RESP_BUF_THLD.value;

    // HCI queue port handling

    // HCI PIOControl ports requests
    xfer_req = hwif_pio_control_i.RX_DATA_PORT.req | hwif_pio_control_i.TX_DATA_PORT.req;
    xfer_req_is_wr = hwif_pio_control_i.RX_DATA_PORT.req_is_wr
      | hwif_pio_control_i.TX_DATA_PORT.req_is_wr;

    cmd_req = hwif_pio_control_i.COMMAND_PORT.req & hwif_pio_control_i.COMMAND_PORT.req_is_wr;
    rx_req = xfer_req && !xfer_req_is_wr;
    tx_req = xfer_req && xfer_req_is_wr;
    resp_req = hwif_pio_control_i.RESPONSE_PORT.req;

    // Reading commands from the command port
    hwif_pio_control_o.COMMAND_PORT.wr_ack = cmd_wr_ack;
    cmd_wr_data = hwif_pio_control_i.COMMAND_PORT.wr_data;

    // Writing data to the rx port
    hwif_pio_control_o.RX_DATA_PORT.rd_ack = rx_rd_ack;
    hwif_pio_control_o.RX_DATA_PORT.rd_data = rx_rd_data;

    // Reading data from the tx port
    hwif_pio_control_o.TX_DATA_PORT.wr_ack = tx_wr_ack;
    tx_wr_data = hwif_pio_control_i.TX_DATA_PORT.wr_data;

    // Writing response to the resp port
    hwif_pio_control_o.RESPONSE_PORT.rd_ack = resp_rd_ack;
    hwif_pio_control_o.RESPONSE_PORT.rd_data = resp_rd_data;
  end : wire_hwif

  dxt #(
      .DatAw(DatAw),
      .DctAw(DctAw)
  ) dxt (
      .clk_i,  // clock
      .rst_ni,  // active low reset

      .dat_read_valid_hw_i,
      .dat_index_hw_i,
      .dat_rdata_hw_o,

      .dct_write_valid_hw_i,
      .dct_read_valid_hw_i,
      .dct_index_hw_i,
      .dct_wdata_hw_i,
      .dct_rdata_hw_o,

      .csr_dat_hwif_i(dat_i),
      .csr_dat_hwif_o(dat_o),

      .csr_dct_hwif_i(dct_i),
      .csr_dct_hwif_o(dct_o),

      .dat_mem_src_i,
      .dat_mem_sink_o,

      .dct_mem_src_i,
      .dct_mem_sink_o
  );

  logic unused_rx_desc_start_thld_trig, unused_tx_desc_start_thld_trig;

  queues #(
      .TxDescFifoDepth(HciCmdFifoDepth),
      .RxDescFifoDepth(HciRespFifoDepth),
      .TxFifoDepth(HciTxFifoDepth),
      .RxFifoDepth(HciRxFifoDepth),

      .TxDescFifoDataWidth(HciCmdDataWidth),
      .RxDescFifoDataWidth(HciRespDataWidth),
      .TxFifoDataWidth(HciTxDataWidth),
      .RxFifoDataWidth(HciRxDataWidth),

      .TxDescFifoThldWidth(HciCmdThldWidth),
      .RxDescFifoThldWidth(HciRespThldWidth),
      .TxFifoThldWidth(HciTxThldWidth),
      .RxFifoThldWidth(HciRxThldWidth)
  ) hci_queues (
      .clk_i,
      .rst_ni,

      .rx_desc_full_o(hci_resp_full_o),
      .rx_desc_depth_o(hci_resp_depth_o),
      .rx_desc_start_thld_trig_o(unused_rx_desc_start_thld_trig),  // Intentionally left hanging, unsupported by Response Queue
      .rx_desc_ready_thld_trig_o(hci_resp_ready_thld_trig_o),
      .rx_desc_empty_o(hci_resp_empty_o),
      .rx_desc_wvalid_i(hci_resp_wvalid_i),
      .rx_desc_wready_o(hci_resp_wready_o),
      .rx_desc_wdata_i(hci_resp_wdata_i),
      .rx_desc_req_i(resp_req),
      .rx_desc_ack_o(resp_rd_ack),
      .rx_desc_data_o(resp_rd_data),
      .rx_desc_start_thld_i('0),
      .rx_desc_ready_thld_i(resp_ready_thld),
      .rx_desc_ready_thld_o(hci_resp_ready_thld_o),
      .rx_desc_reg_rst_i(resprst),
      .rx_desc_reg_rst_we_o(resp_reset_ctrl_we),
      .rx_desc_reg_rst_data_o(resp_reset_ctrl_next),

      .tx_desc_full_o(hci_cmd_full_o),
      .tx_desc_depth_o(hci_cmd_depth_o),
      .tx_desc_start_thld_trig_o(unused_tx_desc_start_thld_trig),  // Intentionally left hanging, unsupported by Command Queue
      .tx_desc_ready_thld_trig_o(hci_cmd_ready_thld_trig_o),
      .tx_desc_empty_o(hci_cmd_empty_o),
      .tx_desc_rvalid_o(hci_cmd_rvalid_o),
      .tx_desc_rready_i(hci_cmd_rready_i),
      .tx_desc_rdata_o(hci_cmd_rdata_o),
      .tx_desc_req_i(cmd_req),
      .tx_desc_ack_o(cmd_wr_ack),
      .tx_desc_data_i(cmd_wr_data),
      .tx_desc_start_thld_i('0),
      .tx_desc_ready_thld_i(cmd_ready_thld),
      .tx_desc_ready_thld_o(hci_cmd_ready_thld_o),
      .tx_desc_reg_rst_i(cmdrst),
      .tx_desc_reg_rst_we_o(cmd_reset_ctrl_we),
      .tx_desc_reg_rst_data_o(cmd_reset_ctrl_next),

      .rx_full_o(hci_rx_full_o),
      .rx_depth_o(hci_rx_depth_o),
      .rx_start_thld_trig_o(hci_rx_start_thld_trig_o),
      .rx_ready_thld_trig_o(hci_rx_ready_thld_trig_o),
      .rx_empty_o(hci_rx_empty_o),
      .rx_wvalid_i(hci_rx_wvalid_i),
      .rx_wready_o(hci_rx_wready_o),
      .rx_wdata_i(hci_rx_wdata_i),
      .rx_req_i(rx_req),
      .rx_ack_o(rx_rd_ack),
      .rx_data_o(rx_rd_data),
      .rx_start_thld_i(hci_rx_start_thld_o),
      .rx_ready_thld_i(rx_ready_thld),
      .rx_ready_thld_o(hci_rx_ready_thld_o),
      .rx_reg_rst_i(rxrst),
      .rx_reg_rst_we_o(rx_reset_ctrl_we),
      .rx_reg_rst_data_o(rx_reset_ctrl_next),

      .tx_full_o(hci_tx_full_o),
      .tx_depth_o(hci_tx_depth_o),
      .tx_start_thld_trig_o(hci_tx_start_thld_trig_o),
      .tx_ready_thld_trig_o(hci_tx_ready_thld_trig_o),
      .tx_empty_o(hci_tx_empty_o),
      .tx_rvalid_o(hci_tx_rvalid_o),
      .tx_rready_i(hci_tx_rready_i),
      .tx_rdata_o(hci_tx_rdata_o),
      .tx_req_i(tx_req),
      .tx_ack_o(tx_wr_ack),
      .tx_data_i(tx_wr_data),
      .tx_start_thld_i(hci_tx_start_thld_o),
      .tx_ready_thld_i(tx_ready_thld),
      .tx_ready_thld_o(hci_tx_ready_thld_o),
      .tx_reg_rst_i(txrst),
      .tx_reg_rst_we_o(tx_reset_ctrl_we),
      .tx_reg_rst_data_o(tx_reset_ctrl_next)
  );

  // In-band Interrupt queue
  logic hci_ibi_rst;
  logic hci_ibi_rst_we;
  logic hci_ibi_rst_next;
  logic hci_ibi_req;
  logic hci_ibi_rd_ack;
  logic unused_ibi_queue_start_thld_trig;
  logic [HciIbiThldWidth-1:0] hci_ibi_thld;
  logic [HciIbiDataWidth-1:0] hci_ibi_rd_data;

  always_comb begin
    hci_ibi_rst = hwif_base_i.RESET_CONTROL.IBI_QUEUE_RST.value;
    hwif_base_o.RESET_CONTROL.IBI_QUEUE_RST.we = hci_ibi_rst_we;
    hwif_base_o.RESET_CONTROL.IBI_QUEUE_RST.next = hci_ibi_rst_next;

    hci_ibi_thld = hwif_pio_control_i.QUEUE_THLD_CTRL.IBI_STATUS_THLD.value;

    hci_ibi_req = hwif_pio_control_i.IBI_PORT.req;
    hwif_pio_control_o.IBI_PORT.rd_ack = hci_ibi_rd_ack;
    hwif_pio_control_o.IBI_PORT.rd_data = hci_ibi_rd_data;
  end

  read_queue #(
      .Depth(HciIbiFifoDepth),
      .DataWidth(HciIbiDataWidth),
      .ThldWidth(HciIbiThldWidth),
      .LimitReadyThld(0),
      .ThldIsPow(0)
  ) hci_ibi_queue (
      .clk_i,
      .rst_ni,

      .full_o(hci_ibi_full_o),
      .depth_o(hci_ibi_depth_o),
      .start_thld_trig_o(unused_ibi_queue_start_thld_trig),
      .ready_thld_trig_o(hci_ibi_ready_thld_trig_o),
      .empty_o(hci_ibi_empty_o),
      .wvalid_i(hci_ibi_wvalid_i),
      .wready_o(hci_ibi_wready_o),
      .wdata_i(hci_ibi_wdata_i),

      .req_i (hci_ibi_req),
      .ack_o (hci_ibi_rd_ack),
      .data_o(hci_ibi_rd_data),

      .start_thld_i('0),
      .ready_thld_i(hci_ibi_thld),
      .ready_thld_o(hci_ibi_ready_thld_o),

      .reg_rst_i(hci_ibi_rst),
      .reg_rst_we_o(hci_ibi_rst_we),
      .reg_rst_data_o(hci_ibi_rst_next)
  );

  always_comb begin : wire_unconnected_regs
    hwif_base_o.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR_VALID.we = '0;
    hwif_base_o.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR.we = '0;
    hwif_base_o.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR_VALID.next = '0;
    hwif_base_o.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR.next = '0;
    hwif_base_o.HC_CONTROL.RESUME.we = '0;
    hwif_base_o.HC_CONTROL.RESUME.next = '0;
    hwif_base_o.HC_CONTROL.BUS_ENABLE.we = '0;
    hwif_base_o.HC_CONTROL.BUS_ENABLE.next = '0;
    hwif_base_o.RESET_CONTROL.SOFT_RST.we = '0;
    hwif_base_o.RESET_CONTROL.SOFT_RST.next = '0;
    hwif_base_o.PRESENT_STATE.AC_CURRENT_OWN.next = '0;
    hwif_base_o.INTR_STATUS.HC_INTERNAL_ERR_STAT.next = '0;
    hwif_base_o.INTR_STATUS.HC_SEQ_CANCEL_STAT.next = '0;
    hwif_base_o.INTR_STATUS.HC_WARN_CMD_SEQ_STALL_STAT.next = '0;
    hwif_base_o.INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT.next = '0;
    hwif_base_o.INTR_STATUS.SCHED_CMD_MISSED_TICK_STAT.next = '0;
    hwif_base_o.DCT_SECTION_OFFSET.TABLE_INDEX.we = '0;
    hwif_base_o.DCT_SECTION_OFFSET.TABLE_INDEX.next = '0;
    hwif_base_o.IBI_DATA_ABORT_CTRL.IBI_DATA_ABORT_MON.we = '0;
    hwif_base_o.IBI_DATA_ABORT_CTRL.IBI_DATA_ABORT_MON.next = '0;

    hwif_pio_control_o.PIO_INTR_STATUS.TX_THLD_STAT.next = '0;
    hwif_pio_control_o.PIO_INTR_STATUS.RX_THLD_STAT.next = '0;
    hwif_pio_control_o.PIO_INTR_STATUS.IBI_STATUS_THLD_STAT.next = '0;
    hwif_pio_control_o.PIO_INTR_STATUS.CMD_QUEUE_READY_STAT.next = '0;
    hwif_pio_control_o.PIO_INTR_STATUS.RESP_READY_STAT.next = '0;
    hwif_pio_control_o.PIO_INTR_STATUS.TRANSFER_ABORT_STAT.next = '0;
    hwif_pio_control_o.PIO_INTR_STATUS.TRANSFER_ERR_STAT.next = '0;
  end

endmodule : hci
`endif // CONTROLLER_SUPPORT
