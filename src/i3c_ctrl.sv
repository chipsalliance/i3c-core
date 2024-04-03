module i3c_ctrl (
    input clk,
    input rst_n,
    // Interface to AHB

    // Interface to SDA/SCL
    input  sda_i,
    output sda_o,
    input  scl_i,
    output scl_o
);

  always_ff @(posedge clk or negedge rst_n) begin : proc_test
    if (!rst_n) begin
      sda_o <= '0;
    end else begin
      sda_o <= '1;
    end
  end

  assign scl_o = '1;

endmodule
