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
        #(2ns);
        clk_i = 1'b1;
        #(2ns);
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
    static i3c_agent_cfg cfg_dev = new;
    static i3c_driver drv_host = new;
    static i3c_driver drv_device = new;
    static i3c_monitor recv = new;
    static i3c_sequencer_mock seq_host = new;
    static i3c_sequencer_mock seq_device = new;
    static uvm_phase phase = new;
    static i3c_seq_item test_item, test_item_copy;
    cfg.tc.i2c_tc = i2c_1000;
    cfg.if_mode = Host;
    cfg.vif = i3c_bus;
    cfg.i3c_target0.static_addr = 7'h72;
    cfg.i3c_target0.static_addr_valid = 1'b1;
    cfg.i3c_target0.dynamic_addr = 7'h72;
    cfg.i3c_target0.dynamic_addr_valid = 1'b1;

    drv_host.cfg = cfg;
    drv_host.set_report_verbosity_level(UVM_DEBUG);
    recv.cfg = cfg;
    recv.set_report_verbosity_level(UVM_DEBUG);

    cfg_dev.tc.i2c_tc = i2c_1000;
    cfg_dev.if_mode = Device;
    cfg_dev.vif = i3c_bus;
    cfg_dev.i3c_target0.static_addr = 7'h72;
    cfg_dev.i3c_target0.static_addr_valid = 1'b1;
    cfg_dev.i3c_target0.dynamic_addr = 7'h72;
    cfg_dev.i3c_target0.dynamic_addr_valid = 1'b1;
    drv_device.cfg = cfg_dev;
    drv_device.set_report_verbosity_level(UVM_DEBUG);

    drv_host.build_phase(phase);
    drv_device.build_phase(phase);
    seq_host.build_phase(phase);
    recv.build_phase(phase);

    drv_host.set_report_verbosity_level(UVM_DEBUG);
    drv_host.seq_item_port.connect(seq_host.seq_item_export);
    drv_host.do_resolve_bindings();

    drv_device.set_report_verbosity_level(UVM_DEBUG);
    drv_device.seq_item_port.connect(seq_device.seq_item_export);
    drv_device.do_resolve_bindings();

    fork
      seq_host.run_phase(phase);
      seq_device.run_phase(phase);
      drv_host.run_phase(phase);
      drv_device.run_phase(phase);
      recv.run_phase(phase);
    join_none

    // I2C followe by I2C
    test_item = new();
    test_item.i3c = 0;
    test_item.addr = 7'h4E;
    test_item.dir = 1;
    test_item.dev_ack = 0;
    test_item.end_with_rstart = 1;
    seq_host.add_item(test_item);
    seq_device.add_item(test_item);

    test_item = new();
    test_item.i3c = 0;
    test_item.addr = 7'h4E;
    test_item.dir = 1;
    test_item.dev_ack = 0;
    test_item.end_with_rstart = 0;
    seq_host.add_item(test_item);
    seq_device.add_item(test_item);
    // I3C followe by I3C
    test_item = new();
    test_item.i3c = 1;
    test_item.addr = 7'h72;
    test_item.dir = 1;
    test_item.dev_ack = 0;
    test_item.end_with_rstart = 1;
    seq_host.add_item(test_item);
    seq_device.add_item(test_item);

    test_item = new();
    test_item.i3c = 1;
    test_item.addr = 7'h72;
    test_item.dir = 1;
    test_item.dev_ack = 0;
    test_item.end_with_rstart = 0;
    seq_host.add_item(test_item);
    seq_device.add_item(test_item);

    // I2C followe by I3C
    test_item = new();
    test_item.i3c = 0;
    test_item.addr = 7'h4E;
    test_item.dir = 1;
    test_item.dev_ack = 0;
    test_item.end_with_rstart = 1;
    seq_host.add_item(test_item);
    seq_device.add_item(test_item);

    test_item = new();
    test_item.i3c = 1;
    test_item.addr = 7'h72;
    test_item.dir = 1;
    test_item.dev_ack = 0;
    test_item.end_with_rstart = 0;
    seq_host.add_item(test_item);
    seq_device.add_item(test_item);

    // I3C followe by I2C
    test_item = new();
    test_item.i3c = 1;
    test_item.addr = 7'h72;
    test_item.dir = 1;
    test_item.dev_ack = 0;
    test_item.end_with_rstart = 1;
    seq_host.add_item(test_item);
    seq_device.add_item(test_item);

    test_item = new();
    test_item.i3c = 0;
    test_item.addr = 7'h4E;
    test_item.dir = 1;
    test_item.dev_ack = 0;
    test_item.end_with_rstart = 0;
    seq_host.add_item(test_item);
    seq_device.add_item(test_item);

    // I2C read
    test_item = new();
    test_item.i3c = 0;
    test_item.addr = 7'h4E;
    test_item.dir = 1;
    test_item.data_cnt = 2;
    test_item.data.push_back(8'hDE);
    test_item.data.push_back(8'hAD);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(0);
    test_item.end_with_rstart = 0;
    test_item.dev_ack = 1;
    seq_host.add_item(test_item);
    seq_device.add_item(test_item);

    // I2C read with interruption
    test_item = new();
    test_item.i3c = 0;
    test_item.addr = 7'h4E;
    test_item.dir = 1;
    test_item.data_cnt = 4;
    test_item.data.push_back(8'hDE);
    test_item.data.push_back(8'hAD);
    test_item.data.push_back(8'hBE);
    test_item.data.push_back(8'hEF);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(0);
    test_item.end_with_rstart = 0;
    test_item.dev_ack = 1;
    seq_device.add_item(test_item);
    $cast(test_item_copy, test_item.clone());
    test_item_copy.data_cnt = 2;
    seq_host.add_item(test_item_copy);

    // I2C write
    test_item = new();
    test_item.i3c = 0;
    test_item.addr = 7'h4E;
    test_item.dir = 0;
    test_item.data_cnt = 2;
    test_item.data.push_back(8'hDE);
    test_item.data.push_back(8'hAD);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(1);
    test_item.end_with_rstart = 0;
    test_item.dev_ack = 1;
    seq_host.add_item(test_item);
    seq_device.add_item(test_item);

    // I2C write with interruption
    test_item = new();
    test_item.i3c = 0;
    test_item.addr = 7'h4E;
    test_item.dir = 0;
    test_item.data_cnt = 2;
    test_item.data.push_back(8'hDE);
    test_item.data.push_back(8'hAD);
    test_item.data.push_back(8'hBE);
    test_item.data.push_back(8'hEF);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(0);
    test_item.end_with_rstart = 0;
    test_item.dev_ack = 1;
    seq_device.add_item(test_item);
    $cast(test_item_copy, test_item.clone());
    test_item_copy.data_cnt = 4;
    seq_host.add_item(test_item_copy);

    // I3C read
    test_item = new();
    test_item.i3c = 1;
    test_item.addr = 7'h72;
    test_item.dir = 1;
    test_item.data_cnt = 4;
    test_item.data.push_back(8'hDE);
    test_item.data.push_back(8'hAD);
    test_item.data.push_back(8'hBE);
    test_item.data.push_back(8'hEF);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(0);
    test_item.T_bits_valid = 1;
    test_item.end_with_rstart = 0;
    test_item.dev_ack = 1;
    seq_device.add_item(test_item);
    seq_host.add_item(test_item);

    // I3C read with interruption
    test_item = new();
    test_item.i3c = 1;
    test_item.addr = 7'h72;
    test_item.dir = 1;
    test_item.data_cnt = 4;
    test_item.data.push_back(8'hDE);
    test_item.data.push_back(8'hAD);
    test_item.data.push_back(8'hBE);
    test_item.data.push_back(8'hEF);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(0);
    test_item.T_bits_valid = 1;
    test_item.end_with_rstart = 0;
    test_item.dev_ack = 1;
    seq_device.add_item(test_item);
    seq_device.add_item(test_item); // Interruption causes next item to be discarded in device mode
    $cast(test_item_copy, test_item.clone());
    test_item_copy.data_cnt = 2;
    seq_host.add_item(test_item_copy);

    // I3C IBI device start
    test_item = new();
    test_item.i3c = 1;
    test_item.addr = 7'h7E;
    test_item.IBI = 1;
    test_item.IBI_ADDR = 7'h72;
    test_item.IBI_START = 1;
    test_item.IBI_ACK = 1;
    test_item.dir = 1;
    test_item.data_cnt = 4;
    test_item.data.push_back(8'hDE);
    test_item.data.push_back(8'hAD);
    test_item.data.push_back(8'hBE);
    test_item.data.push_back(8'hEF);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(0);
    test_item.T_bits_valid = 1;
    test_item.end_with_rstart = 0;
    test_item.dev_ack = 1;
    seq_device.add_item(test_item);
    seq_host.add_item(test_item);

    // I3C IBI host start, truncated data
    test_item = new();
    test_item.i3c = 1;
    test_item.addr = 7'h7E;
    test_item.IBI = 1;
    test_item.IBI_ADDR = 7'h72;
    test_item.IBI_START = 0;
    test_item.IBI_ACK = 1;
    test_item.dir = 1;
    test_item.data_cnt = 4;
    test_item.data.push_back(8'hDE);
    test_item.data.push_back(8'hAD);
    test_item.data.push_back(8'hBE);
    test_item.data.push_back(8'hEF);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(0);
    test_item.T_bits_valid = 1;
    test_item.end_with_rstart = 0;
    test_item.dev_ack = 1;
    seq_device.add_item(test_item);
    seq_device.add_item(test_item);
    $cast(test_item_copy, test_item.clone());
    test_item_copy.data_cnt = 2;
    seq_host.add_item(test_item_copy);

    // I3C IBI device start
    test_item = new();
    test_item.i3c = 1;
    test_item.addr = 7'h7E;
    test_item.IBI = 1;
    test_item.IBI_ADDR = 7'h72;
    test_item.IBI_START = 1;
    test_item.IBI_ACK = 1;
    test_item.dir = 1;
    test_item.data_cnt = 4;
    test_item.data.push_back(8'hDE);
    test_item.data.push_back(8'hAD);
    test_item.data.push_back(8'hBE);
    test_item.data.push_back(8'hEF);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(1);
    test_item.T_bit.push_back(0);
    test_item.T_bits_valid = 1;
    test_item.end_with_rstart = 0;
    test_item.dev_ack = 1;
    seq_device.add_item(test_item);
    seq_host.add_item(test_item);
    //uvm_config_db#(virtual clk_rst_if)::set(null, "*.env", "clk_rst_vif", clk_rst_if);
    //uvm_config_db#(virtual i3c_if)::set(null, "*.env.m_i3c_agent*", "vif", i3c_if);
    //uvm_config_db#(virtual i2c_dv_if)::set(null, "*.env", "i2c_dv_vif", i2c_dv_if);
    //$timeformat(-12, 0, " ps", 12);
    //run_test();
    #(400us);
    $finish();
  end
endmodule
