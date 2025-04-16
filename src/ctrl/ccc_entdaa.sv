module ccc_entdaa
    import controller_pkg::*;
    import i3c_pkg::*;
(
    input logic clk_i,  // Clock
    input logic rst_ni, // Async reset, active low
    input logic [47:0] id_i,
    input start_daa,
    output done_daa
);


  typedef enum logic [7:0] {
    Idle,
    ReceiveRsvdByte,
    AckRsvdByte,
    SendID,
    ReceiveAddr,
    Done,
    Error
  } state_e;

  state_e state_q, state_d;

endmodule
