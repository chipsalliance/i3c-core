// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//

package prim_ram_1p_pkg;

  typedef struct packed {
    logic       cfg_en;
    logic [3:0] cfg;
  } cfg_t;

  typedef struct packed {
    cfg_t ram_cfg;  // configuration for ram
    cfg_t rf_cfg;   // configuration for regfile
  } ram_1p_cfg_t;

endpackage // prim_ram_1p_pkg
