// SPDX-License-Identifier: Apache-2.0
`include "i3c_defines.svh"

///////////////////////////////////////////////////////////////
//                            DUT                            //
///////////////////////////////////////////////////////////////

`define VERILATOR
/*
    This module is used only for simulation with Verilator
*/

module i3c_controller_test_wrapper #(
`ifdef I3C_USE_AHB
    parameter int unsigned AhbDataWidth = `AHB_DATA_WIDTH,
    parameter int unsigned AhbAddrWidth = `AHB_ADDR_WIDTH,
`elsif I3C_USE_AXI
    parameter int unsigned AxiDataWidth = `AXI_DATA_WIDTH,
    parameter int unsigned AxiAddrWidth = `AXI_ADDR_WIDTH,
    parameter int unsigned AxiUserWidth = `AXI_USER_WIDTH,
    parameter int unsigned AxiIdWidth = `AXI_ID_WIDTH,
`ifdef AXI_ID_FILTERING
    parameter int unsigned NumPrivIds = `NUM_PRIV_IDS,
`endif
`endif
    parameter int unsigned DatAw = i3c_pkg::DatAw,
    parameter int unsigned DctAw = i3c_pkg::DctAw,

    parameter int unsigned CsrAddrWidth = I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH,
    parameter int unsigned CsrDataWidth = I3CCSR_pkg::I3CCSR_DATA_WIDTH
) (
`ifdef I3C_USE_AHB
    input  logic                      hclk     [3],
    input  logic                      hreset_n [3],
    // AHB-Lite interface
    input  logic [  AhbAddrWidth-1:0] haddr    [3],
    input  logic [               2:0] hburst   [3],
    input  logic [               3:0] hprot    [3],
    input  logic [               2:0] hsize    [3],
    input  logic [               1:0] htrans   [3],
    input  logic [  AhbDataWidth-1:0] hwdata   [3],
    input  logic [AhbDataWidth/8-1:0] hwstrb   [3],
    input  logic                      hwrite   [3],
    output logic [  AhbDataWidth-1:0] hrdata   [3],
    output logic                      hreadyout[3],
    output logic                      hresp    [3],
    input  logic                      hsel     [3],
    input  logic                      hready   [3],
`elsif I3C_USE_AXI
    input  logic                      aclk     [3],
    input  logic                      areset_n [3],
    // AXI4 Interface
    // AXI Read Channels
    input  logic [  AxiAddrWidth-1:0] araddr   [3],
    input  logic [               1:0] arburst  [3],
    input  logic [               2:0] arsize   [3],
    input  logic [               7:0] arlen    [3],
    input  logic [  AxiUserWidth-1:0] aruser   [3],
    input  logic [    AxiIdWidth-1:0] arid     [3],
    input  logic                      arlock   [3],
    input  logic                      arvalid  [3],
    output logic                      arready  [3],

    output logic [AxiDataWidth-1:0] rdata [3],
    output logic [             1:0] rresp [3],
    output logic [  AxiIdWidth-1:0] rid   [3],
    output logic [AxiUserWidth-1:0] ruser [3],
    output logic                    rlast [3],
    output logic                    rvalid[3],
    input  logic                    rready[3],

    // AXI Write Channels
    input  logic [AxiAddrWidth-1:0] awaddr [3],
    input  logic [             1:0] awburst[3],
    input  logic [             2:0] awsize [3],
    input  logic [             7:0] awlen  [3],
    input  logic [AxiUserWidth-1:0] awuser [3],
    input  logic [  AxiIdWidth-1:0] awid   [3],
    input  logic                    awlock [3],
    input  logic                    awvalid[3],
    output logic                    awready[3],

    input  logic [  AxiDataWidth-1:0] wdata [3],
    input  logic [AxiDataWidth/8-1:0] wstrb [3],
    input  logic [  AxiUserWidth-1:0] wuser [3],
    input  logic                      wlast [3],
    input  logic                      wvalid[3],
    output logic                      wready[3],

    output logic [             1:0] bresp [3],
    output logic [  AxiIdWidth-1:0] bid   [3],
    output logic [AxiUserWidth-1:0] buser [3],
    output logic                    bvalid[3],
    input  logic                    bready[3],

`ifdef AXI_ID_FILTERING
    input logic disable_id_filtering_i[3],
    input logic [AxiUserWidth-1:0] priv_ids_i[3][NumPrivIds],
`endif
`endif
    // I3C Target Controller model
    input logic sda_sim_ctrl_i,
    input logic scl_sim_ctrl_i,
    input wire [4:0] debug_state_target_i,
    input wire [3:0] debug_detected_header_i,

    // I3C Bus signals
    output logic exp_bus_sda,
    output logic exp_bus_scl,
    output i3c_pkg::bus_state_t exp_bus_state,
    output logic phy_sel_od_pp_o,

    output logic act_bus_sda_o,
    output logic act_bus_scl_o,
    // These signals are shifted by 2 clock cycles s.t. the phy_sel_od_pp_o
    // signal and bus signals line up perfectly for the cocotbext i3c target
    output logic act_bus_scl_q2,
    output logic act_bus_sda_q2,
    output i3c_pkg::bus_state_t act_bus_state,
    output logic irq_o[3]
);

  ///////////////////////////////////////////////////////////////
  // AXI port mappings:                                        //
  // [0] -> expected Target                                    //
  // [1] -> actual Controller                                  //
  // [2] -> actual Target                                      //
  ///////////////////////////////////////////////////////////////

  //─────────────────────────── Unassigned ports ──────────────────────────
  logic recovery_payload_available_o[3];
  logic recovery_image_activated_o[3];
  logic peripheral_reset_o[3];
  logic peripheral_reset_done_i[3];
  logic escalated_reset_o[3];
  //───────────────────────── Bus instantiations ─────────────────────────

  logic irq[3];
  assign irq_o[0] = irq[0];
  assign irq_o[1] = irq[1];
  assign irq_o[2] = irq[2];

  ///////////////////////////////////////////////////////////////
  //                       Expected BUS                        //
  ///////////////////////////////////////////////////////////////

  logic unassigned_irq;

  i3c_expected_bus_wrapper i_expected_bus (
      .aclk(aclk[0]),
      .areset_n(areset_n[0]),
      // AXI4 Interface
      // AXI Read Channels
      .araddr(araddr[0]),
      .arburst(arburst[0]),
      .arsize(arsize[0]),
      .arlen(arlen[0]),
      .aruser(aruser[0]),
      .arid(arid[0]),
      .arlock(arlock[0]),
      .arvalid(arvalid[0]),
      .arready(arready[0]),

      .rdata(rdata[0]),
      .rresp(rresp[0]),
      .rid(rid[0]),
      .ruser(ruser[0]),
      .rlast(rlast[0]),
      .rvalid(rvalid[0]),
      .rready(rready[0]),

      // AXI Write Channels
      .awaddr(awaddr[0]),
      .awburst(awburst[0]),
      .awsize(awsize[0]),
      .awlen(awlen[0]),
      .awuser(awuser[0]),
      .awid(awid[0]),
      .awlock(awlock[0]),
      .awvalid(awvalid[0]),
      .awready(awready[0]),

      .wdata (wdata[0]),
      .wstrb (wstrb[0]),
      .wuser (wuser[0]),
      .wlast (wlast[0]),
      .wvalid(wvalid[0]),
      .wready(wready[0]),

      .bresp(bresp[0]),
      .bid(bid[0]),
      .buser(buser[0]),
      .bvalid(bvalid[0]),
      .bready(bready[0]),

      .disable_id_filtering_i(disable_id_filtering_i[0]),
      .priv_ids_i(priv_ids_i[0]),

      // I3C Target Controller model
      .sda_sim_ctrl_i(sda_sim_ctrl_i),
      .scl_sim_ctrl_i(scl_sim_ctrl_i),
      .debug_state_target_i(debug_state_target_i),
      .debug_detected_header_i(debug_detected_header_i),

      // I3C Bus signals
      .bus_sda_o(exp_bus_sda),
      .bus_scl_o(exp_bus_scl),

      .recovery_payload_available_o(recovery_payload_available_o[0]),
      .recovery_image_activated_o  (recovery_image_activated_o[0]),

      .peripheral_reset_o(peripheral_reset_o[0]),
      .peripheral_reset_done_i(peripheral_reset_done_i[0]),
      .escalated_reset_o(escalated_reset_o[0]),

      .irq_o(irq[0])
  );

  bus_monitor i_expected_bus_monitor (
      .clk_i(aclk[0]),
      .rst_ni(areset_n[0]),
      .enable_i(1'b1),
      .scl_i(exp_bus_scl),
      .sda_i(exp_bus_sda),
      // TODO: assign proper values
      .t_hd_dat_i(1'd1),
      .t_r_i(1'd1),
      .t_f_i(1'd1),
      .state_o(exp_bus_state)
  );

  ///////////////////////////////////////////////////////////////
  //                        Actual BUS                         //
  ///////////////////////////////////////////////////////////////

  i3c_actual_bus_wrapper i_actual_bus (
      .aclk(aclk[1:2]),
      .areset_n(areset_n[1:2]),
      // AXI4 Interface
      // AXI Read Channels
      .araddr(araddr[1:2]),
      .arburst(arburst[1:2]),
      .arsize(arsize[1:2]),
      .arlen(arlen[1:2]),
      .aruser(aruser[1:2]),
      .arid(arid[1:2]),
      .arlock(arlock[1:2]),
      .arvalid(arvalid[1:2]),
      .arready(arready[1:2]),

      .rdata(rdata[1:2]),
      .rresp(rresp[1:2]),
      .rid(rid[1:2]),
      .ruser(ruser[1:2]),
      .rlast(rlast[1:2]),
      .rvalid(rvalid[1:2]),
      .rready(rready[1:2]),

      // AXI Write Channels
      .awaddr(awaddr[1:2]),
      .awburst(awburst[1:2]),
      .awsize(awsize[1:2]),
      .awlen(awlen[1:2]),
      .awuser(awuser[1:2]),
      .awid(awid[1:2]),
      .awlock(awlock[1:2]),
      .awvalid(awvalid[1:2]),
      .awready(awready[1:2]),

      .wdata (wdata[1:2]),
      .wstrb (wstrb[1:2]),
      .wuser (wuser[1:2]),
      .wlast (wlast[1:2]),
      .wvalid(wvalid[1:2]),
      .wready(wready[1:2]),

      .bresp(bresp[1:2]),
      .bid(bid[1:2]),
      .buser(buser[1:2]),
      .bvalid(bvalid[1:2]),
      .bready(bready[1:2]),

      .disable_id_filtering_i(disable_id_filtering_i[1:2]),
      .priv_ids_i(priv_ids_i[1:2]),

      // I3C Bus signals
      .bus_sda_o(act_bus_sda),
      .bus_scl_o(act_bus_scl),
      .phy_sel_od_pp_o,

      .recovery_payload_available_o(recovery_payload_available_o[1:2]),
      .recovery_image_activated_o  (recovery_image_activated_o[1:2]),

      .peripheral_reset_o(peripheral_reset_o[1:2]),
      .peripheral_reset_done_i(peripheral_reset_done_i[1:2]),
      .escalated_reset_o(escalated_reset_o[1:2]),

      .irq_o(irq[1:2])
  );

  bus_monitor i_actual_bus_monitor (
      .clk_i(aclk[1]),
      .rst_ni(areset_n[1]),
      .enable_i(1'b1),
      .scl_i(act_bus_scl),
      .sda_i(act_bus_sda),
      // TODO: assign proper values
      .t_hd_dat_i(1'd1),
      .t_r_i(1'd1),
      .t_f_i(1'd1),
      .state_o(act_bus_state)
  );

  assign act_bus_scl_o = act_bus_state.scl.value;
  assign act_bus_sda_o = act_bus_state.sda.value;
  logic act_bus_scl_q, act_bus_sda_q;

  always_ff @(posedge aclk[1] or negedge areset_n[1]) begin
    if (~areset_n[1]) begin
      act_bus_scl_q  <= 1'b0;
      act_bus_scl_q2 <= 1'b0;
      act_bus_sda_q  <= 1'b0;
      act_bus_sda_q2 <= 1'b0;
    end else begin
      act_bus_scl_q  <= act_bus_scl_o;
      act_bus_scl_q2 <= act_bus_scl_q;
      act_bus_sda_q  <= act_bus_sda_o;
      act_bus_sda_q2 <= act_bus_sda_q;
    end
  end

endmodule

