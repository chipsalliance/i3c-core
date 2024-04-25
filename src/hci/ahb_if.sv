// SPDX-License-Identifier: Apache-2.0

module ahb_if
  import I3CCSR_pkg::I3CCSR_DATA_WIDTH;
  import I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
#(
    // Data width of AHB-Lite interface
    parameter int unsigned AHB_DATA_WIDTH  = 64,
    // Address width of AHB-Lite interface.
    parameter int unsigned AHB_ADDR_WIDTH  = 32,
    // Burst width of AHB-Lite interface
    parameter int unsigned AHB_BURST_WIDTH = 3
) (
    // AHB-Lite interface
    input  logic                        hclk_i,
    input  logic                        hreset_n_i,
    // Byte address of the transfer
    input  logic [  AHB_ADDR_WIDTH-1:0] haddr_i,
    // Indicates the number of bursts in a transfer
    input  logic [ AHB_BURST_WIDTH-1:0] hburst_i,     // Unhandled
    // Protection control; provides information on the access type
    input  logic [                 3:0] hprot_i,      // Unhandled
    // Indicates the size of the transfer
    input  logic [                 2:0] hsize_i,
    // Indicates the transfer type
    input  logic [                 1:0] htrans_i,
    // Data for the write operation
    input  logic [  AHB_DATA_WIDTH-1:0] hwdata_i,
    // Write strobes; Deasserted when write data lanes do not contain valid data
    input  logic [AHB_DATA_WIDTH/8-1:0] hwstrb_i,     // Unhandled
    // Indicates write operation when asserted
    input  logic                        hwrite_i,
    // Read data
    output logic [  AHB_DATA_WIDTH-1:0] hrdata_o,
    // Asserted indicates a finished transfer; Can be driven low to extend a transfer
    output logic                        hreadyout_o,
    // Transfer response, high when error occurred
    output logic                        hresp_o,
    // Indicates the subordinate is selected for the transfer
    input  logic                        hsel_i,
    // Indicates all subordinates have finished transfers
    input  logic                        hready_i,

    // I3C SW CSR access interface
    output logic                             s_cpuif_req,
    output logic                             s_cpuif_req_is_wr,
    output logic [I3CCSR_MIN_ADDR_WIDTH-1:0] s_cpuif_addr,
    output logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_data,
    output logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_wr_biten,
    input  logic                             s_cpuif_req_stall_wr,
    input  logic                             s_cpuif_req_stall_rd,
    input  logic                             s_cpuif_rd_ack,
    input  logic                             s_cpuif_rd_err,
    input  logic [    I3CCSR_DATA_WIDTH-1:0] s_cpuif_rd_data,
    input  logic                             s_cpuif_wr_ack,
    input  logic                             s_cpuif_wr_err
);

  // Check configuration
  initial begin : ahb_param_check
    if (!(AHB_ADDR_WIDTH >= 10 && AHB_ADDR_WIDTH <= 64)) begin : ahb_addr_w_oob
      $error("ERROR: Violated requirement: 10 <= AHB_ADDR_WIDTH <= 64 (instance %m)");
      $finish;
    end
    if (!(AHB_DATA_WIDTH inside {32, 64, 128, 256})) begin : ahb_data_w_oob
      $error("ERROR: AHB_DATA_WIDTH is required to be one of {32, 64, 128, 256} (instance %m)");
      $finish;
    end
    if (!(AHB_BURST_WIDTH >= 0 && AHB_BURST_WIDTH <= 3)) begin : ahb_burst_w_oob
      $error("ERROR: Violated requirement: 0 <= AHB_BURST_WIDTH <= 3 (instance %m)");
      $finish;
    end
  end

  logic i3c_req_dv, i3c_req_hld, i3c_req_hld_ext;
  logic cpuif_req_stall;
  logic i3c_req_err, i3c_req_write;
  logic [I3CCSR_DATA_WIDTH-1:0] i3c_req_wdata;
  logic [AHB_ADDR_WIDTH-1:0] i3c_req_addr;
  logic [I3CCSR_DATA_WIDTH-1:0] i3c_req_rdata;

  // Instantiate AHB-Lite module
  ahb_slv_sif #(
      .AHB_ADDR_WIDTH(AHB_ADDR_WIDTH),
      .AHB_DATA_WIDTH(AHB_DATA_WIDTH),
      .CLIENT_DATA_WIDTH(I3CCSR_DATA_WIDTH)
  ) ahb_slv_sif_i3c (
      // AHB-Lite interface
      .hclk(hclk_i),
      .hreset_n(hreset_n_i),
      .haddr_i(haddr_i),
      .hsize_i(hsize_i),
      .htrans_i(htrans_i),
      .hwdata_i(hwdata_i),
      .hwrite_i(hwrite_i),
      .hsel_i(hsel_i),
      .hready_i(hready_i),
      .hrdata_o(hrdata_o),
      .hresp_o(hresp_o),
      .hreadyout_o(hreadyout_o),

      // Component interface
      .dv(i3c_req_dv),
      .hld(i3c_req_hld),
      .err(i3c_req_err),
      .write(i3c_req_write),
      .wdata(i3c_req_wdata),
      .addr(i3c_req_addr),

      .rdata(i3c_req_rdata)
  );

  logic i3c_ign_rd_ack, i3c_ign_wr_ack;

  always_comb begin : ahb_2_i3c_comp
    cpuif_req_stall = i3c_req_write ? s_cpuif_req_stall_wr : s_cpuif_req_stall_rd;
    i3c_req_hld = (cpuif_req_stall | i3c_req_hld_ext) & ~s_cpuif_wr_ack & ~s_cpuif_rd_ack;

    s_cpuif_req = i3c_req_dv | i3c_req_hld;
    s_cpuif_req_is_wr = i3c_req_write;
    s_cpuif_addr = i3c_req_addr[I3CCSR_MIN_ADDR_WIDTH-1:0];
    s_cpuif_wr_data = i3c_req_wdata;
    s_cpuif_wr_biten = '1;  // AHB-Lite implementation doesn't support write strobes
    i3c_req_err = s_cpuif_rd_err | s_cpuif_wr_err;
    i3c_req_rdata = s_cpuif_rd_data;
    i3c_ign_rd_ack = s_cpuif_rd_ack;  // Read ack is not utilized
    i3c_ign_wr_ack = s_cpuif_wr_ack;  // Write ack is not utilized
  end

  always_ff @(posedge hclk_i or negedge hreset_n_i) begin
    if (~hreset_n_i) begin
      i3c_req_hld_ext <= '0;
    end else begin
      i3c_req_hld_ext <= hready_i & hsel_i & htrans_i inside {2'b10, 2'b11};
    end
  end
endmodule
