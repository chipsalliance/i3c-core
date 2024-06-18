// SPDX-License-Identifier: Apache-2.0

module controller_standby
  import controller_pkg::*;
  import i3c_pkg::*;
  import hci_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    // Interface to SDA/SCL
    input  logic ctrl_scl_i[2],
    input  logic ctrl_sda_i[2],
    output logic ctrl_scl_o[2],
    output logic ctrl_sda_o[2]
);


  logic controller_mode_i;
  logic bus_mode_i;
  logic bus_enable_i;
  logic controller_enable_i;
  logic det_start_i;
  logic addr_match_i;
  logic i3c_rsvd_byte_i;
  logic det_rnw_i;
  logic rnw_i;
  logic det_stop_i;
  logic det_rstart_i;
  logic det_ack_i;
  logic det_tbit_i;
  logic tbit_i;
  logic byte_valid_i;
  logic byte_i;
  logic byte_valid_o;
  logic terminate_force_i;
  logic terminate_soft_i;
  logic terminate_complete_o;

  flow_standby xflow_standby (
      .clk_i,
      .rst_ni,

      .controller_mode_i,
      .bus_mode_i,
      .bus_enable_i,
      .controller_enable_i,

      .det_start_i,
      .addr_match_i,
      .i3c_rsvd_byte_i,
      .det_rnw_i,
      .rnw_i,
      .det_stop_i,
      .det_rstart_i,
      .det_ack_i,
      .det_tbit_i,
      .tbit_i,
      .byte_valid_i,
      .byte_i,
      .byte_valid_o,

      .terminate_force_i,
      .terminate_soft_i,
      .terminate_complete_o
  );

  // TODO: fix parameter hierarchy
  parameter int AcqFifoDepth = 64;
  parameter int AcqFifoDepthWidth = $clog2(AcqFifoDepth + 1);

  logic                         i2c_target_enable_i;
  logic                         i2c_tx_fifo_rvalid_i;
  logic                         i2c_tx_fifo_rready_o;
  logic [    TX_FIFO_WIDTH-1:0] i2c_tx_fifo_rdata_i;
  logic                         i2c_acq_fifo_wvalid_o;
  logic [   ACQ_FIFO_WIDTH-1:0] i2c_acq_fifo_wdata_o;
  logic [AcqFifoDepthWidth-1:0] i2c_acq_fifo_depth_i;
  logic                         i2c_acq_fifo_wready_o;
  logic [   ACQ_FIFO_WIDTH-1:0] i2c_acq_fifo_rdata_i;
  logic                         i2c_target_idle_o;
  logic [                 15:0] i2c_t_r_i;
  logic [                 15:0] i2c_tsu_dat_i;
  logic [                 15:0] i2c_thd_dat_i;
  logic [                 31:0] i2c_host_timeout_i;
  logic [                 30:0] i2c_nack_timeout_i;
  logic                         i2c_nack_timeout_en_i;
  logic [                  6:0] i2c_target_address0_i;
  logic [                  6:0] i2c_target_mask0_i;
  logic [                  6:0] i2c_target_address1_i;
  logic [                  6:0] i2c_target_mask1_i;
  logic                         i2c_target_sr_p_cond_o;
  logic                         i2c_event_target_nack_o;
  logic                         i2c_event_cmd_complete_o;
  logic                         i2c_event_tx_stretch_o;
  logic                         i2c_event_unexp_stop_o;
  logic                         i2c_event_host_timeout_o;


  i2c_target_fsm xi2c_target_fsm (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .scl_i(ctrl_scl_i[0]),
      .scl_o(ctrl_scl_o[0]),
      .sda_i(ctrl_sda_i[0]),
      .sda_o(ctrl_sda_o[0]),
      .target_enable_i(i2c_target_enable_i),
      .tx_fifo_rvalid_i(i2c_tx_fifo_rvalid_i),
      .tx_fifo_rready_o(i2c_tx_fifo_rready_o),
      .tx_fifo_rdata_i(i2c_tx_fifo_rdata_i),
      .acq_fifo_wvalid_o(i2c_acq_fifo_wvalid_o),
      .acq_fifo_wdata_o(i2c_acq_fifo_wdata_o),
      .acq_fifo_depth_i(i2c_acq_fifo_depth_i),
      .acq_fifo_wready_o(i2c_acq_fifo_wready_o),
      .acq_fifo_rdata_i(i2c_acq_fifo_rdata_i),
      .target_idle_o(i2c_target_idle_o),
      .t_r_i(i2c_t_r_i),
      .tsu_dat_i(i2c_tsu_dat_i),
      .thd_dat_i(i2c_thd_dat_i),
      .host_timeout_i(i2c_host_timeout_i),
      .nack_timeout_i(i2c_nack_timeout_i),
      .nack_timeout_en_i(i2c_nack_timeout_en_i),
      .target_address0_i(i2c_target_address0_i),
      .target_mask0_i(i2c_target_mask0_i),
      .target_address1_i(i2c_target_address1_i),
      .target_mask1_i(i2c_target_mask1_i),
      .target_sr_p_cond_o(i2c_target_sr_p_cond_o),
      .event_target_nack_o(i2c_event_target_nack_o),
      .event_cmd_complete_o(i2c_event_cmd_complete_o),
      .event_tx_stretch_o(i2c_event_tx_stretch_o),
      .event_unexp_stop_o(i2c_event_unexp_stop_o),
      .event_host_timeout_o(i2c_event_host_timeout_o)
  );

  logic                         i3c_start_detect_i;
  logic                         i3c_stop_detect_i;
  logic                         i3c_transmitting_o;
  logic                         i3c_target_enable_i;
  logic                         i3c_tx_fifo_rvalid_i;
  logic                         i3c_tx_fifo_rready_o;
  logic [    TX_FIFO_WIDTH-1:0] i3c_tx_fifo_rdata_i;
  logic                         i3c_acq_fifo_wvalid_o;
  logic [   ACQ_FIFO_WIDTH-1:0] i3c_acq_fifo_wdata_o;
  logic [AcqFifoDepthWidth-1:0] i3c_acq_fifo_depth_i;
  logic                         i3c_acq_fifo_full_o;
  logic                         i3c_target_idle_o;
  logic [                 12:0] i3c_t_r_i;
  logic [                 12:0] i3c_tsu_dat_i;
  logic [                 12:0] i3c_thd_dat_i;
  logic                         i3c_arbitration_lost_i;
  logic                         i3c_bus_timeout_i;
  logic [                  6:0] i3c_target_address0_i;
  logic [                  6:0] i3c_target_mask0_i;
  logic [                  6:0] i3c_target_address1_i;
  logic [                  6:0] i3c_target_mask1_i;
  logic                         i3c_event_target_nack_o;
  logic                         i3c_event_cmd_complete_o;
  logic                         i3c_event_unexp_stop_o;
  logic                         i3c_event_tx_arbitration_lost_o;
  logic                         i3c_event_tx_bus_timeout_o;
  logic                         i3c_event_read_cmd_received_o;
  logic                         i3c_target_internal_state;

  i3c_target_fsm xi3c_target_fsm (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .scl_i(ctrl_scl_i[1]),
      .scl_o(ctrl_scl_o[1]),
      .sda_i(ctrl_sda_i[1]),
      .sda_o(ctrl_sda_o[1]),

      .start_detect_i(i3c_start_detect_i),
      .stop_detect_i(i3c_stop_detect_i),
      .transmitting_o(i3c_transmitting_o),
      .target_enable_i(i3c_target_enable_i),
      .tx_fifo_rvalid_i(i3c_tx_fifo_rvalid_i),
      .tx_fifo_rready_o(i3c_tx_fifo_rready_o),
      .tx_fifo_rdata_i(i3c_tx_fifo_rdata_i),
      .acq_fifo_wvalid_o(i3c_acq_fifo_wvalid_o),
      .acq_fifo_wdata_o(i3c_acq_fifo_wdata_o),
      .acq_fifo_depth_i(i3c_acq_fifo_depth_i),
      .acq_fifo_full_o(i3c_acq_fifo_full_o),
      .target_idle_o(i3c_target_idle_o),
      .t_r_i(i3c_t_r_i),
      .tsu_dat_i(i3c_tsu_dat_i),
      .thd_dat_i(i3c_thd_dat_i),
      .arbitration_lost_i(i3c_arbitration_lost_i),
      .bus_timeout_i(i3c_bus_timeout_i),
      .target_address0_i(i3c_target_address0_i),
      .target_mask0_i(i3c_target_mask0_i),
      .target_address1_i(i3c_target_address1_i),
      .target_mask1_i(i3c_target_mask1_i),
      .event_target_nack_o(i3c_event_target_nack_o),
      .event_cmd_complete_o(i3c_event_cmd_complete_o),
      .event_unexp_stop_o(i3c_event_unexp_stop_o),
      .event_tx_arbitration_lost_o(i3c_event_tx_arbitration_lost_o),
      .event_tx_bus_timeout_o(i3c_event_tx_bus_timeout_o),
      .event_read_cmd_received_o(i3c_event_read_cmd_received_o),
      .target_internal_state(i3c_target_internal_state)
  );

endmodule
