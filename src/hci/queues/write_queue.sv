// SPDX-License-Identifier: Apache-2.0

module write_queue #(
    parameter int unsigned DEPTH = 64,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned THLD_WIDTH = 3,
    parameter int unsigned THLD_IS_POW = 0,
    localparam int unsigned FifoDepthWidth = $clog2(DEPTH + 1)
) (
    input logic clk_i,
    input logic rst_ni,

    // Direct FIFO read control
    output logic full_o,
    output logic below_thld_o,
    output logic empty_o,
    output logic rvalid_o,
    input logic rready_i,
    output logic [DATA_WIDTH-1:0] rdata_o,

    // CSR access control
    input logic req_i,
    output logic ack_o,
    input logic [DATA_WIDTH-1:0] data_i,

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
  logic [FifoDepthWidth-1:0] empty_entries;

  assign rst = ~rst_ni | reg_rst_i;

  assign fifo_clr = reg_rst_i;
  assign reg_rst_data_o = 1'b0;

  always_comb begin : trigger_threshold
    empty_o = ~|fifo_depth;

    if (THLD_IS_POW == 0) begin
      empty_entries = DEPTH - fifo_depth;
      below_thld_o  = thld_o && (empty_entries >= thld_o);
    end else begin
      empty_entries = DEPTH - fifo_depth;
      below_thld_o  = thld_o && (empty_entries >= (1 << (thld_o + 1)));
    end
  end : trigger_threshold

  always_comb begin : populate_thld
    if (THLD_IS_POW == 0) begin
      // Specified threshold for the CMD queue in 'QUEUE_THLD_CTRL'
      // must be less or equal (<=) than CMD_FIFO_DEPTH.
      thld_o = thld_i > DEPTH ? DEPTH : thld_i;
    end else begin
      // Threshold for TX queue is 2^(thld+1) where 'thld' is specified
      // in the 'DATA_BUFFER_THLD_CTRL' CSR.
      // Threshold must be less or equal (<=) than TX_FIFO_DEPTH.
      if ((1 << (thld_i + 1)) > DEPTH) begin
        thld_o = $clog2(DEPTH) - 1;
      end else begin
        thld_o = thld_i;
      end
    end
  end : populate_thld

  always_ff @(posedge clk_i or negedge rst_ni) begin : csr_rst_control
    if (~rst_ni) begin : rst_control_rst
      reg_rst_we_o <= '0;
    end else begin
      reg_rst_we_o <= reg_rst_i && empty_o;
    end
  end : csr_rst_control

  // TODO: Move access logic from hci.sv
  if (DATA_WIDTH == 64) begin : gen_qword_to_fifo
    logic dword_index;  // Index of currently processed DWORD
    logic start_valid;  // Start of FIFO valid signal assertion
    assign start_valid = req_i & dword_index;

    always_ff @(posedge clk_i or negedge rst_ni) begin : port_to_fifo
      if (!rst_ni) begin : port_to_fifo_rst
        dword_index <= '0;
        ack_o <= '0;
        fifo_wdata <= '0;
        fifo_wvalid <= '0;
      end else begin : push_cmds_to_fifo
        ack_o <= 1'b0;

        if (req_i) begin
          dword_index <= 1'b1;
          if (dword_index) begin
            fifo_wdata[63:32] <= data_i;
          end else begin
            fifo_wdata[31:0] <= data_i;
            ack_o <= 1'b1;
          end
        end

        if (start_valid) begin
          fifo_wvalid <= 1'b1;
        end

        if (fifo_wvalid & fifo_wready) begin
          fifo_wvalid <= 1'b0;
          ack_o <= 1'b1;
          dword_index <= 1'b0;
        end
      end : push_cmds_to_fifo
    end : port_to_fifo
  end else if (DATA_WIDTH == 32) begin : gen_dword_to_fifo
    always_ff @(posedge clk_i or negedge rst_ni) begin : port_to_fifo
      if (!rst_ni) begin : port_to_fifo_rst
        fifo_wvalid <= '0;
        ack_o <= '0;
        fifo_wdata <= '0;
      end else begin : push_to_fifo
        if (req_i) begin
          fifo_wdata  <= data_i;
          fifo_wvalid <= 1'b1;
        end

        if (fifo_wready & fifo_wvalid) begin
          fifo_wdata <= '0;
          fifo_wvalid <= 1'b0;
          ack_o <= 1'b1;
        end else begin
          ack_o <= 1'b0;
        end
      end : push_to_fifo
    end : port_to_fifo
  end

  caliptra_prim_fifo_sync #(
      .Width(DATA_WIDTH),
      .Pass (1'b0),
      .Depth(DEPTH)
  ) fifo (
      .clk_i,
      .rst_ni,
      .clr_i(fifo_clr),
      .wvalid_i(fifo_wvalid),
      .wready_o(fifo_wready),
      .wdata_i(fifo_wdata),
      .depth_o(fifo_depth),
      .rvalid_o,
      .rready_i,
      .rdata_o,
      .full_o,
      .err_o()
  );

endmodule
