// SPDX-License-Identifier: Apache-2.0

module i3c_ahb_if
  import i3c_ahb_if_pkg::*;
#(
    // Data width of the CSR-access interface
    parameter int unsigned CLIENT_DATA_WIDTH = 32,
    // Address width of the CSR-access interface
    parameter int unsigned CLIENT_ADDR_WIDTH = AHB_ADDR_WIDTH
) (
    // TODO: AHB module from cocotb assumes the signals not end with _i, _o
    // Either create a wrapper in the test interface of stick to `classic` names
    // AHB-Lite interface
    input  logic                       hclk_i,
    input  logic                       hreset_n_i,
    // Byte address of the transfer
    input  logic [ AHB_ADDR_WIDTH-1:0] haddr,
    // Indicates the number of bursts in a transfer
    input  logic [AHB_BURST_WIDTH-1:0] hburst,
    // Protection control; provides information on the access type
    input  logic [                3:0] hprot,
    // Indicates the size of the transfer
    input  logic [                2:0] hsize,
    // Indicates the transfer type
    input  logic [                1:0] htrans,
    // Data for the write operation
    input  logic [ AHB_DATA_WIDTH-1:0] hwdata,
    // Write strobes; Deasserted when write data lanes do not contain valid data
    input  logic [ AHB_DATA_WIDTH-1:0] hwstrb,
    // Indicates write operation when asserted
    input  logic                       hwrite,
    // Read data
    output logic [ AHB_DATA_WIDTH-1:0] hrdata,
    // Assrted indicates a finished transfer; Can be driven low to extend a transfer
    output logic                       hreadyout,
    // Transfer response, high when error occured
    output logic                       hresp,
    // Indicates the subordinate is selected for the transfer
    input  logic                       hsel,
    // Indicates all subordiantes have finished transfers
    input  logic                       hready,

    // CSR-access-interface
    // REQUEST
    // When asserted, a read or write transfer is initiated
    // Indicates addr, req_is_wr and wr_data valid
    output wire        s_cpuif_req,
    // Byte address of the transfer
    output wire [11:0] s_cpuif_addr,
    // If 1, incomming transfer is write, otherwise read
    output wire        s_cpuif_req_is_wr,
    // Write data for the transfer
    output wire [31:0] s_cpuif_wr_data,
    // Active-high bit-level-write-enable strobes
    // Only asserted positions will change the register value
    output wire [31:0] s_cpuif_wr_biten,
    // If asserted and the next operation is read, the transfer will not be accepted until deasserted
    input  wire        s_cpuif_req_stall_wr,
    // If asserted and the next operation is write, the transfer will not be accepted until deasserted
    input  wire        s_cpuif_req_stall_rd,
    // READ RESPONSE
    // If asserted, indicates completed transfer and rd_err & rd_data valid
    input  wire        s_cpuif_rd_ack,
    // If asserted, an error occured during the read transfer
    input  wire        s_cpuif_rd_err,
    // Read data
    input  wire [31:0] s_cpuif_rd_data,
    // WRITE RESPONSE
    // If asserted, indicates completed transfer and wr_err valid
    input  wire        s_cpuif_wr_ack,
    // If asserted, an error occured during the write transfer
    input  wire        s_cpuif_wr_err
);

  // Check configuration
  initial begin
    if (!(AHB_ADDR_WIDTH >= 10 && AHB_ADDR_WIDTH <= 64)) begin
      $error("ERROR: Violated requirement: 10 <= AHB_ADDR_WIDTH <= 64 (instance %m)");
      $finish;
    end
    if (!(AHB_DATA_WIDTH inside {32, 64, 128, 256})) begin
      $error("ERROR: AHB_DATA_WIDTH is required to be one of {32, 64, 128, 256} (instance %m)");
      $finish;
    end
    if (!(AHB_BURST_WIDTH >= 0 && AHB_BURST_WIDTH <= 3)) begin
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


  I3CCSR__in_t  hwif_in;
  I3CCSR__out_t hwif_out;

  // TODO: Connect missing
  I3CCSR i3c_csr (
      .clk(hclk_i),
      .rst(hreset_n_i),

      .s_cpuif_req(i3c_req_dv),
      .s_cpuif_req_is_wr(i3c_req_write),
      .s_cpuif_addr(i3c_req_addr[31:0]),
      .s_cpuif_wr_data(i3c_req_wdata),
      .s_cpuif_wr_biten('1),  // Write strobes not handled by AHB-Lite interface
      .s_cpuif_req_stall_wr(),
      .s_cpuif_req_stall_rd(),
      .s_cpuif_rd_ack(),
      .s_cpuif_rd_err(i3c_req_err),
      .s_cpuif_rd_data(),
      .s_cpuif_wr_ack(),
      .s_cpuif_wr_err(),

      .hwif_in (hwif_in),
      .hwif_out(hwif_out)
  );

endmodule
