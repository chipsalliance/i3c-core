// SPDX-License-Identifier: Apache-2.0
// Description: Serializes byte from flow_active and transmitts it on the I3C
// bus.
// Limitations: Selecting Push-Pull mode vs Open-Drain mode is currently not
// supported

module i3c_controller_fsm
  import controller_pkg::*;
  import i3c_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    // Interface to SDA/SCL
    input logic ctrl_scl_i,
    input logic ctrl_sda_i,
    output logic ctrl_scl_o,
    output logic ctrl_sda_o,
    input bus_state_t ctrl_bus_i,

    // Timing constants
    input [i3c_pkg::TimingWidth-1:0] thigh_i,  // high period of the SCL in clock units
    input [i3c_pkg::TimingWidth-1:0] tlow_i,  // low period of the SCL in clock units
    input [i3c_pkg::TimingWidth-1:0] t_r_i,  // rise time of both SDA and SCL in clock units
    input [i3c_pkg::TimingWidth-1:0] t_f_i,  // fall time of both SDA and SCL in clock units
    input [i3c_pkg::TimingWidth-1:0] thd_sta_i,  // hold time for START in clock units
    input [i3c_pkg::TimingWidth-1:0] thd_rsta_i,  // hold time for repeated START in clock units
    input [i3c_pkg::TimingWidth-1:0] tsu_rsta_i,  // setup time for repeated START in clock units
    input [i3c_pkg::TimingWidth-1:0] tsu_sta_i,  // setup time for repeated START in clock units
    input [i3c_pkg::TimingWidth-1:0] tsu_sto_i,  // setup time for STOP in clock units
    input [i3c_pkg::TimingWidth-1:0] t_ds_od_i,  // setup time for SDA during START in clock units
    input [i3c_pkg::TimingWidth-1:0] tsu_dat_i,  // data setup time in clock units
    input [i3c_pkg::TimingWidth-1:0] thd_dat_i,  // data hold time in clock units
    input [i3c_pkg::TimingWidth-1:0] t_buf_i,  // bus free time between STOP and START in clock units

    //FMT Interface
    input  logic                         fmt_fifo_rvalid_i,
    input  logic [I2CFifoDepthWidth-1:0] fmt_fifo_depth_i,
    output logic                         fmt_fifo_rready_o,
    output logic                         fmt_fifo_rdone_o,
    input  logic [                  7:0] fmt_byte_i,
    input  logic                         fmt_bit_i,                 // T bit
    input  logic                         fmt_flag_start_before_i,
    input  logic                         fmt_flag_stop_after_i,
    input  logic                         fmt_flag_restart_after_i,
    output logic                         fmt_receive_nack_o,
    // fmt RX signals
    output logic [                  7:0] fmt_byte_o,
    output logic                         fmt_bit_o,                 // T bit
    input  logic                         fmt_flag_read_bytes_i,
    input  logic                         fmt_flag_read_continue_i,
    output logic                         fmt_flag_read_valid_o


);
  // State definition
  typedef enum logic [2:0] {
    Idle,
    Start,
    Address,
    BusTX,
    BusRX,
    ReStart,
    IBI,
    Stop
  } state_e;
  // Declare internal signals
  state_e state_d, state_q;

  logic tx_bit_q, tx_bit_d;

  // Bus SCL flow internal signals
  logic scl_negedge, scl_posedge, scl_stable_low, scl_stable_high;

  logic scl_enable, scl_stall;

  // Start stop generator internal signals
  logic start_before, stop_after_d, stop_after_q, repeated_start;
  logic start_done, stop_done, repeated_start_done;

  logic start_stop_scl, start_stop_sda;
  logic scl_flow_scl, tx_flow_sda;

  logic start_stop_active;

  logic received_nack_d, received_nack_q;
  assign fmt_receive_nack_o = received_nack_q | received_nack_d;  // instantly update fmt flag

  // TX signals
  logic [7:0] bus_tx_req_value;
  logic
      bus_tx_req_byte,
      bus_tx_req_bit,
      bus_tx_done,
      bus_tx_idle,
      bus_tx_req_err,
      bus_error,
      bus_tx_sel_od_pp;

  // RX signals
  logic [7:0] bus_rx_data, rx_byte_d, rx_byte_q;
  logic
      bus_rx_req_bit, bus_rx_req_bit_d, bus_rx_req_bit_q, bus_rx_req_byte, bus_rx_done, bus_rx_idle;

  // State Transition
  always_comb begin
    state_d = state_q;
    unique case (state_q)
      Idle: begin
        if (fmt_fifo_rvalid_i & fmt_flag_start_before_i) begin
          state_d = Start;
        end
      end
      Start: begin
        if (start_done) begin
          state_d = Address;
        end
      end
      Address: begin
        if (bus_rx_done & tx_bit_q) begin
          if (fmt_receive_nack_o) begin  // wait for SCL to finish cycle before switching state
            state_d = Stop;
          end else begin
            state_d = fmt_flag_read_bytes_i ? BusRX : BusTX;
          end
        end
      end
      BusTX: begin
        if (tx_bit_q & bus_tx_done & fmt_fifo_rvalid_i) begin  // only switch state when we have sent the T bit
          state_d = fmt_flag_stop_after_i ? Stop : (fmt_flag_restart_after_i ? ReStart : BusTX);
        end
      end
      BusRX: begin
        if (bus_rx_done & fmt_flag_read_bytes_i) begin
          state_d = fmt_flag_stop_after_i ? Stop : (fmt_flag_restart_after_i ? ReStart : BusRX);
        end
      end
      ReStart: begin
        if (repeated_start_done) begin
          state_d = Address;
        end
      end
      IBI: begin
        // TODO: implement
      end
      Stop: begin
        if (stop_done) begin
          state_d = Idle;
        end
      end
      default: begin
        state_d = Idle;
      end
    endcase

  end

  // Output Logic
  always_comb begin
    fmt_bit_o = 1'b0;
    fmt_byte_o = rx_byte_q;
    rx_byte_d = rx_byte_q;
    fmt_fifo_rready_o = 1'b0;
    fmt_fifo_rdone_o = 1'b0;
    fmt_flag_read_valid_o = 1'b0;
    received_nack_d = received_nack_q;
    start_before = 1'b0;
    stop_after_d = 1'b0;
    repeated_start = 1'b0;
    ctrl_sda_o = 1'b1;
    ctrl_scl_o = 1'b1;
    tx_bit_d = 1'b0;
    bus_tx_req_byte = 1'b0;
    bus_tx_req_bit = 1'b0;
    bus_tx_req_value = '0;
    bus_rx_req_byte = 1'b0;
    bus_rx_req_bit = 1'b0;
    bus_rx_req_bit_d = bus_rx_req_bit_q;
    scl_enable = ~start_stop_active;
    scl_stall = 1'b0;
    unique case (state_q)
      Idle: begin
        fmt_fifo_rready_o = 1'b1;
        scl_enable = 1'b0;
        received_nack_d = 1'b0;
      end
      Start: begin
        start_before = 1'b1;
        ctrl_sda_o   = start_stop_sda;
        ctrl_scl_o   = start_stop_scl;
      end
      Address: begin
        ctrl_sda_o = tx_flow_sda;
        ctrl_scl_o = scl_flow_scl;
        bus_rx_req_bit = 1'b0;

        if (tx_bit_q) begin
          tx_bit_d = 1'b1;
          //bus_tx_req_bit = 1'b1;

          //bus_tx_req_value = {7'b0, 1'b1};
          // Read bus to check for NACK
          bus_rx_req_bit = 1'b1;
          received_nack_d = bus_rx_data[0] & bus_rx_done;

          if (bus_rx_done) begin
            tx_bit_d = 1'b0;
            fmt_fifo_rdone_o = 1'b1;
          end
        end else begin
          bus_tx_req_byte  = 1'b1;
          bus_tx_req_value = fmt_byte_i;
          if (bus_tx_done) begin
            tx_bit_d = 1'b1;
          end
        end
      end
      BusTX: begin
        ctrl_sda_o = tx_flow_sda;
        ctrl_scl_o = scl_flow_scl;
        if (tx_bit_q) begin
          tx_bit_d = 1'b1;
          bus_tx_req_bit = 1'b1;
          bus_tx_req_value = {7'b0, fmt_bit_i};
          if (bus_tx_done) begin
            tx_bit_d = 1'b0;
            fmt_fifo_rdone_o = 1'b1;
          end
        end else begin
          bus_tx_req_byte  = 1'b1;
          bus_tx_req_value = fmt_byte_i;
          if (bus_tx_done) begin
            tx_bit_d = 1'b1;
          end
        end
      end
      BusRX: begin
        ctrl_scl_o = scl_flow_scl;
        bus_rx_req_byte = fmt_flag_read_bytes_i & ~bus_rx_req_bit_q;
        bus_rx_req_bit = bus_rx_req_bit_q;
        if (bus_rx_done & bus_rx_req_bit_q) begin
          bus_rx_req_bit_d = 1'b0;
          bus_rx_req_byte = 1'b1;
          fmt_flag_read_valid_o = 1'b1;  // Signals that fmt_byte_o and fmt_bit_o are valid
          fmt_bit_o = bus_rx_data[0];
        end else if (bus_rx_done & ~bus_rx_req_bit_q) begin
          bus_rx_req_bit_d = 1'b1;
          bus_rx_req_byte = 1'b0;
          rx_byte_d = bus_rx_data;
        end
      end
      ReStart: begin
        repeated_start = 1'b1;
        ctrl_sda_o = start_stop_sda;
        ctrl_scl_o = start_stop_scl;
        fmt_fifo_rready_o = 1'b1;
      end
      IBI: begin
        // TODO: implement
      end
      Stop: begin
        if (scl_negedge | scl_stable_low | start_stop_active) begin  // wait for cycle to finish and then stop
          stop_after_d = 1'b1;
          ctrl_sda_o = start_stop_sda;
          ctrl_scl_o = start_stop_scl;
          received_nack_d = 1'b0;
        end
      end
      default: begin
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      state_q <= Idle;
      tx_bit_q <= 1'b0;
      received_nack_q <= 1'b0;
      bus_rx_req_bit_q <= 1'b0;
      rx_byte_q <= '0;
      stop_after_q <= 1'b0;
    end else begin
      state_q <= state_d;
      tx_bit_q <= tx_bit_d;
      received_nack_q <= received_nack_d;
      bus_rx_req_bit_q <= bus_rx_req_bit_d;
      rx_byte_q <= rx_byte_d;
      stop_after_q <= stop_after_d;
    end
  end

  // Read Bus

  bus_rx_flow i_bus_rx_flow (
      .clk_i,
      .rst_ni,

      .scl_posedge_i(ctrl_bus_i.scl.pos_edge),
      .scl_stable_high_i(ctrl_bus_i.scl.stable_high),
      .sda_i(ctrl_sda_i),

      .rx_req_bit_i(bus_rx_req_bit),
      .rx_req_byte_i(bus_rx_req_byte),
      .rx_data_o(bus_rx_data),
      .rx_done_o(bus_rx_done),
      .rx_idle_o(bus_rx_idle)
  );

  // SDA driver
  logic unassigned_bus_sel_od_pp;
  bus_tx_flow i_bus_tx_flow (
      .clk_i,
      .rst_ni,
      .t_r_i,
      .t_su_dat_i      (tsu_dat_i),
      .t_hd_dat_i      (thd_dat_i),
      .scl_negedge_i   (scl_negedge),
      .scl_posedge_i   (scl_posedge),
      .scl_stable_low_i(scl_stable_low),
      .req_byte_i      (bus_tx_req_byte),
      .req_bit_i       (bus_tx_req_bit),
      .req_value_i     (bus_tx_req_value),
      .bus_tx_done_o   (bus_tx_done),
      .bus_tx_idle_o   (bus_tx_idle),
      .req_error_o     (bus_tx_req_err),
      .bus_error_o     (bus_error),
      .sel_od_pp_i     (bus_tx_sel_od_pp),
      .sel_od_pp_o     (unassigned_bus_sel_od_pp),
      .sda_o           (tx_flow_sda)
  );

  // SCL driver
  bus_scl_flow i_bus_scl_flow (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      // I3C bus timings
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
      // Output I3C Bus events
      .scl_negedge_o(scl_negedge),
      .scl_posedge_o(scl_posedge),
      .scl_stable_low_o(scl_stable_low),
      .scl_stable_high_o(scl_stable_high),
      // Control signals from controller
      .scl_enable_i(scl_enable),
      .scl_stall_i(scl_stall),
      .scl_o(scl_flow_scl)
  );

  logic unassigned_sel_od_pp_o;
  // Generate start(S), stop(P) and repeated start(Sr) condition
  bus_start_stop_gen i_bus_start_stop_gen (
      .clk_i,
      .rst_ni,

      .thd_sta_i,
      .tlow_i(tlow_i),
      .thd_rsta_i,
      .tsu_rsta_i,
      .tsu_sto_i,
      .t_ds_od_i,  // TODO: change to read from CSR
      .t_r_i,
      .t_f_i,

      .start_before_i(start_before),
      .stop_after_i(stop_after_q),
      .repeated_start_i(repeated_start),

      .start_done_o(start_done),
      .stop_done_o(stop_done),
      .repeated_start_done_o(repeated_start_done),

      .scl_o(start_stop_scl),
      .sda_o(start_stop_sda),

      .sel_od_pp_o(unassigned_sel_od_pp_o),

      .active_o(start_stop_active)
  );
endmodule
