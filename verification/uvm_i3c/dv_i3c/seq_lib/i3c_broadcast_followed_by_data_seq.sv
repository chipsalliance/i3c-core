class i3c_broadcast_followed_by_data_seq extends i3c_direct_data_seq;
  `uvm_object_utils(i3c_broadcast_followed_by_data_seq)
  `uvm_object_new

  virtual task send_device_mode_txn();
    // get seq for agent running in Device mode
    bit [7:0] rdata [$];
    forever begin
      req = i3c_seq_item::type_id::create("req");
      start_item(req);
      req.addr = 7'h7F;
      req.i3c = 1;
      `uvm_info(get_full_name(), $sformatf("\n%s", req.sprint()), UVM_DEBUG)
      finish_item(req);
      get_response(rsp);
      `uvm_info(get_full_name(), $sformatf("\n%s", rsp.sprint()), UVM_DEBUG)
      req = i3c_seq_item::type_id::create("req");
      start_item(req);
      if (rsp.addr == 7'h7E && rsp.dir == 0) begin
        req.randomize() with {
          solve req.dir  before req.data;
          solve req.data before req.data_cnt, req.T_bit;
          req.i3c == 1;
          req.dev_ack == 1;
          req.is_daa == 0;
          req.dir == rsp.dir;
          req.IBI == 0;
          req.IBI_ACK == 0;
          req.IBI_ADDR == 0;
          req.IBI_START == 0;
          if (rsp.dir == 1) {
            if(rsp.addr == cfg.i3c_target0.dynamic_addr)
              req.data.size() <= cfg.i3c_target0.max_read_length;
            else if(rsp.addr == cfg.i3c_target1.dynamic_addr)
              req.data.size() <= cfg.i3c_target1.max_read_length;
            else
              req.data.size() == 0;
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
            else if(rsp.addr == cfg.i3c_target1.dynamic_addr)
              req.data.size() == cfg.i3c_target1.max_write_length;
            else
              req.data.size() == 0;
            req.data_cnt == req.data.size();
            req.T_bit.size() == req.data.size();
          }
        };
        finish_item(req);
        get_response(rsp);
        `uvm_info(get_full_name(), $sformatf("\n%s", rsp.sprint()), UVM_DEBUG)
      end else begin
        `uvm_warning(get_full_name(), $sformatf("\n%s", rsp.sprint()))
        req.dev_ack = 0;
        finish_item(req);
        get_response(rsp);
      end
      if(stop) break;
    end
  endtask

  virtual task send_host_mode_txn();
    // get seq for agent running in Host mode
    req = i3c_seq_item::type_id::create("req");
    start_item(req);
    req.is_daa = 0;
    req.i3c = 1;
    req.addr = 7'h7E;
    req.dir = 0;
    req.end_with_rstart = 1;
    req.IBI = 0;
    req.IBI_ACK = 0;
    req.IBI_ADDR = 0;
    req.IBI_START = 0;
    finish_item(req);
    get_response(rsp);
    req = i3c_seq_item::type_id::create("req");
    start_item(req);
    if (rsp.dev_ack == 1) begin
      `uvm_info(get_full_name(), $sformatf("\nHost recived:\n%s", rsp.sprint()), UVM_LOW)
      req.randomize() with {
        solve req.addr before req.data;
        solve req.dir  before req.data;
        solve req.data before req.data_cnt, req.T_bit;
        req.is_daa == 0;
        req.addr inside {cfg.i3c_target0.dynamic_addr, cfg.i3c_target1.dynamic_addr};
        req.dir inside {0, 1};
        req.i3c == 1;
        req.end_with_rstart == 0;
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
      `uvm_info(get_full_name(), $sformatf("\nHost recived:\n%s", rsp.sprint()), UVM_LOW)
    end else begin
      `uvm_warning(get_full_name(), $sformatf("\nHost recived:\n%s", rsp.sprint()))
    end
  endtask

  virtual task seq_stop();
    stop = 1'b1;
    wait_for_sequence_state(UVM_FINISHED);
  endtask : seq_stop

endclass : i3c_broadcast_followed_by_data_seq

