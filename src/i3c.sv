// SPDX-License-Identifier: Apache-2.0

module i3c
  import i3c_pkg::*;
  import i2c_pkg::*;
  import I3CCSR_pkg::*;
#(
    parameter int unsigned AHB_DATA_WIDTH = 64,
    parameter int unsigned AHB_ADDR_WIDTH = 32,
    parameter int unsigned AHB_BURST_WIDTH = 3,
    parameter int FifoDepth = 64,
    parameter int AcqFifoDepth = 64,
    localparam int FifoDepthWidth = $clog2(FifoDepth + 1),
    localparam int AcqFifoDepthWidth = $clog2(AcqFifoDepth + 1),
    parameter DAT_SIZE = 128,
    parameter DCT_SIZE = 128
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

`ifdef I3C_USE_AHB
    // AHB-Lite interface
    // Byte address of the transfer
    input  logic [  AHB_ADDR_WIDTH-1:0] haddr_i,
    // Indicates the number of bursts in a transfer
    input  logic [ AHB_BURST_WIDTH-1:0] hburst_i,     // Unhandled
    // Protection control; provides information on the access type
    input  logic [                 3:0] hprot_i,      // Unhandled
    // Indicates the size of the transfer
    input  logic [                 2:0] hsize_i,
    // Indicates the transfer type
    input  logic [                 1:0] htrans_i,
    // Data for the write operation
    input  logic [  AHB_DATA_WIDTH-1:0] hwdata_i,
    // Write strobes; Deasserted when write data lanes do not contain valid data
    input  logic [AHB_DATA_WIDTH/8-1:0] hwstrb_i,     // Unhandled
    // Indicates write operation when asserted
    input  logic                        hwrite_i,
    // Read data
    output logic [  AHB_DATA_WIDTH-1:0] hrdata_o,
    // Assrted indicates a finished transfer; Can be driven low to extend a transfer
    output logic                        hreadyout_o,
    // Transfer response, high when error occured
    output logic                        hresp_o,
    // Indicates the subordinate is selected for the transfer
    input  logic                        hsel_i,
    // Indicates all subordiantes have finished transfers
    input  logic                        hready_i,
    // TODO: AXI4 I/O
    // `else
`endif

    // I3C bus IO
    input        i3c_scl_i,    // serial clock input from i3c bus
    output logic i3c_scl_o,    // serial clock output to i3c bus
    output logic i3c_scl_en_o, // serial clock output to i3c bus

    input        i3c_sda_i,    // serial data input from i3c bus
    output logic i3c_sda_o,    // serial data output to i3c bus
    output logic i3c_sda_en_o  // serial data output to i3c bus

    // TODO: Check if anything missing; Interrupts?
);

  // IOs between PHY and I3C bus
  logic scl_o;
  logic scl_en_o;

  logic sda_o;
  logic sda_en_o;

  logic ctrl2phy_scl;
  logic phy2ctrl_scl;
  logic ctrl2phy_sda;
  logic phy2ctrl_sda;

  // I3C SW CSR IF
  logic s_cpuif_req;
  logic s_cpuif_req_is_wr;
  logic [I3CCSR_MIN_ADDR_WIDTH-1:0] s_cpuif_addr;
  logic [I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_data;
  logic [I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_biten;
  logic s_cpuif_req_stall_wr;
  logic s_cpuif_req_stall_rd;
  logic s_cpuif_rd_ack;
  logic s_cpuif_rd_err;
  logic [I3CCSR_DATA_WIDTH-1:0] s_cpuif_rd_data;
  logic s_cpuif_wr_ack;
  logic s_cpuif_wr_err;

`ifdef I3C_USE_AHB
  ahb_if #(
      .AHB_DATA_WIDTH (AHB_DATA_WIDTH),
      .AHB_ADDR_WIDTH (AHB_ADDR_WIDTH),
      .AHB_BURST_WIDTH(AHB_BURST_WIDTH)
  ) i3c_ahb_if (
      .hclk_i(clk_i),
      .hreset_n_i(rst_ni),
      .haddr_i(haddr_i),
      .hburst_i(hburst_i),
      .hprot_i(hprot_i),
      .hsize_i(hsize_i),
      .htrans_i(htrans_i),
      .hwdata_i(hwdata_i),
      .hwstrb_i(hwstrb_i),
      .hwrite_i(hwrite_i),
      .hrdata_o(hrdata_o),
      .hreadyout_o(hreadyout_o),
      .hresp_o(hresp_o),
      .hsel_i(hsel_i),
      .hready_i(hready_i),
      .s_cpuif_req(s_cpuif_req),
      .s_cpuif_req_is_wr(s_cpuif_req_is_wr),
      .s_cpuif_addr(s_cpuif_addr),
      .s_cpuif_wr_data(s_cpuif_wr_data),
      .s_cpuif_wr_biten(s_cpuif_wr_biten),
      .s_cpuif_req_stall_wr(s_cpuif_req_stall_wr),
      .s_cpuif_req_stall_rd(s_cpuif_req_stall_rd),
      .s_cpuif_rd_ack(s_cpuif_rd_ack),
      .s_cpuif_rd_err(s_cpuif_rd_err),
      .s_cpuif_rd_data(s_cpuif_rd_data),
      .s_cpuif_wr_ack(s_cpuif_wr_ack),
      .s_cpuif_wr_err(s_cpuif_wr_err)
  );
  // TODO: AXI4 I/O
  // `else
