// SPDX-License-Identifier: Apache-2.0
// This wrapper module provides compliance to cocotbext-AXI
// with AXI standard signal naming convention

module axi_adapter_wrapper
  import I3CCSR_pkg::I3CCSR_DATA_WIDTH;
  import I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
  import I3CCSR_pkg::I3CCSR__in_t;
  import I3CCSR_pkg::I3CCSR__out_t;
  import i3c_pkg::*;
#(
    localparam int unsigned CsrAddrWidth = I3CCSR_MIN_ADDR_WIDTH,
    localparam int unsigned CsrDataWidth = I3CCSR_DATA_WIDTH,

    parameter int unsigned AxiAddrWidth = 12,
    parameter int unsigned AxiDataWidth = 32,
    parameter int unsigned AxiUserWidth = 32,
    parameter int unsigned AxiIdWidth   = 2
) (
    input aclk,  // clock
    input areset_n,  // active low reset

    // AXI Read Channels
    input  logic [AxiAddrWidth-1:0] araddr,
    input  logic [             1:0] arburst,
    input  logic [             2:0] arsize,
    input  logic [             7:0] arlen,
    input  logic [AxiUserWidth-1:0] aruser,
    input  logic [  AxiIdWidth-1:0] arid,
    input  logic                    arlock,
    input  logic                    arvalid,
    output logic                    arready,

    output logic [AxiDataWidth-1:0] rdata,
    output logic [             1:0] rresp,
    output logic [  AxiIdWidth-1:0] rid,
    output logic [AxiUserWidth-1:0] ruser,
    output logic                    rlast,
    output logic                    rvalid,
    input  logic                    rready,

    // AXI Write Channels
    input  logic [AxiAddrWidth-1:0] awaddr,
    input  logic [             1:0] awburst,
    input  logic [             2:0] awsize,
    input  logic [             7:0] awlen,
    input  logic [AxiUserWidth-1:0] awuser,
    input  logic [  AxiIdWidth-1:0] awid,
    input  logic                    awlock,
    input  logic                    awvalid,
    output logic                    awready,

    input  logic [AxiDataWidth-1:0] wdata,
    input  logic [             3:0] wstrb,
    input  logic [AxiUserWidth-1:0] wuser,
    input  logic                    wlast,
    input  logic                    wvalid,
    output logic                    wready,

    output logic [             1:0] bresp,
    output logic [  AxiIdWidth-1:0] bid,
    output logic [AxiUserWidth-1:0] buser,
    output logic                    bvalid,
    input  logic                    bready,

    output logic [           6:0] fifo_depth_o
);
  // I3C SW CSR access interface
  logic                    s_cpuif_req;
  logic                    s_cpuif_req_is_wr;
  logic [CsrAddrWidth-1:0] s_cpuif_addr;
  logic [CsrDataWidth-1:0] s_cpuif_wr_data;
  logic [CsrDataWidth-1:0] s_cpuif_wr_biten;
  logic                    s_cpuif_req_stall_wr;
  logic                    s_cpuif_req_stall_rd;
  logic                    s_cpuif_rd_ack;
  logic                    s_cpuif_rd_err;
  logic [CsrDataWidth-1:0] s_cpuif_rd_data;
  logic                    s_cpuif_wr_ack;
  logic                    s_cpuif_wr_err;

  axi_adapter #(
      .AxiDataWidth(AxiDataWidth),
      .AxiAddrWidth(AxiAddrWidth),
      .AxiUserWidth(AxiUserWidth),
      .AxiIdWidth(AxiIdWidth)
  ) i3c_axi_if (
      .clk_i (aclk),
      .rst_ni(areset_n),

      // AXI Read Channels
      .araddr_i(araddr),
      .arburst_i(arburst),
      .arsize_i(arsize),
      .arlen_i(arlen),
      .aruser_i(aruser),
      .arid_i(arid),
      .arlock_i(arlock),
      .arvalid_i(arvalid),
      .arready_o(arready),

      .rdata_o(rdata),
      .rresp_o(rresp),
      .rid_o(rid),
      .ruser_o(ruser),
      .rlast_o(rlast),
      .rvalid_o(rvalid),
      .rready_i(rready),

      // AXI Write Channels
      .awaddr_i(awaddr),
      .awburst_i(awburst),
      .awsize_i(awsize),
      .awlen_i(awlen),
      .awuser_i(awuser),
      .awid_i(awid),
      .awlock_i(awlock),
      .awvalid_i(awvalid),
      .awready_o(awready),

      .wdata_i (wdata),
      .wstrb_i (wstrb),
      .wuser_i (wuser),
      .wlast_i (wlast),
      .wvalid_i(wvalid),
      .wready_o(wready),

      .bresp_o(bresp),
      .bid_o(bid),
      .buser_o(buser),
      .bvalid_o(bvalid),
      .bready_i(bready),

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

  I3CCSR__in_t  hwif_in;
  I3CCSR__out_t hwif_out;

  assign hwif_in.rst_ni = areset_n;

  // Connect to I3C CSRs to test SW access
  I3CCSR i3c_csr (
      .clk(aclk),
      .rst(~areset_n),

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
      .s_cpuif_wr_err(s_cpuif_wr_err),

      .hwif_in (hwif_in),
      .hwif_out(hwif_out)
  );

  logic fifo_wvalid;
  logic fifo_wready;
  logic [31:0] fifo_wdata;
  logic fifo_rvalid;
  logic fifo_rready;
  logic [31:0] fifo_rdata;

  logic unused_err, unused_full;

  // FIFO for stress testing AXI
  caliptra_prim_fifo_sync #(
      .Width(32),
      .Pass (1'b0),
      .Depth(64)
  ) fifo (
      .clk_i(aclk),
      .rst_ni(areset_n),
      .clr_i('0),
      .wvalid_i(fifo_wvalid),
      .wready_o(fifo_wready),
      .wdata_i(fifo_wdata),
      .depth_o(fifo_depth_o),
      .rvalid_o(fifo_rvalid),
      .rready_i(fifo_rready),
      .rdata_o(fifo_rdata),
      .full_o(unused_full),
      .err_o(unused_err)
  );

  // TODO: These write-enable signals were not combo-driven or initialized on reset.
  // This is a placeholder driver. They require either unimplemented drivers or changes in RDL.
  always_comb begin : missing_csr_we_inits
    hwif_in.I3CBase.HC_CONTROL.RESUME.we = 0;
    hwif_in.I3CBase.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR.we = 0;
    hwif_in.I3CBase.CONTROLLER_DEVICE_ADDR.DYNAMIC_ADDR_VALID.we = 0;
    hwif_in.I3CBase.RESET_CONTROL.SOFT_RST.we = 0;
    hwif_in.I3CBase.DCT_SECTION_OFFSET.TABLE_INDEX.we = 0;
    hwif_in.I3CBase.IBI_DATA_ABORT_CTRL.IBI_DATA_ABORT_MON.we = 0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.HANDOFF_DEEP_SLEEP.we = 0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.TARGET_XACT_ENABLE.we = 0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_SETAASA_ENABLE.we = 0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_SETDASA_ENABLE.we = 0;
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.DAA_ENTDAA_ENABLE.we = 0;
    hwif_in.I3C_EC.TTI.RESET_CONTROL.SOFT_RST.we = 0;
    hwif_in.I3C_EC.TTI.RESET_CONTROL.RX_DATA_RST.we = 0;
    hwif_in.I3C_EC.CtrlCfg.CONTROLLER_CONFIG.OPERATION_MODE.we = 0;

    hwif_in.I3CBase.HC_CONTROL.BUS_ENABLE.we = 0;

    hwif_in.I3CBase.RESET_CONTROL.CMD_QUEUE_RST.we = 0;
    hwif_in.I3CBase.RESET_CONTROL.RESP_QUEUE_RST.we = 0;
    hwif_in.I3CBase.RESET_CONTROL.TX_FIFO_RST.we = 0;
    hwif_in.I3CBase.RESET_CONTROL.RX_FIFO_RST.we = 0;
    hwif_in.I3CBase.RESET_CONTROL.IBI_QUEUE_RST.we = 0;
    hwif_in.PIOControl.QUEUE_THLD_CTRL.CMD_EMPTY_BUF_THLD.we = 0;
    hwif_in.PIOControl.QUEUE_THLD_CTRL.RESP_BUF_THLD.we = 0;
    hwif_in.I3C_EC.TTI.RESET_CONTROL.TX_DESC_RST.we = 0;
    hwif_in.I3C_EC.TTI.RESET_CONTROL.RX_DESC_RST.we = 0;
    hwif_in.I3C_EC.TTI.RESET_CONTROL.TX_DATA_RST.we = 0;
    hwif_in.I3C_EC.TTI.RESET_CONTROL.IBI_QUEUE_RST.we = 0;
    hwif_in.I3C_EC.TTI.QUEUE_THLD_CTRL.TX_DESC_THLD.we = 0;
    hwif_in.I3C_EC.TTI.QUEUE_THLD_CTRL.RX_DESC_THLD.we = 0;
    hwif_in.I3C_EC.TTI.QUEUE_THLD_CTRL.IBI_THLD.we = 0;
  end : missing_csr_we_inits

  always_comb begin : other_uninit_signals
    hwif_in.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.HANDOFF_DEEP_SLEEP.hwclr = 0;

    // Unhandled wr/rd_ack (drivers are not included in this wrapper)
    hwif_in.PIOControl.COMMAND_PORT.wr_ack = 0;
    hwif_in.PIOControl.RESPONSE_PORT.rd_ack = 0;
    hwif_in.PIOControl.TX_DATA_PORT.wr_ack = 0;
    hwif_in.PIOControl.RX_DATA_PORT.rd_ack = 0;
    hwif_in.PIOControl.IBI_PORT.rd_ack = 0;
    hwif_in.I3C_EC.TTI.RX_DESC_QUEUE_PORT.rd_ack = 0;
    hwif_in.I3C_EC.TTI.RX_DATA_PORT.rd_ack = 0;
    hwif_in.I3C_EC.TTI.TX_DESC_QUEUE_PORT.wr_ack = 0;
    hwif_in.I3C_EC.TTI.TX_DATA_PORT.wr_ack = 0;
    hwif_in.I3C_EC.TTI.IBI_PORT.wr_ack = 0;

    // Unhandled wr/rd_ack (drivers are mising)
    hwif_in.DAT.rd_ack = 0;
    hwif_in.DAT.wr_ack = 0;
    hwif_in.DCT.rd_ack = 0;
    hwif_in.DCT.wr_ack = 0;
  end : other_uninit_signals

  logic wr_ack_q, rd_ack_q;
  logic fifo_rready_q, fifo_wvalid_q;
  logic [31:0] fifo_rdata_q, fifo_wdata_q;

  always_comb begin : connect_inidrect_fifo
    fifo_wvalid = fifo_wvalid_q;
    fifo_wdata = fifo_wdata_q;
    hwif_in.I3C_EC.SecFwRecoveryIf.INDIRECT_FIFO_DATA.wr_ack = wr_ack_q;

    fifo_rready = fifo_rready_q;
    hwif_in.I3C_EC.SecFwRecoveryIf.INDIRECT_FIFO_DATA.rd_data = fifo_rdata_q;
    hwif_in.I3C_EC.SecFwRecoveryIf.INDIRECT_FIFO_DATA.rd_ack = rd_ack_q;
  end

  always_ff @(posedge aclk or negedge areset_n) begin : stall_fifo_access
    if (~areset_n) begin
      wr_ack_q <= '0;
      rd_ack_q <= '0;
      fifo_rready_q <= '0;
      fifo_wvalid_q <= '0;
      fifo_rdata_q <= '0;
      fifo_wdata_q <= '0;
    end else begin
      wr_ack_q <= fifo_wvalid & fifo_wready;
      rd_ack_q <= fifo_rvalid & fifo_rready;
      fifo_rready_q <= hwif_out.I3C_EC.SecFwRecoveryIf.INDIRECT_FIFO_DATA.req & ~hwif_out.I3C_EC.SecFwRecoveryIf.INDIRECT_FIFO_DATA.req_is_wr;
      fifo_wvalid_q <= hwif_out.I3C_EC.SecFwRecoveryIf.INDIRECT_FIFO_DATA.req & hwif_out.I3C_EC.SecFwRecoveryIf.INDIRECT_FIFO_DATA.req_is_wr;
      fifo_rdata_q <= fifo_rdata;
      fifo_wdata_q <= hwif_out.I3C_EC.SecFwRecoveryIf.INDIRECT_FIFO_DATA.wr_data;
    end
  end
endmodule
