class i3c_sequence_direct_vseq extends i3c_base_vseq #(
  .CFG_T(i3c_sequence_env_cfg),
  .VIRTUAL_SEQUENCER_T(i3c_sequence_virtual_sequencer)
);

  `uvm_object_utils(i3c_sequence_direct_vseq)

  function new (string name="");
    super.new(name);
  endfunction : new

  task body();
  endtask: body

endclass
