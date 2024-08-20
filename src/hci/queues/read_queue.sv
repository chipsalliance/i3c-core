// SPDX-License-Identifier: Apache-2.0

/*
  Read queue provides read access from software and write access from hardware. The queue provides
  start and ready threshold triggers with configurale activation levels.

  TODO: Ensure that configurations with both `THLD_IS_POW` and `LIMIT_READY_THLD` parameters
        enabled or disabled work correctly.
*/

module read_queue #(
    parameter int unsigned DEPTH = 64,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned THLD_WIDTH = 3,
    parameter bit THLD_IS_POW = 1,  // Calculate maximum ready threshold value as
                                             // `2^(ready_thld_i+1)`
    parameter bit LIMIT_READY_THLD = 0,  // Set ready threshold value to `DEPTH-1` if it
                                                  // exceeds the queue size
    localparam int unsigned FifoDepthWidth = $clog2(DEPTH + 1)
) (
    input logic clk_i,
    input logic rst_ni,

    // Direct FIFO write control
    output logic full_o,
    output logic start_thld_trig_o,
    output logic ready_thld_trig_o,
    output logic empty_o,
    input logic wvalid_i,
    output logic wready_o,
    input logic [DATA_WIDTH-1:0] wdata_i,

    // CSR access control
    input logic req_i,
    output logic ack_o,
    output logic [DATA_WIDTH-1:0] data_o,

    // Threshold value
    input  logic [THLD_WIDTH-1:0] start_thld_i,
    input  logic [THLD_WIDTH-1:0] ready_thld_i,
    output logic [THLD_WIDTH-1:0] ready_thld_o,

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

  initial begin
    if (THLD_IS_POW == LIMIT_READY_THLD) begin
      $warning("Configuration with both `THLD_IS_POW` and `LIMIT_READY_THLD` enabled or disabled",
               "is not tested and might result in unexpected behavior.");
    end
  end

  assign rst = ~rst_ni | reg_rst_i;

  assign fifo_clr = reg_rst_i;
  assign reg_rst_data_o = 1'b0;

  always_comb begin : trigger_threshold
    empty_o = ~|fifo_depth;
    empty_entries = FifoDepthWidth'(DEPTH) - fifo_depth;

    if (THLD_IS_POW == 0) begin
      start_thld_trig_o = |start_thld_i && (empty_entries >= FifoDepthWidth'(start_thld_i));
      ready_thld_trig_o = |ready_thld_o && (fifo_depth >= FifoDepthWidth'(ready_thld_o));
    end else begin
      start_thld_trig_o = |start_thld_i &&
                          (empty_entries >= (1 << (FifoDepthWidth'(start_thld_i) + 1)));
      ready_thld_trig_o = |ready_thld_o &&
                          (fifo_depth >= (1 << (FifoDepthWidth'(ready_thld_o) + 1)));
    end
  end : trigger_threshold

  always_ff @(posedge clk_i or negedge rst_ni) begin : populate_thld
    if (!rst_ni) begin
      ready_thld_o <= '0;
    end else begin
      if (LIMIT_READY_THLD) begin
        if (THLD_IS_POW) begin
          // Specified `2^(ready_thld_o+1)` can't be higher than `DEPTH - 1`
          // For configurations with a threshold width more narrow than the queue depth width
          // the expression might become a constant comparison
          // verilator lint_off UNSIGNED
          if ((1 << (ready_thld_i + 1)) >= THLD_WIDTH'(DEPTH)) begin
            // verilator lint_on UNSIGNED
            ready_thld_o <= THLD_WIDTH'($clog2(DEPTH) - 1);
          end else begin
            ready_thld_o <= ready_thld_i;
          end
        end else begin
          // Specified `ready_thld_o` can't be higher than `DEPTH - 1`
          // For configurations with a threshold width more narrow than the queue depth width
          // the expression might become a constant comparison
          // verilator lint_off UNSIGNED
          ready_thld_o <= (ready_thld_i >= THLD_WIDTH'(DEPTH))
                          ? THLD_WIDTH'(DEPTH) - 1
                          : ready_thld_i;
          // verilator lint_on UNSIGNED
        end
      end else begin
        ready_thld_o <= ready_thld_i;
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

  logic unused_err;

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
      .err_o(unused_err)
  );

endmodule
