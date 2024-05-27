module i3c_monitor_test_from_csv;
  import i3c_agent_pkg::*;
  import uvm_pkg::*;

  wire scl, sda;
  string str, unused;
  time timestamp;
  real _timestamp;
  bit sda_delay, scl_delay, sda_state, scl_state;

  logic clk_i;
  logic rst_ni;

  initial begin
    rst_ni = 1'b0;
    clk_i = 1'b0;
    sda_state = 1'b1;
    scl_state = 1'b1;
    fork
      begin
        for(int i=0; i<100; i++)
          @(posedge clk_i)
        rst_ni = 1'b1;
      end
      forever begin
        clk_i = 1'b0;
        #(25ns);
        clk_i = 1'b1;
        #(25ns);
      end
    join
  end

  i3c_if i3c_bus(
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .scl_io(scl),
    .sda_io(sda)
  );

 // Load stimuli from file
  int fd;
  string file_path;
  initial begin
    $value$plusargs ("CSV_FILE_PATH=%s", file_path);
    if ((fd=$fopen(file_path, "r")) != 0) begin
      $fgets(str,fd); // get first line
      while($fgets(str,fd) != 0) begin
        $sscanf(str, "%f%c%d%c%d", _timestamp, unused, scl_delay, unused, sda_delay);
        _timestamp *= 1000000000;
        timestamp = _timestamp;
        #(timestamp - $time);
        sda_state = sda_delay;
        scl_state = scl_delay;
      end
    end
    #(100us) // Allow monitor to finish its tasks
    $finish();
  end

  assign scl = scl_state ? 1'b1: 1'b0;
  assign sda = sda_state ? 1'b1: 1'b0;

  //i3c dut

  initial begin
    static i3c_agent_cfg cfg = new;
    static i3c_monitor recv = new;
    static uvm_phase phase = new;
    cfg.tc.i2c_tc = i2c_1000;
    recv.set_report_verbosity_level(UVM_DEBUG);
    cfg.if_mode = Device;
    cfg.vif = i3c_bus;
    cfg.i3c_target0.static_addr = 7'h72;
    cfg.i3c_target0.static_addr_valid = 1'b1;
    cfg.i3c_target0.dynamic_addr = 7'h72;
    cfg.i3c_target0.dynamic_addr_valid = 1'b1;
    recv.cfg = cfg;
    recv.build_phase(phase);
    recv.run_phase(phase);
    //uvm_config_db#(virtual clk_rst_if)::set(null, "*.env", "clk_rst_vif", clk_rst_if);
    //uvm_config_db#(virtual i3c_if)::set(null, "*.env.m_i3c_agent*", "vif", i3c_if);
    //uvm_config_db#(virtual i2c_dv_if)::set(null, "*.env", "i2c_dv_vif", i2c_dv_if);
    //$timeformat(-12, 0, " ps", 12);
    //run_test();
  end
endmodule
