class i3c_direct_data_seq extends uvm_sequence#(i3c_seq_item, i3c_seq_item);
  `uvm_declare_p_sequencer(i3c_sequencer)
  `uvm_object_utils(i3c_direct_data_seq)
  `uvm_object_new

  i3c_agent_cfg cfg;

  // data to be sent to target dut
  rand bit [7:0] data_q[$];

  function int max(int a, int b);
    return a >= b ? a : b;
  endfunction

  // Stops running this sequence
  protected bit stop;

  // constrain size of data sent/received
  constraint data_q_size_c {
    data_q.size() inside {[0 :
      max(cfg.i3c_target0.max_write_length, cfg.i3c_target1.max_write_length)]};
  }

  task pre_start();
    super.pre_start();
    cfg = p_sequencer.cfg;
    this.randomize();
  endtask

  virtual task body();
    if (cfg.if_mode == Device) begin
      send_device_mode_txn();
    end else begin
      send_host_mode_txn();
    end
  endtask : body

  virtual task device_direct_phase();
    req = i3c_seq_item::type_id::create("req");
    start_item(req);
    req.addr = 7'h7F;
    req.i3c = 1;
    `uvm_info(get_full_name(), $sformatf("\n%s", req.sprint()), UVM_DEBUG)
    finish_item(req);
    get_response(rsp);
    `uvm_info(get_full_name(), $sformatf("\n%s", rsp.sprint()), UVM_DEBUG)
    if ((rsp.addr != cfg.i3c_target0.dynamic_addr) &&
        (rsp.addr != cfg.i3c_target1.dynamic_addr)) begin
      `uvm_info(get_full_name(), $sformatf("\n%s", rsp.sprint()), UVM_LOW)
      `uvm_error(get_full_name(),"Incorrect I3C address!")
    end
    req = i3c_seq_item::type_id::create("req");
    start_item(req);
    req.randomize() with {
      solve req.addr before req.data;
      solve req.dir  before req.data;
      solve req.data before req.data_cnt, req.T_bit;
      req.addr == rsp.addr;
      req.i3c == 1;
      if ((rsp.addr == cfg.i3c_target0.dynamic_addr) || (rsp.addr == cfg.i3c_target1.dynamic_addr))
        req.dev_ack == 1;
      else
        req.dev_ack == 0;
      req.is_daa == 0;
      req.dir == rsp.dir;
      req.IBI == 0;
      req.IBI_ACK == 0;
      req.IBI_ADDR == 0;
      req.IBI_START == 0;
      if (rsp.dir == 1) {
        if(rsp.addr == cfg.i3c_target0.dynamic_addr)
          req.data.size() <= cfg.i3c_target0.max_read_length;
        if(rsp.addr == cfg.i3c_target1.dynamic_addr)
          req.data.size() <= cfg.i3c_target1.max_read_length;
        req.data_cnt == req.data.size();
        req.T_bit.size() == req.data.size();
        foreach (req.T_bit[i])
          if (i < req.T_bit.size() - 1)
            req.T_bit[i] == 1;
          else
            req.T_bit[i] == 0;
      } else {
        if(rsp.addr == cfg.i3c_target0.dynamic_addr)
          req.data.size() == cfg.i3c_target0.max_write_length;
        if(rsp.addr == cfg.i3c_target1.dynamic_addr)
          req.data.size() == cfg.i3c_target1.max_write_length;
        req.data_cnt == req.data.size();
        req.T_bit.size() == req.data.size();
      }
    };
    `uvm_info(get_full_name(), $sformatf("\n%s", req.sprint()), UVM_DEBUG)
    finish_item(req);
    get_response(rsp);
    `uvm_info(get_full_name(), $sformatf("\n%s", rsp.sprint()), UVM_DEBUG)
  endtask : device_direct_phase

  virtual task send_device_mode_txn();
    // get seq for agent running in Device mode
    bit [7:0] rdata [$];
    forever begin
      device_direct_phase();
      if(stop) break;
    end
  endtask

  virtual task host_direct_phase(input bit RStart);
    req = i3c_seq_item::type_id::create("req");
    start_item(req);
    req.randomize() with {
      solve req.addr before req.data;
      solve req.dir  before req.data;
      solve req.data before req.data_cnt, req.T_bit;
      req.is_daa == 0;
      req.addr inside {cfg.i3c_target0.dynamic_addr, cfg.i3c_target1.dynamic_addr};
      req.dir inside {0, 1};
      req.i3c == 1;
      req.dev_ack == 1;
      req.data.size() == 0;
      req.T_bit.size() == 0;
      req.data_cnt == 0;
      req.IBI == 0;
      req.IBI_ACK == 0;
      req.IBI_ADDR == 0;
      req.IBI_START == 0;
    };
    `uvm_info(get_full_name(), $sformatf("\n%s", req.sprint()), UVM_DEBUG)
    finish_item(req);
    get_response(rsp);
    `uvm_info(get_full_name(), $sformatf("\n%s", rsp.sprint()), UVM_DEBUG)
    if (rsp.dev_ack) begin
      req = i3c_seq_item::type_id::create("req");
      start_item(req);
      req.randomize() with {
        solve req.addr before req.data;
        solve req.dir  before req.data;
        solve req.data before req.data_cnt, req.T_bit;
        req.is_daa == 0;
        req.addr == rsp.addr;
        req.dir == rsp.dir;
        req.i3c == 1;
        req.dev_ack == 1;
        req.end_with_rstart == RStart;
        if (req.dir == 0) {
          0 < req.data.size();
          req.data.size() <= local::data_q.size();
          if(req.addr == cfg.i3c_target0.dynamic_addr)
            req.data.size() <= cfg.i3c_target0.max_write_length;
          if(req.addr == cfg.i3c_target1.dynamic_addr)
            req.data.size() <= cfg.i3c_target1.max_write_length;
          foreach(req.data[i]) {
            req.data[i] == local::data_q[i];
          }
          req.T_bit.size() == req.data.size();
          foreach(req.data[i]) {
            req.T_bit[i] == !(^local::data_q[i]);
          }
          req.data_cnt == req.data.size();
        } else {
          if(req.addr == cfg.i3c_target0.dynamic_addr)
            req.data.size() == cfg.i3c_target0.max_read_length;
          if(req.addr == cfg.i3c_target1.dynamic_addr)
            req.data.size() == cfg.i3c_target1.max_read_length;
          req.data_cnt == req.data.size();
          req.T_bit.size() == req.data.size();
          foreach(req.T_bit[i]) {
            if (i < req.T_bit.size() - 1)
              req.T_bit[i] == 1;
            else
              req.T_bit[i] == 0;
          }
        }
        req.IBI == 0;
        req.IBI_ACK == 0;
        req.IBI_ADDR == 0;
        req.IBI_START == 0;
      };
      `uvm_info(get_full_name(), $sformatf("\n%s", req.sprint()), UVM_DEBUG)
      finish_item(req);
      get_response(rsp);
    end else begin
      `uvm_info(get_full_name(), $sformatf("\n%s", rsp.sprint()), UVM_LOW)
      `uvm_error(get_full_name(),"Device NACK I3C address!")
    end
  endtask : host_direct_phase

  virtual task send_host_mode_txn();
    // get seq for agent running in Host mode
    host_direct_phase(0);
    `uvm_info(get_full_name(), $sformatf("\nHost recived:\n%s", rsp.sprint()), UVM_LOW)
  endtask

  virtual task seq_stop();
    stop = 1'b1;
    wait_for_sequence_state(UVM_FINISHED);
  endtask : seq_stop

endclass : i3c_direct_data_seq

