// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

/*
  Model of a Push-Pull Driver

  | pu | pd | out |
  -----------------
  |  0 |   0| x   |
  |  0 |   1| 0   |
  |  1 |   0| 1   |
  |  1 |   1| x   |

  TODO: Add assertion for when pull_up_en and pull_down_en have the same state
*/
module buf_pp (
    input  logic pull_up_en,
    input  logic pull_down_en,
    output logic buf_pp_o
);

  always_comb begin : drive_push_pull
    case ({
      pull_up_en, pull_down_en
    })
      2'b00:   buf_pp_o = 1'bx;
      2'b01:   buf_pp_o = 1'b0;
      2'b10:   buf_pp_o = 1'b1;
      2'b11:   buf_pp_o = 1'bx;
      default: buf_pp_o = 1'bx;
    endcase
  end

endmodule
