
// SPDX-License-Identifier: Apache-2.0
package hci_pkg;
  localparam int unsigned CmdFifoWidth = 64;  // MIPI I3C HCI v.1.2: 6.7: 2 DWORD
  localparam int unsigned RxFifoWidth = 32;
  localparam int unsigned TxFifoWidth = 32;
  localparam int unsigned RespFifoWidth = 32;  // MIPI I3C HCI v.1.2: 6.7: 1 DWORD

  localparam int unsigned CmdThldWidth = 8;
  localparam int unsigned TxThldWidth = 3;
  localparam int unsigned RxThldWidth = 3;
  localparam int unsigned RespThldWidth = 8;
endpackage : hci_pkg
