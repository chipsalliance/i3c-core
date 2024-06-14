class i3c_sequence_env extends uvm_env;
  `uvm_component_utils(i3c_sequence_env)

  i3c_sequence_env_cfg  m_cfg;

  i3c_agent             m_i3c_agent_dev;
  i3c_agent             m_i3c_agent_host;

  function new (string name="", uvm_component parent=null);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(i3c_sequence_env_cfg)::get(this, "", "m_cfg", m_cfg)) begin
      `uvm_fatal(get_full_name(), $sformatf("failed to get %s from uvm_config_db", m_cfg.get_type_name()))
    end

    m_i3c_agent_dev = i3c_agent::type_id::create("m_i3c_agent_dev", this);
    m_i3c_agent_host = i3c_agent::type_id::create("m_i3c_agent_host", this);
    uvm_config_db#(i3c_agent_cfg)::set(this, "m_i3c_agent_dev", "cfg", m_cfg.m_i3c_agent_cfg_dev);
    uvm_config_db#(i3c_agent_cfg)::set(this, "m_i3c_agent_host", "cfg", m_cfg.m_i3c_agent_cfg_host);
    m_cfg.m_i3c_agent_cfg_dev.en_monitor = 1'b1;
    m_cfg.m_i3c_agent_cfg_host.en_monitor = 1'b1;
  endfunction : build_phase

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

endclass : i3c_sequence_env

