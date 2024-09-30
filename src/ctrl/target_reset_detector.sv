typedef enum logic [1:0] {
  AwaitPattern = 2'h0,
  AwaitSr = 2'h1,
  AwaitP = 2'h2,
  ResetDetected = 2'h3
} target_reset_detector_state_e;

module target_reset_detector
  import controller_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input logic enable_i,  // Enable

    input logic scl_low,
    input logic scl_high,
    input logic scl_negedge,
    input logic sda_posedge,
    input logic sda_negedge,

    input start_detected_i, stop_detected_i,

    output logic target_reset_detect_o
);
  logic count_sda_transition;

  logic [3:0] transition_count_q;
  logic [3:0] transition_count_d;
  logic [1:0] suspicious_transition_count_q;
  logic [1:0] suspicious_transition_count_d;
  logic invalidate_sr;

  target_reset_detector_state_e state_q, state_d;

  always_comb begin
    if (scl_high)
      transition_count_d = 4'h0;
    else
      transition_count_d =
        count_sda_transition ? transition_count_q + 4'h1 : transition_count_q;

    if ((state_q inside {AwaitP, AwaitSr}) & (sda_posedge | sda_negedge)) begin
      suspicious_transition_count_d = suspicious_transition_count_q + 2'h1;
    end else if (state_q == AwaitPattern) begin
      suspicious_transition_count_d = 2'h0;
    end

    count_sda_transition = 0;
    if ((state_q == AwaitPattern) & (transition_count_q < 4'he))
      count_sda_transition = (sda_posedge & (transition_count_q != 0)) | sda_negedge;

    invalidate_sr = suspicious_transition_count_d > 1;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : target_reset_transition_counter
    if (!rst_ni) begin
      transition_count_q <= 4'h0;
    end else if (clk_i) begin
      transition_count_q <= transition_count_d;
    end
  end : target_reset_transition_counter

  // If suspicious_transition_count == 1, it's either start or stop signal,
  // but if it's more then it means something weird has happened or start/stop timing
  // requirements were not met
  always_ff @(posedge clk_i or negedge rst_ni) begin : suspicious_transition_counter
    if (!rst_ni) begin
      suspicious_transition_count_q <= 2'h0;
    end else if (clk_i) begin
      if (state_d == state_q)
        suspicious_transition_count_q <= suspicious_transition_count_d;
      else
        suspicious_transition_count_q <= 2'h0; // Reset on state transition
    end
  end: suspicious_transition_counter

  always_ff @(posedge clk_i or negedge rst_ni) begin : target_reset_detection_state
    if (!rst_ni) begin
      state_q <= AwaitPattern;
    end else if (clk_i) begin
      state_q <= state_d;
    end
  end : target_reset_detection_state

  always_comb begin : target_reset_detection_fsm
    case (state_q)
      AwaitPattern: begin
        state_d = (transition_count_q == 4'he) ? AwaitSr : AwaitPattern;
      end
      AwaitSr: begin
        state_d = AwaitSr;
        if (start_detected_i & scl_high) begin
          state_d = AwaitP;
        end else if (scl_low | suspicious_transition_count_q > 1) begin
          state_d = AwaitPattern;
        end
      end
      AwaitP: begin
        state_d = AwaitP;
        if (stop_detected_i & scl_high) begin
          state_d = ResetDetected;
        end else begin
          if (invalidate_sr)
            state_d = AwaitPattern;
        end
      end
      ResetDetected: begin
        state_d = AwaitPattern;
      end
      default: begin
        state_d = AwaitPattern;
      end // Unreachable
    endcase
  end : target_reset_detection_fsm

  assign target_reset_detect_o = state_d == ResetDetected;
endmodule
