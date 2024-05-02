// SPDX-License-Identifier: Apache-2.0

// I3C Host Controller Interface
module hci
  import I3CCSR_pkg::I3CCSR_DATA_WIDTH;
  import I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
  import I3CCSR_pkg::I3CCSR__in_t;
  import I3CCSR_pkg::I3CCSR__out_t;
#(
    parameter DAT_SIZE = 128,
    parameter DCT_SIZE = 128
)
(
    input clk_i,  // clock
    input rst_ni, // active low reset

    // I3C SW CSR access interface
    input  logic                             s_cpuif_req,
    input  logic                             s_cpuif_req_is_wr,
    input  logic [I3CCSR_MIN_ADDR_WIDTH-1:0] s_cpuif_addr,
    input  logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_data,
    input  logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_biten,
    output logic                             s_cpuif_req_stall_wr,
    output logic                             s_cpuif_req_stall_rd,
    output logic                             s_cpuif_rd_ack,
    output logic                             s_cpuif_rd_err,
    output logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_rd_data,
    output logic                             s_cpuif_wr_ack,
    output logic                             s_cpuif_wr_err,

    // DAT <-> Controller interface
    input  logic                        dat_read_valid_hw_i,
    input  logic [$clog2(DAT_SIZE)-1:0] dat_index_hw_i,
    output logic [                63:0] dat_rdata_hw_o,

    // DCT <-> Controller interface
    input  logic                        dct_write_valid_hw_i,
    input  logic                        dct_read_valid_hw_i,
    input  logic [$clog2(DCT_SIZE)-1:0] dct_index_hw_i,
    input  logic [               127:0] dct_wdata_hw_i,
    output logic [               127:0] dct_rdata_hw_o

    // TODO: Expose missing queue interfaces
);
  // CSR HW interface
  I3CCSR__in_t hwif_in;
  I3CCSR__out_t hwif_out;

  // TODO: Add missing queues

  I3CCSR i3c_csr (
      .clk(clk_i),
      .rst(~rst_ni),

      .s_cpuif_req(s_cpuif_req),
      .s_cpuif_req_is_wr(s_cpuif_req_is_wr),
      .s_cpuif_addr(s_cpuif_addr),
      .s_cpuif_wr_data(s_cpuif_wr_data),
      .s_cpuif_wr_biten(s_cpuif_wr_biten),  // Write strobes not handled by AHB-Lite interface
      .s_cpuif_req_stall_wr(s_cpuif_req_stall_wr),
      .s_cpuif_req_stall_rd(s_cpuif_req_stall_rd),
      .s_cpuif_rd_ack(s_cpuif_rd_ack),  // Ignored by AHB component
      .s_cpuif_rd_err(s_cpuif_rd_err),
      .s_cpuif_rd_data(s_cpuif_rd_data),
      .s_cpuif_wr_ack(s_cpuif_wr_ack),  // Ignored by AHB component
      .s_cpuif_wr_err(s_cpuif_wr_err),

      .hwif_in (hwif_in),
      .hwif_out(hwif_out)
  );

  dxt #(
    .DAT_SIZE(DAT_SIZE),
    .DCT_SIZE(DCT_SIZE)
  ) dxt (
    .clk_i,  // clock
    .rst_ni, // active low reset
    .dat_read_valid_hw_i,
    .dat_index_hw_i,
    .dat_rdata_hw_o,
    .dct_write_valid_hw_i,
    .dct_read_valid_hw_i,
    .dct_index_hw_i,
    .dct_wdata_hw_i,
    .dct_rdata_hw_o,
    .hwif_out_i(hwif_out),
    .hwif_in_o(hwif_in)
  );

endmodule
