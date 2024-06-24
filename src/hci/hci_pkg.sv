
// SPDX-License-Identifier: Apache-2.0
package hci_pkg;
  // Host Controller Interface
  localparam int unsigned HciRespDataWidth = 32;  // MIPI I3C HCI v.1.2: 6.7: 1 DWORD
  localparam int unsigned HciCmdDataWidth = 64;  // MIPI I3C HCI v.1.2: 6.7: 2 DWORD
  localparam int unsigned HciRxDataWidth = 32;
  localparam int unsigned HciTxDataWidth = 32;

  localparam int unsigned HciRespThldWidth = 8;
  localparam int unsigned HciCmdThldWidth = 8;
  localparam int unsigned HciRxThldWidth = 3;
  localparam int unsigned HciTxThldWidth = 3;

  // Target Transaction Interface
  localparam int unsigned TtiRxDescDataWidth = 32;
  localparam int unsigned TtiTxDescDataWidth = 32;
  localparam int unsigned TtiRxDataWidth = 32;
  localparam int unsigned TtiTxDataWidth = 32;

  localparam int unsigned TtiRxDescThldWidth = 8;
  localparam int unsigned TtiTxDescThldWidth = 8;
  localparam int unsigned TtiRxThldWidth = 3;
  localparam int unsigned TtiTxThldWidth = 3;
endpackage : hci_pkg
