// SPDX-License-Identifier: Apache-2.0

/*
  Read queue provides write access from software and read access from hardware. The queue provides
  start and ready threshold triggers with configurale activation levels.

  TODO: Ensure that configurations with both `ThldIsPow` and `LimitReadyThld` parameters
        enabled or disabled work correctly.
*/

module write_queue #(
    parameter int unsigned CsrDataWidth = 32,
    parameter int unsigned Depth = 64,
    parameter int unsigned DataWidth = 32,
    parameter int unsigned ThldWidth = 3,
    parameter bit ThldIsPow = 1,  // Calculate maximum ready threshold value as
                                  // `2^(ready_thld_i+1)`
    parameter bit LimitReadyThld = 0,  // Set ready threshold value to `Depth-1` if it
                                       // exceeds the queue size
    localparam int unsigned FifoDepthWidth = $clog2(Depth + 1)
) (
    input logic clk_i,
    input logic rst_ni,

    // Direct FIFO read control
    output logic full_o,
    output logic [FifoDepthWidth-1:0] depth_o,
    output logic start_thld_trig_o,
    output logic ready_thld_trig_o,
    output logic empty_o,
    output logic rvalid_o,
    input logic rready_i,
    output logic [DataWidth-1:0] rdata_o,

    // CSR access control
    input logic req_i,
    output logic ack_o,
    input logic [CsrDataWidth-1:0] data_i,

    // Threshold value
    input  logic [ThldWidth-1:0] start_thld_i,
    input  logic [ThldWidth-1:0] ready_thld_i,
    output logic [ThldWidth-1:0] ready_thld_o,

    // CSR reset control
    input  logic reg_rst_i,
    output logic reg_rst_we_o,
    output logic reg_rst_data_o
);

  logic fifo_clr;
  logic fifo_wvalid;
  logic fifo_wready;
  logic [DataWidth-1:0] fifo_wdata;
  logic [FifoDepthWidth-1:0] fifo_depth;

  logic [FifoDepthWidth-1:0] empty_entries;

  assign fifo_clr = reg_rst_i;
  assign reg_rst_data_o = 1'b0;

  assign depth_o = fifo_depth;

  always_comb begin : trigger_threshold
    empty_o = ~|fifo_depth;
    empty_entries = FifoDepthWidth'(Depth) - fifo_depth;

    if (ThldIsPow == 0) begin
      start_thld_trig_o = |start_thld_i && (fifo_depth >= FifoDepthWidth'(start_thld_i));
      ready_thld_trig_o = |ready_thld_o && (empty_entries >= FifoDepthWidth'(ready_thld_o));
    end else begin
      start_thld_trig_o = |start_thld_i &&
                          (fifo_depth >= FifoDepthWidth'(1 << (FifoDepthWidth'(start_thld_i) + 1)));
      ready_thld_trig_o = |ready_thld_o &&
                          (empty_entries >= FifoDepthWidth'(1 << (FifoDepthWidth'(ready_thld_o) + 1)));
    end
  end : trigger_threshold

  always_ff @(posedge clk_i) begin : populate_thld
    if (!rst_ni) begin
      ready_thld_o <= '0;
    end else begin
      if (LimitReadyThld) begin
        if (ThldIsPow) begin
          // Specified `2^(ready_thld_o+1)` can't be higher than `Depth - 1`
          // For configurations with a threshold width more narrow than the queue depth width
          // the expression might become a constant comparison
          // verilator lint_off UNSIGNED
          if ((1 << (ready_thld_i + 1)) >= ThldWidth'(Depth)) begin
            // verilator lint_on UNSIGNED
            ready_thld_o <= ThldWidth'($clog2(Depth) - 1);
          end else begin
            ready_thld_o <= ready_thld_i;
          end
        end else begin
          // Specified `ready_thld_o` can't be higher than `Depth - 1`
          // For configurations with a threshold width more narrow than the queue depth width
          // the expression might become a constant comparison
          // verilator lint_off UNSIGNED
          ready_thld_o <= (ready_thld_i >= ThldWidth'(Depth))
                          ? ThldWidth'(Depth) - 1
                          : ready_thld_i;
          // verilator lint_on UNSIGNED
        end
      end else begin
        ready_thld_o <= ready_thld_i;
      end
    end
  end : populate_thld

  always_ff @(posedge clk_i) begin : csr_rst_control
    if (~rst_ni) begin : rst_control_rst
      reg_rst_we_o <= '0;
    end else begin
      reg_rst_we_o <= reg_rst_i && empty_o;
    end
  end : csr_rst_control

  if (DataWidth == 64) begin : gen_qword_to_fifo
    logic dword_index;  // Index of currently processed DWORD
    logic start_valid;  // Start of FIFO valid signal assertion
    assign start_valid = req_i & dword_index;

    always_ff @(posedge clk_i) begin : port_to_fifo
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
  end else if (DataWidth == 32) begin : gen_dword_to_fifo
    always_ff @(posedge clk_i) begin : port_to_fifo
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

  logic unused_err;

  caliptra_prim_fifo_sync #(
      .Width(DataWidth),
      .Pass (1'b0),
      .Depth(Depth)
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
      .err_o(unused_err)
  );

endmodule
