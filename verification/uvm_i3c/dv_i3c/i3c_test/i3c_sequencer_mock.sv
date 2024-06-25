class i3c_sequencer_mock #(type REQ = i3c_seq_item, type RSP = REQ) extends uvm_component;

  typedef i3c_sequencer_mock #(REQ, RSP) this_type;
  uvm_seq_item_pull_imp #(REQ, RSP, this_type) seq_item_export;

  extern virtual function void add_item(REQ item);
  extern virtual function bit try_get_rsp(output RSP rsp);
  extern task get_rsp(output RSP rsp);

  extern virtual task get_next_item(output REQ t);
  extern virtual task try_next_item(output REQ t);
  extern virtual task get(output REQ t);
  extern virtual task peek(output REQ t);

  extern virtual function void item_done(RSP item = null);
  extern virtual task put(RSP t);
  extern virtual function void put_response(RSP t);

  extern virtual task wait_for_sequences();
  extern virtual function bit has_do_available();

  protected uvm_tlm_fifo #(REQ) reqs;
  protected uvm_tlm_fifo #(RSP) rsps;

  function new(string name="", uvm_component parent=null);
    super.new(name, parent);
    seq_item_export = new("seq_item_export", this);
    reqs = new("reqs", this, 0);
    rsps = new("rsps", this, 0);
  endfunction

  extern virtual function void disable_auto_item_recording();
  extern virtual function bit is_auto_item_recording_enabled();
endclass : i3c_sequencer_mock

function void i3c_sequencer_mock::add_item(REQ item);
  void'(reqs.try_put(item));
endfunction

function bit i3c_sequencer_mock::try_get_rsp(output RSP rsp);
  return rsps.try_get(rsp);
endfunction

task i3c_sequencer_mock::get_rsp(output RSP rsp);
  rsps.get(rsp);
endtask

task i3c_sequencer_mock::get_next_item(output REQ t);
  `uvm_info(get_full_name(), "Get_next_item called", UVM_DEBUG);
  reqs.peek(t);
endtask


task i3c_sequencer_mock::try_next_item(output REQ t);
  void'(reqs.try_peek(t));
endtask

task i3c_sequencer_mock::get(output REQ t);
  reqs.get(t);
endtask


task i3c_sequencer_mock::peek(output REQ t);
  reqs.peek(t);
endtask

function void i3c_sequencer_mock::item_done(RSP item = null);
  REQ t;
  `uvm_info(get_full_name(), "Item_done called", UVM_DEBUG)
  void'(reqs.try_get(t));

  if (item != null)
    void'(rsps.try_put(item));
endfunction

task i3c_sequencer_mock::put(RSP t);
  rsps.put(t);
endtask


function void i3c_sequencer_mock::put_response(RSP t);
  void'(rsps.try_put(t));
endfunction

task i3c_sequencer_mock::wait_for_sequences();
  `uvm_fatal("USGERR", "Not supported");
endtask


function bit i3c_sequencer_mock::has_do_available();
  return !reqs.is_empty();
endfunction


function void i3c_sequencer_mock::disable_auto_item_recording();
endfunction


function bit i3c_sequencer_mock::is_auto_item_recording_enabled();
endfunction
