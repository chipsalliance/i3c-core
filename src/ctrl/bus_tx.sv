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
  logic [12:0] tcount_q;  // current counter for setting delays
  logic [12:0] tcount_d;  // next counter for setting delays
  logic        load_tcount;  // indicates counter must be loaded

  logic tx_idle, tx_done;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      tx_idle_o <= '0;
      tx_done_o <= '0;
    end else begin
      tx_idle_o <= tx_idle;
      tx_done_o <= tx_done;
    end
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
        tSetupData: tcount_d = (13'(t_r_i) + 13'(t_su_dat_i)) > 0 ? (13'(t_r_i) + 13'(t_su_dat_i)) : 13'h0001;
        tHoldData:  tcount_d = (13'(t_hd_dat_i) > 0) ? 13'(t_hd_dat_i) : 13'h0001;
        tNoDelay:   tcount_d = 13'h0001;
        default:    tcount_d = 13'h0001;
      endcase
    end else begin
      if (tcount_q > 13'h0001)
        tcount_d = tcount_q - 1'b1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : clk_counter
    if (~rst_ni) begin
      tcount_q <= '1;
    end else begin
      tcount_q <= tcount_d;
    end
  end

  typedef enum logic [2:0] {
    Idle,
    AwaitClockNegedge,
    SetupData,
    AwaitClockPosedge,
    TransmitData,
    HoldData,
    NextTaskDecision
  } tx_state_e;

  tx_state_e state_d, state_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_fsm_state
    if (~rst_ni) begin
      state_q <= Idle;
    end else begin
      state_q <= state_d;
    end
  end

  always_comb begin : tx_fsm_outputs
    sda_o = drive_value_i;
    tx_idle = 1'b0;  // Assign to 1 only in Idle
    tx_done = 1'b0;  // Assign to 1 only after transmitting a bit
    load_tcount = 1'b0;
    tcount_sel = tNoDelay;

    unique case (state_q)
      Idle: begin
        sda_o   = 1'b1;  // Do not pull down the bus
        tx_idle = 1'b1;
        if (scl_stable_low_i) begin
          load_tcount = 1'b1;
          tcount_sel  = tSetupData;
        end
      end
      AwaitClockNegedge: begin
        sda_o = 1'b1;  // Do not pull down the bus
        load_tcount = 1'b1;
        tcount_sel = tSetupData;
      end
      SetupData: ;
      AwaitClockPosedge: ;
      TransmitData: begin
        if (scl_negedge_i) begin
          load_tcount = 1'b1;
          tcount_sel  = tHoldData;
        end
      end
      HoldData: begin
        tx_done = 1'b1;
        if (drive_i) begin
          load_tcount = 1'b1;
          tcount_sel  = tSetupData;
        end
      end
      NextTaskDecision: ;
      default: begin
        sda_o   = 1'b1;
        tx_idle = 1'b0;
        tx_done = 1'b0;
      end
    endcase
  end

  always_comb begin : tx_fsm_state
    state_d = state_q;

    unique case (state_q)
      Idle: begin
        state_d = scl_stable_low_i ? SetupData : AwaitClockNegedge;
      end
      AwaitClockNegedge: begin
        if (scl_negedge_i) begin
          state_d = SetupData;
        end
      end
      SetupData: begin
        if (tcount_q == 13'd1) begin
          state_d = AwaitClockPosedge;
        end
      end
      AwaitClockPosedge: begin
        if (scl_posedge_i) begin
          state_d = TransmitData;
        end
      end
      TransmitData: begin
        if (scl_negedge_i) begin
          state_d = HoldData;
        end
      end
      HoldData: begin
        state_d = NextTaskDecision;
      end
      NextTaskDecision: begin
        state_d = SetupData;
      end
      default: begin
        state_d = Idle;
      end
    endcase

    // Allow to abort and go back to Idle if needed
    if (~drive_i) begin
      state_d = Idle;
    end
  end

  assign sel_od_pp_o = sel_od_pp_i;  // Pass through the OD/PP selection
endmodule
