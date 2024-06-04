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
    output logic                    cmdrst,
    output logic [CmdThldWidth-1:0] cmd_fifo_thld_o,
    input  logic                    cmd_fifo_empty_i,
    // Writes to the command FIFO are issued from CSR CMD_PORT
    output logic                    cmd_fifo_wvalid_o,
    input  logic                    cmd_fifo_wready_i,
    output logic [CmdFifoWidth-1:0] cmd_fifo_wdata_o,

    // RX queue
    output logic                   rxrst,
    output logic [RxThldWidth-1:0] rx_fifo_thld_o,
    input  logic                   rx_fifo_empty_i,
    // Reads from RX FIFO are forwarded to RX_PORT
    input  logic                   rx_fifo_rvalid_i,
    output logic                   rx_fifo_rready_o,
    input  logic [RxFifoWidth-1:0] rx_fifo_rdata_i,

    // TX queue
    output logic                   txrst,
    output logic [TxThldWidth-1:0] tx_fifo_thld_o,
    input  logic                   tx_fifo_empty_i,
    // Writes to TX FIFO come from CSR TX_PORT
    output logic                   tx_fifo_wvalid_o,
    input  logic                   tx_fifo_wready_i,
    output logic [TxFifoWidth-1:0] tx_fifo_wdata_o,

    // Response queue
    output logic                     resprst,
    output logic [RespThldWidth-1:0] resp_fifo_thld_o,
    input  logic                     resp_fifo_empty_i,
    // Responses are processed to be placed in RESP_PORT
    input  logic                     resp_fifo_rvalid_i,
    output logic                     resp_fifo_rready_o,
    input  logic [RespFifoWidth-1:0] resp_fifo_rdata_i
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

  // When the fifo has been emptied unset the fifo reset
  assign cmd_reset_ctrl_next  = '0;
  assign rx_reset_ctrl_next   = '0;
  assign tx_reset_ctrl_next   = '0;
  assign resp_reset_ctrl_next = '0;

  always_ff @(posedge clk_i or negedge rst_ni) begin : reset_control
    if (!rst_ni) begin : reset_control_rst
      cmd_reset_ctrl_we  <= '0;
      rx_reset_ctrl_we   <= '0;
      tx_reset_ctrl_we   <= '0;
      resp_reset_ctrl_we <= '0;
    end else begin
      cmd_reset_ctrl_we  <= cmdrst && cmd_fifo_empty_i;
      rx_reset_ctrl_we   <= rxrst && rx_fifo_empty_i;
      tx_reset_ctrl_we   <= txrst && tx_fifo_empty_i;
      resp_reset_ctrl_we <= resprst && resp_fifo_empty_i;
    end
  end : reset_control

  always_ff @(posedge clk_i or negedge rst_ni) begin : populate_thld
    if (!rst_ni) begin : populate_thld_rst
      cmd_fifo_thld_o  <= '0;
      rx_fifo_thld_o   <= '0;
      tx_fifo_thld_o   <= '0;
      resp_fifo_thld_o <= '0;
    end else begin
      // Specified threshold for the CMD queue in 'QUEUE_THLD_CTRL'
      // must be less or equal (<=) than CMD_FIFO_DEPTH.
      cmd_fifo_thld_o <= cmd_thld > `CMD_FIFO_DEPTH ? `CMD_FIFO_DEPTH : cmd_thld;
      // Threshold for RX queue is 2^(rx_thld+1) where 'rx_thld' is the value specified
      // in the 'DATA_BUFFER_THLD_CTRL' CSR.
      // Threshold must be less (<) than RX_FIFO_DEPTH.
      if ((1 << (rx_thld + 1)) >= `RX_FIFO_DEPTH) begin
        rx_fifo_thld_o <= $clog2(`RX_FIFO_DEPTH) - 2;
      end else begin
        rx_fifo_thld_o <= rx_thld;
      end
      // Threshold for TX queue is 2^(tx_thld+1) where 'tx_thld' is specified
      // in the 'DATA_BUFFER_THLD_CTRL' CSR.
      // Threshold must be less or equal (<=) than TX_FIFO_DEPTH.
      if ((1 << (tx_thld + 1)) > `TX_FIFO_DEPTH) begin
        tx_fifo_thld_o <= $clog2(`TX_FIFO_DEPTH) - 1;
      end else begin
        tx_fifo_thld_o <= tx_thld;
      end
      // Specified threshold for the RESP queue in 'QUEUE_THLD_CTRL'
      // must be less (<) than RESP_FIFO_DEPTH.
      resp_fifo_thld_o <= resp_thld >= `RESP_FIFO_DEPTH ? `RESP_FIFO_DEPTH - 1 : resp_thld;
    end
  end : populate_thld

  logic cmd_dword_index;  // Index of currently processed DWORD
  logic cmd_start_valid;  // Start of FIFO valid signal assertion
  assign cmd_start_valid = cmd_req & cmd_dword_index;

  always_ff @(posedge clk_i or negedge rst_ni) begin : cmd_port_to_fifo
    if (!rst_ni) begin : cmd_port_to_fifo_rst
      cmd_dword_index <= '0;
      cmd_wr_ack <= '0;
      cmd_fifo_wdata_o <= '0;
      cmd_fifo_wvalid_o <= '0;
    end else begin : push_cmds_to_fifo
      cmd_wr_ack <= 1'b0;

      if (cmd_req) begin
        cmd_dword_index <= 1'b1;
        if (cmd_dword_index) begin
          cmd_fifo_wdata_o[63:32] <= cmd_wr_data;
        end else begin
          cmd_fifo_wdata_o[31:0] <= cmd_wr_data;
          cmd_wr_ack <= 1'b1;
        end
      end

      if (cmd_start_valid) begin
        cmd_fifo_wvalid_o <= 1'b1;
      end

      if (cmd_fifo_wvalid_o & cmd_fifo_wready_i) begin
        cmd_fifo_wvalid_o <= 1'b0;
        cmd_wr_ack <= 1'b1;
        cmd_dword_index <= 1'b0;
      end
    end : push_cmds_to_fifo
  end : cmd_port_to_fifo

  always_ff @(posedge clk_i or negedge rst_ni or posedge rxrst) begin : rx_fifo_to_port
    if (!rst_ni | rxrst) begin : rx_fifo_to_port_rst
      rx_fifo_rready_o <= '0;
      rx_rd_data <= '0;
      rx_rd_ack <= '0;
    end else begin : push_rx_to_port
      if (rx_req) begin
        rx_fifo_rready_o <= 1'b1;
      end

      if (rx_fifo_rready_o & rx_fifo_rvalid_i) begin
        rx_fifo_rready_o <= 1'b0;
        rx_rd_data <= rx_fifo_rdata_i;
        rx_rd_ack <= 1'b1;
      end else begin
        rx_rd_data <= '0;
        rx_rd_ack  <= 1'b0;
      end
    end : push_rx_to_port
  end : rx_fifo_to_port

  always_ff @(posedge clk_i or negedge rst_ni) begin : tx_port_to_fifo
    if (!rst_ni) begin : tx_port_to_fifo_rst
      tx_fifo_wvalid_o <= '0;
      tx_wr_ack <= '0;
      tx_fifo_wdata_o <= '0;
    end else begin : push_tx_to_fifo
      if (tx_req) begin
        tx_fifo_wdata_o  <= tx_wr_data;
        tx_fifo_wvalid_o <= 1'b1;
      end

      if (tx_fifo_wready_i & tx_fifo_wvalid_o) begin
        tx_fifo_wdata_o <= '0;
        tx_fifo_wvalid_o <= 1'b0;
        tx_wr_ack <= 1'b1;
      end else begin
        tx_wr_ack <= 1'b0;
      end
    end : push_tx_to_fifo
  end : tx_port_to_fifo

  always_ff @(posedge clk_i or negedge rst_ni or posedge resprst) begin : resp_fifo_to_port
    if (!rst_ni | resprst) begin : resp_fifo_to_port_rst
      resp_fifo_rready_o <= '0;
      resp_rd_data <= '0;
      resp_rd_ack <= '0;
    end else begin : push_resp_to_port
      if (resp_req) begin
        resp_fifo_rready_o <= 1'b1;
      end

      if (resp_fifo_rready_o & resp_fifo_rvalid_i) begin
        resp_fifo_rready_o <= 1'b0;
        resp_rd_data <= resp_fifo_rdata_i;
        resp_rd_ack <= 1'b1;
      end else begin
        resp_rd_data <= '0;
        resp_rd_ack  <= 1'b0;
      end
    end : push_resp_to_port
  end : resp_fifo_to_port

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

endmodule : hci
