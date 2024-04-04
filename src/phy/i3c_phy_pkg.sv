// Copyright (c) 2024 Antmicro <www.antmicro.com>
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

package i3c_phy_pkg;

  typedef struct packed {
    logic interference_scl_err_o;
    logic interference_sda_err_o;
  } i3c_phy_err_t;

endpackage
