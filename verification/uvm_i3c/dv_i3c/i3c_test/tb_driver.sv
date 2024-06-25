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

  i3c_agent_cfg cfg;
  i3c_agent_cfg cfg_dev;
  i3c_driver drv_host;
  i3c_driver drv_device;
  i3c_monitor recv;
  i3c_sequencer_mock seq_host;
  i3c_sequencer_mock seq_device;
  uvm_phase phase;
  i3c_seq_item host_item, dev_item;
  i3c_seq_item rsp_host, rsp_dev;

  //i3c dut
  initial begin
    cfg = new;
    cfg_dev = new;
    drv_host = new;
    drv_device = new;
    recv = new;
    seq_host = new;
    seq_device = new;
    phase = new;
    cfg.tc.i2c_tc = i2c_400;
    cfg.if_mode = Host;
    cfg.vif = i3c_bus;
    cfg.i3c_target0.static_addr = 7'h72;
    cfg.i3c_target0.static_addr_valid = 1'b1;
    cfg.i3c_target0.dynamic_addr = 7'h72;
    cfg.i3c_target0.dynamic_addr_valid = 1'b1;

    drv_host.cfg = cfg;
    recv.cfg = cfg;
    recv.set_report_verbosity_level(UVM_DEBUG);

    cfg_dev.tc.i2c_tc = i2c_400;
    cfg_dev.if_mode = Device;
    cfg_dev.vif = i3c_bus;
    cfg_dev.i3c_target0.static_addr = 7'h72;
    cfg_dev.i3c_target0.static_addr_valid = 1'b1;
    cfg_dev.i3c_target0.dynamic_addr = 7'h72;
    cfg_dev.i3c_target0.dynamic_addr_valid = 1'b1;
    drv_device.cfg = cfg_dev;

    drv_host.build_phase(phase);
    drv_device.build_phase(phase);
    seq_host.build_phase(phase);
    recv.build_phase(phase);

    drv_host.seq_item_port.connect(seq_host.seq_item_export);
    drv_host.do_resolve_bindings();

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
    i2c_after_i2c();
    // I3C followe by I3C
    i3c_after_i3c();
    // I2C followe by I3C
    i3c_after_i2c();
    // I3C followe by I2C
    i2c_after_i3c();
    // I2C reads
    i2c_read();
    // I2C write
    i2c_write();
    // I3C read
    i3c_read();
    // I3C write
    i3c_write();
    // I3C IBI
    i3c_ibi();
    // I3C DAA
    i3c_daa();
    $finish();
  end

  function _create_i2c_item(input bit [6:0] addr, input bit dir,
    input bit [7:0] data[$], input bit T_bit[$],
    output i3c_seq_item item);
    item = new();
    item.i3c = 0;
    item.addr = addr;
    item.dir = dir;
    item.dev_ack = 0;
    item.end_with_rstart = 0;
    item.data = data;
    item.data_cnt = data.size();
    item.T_bit = T_bit;
  endfunction

  function _create_i3c_item(input bit [6:0] addr, input bit dir,
    input bit [7:0] data[$], input bit T_bit[$],
    output i3c_seq_item item);
    item = new();
    item.i3c = 1;
    item.addr = addr;
    item.dir = dir;
    item.dev_ack = 0;
    item.end_with_rstart = 0;
    item.data = data;
    item.data_cnt = data.size();
    item.T_bit = T_bit;
  endfunction

  task create_i2c_item(input bit [6:0] addr, input bit dir,
    input bit [7:0] host_data[$], input bit host_T_bit[$],
    input bit [7:0] dev_data[$] = host_data, input bit dev_T_bit[$] = host_T_bit);
    _create_i2c_item(addr, dir, host_data, host_T_bit, host_item);
    _create_i2c_item(addr, dir, dev_data, dev_T_bit, dev_item);
  endtask

  task create_i3c_item(input bit [6:0] addr, input bit dir,
    input bit [7:0] host_data[$], input bit host_T_bit[$],
    input bit [7:0] dev_data[$] = host_data, input bit dev_T_bit[$] = host_T_bit);
    _create_i3c_item(addr, dir, host_data, host_T_bit, host_item);
    _create_i3c_item(addr, dir, dev_data, dev_T_bit, dev_item);
  endtask

  task nack_addr_test();
    i3c_seq_item temp;
    seq_host.add_item(host_item);
    seq_device.add_item(dev_item);
    seq_device.get_rsp(rsp_dev);
    assert (rsp_dev.addr == host_item.addr);
    assert (rsp_dev.dir == host_item.dir);
    #0 assert (seq_host.try_get_rsp(rsp_host) == 0);
    seq_device.add_item(dev_item);
    seq_host.get_rsp(rsp_host);
    #1;
    assert (rsp_host.addr == host_item.addr);
    assert (rsp_host.dir == host_item.dir);
    assert (rsp_host.dev_ack == dev_item.dev_ack);
    assert (seq_device.try_get_rsp(rsp_dev) == 1);
    temp = rsp_dev;
    assert (seq_device.try_get_rsp(rsp_dev) == 0);
    rsp_dev = temp;
    temp = rsp_host;
    assert (seq_host.try_get_rsp(rsp_host) == 0);
    rsp_host = temp;
  endtask

  task addr_test();
    i3c_seq_item temp;
    seq_host.add_item(host_item);
    seq_device.add_item(dev_item);
    seq_device.get_rsp(rsp_dev);
    assert (rsp_dev.addr == host_item.addr);
    assert (rsp_dev.dir == host_item.dir);
    #0 assert (seq_host.try_get_rsp(rsp_host) == 0);
    dev_item.dev_ack = 1;
    seq_device.add_item(dev_item);
    seq_host.get_rsp(rsp_host);
    #1;
    assert (rsp_host.addr == host_item.addr);
    assert (rsp_host.dir == host_item.dir);
    assert (rsp_host.dev_ack == dev_item.dev_ack);
    assert (seq_device.try_get_rsp(rsp_dev) == 1);
    temp = rsp_dev;
    assert (seq_device.try_get_rsp(rsp_dev) == 0);
    rsp_dev = temp;
    temp = rsp_host;
    assert (seq_host.try_get_rsp(rsp_host) == 0);
    rsp_host = temp;
  endtask

  task ibi_test();
    i3c_seq_item temp;
    seq_host.add_item(host_item);
    seq_device.add_item(dev_item);
    seq_host.get_rsp(rsp_host);
    assert (rsp_host.IBI);
    assert (rsp_host.IBI_ADDR == dev_item.IBI_ADDR);
    assert (rsp_host.dir == 1);
    #0 assert (seq_device.try_get_rsp(rsp_dev) == 0);
    host_item.IBI_ACK = 1;
    seq_host.add_item(host_item);
    seq_device.get_rsp(rsp_dev);
    assert (rsp_dev.addr == dev_item.IBI_ADDR);
    assert (rsp_dev.dir == 1);
    assert (rsp_dev.dev_ack == host_item.IBI_ACK);
    rsp_host = null;
    fork
      fork
        seq_host.get_rsp(rsp_host);
