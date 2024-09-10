// SPDX-License-Identifier: Apache-2.0

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

    parameter int unsigned HciRespDataWidth = 32,
    parameter int unsigned HciCmdDataWidth  = 64,
    parameter int unsigned HciRxDataWidth   = 32,
    parameter int unsigned HciTxDataWidth   = 32,
    parameter int unsigned HciIbiDataWidth  = 32,

    parameter int unsigned HciRespThldWidth = 8,
    parameter int unsigned HciCmdThldWidth  = 8,
    parameter int unsigned HciRxThldWidth   = 3,
    parameter int unsigned HciTxThldWidth   = 3,
    parameter int unsigned HciIbiThldWidth  = 8,

    parameter int unsigned TtiRespFifoDepth = 64,
    parameter int unsigned TtiCmdFifoDepth  = 64,
    parameter int unsigned TtiRxFifoDepth   = 64,
    parameter int unsigned TtiTxFifoDepth   = 64,
    parameter int unsigned TtiIbiFifoDepth  = 64,

    parameter int unsigned TtiRxDescDataWidth = 32,
    parameter int unsigned TtiTxDescDataWidth = 32,
    parameter int unsigned TtiRxDataWidth = 32,
    parameter int unsigned TtiTxDataWidth = 32,
    parameter int unsigned TtiIbiDataWidth = 32,

    parameter int unsigned TtiRxDescThldWidth = 8,
    parameter int unsigned TtiTxDescThldWidth = 8,
    parameter int unsigned TtiRxThldWidth = 3,
    parameter int unsigned TtiTxThldWidth = 3,
    parameter int unsigned TtiIbiThldWidth = 8
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

    // I3C SW CSR access interface
    input  logic                    s_cpuif_req,
    input  logic                    s_cpuif_req_is_wr,
    input  logic [CsrAddrWidth-1:0] s_cpuif_addr,
    input  logic [CsrDataWidth-1:0] s_cpuif_wr_data,
    input  logic [CsrDataWidth-1:0] s_cpuif_wr_biten,
    output logic                    s_cpuif_req_stall_wr,
    output logic                    s_cpuif_req_stall_rd,
    output logic                    s_cpuif_rd_ack,
    output logic                    s_cpuif_rd_err,
    output logic [CsrDataWidth-1:0] s_cpuif_rd_data,
    output logic                    s_cpuif_wr_ack,
    output logic                    s_cpuif_wr_err,

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
    output logic [HciRespThldWidth-1:0] hci_resp_ready_thld_o,
    output logic hci_resp_ready_thld_trig_o,
    output logic hci_resp_empty_o,
    input logic hci_resp_wvalid_i,
    output logic hci_resp_wready_o,
    input logic [CsrDataWidth-1:0] hci_resp_wdata_i,

    // Command queue
    output logic hci_cmd_full_o,
    output logic [HciCmdThldWidth-1:0] hci_cmd_ready_thld_o,
    output logic hci_cmd_ready_thld_trig_o,
    output logic hci_cmd_empty_o,
    output logic hci_cmd_rvalid_o,
    input logic hci_cmd_rready_i,
    output logic [HciCmdDataWidth-1:0] hci_cmd_rdata_o,

    // RX queue
    output logic hci_rx_full_o,
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
    output logic [HciTxThldWidth-1:0] hci_tx_start_thld_o,
    output logic [HciTxThldWidth-1:0] hci_tx_ready_thld_o,
    output logic hci_tx_start_thld_trig_o,
    output logic hci_tx_ready_thld_trig_o,
    output logic hci_tx_empty_o,
    output logic hci_tx_rvalid_o,
    input logic hci_tx_rready_i,
    output logic [HciTxDataWidth-1:0] hci_tx_rdata_o,

    // In-band Interrupt queue
    output logic hci_ibi_queue_full_o,
    output logic [HciIbiThldWidth-1:0] hci_ibi_queue_ready_thld_o,
    output logic hci_ibi_queue_ready_thld_trig_o,
    output logic hci_ibi_queue_empty_o,
    input logic hci_ibi_queue_wvalid_i,
    output logic hci_ibi_queue_wready_o,
    input logic [HciIbiDataWidth-1:0] hci_ibi_queue_wdata_i,

    // Target Transaction Interface
    // RX descriptors queue
    output logic tti_rx_desc_queue_full_o,
    output logic [TtiRxDescThldWidth-1:0] tti_rx_desc_queue_ready_thld_o,
    output logic tti_rx_desc_queue_ready_thld_trig_o,
    output logic tti_rx_desc_queue_empty_o,
    input logic tti_rx_desc_queue_wvalid_i,
    output logic tti_rx_desc_queue_wready_o,
    input logic [CsrDataWidth-1:0] tti_rx_desc_queue_wdata_i,

    // TX descriptors queue
    output logic tti_tx_desc_queue_full_o,
    output logic [TtiTxDescThldWidth-1:0] tti_tx_desc_queue_ready_thld_o,
    output logic tti_tx_desc_queue_ready_thld_trig_o,
    output logic tti_tx_desc_queue_empty_o,
    output logic tti_tx_desc_queue_rvalid_o,
    input logic tti_tx_desc_queue_rready_i,
    output logic [TtiTxDescDataWidth-1:0] tti_tx_desc_queue_rdata_o,

    // RX queue
    output logic tti_rx_queue_full_o,
    output logic [TtiRxThldWidth-1:0] tti_rx_queue_start_thld_o,
    output logic [TtiRxThldWidth-1:0] tti_rx_queue_ready_thld_o,
    output logic tti_rx_queue_start_thld_trig_o,
    output logic tti_rx_queue_ready_thld_trig_o,
    output logic tti_rx_queue_empty_o,
    input logic tti_rx_queue_wvalid_i,
    output logic tti_rx_queue_wready_o,
    input logic [CsrDataWidth-1:0] tti_rx_queue_wdata_i,

    // TX queue
    output logic tti_tx_queue_full_o,
    output logic [TtiTxThldWidth-1:0] tti_tx_queue_start_thld_o,
    output logic [TtiTxThldWidth-1:0] tti_tx_queue_ready_thld_o,
    output logic tti_tx_queue_start_thld_trig_o,
    output logic tti_tx_queue_ready_thld_trig_o,
    output logic tti_tx_queue_empty_o,
    output logic tti_tx_queue_rvalid_o,
    input logic tti_tx_queue_rready_i,
    output logic [TtiTxDataWidth-1:0] tti_tx_queue_rdata_o,

    // In-band Interrupt queue
    output logic tti_ibi_queue_full_o,
    output logic [TtiIbiThldWidth-1:0] tti_ibi_queue_ready_thld_o,
    output logic tti_ibi_queue_ready_thld_trig_o,
    input logic [TtiIbiDataWidth-1:0] tti_ibi_queue_wr_data_i,
    output logic tti_ibi_queue_empty_o,
    output logic tti_ibi_queue_rvalid_o,
    input logic tti_ibi_queue_rready_i,
    output logic [TtiIbiDataWidth-1:0] tti_ibi_queue_rdata_o,

    // Controller configuration
    output logic phy_en_o,
    output logic [1:0] phy_mux_select_o,
    output logic i2c_active_en_o,
    output logic i2c_standby_en_o,
    output logic i3c_active_en_o,
    output logic i3c_standby_en_o,
    output logic [19:0] t_su_dat_o,
    output logic [19:0] t_hd_dat_o,
    output logic [19:0] t_r_o,
    output logic [19:0] t_bus_free_o,
    output logic [19:0] t_bus_idle_o,
    output logic [19:0] t_bus_available_o
);
  I3CCSR_pkg::I3CCSR__in_t  hwif_in;
  I3CCSR_pkg::I3CCSR__out_t hwif_out;

  // Propagate reset to CSRs
  assign hwif_in.rst_ni = rst_ni;

  // DAT CSR interface
  I3CCSR_pkg::I3CCSR__DAT__out_t dat_o;
  I3CCSR_pkg::I3CCSR__DAT__in_t dat_i;

  // DCT CSR interface
  I3CCSR_pkg::I3CCSR__DCT__out_t dct_o;
  I3CCSR_pkg::I3CCSR__DCT__in_t dct_i;

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
      cmd_ready_thld_we  <= '0;
      resp_ready_thld_we <= '0;
    end else begin
      cmd_ready_thld_swmod_q <= hwif_out.PIOControl.QUEUE_THLD_CTRL.CMD_EMPTY_BUF_THLD.swmod;
      cmd_ready_thld_we <= cmd_ready_thld_swmod_q;
      resp_ready_thld_swmod_q <= hwif_out.PIOControl.QUEUE_THLD_CTRL.RESP_BUF_THLD.swmod;
      resp_ready_thld_we <= resp_ready_thld_swmod_q;
    end
  end

  always_comb begin : wire_hwif
    // Reset control
    cmdrst = hwif_out.I3CBase.RESET_CONTROL.CMD_QUEUE_RST.value;
    rxrst = hwif_out.I3CBase.RESET_CONTROL.RX_FIFO_RST.value;
    txrst = hwif_out.I3CBase.RESET_CONTROL.TX_FIFO_RST.value;
    resprst = hwif_out.I3CBase.RESET_CONTROL.RESP_QUEUE_RST.value;

    hwif_in.I3CBase.RESET_CONTROL.CMD_QUEUE_RST.we = cmd_reset_ctrl_we;
    hwif_in.I3CBase.RESET_CONTROL.CMD_QUEUE_RST.next = cmd_reset_ctrl_next;

    hwif_in.I3CBase.RESET_CONTROL.RX_FIFO_RST.we = rx_reset_ctrl_we;
    hwif_in.I3CBase.RESET_CONTROL.RX_FIFO_RST.next = rx_reset_ctrl_next;

    hwif_in.I3CBase.RESET_CONTROL.TX_FIFO_RST.we = tx_reset_ctrl_we;
    hwif_in.I3CBase.RESET_CONTROL.TX_FIFO_RST.next = tx_reset_ctrl_next;

    hwif_in.I3CBase.RESET_CONTROL.RESP_QUEUE_RST.we = resp_reset_ctrl_we;
    hwif_in.I3CBase.RESET_CONTROL.RESP_QUEUE_RST.next = resp_reset_ctrl_next;

    // Threshold
    hwif_in.PIOControl.QUEUE_THLD_CTRL.CMD_EMPTY_BUF_THLD.we = cmd_ready_thld_we;
    hwif_in.PIOControl.QUEUE_THLD_CTRL.RESP_BUF_THLD.we = resp_ready_thld_we;
    hwif_in.PIOControl.QUEUE_THLD_CTRL.CMD_EMPTY_BUF_THLD.next = hci_cmd_ready_thld_o;
    hwif_in.PIOControl.QUEUE_THLD_CTRL.RESP_BUF_THLD.next = hci_resp_ready_thld_o;
    cmd_ready_thld = hwif_out.PIOControl.QUEUE_THLD_CTRL.CMD_EMPTY_BUF_THLD.value;
    hci_rx_start_thld_o = hwif_out.PIOControl.DATA_BUFFER_THLD_CTRL.RX_START_THLD.value;
    rx_ready_thld = hwif_out.PIOControl.DATA_BUFFER_THLD_CTRL.RX_BUF_THLD.value;
    hci_tx_start_thld_o = hwif_out.PIOControl.DATA_BUFFER_THLD_CTRL.TX_START_THLD.value;
    tx_ready_thld = hwif_out.PIOControl.DATA_BUFFER_THLD_CTRL.TX_BUF_THLD.value;
    resp_ready_thld = hwif_out.PIOControl.QUEUE_THLD_CTRL.RESP_BUF_THLD.value;

    // HCI queue port handling

    // HCI PIOControl ports requests
    xfer_req = hwif_out.PIOControl.RX_DATA_PORT.req | hwif_out.PIOControl.TX_DATA_PORT.req;
    xfer_req_is_wr = hwif_out.PIOControl.RX_DATA_PORT.req_is_wr
      | hwif_out.PIOControl.TX_DATA_PORT.req_is_wr;

    cmd_req = hwif_out.PIOControl.COMMAND_PORT.req & hwif_out.PIOControl.COMMAND_PORT.req_is_wr;
    rx_req = xfer_req && !xfer_req_is_wr;
    tx_req = xfer_req && xfer_req_is_wr;
    resp_req = hwif_out.PIOControl.RESPONSE_PORT.req;

    // Reading commands from the command port
    hwif_in.PIOControl.COMMAND_PORT.wr_ack = cmd_wr_ack;
    cmd_wr_data = hwif_out.PIOControl.COMMAND_PORT.wr_data;

    // Writing data to the rx port
    hwif_in.PIOControl.RX_DATA_PORT.rd_ack = rx_rd_ack;
    hwif_in.PIOControl.RX_DATA_PORT.rd_data = rx_rd_data;

    // Reading data from the tx port
    hwif_in.PIOControl.TX_DATA_PORT.wr_ack = tx_wr_ack;
    tx_wr_data = hwif_out.PIOControl.TX_DATA_PORT.wr_data;

    // Writing response to the resp port
    hwif_in.PIOControl.RESPONSE_PORT.rd_ack = resp_rd_ack;
    hwif_in.PIOControl.RESPONSE_PORT.rd_data = resp_rd_data;

    // DXT
    hwif_in.DAT = dat_i;
    hwif_in.DCT = dct_i;
    dat_o = hwif_out.DAT;
    dct_o = hwif_out.DCT;

  end : wire_hwif

  // TTI
  logic tti_rx_desc_queue_rd_ack;
  logic [TtiRxDataWidth-1:0] tti_rx_desc_queue_rd_data;
  logic tti_tx_desc_queue_wr_ack;
  logic tti_rx_queue_rd_ack;
  logic [TtiRxDataWidth-1:0] tti_rx_queue_rd_data;
  logic tti_tx_queue_wr_ack;
  logic tti_ibi_queue_wr_ack;

  always_comb begin : wire_hwif_tti
    hwif_in.I3C_EC.TTI.RX_DESC_QUEUE_PORT.rd_ack = tti_rx_desc_queue_rd_ack;
    hwif_in.I3C_EC.TTI.RX_DESC_QUEUE_PORT.rd_data = tti_rx_desc_queue_rd_data;

    hwif_in.I3C_EC.TTI.RX_DATA_PORT.rd_ack = tti_rx_queue_rd_ack;
    hwif_in.I3C_EC.TTI.RX_DATA_PORT.rd_data = tti_rx_queue_rd_data;

    hwif_in.I3C_EC.TTI.TX_DESC_QUEUE_PORT.wr_ack = tti_tx_desc_queue_wr_ack;

    hwif_in.I3C_EC.TTI.TX_DATA_PORT.wr_ack = tti_tx_queue_wr_ack;

    hwif_in.I3C_EC.TTI.IBI_PORT.wr_ack = tti_ibi_queue_wr_ack;
  end : wire_hwif_tti

  I3CCSR i3c_csr (
      .clk(clk_i),
      .rst('0),  // Unused, CSRs are reset through hwif_in.rst_ni

      .s_cpuif_req(s_cpuif_req),
      .s_cpuif_req_is_wr(s_cpuif_req_is_wr),
      .s_cpuif_addr(s_cpuif_addr),
      .s_cpuif_wr_data(s_cpuif_wr_data),
      .s_cpuif_wr_biten(s_cpuif_wr_biten),  // Write strobes not handled by AHB-Lite interface
      .s_cpuif_req_stall_wr(s_cpuif_req_stall_wr),
      .s_cpuif_req_stall_rd(s_cpuif_req_stall_rd),
      .s_cpuif_rd_ack(s_cpuif_rd_ack),  // Ignored by AHB component
      .s_cpuif_rd_err(s_cpuif_rd_err),
      .s_cpuif_rd_data(s_cpuif_rd_data),
      .s_cpuif_wr_ack(s_cpuif_wr_ack),  // Ignored by AHB component
      .s_cpuif_wr_err(s_cpuif_wr_err),

      .hwif_in (hwif_in),
      .hwif_out(hwif_out)
  );

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

      .csr_dat_hwif_i(dat_o),
      .csr_dat_hwif_o(dat_i),

      .csr_dct_hwif_i(dct_o),
      .csr_dct_hwif_o(dct_i),

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

  configuration xconfiguration (
      .clk_i,
      .rst_ni,
      .hwif_out,
      .phy_en_o,
      .phy_mux_select_o,
      .i2c_active_en_o,
      .i2c_standby_en_o,
      .i3c_active_en_o,
      .i3c_standby_en_o,
      .t_su_dat_o,
      .t_hd_dat_o,
      .t_r_o,
      .t_bus_free_o,
      .t_bus_idle_o,
      .t_bus_available_o
  );

  tti #(
      .CsrDataWidth(CsrDataWidth),

      .TxDescFifoDepth(TtiRespFifoDepth),
      .RxDescFifoDepth(TtiCmdFifoDepth),
      .TxFifoDepth(TtiRxFifoDepth),
      .RxFifoDepth(TtiTxFifoDepth),
      .IbiFifoDepth(TtiIbiFifoDepth),

      .RxDescDataWidth(TtiRxDescDataWidth),
      .TxDescDataWidth(TtiTxDescDataWidth),
      .RxDataWidth(TtiRxDataWidth),
      .TxDataWidth(TtiTxDataWidth),
      .IbiDataWidth(TtiIbiDataWidth),

      .RxDescThldWidth(TtiRxDescThldWidth),
      .TxDescThldWidth(TtiTxDescThldWidth),
      .RxThldWidth(TtiRxThldWidth),
      .TxThldWidth(TtiTxThldWidth),
      .IbiThldWidth(TtiIbiThldWidth)
  ) tti (
      .clk_i,
      .rst_ni,

      .hwif_out_i(hwif_out),

      // Command queue
      .rx_desc_queue_full_o(tti_rx_desc_queue_full_o),
      .rx_desc_queue_ready_thld_trig_o(tti_rx_desc_queue_ready_thld_trig_o),
      .rx_desc_queue_ready_thld_o(tti_rx_desc_queue_ready_thld_o),
      .rx_desc_queue_ready_thld_next_i(hwif_in.I3C_EC.TTI.QUEUE_THLD_CTRL.RX_DESC_THLD.next),
      .rx_desc_queue_ready_thld_we_i(hwif_in.I3C_EC.TTI.QUEUE_THLD_CTRL.RX_DESC_THLD.we),
      .rx_desc_queue_empty_o(tti_rx_desc_queue_empty_o),
      .rx_desc_queue_wvalid_i(tti_rx_desc_queue_wvalid_i),
      .rx_desc_queue_wready_o(tti_rx_desc_queue_wready_o),
      .rx_desc_queue_wdata_i(tti_rx_desc_queue_wdata_i),
      .rx_desc_queue_rd_ack_o(tti_rx_desc_queue_rd_ack),
      .rx_desc_queue_rd_data_o(tti_rx_desc_queue_rd_data),
      .rx_desc_queue_rst_we_o(hwif_in.I3C_EC.TTI.RESET_CONTROL.RX_DESC_RST.we),
      .rx_desc_queue_rst_next_o(hwif_in.I3C_EC.TTI.RESET_CONTROL.RX_DESC_RST.next),

      .tx_desc_queue_full_o(tti_tx_desc_queue_full_o),
      .tx_desc_queue_ready_thld_trig_o(tti_tx_desc_queue_ready_thld_trig_o),
      .tx_desc_queue_ready_thld_o(tti_tx_desc_queue_ready_thld_o),
      .tx_desc_queue_ready_thld_next_i(hwif_in.I3C_EC.TTI.QUEUE_THLD_CTRL.TX_DESC_THLD.next),
      .tx_desc_queue_ready_thld_we_i(hwif_in.I3C_EC.TTI.QUEUE_THLD_CTRL.TX_DESC_THLD.we),
      .tx_desc_queue_empty_o(tti_tx_desc_queue_empty_o),
      .tx_desc_queue_rvalid_o(tti_tx_desc_queue_rvalid_o),
      .tx_desc_queue_rready_i(tti_tx_desc_queue_rready_i),
      .tx_desc_queue_rdata_o(tti_tx_desc_queue_rdata_o),
      .tx_desc_queue_wr_ack_o(tti_tx_desc_queue_wr_ack),
      .tx_desc_queue_rst_we_o(hwif_in.I3C_EC.TTI.RESET_CONTROL.TX_DESC_RST.we),
      .tx_desc_queue_rst_next_o(hwif_in.I3C_EC.TTI.RESET_CONTROL.TX_DESC_RST.next),

      .rx_queue_full_o(tti_rx_queue_full_o),
      .rx_queue_start_thld_o(tti_rx_queue_start_thld_o),
      .rx_queue_start_thld_trig_o(tti_rx_queue_start_thld_trig_o),
      .rx_queue_ready_thld_o(tti_rx_queue_ready_thld_o),
      .rx_queue_ready_thld_trig_o(tti_rx_queue_ready_thld_trig_o),
      .rx_queue_empty_o(tti_rx_queue_empty_o),
      .rx_queue_wvalid_i(tti_rx_queue_wvalid_i),
      .rx_queue_wready_o(tti_rx_queue_wready_o),
      .rx_queue_wdata_i(tti_rx_queue_wdata_i),
      .rx_queue_rd_ack_o(tti_rx_queue_rd_ack),
      .rx_queue_rd_data_o(tti_rx_queue_rd_data),
      .rx_queue_rst_we_o(hwif_in.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST.we),
      .rx_queue_rst_next_o(hwif_in.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST.next),

      .tx_queue_full_o(tti_tx_queue_full_o),
      .tx_queue_start_thld_o(tti_tx_queue_start_thld_o),
      .tx_queue_start_thld_trig_o(tti_tx_queue_start_thld_trig_o),
      .tx_queue_ready_thld_o(tti_tx_queue_ready_thld_o),
      .tx_queue_ready_thld_trig_o(tti_tx_queue_ready_thld_trig_o),
      .tx_queue_empty_o(tti_tx_queue_empty_o),
      .tx_queue_rvalid_o(tti_tx_queue_rvalid_o),
      .tx_queue_rready_i(tti_tx_queue_rready_i),
      .tx_queue_rdata_o(tti_tx_queue_rdata_o),
      .tx_queue_wr_ack_o(tti_tx_queue_wr_ack),
      .tx_queue_rst_we_o(hwif_in.I3C_EC.TTI.RESET_CONTROL.TX_DATA_RST.we),
      .tx_queue_rst_next_o(hwif_in.I3C_EC.TTI.RESET_CONTROL.TX_DATA_RST.next),

      .ibi_queue_full_o(tti_ibi_queue_full_o),
      .ibi_queue_ready_thld_o(tti_ibi_queue_ready_thld_o),
      .ibi_queue_ready_thld_trig_o(tti_ibi_queue_ready_thld_trig_o),
      .ibi_queue_empty_o(tti_ibi_queue_empty_o),
      .ibi_queue_rvalid_o(tti_ibi_queue_rvalid_o),
      .ibi_queue_rready_i(tti_ibi_queue_rready_i),
      .ibi_queue_rdata_o(tti_ibi_queue_rdata_o),
      .ibi_queue_wr_ack_o(tti_ibi_queue_wr_ack),
      .ibi_queue_rst_we_o(hwif_in.I3C_EC.TTI.RESET_CONTROL.IBI_QUEUE_RST.we),
      .ibi_queue_rst_next_o(hwif_in.I3C_EC.TTI.RESET_CONTROL.IBI_QUEUE_RST.next)
  );

  // In-band Interrupt queue
  logic hci_ibi_queue_rst;
  logic hci_ibi_queue_rst_we;
  logic hci_ibi_queue_rst_next;
  logic hci_ibi_queue_req;
  logic hci_ibi_queue_rd_ack;
  logic unused_ibi_queue_start_thld_trig;
  logic [HciIbiThldWidth-1:0] hci_ibi_queue_thld;
  logic [HciIbiDataWidth-1:0] hci_ibi_queue_rd_data;

  always_comb begin
    hci_ibi_queue_rst = hwif_out.I3CBase.RESET_CONTROL.IBI_QUEUE_RST.value;
    hwif_in.I3CBase.RESET_CONTROL.IBI_QUEUE_RST.we = hci_ibi_queue_rst_we;
    hwif_in.I3CBase.RESET_CONTROL.IBI_QUEUE_RST.next = hci_ibi_queue_rst_next;

    hci_ibi_queue_thld = hwif_out.PIOControl.QUEUE_THLD_CTRL.IBI_STATUS_THLD.value;

    hci_ibi_queue_req = hwif_out.PIOControl.IBI_PORT.req;
    hwif_in.PIOControl.IBI_PORT.rd_ack = hci_ibi_queue_rd_ack;
    hwif_in.PIOControl.IBI_PORT.rd_data = hci_ibi_queue_rd_data;
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

      .full_o(hci_ibi_queue_full_o),
      .start_thld_trig_o(unused_ibi_queue_start_thld_trig),
      .ready_thld_trig_o(hci_ibi_queue_ready_thld_trig_o),
      .empty_o(hci_ibi_queue_empty_o),
      .wvalid_i(hci_ibi_queue_wvalid_i),
      .wready_o(hci_ibi_queue_wready_o),
      .wdata_i(hci_ibi_queue_wdata_i),

      .req_i (hci_ibi_queue_req),
      .ack_o (hci_ibi_queue_rd_ack),
      .data_o(hci_ibi_queue_rd_data),

      .start_thld_i('0),
      .ready_thld_i(hci_ibi_queue_thld),
      .ready_thld_o(hci_ibi_queue_ready_thld_o),

      .reg_rst_i(hci_ibi_queue_rst),
      .reg_rst_we_o(hci_ibi_queue_rst_we),
      .reg_rst_data_o(hci_ibi_queue_rst_next)
  );

endmodule : hci
