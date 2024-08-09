class i3c_sequence_env_cfg extends uvm_object;

  bit is_active         = 1;
  bit en_scb            = 1;

  local bit will_reset  = 0;
  bit under_reset       = 0;
  bit is_initialized;

  // i3c agent cfg
  i3c_agent_cfg m_i3c_agent_cfg_dev;
  i3c_agent_cfg m_i3c_agent_cfg_host;

  `uvm_object_utils_begin(i3c_sequence_env_cfg)
    `uvm_field_int   (is_active,   UVM_DEFAULT)
    `uvm_field_int   (en_scb,      UVM_DEFAULT)
    `uvm_field_object(m_i3c_agent_cfg_dev, UVM_DEFAULT)
    `uvm_field_object(m_i3c_agent_cfg_host, UVM_DEFAULT)
  `uvm_object_utils_end

  function new (string name="");
    super.new(name);
  endfunction : new

  virtual function void initialize();
    is_initialized = 1'b1;
    // create i2c_agent_cfg
    m_i3c_agent_cfg_dev = i3c_agent_cfg::type_id::create("m_i3c_agent_cfg_dev");
    m_i3c_agent_cfg_host = i3c_agent_cfg::type_id::create("m_i3c_agent_cfg_host");
    // set agent to Device mode
    m_i3c_agent_cfg_dev.if_mode = Device;
    m_i3c_agent_cfg_host.if_mode = Host;
  endfunction

endclass : i3c_sequence_env_cfg
