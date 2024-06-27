class i3c_env extends uvm_env;
  `uvm_component_utils(i3c_env)

  i3c_env_cfg      cfg;

  i3c_agent                 m_i3c_agent;
  // TODO: add AXI agent
  i3c_virtual_sequencer     m_vsequencer;

  function new (string name="", uvm_component parent=null);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(i3c_env_cfg)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal(get_full_name(), $sformatf("failed to get %s from uvm_config_db", cfg.get_type_name()))
    end

    if (cfg.is_active) begin
      m_vsequencer = i3c_virtual_sequencer::type_id::create("m_vsequence", this);
      m_vsequencer.cfg = cfg;
    end

    m_i3c_agent = i3c_agent::type_id::create("m_i3c_agent", this);
    uvm_config_db#(i3c_agent_cfg)::set(this, "m_i3c_agent", "cfg", cfg.m_i3c_agent_cfg);
    cfg.m_i3c_agent_cfg.en_monitor = 1'b1;
  endfunction : build_phase

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    m_vsequencer.m_i3c_sequencer  = m_i3c_agent.sequencer;
    //TODO: add AXI sequencer
  endfunction

endclass : i3c_env

