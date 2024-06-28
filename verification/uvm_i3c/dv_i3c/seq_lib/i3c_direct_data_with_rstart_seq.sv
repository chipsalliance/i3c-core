class i3c_direct_data_with_rstart_seq extends i3c_direct_data_seq;
  `uvm_object_utils(i3c_direct_data_with_rstart_seq)
  `uvm_object_new

  int num_trans;
  int curr_trans;

  constraint transfer_i3c_end_c {
    if (curr_trans < num_trans-1)
      transfer.end_with_rstart dist {1 := 7, 0 := 3};
    else
      transfer.end_with_rstart == 0;
  }

  virtual task send_host_mode_txn();
    // get seq for agent running in Host mode
    `uvm_info(get_full_name(), $sformatf("\nNumber of transactions: %d", num_trans), UVM_LOW)
    for (curr_trans = 0; curr_trans < num_trans; curr_trans++) begin
      host_direct_phase();
      `uvm_info(get_full_name(), $sformatf("\nHost recived:\n%s", rsp.sprint()), UVM_LOW)
    end
  endtask

  virtual task seq_stop();
    stop = 1'b1;
    wait_for_sequence_state(UVM_FINISHED);
  endtask : seq_stop

endclass : i3c_direct_data_with_rstart_seq

