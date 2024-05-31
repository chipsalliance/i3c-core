import i3c_agent_pkg::*;
import uvm_pkg::*;

interface i3c_if(
  input clk_i,
  input rst_ni,
  inout wire scl_io,
  inout wire sda_io
);

  // standard i3c interface pins
  logic scl_i;
  logic scl_o = 1'b1;
  logic scl_pp_en = 1'b0;
  logic sda_i;
  logic sda_o = 1'b1;
  logic sda_pp_en = 1'b0;

  assign scl_i = scl_io;
  assign sda_i = sda_io;
  // select between push-pull and open-drain driving
  assign scl_io = scl_pp_en ?
    scl_o : (scl_o ?
      1'bz : scl_o);
  assign (highz0, weak1) scl_io = 1'b1;
  assign sda_io = sda_pp_en ?
    sda_o : (sda_o ?
      1'bz : sda_o);
  assign (highz0, weak1) sda_io = 1'b1;

  string msg_id = "i3c_if";

  int scl_spinwait_timeout_ns = 10_000_000; // 10ms

  // Trace drivers' status
  i3c_drv_phase_e drv_phase;

  clocking cb @(posedge clk_i);
    input scl_i;
    input sda_i;
    output scl_o;
    output sda_o;
    output scl_pp_en;
    output sda_pp_en;
  endclocking

  //---------------------------------
  // Timing checker configuration
  //---------------------------------

  bit spike_filter = 0;
  task automatic enable_spkie_filter();
    spike_filter = 1;
  endtask // enable_spkie_filter

  task automatic disable_spkie_filter();
    spike_filter = 0;
  endtask // disable_spkie_filter

  int delay;
  assign delay = spike_filter ? 50 : 0;

  wire scl_delayed, scl_filtered;
  assign #(delay) scl_delayed = cb.scl_i;
  assign scl_filtered = cb.scl_i & scl_delayed;

  bit i2c_devices_present = 0;
  task automatic mixed_bus();
    i2c_devices_present = 1;
  endtask // mixed_bus

  task automatic i3c_only_bus();
    i2c_devices_present = 0;
  endtask // i3c_only_bus

  task automatic p_edge_scl();
    wait(cb.scl_i == 0);
    wait(cb.scl_i == 1);
  endtask

  task automatic sample_target_data(output bit data);
    p_edge_scl();
    data = cb.sda_i;
  endtask // sample_target_data

  task automatic wait_for_host_start();
    forever begin
      @(negedge sda_i);
      if(!scl_i) continue;
      @(negedge scl_i);
      if (!sda_i) begin
        break;
      end else continue;
    end
  endtask : wait_for_host_start

  task automatic get_bit_data(string src = "host",
                              output bit bit_o);
    @(posedge scl_i);
    bit_o = sda_i;


    if (src == "host") begin // host transmits data (addr/wr_data)
      `uvm_info(msg_id, $sformatf("get bit data %d", bit_o), UVM_HIGH)
      @(negedge scl_i);
    end else begin // target transmits data (rd_data)
      @(negedge scl_i);
    end
  endtask: get_bit_data

  task automatic wait_for_device_ack(input bit ack_bit = 1'b1);
    forever begin
      @(posedge scl_i);
      if (sda_i == ack_bit) begin
        break;
      end
    end
  endtask: wait_for_device_ack

  task automatic wait_for_device_ack_or_nack(output bit   ack_r);
    bit ack = 1'b0;
    bit nack = 1'b0;
    fork
      begin : iso_fork
        fork
          begin
            wait_for_device_ack(.ack_bit(1'b0));
            ack = 1'b1;
          end
          begin
            wait_for_device_ack(.ack_bit(1'b1));
            nack = 1'b1;
          end
        join_any
        disable fork;
      end : iso_fork
    join
    wait(scl_io == 0);
    ack_r = ack && !nack;
  endtask: wait_for_device_ack_or_nack

  task automatic wait_for_host_rstart(output bit rstart);
    rstart = 1'b0;
    forever begin
      @(posedge scl_i && sda_i);
      @(negedge sda_i);
      if (scl_i) begin
        @(negedge scl_i) begin
          rstart = 1'b1;
          break;
        end
      end
    end
  endtask: wait_for_host_rstart

  task automatic wait_for_host_stop(int wait_delay,
                                    output bit stop);
    stop = 1'b0;
    forever begin
      @(posedge scl_i);
      @(posedge sda_i);
      if (scl_i) begin
        stop = 1'b1;
        break;
      end
    end
    #(wait_delay * 1ns);
  endtask: wait_for_host_stop

  task automatic wait_for_i2c_host_stop_or_rstart(ref i2c_timing_t tc,
                                                  output bit   rstart,
                                                  output bit   stop);
    fork
      begin : iso_fork
        fork
          wait_for_host_stop(tc.tHoldStop, stop);
          wait_for_host_rstart(rstart);
        join_any
        disable fork;
      end : iso_fork
    join
  endtask: wait_for_i2c_host_stop_or_rstart

  task automatic wait_for_i3c_host_stop_or_rstart(ref i3c_timing_t tc,
                                                  output bit   rstart,
                                                  output bit   stop);
    fork
      begin : iso_fork
        fork
          wait_for_host_stop(tc.tHoldStop, stop);
          wait_for_host_rstart(rstart);
        join_any
        disable fork;
      end : iso_fork
    join
  endtask: wait_for_i3c_host_stop_or_rstart

  task automatic wait_for_host_ack();
    `uvm_info(msg_id, "Wait for host ack::Begin", UVM_HIGH)
    forever begin
      @(posedge scl_i);
      if (!sda_i) begin
        break;
      end
    end
    `uvm_info(msg_id, "Wait for host ack::Ack received", UVM_HIGH)
  endtask: wait_for_host_ack

  task automatic wait_for_host_nack();
    `uvm_info(msg_id, "Wait for host nack::Begin", UVM_HIGH)
    forever begin
      @(posedge scl_i);
      if (sda_i) begin
        break;
      end
    end
    `uvm_info(msg_id, "Wait for host nack::nack received", UVM_HIGH)
  endtask: wait_for_host_nack


  task automatic wait_for_host_ack_or_nack(output bit   ack,
                                           output bit   nack);
    ack = 1'b0;
    nack = 1'b0;
    fork
      begin : iso_fork
        fork
          begin
            wait_for_host_ack();
            ack = 1'b1;
          end
          begin
            wait_for_host_nack();
            nack = 1'b1;
          end
        join_any
        disable fork;
      end : iso_fork
    join
  endtask: wait_for_host_ack_or_nack

  task automatic time_check(input int delay, input bit exp_value, ref check_wire, input string msg);
    time valid_time;
    time exp_value_time;
    fork
      begin
        #(delay * 1ns);
        valid_time = $time;
      end
      begin
        wait(check_wire === exp_value);
        exp_value_time = $time;
      end
    join
    if (valid_time > exp_value_time)
      `uvm_info(msg_id, $sformatf("%s time check failed: expected time %d vs actual time %d",
        msg, valid_time, exp_value_time), UVM_HIGH)
  endtask

  task automatic host_i2c_start(ref i2c_timing_t tc);
    `DV_WAIT(scl_i === 1'b1,, scl_spinwait_timeout_ns, "host_start")
    #(tc.tSetupStart * 1ns);
    sda_o = 1'b0;
    #(tc.tHoldStart * 1ns);
    scl_o = 1'b0;
  endtask: host_i2c_start

  task automatic host_i3c_start(ref i3c_timing_t tc);
    `DV_WAIT(scl_i === 1'b1,, scl_spinwait_timeout_ns, "host_start")
    #(tc.tSetupStart * 1ns);
    sda_o = 1'b0;
    #(tc.tHoldStart * 1ns);
    scl_o = 1'b0;
  endtask: host_i3c_start

  task automatic host_i2c_rstart(ref i2c_timing_t tc);
    @(posedge scl_i && sda_i);
    #(tc.tSetupStart * 1ns);
    sda_o = 1'b0;
    #(tc.tHoldStart * 1ns);
    #(tc.tHoldBit * 1ns);
  endtask: host_i2c_rstart

  task automatic host_i3c_rstart(ref i3c_timing_t tc);
    @(posedge scl_i && sda_i);
    #(tc.tSetupStart * 1ns);
    sda_o = 1'b0;
    #(tc.tHoldRStart * 1ns);
    #(tc.tHoldBit * 1ns);
  endtask: host_i3c_rstart

  task automatic host_i2c_stop(ref i2c_timing_t tc);
    if (scl_i === 1'b1 && sda_i === 1'b1) begin
      `uvm_fatal(msg_id, "Cannot begin host_stop when both scl and sda are high")
    end

    if (scl_i === 1'b1)
      @(negedge scl_i);
    sda_o = 1'b0;
    #(tc.tClockLow * 1ns);
    scl_o = 1'b1;
    wait(scl_i === 1'b1);
    #(tc.tSetupStop * 1ns);
    sda_o = 1'b1;
    #(tc.tHoldStop * 1ns);
  endtask: host_i2c_stop

  task automatic host_i3c_stop(ref i3c_timing_t tc);
    if (scl_i === 1'b1 && sda_i === 1'b1) begin
      `uvm_fatal(msg_id, "Cannot begin host_stop when both scl and sda are high")
    end

    if (scl_i === 1'b1)
      @(negedge scl_i);
    sda_o = 1'b0;
    if (!scl_pp_en) begin
      #(tc.tClockLowOD * 1ns);
    end else begin
      #(tc.tClockLowPP * 1ns);
    end
    scl_o = 1'b1;
    wait(scl_i === 1'b1);
    #(tc.tSetupStop * 1ns);
    sda_o = 1'b1;
    #(tc.tHoldStop * 1ns);
  endtask: host_i3c_stop

  task automatic host_i2c_data(input i2c_timing_t tc, input bit bit_i);
    wait(scl_i === 1'b0);
    sda_o = bit_i;
    time_check(tc.tSetupBit, 1'b1, scl_i, "I2C host bit setup");
    time_check(tc.tClockPulse, 1'b0, scl_i, "I2C host bit clock high pulse width");
    #(tc.tHoldBit * 1ns);
    sda_o = 1;
  endtask: host_i2c_data

  task automatic host_i3c_data(input i3c_timing_t tc, input bit bit_i);
    wait(scl_i === 1'b0);
    sda_o = bit_i;
    time_check(tc.tSetupBit, 1'b1, scl_i, "I3C host bit setup");
    time_check(tc.tClockPulse, 1'b0, scl_i, "I3C host bit clock high pulse width");
    #(tc.tHoldBit * 1ns);
    sda_o = 1;
  endtask: host_i3c_data

  task automatic device_i2c_send_bit(ref i2c_timing_t tc,
                                 input bit bit_i);
    sda_o = 1'b1;
    wait(!scl_i);
    `uvm_info(msg_id, "device_send_bit::Drive bit", UVM_HIGH)
    sda_o = bit_i;
    time_check(tc.tSetupBit, 1'b1, scl_i, "I2C device bit setup");
    `uvm_info(msg_id, "device_send_bit::Value sampled ", UVM_HIGH)
    // Hold the bit steady for the rest of the clock low time.
    time_check(tc.tClockPulse, 1'b0, scl_i, "I2C device bit clock high pulse width");
    // Hold the bit past SCL going low, then release.
    #(tc.tHoldBit * 1ns);
    sda_o = 1'b1;
  endtask: device_i2c_send_bit

  task automatic device_i2c_send_ack(ref i2c_timing_t tc);
    device_i2c_send_bit(tc, 1'b0);
  endtask: device_i2c_send_ack

  task automatic device_i2c_send_nack(ref i2c_timing_t tc);
    device_i2c_send_bit(tc, 1'b1);
  endtask: device_i2c_send_nack

endinterface : i3c_if
