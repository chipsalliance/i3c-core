// SPDX-License-Identifier: Apache-2.0
// Generated from the selected YAML profile; do not edit.
package i3c_tb_cfg_pkg;
  localparam bit UseAxi = 1'b1;
  localparam int unsigned AhbAddrWidth = 18;
  localparam int unsigned AhbDataWidth = 64;
  localparam int unsigned AxiAddrWidth = 12;
  localparam int unsigned AxiDataWidth = 32;
  localparam int unsigned AxiUserWidth = 32;
  localparam int unsigned AxiIdWidth = 8;
  localparam bit EnableIdFiltering = 1'b1;
  localparam int unsigned NumPrivIds = 4;
  localparam bit DisableLoopback = 1'b0;
  localparam int unsigned CmdFifoDepth = 64;
  localparam int unsigned RespFifoDepth = 64;
  localparam int unsigned RxFifoDepth = 64;
  localparam int unsigned TxFifoDepth = 64;
  localparam int unsigned IbiFifoDepth = 64;
  localparam bit IbiFifoExtSize = 1'b0;
  localparam int unsigned DatDepth = 128;
  localparam int unsigned DctDepth = 128;
endpackage
