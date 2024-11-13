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

    input logic enable_i,

    input logic scl_low,
    input logic scl_high,
    input logic scl_negedge,
    input logic sda_posedge,
    input logic sda_negedge,

    input start_detected_i,
    stop_detected_i,

    output logic target_reset_detect_o
);
  logic count_sda_transition_en;

  logic [3:0] sda_transition_count_q;
  logic [3:0] sda_transition_count_d;

  target_reset_detector_state_e state_q, state_d;

  always_comb begin
    if (scl_high) sda_transition_count_d = 4'h0;
    else
      sda_transition_count_d = count_sda_transition_en ?
                                  sda_transition_count_q + 4'h1 :
                                  sda_transition_count_q;

    if ((state_q == AwaitPattern) & (sda_transition_count_q < 4'he))
      count_sda_transition_en = (sda_posedge & (sda_transition_count_q != 0)) | sda_negedge;
    else count_sda_transition_en = 0;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : target_reset_sda_transition_counter
    if (!rst_ni) begin
      sda_transition_count_q <= 4'h0;
    end else begin
      sda_transition_count_q <= sda_transition_count_d;
    end
  end : target_reset_sda_transition_counter

  always_ff @(posedge clk_i or negedge rst_ni) begin : target_reset_detection_state
    if (!rst_ni) begin
      state_q <= AwaitPattern;
    end else begin
      state_q <= state_d;
    end
  end : target_reset_detection_state

  always_comb begin : target_reset_detection_fsm
    case (state_q)
      AwaitPattern: begin
        state_d = (sda_transition_count_q == 4'he) ? AwaitSr : AwaitPattern;
      end
      AwaitSr: begin
        state_d = AwaitSr;
        // If SDA posedge is detected, it means that it toggled from LOW to HIGH before fulfilling
        // the START condition hold timing, otherwise `start_detected_i` would be asserted
        if (scl_low | sda_posedge) begin
          state_d = AwaitPattern;
        end else if (start_detected_i) begin
          state_d = AwaitP;
        end
      end
      AwaitP: begin
        state_d = AwaitP;
        // If SDA negedge is detected, it means that it toggled from HIGH to LOW before fulfilling
        // the STOP condition hold timing, otherwise `stop_detected_i` would be asserted
        if (scl_low | sda_negedge) begin
          state_d = AwaitPattern;
        end else if (stop_detected_i) begin
          state_d = ResetDetected;
        end
      end
      ResetDetected: begin
        state_d = AwaitPattern;
      end
      default: begin
        state_d = AwaitPattern;
      end
    endcase
  end : target_reset_detection_fsm

  assign target_reset_detect_o = state_d == ResetDetected;
endmodule
