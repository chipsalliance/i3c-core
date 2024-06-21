class i3c_sequence_direct_with_rstart_vseq extends i3c_sequence_base_vseq #(
    .CFG_T                (i3c_sequence_env_cfg),
    .VIRTUAL_SEQUENCER_T  (i3c_sequence_virtual_sequencer)
  );

  `uvm_object_utils(i3c_sequence_direct_with_rstart_vseq)

  i3c_direct_data_seq dev;
  i3c_direct_data_with_rstart_seq host;

  function new (string name="");
    super.new(name);
  endfunction : new

  task body();
    dev = i3c_direct_data_seq::type_id::create("dev");
    host = i3c_direct_data_with_rstart_seq::type_id::create("host");
    prep_cfg(.t0(m_cfg.m_i3c_agent_cfg_dev.i3c_target0),
             .t1(m_cfg.m_i3c_agent_cfg_dev.i3c_target1));
    prep_cfg(.t0(m_cfg.m_i3c_agent_cfg_host.i3c_target0),
             .t1(m_cfg.m_i3c_agent_cfg_host.i3c_target1));
    fork
      fork
        dev.start(p_sequencer.m_i3c_sequencer_dev);
        for (int i=0; i < num_runs; i++) begin
          host.num_trans = num_trans;
          host.start(p_sequencer.m_i3c_sequencer_host);
          this.randomize(num_trans);
        end
      join_any
      disable fork;
    join
  endtask: body

endclass : i3c_sequence_direct_with_rstart_vseq
