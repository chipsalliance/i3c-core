class i3c_agent extends uvm_agent;
  `uvm_component_utils(i3c_agent)

  i3c_agent_cfg cfg;
//  i3c_driver    driver;
//  i3c_sequencer sequencer;
  i3c_monitor   monitor;

  function new (string name="", uvm_component parent=null);
    super.new(name, parent);
  endfunction : new


  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // get CFG_T object from uvm_config_db
    if (!uvm_config_db#(i3c_agent_cfg)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal(get_full_name(), $sformatf("failed to get %s from uvm_config_db", cfg.get_type_name()))
    end
    `uvm_info(get_full_name(), $sformatf("\n%0s", cfg.sprint()), UVM_HIGH)

    monitor = i3c_monitor::type_id::create("monitor", this);
    monitor.cfg = cfg;

//    if (cfg.is_active) begin
//      sequencer = i3c_sequencer::type_id::create("sequencer", this);
//      sequencer.cfg = cfg;
//
//      if (cfg.has_driver) begin
//        driver = i3c_driver::type_id::create("driver", this);
//        driver.cfg = cfg;
//      end
//    end
//    if (!uvm_config_db#(virtual i3c_if)::get(this, "", "vif", cfg.vif)) begin
//      `uvm_fatal(`gfn, "failed to get i3c_if handle from uvm_config_db")
//    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
//    if (cfg.is_active && cfg.has_driver) begin
//      driver.seq_item_port.connect(sequencer.seq_item_export);
//    end
  endfunction
endclass

