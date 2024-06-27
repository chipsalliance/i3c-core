class i3c_base_test extends uvm_test;
  `uvm_component_utils(i3c_base_test)

  i3c_env       env;
  i3c_env_cfg   cfg;

  function new (string name="", uvm_component parent=null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    env = i3c_env::type_id::create("env", this);
    cfg = i3c_env_cfg::type_id::create("cfg", this);

    cfg.initialize();
    `DV_CHECK_RANDOMIZE_FATAL(cfg)
    uvm_config_db#(i3c_env_cfg)::set(this, "env", "cfg", cfg);
  endfunction : build_phase

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction : end_of_elaboration_phase

  virtual task run_phase(uvm_phase phase);
    uvm_object      obj;
    uvm_factory     factory;
    uvm_sequence    test_seq;

    string test_seq_s = "direct_vseq";
    void'($value$plusargs("UVM_TEST_SEQ=%0s", test_seq_s));
    factory = uvm_factory::get();
    obj = factory.create_object_by_name(test_seq_s, "", test_seq_s);
    if (obj == null) begin
      factory.print(1);
      `uvm_fatal(get_full_name(), $sformatf("could not create %0s seq", test_seq_s))
    end
    if (!$cast(test_seq, obj)) begin
      `uvm_fatal(get_full_name(), $sformatf("cast failed - %0s is not a uvm_sequence", test_seq_s))
    end
    test_seq.set_sequencer(env.m_vsequencer);
    `DV_CHECK_RANDOMIZE_FATAL(test_seq)
    `uvm_info(get_full_name(), {"Starting test sequence ", test_seq_s}, UVM_MEDIUM)
    phase.raise_objection(this, $sformatf("%s objection raised", get_name()));
    test_seq.start(env.m_vsequencer);
    phase.drop_objection(this, $sformatf("%s objection dropped", get_name()));
    `uvm_info(get_full_name(), {"Finished test sequence ", test_seq_s}, UVM_MEDIUM)
  endtask
endclass : i3c_base_test

