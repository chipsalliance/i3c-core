// SPDX-License-Identifier: Apache-2.0

module ccc
  import controller_pkg::*;
  import i3c_pkg::*;
  import I3CCSR_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    // Latch CCC data
    input logic [7:0] command_code_i,
    input logic command_code_valid_i,

    input logic [7:0] defining_byte_i,
    input logic defining_byte_valid_i,

    //TODO: Establish correct size
    input logic [7:0] command_data_i,
    input logic command_data_valid_i,

    input logic [31:0] queue_size_reg_i,
    output logic response_byte_o,
    output logic response_valid_o,

    output logic is_in_hdr_mode_o,

    output logic [7:0] rst_action_o,

    // TODO: establish correct sizes
    output logic [1:0] command_min_bytes_o,
    output logic [1:0] command_max_bytes_o
);

  // Latch CCC data
  logic [7:0] command_code;
  logic [7:0] defining_byte;
  logic       defining_byte_valid;
  logic [7:0] command_data;

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_latch_inputs
    if (~rst_ni) begin
      command_code  <= '0;
      defining_byte <= '0;
      defining_byte_valid <= '0;
      command_data  <= '0;
    end else begin
      command_code  <= command_code_valid_i ? command_code_i : command_code;
      defining_byte <= defining_byte_valid_i ? defining_byte_i : defining_byte;
      defining_byte_valid <= defining_byte_valid_i;
      command_data  <= command_data_valid_i ? command_data_i : command_data;
    end
  end

  // GETMRL
  logic [7:0] tx_data_buffer_size;
  logic [7:0] rx_data_buffer_size;
  logic [7:0] ibi_status_size;
  logic [7:0] cr_queue_size;

  assign tx_data_buffer_size = queue_size_reg_i[31:24];
  assign rx_data_buffer_size = queue_size_reg_i[23:16];
  assign ibi_status_size = queue_size_reg_i[15:8];
  assign cr_queue_size = queue_size_reg_i[7:0];

  // Decode CCC
  logic is_direct_cmd = command_code[7];  // 0 - BCast, 1 - Direct

  always_comb begin
    response_valid_o = '0;
    response_byte_o  = '0;
    is_in_hdr_mode_o = '0;
    rst_action_o = '0;
    command_min_bytes_o = '0;
    command_max_bytes_o = '0;
    unique case (command_code)
      // Idle: Wait for command appearance in the Command Queue
      `I3C_DIRECT_GETMRL: begin
        response_byte_o  = rx_data_buffer_size;
        response_valid_o = '1;
      end
      `I3C_DIRECT_GETMWL: begin
        response_byte_o  = tx_data_buffer_size;
        response_valid_o = '1;
      end
      `I3C_BCAST_ENTHDR0: begin
        is_in_hdr_mode_o = '1;
      end
      `I3C_DIRECT_RSTACT, `I3C_BCAST_RSTACT: begin
        command_min_bytes_o = '1;
        command_max_bytes_o = '1;
        if (defining_byte_valid) begin
          rst_action_o = defining_byte;
        end
      end
      default: ;
    endcase
  end
endmodule
