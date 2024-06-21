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
      req.i3c = 1;
      if (rsp.addr == 7'h7E && rsp.dir == 0) begin
        req.dev_ack = 1;
        req.is_daa = 0;
        req.dir = rsp.dir;
        req.IBI = 0;
        req.IBI_ACK = 0;
        req.IBI_ADDR = 0;
        req.IBI_START = 0;
        req.data_cnt = 0;
        `uvm_info(get_full_name(), $sformatf("\n%s", req.sprint()), UVM_DEBUG)
        finish_item(req);
        get_response(rsp);
        `uvm_info(get_full_name(), $sformatf("\n%s", rsp.sprint()), UVM_DEBUG)
        // ACKed broadcast, expecting RStart
        while (rsp.end_with_rstart) begin
          device_direct_phase();
        end
      end else begin
        `uvm_error(get_full_name(), $sformatf("\n%s", rsp.sprint()))
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
    `uvm_info(get_full_name(), $sformatf("\n%s", req.sprint()), UVM_DEBUG)
    finish_item(req);
    get_response(rsp);
    `uvm_info(get_full_name(), $sformatf("\n%s", rsp.sprint()), UVM_DEBUG)
    req = i3c_seq_item::type_id::create("req");
    start_item(req);
    req.i3c = 1;
    req.dev_ack = 0;
    if (rsp.dev_ack == 1) begin
      req.end_with_rstart = 1;
      `uvm_info(get_full_name(), $sformatf("\n%s", req.sprint()), UVM_DEBUG)
      finish_item(req);
      get_response(rsp);
      `uvm_info(get_full_name(), $sformatf("\n%s", rsp.sprint()), UVM_DEBUG)
      host_direct_phase(0);
      `uvm_info(get_full_name(), $sformatf("\nHost recived:\n%s", rsp.sprint()), UVM_LOW)
    end else begin
      req.end_with_rstart = 0;
      `uvm_error(get_full_name(), $sformatf("\nHost recived:\n%s", rsp.sprint()))
    end
  endtask

  virtual task seq_stop();
    stop = 1'b1;
    wait_for_sequence_state(UVM_FINISHED);
  endtask : seq_stop

endclass : i3c_broadcast_followed_by_data_seq

