// SPDX-License-Identifier: Apache-2.0

package i3c_ahb_if_pkg;
  // Data width of AHB FIFO interface
  parameter int unsigned AHB_DATA_WIDTH = 64;
  // Address width of AHB FIFO interface.
  parameter int unsigned AHB_ADDR_WIDTH = 32;
  // Burst width of AHB FIFO interface
  parameter int unsigned AHB_BURST_WIDTH = 3;
  // Length of the AHB FIFO. Directly defines
  // the number of CSR commands that can be stored at a time
  parameter int unsigned FIFO_DEPTH = 5;
endpackage
