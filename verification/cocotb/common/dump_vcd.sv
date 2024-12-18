// SPDX-License-Identifier: Apache-2.0

module dump_vcd;
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars();
  end
endmodule
