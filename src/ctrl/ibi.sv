// SPDX-License-Identifier: Apache-2.0

module ibi (

    input logic clk_i,
    input logic rst_ni,

    input  logic begin_i,  // Begin driving the IBI
    output logic done_o    // FSM is done with the IBI

    // Interface to the IBI queue

    // Interface to the "write" module
);

  typedef enum logic [7:0] {
    // Wait state
    Idle,
    //
    DriveStart,
    //
    DriveAddr,
    //
    ReadAck,
    //
    DriveHandoffBit,
    //
    WaitHandoffBit,
    //
    DriveByte,
    //
    DriveTbit,
    // Signal to primary FSM that IBI is done
    Done


  } state_e;

endmodule
