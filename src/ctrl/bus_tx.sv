// SPDX-License-Identifier: Apache-2.0

/*
  This module provides a common interface to drive the I3C bus in Target Mode.


*/
module bus_tx (
    input logic clk_i,
    input logic rst_ni,

    // I3C bus timings
    input logic [19:0] t_r_i,       // rise time of both SDA and SCL in clock units
    input logic [19:0] t_su_dat_i,  // data setup time in clock units
    input logic [19:0] t_hd_dat_i,  // data hold time in clock units

    input logic drive_i,  // Driving the bus, it should never come later than (t_low-t_hd_dat) after
                          // SCL falling edge if SCL is in stable LOW state
    input logic drive_value_i,  // Requested value to drive

    // Input I3C Bus events
    input logic scl_negedge_i,
    input logic scl_posedge_i,
    input logic scl_stable_low_i,

    // Open Drain / Push Pull
    input logic sel_od_pp_i,

    output logic tx_idle_o,
    output logic tx_done_o,  // Indicate finished bit write

    output logic sel_od_pp_o,
    output logic sda_o  // Output I3C SDA bus line
);

  logic [19:0] tcount_q;    // current counter for setting delays
  logic [19:0] tcount_d;    // next counter for setting delays
  logic        load_tcount; // indicates counter must be loaded

  // Compute timings
  logic [19:0] t_sd_i;
  logic [19:0] t_sd;

  logic        t_sd_z;
  logic        t_hd_z;

  assign t_sd_i = t_r_i + t_su_dat_i;

  always_ff @(posedge clk_i) begin
    t_sd   <= t_sd_i;
    t_sd_z <= t_sd_i == 20'd0;
    t_hd_z <= t_hd_dat_i == 20'd0;
  end

  // Clock counter implementation
  typedef enum logic [1:0] {
    tSetupData,
    tHoldData,
    tNoDelay
  } tcount_sel_e;

  tcount_sel_e tcount_sel;

  always_comb begin : counter_functions
    tcount_d = tcount_q;
    if (load_tcount) begin
      unique case (tcount_sel)
        tSetupData: tcount_d = t_sd;
        tHoldData:  tcount_d = (t_hd_dat_i > 0) ? t_hd_dat_i : 20'd1;
        tNoDelay:   tcount_d = 20'd1;
        default:    tcount_d = 20'd1;
      endcase
    end else begin
      if (tcount_q != 20'd0) begin
        tcount_d = tcount_q - 1'b1;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : clk_counter
    if (~rst_ni) begin
      tcount_q <= '0;
    end else begin
      tcount_q <= tcount_d;
    end
  end

  typedef enum logic [2:0] {
    Idle,
    AwaitClockNegedge,
    SetupData,
    TransmitData,
    HoldData
  } tx_state_e;

  tx_state_e state_d, state_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_fsm_state
    if (~rst_ni) begin
      state_q <= Idle;
    end else begin
      state_q <= state_d;
    end
  end

  // State outputs
  assign tx_idle_o = (state_q == Idle);

  always_comb begin : tx_fsm_outputs
    sda_o = '1;
    tx_done_o = '0;  // Assign to 1 only after transmitting a bit
    load_tcount = '0;
    tcount_sel = tNoDelay;

    unique case (state_q)
      Idle: begin
        if (drive_i) begin
          tcount_sel  = tSetupData;
          load_tcount = '1;
          if (t_sd_z & (scl_stable_low_i | scl_negedge_i)) begin
            sda_o = drive_value_i;
          end
        end
      end
      AwaitClockNegedge: begin
        tcount_sel  = tSetupData;
        load_tcount = '1;
        if (t_sd_z & scl_negedge_i) begin
          sda_o = drive_value_i;
        end
      end
      SetupData: begin
        if (tcount_q == 20'd1) begin
          sda_o = drive_value_i;
        end
      end
      TransmitData: begin
        sda_o = drive_value_i;
        if (scl_negedge_i) begin
          tcount_sel  = tHoldData;
          load_tcount = '1;
          if (t_hd_z) tx_done_o = '1;
        end
      end
      HoldData: begin
        if (tcount_q != 20'd0) begin
          sda_o = drive_value_i;
        end else begin
          tx_done_o = '1;
        end
      end
    endcase
  end

  // State transitions
  always_comb begin : tx_fsm_state
    state_d = state_q;

    unique case (state_q)
      Idle: begin
        if (drive_i) begin
          if (scl_stable_low_i | scl_negedge_i)
            state_d = (t_sd_z) ? TransmitData : SetupData;
          else
            state_d = AwaitClockNegedge;
        end
      end
      AwaitClockNegedge: begin
        if (scl_stable_low_i | scl_negedge_i)
          state_d = (t_sd_z) ? TransmitData : SetupData;
      end
      SetupData: begin
        if (tcount_q == 20'd1)
          state_d = TransmitData;
      end
      TransmitData: begin
        if (scl_negedge_i)
          state_d = (t_hd_z) ? Idle : HoldData;
      end
      HoldData: begin
        if (tcount_q == 20'd0 & scl_stable_low_i)
          state_d = Idle;
      end
    endcase
  end

  assign sel_od_pp_o = sel_od_pp_i;  // Pass through the OD/PP selection
endmodule
