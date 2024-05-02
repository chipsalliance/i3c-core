// SPDX-License-Identifier: Apache-2.0

// I3C Device Address/Characteristic Tables
module dxt
  import I3CCSR_pkg::*;
#(
    parameter  DAT_SIZE  = 128,
    parameter  DCT_SIZE  = 128,
    localparam DAT_DEPTH = DAT_SIZE * 2,  // Data width = 64 bit
    localparam DCT_DEPTH = DCT_SIZE * 4   // Data width = 128 bit
) (
    input logic clk_i,  // clock
    input logic rst_ni, // active low reset

    // DAT <-> Controller interface
    input  logic                        dat_read_valid_hw_i,
    input  logic [$clog2(DAT_SIZE)-1:0] dat_index_hw_i,
    output logic [                63:0] dat_rdata_hw_o,

    // DCT <-> Controller interface
    input  logic                        dct_write_valid_hw_i,
    input  logic                        dct_read_valid_hw_i,
    input  logic [$clog2(DCT_SIZE)-1:0] dct_index_hw_i,
    input  logic [               127:0] dct_wdata_hw_i,
    output logic [               127:0] dct_rdata_hw_o,

    input  I3CCSR__out_t hwif_out_i,
    output I3CCSR__in_t  hwif_in_o
);

  // Device Address Table
  logic dat_read_valid;
  logic dat_write_valid;
  logic [$clog2(DAT_SIZE):0] dat_addr;
  logic [63:0] dat_wdata;
  logic [63:0] dat_wmask;
  logic [63:0] dat_rdata;
  logic [$clog2(DAT_SIZE):0] dat_index_sw;
  logic dat_word_index_sw;

  logic dat_rd_ack;
  logic dat_wr_ack;

  // Two 32-bit words per 64-bit word so retrieve index by shifting 3 bits
  assign dat_index_sw = hwif_out_i.DAT.addr[$clog2(DAT_DEPTH)+2:3];
  // Second bit indicates which 32-bit word is requested by software
  assign dat_word_index_sw = hwif_out_i.DAT.addr[2];

  assign dat_read_valid = hwif_out_i.DAT.req | dat_read_valid_hw_i;
  assign dat_write_valid = hwif_out_i.DAT.req_is_wr;
  assign dat_rdata_hw_o = dat_rdata;

  prim_ram_1p_adv #(
      .Depth(DAT_DEPTH),
      .Width(64),
      .DataBitsPerMask(32)
  ) dat_memory (
      .clk_i,
      .rst_ni,
      .req_i(dat_read_valid),
      .write_i(dat_write_valid),
      .addr_i(dat_addr),
      .wdata_i(dat_wdata),
      .wmask_i(dat_wmask),
      .rdata_o(dat_rdata),
      .rvalid_o(),  // Unused
      .rerror_o(),  // Unused
      .cfg_i()  // Unused
  );

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
          dat_wdata = {{32{1'b0}}, hwif_out_i.DAT.wr_data};
        end
        1'b1: begin
          // Word mask = 2'b10
          dat_wmask = {{32{1'b1}}, {32{1'b0}}};
          dat_wdata = {hwif_out_i.DAT.wr_data, {32{1'b0}}};
        end
      endcase
    end
  end

  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      case (dat_word_index_sw)
        1'd0: hwif_in_o.DAT.rd_data <= dat_rdata[31:0];
        1'd1: hwif_in_o.DAT.rd_data <= dat_rdata[63:32];
      endcase
    end else begin
      hwif_in_o.DAT.rd_data <= '0;
    end
  end

  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      dat_rd_ack <= hwif_out_i.DAT.req & ~hwif_out_i.DAT.req_is_wr & ~dat_read_valid_hw_i;
      hwif_in_o.DAT.rd_ack <= dat_rd_ack;

      dat_wr_ack <= hwif_out_i.DAT.req & hwif_out_i.DAT.req_is_wr;
      hwif_in_o.DAT.wr_ack <= dat_wr_ack;
    end else begin
      dat_rd_ack <= 1'b0;
      dat_wr_ack <= 1'b0;
      hwif_in_o.DAT.rd_ack <= 1'b0;
      hwif_in_o.DAT.wr_ack <= 1'b0;
    end
  end

  // Device Context Table
  logic dct_read_valid;
  logic dct_write_valid;
  logic [$clog2(DCT_SIZE):0] dct_addr;
  logic [127:0] dct_wdata;
  logic [127:0] dct_wmask;
  logic [127:0] dct_rdata;
  logic [$clog2(DCT_SIZE):0] dct_index_sw;
  logic [1:0] dct_word_index_sw;

  logic dct_rd_ack;
  logic dct_wr_ack;

  // Four 32-bit words per 128-bit word so retrieve index by shifting 4 bits
  assign dct_index_sw = hwif_out_i.DCT.addr[$clog2(DCT_DEPTH)+3:4];
  // Second and third bits indicate which 32-bit word is requested by software
  assign dct_word_index_sw = hwif_out_i.DCT.addr[3:2];

  assign dct_read_valid = hwif_out_i.DCT.req | dct_read_valid_hw_i;
  assign dct_write_valid = dct_write_valid_hw_i;
  assign dct_wdata = dct_wdata_hw_i;
  assign dct_rdata_hw_o = dct_rdata;

  prim_ram_1p_adv #(
      .Depth(DCT_DEPTH),
      .Width(128),
      .DataBitsPerMask(32)
  ) dct_memory (
      .clk_i,
      .rst_ni,
      .req_i(dct_read_valid),
      .write_i(dct_write_valid),
      .addr_i(dct_addr),
      .wdata_i(dct_wdata),
      .wmask_i(dct_wmask),
      .rdata_o(dct_rdata),
      .rvalid_o(),  // Unused
      .rerror_o(),  // Unused
      .cfg_i()  // Unused
  );

  always_comb begin
    if (dct_read_valid_hw_i) begin
      dct_addr  = dct_index_hw_i;
      dct_wmask = {128{1'b1}};
    end else begin
      dct_addr  = dct_index_sw;
      dct_wmask = {128{1'b0}};
    end
  end

  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      case (dct_word_index_sw)
        2'd0: hwif_in_o.DCT.rd_data <= dct_rdata[31:0];
        2'd1: hwif_in_o.DCT.rd_data <= dct_rdata[63:32];
        2'd2: hwif_in_o.DCT.rd_data <= dct_rdata[95:64];
        2'd3: hwif_in_o.DCT.rd_data <= dct_rdata[127:96];
      endcase
    end else begin
      hwif_in_o.DCT.rd_data <= '0;
    end
  end

  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      dct_rd_ack <= hwif_out_i.DCT.req & ~hwif_out_i.DCT.req_is_wr & ~dct_read_valid_hw_i;
      hwif_in_o.DCT.rd_ack <= dct_rd_ack;
      // ACK write requests to remove CPU stall, even though they're illegal to DCT
      dct_wr_ack <= hwif_out_i.DCT.req & hwif_out_i.DCT.req_is_wr;
      hwif_in_o.DCT.wr_ack <= dct_wr_ack;
    end else begin
      dct_rd_ack <= 1'b0;
      dct_wr_ack <= 1'b0;
      hwif_in_o.DCT.rd_ack <= 1'b0;
      hwif_in_o.DCT.wr_ack <= 1'b0;
    end
  end

endmodule
