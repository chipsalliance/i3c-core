// SPDX-License-Identifier: Apache-2.0

module ahb_if
  import I3CCSR_pkg::I3CCSR__in_t;
  import I3CCSR_pkg::I3CCSR__out_t;
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
    // TODO: AHB module from cocotb assumes the signals not end with _i, _o
    // Either create a wrapper in the test interface of stick to `classic` names
    // AHB-Lite interface
    input  logic                        hclk_i,
    input  logic                        hreset_n_i,
    // Byte address of the transfer
    input  logic [  AHB_ADDR_WIDTH-1:0] haddr,
    // Indicates the number of bursts in a transfer
    input  logic [ AHB_BURST_WIDTH-1:0] hburst,
    // Protection control; provides information on the access type
    input  logic [                 3:0] hprot,
    // Indicates the size of the transfer
    input  logic [                 2:0] hsize,
    // Indicates the transfer type
    input  logic [                 1:0] htrans,
    // Data for the write operation
    input  logic [  AHB_DATA_WIDTH-1:0] hwdata,
    // Write strobes; Deasserted when write data lanes do not contain valid data
    input  logic [AHB_DATA_WIDTH/8-1:0] hwstrb,
    // Indicates write operation when asserted
    input  logic                        hwrite,
    // Read data
    output logic [  AHB_DATA_WIDTH-1:0] hrdata,
    // Assrted indicates a finished transfer; Can be driven low to extend a transfer
    output logic                        hreadyout,
    // Transfer response, high when error occured
    output logic                        hresp,
    // Indicates the subordinate is selected for the transfer
    input  logic                        hsel,
    // Indicates all subordiantes have finished transfers
    input  logic                        hready
);

  // Check configuration
  initial begin
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

  logic i3c_req_dv, i3c_req_hld;
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
      .haddr_i(haddr),
      .hsize_i(hsize),
      .htrans_i(htrans),
      .hwdata_i(hwdata),
      .hwrite_i(hwrite),
      .hsel_i(hsel),
      .hready_i(hready),
      .hrdata_o(hrdata),
      .hresp_o(hresp),
      .hreadyout_o(hreadyout),

      // Component interface
      .dv(i3c_req_dv),
      .hld(i3c_req_hld),
      .err(i3c_req_err),
      .write(i3c_req_write),
      .wdata(i3c_req_wdata),
      .addr(i3c_req_addr),

      .rdata(i3c_req_rdata)
  );

  // TODO: Connect to the I3C hw CSR access logic
  I3CCSR__in_t  hwif_in;
  I3CCSR__out_t hwif_out;

  logic i3c_csr_rd_err, i3c_csr_wr_err;
  logic i3c_csr_rd_hld, i3c_csr_wr_hld;
  logic i3c_csr_rst;
  logic i3c_ign_rd_ack, i3c_ign_wr_ack;
  always_comb begin : ahb_2_i3c_comp
    i3c_req_err = i3c_csr_rd_err | i3c_csr_wr_err;
    i3c_req_hld = i3c_req_write ? i3c_csr_wr_hld : i3c_csr_rd_hld;
    i3c_csr_rst = ~hreset_n_i;
  end

  I3CCSR i3c_csr (
      .clk(hclk_i),
      .rst(i3c_csr_rst),

      .s_cpuif_req(i3c_req_dv),
      .s_cpuif_req_is_wr(i3c_req_write),
      .s_cpuif_addr(i3c_req_addr[I3CCSR_MIN_ADDR_WIDTH-1:0]),
      .s_cpuif_wr_data(i3c_req_wdata),
      .s_cpuif_wr_biten('1),  // Write strobes not handled by AHB-Lite interface
      .s_cpuif_req_stall_wr(i3c_csr_wr_hld),
      .s_cpuif_req_stall_rd(i3c_csr_rd_hld),
      .s_cpuif_rd_ack(i3c_ign_rd_ack),  // Ignored by AHB component
      .s_cpuif_rd_err(i3c_csr_rd_err),
      .s_cpuif_rd_data(i3c_req_rdata),
      .s_cpuif_wr_ack(i3c_ign_wr_ack),  // Ignored by AHB component
      .s_cpuif_wr_err(i3c_csr_wr_err),

      .hwif_in (hwif_in),
      .hwif_out(hwif_out)
  );

endmodule
