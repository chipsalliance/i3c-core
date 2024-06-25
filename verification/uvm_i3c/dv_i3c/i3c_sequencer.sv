class i3c_sequencer extends uvm_sequencer #(.REQ(i3c_seq_item), .RSP(i3c_seq_item));
  `uvm_component_utils(i3c_sequencer)

  i3c_agent_cfg cfg;

  function new (string name="", uvm_component parent=null);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction : build_phase

endclass : i3c_sequencer
