// SPDX-License-Identifier: Apache-2.0

module read_queue #(
    parameter int unsigned DEPTH = 64,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned THLD_WIDTH = 3,
    parameter int unsigned THLD_IS_POW = 0,
    localparam int unsigned FifoDepthWidth = $clog2(DEPTH + 1)
) (
    input logic clk_i,
    input logic rst_ni,

    // Direct FIFO write control
    output logic full_o,
    output logic above_thld_o,
    output logic empty_o,
    input logic wvalid_i,
    output logic wready_o,
    input logic [DATA_WIDTH-1:0] wdata_i,

    // CSR access control
    input logic req_i,
    output logic ack_o,
    output logic [DATA_WIDTH-1:0] data_o,

    // Threshold value
    input  logic [THLD_WIDTH-1:0] thld_i,
    output logic [THLD_WIDTH-1:0] thld_o,

    // CSR reset control
    input  logic reg_rst_i,
    output logic reg_rst_we_o,
    output logic reg_rst_data_o
);

  logic rst;
  logic fifo_clr;
  logic fifo_wvalid;
  logic fifo_wready;
  logic [DATA_WIDTH-1:0] fifo_wdata;
  logic [FifoDepthWidth-1:0] fifo_depth;
  logic fifo_rvalid;
  logic fifo_rready;
  logic [DATA_WIDTH-1:0] fifo_rdata;
  logic fifo_full;

  assign rst = ~rst_ni | reg_rst_i;

  assign fifo_clr = reg_rst_i;
  assign reg_rst_data_o = 1'b0;

  always_comb begin : trigger_threshold
    empty_o = ~|fifo_depth;

    if (THLD_IS_POW == 0) begin
      above_thld_o = thld_o && (fifo_depth >= thld_o);
    end else begin
      above_thld_o = thld_o && (fifo_depth >= (1 << (thld_o + 1)));
    end
  end : trigger_threshold

  always_ff @(posedge clk_i or negedge rst_ni) begin : csr_rst_control
    if (~rst_ni) begin : rst_control_rst
      reg_rst_we_o <= '0;
    end else begin
      reg_rst_we_o <= reg_rst_i && empty_o;
    end
  end : csr_rst_control

  always_ff @(posedge clk_i or negedge rst_ni) begin : populate_thld
    if (!rst_ni) begin : populate_thld_rst
      thld_o <= '0;
    end else begin
      if (THLD_IS_POW == 0) begin
        // Specified threshold for the RESP queue in 'QUEUE_THLD_CTRL'
        // must be less (<) than DEPTH.
        thld_o <= thld_i >= DEPTH ? DEPTH - 1 : thld_i;
      end else begin
        // Threshold for RX queue is 2^(thld_i+1) where 'thld_i' is the value specified
        // in the 'DATA_BUFFER_THLD_CTRL' CSR.
        // Threshold must be less (<) than DEPTH.
        if ((1 << (thld_i + 1)) >= DEPTH) begin
          thld_o <= $clog2(DEPTH) - 2;
        end else begin
          thld_o <= thld_i;
        end
      end
    end
  end : populate_thld

  always_ff @(posedge clk_i or posedge rst) begin : fifo_to_port
    if (rst) begin : fifo_to_port_rst
      fifo_rready <= '0;
      data_o <= '0;
      ack_o <= '0;
    end else begin : push_to_port
      if (req_i) begin
        fifo_rready <= 1'b1;
      end

      if (fifo_rready & fifo_rvalid) begin
        fifo_rready <= 1'b0;
        data_o <= fifo_rdata;
        ack_o <= 1'b1;
      end else begin
        data_o <= '0;
        ack_o  <= 1'b0;
      end
    end : push_to_port
  end : fifo_to_port

  caliptra_prim_fifo_sync #(
      .Width(DATA_WIDTH),
      .Pass (1'b0),
      .Depth(DEPTH)
  ) fifo (
      .clk_i,
      .rst_ni,
      .clr_i(fifo_clr),
      .wvalid_i,
      .wready_o,
      .wdata_i,
      .depth_o(fifo_depth),
      .rvalid_o(fifo_rvalid),
      .rready_i(fifo_rready),
      .rdata_o(fifo_rdata),
      .full_o,
      .err_o()
  );

endmodule
