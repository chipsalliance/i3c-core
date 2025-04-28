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

    // Target Transaction Interface CSRs
    output I3CCSR_pkg::I3CCSR__I3C_EC__TTI__out_t hwif_tti_o,
    input  I3CCSR_pkg::I3CCSR__I3C_EC__TTI__in_t  hwif_tti_i,
    // SoC Managment CSR interface
    output I3CCSR_pkg::I3CCSR__I3C_EC__SoCMgmtIf__out_t hwif_socmgmt_o,
    input  I3CCSR_pkg::I3CCSR__I3C_EC__SoCMgmtIf__in_t  hwif_socmgmt_i,

    // Recovery interface CSRs
    output I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__out_t hwif_rec_o,
    input  I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__in_t  hwif_rec_i,

    // Controller configuration
    output I3CCSR_pkg::I3CCSR__out_t hwif_out_o,

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

  I3CCSR_pkg::I3CCSR__in_t hwif_in;

  // Propagate reset to CSRs
  assign hwif_in.rst_ni = rst_ni;

  // DAT CSR interface
  I3CCSR_pkg::I3CCSR__DAT__out_t dat_o;
  I3CCSR_pkg::I3CCSR__DAT__in_t  dat_i;

  // DCT CSR interface
  I3CCSR_pkg::I3CCSR__DCT__out_t dct_o;
  I3CCSR_pkg::I3CCSR__DCT__in_t  dct_i;


  // TTI CSR interface
  assign hwif_tti_o = hwif_out_o.I3C_EC.TTI;
  assign hwif_in.I3C_EC.TTI = hwif_tti_i;

  // SoC Managment CSR interface
  assign hwif_socmgmt_o = hwif_out_o.I3C_EC.SoCMgmtIf;
  assign hwif_in.I3C_EC.SoCMgmtIf = hwif_socmgmt_i;

  // Recovery CSR interface
  assign hwif_rec_o = hwif_out_o.I3C_EC.SecFwRecoveryIf;

  // TODO: Use this if
  assign hwif_in.I3C_EC.SecFwRecoveryIf = hwif_rec_i;

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
      cmd_ready_thld_swmod_q <= '0;
      resp_ready_thld_swmod_q <= '0;
    end else begin
      cmd_ready_thld_swmod_q <= hwif_out_o.PIOControl.QUEUE_THLD_CTRL.CMD_EMPTY_BUF_THLD.swmod;
      cmd_ready_thld_we <= cmd_ready_thld_swmod_q;
      resp_ready_thld_swmod_q <= hwif_out_o.PIOControl.QUEUE_THLD_CTRL.RESP_BUF_THLD.swmod;
      resp_ready_thld_we <= resp_ready_thld_swmod_q;
    end
  end

  always_comb begin : wire_hwif
    // Reset control
    cmdrst = hwif_out_o.I3CBase.RESET_CONTROL.CMD_QUEUE_RST.value;
    rxrst = hwif_out_o.I3CBase.RESET_CONTROL.RX_FIFO_RST.value;
    txrst = hwif_out_o.I3CBase.RESET_CONTROL.TX_FIFO_RST.value;
    resprst = hwif_out_o.I3CBase.RESET_CONTROL.RESP_QUEUE_RST.value;

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
    cmd_ready_thld = hwif_out_o.PIOControl.QUEUE_THLD_CTRL.CMD_EMPTY_BUF_THLD.value;
    hci_rx_start_thld_o = hwif_out_o.PIOControl.DATA_BUFFER_THLD_CTRL.RX_START_THLD.value;
    rx_ready_thld = hwif_out_o.PIOControl.DATA_BUFFER_THLD_CTRL.RX_BUF_THLD.value;
    hci_tx_start_thld_o = hwif_out_o.PIOControl.DATA_BUFFER_THLD_CTRL.TX_START_THLD.value;
    tx_ready_thld = hwif_out_o.PIOControl.DATA_BUFFER_THLD_CTRL.TX_BUF_THLD.value;
    resp_ready_thld = hwif_out_o.PIOControl.QUEUE_THLD_CTRL.RESP_BUF_THLD.value;

    // HCI queue port handling

    // HCI PIOControl ports requests
    xfer_req = hwif_out_o.PIOControl.RX_DATA_PORT.req | hwif_out_o.PIOControl.TX_DATA_PORT.req;
    xfer_req_is_wr = hwif_out_o.PIOControl.RX_DATA_PORT.req_is_wr
      | hwif_out_o.PIOControl.TX_DATA_PORT.req_is_wr;

    cmd_req = hwif_out_o.PIOControl.COMMAND_PORT.req & hwif_out_o.PIOControl.COMMAND_PORT.req_is_wr;
    rx_req = xfer_req && !xfer_req_is_wr;
    tx_req = xfer_req && xfer_req_is_wr;
    resp_req = hwif_out_o.PIOControl.RESPONSE_PORT.req;

    // Reading commands from the command port
    hwif_in.PIOControl.COMMAND_PORT.wr_ack = cmd_wr_ack;
    cmd_wr_data = hwif_out_o.PIOControl.COMMAND_PORT.wr_data;

    // Writing data to the rx port
    hwif_in.PIOControl.RX_DATA_PORT.rd_ack = rx_rd_ack;
    hwif_in.PIOControl.RX_DATA_PORT.rd_data = rx_rd_data;

    // Reading data from the tx port
    hwif_in.PIOControl.TX_DATA_PORT.wr_ack = tx_wr_ack;
    tx_wr_data = hwif_out_o.PIOControl.TX_DATA_PORT.wr_data;

    // Writing response to the resp port
    hwif_in.PIOControl.RESPONSE_PORT.rd_ack = resp_rd_ack;
    hwif_in.PIOControl.RESPONSE_PORT.rd_data = resp_rd_data;

    // DXT
    hwif_in.DAT = dat_i;
    hwif_in.DCT = dct_i;
    dat_o = hwif_out_o.DAT;
    dct_o = hwif_out_o.DCT;
  end : wire_hwif

  always_comb begin : wire_hwif_rstact
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_RSTACT_PARAMS.RST_ACTION.next = rst_action_valid_i ? rst_action_i : '0;
  end

  always_comb begin : wire_address_setting
    // Target address
    if (set_dasa_valid_i | rstdaa_i) begin
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID.we = (set_dasa_valid_i | rstdaa_i) && ~(set_dasa_virtual_device_i);
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID.next = (rstdaa_i && ~(set_dasa_virtual_device_i)) ? '0: set_dasa_valid_i;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR.we = (set_dasa_valid_i | rstdaa_i) && ~(set_dasa_virtual_device_i);
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR.next = (rstdaa_i && ~(set_dasa_virtual_device_i)) ? 1'b0 : set_dasa_i;
      // Virtual device address
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID.we = (set_dasa_valid_i | rstdaa_i) && (set_dasa_virtual_device_i);
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID.next = rstdaa_i && set_dasa_virtual_device_i ? '0: set_dasa_valid_i;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR.we = (set_dasa_valid_i | rstdaa_i) && (set_dasa_virtual_device_i);
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR.next = rstdaa_i && set_dasa_virtual_device_i ? 1'b0 : set_dasa_i;
    end else if (set_newda_i | set_newda_virtual_device_i) begin
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID.we = set_newda_i && ~(set_newda_virtual_device_i);
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID.next = 1'b1;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR.we = set_newda_i && ~(set_newda_virtual_device_i);
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR.next = newda_i;
      // Virtual device address
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID.we = set_newda_i && set_newda_virtual_device_i;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID.next = 1'b1;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR.we = set_newda_i && set_newda_virtual_device_i;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR.next = newda_i;
    end else begin
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID.we = 1'b0;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID.next = '0;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR.we = 1'b0;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR.next = '0;
      // Virtual device address
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID.we = 1'b0;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID.next = '0;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR.we = 1'b0;
      hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR.next = '0;
    end
  end

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
      .hwif_out(hwif_out_o)
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
    hci_ibi_rst = hwif_out_o.I3CBase.RESET_CONTROL.IBI_QUEUE_RST.value;
    hwif_in.I3CBase.RESET_CONTROL.IBI_QUEUE_RST.we = hci_ibi_rst_we;
    hwif_in.I3CBase.RESET_CONTROL.IBI_QUEUE_RST.next = hci_ibi_rst_next;

    hci_ibi_thld = hwif_out_o.PIOControl.QUEUE_THLD_CTRL.IBI_STATUS_THLD.value;

    hci_ibi_req = hwif_out_o.PIOControl.IBI_PORT.req;
    hwif_in.PIOControl.IBI_PORT.rd_ack = hci_ibi_rd_ack;
    hwif_in.PIOControl.IBI_PORT.rd_data = hci_ibi_rd_data;
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
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR_VALID.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.__rsvd_3.__rsvd.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_RSTACT_PARAMS.RST_ACTION.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.STBY_CR_OP_RSTACT_SIGNAL_EN.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR.next = '0;
    hwif_in.I3C_EC.CtrlCfg.CONTROLLER_CONFIG.OPERATION_MODE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.STBY_CR_OP_RSTACT_STAT.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.STBY_CR_OP_RSTACT_FORCE.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_ENTDAA_ENABLE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.HANDOFF_DEEP_SLEEP.hwclr = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.STATIC_ADDR_VALID.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.STATIC_ADDR.next= '0;

    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.STATIC_ADDR_VALID.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_DEVICE_ADDR.STATIC_ADDR.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR_VALID.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.PENDING_RX_NACK.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.HANDOFF_DELAY_NACK.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.ACR_FSM_OP_SELECT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.PRIME_ACCEPT_GETACCCR.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.HANDOFF_DEEP_SLEEP.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.HANDOFF_DEEP_SLEEP.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.TARGET_XACT_ENABLE.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.TARGET_XACT_ENABLE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_SETAASA_ENABLE.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_SETAASA_ENABLE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_SETDASA_ENABLE.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_SETDASA_ENABLE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_ENTDAA_ENABLE.we = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_STATUS.AC_CURRENT_OWN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_STATUS.SIMPLE_CRR_STATUS.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_STATUS.HJ_REQ_STATUS.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.ACR_HANDOFF_OK_REMAIN_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.ACR_HANDOFF_OK_PRIMED_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.ACR_HANDOFF_ERR_FAIL_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.ACR_HANDOFF_ERR_M3_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.CRR_RESPONSE_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.STBY_CR_DYN_ADDR_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.STBY_CR_ACCEPT_NACKED_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.STBY_CR_ACCEPT_OK_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.STBY_CR_ACCEPT_ERR_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.STBY_CR_OP_RSTACT_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.CCC_PARAM_MODIFIED_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.CCC_UNHANDLED_NACK_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_STATUS.CCC_FATAL_RSTDAA_ERR_STAT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.ACR_HANDOFF_OK_REMAIN_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.ACR_HANDOFF_OK_PRIMED_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.ACR_HANDOFF_ERR_FAIL_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.ACR_HANDOFF_ERR_M3_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.CRR_RESPONSE_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.STBY_CR_DYN_ADDR_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.STBY_CR_ACCEPT_NACKED_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.STBY_CR_ACCEPT_OK_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.STBY_CR_ACCEPT_ERR_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.STBY_CR_OP_RSTACT_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.CCC_PARAM_MODIFIED_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.CCC_UNHANDLED_NACK_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_SIGNAL_ENABLE.CCC_FATAL_RSTDAA_ERR_SIGNAL_EN.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.CRR_RESPONSE_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.STBY_CR_DYN_ADDR_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.STBY_CR_ACCEPT_NACKED_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.STBY_CR_ACCEPT_OK_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.STBY_CR_ACCEPT_ERR_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.STBY_CR_OP_RSTACT_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.CCC_PARAM_MODIFIED_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.CCC_UNHANDLED_NACK_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_INTR_FORCE.CCC_FATAL_RSTDAA_ERR_FORCE.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_GETCAPS.F2_CRCAP1_BUS_CONFIG.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_GETCAPS.F2_CRCAP2_DEV_INTERACT.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_RSTACT_PARAMS.RESET_TIME_PERIPHERAL.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_RSTACT_PARAMS.RESET_TIME_TARGET.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_RSTACT_PARAMS.RESET_DYNAMIC_ADDR.next = '0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CCC_CONFIG_RSTACT_PARAMS.RESET_DYNAMIC_ADDR.we = '0;

    hwif_in.I3C_EC.CtrlCfg.CONTROLLER_CONFIG.OPERATION_MODE.we = '0;

    hwif_in.I3CBase.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR_VALID.we = '0;
    hwif_in.I3CBase.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR.we = '0;
    hwif_in.I3CBase.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR_VALID.next = '0;
    hwif_in.I3CBase.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR.next = '0;
    hwif_in.I3CBase.HC_CONTROL.RESUME.we = '0;
    hwif_in.I3CBase.HC_CONTROL.RESUME.next = '0;
    hwif_in.I3CBase.HC_CONTROL.BUS_ENABLE.we = '0;
    hwif_in.I3CBase.HC_CONTROL.BUS_ENABLE.next = '0;
    hwif_in.I3CBase.RESET_CONTROL.SOFT_RST.we = '0;
    hwif_in.I3CBase.RESET_CONTROL.SOFT_RST.next = '0;
    hwif_in.I3CBase.PRESENT_STATE.AC_CURRENT_OWN.next = '0;
    hwif_in.I3CBase.INTR_STATUS.HC_INTERNAL_ERR_STAT.next = '0;
    hwif_in.I3CBase.INTR_STATUS.HC_SEQ_CANCEL_STAT.next = '0;
    hwif_in.I3CBase.INTR_STATUS.HC_WARN_CMD_SEQ_STALL_STAT.next = '0;
    hwif_in.I3CBase.INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT.next = '0;
    hwif_in.I3CBase.INTR_STATUS.SCHED_CMD_MISSED_TICK_STAT.next = '0;
    hwif_in.I3CBase.DCT_SECTION_OFFSET.TABLE_INDEX.we = '0;
    hwif_in.I3CBase.DCT_SECTION_OFFSET.TABLE_INDEX.next = '0;
    hwif_in.I3CBase.IBI_DATA_ABORT_CTRL.IBI_DATA_ABORT_MON.we = '0;
    hwif_in.I3CBase.IBI_DATA_ABORT_CTRL.IBI_DATA_ABORT_MON.next = '0;

    hwif_in.PIOControl.PIO_INTR_STATUS.TX_THLD_STAT.next = '0;
    hwif_in.PIOControl.PIO_INTR_STATUS.RX_THLD_STAT.next = '0;
    hwif_in.PIOControl.PIO_INTR_STATUS.IBI_STATUS_THLD_STAT.next = '0;
    hwif_in.PIOControl.PIO_INTR_STATUS.CMD_QUEUE_READY_STAT.next = '0;
    hwif_in.PIOControl.PIO_INTR_STATUS.RESP_READY_STAT.next = '0;
    hwif_in.PIOControl.PIO_INTR_STATUS.TRANSFER_ABORT_STAT.next = '0;
    hwif_in.PIOControl.PIO_INTR_STATUS.TRANSFER_ERR_STAT.next = '0;
  end

    `I3C_ASSERT(CMD_WR_ACK_O, rst_ni |-> cmd_wr_ack == 1'b0);
    `I3C_ASSERT(HCI_IBI_RD_ACK_O, rst_ni |-> hci_ibi_rd_ack == 1'b0);
    `I3C_ASSERT(RESP_RD_ACK_O, rst_ni |-> resp_rd_ack == 1'b0);
    `I3C_ASSERT(RX_RD_ACK_O, rst_ni |-> rx_rd_ack == 1'b0);
    `I3C_ASSERT(TX_WR_ACK_O, rst_ni |-> tx_wr_ack == 1'b0);
    `I3C_ASSERT(IBI_QUEUE_DATA_O, rst_ni |-> hci_ibi_rd_data == '0);
    `I3C_ASSERT(RX_DESC_DATA_O, rst_ni |-> resp_rd_data == '0);

endmodule : hci
