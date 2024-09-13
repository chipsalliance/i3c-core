// SPDX-License-Identifier: Apache-2.0

// TODO: Consider arbitration difference from i2c:
// Section 5.1.4
// 48b provisioned id and bcr, dcr are used.
// This is to enable dynamic addressing.

module controller
  import controller_pkg::*;
  import i3c_pkg::*;
#(
    parameter int unsigned DatAw = i3c_pkg::DatAw,
    parameter int unsigned DctAw = i3c_pkg::DctAw,

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

    parameter int unsigned TtiRxDescDataWidth = 32,
    parameter int unsigned TtiTxDescDataWidth = 32,
    parameter int unsigned TtiRxDataWidth = 8,
    parameter int unsigned TtiTxDataWidth = 8,
    parameter int unsigned TtiIbiDataWidth = 32,

    parameter int unsigned TtiRxDescThldWidth = 8,
    parameter int unsigned TtiTxDescThldWidth = 8,
    parameter int unsigned TtiRxThldWidth = 3,
    parameter int unsigned TtiTxThldWidth = 3,
    parameter int unsigned TtiIbiThldWidth = 8
) (
    input logic clk_i,
    input logic rst_ni,

    // Interface to SDA/SCL
    input  logic scl_i,
    input  logic sda_i,
    output logic scl_o,
    output logic sda_o,
    output logic sel_od_pp_o,

    // HCI queues
    // Command FIFO
    input logic hci_cmd_queue_full_i,
    input logic [HciCmdThldWidth-1:0] hci_cmd_queue_ready_thld_i,
    input logic hci_cmd_queue_ready_thld_trig_i,
    input logic hci_cmd_queue_empty_i,
    input logic hci_cmd_queue_rvalid_i,
    output logic hci_cmd_queue_rready_o,
    input logic [HciCmdDataWidth-1:0] hci_cmd_queue_rdata_i,
    // RX FIFO
    input logic hci_rx_queue_full_i,
    input logic [HciRxThldWidth-1:0] hci_rx_queue_start_thld_i,
    input logic hci_rx_queue_start_thld_trig_i,
    input logic [HciRxThldWidth-1:0] hci_rx_queue_ready_thld_i,
    input logic hci_rx_queue_ready_thld_trig_i,
    input logic hci_rx_queue_empty_i,
    output logic hci_rx_queue_wvalid_o,
    input logic hci_rx_queue_wready_i,
    output logic [HciRxDataWidth-1:0] hci_rx_queue_wdata_o,
    // TX FIFO
    input logic hci_tx_queue_full_i,
    input logic [HciTxThldWidth-1:0] hci_tx_queue_start_thld_i,
    input logic hci_tx_queue_start_thld_trig_i,
    input logic [HciTxThldWidth-1:0] hci_tx_queue_ready_thld_i,
    input logic hci_tx_queue_ready_thld_trig_i,
    input logic hci_tx_queue_empty_i,
    input logic hci_tx_queue_rvalid_i,
    output logic hci_tx_queue_rready_o,
    input logic [HciTxDataWidth-1:0] hci_tx_queue_rdata_i,
    // Response FIFO
    input logic hci_resp_queue_full_i,
    input logic [HciRespThldWidth-1:0] hci_resp_queue_ready_thld_i,
    input logic hci_resp_queue_ready_thld_trig_i,
    input logic hci_resp_queue_empty_i,
    output logic hci_resp_queue_wvalid_o,
    input logic hci_resp_queue_wready_i,
    output logic [HciRespDataWidth-1:0] hci_resp_queue_wdata_o,

    // Target Transaction Interface

    // TTI: RX Descriptor
    input logic tti_rx_desc_queue_full_i,
    input logic [TtiRxDescThldWidth-1:0] tti_rx_desc_queue_ready_thld_i,
    input logic tti_rx_desc_queue_ready_thld_trig_i,
    input logic tti_rx_desc_queue_empty_i,
    output logic tti_rx_desc_queue_wvalid_o,
    input logic tti_rx_desc_queue_wready_i,
    output logic [TtiRxDescDataWidth-1:0] tti_rx_desc_queue_wdata_o,

    // TTI: TX Descriptor
    input logic tti_tx_desc_queue_full_i,
    input logic [TtiTxDescThldWidth-1:0] tti_tx_desc_queue_ready_thld_i,
    input logic tti_tx_desc_queue_ready_thld_trig_i,
    input logic tti_tx_desc_queue_empty_i,
    input logic tti_tx_desc_queue_rvalid_i,
    output logic tti_tx_desc_queue_rready_o,
    input logic [TtiTxDescDataWidth-1:0] tti_tx_desc_queue_rdata_i,

    // TTI: RX Data
    input logic tti_rx_queue_full_i,
    input logic [TtiRxThldWidth-1:0] tti_rx_queue_start_thld_i,
    input logic tti_rx_queue_start_thld_trig_i,
    input logic [TtiRxThldWidth-1:0] tti_rx_queue_ready_thld_i,
    input logic tti_rx_queue_ready_thld_trig_i,
    input logic tti_rx_queue_empty_i,
    output logic tti_rx_queue_wvalid_o,
    input logic tti_rx_queue_wready_i,
    output logic [TtiRxDataWidth-1:0] tti_rx_queue_wdata_o,

    // TTI: TX Data
    input logic tti_tx_queue_full_i,
    input logic [TtiTxThldWidth-1:0] tti_tx_queue_start_thld_i,
    input logic tti_tx_queue_start_thld_trig_i,
    input logic [TtiTxThldWidth-1:0] tti_tx_queue_ready_thld_i,
    input logic tti_tx_queue_ready_thld_trig_i,
    input logic tti_tx_queue_empty_i,
    input logic tti_tx_queue_rvalid_i,
    output logic tti_tx_queue_rready_o,
    input logic [TtiTxDataWidth-1:0] tti_tx_queue_rdata_i,

    // In-band Interrupt queue
    input logic ibi_queue_full_i,
    input logic [HciIbiThldWidth-1:0] ibi_queue_thld_i,
    input logic ibi_queue_above_thld_i,
    input logic ibi_queue_empty_i,
    output logic ibi_queue_wvalid_o,
    input logic ibi_queue_wready_i,
    output logic [HciIbiDataWidth-1:0] ibi_queue_wdata_o,

    // DAT <-> Controller interface
    output logic             dat_read_valid_hw_o,
    output logic [DatAw-1:0] dat_index_hw_o,
    input  logic [     63:0] dat_rdata_hw_i,

    // DCT <-> Controller interface
    output logic             dct_write_valid_hw_o,
    output logic             dct_read_valid_hw_o,
    output logic [DctAw-1:0] dct_index_hw_o,
    output logic [    127:0] dct_wdata_hw_o,
    input  logic [    127:0] dct_rdata_hw_i,

    input  logic i3c_fsm_en_i,
    output logic i3c_fsm_idle_o,

    // Errors and Interrupts
    output i3c_err_t err,
    output i3c_irq_t irq,

    // Configuration
    input logic phy_en_i,
    input logic [1:0] phy_mux_select_i,
    input logic i2c_active_en_i,
    input logic i2c_standby_en_i,
    input logic i3c_active_en_i,
    input logic i3c_standby_en_i,
    input logic [19:0] t_hd_dat_i,
    input logic [19:0] t_su_dat_i,
    input logic [19:0] t_r_i,
    input logic [19:0] t_bus_free_i,
    input logic [19:0] t_bus_idle_i,
    input logic [19:0] t_bus_available_i
);

  // 4:1 multiplexer for signals between PHY and controllers.
  // Needed, because there are 4 controllers in the design (i2c/i3c + active/standby).
  logic ctrl_scl_i[4];
  logic ctrl_sda_i[4];
  logic ctrl_scl_o[4];
  logic ctrl_sda_o[4];
  logic ctrl_sel_od_pp_i[4];

  always_comb begin : mux_4_to_1
    scl_o = ctrl_scl_o[phy_mux_select_i];
    sda_o = ctrl_sda_o[phy_mux_select_i];
    ctrl_scl_i[phy_mux_select_i] = scl_i;
    ctrl_sda_i[phy_mux_select_i] = sda_i;
    sel_od_pp_o = ctrl_sel_od_pp_i[phy_mux_select_i];
  end

  // Active controller
  controller_active xcontroller_active (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .ctrl_scl_i(ctrl_scl_i[0:1]),
      .ctrl_sda_i(ctrl_sda_i[0:1]),
      .ctrl_scl_o(ctrl_scl_o[0:1]),
      .ctrl_sda_o(ctrl_sda_o[0:1]),
      .phy_sel_od_pp_o(ctrl_sel_od_pp_i[0:1]),
      .cmd_queue_full_i(hci_cmd_queue_full_i),
      .cmd_queue_ready_thld_i(hci_cmd_queue_ready_thld_i),
      .cmd_queue_ready_thld_trig_i(hci_cmd_queue_ready_thld_trig_i),
      .cmd_queue_empty_i(hci_cmd_queue_empty_i),
      .cmd_queue_rvalid_i(hci_cmd_queue_rvalid_i),
      .cmd_queue_rready_o(hci_cmd_queue_rready_o),
      .cmd_queue_rdata_i(hci_cmd_queue_rdata_i),
      .rx_queue_full_i(hci_rx_queue_full_i),
      .rx_queue_start_thld_i(hci_rx_queue_start_thld_i),
      .rx_queue_start_thld_trig_i(hci_rx_queue_start_thld_trig_i),
      .rx_queue_ready_thld_i(hci_rx_queue_ready_thld_i),
      .rx_queue_ready_thld_trig_i(hci_rx_queue_ready_thld_trig_i),
      .rx_queue_empty_i(hci_rx_queue_empty_i),
      .rx_queue_wvalid_o(hci_rx_queue_wvalid_o),
      .rx_queue_wready_i(hci_rx_queue_wready_i),
      .rx_queue_wdata_o(hci_rx_queue_wdata_o),
      .tx_queue_full_i(hci_tx_queue_full_i),
      .tx_queue_start_thld_i(hci_tx_queue_start_thld_i),
      .tx_queue_start_thld_trig_i(hci_tx_queue_start_thld_trig_i),
      .tx_queue_ready_thld_i(hci_tx_queue_ready_thld_i),
      .tx_queue_ready_thld_trig_i(hci_tx_queue_ready_thld_trig_i),
      .tx_queue_empty_i(hci_tx_queue_empty_i),
      .tx_queue_rvalid_i(hci_tx_queue_rvalid_i),
      .tx_queue_rready_o(hci_tx_queue_rready_o),
      .tx_queue_rdata_i(hci_tx_queue_rdata_i),
      .resp_queue_full_i(hci_resp_queue_full_i),
      .resp_queue_ready_thld_i(hci_resp_queue_ready_thld_i),
      .resp_queue_ready_thld_trig_i(hci_resp_queue_ready_thld_trig_i),
      .resp_queue_empty_i(hci_resp_queue_empty_i),
      .resp_queue_wvalid_o(hci_resp_queue_wvalid_o),
      .resp_queue_wready_i(hci_resp_queue_wready_i),
      .resp_queue_wdata_o(hci_resp_queue_wdata_o),
      .ibi_queue_full_i,
      .ibi_queue_thld_i,
      .ibi_queue_above_thld_i,
      .ibi_queue_empty_i,
      .ibi_queue_wvalid_o,
      .ibi_queue_wready_i,
      .ibi_queue_wdata_o,
      .dat_read_valid_hw_o(dat_read_valid_hw_o),
      .dat_index_hw_o(dat_index_hw_o),
      .dat_rdata_hw_i(dat_rdata_hw_i),
      .dct_write_valid_hw_o(dct_write_valid_hw_o),
      .dct_read_valid_hw_o(dct_read_valid_hw_o),
      .dct_index_hw_o(dct_index_hw_o),
      .dct_wdata_hw_o(dct_wdata_hw_o),
      .dct_rdata_hw_i(dct_rdata_hw_i),
      .i3c_fsm_en_i(i3c_fsm_en_i),
      .i3c_fsm_idle_o(i3c_fsm_idle_o),
      .err(err),
      .irq(irq),
      .phy_en_i(phy_en_i),
      .phy_mux_select_i(phy_mux_select_i),
      .i2c_active_en_i(i2c_active_en_i),
      .i2c_standby_en_i(i2c_standby_en_i),
      .i3c_active_en_i(i3c_active_en_i),
      .i3c_standby_en_i(i3c_standby_en_i),
      .t_hd_dat_i(t_hd_dat_i),
      .t_r_i(t_r_i),
      .t_bus_free_i(t_bus_free_i),
      .t_bus_idle_i(t_bus_idle_i),
      .t_bus_available_i(t_bus_available_i)
  );

  // Standby (Secondary) Controller
  controller_standby xcontroller_standby (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .ctrl_scl_i(ctrl_scl_i[2:3]),
      .ctrl_sda_i(ctrl_sda_i[2:3]),
      .ctrl_scl_o(ctrl_scl_o[2:3]),
      .ctrl_sda_o(ctrl_sda_o[2:3]),
      .phy_sel_od_pp_o(ctrl_sel_od_pp_i[2:3]),
      .rx_desc_queue_full_i(tti_rx_desc_queue_full_i),
      .rx_desc_queue_ready_thld_i(tti_rx_desc_queue_ready_thld_i),
      .rx_desc_queue_ready_thld_trig_i(tti_rx_desc_queue_ready_thld_trig_i),
      .rx_desc_queue_empty_i(tti_rx_desc_queue_empty_i),
      .rx_desc_queue_wvalid_o(tti_rx_desc_queue_wvalid_o),
      .rx_desc_queue_wready_i(tti_rx_desc_queue_wready_i),
      .rx_desc_queue_wdata_o(tti_rx_desc_queue_wdata_o),
      .tx_desc_queue_full_i(tti_tx_desc_queue_full_i),
      .tx_desc_queue_ready_thld_i(tti_tx_desc_queue_ready_thld_i),
      .tx_desc_queue_ready_thld_trig_i(tti_tx_desc_queue_ready_thld_trig_i),
      .tx_desc_queue_empty_i(tti_tx_desc_queue_empty_i),
      .tx_desc_queue_rvalid_i(tti_tx_desc_queue_rvalid_i),
      .tx_desc_queue_rready_o(tti_tx_desc_queue_rready_o),
      .tx_desc_queue_rdata_i(tti_tx_desc_queue_rdata_i),
      .rx_queue_full_i(tti_rx_queue_full_i),
      .rx_queue_start_thld_i(tti_rx_queue_start_thld_i),
      .rx_queue_start_thld_trig_i(tti_rx_queue_start_thld_trig_i),
      .rx_queue_ready_thld_i(tti_rx_queue_ready_thld_i),
      .rx_queue_ready_thld_trig_i(tti_rx_queue_ready_thld_trig_i),
      .rx_queue_empty_i(tti_rx_queue_empty_i),
      .rx_queue_wvalid_o(tti_rx_queue_wvalid_o),
      .rx_queue_wready_i(tti_rx_queue_wready_i),
      .rx_queue_wdata_o(tti_rx_queue_wdata_o),
      .tx_queue_full_i(tti_tx_queue_full_i),
      .tx_queue_start_thld_i(tti_tx_queue_start_thld_i),
      .tx_queue_start_thld_trig_i(tti_tx_queue_start_thld_trig_i),
      .tx_queue_ready_thld_i(tti_tx_queue_ready_thld_i),
      .tx_queue_ready_thld_trig_i(tti_tx_queue_ready_thld_trig_i),
      .tx_queue_empty_i(tti_tx_queue_empty_i),
      .tx_queue_rvalid_i(tti_tx_queue_rvalid_i),
      .tx_queue_rready_o(tti_tx_queue_rready_o),
      .tx_queue_rdata_i(tti_tx_queue_rdata_i),
      .phy_en_i(phy_en_i),
      .phy_mux_select_i(phy_mux_select_i),
      .i2c_active_en_i(i2c_active_en_i),
      .i2c_standby_en_i(i2c_standby_en_i),
      .i3c_active_en_i(i3c_active_en_i),
      .i3c_standby_en_i(i3c_standby_en_i),
      .t_su_dat_i(t_su_dat_i),
      .t_hd_dat_i(t_hd_dat_i),
      .t_r_i(t_r_i),
      .t_bus_free_i(t_bus_free_i),
      .t_bus_idle_i(t_bus_idle_i),
      .t_bus_available_i(t_bus_available_i)
  );

endmodule
