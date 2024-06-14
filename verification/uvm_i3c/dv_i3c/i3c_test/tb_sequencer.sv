module tb;
  import i3c_sequence_test_pkg::*;
  import uvm_pkg::*;

  wire scl, sda;

  logic clk_i;
  logic rst_ni;

  initial begin
    rst_ni = 1'b0;
    clk_i = 1'b0;
    fork
      begin
        for(int i=0; i<100; i++)
          @(posedge clk_i)
        rst_ni = 1'b1;
      end
      forever begin
        clk_i = 1'b0;
        #(2ns);
        clk_i = 1'b1;
        #(2ns);
      end
    join
  end

  i3c_if i3c_bus(
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .scl_io(scl),
    .sda_io(sda)
  );

  // For true I3C test add DUT here and change clock to be system clock

  initial begin
    uvm_config_db#(virtual i3c_if)::set(null, "*.m_top_env.m_i3c_agent*", "vif", i3c_bus);
    $timeformat(-12, 0, " ps", 12);
    run_test();
  end
endmodule
