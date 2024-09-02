// SPDX-License-Identifier: Apache-2.0

/*
  This module implements timers to measure t_{CAS}, t_{BUF}, t_{AVAL}, t_{IDLE}.
  Returns bus state {busy, idle, available, free}.

  Important note: section 5.1.3.2 Bus Condition Timing is ambiguous:

  Bus Available Condition definition:
    "The Bus Available Condition is defined as a period during which the Bus Free Condition is sustained
     continuously for a duration of at least tAVAL (see Table 86)."

  However:
    Figure 24 Bus Condition Timing shows that the timing tAVAL is calculated from the STOP Condition Detect.

  These 2 items contradict each other.

  In this implementation, we will resolve the ambiguity by assuming that text has higher priority than the timing diagram.
  If we are wrong, then this is the safer route since the Bus Available Condition will be detected too late rather too soon.
  Hence, this implementation will be (at most) slightly less efficient, but will not interfere with operation of the bus.
*/

module bus_timers
  import controller_pkg::*;
(
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        enable_i,
    input  logic        restart_counter_i,
    input  logic [19:0] t_bus_free_i,       // CSR: Time to free
    input  logic [19:0] t_bus_idle_i,       // CSR: Time to idle
    input  logic [19:0] t_bus_available_i,  // CSR: Time to available
    output logic        bus_busy_o,         // Bus is busy
    output logic        bus_free_o,         // Bus is free
    output logic        bus_idle_o,         // Bus is idle
    output logic        bus_available_o     // Bus is available
);
  logic [31:0] bus_state_counter;

  logic enable;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_enable
    if (!rst_ni) begin
      enable <= '0;
    end else begin
      enable <= enable_i & ~bus_idle_o;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_counter
    if (!rst_ni) begin
      bus_state_counter <= '0;
    end else begin
      if (restart_counter_i) begin
        bus_state_counter <= '0;
      end else begin
        if (enable) begin
          bus_state_counter <= bus_state_counter + 1'b1;
        end else begin
          bus_state_counter <= bus_state_counter;
        end
      end
    end
  end

  assign bus_free_o = bus_state_counter > (t_bus_free_i - 1'b1);
  assign bus_idle_o = bus_state_counter > (t_bus_idle_i - 1'b1);
  assign bus_available_o = bus_state_counter > (t_bus_available_i - 1'b1);
  assign bus_busy_o = ~(bus_free_o | bus_idle_o | bus_available_o);

endmodule



