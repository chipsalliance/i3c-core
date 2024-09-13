// XOR equations generated using https://bues.ch/cms/hacking/crcgen

module recovery_pec (

    input logic clk_i,
    input logic rst_ni,

    input  logic       valid_i,
    input  logic [7:0] dat_i,
    output logic [7:0] crc_o
);

  logic [7:0] crc_x;

  // Implements CRC8 according to 1+x^1+x^2+x^8 polynomial
  always_comb begin
    crc_x[0] = crc_o[0] ^ crc_o[6] ^ crc_o[7] ^ dat_i[0] ^ dat_i[6] ^ dat_i[7];
    crc_x[1] = crc_o[0] ^ crc_o[1] ^ crc_o[6] ^ dat_i[0] ^ dat_i[1] ^ dat_i[6];
    crc_x[2] = crc_o[0] ^ crc_o[1] ^ crc_o[2] ^ crc_o[6] ^ dat_i[0] ^ dat_i[1] ^ dat_i[2] ^ dat_i[6];
    crc_x[3] = crc_o[1] ^ crc_o[2] ^ crc_o[3] ^ crc_o[7] ^ dat_i[1] ^ dat_i[2] ^ dat_i[3] ^ dat_i[7];
    crc_x[4] = crc_o[2] ^ crc_o[3] ^ crc_o[4] ^ dat_i[2] ^ dat_i[3] ^ dat_i[4];
    crc_x[5] = crc_o[3] ^ crc_o[4] ^ crc_o[5] ^ dat_i[3] ^ dat_i[4] ^ dat_i[5];
    crc_x[6] = crc_o[4] ^ crc_o[5] ^ crc_o[6] ^ dat_i[4] ^ dat_i[5] ^ dat_i[6];
    crc_x[7] = crc_o[5] ^ crc_o[6] ^ crc_o[7] ^ dat_i[5] ^ dat_i[6] ^ dat_i[7];
  end

  always_ff @(posedge clk_i)
    if (!rst_ni)
      crc_o <= 8'h00;  // FIXME: The recovery spec doesn't define CRC init value, assuming 0
    else if (valid_i) crc_o <= crc_x;

endmodule
