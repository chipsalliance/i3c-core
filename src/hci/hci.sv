// SPDX-License-Identifier: Apache-2.0

// I3C Host Controller Interface
module hci
  import I3CCSR_pkg::*;
  import i3c_pkg::*;
  import hci_pkg::*;
(
    input clk_i,  // clock
    input rst_ni, // active low reset

    // I3C SW CSR access interface
    input  logic                             s_cpuif_req,
    input  logic                             s_cpuif_req_is_wr,
    input  logic [I3CCSR_MIN_ADDR_WIDTH-1:0] s_cpuif_addr,
    input  logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_data,
    input  logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_biten,
    output logic                             s_cpuif_req_stall_wr,
    output logic                             s_cpuif_req_stall_rd,
    output logic                             s_cpuif_rd_ack,
    output logic                             s_cpuif_rd_err,
    output logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_rd_data,
    output logic                             s_cpuif_wr_ack,
    output logic                             s_cpuif_wr_err,

    // DAT <-> Controller interface
    input  logic                          dat_read_valid_hw_i,
    input  logic [$clog2(`DAT_DEPTH)-1:0] dat_index_hw_i,
    output logic [                  63:0] dat_rdata_hw_o,

    // DCT <-> Controller interface
    input  logic                          dct_write_valid_hw_i,
    input  logic                          dct_read_valid_hw_i,
    input  logic [$clog2(`DCT_DEPTH)-1:0] dct_index_hw_i,
    input  logic [                 127:0] dct_wdata_hw_i,
    output logic [                 127:0] dct_rdata_hw_o,

    // DAT memory export interface
    input  dat_mem_src_t  dat_mem_src_i,
    output dat_mem_sink_t dat_mem_sink_o,

    // DCT memory export interface
    input  dct_mem_src_t  dct_mem_src_i,
    output dct_mem_sink_t dct_mem_sink_o,

    // Command queue
    output logic hci_cmd_full_o,
    output logic [HciCmdThldWidth-1:0] hci_cmd_thld_o,
    output logic hci_cmd_below_thld_o,
    output logic hci_cmd_empty_o,
    output logic hci_cmd_rvalid_o,
    input logic hci_cmd_rready_i,
    output logic [HciCmdDataWidth-1:0] hci_cmd_rdata_o,

    // RX queue
    output logic hci_rx_full_o,
    output logic [HciRxThldWidth-1:0] hci_rx_thld_o,
    output logic hci_rx_above_thld_o,
    output logic hci_rx_empty_o,
    input logic hci_rx_wvalid_i,
    output logic hci_rx_wready_o,
    input logic [HciRxDataWidth-1:0] hci_rx_wdata_i,

    // TX queue
    output logic hci_tx_full_o,
    output logic [HciTxThldWidth-1:0] hci_tx_thld_o,
    output logic hci_tx_below_thld_o,
    output logic hci_tx_empty_o,
    output logic hci_tx_rvalid_o,
    input logic hci_tx_rready_i,
    output logic [HciTxDataWidth-1:0] hci_tx_rdata_o,

    output logic hci_resp_full_o,
    output logic [HciRespThldWidth-1:0] hci_resp_thld_o,
    output logic hci_resp_above_thld_o,
    output logic hci_resp_empty_o,
    input logic hci_resp_wvalid_i,
    output logic hci_resp_wready_o,
    input logic [HciRespDataWidth-1:0] hci_resp_wdata_i,

    // Target Transport Interface
    // RX descriptors queue
    output logic tti_rx_desc_queue_full_o,
    output logic [TtiCmdThldWidth-1:0] tti_rx_desc_queue_thld_o,
    output logic tti_rx_desc_queue_above_thld_o,
    output logic tti_rx_desc_queue_empty_o,
    input logic tti_rx_desc_queue_wvalid_i,
    output logic tti_rx_desc_queue_wready_o,
    input logic [TtiCmdDataWidth-1:0] tti_rx_desc_queue_wdata_i,

    // RX queue
    output logic tti_rx_queue_full_o,
    output logic [TtiRxThldWidth-1:0] tti_rx_queue_thld_o,
    output logic tti_rx_queue_above_thld_o,
    output logic tti_rx_queue_empty_o,
    input logic tti_rx_queue_wvalid_i,
    output logic tti_rx_queue_wready_o,
    input logic [TtiRxDataWidth-1:0] tti_rx_queue_wdata_i,

    // Response queue
    output logic tti_tx_desc_queue_full_o,
    output logic [TtiRespThldWidth-1:0] tti_tx_desc_queue_thld_o,
    output logic tti_tx_desc_queue_below_thld_o,
    output logic tti_tx_desc_queue_empty_o,
    output logic tti_tx_desc_queue_rvalid_o,
    input logic tti_tx_desc_queue_rready_i,
    output logic [TtiRespDataWidth-1:0] tti_tx_desc_queue_rdata_o,

    // TX queue
    output logic tti_tx_queue_full_o,
    output logic [TtiTxThldWidth-1:0] tti_tx_queue_thld_o,
    output logic tti_tx_queue_below_thld_o,
    output logic tti_tx_queue_empty_o,
    output logic tti_tx_queue_rvalid_o,
    input logic tti_tx_queue_rready_i,
    output logic [TtiTxDataWidth-1:0] tti_tx_queue_rdata_o,

    // Controller configuration
    output i3c_config_t core_config
);
  localparam int unsigned CmdSizeInDwords = HciCmdDataWidth / I3CCSR_DATA_WIDTH;

  I3CCSR__in_t  hwif_in;
  I3CCSR__out_t hwif_out;

  // Propagate reset to CSRs
  assign hwif_in.rst_ni = rst_ni;

  // DAT CSR interface
  I3CCSR__DAT__out_t dat_o;
  I3CCSR__DAT__in_t dat_i;

  // DCT CSR interface
  I3CCSR__DCT__out_t dct_o;
  I3CCSR__DCT__in_t dct_i;

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
  logic [HciCmdThldWidth-1:0] cmd_thld;
  logic [HciRxThldWidth-1:0] rx_thld;
  logic [HciTxThldWidth-1:0] tx_thld;
  logic [HciRespThldWidth-1:0] resp_thld;

  // HCI queue port control
  logic cmd_req;  // Read DWORD from the COMMAND_PORT request
  logic cmd_wr_ack;  // Feedback to the COMMAND_PORT; command has been fetched
  logic [HciCmdDataWidth-1:0] cmd_wr_data;  // DWORD collected from the COMMAND_PORT

  logic xfer_req;  // RX / TX data write / read request
  logic xfer_req_is_wr;  // TX iff true, otherwise RX

  logic rx_req;  // Write RX data to the RX_PORT request
  logic rx_rd_ack;  // XFER_DATA_PORT drives valid RX data
  logic [HciRxDataWidth-1:0] rx_rd_data;  // RX data read from the rx_fifo to be put to RX port

  logic tx_req;  // Read TX data from the TX_PORT request
  logic tx_wr_ack;  // Feedback to the XFER_DATA_PORT; data has been read from TX port
  logic [HciTxDataWidth-1:0] tx_wr_data;  // TX data to be put in tx_fifo

  logic resp_req;  // Write response to the RESPONSE_PORT request
  logic resp_rd_ack;  // resp_req is fulfilled; RESPONSE_PORT drives valid data
  logic [HciRespDataWidth-1:0] resp_rd_data;  // Response read from resp_fifo
                                              // placed in RESPONSE_PORT

  // TTI
  logic tti_rx_desc_queue_rd_ack;
  logic [TtiRxDataWidth-1:0] tti_rx_desc_queue_rd_data;
  logic tti_rx_queue_rd_ack;
  logic [TtiRxDataWidth-1:0] tti_rx_queue_rd_data;
  logic tti_tx_desc_queue_wr_ack;
  logic tti_tx_queue_wr_ack;

  logic cmdrst, txrst, resprst, rxrst;

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
    cmd_thld = hwif_out.PIOControl.QUEUE_THLD_CTRL.CMD_EMPTY_BUF_THLD.value;
    rx_thld = hwif_out.PIOControl.DATA_BUFFER_THLD_CTRL.RX_BUF_THLD.value;
    tx_thld = hwif_out.PIOControl.DATA_BUFFER_THLD_CTRL.TX_BUF_THLD.value;
    resp_thld = hwif_out.PIOControl.QUEUE_THLD_CTRL.RESP_BUF_THLD.value;

    // HCI queue port handling

    // HCI PIOControl ports requests
    xfer_req = hwif_out.PIOControl.XFER_DATA_PORT.req;
    xfer_req_is_wr = hwif_out.PIOControl.XFER_DATA_PORT.req_is_wr;

    cmd_req = hwif_out.PIOControl.COMMAND_PORT.req & hwif_out.PIOControl.COMMAND_PORT.req_is_wr;
    rx_req = xfer_req && !xfer_req_is_wr;
    tx_req = xfer_req && xfer_req_is_wr;
    resp_req = hwif_out.PIOControl.RESPONSE_PORT.req;

    // Reading commands from the command port
    hwif_in.PIOControl.COMMAND_PORT.wr_ack = cmd_wr_ack;
    cmd_wr_data = hwif_out.PIOControl.COMMAND_PORT.wr_data;

    // Writing data to the rx port
    hwif_in.PIOControl.XFER_DATA_PORT.rd_ack = rx_rd_ack;
    hwif_in.PIOControl.XFER_DATA_PORT.rd_data = rx_rd_data;

    // Reading data from the tx port
    hwif_in.PIOControl.XFER_DATA_PORT.wr_ack = tx_wr_ack;
    tx_wr_data = hwif_out.PIOControl.XFER_DATA_PORT.wr_data;

    // Writing response to the resp port
    hwif_in.PIOControl.RESPONSE_PORT.rd_ack = resp_rd_ack;
    hwif_in.PIOControl.RESPONSE_PORT.rd_data = resp_rd_data;

    // DXT
    hwif_in.DAT = dat_i;
    hwif_in.DCT = dct_i;
    dat_o = hwif_out.DAT;
    dct_o = hwif_out.DCT;
  end : wire_hwif

  always_comb begin : wire_hwif_tti
    hwif_in.I3C_EC.TTI.RX_DESC_QUEUE_PORT.rd_ack = tti_rx_desc_queue_rd_ack;
    hwif_in.I3C_EC.TTI.RX_DESC_QUEUE_PORT.rd_data = tti_rx_desc_queue_rd_data;

    hwif_in.I3C_EC.TTI.RX_DATA_PORT.rd_ack = tti_rx_queue_rd_ack;
    hwif_in.I3C_EC.TTI.RX_DATA_PORT.rd_data = tti_rx_queue_rd_data;

    hwif_in.I3C_EC.TTI.TX_DESC_QUEUE_PORT.wr_ack = tti_tx_desc_queue_wr_ack;

    hwif_in.I3C_EC.TTI.TX_DATA_PORT.wr_ack = tti_tx_queue_wr_ack;
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

  dxt dxt (
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

  queues #(
      .TX_DESC_FIFO_DEPTH(`CMD_FIFO_DEPTH),
      .TX_FIFO_DEPTH(`TX_FIFO_DEPTH),
      .RX_FIFO_DEPTH(`RX_FIFO_DEPTH),
      .RX_DESC_FIFO_DEPTH(`RESP_FIFO_DEPTH),

      .TX_DESC_FIFO_DATA_WIDTH(HciCmdDataWidth),
      .TX_FIFO_DATA_WIDTH(HciTxDataWidth),
      .RX_FIFO_DATA_WIDTH(HciRxDataWidth),
      .RX_DESC_FIFO_DATA_WIDTH(HciRespDataWidth),

      .TX_DESC_THLD_WIDTH(HciCmdThldWidth),
      .TX_THLD_WIDTH(HciTxThldWidth),
      .RX_THLD_WIDTH(HciRxThldWidth),
      .RX_DESC_THLD_WIDTH(HciRespThldWidth)
  ) hci_queues (
      .clk_i,
      .rst_ni,

      .tx_desc_full_o(hci_cmd_full_o),
      .tx_desc_below_thld_o(hci_cmd_below_thld_o),
      .tx_desc_empty_o(hci_cmd_empty_o),
      .tx_desc_rvalid_o(hci_cmd_rvalid_o),
      .tx_desc_rready_i(hci_cmd_rready_i),
      .tx_desc_rdata_o(hci_cmd_rdata_o),
      .tx_desc_req_i(cmd_req),
      .tx_desc_ack_o(cmd_wr_ack),
      .tx_desc_data_i(cmd_wr_data),
      .tx_desc_thld_i(cmd_thld),
      .tx_desc_thld_o(hci_cmd_thld_o),
      .tx_desc_reg_rst_i(cmdrst),
      .tx_desc_reg_rst_we_o(cmd_reset_ctrl_we),
      .tx_desc_reg_rst_data_o(cmd_reset_ctrl_next),

      .rx_full_o(hci_rx_full_o),
      .rx_above_thld_o(hci_rx_above_thld_o),
      .rx_empty_o(hci_rx_empty_o),
      .rx_wvalid_i(hci_rx_wvalid_i),
      .rx_wready_o(hci_rx_wready_o),
      .rx_wdata_i(hci_rx_wdata_i),
      .rx_req_i(rx_req),
      .rx_ack_o(rx_rd_ack),
      .rx_data_o(rx_rd_data),
      .rx_thld_i(rx_thld),
      .rx_thld_o(hci_rx_thld_o),
      .rx_reg_rst_i(rxrst),
      .rx_reg_rst_we_o(rx_reset_ctrl_we),
      .rx_reg_rst_data_o(rx_reset_ctrl_next),

      .tx_full_o(hci_tx_full_o),
      .tx_below_thld_o(hci_tx_below_thld_o),
      .tx_empty_o(hci_tx_empty_o),
      .tx_rvalid_o(hci_tx_rvalid_o),
      .tx_rready_i(hci_tx_rready_i),
      .tx_rdata_o(hci_tx_rdata_o),
      .tx_req_i(tx_req),
      .tx_ack_o(tx_wr_ack),
      .tx_data_i(tx_wr_data),
      .tx_thld_i(tx_thld),
      .tx_thld_o(hci_tx_thld_o),
      .tx_reg_rst_i(txrst),
      .tx_reg_rst_we_o(tx_reset_ctrl_we),
      .tx_reg_rst_data_o(tx_reset_ctrl_next),

      .rx_desc_full_o(hci_resp_full_o),
      .rx_desc_above_thld_o(hci_resp_above_thld_o),
      .rx_desc_empty_o(hci_resp_empty_o),
      .rx_desc_wvalid_i(hci_resp_wvalid_i),
      .rx_desc_wready_o(hci_resp_wready_o),
      .rx_desc_wdata_i(hci_resp_wdata_i),
      .rx_desc_req_i(resp_req),
      .rx_desc_ack_o(resp_rd_ack),
      .rx_desc_data_o(resp_rd_data),
      .rx_desc_thld_i(resp_thld),
      .rx_desc_thld_o(hci_resp_thld_o),
      .rx_desc_reg_rst_i(resprst),
      .rx_desc_reg_rst_we_o(resp_reset_ctrl_we),
      .rx_desc_reg_rst_data_o(resp_reset_ctrl_next)
  );

  configuration xconfiguration (
      .clk_i,
      .rst_ni,
      .hwif_out,
      .core_config
  );

  tti tti (
      .clk_i,
      .rst_ni,

      .hwif_out_i(hwif_out),

      // Command queue
      .rx_desc_queue_full_o(tti_rx_desc_queue_full_o),
      .rx_desc_queue_thld_o(tti_rx_desc_queue_thld_o),
      .rx_desc_queue_above_thld_o(tti_rx_desc_queue_above_thld_o),
      .rx_desc_queue_empty_o(tti_rx_desc_queue_empty_o),
      .rx_desc_queue_wvalid_i(tti_rx_desc_queue_wvalid_i),
      .rx_desc_queue_wready_o(tti_rx_desc_queue_wready_o),
      .rx_desc_queue_wdata_i(tti_rx_desc_queue_wdata_i),
      .rx_desc_queue_rd_ack_o(tti_rx_desc_queue_rd_ack),
      .rx_desc_queue_rd_data_o(tti_rx_desc_queue_rd_data),

      .rx_queue_full_o(tti_rx_queue_full_o),
      .rx_queue_thld_o(tti_rx_queue_thld_o),
      .rx_queue_above_thld_o(tti_rx_queue_above_thld_o),
      .rx_queue_empty_o(tti_rx_queue_empty_o),
      .rx_queue_wvalid_i(tti_rx_queue_wvalid_i),
      .rx_queue_wready_o(tti_rx_queue_wready_o),
      .rx_queue_wdata_i(tti_rx_queue_wdata_i),
      .rx_queue_rd_ack_o(tti_rx_queue_rd_ack),
      .rx_queue_rd_data_o(tti_rx_queue_rd_data),

      .tx_desc_queue_full_o(tti_tx_desc_queue_full_o),
      .tx_desc_queue_thld_o(tti_tx_desc_queue_thld_o),
      .tx_desc_queue_below_thld_o(tti_tx_desc_queue_below_thld_o),
      .tx_desc_queue_empty_o(tti_tx_desc_queue_empty_o),
      .tx_desc_queue_rvalid_o(tti_tx_desc_queue_rvalid_o),
      .tx_desc_queue_rready_i(tti_tx_desc_queue_rready_i),
      .tx_desc_queue_rdata_o(tti_tx_desc_queue_rdata_o),
      .tx_desc_queue_wr_ack_o(tti_tx_desc_queue_wr_ack),

      .tx_queue_full_o(tti_tx_queue_full_o),
      .tx_queue_thld_o(tti_tx_queue_thld_o),
      .tx_queue_below_thld_o(tti_tx_queue_below_thld_o),
      .tx_queue_empty_o(tti_tx_queue_empty_o),
      .tx_queue_rvalid_o(tti_tx_queue_rvalid_o),
      .tx_queue_rready_i(tti_tx_queue_rready_i),
      .tx_queue_rdata_o(tti_tx_queue_rdata_o),
      .tx_queue_wr_ack_o(tti_tx_queue_wr_ack)
  );

endmodule : hci
