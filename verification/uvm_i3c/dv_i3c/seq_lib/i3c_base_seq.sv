class i3c_direct_seq extends uvm_sequence#(i3c_seq_item, i3c_seq_item);
  `uvm_declare_p_sequencer(i3c_sequencer)
  `uvm_object_new

  i3c_agent_cfg cfg;

  task pre_start();
    super.pre_start();
    cfg = p_sequencer.cfg;
  endtask

  // data to be sent to target dut
  bit [7:0] data_q[$];

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

  virtual task body();
    if (cfg.if_mode == Device) begin
      send_device_mode_txn();
    end else begin
      send_host_mode_txn();
    end
  endtask : body

  virtual task send_device_mode_txn();
    // get seq for agent running in Device mode
    bit [7:0] rdata [$];
    forever begin
      req = i3c_seq_item::type_id::create("req");
      start_item(req);
      req.addr = 7'h7F;
      req.i3c = 1;
      finish_item(req);
      get_response(rsp);
      req = i3c_seq_item::type_id::create("req");
      start_item(req);
      std::randomize(req) with {
        req.i3c == 1;
        solve req.data before req.data_cnt, req.T_bit;
        req.dev_ack == 1;
        if (rsp.dir) {
          if(req.addr == cfg.i3c_target0.dynamic_addr)
            req.data.size() <= cfg.i3c_target0.max_read_length;
          if(req.addr == cfg.i3c_target1.dynamic_addr)
            req.data.size() <= cfg.i3c_target1.max_read_length;
          req.data_cnt == req.data.size();
          req.T_bit.size() == req.data.size();
          foreach (req.T_bit[i])
            if (i+1 < req.T_bit.size()) req.T_bit[i] == 1;
            else req.T_bit[i] == 0;
        } else {
          req.data.size() == 0;
          req.T_bit.size() == 0;
          if(req.addr == cfg.i3c_target0.dynamic_addr)
            req.data_cnt == cfg.i3c_target0.max_write_length;
          if(req.addr == cfg.i3c_target1.dynamic_addr)
            req.data_cnt == cfg.i3c_target1.max_write_length;
        }
      };
      finish_item(req);
      get_response(rsp);
      if(stop) break;
    end
  endtask

  virtual task send_host_mode_txn();
    // get seq for agent running in Host mode
    req = i3c_seq_item::type_id::create("req");
    start_item(req);
    std::randomize(req) with {
      solve req.addr before req.data;
      solve req.dir  before req.data;
      solve req.data before req.data_cnt, req.T_bit;
      req.addr inside {cfg.i3c_target0.dynamic_addr, cfg.i3c_target1.dynamic_addr};
      req.dir inside {0, 1};
      req.i3c == 1;
      req.end_with_rstart == 0;
      if (req.dir == 0) {
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
      }
    };
    finish_item(req);
    get_response(rsp);
  endtask

  virtual task seq_stop();
    stop = 1'b1;
    wait_for_sequence_state(UVM_FINISHED);
  endtask : seq_stop

endclass : i3c_direct_seq

