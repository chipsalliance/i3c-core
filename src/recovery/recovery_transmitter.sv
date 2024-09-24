module recovery_transmitter
  import i3c_pkg::*;
# (
    parameter int unsigned TtiTxDescDataWidth = 32
) (
    input  logic clk_i,  // Clock
    input  logic rst_ni, // Reset (active low)

    // TTI TX descriptor
    output logic                          desc_valid_o,
    input  logic                          desc_ready_i,
    output logic [TtiTxDescDataWidth-1:0] desc_data_o,

    // TTI TX data
    output logic       data_valid_o,
    input  logic       data_ready_i,
    output logic [7:0] data_data_o,

    // TTX TX mux control
    output logic       data_queue_select_o,
    output logic       start_trig_o,

    // PEC computation control
    input  logic [7:0] pec_crc_i,
    output logic       pec_enable_o,
    output logic       pec_clear_o,

    // Response interface
    input  logic        res_valid_i,
    output logic        res_ready_o,
    input  logic [15:0] res_len_i,

    input  logic        res_dvalid_i,
    output logic        res_dready_o,
    input  logic [ 7:0] res_data_i
);

    assign data_queue_select_o  = 1'b1;
    assign start_trig_o         = 1'b0;

    // Dummy reply
    reg [7:0] lcnt;

    always_ff @(posedge clk_i)
        if (!rst_ni)
            lcnt <= 0;
        else if (lcnt == 0 & res_valid_i)
            lcnt <= 3;
        else if (lcnt != 0)
            lcnt <= lcnt - 1;

    assign res_ready_o = (lcnt == 0);

    // Dummy reply
    reg [7:0] dcnt;

    always_ff @(posedge clk_i)
        if (!rst_ni)
            dcnt <= 0;
        else if (dcnt == 0 & res_dvalid_i)
            dcnt <= 3;
        else if (dcnt != 0)
            dcnt <= dcnt - 1;

    assign res_dready_o = (dcnt == 0);

endmodule
