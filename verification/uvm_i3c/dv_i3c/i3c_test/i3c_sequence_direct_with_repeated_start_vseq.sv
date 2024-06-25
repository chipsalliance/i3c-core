class i3c_sequence_direct_with_repeated_start_vseq extends i3c_sequence_base_vseq #(
    .CFG_T                (i3c_sequence_env_cfg),
    .VIRTUAL_SEQUENCER_T  (i3c_sequence_virtual_sequencer)
  );

  `uvm_object_utils(i3c_sequence_direct_with_repeated_start_vseq)

  i3c_direct_data_seq dev;
  i3c_direct_data_with_repeated_start_seq host;

  function new (string name="");
    super.new(name);
  endfunction : new

  function prep_cfg(output I3C_device t0, output I3C_device t1);
    t0 = '{
      IBI_enabled               : 1'b0,
      controller_request_enable : 1'b0,
      hot_join_request_enable   : 1'b0,

      static_addr        : 7'b0,
      static_addr_valid  : 1'b0,
      dynamic_addr       : i3c_addr0,
      dynamic_addr_valid : 1'b1,

      bcr : bcr0,
      dcr : dcr0,
      pid : pid0,
      device_read_limit  : device_read_limit0,
      max_read_length    : max_read_limit0,
      device_write_limit : device_write_limit0,
      max_write_length   : max_write_limit0,
      status             : status0
    };
    t1 = '{
      IBI_enabled               : 1'b0,
      controller_request_enable : 1'b0,
      hot_join_request_enable   : 1'b0,

      static_addr        : 7'b0,
      static_addr_valid  : 1'b0,
      dynamic_addr       : i3c_addr1,
      dynamic_addr_valid : 1'b1,

      bcr : bcr1,
      dcr : dcr1,
      pid : pid1,
      device_read_limit  : device_read_limit1,
      max_read_length    : max_read_limit1,
      device_write_limit : device_write_limit1,
      max_write_length   : max_write_limit1,
      status             : status1
    };
  endfunction

  task body();
    dev = i3c_direct_data_seq::type_id::create("dev");
    host = i3c_direct_data_with_repeated_start_seq::type_id::create("host");
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

endclass
