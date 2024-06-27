class i3c_base_vseq #(type CFG_T               = i3c_env_cfg,
                      type VIRTUAL_SEQUENCER_T = i3c_virtual_sequencer
) extends uvm_sequence;

  `uvm_object_utils(i3c_base_vseq)
  `uvm_declare_p_sequencer(VIRTUAL_SEQUENCER_T)

  CFG_T cfg;

  rand int num_trans;
  rand int num_runs;

  rand bit [6:0] i2c_addr0, i2c_addr1;
  rand bit [6:0] i3c_addr0, i3c_addr1;
  rand bit [6:0] target_addr; // address for the I3C DUT in Device mode
  rand bit [7:0] bcr0, bcr1;
  rand bit [7:0] dcr0, dcr1;
  rand bit [47:0] pid0, pid1;
  rand bit [15:0] device_read_limit0, device_read_limit1;
  rand bit [15:0] device_write_limit0, device_write_limit1;
  rand bit [15:0] max_read_limit0, max_read_limit1;
  rand bit [15:0] max_write_limit0, max_write_limit1;
  rand bit [15:0] status0, status1;

  constraint num_trans_c {
    num_trans inside {[1:20]};
  }

  constraint num_runs_c {
    num_runs inside {[1:20]};
  }

  constraint i2c_addr_c {
    solve i2c_addr0 before i2c_addr1;
    i2c_addr0 inside {[8:119]};
    i2c_addr1 inside {[8:119]};
    i2c_addr1 != i2c_addr0;
  }

  constraint i3c_addr_c {
    solve i3c_addr0 before i3c_addr1;
    solve i3c_addr1 before target_addr;
    !(i3c_addr0 inside {0, 1, 2, 62, 94, 110, 118, 122, 124, 126, 127});
    !(i3c_addr1 inside {0, 1, 2, 62, 94, 110, 118, 122, 124, 126, 127});
    !(target_addr inside {0, 1, 2, 62, 94, 110, 118, 122, 124, 126, 127});
    i3c_addr1 != i3c_addr0;
    target_addr != i3c_addr0;
    target_addr != i3c_addr1;
  }

  constraint bcr_c {
    bcr0[7:0] == 0;
    bcr1[7:0] == 0;
  }

  constraint dcr_c {
    dcr0[7:0] == 0;
    dcr1[7:0] == 0;
  }

  constraint pid_c {
    pid0[32] == 1;
    pid1[32] == 1;
  }

  constraint read_limit_c {
    solve device_read_limit0 before max_read_limit0;
    solve device_read_limit1 before max_read_limit1;
    device_read_limit0 inside {0, [16:65535]};
    device_read_limit1 inside {0, [16:65535]};
    max_read_limit0 <= device_read_limit0;
    max_read_limit1 <= device_read_limit1;
  }

  constraint write_limit_c {
    solve device_write_limit0 before max_write_limit0;
    solve device_write_limit1 before max_write_limit1;
    device_write_limit0 inside {0, [16:65535]};
    device_write_limit1 inside {0, [16:65535]};
    max_write_limit0 <= device_write_limit0;
    max_write_limit1 <= device_write_limit1;
  }

  function new (string name="");
    super.new(name);
  endfunction : new

  virtual function void set_handles();
    if (p_sequencer == null)
      `uvm_fatal(get_full_name(), "Did you forget to call `set_sequencer()`?")
    cfg = p_sequencer.cfg;
  endfunction

  virtual function void configure_vseq();
  endfunction

  function void pre_randomize();
    if (cfg == null) set_handles();
    configure_vseq();
  endfunction

  task pre_start();
    super.pre_start();
    if (cfg == null) set_handles();
    num_trans.rand_mode(0);
  endtask

  task body();
    `uvm_fatal(`gtn, "Need to override this when you extend from this class!")
  endtask : body

endclass

