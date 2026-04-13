// Description: Generate SCL signal
// Limitations: STALLING SCL is not supported
module bus_scl_flow (
    input logic clk_i,
    input logic rst_ni,

    // I3C bus timings
    input [i3c_pkg::TimingWidth-1:0] thigh_i,  // high period of the SCL in clock units
    input [i3c_pkg::TimingWidth-1:0] tlow_i,   // low period of the SCL in clock units
    input [i3c_pkg::TimingWidth-1:0] t_r_i,    // rise time of both SDA and SCL in clock units
    input [i3c_pkg::TimingWidth-1:0] t_f_i,    // fall time of both SDA and SCL in clock units

    // Output I3C Bus events
    output logic scl_negedge_o,
    output logic scl_posedge_o,
    output logic scl_stable_low_o,
    output logic scl_stable_high_o,

    // Control signals from controller
    input logic scl_enable_i,  // while set, SCL should be generated.
    input logic scl_stall_i,  // when set, SCL will be held at low for as long as the signal is set. NOT SUPPORTED

    output logic scl_o  // Output I3C SDA bus line
);

  typedef enum logic [1:0] {
    Idle,
    Low,
    High
  } state_e;

  state_e state_d, state_q;
  logic scl_negedge_d, scl_negedge_q;
  logic scl_posedge_d, scl_posedge_q;

  assign scl_negedge_o = scl_negedge_q;
  assign scl_posedge_o = scl_posedge_q;

  // Timer counter
  logic [i3c_pkg::TimingWidth:0] timer_d, timer_q;  // one bit longer than the input timing
  logic [i3c_pkg::TimingWidth:0] scl_low_time, scl_high_time;  // supports adding two timings
  assign scl_low_time  = tlow_i + t_r_i;
  assign scl_high_time = thigh_i + t_f_i;

  // FSM transitions
  always_comb begin
    state_d = state_q;
    timer_d = timer_q;
    scl_negedge_d = 1'b0;
    scl_posedge_d = 1'b0;
    scl_stable_low_o = 1'b0;
    scl_stable_high_o = 1'b0;
    scl_o = 1'b1;
    unique case (state_q)
      Idle: begin
        scl_stable_high_o = 1'b1;
        if (scl_enable_i) begin
          state_d = Low;
          timer_d = '0;
          scl_o = 1'b0;
          scl_negedge_d = 1'b1;
        end
      end
      Low: begin
        if (scl_stall_i) begin : stall_scl
          scl_o = 1'b0;
          scl_stable_low_o = 1'b1;
        end else begin
          if (timer_q < scl_low_time) begin
            timer_d = timer_q + 1;
            scl_o   = 1'b0;
            if (timer_q > t_f_i) begin
              scl_stable_low_o = 1'b1;
            end
          end else begin
            state_d = High;
            timer_d = '0;
            scl_stable_low_o = 1'b0;
            scl_posedge_d = 1'b1;
          end
        end
      end
      High: begin
        if (timer_q < scl_high_time) begin
          timer_d = timer_q + 1;
          scl_o   = 1'b1;
          if (timer_q > t_r_i) begin
            scl_stable_high_o = 1'b1;
          end
        end else begin
          state_d = scl_enable_i ? Low : Idle;
          timer_d = '0;
          scl_negedge_d = scl_enable_i ? 1'b1 : 1'b0;
        end
      end
      default: begin
        state_d = Idle;
        timer_d = '0;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      state_q <= Idle;
      timer_q <= '0;
      scl_posedge_q <= 1'b0;
      scl_negedge_q <= 1'b0;
    end else begin
      state_q <= state_d;
      timer_q <= timer_d;
      scl_posedge_q <= scl_posedge_d;
      scl_negedge_q <= scl_negedge_d;
    end
  end
endmodule