`endif

    // DAT <-> Controller interface
    logic                        dat_read_valid_hw_i;
    logic [$clog2(DAT_SIZE)-1:0] dat_index_hw_i;
    logic [                63:0] dat_rdata_hw_o;

    // DCT <-> Controller interface
    logic                        dct_write_valid_hw_i;
    logic                        dct_read_valid_hw_i;
    logic [$clog2(DCT_SIZE)-1:0] dct_index_hw_i;
    logic [               127:0] dct_wdata_hw_i;
    logic [               127:0] dct_rdata_hw_o;

  hci hci (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .s_cpuif_req(s_cpuif_req),
      .s_cpuif_req_is_wr(s_cpuif_req_is_wr),
      .s_cpuif_addr(s_cpuif_addr),
      .s_cpuif_wr_data(s_cpuif_wr_data),
      .s_cpuif_wr_biten(s_cpuif_wr_biten),
      .s_cpuif_req_stall_wr(s_cpuif_req_stall_wr),
      .s_cpuif_req_stall_rd(s_cpuif_req_stall_rd),
      .s_cpuif_rd_ack(s_cpuif_rd_ack),
      .s_cpuif_rd_err(s_cpuif_rd_err),
      .s_cpuif_rd_data(s_cpuif_rd_data),
      .s_cpuif_wr_ack(s_cpuif_wr_ack),
      .s_cpuif_wr_err(s_cpuif_wr_err),

      .dat_read_valid_hw_i(dat_read_valid_hw_i),
      .dat_index_hw_i(dat_index_hw_i),
      .dat_rdata_hw_o(dat_rdata_hw_o),

      .dct_write_valid_hw_i(dct_write_valid_hw_i),
      .dct_read_valid_hw_i(dct_read_valid_hw_i),
      .dct_index_hw_i(dct_index_hw_i),
      .dct_wdata_hw_i(dct_wdata_hw_i),
      .dct_rdata_hw_o(dct_rdata_hw_o)
  );

  // TODO: Connect properly to i2c_controller_fsm
  // TODO: #57765 to be integrated here
  logic fmt_fifo_rvalid_i;  // indicates there is valid data in fmt_fifo
  logic [FifoDepthWidth-1:0] fmt_fifo_depth_i;  // fmt_fifo_depth
  logic fmt_fifo_rready_o;  // populates fmt_fifo
  logic [7:0] fmt_byte_i;  // byte in fmt_fifo to be sent to target
  logic fmt_flag_start_before_i;  // issue start before sending byte
  logic fmt_flag_stop_after_i;  // issue stop after sending byte
  logic fmt_flag_read_bytes_i;  // indicates byte is an number of reads
  logic fmt_flag_read_continue_i;  // host to send Ack to final byte read
  logic fmt_flag_nak_ok_i;  // no Ack is expected
  logic unhandled_unexp_nak_i;
  logic unhandled_nak_timeout_i;  // NACK handler timeout event not cleared

  logic rx_fifo_wvalid_o;  // high if there is valid data in rx_fifo
  logic [RX_FIFO_WIDTH-1:0] rx_fifo_wdata_o;  // byte in rx_fifo read from target

  logic host_idle_o;  // indicates the host is idle

  // TODO: Connect to timings calculated in #57632
  logic [15:0] thigh_i;  // high period of the SCL in clock units
  logic [15:0] tlow_i;  // low period of the SCL in clock units
  logic [15:0] t_r_i;  // rise time of both SDA and SCL in clock units
  logic [15:0] t_f_i;  // fall time of both SDA and SCL in clock units
  logic [15:0] thd_sta_i;  // hold time for (repeated) START in clock units
  logic [15:0] tsu_sta_i;  // setup time for repeated START in clock units
  logic [15:0] tsu_sto_i;  // setup time for STOP in clock units
  logic [15:0] tsu_dat_i;  // data setup time in clock units
  logic [15:0] thd_dat_i;  // data hold time in clock units
  logic [15:0] t_buf_i;  // bus free time between STOP and START in clock units
  logic [30:0] stretch_timeout_i;  // max time target connected to this host may stretch the clock
  logic timeout_enable_i;  // assert if target stretches clock past max
  logic [30:0] host_nack_handler_timeout_i;  // Timeout threshold for unhandled Host-Mode 'nak' irq.
  logic host_nack_handler_timeout_en_i;

  logic event_nak_o;  // target didn't Ack when expected
  logic event_unhandled_nak_timeout_o;  // SW didn't handle the NACK in time
  logic event_scl_interference_o;  // other device forcing SCL low
  logic event_sda_interference_o;  // other device forcing SDA low
  logic event_stretch_timeout_o;  // target stretches clock past max time
  logic event_sda_unstable_o;  // SDA is not constant during SCL pulse
  logic event_cmd_complete_o;  // Command is complete
  logic host_enable_i;  // enable host functionality

  i2c_controller_fsm i2c_controller_fsm (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .scl_i(phy2ctrl_scl),
      .scl_o(ctrl2phy_scl),
      .sda_i(phy2ctrl_sda),
      .sda_o(ctrl2phy_sda),

      .host_enable_i(host_enable_i),

      .fmt_fifo_rvalid_i(fmt_fifo_rvalid_i),
      .fmt_fifo_depth_i(fmt_fifo_depth_i),
      .fmt_fifo_rready_o(fmt_fifo_rready_o),
      .fmt_byte_i(fmt_byte_i),
      .fmt_flag_start_before_i(fmt_flag_start_before_i),
      .fmt_flag_stop_after_i(fmt_flag_stop_after_i),
      .fmt_flag_read_bytes_i(fmt_flag_read_bytes_i),
      .fmt_flag_read_continue_i(fmt_flag_read_continue_i),
      .fmt_flag_nak_ok_i(fmt_flag_nak_ok_i),
      .unhandled_unexp_nak_i(unhandled_unexp_nak_i),
      .unhandled_nak_timeout_i(unhandled_nak_timeout_i),

      .rx_fifo_wvalid_o(rx_fifo_wvalid_o),
      .rx_fifo_wdata_o (rx_fifo_wdata_o),

      .host_idle_o(host_idle_o),

      .thigh_i(thigh_i),
      .tlow_i(tlow_i),
      .t_r_i(t_r_i),
      .t_f_i(t_f_i),
      .thd_sta_i(thd_sta_i),
      .tsu_sta_i(tsu_sta_i),
      .tsu_sto_i(tsu_sto_i),
      .tsu_dat_i(tsu_dat_i),
      .thd_dat_i(thd_dat_i),
      .t_buf_i(t_buf_i),
      .stretch_timeout_i(stretch_timeout_i),
      .timeout_enable_i(timeout_enable_i),
      .host_nack_handler_timeout_i(host_nack_handler_timeout_i),
      .host_nack_handler_timeout_en_i(host_nack_handler_timeout_en_i),

      .event_nak_o(event_nak_o),
      .event_unhandled_nak_timeout_o(event_unhandled_nak_timeout_o),
      .event_scl_interference_o(event_scl_interference_o),
      .event_sda_interference_o(event_sda_interference_o),
      .event_stretch_timeout_o(event_stretch_timeout_o),
      .event_sda_unstable_o(event_sda_unstable_o),
      .event_cmd_complete_o(event_cmd_complete_o)
  );
  // End: Connect properly to i2c_controller_fsm

  // I3C PHY
  i3c_phy phy (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .scl_i(i3c_scl_i),
      .scl_o(i3c_scl_o),
      .scl_en_o(i3c_scl_en_o),

      .sda_i(i3c_sda_i),
      .sda_o(i3c_sda_o),
      .sda_en_o(i3c_sda_en_o),

      .ctrl_scl_i(ctrl2phy_scl),
      .ctrl_scl_o(phy2ctrl_scl),
      .ctrl_sda_i(ctrl2phy_sda),
      .ctrl_sda_o(phy2ctrl_sda)
  );
endmodule

