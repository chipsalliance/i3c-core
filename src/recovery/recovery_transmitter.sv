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

    // TTX TX control
    output logic       data_queue_select_o,
    output logic       start_trig_o,
    input  logic       host_abort_i,

    // PEC computation control
    input  logic [7:0] pec_crc_i,
    output logic       pec_enable_o,

    // Response interface
    input  logic        res_valid_i,
    output logic        res_ready_o,
    input  logic [15:0] res_len_i,

    // Response data interface
    input  logic        res_dvalid_i,
    output logic        res_dready_o,
    input  logic [ 7:0] res_data_i,
    input  logic        res_dlast_i
);

  // TODO
  assign data_queue_select_o  = 1'b1;
  assign start_trig_o         = 1'b0;

  // Internal signals
  logic [15:0] len_q;

  // ....................................................

  // FSM
  typedef enum logic [7:0] {
    Idle        = 'h00,
    TxLenL      = 'h10,
    TxLenH      = 'h11,
    TxData      = 'h20,
    TxPEC       = 'h30,
    Flush       = 'hF0
  } state_e;

  state_e state_d, state_q;

  // State transition
  always_ff @(posedge clk_i)
    if (!rst_ni) state_q <= Idle;
    else state_q <= state_d;

  // Next state
  always_comb
    unique case (state_q)
      Idle: begin
        state_d = Idle;
        if (res_valid_i)
          state_d = TxLenL;
      end

      TxLenL: begin
        state_d = TxLenL;
        if(host_abort_i)
          state_d = Idle;
        else if(data_ready_i)
          state_d = TxLenH;
      end

      TxLenH: begin
        state_d = TxLenH;
        if(host_abort_i)
          state_d = Idle;
        else if(data_ready_i)
          state_d = TxData;
      end

      TxData: begin
        state_d = TxData;
        if(host_abort_i)
          state_d = Flush;
        else if(data_ready_i && data_valid_o)
          if(res_dlast_i)
            state_d = TxPEC;
      end

      TxPEC: begin
        state_d = TxPEC;
        if(data_ready_i && data_valid_o)
          state_d = Idle;
      end

      Flush: begin
        state_d = Flush;
        if(!res_dvalid_i)
          state_d = Idle;
      end

      default:
        state_d = Idle;
    endcase

  // ....................................................

  // Latch length
  always_ff @(posedge clk_i)
    if (state_q == Idle & res_ready_o & res_valid_i)
      len_q <= res_len_i;

  // Response ready
  assign res_ready_o = (state_q == Idle);
  // Response data ready
  //sign res_dready_o = (state_q == TxData) & data_ready_i;
  always_comb
    unique case(state_q)
      TxData:   res_dready_o = data_ready_i;
      Flush:    res_dready_o = 1'b1;
      default:  res_dready_o = 1'b0;
    endcase

  // Data output
  always_comb
    unique case(state_q)
      TxLenL:   data_data_o  = len_q[ 7:0];
      TxLenH:   data_data_o  = len_q[15:8];
      TxPEC:    data_data_o  = pec_crc_i;
      default:  data_data_o  = res_data_i;
    endcase

  always_comb
    unique case(state_q)
      TxLenL:   data_valid_o = 1'b1;
      TxLenH:   data_valid_o = 1'b1;
      TxData:   data_valid_o = res_dvalid_i;
      TxPEC:    data_valid_o = 1'b1;
      default:  data_valid_o = 1'b0;
    endcase

  // PEC enable
  always_comb
    unique case(state_q)
      TxLenL:   pec_enable_o = data_valid_o & data_ready_i;
      TxLenH:   pec_enable_o = data_valid_o & data_ready_i;
      TxData:   pec_enable_o = data_valid_o & data_ready_i;
      default:  pec_enable_o = 1'b0;
    endcase

endmodule
