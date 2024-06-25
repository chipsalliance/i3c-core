class i3c_direct_data_with_repeated_start_seq extends i3c_direct_data_seq;
  `uvm_object_utils(i3c_direct_data_with_repeated_start_seq)
  `uvm_object_new

  int num_trans;

  virtual task send_host_mode_txn();
    // get seq for agent running in Host mode
    `uvm_info(get_full_name(), $sformatf("\nNumber of transactions: %d", num_trans), UVM_LOW)
    for (int curr_trans = 0; curr_trans < num_trans; curr_trans++) begin
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
      if(rsp.dev_ack) begin
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
          req.end_with_rstart == (curr_trans < num_trans-1);
          req.dev_ack == 1;
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
        `uvm_fatal(get_full_name(),"Device NACK I3C address!")
      end
      `uvm_info(get_full_name(), $sformatf("\nHost recived:\n%s", rsp.sprint()), UVM_LOW)
    end
  endtask

  virtual task seq_stop();
    stop = 1'b1;
    wait_for_sequence_state(UVM_FINISHED);
  endtask : seq_stop

endclass : i3c_direct_data_with_repeated_start_seq

