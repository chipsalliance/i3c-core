// SPDX-License-Identifier: Apache-2.0

// I3C Device Address/Characteristic Tables
module dxt
  import I3CCSR_pkg::*;
  import i3c_pkg::*;
#(
    parameter int unsigned DatAw = 7,
    parameter int unsigned DctAw = 7
) (
    input logic clk_i,  // clock
    input logic rst_ni, // active low reset

    // DAT <-> Controller interface
    input  logic             dat_read_valid_hw_i,
    input  logic [DatAw-1:0] dat_index_hw_i,
    output logic [     63:0] dat_rdata_hw_o,

    // DCT <-> Controller interface
    input  logic             dct_write_valid_hw_i,
    input  logic             dct_read_valid_hw_i,
    input  logic [DctAw-1:0] dct_index_hw_i,
    input  logic [    127:0] dct_wdata_hw_i,
    output logic [    127:0] dct_rdata_hw_o,

    // DAT CSR interface
    input  I3CCSR__DAT__out_t csr_dat_hwif_i,
    output I3CCSR__DAT__in_t  csr_dat_hwif_o,

    // DCT CSR interface
    input  I3CCSR__DCT__out_t csr_dct_hwif_i,
    output I3CCSR__DCT__in_t  csr_dct_hwif_o,

    // DAT memory export interface
    input  dat_mem_src_t  dat_mem_src_i,
    output dat_mem_sink_t dat_mem_sink_o,

    // DCT memory export interface
    input  dct_mem_src_t  dct_mem_src_i,
    output dct_mem_sink_t dct_mem_sink_o
);

  // Device Address Table
  logic dat_read_valid;
  logic dat_write_valid;
  logic [DatAw-1:0] dat_addr;
  logic [63:0] dat_wdata;
  logic [63:0] dat_wmask;
  logic [63:0] dat_rdata;
  logic [DatAw-1:0] dat_index_sw;
  logic dat_word_index_sw;

  logic dat_rd_ack;
  logic dat_wr_ack;

  // Two 32-bit words per 64-bit word so retrieve index by shifting 3 bits
  assign dat_index_sw = csr_dat_hwif_i.addr[DatAw+2:3];
  // Second bit indicates which 32-bit word is requested by software
  assign dat_word_index_sw = csr_dat_hwif_i.addr[2];

  assign dat_read_valid = csr_dat_hwif_i.req | dat_read_valid_hw_i;
  assign dat_write_valid = csr_dat_hwif_i.req_is_wr;

  // Connect signals to DAT memory
  assign dat_rdata_hw_o = dat_mem_src_i.rdata;
  assign dat_mem_sink_o.req = dat_read_valid;
  assign dat_mem_sink_o.write = dat_write_valid;
  assign dat_mem_sink_o.addr = dat_addr;
  assign dat_mem_sink_o.wdata = dat_wdata;
  assign dat_mem_sink_o.wmask = dat_wmask;

  always_comb begin
    if (dat_read_valid_hw_i) begin
      dat_addr  = dat_index_hw_i;
      dat_wmask = {64{1'b1}};
      dat_wdata = '0;
    end else begin
      dat_addr = dat_index_sw;

      case (dat_word_index_sw)
        1'b0: begin
          // Word mask = 2'b01
          dat_wmask = {{32{1'b0}}, {32{1'b1}}};
          dat_wdata = {{32{1'b0}}, csr_dat_hwif_i.wr_data};
        end
        1'b1: begin
          // Word mask = 2'b10
          dat_wmask = {{32{1'b1}}, {32{1'b0}}};
          dat_wdata = {csr_dat_hwif_i.wr_data, {32{1'b0}}};
        end
        default: begin
          dat_wmask = '0;
          dat_wdata = '0;
        end
      endcase
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      csr_dat_hwif_o.rd_data <= '0;
    end else begin
      case (dat_word_index_sw)
        1'd0: csr_dat_hwif_o.rd_data <= dat_mem_src_i.rdata[31:0];
        1'd1: csr_dat_hwif_o.rd_data <= dat_mem_src_i.rdata[63:32];
        default: csr_dat_hwif_o.rd_data <= '0;
      endcase
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      dat_rd_ack <= 1'b0;
      dat_wr_ack <= 1'b0;
      csr_dat_hwif_o.rd_ack <= 1'b0;
      csr_dat_hwif_o.wr_ack <= 1'b0;
    end else begin
      dat_rd_ack <= csr_dat_hwif_i.req & ~csr_dat_hwif_i.req_is_wr & ~dat_read_valid_hw_i;
      csr_dat_hwif_o.rd_ack <= dat_rd_ack;

      dat_wr_ack <= csr_dat_hwif_i.req & csr_dat_hwif_i.req_is_wr;
      csr_dat_hwif_o.wr_ack <= dat_wr_ack;
    end
  end

  // Device Context Table
  logic dct_read_valid;
  logic dct_write_valid;
  logic [DctAw-1:0] dct_addr;
  logic [127:0] dct_wdata;
  logic [127:0] dct_wmask;
  logic [127:0] dct_rdata;
  logic [DctAw-1:0] dct_index_sw;
  logic [1:0] dct_word_index_sw;

  logic dct_rd_ack;
  logic dct_wr_ack;

  // Four 32-bit words per 128-bit word so retrieve index by shifting 4 bits
  assign dct_index_sw = csr_dct_hwif_i.addr[DctAw+3:4];
  // Second and third bits indicate which 32-bit word is requested by software
  assign dct_word_index_sw = csr_dct_hwif_i.addr[3:2];

  assign dct_read_valid = csr_dct_hwif_i.req | dct_read_valid_hw_i;
  assign dct_write_valid = dct_write_valid_hw_i;
  assign dct_wdata = dct_wdata_hw_i;

  // Connect signals to DCT memory
  assign dct_rdata_hw_o = dct_mem_src_i.rdata;
  assign dct_mem_sink_o.req = dct_read_valid;
  assign dct_mem_sink_o.write = dct_write_valid;
  assign dct_mem_sink_o.addr = dct_addr;
  assign dct_mem_sink_o.wdata = dct_wdata;
  assign dct_mem_sink_o.wmask = dct_wmask;

  always_comb begin
    if (dct_read_valid_hw_i) begin
      dct_addr  = dct_index_hw_i;
      dct_wmask = {128{1'b1}};
    end else begin
      dct_addr  = dct_index_sw;
      dct_wmask = {128{1'b0}};
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      csr_dct_hwif_o.rd_data <= '0;
    end else begin
      case (dct_word_index_sw)
        2'd0: csr_dct_hwif_o.rd_data <= dct_mem_src_i.rdata[31:0];
        2'd1: csr_dct_hwif_o.rd_data <= dct_mem_src_i.rdata[63:32];
        2'd2: csr_dct_hwif_o.rd_data <= dct_mem_src_i.rdata[95:64];
        2'd3: csr_dct_hwif_o.rd_data <= dct_mem_src_i.rdata[127:96];
        default: csr_dct_hwif_o.rd_data <= '0;
      endcase
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      dct_rd_ack <= 1'b0;
      dct_wr_ack <= 1'b0;
      csr_dct_hwif_o.rd_ack <= 1'b0;
      csr_dct_hwif_o.wr_ack <= 1'b0;
    end else begin
      dct_rd_ack <= csr_dct_hwif_i.req & ~csr_dct_hwif_i.req_is_wr & ~dct_read_valid_hw_i;
      csr_dct_hwif_o.rd_ack <= dct_rd_ack;
      // ACK write requests to remove CPU stall, even though they're illegal to DCT
      dct_wr_ack <= csr_dct_hwif_i.req & csr_dct_hwif_i.req_is_wr;
      csr_dct_hwif_o.wr_ack <= dct_wr_ack;
    end
  end

endmodule
