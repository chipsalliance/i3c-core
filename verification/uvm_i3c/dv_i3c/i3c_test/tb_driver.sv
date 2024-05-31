`include "i3c_sequencer_mock.sv"

module i3c_driver_test;
  import i3c_agent_pkg::*;
  import uvm_pkg::*;

  wire scl, sda;
  string str, unused;
  time timestamp;
  real _timestamp;
  bit sda_delay, scl_delay, sda_state, scl_state;

  logic clk_i;
  logic rst_ni;

  initial begin
    rst_ni = 1'b0;
    clk_i = 1'b0;
    sda_state = 1'b1;
    scl_state = 1'b1;
    fork
      begin
        for(int i=0; i<100; i++)
          @(posedge clk_i)
        rst_ni = 1'b1;
      end
      forever begin
        clk_i = 1'b0;
        #(5ns);
        clk_i = 1'b1;
        #(5ns);
      end
    join
  end

  i3c_if i3c_bus(
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .scl_io(scl),
    .sda_io(sda)
  );

  //assign scl = scl_state ? 1'b1: 1'b0;
  //assign sda = sda_state ? 1'b1: 1'b0;

  //i3c dut


  initial begin
    static i3c_agent_cfg cfg = new;
    static i3c_driver drv = new;
    static i3c_monitor recv = new;
    static i3c_sequencer_mock seq = new;
    static uvm_phase phase = new;
    static i3c_seq_item test_item;
    cfg.tc.i2c_tc = i2c_1000;
    drv.set_report_verbosity_level(UVM_DEBUG);
    recv.set_report_verbosity_level(UVM_DEBUG);
    cfg.if_mode = Host;
    cfg.vif = i3c_bus;
    cfg.i3c_target0.static_addr = 7'h72;
    cfg.i3c_target0.static_addr_valid = 1'b1;
    cfg.i3c_target0.dynamic_addr = 7'h72;
    cfg.i3c_target0.dynamic_addr_valid = 1'b1;
    drv.cfg = cfg;
    recv.cfg = cfg;
    drv.build_phase(phase);
    seq.build_phase(phase);
    recv.build_phase(phase);
    drv.set_report_verbosity_level(UVM_DEBUG);
    drv.seq_item_port.connect(seq.seq_item_export);
    drv.do_resolve_bindings();
    fork
      seq.run_phase(phase);
      drv.run_phase(phase);
      recv.run_phase(phase);
    join_none

    // I2C followe by I2C
    test_item = new();
    test_item.i3c = 0;
    test_item.addr = 7'h4E;
    test_item.dir = 1;
    test_item.end_with_rstart = 1;
    seq.add_item(test_item);
    test_item = new();
    test_item.i3c = 0;
    test_item.addr = 7'h4E;
    test_item.dir = 1;
    test_item.end_with_rstart = 0;
    seq.add_item(test_item);
    test_item = new();
    // I3C followe by I3C
    test_item.i3c = 1;
    test_item.addr = 7'h4E;
    test_item.dir = 1;
    test_item.end_with_rstart = 1;
    seq.add_item(test_item);
    test_item = new();
    test_item.i3c = 1;
    test_item.addr = 7'h4E;
    test_item.dir = 1;
    test_item.end_with_rstart = 0;
    seq.add_item(test_item);
    // I2C followe by I3C
    test_item = new();
    test_item.i3c = 0;
    test_item.addr = 7'h4E;
    test_item.dir = 1;
    test_item.end_with_rstart = 1;
    seq.add_item(test_item);
    test_item = new();
    test_item.i3c = 1;
    test_item.addr = 7'h4E;
    test_item.dir = 1;
    test_item.end_with_rstart = 0;
    seq.add_item(test_item);
    test_item = new();
    // I3C followe by I2C
    test_item.i3c = 1;
    test_item.addr = 7'h4E;
    test_item.dir = 1;
    test_item.end_with_rstart = 1;
    seq.add_item(test_item);
    test_item = new();
    test_item.i3c = 0;
    test_item.addr = 7'h4E;
    test_item.dir = 1;
    test_item.end_with_rstart = 0;
    seq.add_item(test_item);
    //uvm_config_db#(virtual clk_rst_if)::set(null, "*.env", "clk_rst_vif", clk_rst_if);
    //uvm_config_db#(virtual i3c_if)::set(null, "*.env.m_i3c_agent*", "vif", i3c_if);
    //uvm_config_db#(virtual i2c_dv_if)::set(null, "*.env", "i2c_dv_vif", i2c_dv_if);
    //$timeformat(-12, 0, " ps", 12);
    //run_test();
    #(100us);
    $finish();
  end
endmodule
