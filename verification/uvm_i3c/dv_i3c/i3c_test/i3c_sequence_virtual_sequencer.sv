class i3c_sequence_virtual_sequencer extends uvm_sequencer;
  i3c_sequence_env_cfg  m_cfg;
  i3c_sequencer         m_i3c_sequencer_dev;
  i3c_sequencer         m_i3c_sequencer_host;

  `uvm_component_utils(i3c_sequence_virtual_sequencer)

  function new (string name="", uvm_component parent=null);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

endclass : i3c_sequence_virtual_sequencer
