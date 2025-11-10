// SPDX-License-Identifier: Apache-2.0

/*
    The module is responsible for calculating PEC checksum for recovery data
    transferred over I3C. XOR equations were inspired by code generated using
    https://bues.ch/cms/hacking/crcgen
*/

module recovery_pec (

    input logic clk_i,
    input logic rst_ni,
    input logic soft_reset_ni,

    input  logic       valid_i,  // Data valid
    input  logic       init_i,   // When 1 assume that previous CRC was 0
    input  logic [7:0] dat_i,
    output logic [7:0] crc_o
);

  logic [7:0] crc_x;
  logic [7:0] crc_i;

  // Implements CRC8 according to 1+x^1+x^2+x^8 polynomial
  always_comb begin
    crc_x[0] = crc_i[0] ^ crc_i[6] ^ crc_i[7] ^ dat_i[0] ^ dat_i[6] ^ dat_i[7];
    crc_x[1] = crc_i[0] ^ crc_i[1] ^ crc_i[6] ^ dat_i[0] ^ dat_i[1] ^ dat_i[6];
    crc_x[2] = crc_i[0] ^ crc_i[1] ^ crc_i[2] ^ crc_i[6] ^ dat_i[0] ^ dat_i[1] ^ dat_i[2] ^ dat_i[6];
    crc_x[3] = crc_i[1] ^ crc_i[2] ^ crc_i[3] ^ crc_i[7] ^ dat_i[1] ^ dat_i[2] ^ dat_i[3] ^ dat_i[7];
    crc_x[4] = crc_i[2] ^ crc_i[3] ^ crc_i[4] ^ dat_i[2] ^ dat_i[3] ^ dat_i[4];
    crc_x[5] = crc_i[3] ^ crc_i[4] ^ crc_i[5] ^ dat_i[3] ^ dat_i[4] ^ dat_i[5];
    crc_x[6] = crc_i[4] ^ crc_i[5] ^ crc_i[6] ^ dat_i[4] ^ dat_i[5] ^ dat_i[6];
    crc_x[7] = crc_i[5] ^ crc_i[6] ^ crc_i[7] ^ dat_i[5] ^ dat_i[6] ^ dat_i[7];
  end

  // CRC init
  assign crc_i = (init_i) ? 8'h00 : crc_o;

  // Output register
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni)
      crc_o <= 8'h00;
    else begin
      if (!soft_reset_ni) crc_o <= 8'h00;
      else if (valid_i) crc_o <= crc_x;
    end

endmodule
