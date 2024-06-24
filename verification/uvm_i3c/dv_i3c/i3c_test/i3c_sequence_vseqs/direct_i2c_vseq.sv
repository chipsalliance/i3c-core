class direct_i2c_vseq extends base_vseq #(
    .CFG_T                (i3c_sequence_env_cfg),
    .VIRTUAL_SEQUENCER_T  (i3c_sequence_virtual_sequencer)
  );

  `uvm_object_utils(direct_i2c_vseq)

  i2c_direct_data_seq dev;
  i2c_direct_data_seq host;

  function new (string name="");
    super.new(name);
  endfunction : new

  task body();
    dev = i2c_direct_data_seq::type_id::create("dev");
    host = i2c_direct_data_seq::type_id::create("host");
    m_cfg.m_i3c_agent_cfg_dev.i2c_target_addr0 = i2c_addr0;
    m_cfg.m_i3c_agent_cfg_dev.i2c_target_addr1 = i2c_addr1;
    m_cfg.m_i3c_agent_cfg_host.i2c_target_addr0 = i2c_addr0;
    m_cfg.m_i3c_agent_cfg_host.i2c_target_addr1 = i2c_addr1;
    fork
      fork
        dev.start(p_sequencer.m_i3c_sequencer_dev);
        for (int i=0; i < num_runs; i++) begin
          host.start(p_sequencer.m_i3c_sequencer_host);
          #(100*1us);
        end
      join_any
      disable fork;
    join
  endtask: body

endclass : direct_i2c_vseq
