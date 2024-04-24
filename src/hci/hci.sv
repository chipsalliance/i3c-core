// SPDX-License-Identifier: Apache-2.0

// I3C Host Controller Interface
module hci
  import I3CCSR_pkg::I3CCSR_DATA_WIDTH;
  import I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
  import I3CCSR_pkg::I3CCSR__in_t;
  import I3CCSR_pkg::I3CCSR__out_t;
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

    // TODO: Expose missing queue interfaces
    input  I3CCSR__in_t  hwif_in,
    output I3CCSR__out_t hwif_out
);

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
endmodule