// Host takes time to send I2c/I3C STOP
// Wait 2us timeout
        #2us;
      join_any
      disable fork;
    join
    assert (rsp_host != null);
    temp = rsp_host;
    assert (seq_host.try_get_rsp(rsp_host) == 0);
    rsp_host = temp;
    temp = rsp_dev;
    assert (seq_device.try_get_rsp(rsp_dev) == 0);
    rsp_dev = temp;
  endtask

  task i2c_after_i2c();
    create_i2c_item(7'h4E, 1, {}, {});
    host_item.end_with_rstart = 1;
    nack_addr_test();
    create_i2c_item(7'h4E, 1, {}, {});
    nack_addr_test();
  endtask

  task i3c_after_i3c();
    create_i3c_item(7'h72, 1, {}, {});
    host_item.end_with_rstart = 1;
    nack_addr_test();
    create_i3c_item(7'h72, 1, {}, {});
    nack_addr_test();
  endtask

  task i3c_after_i2c();
    create_i2c_item(7'h4E, 1, {}, {});
    host_item.end_with_rstart = 1;
    nack_addr_test();
    create_i3c_item(7'h72, 1, {}, {});
    nack_addr_test();
  endtask

  task i2c_after_i3c();
    create_i2c_item(7'h72, 1, {}, {});
    host_item.end_with_rstart = 1;
    nack_addr_test();
    create_i3c_item(7'h4E, 1, {}, {});
    nack_addr_test();
  endtask

  task i2c_read();
    // I2C read
    create_i2c_item(7'h4E, 1, {8'hDE, 8'hAD}, {1, 0});
    addr_test();
    assert (rsp_host.data == dev_item.data);
    // I2C read with interruption
    create_i2c_item(7'h4E, 1, {8'hDE, 8'hAD, 8'hBE, 8'hEF}, {1, 0});
    addr_test();
    assert (rsp_host.data == dev_item.data[0:1]);
  endtask

  task i2c_write();
    // I2C write
    create_i2c_item(7'h4E, 0, {8'hDE, 8'hAD}, {1, 1});
    addr_test();
    assert (rsp_dev.data == host_item.data);
    // I2C write with interruption
    create_i2c_item(7'h4E, 0, {8'hDE, 8'hAD, 8'hBE, 8'hEF}, {1, 0});
    addr_test();
    assert (rsp_dev.data == host_item.data[0:1]);
  endtask

  task i3c_read();
    // I3C read
    create_i3c_item(7'h72, 1, {8'hDE, 8'hAD, 8'hBE, 8'hEF}, {1, 1, 1, 0});
    addr_test();
    assert (rsp_host.data == dev_item.data);
    // I3C read with interruption
    create_i3c_item(7'h72, 1, {8'h0, 8'h0}, {0, 0},
        {8'hDE, 8'hAD, 8'hBE, 8'hEF}, {1, 1, 1, 0});
    addr_test();
    assert (rsp_host.data == dev_item.data[0:1]);
  endtask

  task i3c_write();
    // I3C write
    create_i3c_item(7'h72, 0, {8'hDE, 8'hAD, 8'hBE, 8'hEF}, {1, 0, 1, 0});
    addr_test();
    assert (rsp_dev.data == host_item.data);
    // I3C write with interruption
    create_i3c_item(7'h72, 0, {8'hDE, 8'hAD, 8'hBE, 8'hEF}, {1, 1, 1, 0});
    addr_test();
    assert (rsp_dev.data == host_item.data[0:1]);
  endtask

  task i3c_ibi();
    // I3C IBI device start
    create_i3c_item(7'h7E, 0, {8'hDE, 8'hAD, 8'hBE, 8'hEF}, {1, 1, 1, 0});
    dev_item.IBI = 1;
    dev_item.IBI_ADDR = 7'h72;
    dev_item.IBI_START = 1;
    ibi_test();
    assert (rsp_host.data == dev_item.data);
    // I3C IBI device start, truncated data
    create_i3c_item(7'h7E, 0, {8'h0, 8'h0}, {0, 0},
        {8'hDE, 8'hAD, 8'hBE, 8'hEF}, {1, 1, 1, 0});
    dev_item.IBI = 1;
    dev_item.IBI_ADDR = 7'h72;
    dev_item.IBI_START = 1;
    ibi_test();
    assert (rsp_host.data == dev_item.data[0:1]);
    // I3C IBI host start
    create_i3c_item(7'h7E, 0, {8'hDE, 8'hAD, 8'hBE, 8'hEF}, {1, 1, 1, 0});
    dev_item.IBI = 1;
    dev_item.IBI_ADDR = 7'h72;
    ibi_test();
    assert (rsp_host.data == dev_item.data);
    // I3C IBI host start, truncated data
    create_i3c_item(7'h7E, 0, {8'h0, 8'h0}, {0, 0},
        {8'hDE, 8'hAD, 8'hBE, 8'hEF}, {1, 1, 1, 0});
    dev_item.IBI = 1;
    dev_item.IBI_ADDR = 7'h72;
    ibi_test();
    assert (rsp_host.data == dev_item.data[0:1]);
  endtask

  task i3c_daa();
    // I3C DAA
    create_i3c_item(7'h7E, 0, {8'h07}, {0});
    host_item.end_with_rstart = 1;
    addr_test();
    assert (rsp_dev.data == host_item.data);
    // Set first addr
    create_i3c_item(7'h7E, 1, {8'h43}, {0},
      {8'hDE, 8'hAD, 8'hBE, 8'hEF, 8'h55, 8'hAA, 8'h55, 8'hAA}, {1});
    host_item.end_with_rstart = 1;
    host_item.is_daa = 1;
    dev_item.is_daa = 1;
    addr_test();
    assert (rsp_dev.data == host_item.data);
    assert (rsp_host.data == dev_item.data);
    // Set second addr
    create_i3c_item(7'h7E, 1, {8'h45}, {0},
      {8'hDE, 8'hAD, 8'hBE, 8'hEF, 8'h75, 8'hAA, 8'h55, 8'hAA}, {1});
    host_item.end_with_rstart = 1;
    host_item.is_daa = 1;
    dev_item.is_daa = 1;
    addr_test();
    assert (rsp_dev.data == host_item.data);
    assert (rsp_host.data == dev_item.data);
    // Finish DAA
    create_i3c_item(7'h7E, 1, {}, {});
    nack_addr_test();
  endtask
endmodule
