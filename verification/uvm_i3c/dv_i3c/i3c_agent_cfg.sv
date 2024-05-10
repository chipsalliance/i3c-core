class i3c_agent_cfg extends uvm_object;

  // agent cfg knobs
  bit         is_active = 1'b1;   // active driver/sequencer or passive monitor
  if_mode_e   if_mode;            // interface mode - Host or Device

  // indicate to create and connet driver to sequencer or not
  // if this is a high-level agent, we may just call lower-level agent to send item in seq, then
  // driver isn't needed
  bit         has_driver = 1'b1;

  // use for phase_ready_to_end to add additional delay after ok_to_end is set
  int ok_to_end_delay_ns = 1000;

  // Indicates that the interface is under reset. The derived monitor detects and maintains it.
  bit in_reset;
  bit en_monitor = 1'b1;

  virtual i3c_if  vif;

  // Default timings for I2C 400KHz and I3C 12.5MHz
  bus_timing_t tc;

  // target address is stored when dut is programmed
  bit [6:0] i2c_target_addr0;
  bit [6:0] i2c_target_addr1;
  I3C_device i3c_target0;
  I3C_device i3c_target1;

  // reset driver only without resetting dut
  bit       driver_rst = 0;
  // reset monitor only without resetting dut
  bit       monitor_rst = 0;

  `uvm_object_utils_begin(i3c_agent_cfg)
    `uvm_field_int (is_active,                                UVM_DEFAULT)
    `uvm_field_enum(if_mode_e, if_mode,                       UVM_DEFAULT)
    `uvm_field_int(en_monitor,                                UVM_DEFAULT)
  `uvm_object_utils_end

  function new (string name="");
    super.new(name);
  endfunction : new

endclass : i3c_agent_cfg
