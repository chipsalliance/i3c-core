module recovery_executor
  import i3c_pkg::*;
(
    input  logic clk_i,  // Clock
    input  logic rst_ni, // Reset (active low)

    // Command interface
    input  logic        cmd_valid_i,
    input  logic        cmd_is_rd_i,
    input  logic [ 7:0] cmd_cmd_i,
    input  logic [15:0] cmd_len_i,
    input  logic        cmd_error_i,
    output logic        cmd_done_o
);

    // Dummy logic to respond after some time
    reg [7:0] cnt;
    always_ff @(posedge clk_i)
        if (cmd_valid_i)    cnt <= 10;
        else if (cnt > 0)   cnt <= cnt - 1;

    assign cmd_done_o = (cnt == 1);

endmodule
