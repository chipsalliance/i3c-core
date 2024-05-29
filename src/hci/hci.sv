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
    output logic cmd_full_o,
    output logic [CmdThldWidth-1:0] cmd_thld_o,
    output logic cmd_below_thld_o,
    output logic cmd_empty_o,
    output logic cmd_rvalid_o,
    input logic cmd_rready_i,
    output logic [CmdFifoWidth-1:0] cmd_rdata_o,

    // RX queue
    output logic rx_full_o,
    output logic [RxThldWidth-1:0] rx_thld_o,
    output logic rx_above_thld_o,
    output logic rx_empty_o,
    input logic rx_wvalid_i,
    output logic rx_wready_o,
    input logic [RxFifoWidth-1:0] rx_wdata_i,

    // TX queue
    output logic tx_full_o,
    output logic [TxThldWidth-1:0] tx_thld_o,
    output logic tx_below_thld_o,
    output logic tx_empty_o,
    output logic tx_rvalid_o,
    input logic tx_rready_i,
    output logic [TxFifoWidth-1:0] tx_rdata_o,

    // Response queue
    output logic resp_full_o,
    output logic [RespThldWidth-1:0] resp_thld_o,
    output logic resp_above_thld_o,
    output logic resp_empty_o,
    input logic resp_wvalid_i,
    output logic resp_wready_o,
    input logic [RespFifoWidth-1:0] resp_wdata_i
);
  localparam int unsigned CmdSizeInDwords = CmdFifoWidth / I3CCSR_DATA_WIDTH;
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
  logic [CmdThldWidth-1:0] cmd_thld;
  logic [RxThldWidth-1:0] rx_thld;
  logic [TxThldWidth-1:0] tx_thld;
  logic [RespThldWidth-1:0] resp_thld;

  // HCI queue port control
  logic cmd_req;  // Read DWORD from the COMMAND_PORT request
  logic cmd_wr_ack;  // Feedback to the COMMAND_PORT; command has been fetched
  logic [CmdFifoWidth-1:0] cmd_wr_data;  // DWORD collected from the COMMAND_PORT

  logic xfer_req;  // RX / TX data write / read request
  logic xfer_req_is_wr;  // TX iff true, otherwise RX

  logic rx_req;  // Write RX data to the RX_PORT request
  logic rx_rd_ack;  // XFER_DATA_PORT drives valid RX data
  logic [RxFifoWidth-1:0] rx_rd_data;  // RX data read from the rx_fifo to be put to RX port

  logic tx_req;  // Read TX data from the TX_PORT request
  logic tx_wr_ack;  // Feedback to the XFER_DATA_PORT; data has been read from TX port
  logic [TxFifoWidth-1:0] tx_wr_data;  // TX data to be put in tx_fifo

  logic resp_req;  // Write response to the RESPONSE_PORT request
  logic resp_rd_ack;  // resp_req is fulfilled; RESPONSE_PORT drives valid data
  logic [RespFifoWidth-1:0] resp_rd_data;  // Response read from resp_fifo; placed in RESPONSE_PORT

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

  hci_ctrl_queues #(
      .CMD_FIFO_DEPTH (64),
      .RESP_FIFO_DEPTH(64),
      .RX_FIFO_DEPTH  (64),
      .TX_FIFO_DEPTH  (64)
  ) hci_queues (
      .clk_i,
      .rst_ni,

      .cmd_full_o,
      .cmd_below_thld_o,
      .cmd_empty_o,
      .cmd_rvalid_o,
      .cmd_rready_i,
      .cmd_rdata_o,
      .cmd_req_i(cmd_req),
      .cmd_ack_o(cmd_wr_ack),
      .cmd_data_i(cmd_wr_data),
      .cmd_thld_i(cmd_thld),
      .cmd_thld_o,
      .cmd_reg_rst_i(cmdrst),
      .cmd_reg_rst_we_o(cmd_reset_ctrl_we),
      .cmd_reg_rst_data_o(cmd_reset_ctrl_next),

      .rx_full_o,
      .rx_above_thld_o,
      .rx_empty_o,
      .rx_wvalid_i,
      .rx_wready_o,
      .rx_wdata_i,
      .rx_req_i(rx_req),
      .rx_ack_o(rx_rd_ack),
      .rx_data_o(rx_rd_data),
      .rx_thld_i(rx_thld),
      .rx_thld_o,
      .rx_reg_rst_i(rxrst),
      .rx_reg_rst_we_o(rx_reset_ctrl_we),
      .rx_reg_rst_data_o(rx_reset_ctrl_next),

      .tx_full_o,
      .tx_below_thld_o,
      .tx_empty_o,
      .tx_rvalid_o,
      .tx_rready_i,
      .tx_rdata_o,
      .tx_req_i(tx_req),
      .tx_ack_o(tx_wr_ack),
      .tx_data_i(tx_wr_data),
      .tx_thld_i(tx_thld),
      .tx_thld_o,
      .tx_reg_rst_i(txrst),
      .tx_reg_rst_we_o(tx_reset_ctrl_we),
      .tx_reg_rst_data_o(tx_reset_ctrl_next),

      .resp_full_o,
      .resp_above_thld_o,
      .resp_empty_o,
      .resp_wvalid_i,
      .resp_wready_o,
      .resp_wdata_i,
      .resp_req_i(resp_req),
      .resp_ack_o(resp_rd_ack),
      .resp_data_o(resp_rd_data),
      .resp_thld_i(resp_thld),
      .resp_thld_o,
      .resp_reg_rst_i(resprst),
      .resp_reg_rst_we_o(resp_reset_ctrl_we),
      .resp_reg_rst_data_o(resp_reset_ctrl_next)
  );

endmodule : hci
