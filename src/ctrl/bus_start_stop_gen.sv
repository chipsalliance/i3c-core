// Description: Generates I3C Start, Repeated Start or Stop condition
module bus_start_stop_gen (
    input logic clk_i,
    input logic rst_ni,

    input [i3c_pkg::TimingWidth-1:0] tlow_i,  // low period of the SCL in clock units
    input [i3c_pkg::TimingWidth-1:0] thd_sta_od_i,  // hold time for START in clock units
    input [i3c_pkg::TimingWidth-1:0] thd_rsta_i,  // hold time for repeated START in clock units
    input [i3c_pkg::TimingWidth-1:0] tsu_rsta_i,  // setup time for repeated START in clock units
    input [i3c_pkg::TimingWidth-1:0] tsu_sto_i,  // setup time for STOP in clock units
    input [i3c_pkg::TimingWidth-1:0] t_ds_od_i,  // setup time for SDA during START in clock units
    input [i3c_pkg::TimingWidth-1:0] t_r_i,  // rise time of both SDA and SCL in clock units
    input [i3c_pkg::TimingWidth-1:0] t_f_i,  // fall time of both SDA and SCL in clock units

    // These signals cannot be asserted at the same time
    // currently it's asserted until the condition is generated
    input logic start_before_i,  // writes S condition on the I3C bus before writing first byte
    input logic stop_after_i,  // writes P condition on the I3C bus after writing/reading last byte
    input logic repeated_start_i,  // writes Sr condition on the I3C bus

    // These signals indicate that the condition has been generated on the bus
    output logic start_done_o,
    output logic stop_done_o,
    output logic repeated_start_done_o,

    output logic scl_o,
    output logic sda_o,
    output logic active_o // This signal is used to select between SCL/SDA of this module and bus_tx_flow and bus_scl_flow
);
  // FSM signals
  typedef enum logic [1:0] {
    Idle,
    Start,
    RepeatedStart,
    Stop
  } state_e;
  state_e state_d, state_q;

  // Timer signals
  logic [i3c_pkg::TimingWidth+3:0] timer_d, timer_q;
  logic [i3c_pkg::TimingWidth+3:0] total_repeated_start_time;
  logic [i3c_pkg::TimingWidth+2:0] total_hold_repeated_start;
  logic [i3c_pkg::TimingWidth+1:0] total_sda_low, total_sda_stop_low;
  logic [i3c_pkg::TimingWidth:0] total_hold_start, total_setup_stop;
  logic [i3c_pkg::TimingWidth-1:0] total_setup_repeated_start, t_scl_zero;

  assign total_hold_start = t_f_i + thd_sta_od_i;  // See Fig 144 I3C Basic Spec
  assign total_setup_stop = tsu_sto_i + t_r_i;
  assign total_setup_repeated_start = tsu_rsta_i + tlow_i; // according to Fig 153 I3C Basic Spec t_r_i is not taken into account for the setup time
  assign total_hold_repeated_start = t_f_i + thd_rsta_i + total_setup_repeated_start; // add with total setup time so we can use only one timer for repeated start
  assign total_repeated_start_time = total_hold_repeated_start + tlow_i;
  assign total_sda_low = total_hold_start + t_ds_od_i;
  assign t_scl_zero = tlow_i;  // TODO: change this
  assign total_sda_stop_low = total_setup_stop + t_scl_zero;
  // Next state logic
  always_comb begin
    state_d = state_q;
    timer_d = timer_q;
    scl_o = 1'b1;
    sda_o = 1'b1;
    active_o = 1'b0;
    start_done_o = 1'b0;
    repeated_start_done_o = 1'b0;
    stop_done_o = 1'b0;
    unique case (state_q)
      Idle: begin
        timer_d = '0;
        if (start_before_i) begin
          state_d = Start;
          sda_o = 1'b0;
          active_o = 1'b1;
        end else if (stop_after_i) begin
          state_d = Stop;
          sda_o = 1'b0;
          scl_o = 1'b0;
          active_o = 1'b1;
        end else if (repeated_start_i) begin
          state_d = RepeatedStart;
          scl_o = 1'b0;
          active_o = 1'b1;
        end
      end
      Start: begin
        active_o = 1'b1;
        if (timer_q < total_hold_start) begin
          timer_d = timer_q + 1;
          sda_o   = 1'b0;
        end else if (timer_q < total_sda_low) begin
          sda_o   = 1'b0;
          scl_o   = 1'b0;
          timer_d = timer_q + 1;
        end else begin
          state_d = Idle;
          timer_d = '0;
          scl_o = 1'b0;
          start_done_o = 1'b1;
        end
      end
      RepeatedStart: begin
        active_o = 1'b1;
        if (timer_q < tlow_i) begin
          scl_o   = 1'b0;
          timer_d = timer_q + 1;
        end else if (timer_q < total_setup_repeated_start) begin : setup_condition
          timer_d = timer_q + 1;
        end else begin : hold_condition
          sda_o = 1'b0;
          if (timer_q < total_hold_repeated_start) begin
            timer_d = timer_q + 1;
          end else begin
            scl_o   = 1'b0;
            timer_d = timer_q + 1;
            if (timer_q >= total_repeated_start_time) begin
              state_d = Idle;
              timer_d = '0;
              repeated_start_done_o = 1'b1;
            end
          end
        end
      end
      Stop: begin
        sda_o = 1'b0;
        scl_o = 1'b0;
        active_o = 1'b1;
        if (timer_q < total_sda_stop_low) begin
          timer_d = timer_q + 1;
          if (timer_q < t_scl_zero) begin
            scl_o = 1'b0;
          end else begin
            scl_o = 1'b1;
          end
        end else begin
          state_d = Idle;
          timer_d = '0;
          stop_done_o = 1'b1;
          sda_o = 1'b1;
          scl_o = 1'b1;
        end
      end
      default: begin
      end
    endcase

  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      state_q <= Idle;
      timer_q <= '0;
    end else begin
      state_q <= state_d;
      timer_q <= timer_d;
    end
  end
endmodule
