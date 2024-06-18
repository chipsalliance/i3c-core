class i3c_sequence_test extends uvm_test;
  `uvm_component_utils(i3c_sequence_test)

  function new (string name, uvm_component parent = null);
    super.new(name, parent);
  endfunction

  i3c_sequence_env      m_top_env;
  i3c_sequence_env_cfg  m_cfg;

  virtual function void build_phase (uvm_phase phase);
    super.build_phase(phase);

    m_top_env = i3c_sequence_env::type_id::create("m_top_env", this);
    m_cfg     = i3c_sequence_env_cfg::type_id::create("m_cfg", this);

    m_cfg.initialize();
    `DV_CHECK_RANDOMIZE_FATAL(m_cfg)

    uvm_config_db#(i3c_sequence_env_cfg)::set(this, "m_top_env", "m_cfg", m_cfg);
    `uvm_info(get_full_name(), $sformatf("\n%s", m_cfg.sprint()),UVM_LOW)
    `uvm_info(get_full_name(), $sformatf("\n%s", m_cfg.m_i3c_agent_cfg_dev.sprint()),UVM_LOW)
    `uvm_info(get_full_name(), $sformatf("\n%s", m_cfg.m_i3c_agent_cfg_host.sprint()),UVM_LOW)
  endfunction

  virtual function void end_of_elaboration_phase (uvm_phase phase);
    uvm_top.print_topology();
  endfunction

  virtual task run_phase(uvm_phase phase);
    uvm_object      obj;
    uvm_factory     factory;
    uvm_sequence    test_seq;

    string test_seq_s = "i3c_sequence_direct_vseq";
    //void'($value$plusargs("UVM_TEST_SEQ=%0s", test_seq_s));
    factory = uvm_factory::get();
    obj = factory.create_object_by_name(test_seq_s, "", test_seq_s);
    if (obj == null) begin
      factory.print(1);
      `uvm_fatal(get_full_name(), $sformatf("could not create %0s seq", test_seq_s))
    end
    if (!$cast(test_seq, obj)) begin
      `uvm_fatal(get_full_name(), $sformatf("cast failed - %0s is not a uvm_sequence", test_seq_s))
    end
    test_seq.set_sequencer(m_top_env.m_vsequencer);
    `DV_CHECK_RANDOMIZE_FATAL(test_seq)
    `uvm_info(get_full_name(), {"Starting test sequence ", test_seq_s}, UVM_MEDIUM)
    phase.raise_objection(this, $sformatf("%s objection raised", get_name()));
    test_seq.start(m_top_env.m_vsequencer);
    phase.drop_objection(this, $sformatf("%s objection dropped", get_name()));
    `uvm_info(get_full_name(), {"Finished test sequence ", test_seq_s}, UVM_MEDIUM)
  endtask

endclass : i3c_sequence_test

