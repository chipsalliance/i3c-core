module recovery_receiver
  import i3c_pkg::*;
#(
    parameter int unsigned TtiRxDescDataWidth = 32,
    parameter int unsigned TtiTxDescDataWidth = 32
) (
    input  logic clk_i,  // Clock
    input  logic rst_ni, // Reset (active low)

    // TTI RX descriptor
    input  logic                            desc_valid_i,
    output logic                            desc_ready_o,
    input  logic [TtiRxDescDataWidth-1:0]   desc_data_i,

    // TTI RX data
    input  logic                            data_valid_i,
    output logic                            data_ready_o,
    input  logic [                   7:0]   data_data_i,

    // TTI RX data queue mux control and data flow monitor
    output logic                            data_queue_select_o,
    input  logic                            data_queue_ready_i,

    // PEC computation control
    input  logic [                   7:0]   pec_crc_i,
    output logic                            pec_enable_o,
    output logic                            pec_clear_o,

    // Received command interface
    output logic                            cmd_valid_o,
    output logic [                   7:0]   cmd_cmd_o,
    output logic [                  15:0]   cmd_len_o,
    output logic                            cmd_error_o,
    input  logic                            cmd_done_i,
);

    // Internal signals
    logic [15:0]    dcnt;

    logic [ 7:0]    pec_recv;
    logic [ 7:0]    pec_calc;
    logic           pec_match;

    // FSM States
    typedef enum logic [7:0] {
        Idle    = 'h0,
        RxCmd   = 'h10,
        RxLenL  = 'h11,
        RxLenH  = 'h12,
        RxData  = 'h20,
        RxPec   = 'h30,
        Cmd     = 'h40,
        Busy    = 'h41
    } state_e; 

    state_e state_q, state_d;

    // Helper signals
    logic rx_flow;
    logic rx_flow_queue;

    always_comb begin
        rx_flow         = data_valid_i & data_ready_o;
        rx_flow_queue   = data_valid_i & data_queue_ready_i;
    end

    // State transition
    always_ff @(posedge clk_i)
        if (!rst_ni)    state_q <= Idle;
        else            state_q <= state_d;

    always_comb case (state_q)
        Idle:                   state_d = RxCmd;
        RxCmd:  if (rx_flow)    state_d = RxLenL;
        RxLenL: if (rx_flow)    state_d = RxLenH;
        RxLenH: if (rx_flow)    state_d = RxData;
        RxData: if ((rx_flow_queue & dcnt == 1) | (dcnt == 0))
                    state_d = RxPec;
        RxPec:  if (rx_flow)    state_d = Cmd;
        Cmd:                    state_d = Busy;
        Busy:   if (cmd_done_i) state_d = Idle;

        default:                state_d = Idle;
    endcase

    // Data ready
    always_ff @(posedge clk_i)
        if (!rst_ni)
            data_ready_o <= '0;
        else case (state_q)
            RxCmd:                  data_ready_o <= 1'b1;
            RxPec:  if (rx_flow)    data_ready_o <= '0;
        endcase

    // Data queue mux select
    always_ff @(posedge clk_i)
        if (!rst_ni)
            data_queue_select_o <= '0;
        else if (state_q == RxData)
            data_queue_select_o <= !(rx_flow_queue & dcnt == 1);

    // Data counter
    always_ff @(posedge clk_i)
        case (state_q)
            RxLenL:     if (rx_flow)        dcnt[ 7:0] <= data_data_i;
            RxLenH:     if (rx_flow)        dcnt[15:8] <= data_data_i;
            RxData:     if (rx_flow_queue)  dcnt       <= dcnt - 1;
        endcase

    // Command header & PEC capture
    always_ff @(posedge clk_i) begin
        case (state_q)
            RxCmd:      if (rx_flow)        cmd_cmd_o       <= data_data_i;
            RxLenL:     if (rx_flow)        cmd_len_o[ 7:0] <= data_data_i;
            RxLenH:     if (rx_flow)        cmd_len_o[15:8] <= data_data_i;
            RxPec:      if (rx_flow)        pec_recv        <= data_data_i;
        endcase
    end

    // PEC enable
    assign pec_enable_o = (data_queue_select_o) ? rx_flow_queue : rx_flow;
    // PEC clear
    assign pec_clear_o  = (state_q == RxPec) && rx_flow;

    // PEC capture
    always_ff @(posedge clk_i)
        if ((state_q == RxPec) && rx_flow)
            pec_calc <= pec_crc_i;

    // PEC comparator
    assign pec_match = !(|(pec_calc ^ pec_recv));

    // Command interface
    always_ff @(posedge clk_i)
        if (!rst_ni)
            cmd_valid_o <= '0;
        else 
            cmd_valid_o <= (state_q == Cmd);

    assign cmd_error_o = !pec_match;

    // Discard any RX descriptors
    assign desc_ready_o = 1'b1;

endmodule
