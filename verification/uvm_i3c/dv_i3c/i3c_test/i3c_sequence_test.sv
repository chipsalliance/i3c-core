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

    uvm_config_db#(i3c_sequence_env_cfg)::set(this, "m_top_env", "m_cfg", m_cfg);
    `uvm_info(get_full_name(), $sformatf("\n%s", m_cfg.sprint()),UVM_LOW)
    `uvm_info(get_full_name(), $sformatf("\n%s", m_cfg.m_i3c_agent_cfg_dev.sprint()),UVM_LOW)
    `uvm_info(get_full_name(), $sformatf("\n%s", m_cfg.m_i3c_agent_cfg_host.sprint()),UVM_LOW)
  endfunction

  virtual function void end_of_elaboration_phase (uvm_phase phase);
    uvm_top.print_topology();
  endfunction

endclass : i3c_sequence_test

