module recovery_receiver
  import i3c_pkg::*;
#(
    parameter int unsigned TtiRxDescDataWidth = 32,
    parameter int unsigned TtiTxDescDataWidth = 32
) (
    input logic clk_i,  // Clock
    input logic rst_ni, // Reset (active low)

    // TTI RX descriptor
    input  logic                          desc_valid_i,
    output logic                          desc_ready_o,
    input  logic [TtiRxDescDataWidth-1:0] desc_data_i,

    // TTI RX data
    input  logic       data_valid_i,
    output logic       data_ready_o,
    input  logic [7:0] data_data_i,

    // TTI RX data queue mux control and data flow monitor
    output logic data_queue_select_o,
    output logic data_queue_flush_o,
    input  logic data_queue_flow_i,

    // Bus condition detection
    input logic bus_start_i,
    input logic bus_stop_i,

    // PEC computation control
    input  logic [7:0] pec_crc_i,
    output logic       pec_enable_o,

    // Received command interface
    output logic        cmd_valid_o,
    output logic        cmd_is_rd_o,
    output logic [ 7:0] cmd_cmd_o,
    output logic [15:0] cmd_len_o,
    output logic        cmd_error_o,
    input  logic        cmd_done_i
);

  // Internal signals
  logic        rx_flow;
  logic [15:0] dcnt;

  logic [ 7:0] len_lsb;
  logic [ 7:0] len_msb;

  logic [ 7:0] pec_recv;
  logic [ 7:0] pec_calc;
  logic        pec_match;

  assign rx_flow = data_valid_i & data_ready_o;

  // FSM States
  typedef enum logic [7:0] {
    Idle    = 'h0,
    RxCmd   = 'h10,
    RxLenL  = 'h11,
    RxLenH  = 'h12,
    RxData  = 'h20,
    RxPec   = 'h30,
    CmdIsRd = 'h38,
    Cmd     = 'h40,
    Busy    = 'h41
  } state_e;

  state_e state_q, state_d;

  // State transition
  always_ff @(posedge clk_i)
    if (!rst_ni) state_q <= Idle;
    else state_q <= state_d;

  always_comb begin
    state_d = state_q;
    unique case (state_q)
      Idle: begin
        if (bus_start_i) state_d = RxCmd;
      end

      RxCmd: begin
        if (rx_flow) state_d = RxLenL;
        else if (bus_stop_i) state_d = Idle;
      end

      RxLenL: begin
        if (rx_flow) state_d = RxLenH;
        else if (bus_stop_i) state_d = Idle;
      end

      RxLenH: begin
        if (rx_flow) state_d = RxData;
        else if (bus_start_i) state_d = CmdIsRd;
        else if (bus_stop_i) state_d = Idle;
      end

      RxData: begin
        if ((data_queue_flow_i & dcnt == 1) | (dcnt == 0)) state_d = RxPec;
        else if (bus_stop_i) state_d = Idle;
      end

      RxPec: begin
        if (rx_flow) state_d = Cmd;
        else if (bus_stop_i) state_d = Idle;
      end

      CmdIsRd: state_d = Cmd;

      Cmd: state_d = Busy;

      Busy: begin
        if (cmd_done_i) state_d = Idle;
      end

      default: state_d = Idle;
    endcase
  end

  // Data ready
  always_ff @(posedge clk_i)
    if (!rst_ni) data_ready_o <= '0;
    else
      unique case (state_q)
        RxCmd:   data_ready_o <= 1'b1;
        RxPec:   if (rx_flow) data_ready_o <= '0;
        default: data_ready_o <= data_ready_o;
      endcase

  // Data queue mux select
  always_ff @(posedge clk_i)
    if (!rst_ni) data_queue_select_o <= 1'b1;
    else if (state_q == RxData) data_queue_select_o <= (data_queue_flow_i & dcnt == 1);

  // Data queue flush signal. Flush if data length is not divisible by 4
  always_ff @(posedge clk_i)
    if (!rst_ni) data_queue_flush_o <= 1'b0;
    else data_queue_flush_o <= (state_q == Cmd) && |(len_lsb[1:0]);

  // Data counter
  always_ff @(posedge clk_i)
    unique case (state_q)
      RxLenL:  if (rx_flow) dcnt[7:0] <= data_data_i;
      RxLenH:  if (rx_flow) dcnt[15:8] <= data_data_i;
      RxData:  if (data_queue_flow_i) dcnt <= dcnt - 1;
      default: dcnt <= dcnt;
    endcase

  // Command header & PEC capture
  always_ff @(posedge clk_i) begin
    unique case (state_q)
      RxCmd:  if (rx_flow) cmd_cmd_o <= data_data_i;
      RxLenL: if (rx_flow) len_lsb <= data_data_i;
      RxLenH: if (rx_flow) len_msb <= data_data_i;
      RxPec:  if (rx_flow) pec_recv <= data_data_i;

      CmdIsRd: begin
        len_lsb  <= '0;
        len_msb  <= '0;
        pec_recv <= len_lsb;
      end

      default: begin
        cmd_cmd_o <= cmd_cmd_o;
        len_lsb   <= len_lsb;
        len_msb   <= len_msb;
        pec_recv  <= pec_recv;
      end
    endcase
  end

  // PEC enable
  assign pec_enable_o = (data_queue_select_o) ? rx_flow : data_queue_flow_i;

  // PEC capture
  always_ff @(posedge clk_i)
    unique case (state_q)
      RxPec:   if (rx_flow) pec_calc <= pec_crc_i;  // PEC of a write command
      RxLenL:  if (rx_flow) pec_calc <= pec_crc_i;  // PEC of a read command
      default: pec_calc <= pec_calc;
    endcase

  // PEC comparator
  assign pec_match = !(|(pec_calc ^ pec_recv));

  // Command interface
  always_ff @(posedge clk_i)
    if (!rst_ni) begin
      cmd_valid_o <= '0;
      cmd_is_rd_o <= '0;
    end else begin
      cmd_valid_o <= (state_q == Cmd);

      if (state_q == CmdIsRd) cmd_is_rd_o <= 1'b1;
      if (state_q == Idle) cmd_is_rd_o <= '0;
    end

  assign cmd_len_o = {len_msb, len_lsb};
  assign cmd_error_o = !pec_match;

  // Discard any RX descriptors
  assign desc_ready_o = 1'b1;

endmodule
