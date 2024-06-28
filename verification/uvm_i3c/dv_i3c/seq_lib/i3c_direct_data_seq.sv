class i3c_direct_data_seq extends uvm_sequence#(i3c_seq_item, i3c_seq_item);
  `uvm_declare_p_sequencer(i3c_sequencer)
  `uvm_object_utils(i3c_direct_data_seq)
  `uvm_object_new

  i3c_agent_cfg cfg;

  // data to be sent to target dut
  rand i3c_seq_item transfer;

  function int max(int a, int b);
    return a >= b ? a : b;
  endfunction

  function int min(int a, int b);
    return a >= b ? b : a;
  endfunction

  // Stops running this sequence
  protected bit stop;

  constraint transfer_addr_c {
    if (cfg.if_mode == Device) {
      transfer.addr == rsp.addr;
      transfer.dir  == rsp.dir;
    } else {
      transfer.addr inside {cfg.i3c_target0.dynamic_addr, cfg.i3c_target1.dynamic_addr};
      transfer.dir inside {0, 1};
    }
  }

  constraint transfer_i3c_direct_c {
    transfer.is_daa == 0;
    transfer.i3c == 1;
    transfer.IBI == 0;
    transfer.IBI_ACK == 0;
    transfer.IBI_ADDR == 0;
    transfer.IBI_START == 0;
  }

  constraint transfer_i3c_end_c {
    transfer.end_with_rstart == 0;
  }

  constraint transfer_dev_ack_c {
    if (cfg.if_mode == Host) {
      transfer.dev_ack == 1;
    } else {
      if ((rsp.addr == cfg.i3c_target0.dynamic_addr) ||
          (rsp.addr == cfg.i3c_target1.dynamic_addr))
        transfer.dev_ack == 1;
      else
        transfer.dev_ack == 0;
    }
  }

  constraint transfer_i3c_data_c {
    solve transfer.addr before transfer.data;
    solve transfer.dir  before transfer.data;
    solve transfer.data before transfer.data_cnt, transfer.T_bit;
    if (cfg.if_mode == Device) {
      if (transfer.dir == 1) {
        if(transfer.addr == cfg.i3c_target0.dynamic_addr)
          transfer.data.size() <= cfg.i3c_target0.max_read_length;
        if(transfer.addr == cfg.i3c_target1.dynamic_addr)
          transfer.data.size() <= cfg.i3c_target1.max_read_length;
        transfer.data_cnt == transfer.data.size();
        transfer.T_bit.size() == transfer.data.size();
        foreach (transfer.T_bit[i])
          if (i < transfer.T_bit.size() - 1)
            transfer.T_bit[i] == 1;
          else
            transfer.T_bit[i] == 0;
      } else {
        if(transfer.addr == cfg.i3c_target0.dynamic_addr)
          transfer.data.size() == cfg.i3c_target0.max_write_length;
        if(transfer.addr == cfg.i3c_target1.dynamic_addr)
          transfer.data.size() == cfg.i3c_target1.max_write_length;
        transfer.data_cnt == transfer.data.size();
        transfer.T_bit.size() == transfer.data.size();
      }
    } else {
      if (transfer.dir == 0) {
        0 < transfer.data.size();
        if(transfer.addr == cfg.i3c_target0.dynamic_addr)
          transfer.data.size() <= cfg.i3c_target0.max_write_length;
        if(transfer.addr == cfg.i3c_target1.dynamic_addr)
          transfer.data.size() <= cfg.i3c_target1.max_write_length;
        transfer.T_bit.size() == transfer.data.size();
        foreach(transfer.data[i]) {
          transfer.T_bit[i] == !(^transfer.data[i]);
        }
        transfer.data_cnt == transfer.data.size();
      } else {
        if(transfer.addr == cfg.i3c_target0.dynamic_addr)
          transfer.data.size() == cfg.i3c_target0.max_read_length;
        if(transfer.addr == cfg.i3c_target1.dynamic_addr)
          transfer.data.size() == cfg.i3c_target1.max_read_length;
        transfer.data_cnt == transfer.data.size();
        transfer.T_bit.size() == transfer.data.size();
        foreach(transfer.T_bit[i]) {
          if (i < transfer.T_bit.size() - 1)
            transfer.T_bit[i] == 1;
          else
            transfer.T_bit[i] == 0;
        }
      }
    }
  }

  task pre_start();
    super.pre_start();
    cfg = p_sequencer.cfg;
    transfer = new();
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
    this.randomize();
    $cast(req, transfer.clone());
    start_item(req);
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

  virtual task host_direct_phase();
    this.randomize();
    $cast(req, transfer.clone());
    start_item(req);
    `uvm_info(get_full_name(), $sformatf("\n%s", req.sprint()), UVM_DEBUG)
    finish_item(req);
    get_response(rsp);
    `uvm_info(get_full_name(), $sformatf("\n%s", rsp.sprint()), UVM_DEBUG)
    if (rsp.dev_ack) begin
      $cast(req, transfer.clone());
      start_item(req);
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
    host_direct_phase();
    `uvm_info(get_full_name(), $sformatf("\nHost recived:\n%s", rsp.sprint()), UVM_LOW)
  endtask

  virtual task seq_stop();
    stop = 1'b1;
    wait_for_sequence_state(UVM_FINISHED);
  endtask : seq_stop

endclass : i3c_direct_data_seq

