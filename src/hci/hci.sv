// SPDX-License-Identifier: Apache-2.0

// I3C Host Controller Interface
module hci
  import I3CCSR_pkg::I3CCSR_DATA_WIDTH;
  import I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
  import I3CCSR_pkg::I3CCSR__in_t;
  import I3CCSR_pkg::I3CCSR__out_t;
#(
    parameter int unsigned AHB_DATA_WIDTH  = 64,
    parameter int unsigned AHB_ADDR_WIDTH  = 32,
    parameter int unsigned AHB_BURST_WIDTH = 3
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

    // AHB-Lite interface
    input  logic [  AHB_ADDR_WIDTH-1:0] haddr_i,
    input  logic [ AHB_BURST_WIDTH-1:0] hburst_i,     // Unhandled
    input  logic [                 3:0] hprot_i,      // Unhandled
    input  logic [                 2:0] hsize_i,
    input  logic [                 1:0] htrans_i,
    input  logic [  AHB_DATA_WIDTH-1:0] hwdata_i,
    input  logic [AHB_DATA_WIDTH/8-1:0] hwstrb_i,     // Unhandled
    input  logic                        hwrite_i,
    output logic [  AHB_DATA_WIDTH-1:0] hrdata_o,
    output logic                        hreadyout_o,
    output logic                        hresp_o,
    input  logic                        hsel_i,
    input  logic                        hready_i
    // TODO: Add: Missing: I/Os to interface with i2c_controller_fsm
);

  // TODO: Instantiate command queues
  logic s_cpuif_req;
  logic s_cpuif_req_is_wr;
  logic [I3CCSR_MIN_ADDR_WIDTH-1:0] s_cpuif_addr;
  logic [I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_data;
  logic [I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_biten;
  logic s_cpuif_req_stall_wr;
  logic s_cpuif_req_stall_rd;
  logic s_cpuif_rd_ack;
  logic s_cpuif_rd_err;
  logic [I3CCSR_DATA_WIDTH-1:0] s_cpuif_rd_data;
  logic s_cpuif_wr_ack;
  logic s_cpuif_wr_err;

  // AHB <> I3C CSR IF integration
  ahb_if #(
      .AHB_DATA_WIDTH (AHB_DATA_WIDTH),
      .AHB_ADDR_WIDTH (AHB_ADDR_WIDTH),
      .AHB_BURST_WIDTH(AHB_BURST_WIDTH)
  ) i3c_ahb_if (
      .hclk_i(clk_i),
      .hreset_n_i(rst_ni),
      .haddr_i(haddr_i),
      .hburst_i(hburst_i),
      .hprot_i(hprot_i),
      .hsize_i(hsize_i),
      .htrans_i(htrans_i),
      .hwdata_i(hwdata_i),
      .hwstrb_i(hwstrb_i),
      .hwrite_i(hwrite_i),
      .hrdata_o(hrdata_o),
      .hreadyout_o(hreadyout_o),
      .hresp_o(hresp_o),
      .hsel_i(hsel_i),
      .hready_i(hready_i),
      .s_cpuif_req(s_cpuif_req),
      .s_cpuif_req_is_wr(s_cpuif_req_is_wr),
      .s_cpuif_addr(s_cpuif_addr),
      .s_cpuif_wr_data(s_cpuif_wr_data),
      .s_cpuif_wr_biten(s_cpuif_wr_biten),
      .s_cpuif_req_stall_wr(s_cpuif_req_stall_wr),
      .s_cpuif_req_stall_rd(s_cpuif_req_stall_rd),
      .s_cpuif_rd_ack(s_cpuif_rd_ack),
      .s_cpuif_rd_err(s_cpuif_rd_err),
      .s_cpuif_rd_data(s_cpuif_rd_data),
      .s_cpuif_wr_ack(s_cpuif_wr_ack),
      .s_cpuif_wr_err(s_cpuif_wr_err)
  );

  // TODO: Connect hwif
  I3CCSR__in_t  hwif_in;
  I3CCSR__out_t hwif_out;

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
