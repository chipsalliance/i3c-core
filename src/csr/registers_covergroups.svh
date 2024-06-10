// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef I3CCSR_COVERGROUPS
`define I3CCSR_COVERGROUPS

/*----------------------- I3CCSR__I3CBASE__HCI_VERSION COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__HCI_VERSION_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__HCI_VERSION_fld_cg with function sample (input bit [32-1:0] VERSION);
  option.per_instance = 1;
  VERSION_cp: coverpoint VERSION;

endgroup

/*----------------------- I3CCSR__I3CBASE__HC_CONTROL COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__HC_CONTROL_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__HC_CONTROL_fld_cg with function sample (
    input bit [1-1:0] IBA_INCLUDE,
    input bit [1-1:0] AUTOCMD_DATA_RPT,
    input bit [1-1:0] DATA_BYTE_ORDER_MODE,
    input bit [1-1:0] MODE_SELECTOR,
    input bit [1-1:0] I2C_DEV_PRESENT,
    input bit [1-1:0] HOT_JOIN_CTRL,
    input bit [1-1:0] HALT_ON_CMD_SEQ_TIMEOUT,
    input bit [1-1:0] ABORT,
    input bit [1-1:0] RESUME,
    input bit [1-1:0] BUS_ENABLE
);
  option.per_instance = 1;
  IBA_INCLUDE_cp: coverpoint IBA_INCLUDE;
  AUTOCMD_DATA_RPT_cp: coverpoint AUTOCMD_DATA_RPT;
  DATA_BYTE_ORDER_MODE_cp: coverpoint DATA_BYTE_ORDER_MODE;
  MODE_SELECTOR_cp: coverpoint MODE_SELECTOR;
  I2C_DEV_PRESENT_cp: coverpoint I2C_DEV_PRESENT;
  HOT_JOIN_CTRL_cp: coverpoint HOT_JOIN_CTRL;
  HALT_ON_CMD_SEQ_TIMEOUT_cp: coverpoint HALT_ON_CMD_SEQ_TIMEOUT;
  ABORT_cp: coverpoint ABORT;
  RESUME_cp: coverpoint RESUME;
  BUS_ENABLE_cp: coverpoint BUS_ENABLE;

endgroup

/*----------------------- I3CCSR__I3CBASE__CONTROLLER_DEVICE_ADDR COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__CONTROLLER_DEVICE_ADDR_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__CONTROLLER_DEVICE_ADDR_fld_cg with function sample (
    input bit [7-1:0] DYNAMIC_ADDR, input bit [1-1:0] DYNAMIC_ADDR_VALID
);
  option.per_instance = 1;
  DYNAMIC_ADDR_cp: coverpoint DYNAMIC_ADDR;
  DYNAMIC_ADDR_VALID_cp: coverpoint DYNAMIC_ADDR_VALID;

endgroup

/*----------------------- I3CCSR__I3CBASE__HC_CAPABILITIES COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__HC_CAPABILITIES_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__HC_CAPABILITIES_fld_cg with function sample (
    input bit [1-1:0] COMBO_COMMAND,
    input bit [1-1:0] AUTO_COMMAND,
    input bit [1-1:0] STANDBY_CR_CAP,
    input bit [1-1:0] HDR_DDR_EN,
    input bit [1-1:0] HDR_TS_EN,
    input bit [1-1:0] CMD_CCC_DEFBYTE,
    input bit [1-1:0] IBI_DATA_ABORT_EN,
    input bit [1-1:0] IBI_CREDIT_COUNT_EN,
    input bit [1-1:0] SCHEDULED_COMMANDS_EN,
    input bit [2-1:0] CMD_SIZE,
    input bit [1-1:0] SG_CAPABILITY_CR_EN,
    input bit [1-1:0] SG_CAPABILITY_IBI_EN,
    input bit [1-1:0] SG_CAPABILITY_DC_EN
);
  option.per_instance = 1;
  COMBO_COMMAND_cp: coverpoint COMBO_COMMAND;
  AUTO_COMMAND_cp: coverpoint AUTO_COMMAND;
  STANDBY_CR_CAP_cp: coverpoint STANDBY_CR_CAP;
  HDR_DDR_EN_cp: coverpoint HDR_DDR_EN;
  HDR_TS_EN_cp: coverpoint HDR_TS_EN;
  CMD_CCC_DEFBYTE_cp: coverpoint CMD_CCC_DEFBYTE;
  IBI_DATA_ABORT_EN_cp: coverpoint IBI_DATA_ABORT_EN;
  IBI_CREDIT_COUNT_EN_cp: coverpoint IBI_CREDIT_COUNT_EN;
  SCHEDULED_COMMANDS_EN_cp: coverpoint SCHEDULED_COMMANDS_EN;
  CMD_SIZE_cp: coverpoint CMD_SIZE;
  SG_CAPABILITY_CR_EN_cp: coverpoint SG_CAPABILITY_CR_EN;
  SG_CAPABILITY_IBI_EN_cp: coverpoint SG_CAPABILITY_IBI_EN;
  SG_CAPABILITY_DC_EN_cp: coverpoint SG_CAPABILITY_DC_EN;

endgroup

/*----------------------- I3CCSR__I3CBASE__RESET_CONTROL COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__RESET_CONTROL_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__RESET_CONTROL_fld_cg with function sample (
    input bit [1-1:0] SOFT_RST,
    input bit [1-1:0] CMD_QUEUE_RST,
    input bit [1-1:0] RESP_QUEUE_RST,
    input bit [1-1:0] TX_FIFO_RST,
    input bit [1-1:0] RX_FIFO_RST,
    input bit [1-1:0] IBI_QUEUE_RST
);
  option.per_instance = 1;
  SOFT_RST_cp: coverpoint SOFT_RST;
  CMD_QUEUE_RST_cp: coverpoint CMD_QUEUE_RST;
  RESP_QUEUE_RST_cp: coverpoint RESP_QUEUE_RST;
  TX_FIFO_RST_cp: coverpoint TX_FIFO_RST;
  RX_FIFO_RST_cp: coverpoint RX_FIFO_RST;
  IBI_QUEUE_RST_cp: coverpoint IBI_QUEUE_RST;

endgroup

/*----------------------- I3CCSR__I3CBASE__PRESENT_STATE COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__PRESENT_STATE_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__PRESENT_STATE_fld_cg with function sample (
    input bit [1-1:0] AC_CURRENT_OWN
);
  option.per_instance = 1;
  AC_CURRENT_OWN_cp: coverpoint AC_CURRENT_OWN;

endgroup

/*----------------------- I3CCSR__I3CBASE__INTR_STATUS COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__INTR_STATUS_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__INTR_STATUS_fld_cg with function sample (
    input bit [1-1:0] HC_INTERNAL_ERR_STAT,
    input bit [1-1:0] HC_SEQ_CANCEL_STAT,
    input bit [1-1:0] HC_WARN_CMD_SEQ_STALL_STAT,
    input bit [1-1:0] HC_ERR_CMD_SEQ_TIMEOUT_STAT,
    input bit [1-1:0] SCHED_CMD_MISSED_TICK_STAT
);
  option.per_instance = 1;
  HC_INTERNAL_ERR_STAT_cp: coverpoint HC_INTERNAL_ERR_STAT;
  HC_SEQ_CANCEL_STAT_cp: coverpoint HC_SEQ_CANCEL_STAT;
  HC_WARN_CMD_SEQ_STALL_STAT_cp: coverpoint HC_WARN_CMD_SEQ_STALL_STAT;
  HC_ERR_CMD_SEQ_TIMEOUT_STAT_cp: coverpoint HC_ERR_CMD_SEQ_TIMEOUT_STAT;
  SCHED_CMD_MISSED_TICK_STAT_cp: coverpoint SCHED_CMD_MISSED_TICK_STAT;

endgroup

/*----------------------- I3CCSR__I3CBASE__INTR_STATUS_ENABLE COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__INTR_STATUS_ENABLE_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__INTR_STATUS_ENABLE_fld_cg with function sample (
    input bit [1-1:0] HC_INTERNAL_ERR_STAT_EN,
    input bit [1-1:0] HC_SEQ_CANCEL_STAT_EN,
    input bit [1-1:0] HC_WARN_CMD_SEQ_STALL_STAT_EN,
    input bit [1-1:0] HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN,
    input bit [1-1:0] SCHED_CMD_MISSED_TICK_STAT_EN
);
  option.per_instance = 1;
  HC_INTERNAL_ERR_STAT_EN_cp: coverpoint HC_INTERNAL_ERR_STAT_EN;
  HC_SEQ_CANCEL_STAT_EN_cp: coverpoint HC_SEQ_CANCEL_STAT_EN;
  HC_WARN_CMD_SEQ_STALL_STAT_EN_cp: coverpoint HC_WARN_CMD_SEQ_STALL_STAT_EN;
  HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN_cp: coverpoint HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN;
  SCHED_CMD_MISSED_TICK_STAT_EN_cp: coverpoint SCHED_CMD_MISSED_TICK_STAT_EN;

endgroup

/*----------------------- I3CCSR__I3CBASE__INTR_SIGNAL_ENABLE COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__INTR_SIGNAL_ENABLE_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__INTR_SIGNAL_ENABLE_fld_cg with function sample (
    input bit [1-1:0] HC_INTERNAL_ERR_SIGNAL_EN,
    input bit [1-1:0] HC_SEQ_CANCEL_SIGNAL_EN,
    input bit [1-1:0] HC_WARN_CMD_SEQ_STALL_SIGNAL_EN,
    input bit [1-1:0] HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN,
    input bit [1-1:0] SCHED_CMD_MISSED_TICK_SIGNAL_EN
);
  option.per_instance = 1;
  HC_INTERNAL_ERR_SIGNAL_EN_cp: coverpoint HC_INTERNAL_ERR_SIGNAL_EN;
  HC_SEQ_CANCEL_SIGNAL_EN_cp: coverpoint HC_SEQ_CANCEL_SIGNAL_EN;
  HC_WARN_CMD_SEQ_STALL_SIGNAL_EN_cp: coverpoint HC_WARN_CMD_SEQ_STALL_SIGNAL_EN;
  HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN_cp: coverpoint HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN;
  SCHED_CMD_MISSED_TICK_SIGNAL_EN_cp: coverpoint SCHED_CMD_MISSED_TICK_SIGNAL_EN;

endgroup

/*----------------------- I3CCSR__I3CBASE__INTR_FORCE COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__INTR_FORCE_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__INTR_FORCE_fld_cg with function sample (
    input bit [1-1:0] HC_INTERNAL_ERR_FORCE,
    input bit [1-1:0] HC_SEQ_CANCEL_FORCE,
    input bit [1-1:0] HC_WARN_CMD_SEQ_STALL_FORCE,
    input bit [1-1:0] HC_ERR_CMD_SEQ_TIMEOUT_FORCE,
    input bit [1-1:0] SCHED_CMD_MISSED_TICK_FORCE
);
  option.per_instance = 1;
  HC_INTERNAL_ERR_FORCE_cp: coverpoint HC_INTERNAL_ERR_FORCE;
  HC_SEQ_CANCEL_FORCE_cp: coverpoint HC_SEQ_CANCEL_FORCE;
  HC_WARN_CMD_SEQ_STALL_FORCE_cp: coverpoint HC_WARN_CMD_SEQ_STALL_FORCE;
  HC_ERR_CMD_SEQ_TIMEOUT_FORCE_cp: coverpoint HC_ERR_CMD_SEQ_TIMEOUT_FORCE;
  SCHED_CMD_MISSED_TICK_FORCE_cp: coverpoint SCHED_CMD_MISSED_TICK_FORCE;

endgroup

/*----------------------- I3CCSR__I3CBASE__DAT_SECTION_OFFSET COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__DAT_SECTION_OFFSET_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__DAT_SECTION_OFFSET_fld_cg with function sample (
    input bit [12-1:0] TABLE_OFFSET,
    input bit [7-1:0] TABLE_SIZE,
    input bit [4-1:0] ENTRY_SIZE
);
  option.per_instance = 1;
  TABLE_OFFSET_cp: coverpoint TABLE_OFFSET;
  TABLE_SIZE_cp: coverpoint TABLE_SIZE;
  ENTRY_SIZE_cp: coverpoint ENTRY_SIZE;

endgroup

/*----------------------- I3CCSR__I3CBASE__DCT_SECTION_OFFSET COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__DCT_SECTION_OFFSET_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__DCT_SECTION_OFFSET_fld_cg with function sample (
    input bit [12-1:0] TABLE_OFFSET,
    input bit [7-1:0] TABLE_SIZE,
    input bit [5-1:0] TABLE_INDEX,
    input bit [4-1:0] ENTRY_SIZE
);
  option.per_instance = 1;
  TABLE_OFFSET_cp: coverpoint TABLE_OFFSET;
  TABLE_SIZE_cp: coverpoint TABLE_SIZE;
  TABLE_INDEX_cp: coverpoint TABLE_INDEX;
  ENTRY_SIZE_cp: coverpoint ENTRY_SIZE;

endgroup

/*----------------------- I3CCSR__I3CBASE__RING_HEADERS_SECTION_OFFSET COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__RING_HEADERS_SECTION_OFFSET_bit_cg with function sample (
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__RING_HEADERS_SECTION_OFFSET_fld_cg with function sample (
    input bit [16-1:0] SECTION_OFFSET
);
  option.per_instance = 1;
  SECTION_OFFSET_cp: coverpoint SECTION_OFFSET;

endgroup

/*----------------------- I3CCSR__I3CBASE__PIO_SECTION_OFFSET COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__PIO_SECTION_OFFSET_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__PIO_SECTION_OFFSET_fld_cg with function sample (
    input bit [16-1:0] SECTION_OFFSET
);
  option.per_instance = 1;
  SECTION_OFFSET_cp: coverpoint SECTION_OFFSET;

endgroup

/*----------------------- I3CCSR__I3CBASE__EXT_CAPS_SECTION_OFFSET COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__EXT_CAPS_SECTION_OFFSET_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__EXT_CAPS_SECTION_OFFSET_fld_cg with function sample (
    input bit [16-1:0] SECTION_OFFSET
);
  option.per_instance = 1;
  SECTION_OFFSET_cp: coverpoint SECTION_OFFSET;

endgroup

/*----------------------- I3CCSR__I3CBASE__INT_CTRL_CMDS_EN COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__INT_CTRL_CMDS_EN_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__INT_CTRL_CMDS_EN_fld_cg with function sample (
    input bit [1-1:0] ICC_SUPPORT, input bit [15-1:0] MIPI_CMDS_SUPPORTED
);
  option.per_instance = 1;
  ICC_SUPPORT_cp: coverpoint ICC_SUPPORT;
  MIPI_CMDS_SUPPORTED_cp: coverpoint MIPI_CMDS_SUPPORTED;

endgroup

/*----------------------- I3CCSR__I3CBASE__IBI_NOTIFY_CTRL COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__IBI_NOTIFY_CTRL_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__IBI_NOTIFY_CTRL_fld_cg with function sample (
    input bit [1-1:0] NOTIFY_HJ_REJECTED,
    input bit [1-1:0] NOTIFY_CRR_REJECTED,
    input bit [1-1:0] NOTIFY_IBI_REJECTED
);
  option.per_instance = 1;
  NOTIFY_HJ_REJECTED_cp: coverpoint NOTIFY_HJ_REJECTED;
  NOTIFY_CRR_REJECTED_cp: coverpoint NOTIFY_CRR_REJECTED;
  NOTIFY_IBI_REJECTED_cp: coverpoint NOTIFY_IBI_REJECTED;

endgroup

/*----------------------- I3CCSR__I3CBASE__IBI_DATA_ABORT_CTRL COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__IBI_DATA_ABORT_CTRL_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__IBI_DATA_ABORT_CTRL_fld_cg with function sample (
    input bit [8-1:0] MATCH_IBI_ID,
    input bit [2-1:0] AFTER_N_CHUNKS,
    input bit [3-1:0] MATCH_STATUS_TYPE,
    input bit [1-1:0] IBI_DATA_ABORT_MON
);
  option.per_instance = 1;
  MATCH_IBI_ID_cp: coverpoint MATCH_IBI_ID;
  AFTER_N_CHUNKS_cp: coverpoint AFTER_N_CHUNKS;
  MATCH_STATUS_TYPE_cp: coverpoint MATCH_STATUS_TYPE;
  IBI_DATA_ABORT_MON_cp: coverpoint IBI_DATA_ABORT_MON;

endgroup

/*----------------------- I3CCSR__I3CBASE__DEV_CTX_BASE_LO COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__DEV_CTX_BASE_LO_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__DEV_CTX_BASE_LO_fld_cg with function sample (
    input bit [1-1:0] BASE_LO
);
  option.per_instance = 1;
  BASE_LO_cp: coverpoint BASE_LO;

endgroup

/*----------------------- I3CCSR__I3CBASE__DEV_CTX_BASE_HI COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__DEV_CTX_BASE_HI_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__DEV_CTX_BASE_HI_fld_cg with function sample (
    input bit [1-1:0] BASE_HI
);
  option.per_instance = 1;
  BASE_HI_cp: coverpoint BASE_HI;

endgroup

/*----------------------- I3CCSR__I3CBASE__DEV_CTX_SG COVERGROUPS -----------------------*/
covergroup I3CCSR__I3CBase__DEV_CTX_SG_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3CBase__DEV_CTX_SG_fld_cg with function sample (
    input bit [16-1:0] LIST_SIZE, input bit [1-1:0] BLP
);
  option.per_instance = 1;
  LIST_SIZE_cp: coverpoint LIST_SIZE;
  BLP_cp: coverpoint BLP;

endgroup

/*----------------------- I3CCSR__PIOCONTROL__COMMAND_PORT COVERGROUPS -----------------------*/
covergroup I3CCSR__PIOControl__COMMAND_PORT_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__PIOControl__COMMAND_PORT_fld_cg with function sample (
    input bit [1-1:0] COMMAND_DATA
);
  option.per_instance = 1;
  COMMAND_DATA_cp: coverpoint COMMAND_DATA;

endgroup

/*----------------------- I3CCSR__PIOCONTROL__RESPONSE_PORT COVERGROUPS -----------------------*/
covergroup I3CCSR__PIOControl__RESPONSE_PORT_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__PIOControl__RESPONSE_PORT_fld_cg with function sample (
    input bit [1-1:0] RESPONSE_DATA
);
  option.per_instance = 1;
  RESPONSE_DATA_cp: coverpoint RESPONSE_DATA;

endgroup

/*----------------------- I3CCSR__PIOCONTROL__XFER_DATA_PORT COVERGROUPS -----------------------*/
covergroup I3CCSR__PIOControl__XFER_DATA_PORT_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__PIOControl__XFER_DATA_PORT_fld_cg with function sample (
    input bit [32-1:0] TX_DATA, input bit [32-1:0] RX_DATA
);
  option.per_instance = 1;
  TX_DATA_cp: coverpoint TX_DATA;
  RX_DATA_cp: coverpoint RX_DATA;

endgroup

/*----------------------- I3CCSR__PIOCONTROL__IBI_PORT COVERGROUPS -----------------------*/
covergroup I3CCSR__PIOControl__IBI_PORT_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__PIOControl__IBI_PORT_fld_cg with function sample (input bit [1-1:0] IBI_DATA);
  option.per_instance = 1;
  IBI_DATA_cp: coverpoint IBI_DATA;

endgroup

/*----------------------- I3CCSR__PIOCONTROL__QUEUE_THLD_CTRL COVERGROUPS -----------------------*/
covergroup I3CCSR__PIOControl__QUEUE_THLD_CTRL_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__PIOControl__QUEUE_THLD_CTRL_fld_cg with function sample (
    input bit [8-1:0] CMD_EMPTY_BUF_THLD,
    input bit [8-1:0] RESP_BUF_THLD,
    input bit [8-1:0] IBI_DATA_SEGMENT_SIZE,
    input bit [8-1:0] IBI_STATUS_THLD
);
  option.per_instance = 1;
  CMD_EMPTY_BUF_THLD_cp: coverpoint CMD_EMPTY_BUF_THLD;
  RESP_BUF_THLD_cp: coverpoint RESP_BUF_THLD;
  IBI_DATA_SEGMENT_SIZE_cp: coverpoint IBI_DATA_SEGMENT_SIZE;
  IBI_STATUS_THLD_cp: coverpoint IBI_STATUS_THLD;

endgroup

/*----------------------- I3CCSR__PIOCONTROL__DATA_BUFFER_THLD_CTRL COVERGROUPS -----------------------*/
covergroup I3CCSR__PIOControl__DATA_BUFFER_THLD_CTRL_bit_cg with function sample (
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__PIOControl__DATA_BUFFER_THLD_CTRL_fld_cg with function sample (
    input bit [3-1:0] TX_BUF_THLD,
    input bit [3-1:0] RX_BUF_THLD,
    input bit [3-1:0] TX_START_THLD,
    input bit [3-1:0] RX_START_THLD
);
  option.per_instance = 1;
  TX_BUF_THLD_cp: coverpoint TX_BUF_THLD;
  RX_BUF_THLD_cp: coverpoint RX_BUF_THLD;
  TX_START_THLD_cp: coverpoint TX_START_THLD;
  RX_START_THLD_cp: coverpoint RX_START_THLD;

endgroup

/*----------------------- I3CCSR__PIOCONTROL__QUEUE_SIZE COVERGROUPS -----------------------*/
covergroup I3CCSR__PIOControl__QUEUE_SIZE_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__PIOControl__QUEUE_SIZE_fld_cg with function sample (
    input bit [8-1:0] CR_QUEUE_SIZE,
    input bit [8-1:0] IBI_STATUS_SIZE,
    input bit [8-1:0] RX_DATA_BUFFER_SIZE,
    input bit [8-1:0] TX_DATA_BUFFER_SIZE
);
  option.per_instance = 1;
  CR_QUEUE_SIZE_cp: coverpoint CR_QUEUE_SIZE;
  IBI_STATUS_SIZE_cp: coverpoint IBI_STATUS_SIZE;
  RX_DATA_BUFFER_SIZE_cp: coverpoint RX_DATA_BUFFER_SIZE;
  TX_DATA_BUFFER_SIZE_cp: coverpoint TX_DATA_BUFFER_SIZE;

endgroup

/*----------------------- I3CCSR__PIOCONTROL__ALT_QUEUE_SIZE COVERGROUPS -----------------------*/
covergroup I3CCSR__PIOControl__ALT_QUEUE_SIZE_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__PIOControl__ALT_QUEUE_SIZE_fld_cg with function sample (
    input bit [8-1:0] ALT_RESP_QUEUE_SIZE,
    input bit [1-1:0] ALT_RESP_QUEUE_EN,
    input bit [1-1:0] EXT_IBI_QUEUE_EN
);
  option.per_instance = 1;
  ALT_RESP_QUEUE_SIZE_cp: coverpoint ALT_RESP_QUEUE_SIZE;
  ALT_RESP_QUEUE_EN_cp: coverpoint ALT_RESP_QUEUE_EN;
  EXT_IBI_QUEUE_EN_cp: coverpoint EXT_IBI_QUEUE_EN;

endgroup

/*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_STATUS COVERGROUPS -----------------------*/
covergroup I3CCSR__PIOControl__PIO_INTR_STATUS_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__PIOControl__PIO_INTR_STATUS_fld_cg with function sample (
    input bit [1-1:0] TX_THLD_STAT,
    input bit [1-1:0] RX_THLD_STAT,
    input bit [1-1:0] IBI_STATUS_THLD_STAT,
    input bit [1-1:0] CMD_QUEUE_READY_STAT,
    input bit [1-1:0] RESP_READY_STAT,
    input bit [1-1:0] TRANSFER_ABORT_STAT,
    input bit [1-1:0] TRANSFER_ERR_STAT
);
  option.per_instance = 1;
  TX_THLD_STAT_cp: coverpoint TX_THLD_STAT;
  RX_THLD_STAT_cp: coverpoint RX_THLD_STAT;
  IBI_STATUS_THLD_STAT_cp: coverpoint IBI_STATUS_THLD_STAT;
  CMD_QUEUE_READY_STAT_cp: coverpoint CMD_QUEUE_READY_STAT;
  RESP_READY_STAT_cp: coverpoint RESP_READY_STAT;
  TRANSFER_ABORT_STAT_cp: coverpoint TRANSFER_ABORT_STAT;
  TRANSFER_ERR_STAT_cp: coverpoint TRANSFER_ERR_STAT;

endgroup

/*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_STATUS_ENABLE COVERGROUPS -----------------------*/
covergroup I3CCSR__PIOControl__PIO_INTR_STATUS_ENABLE_bit_cg with function sample (
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__PIOControl__PIO_INTR_STATUS_ENABLE_fld_cg with function sample (
    input bit [1-1:0] TX_THLD_STAT_EN,
    input bit [1-1:0] RX_THLD_STAT_EN,
    input bit [1-1:0] IBI_STATUS_THLD_STAT_EN,
    input bit [1-1:0] CMD_QUEUE_READY_STAT_EN,
    input bit [1-1:0] RESP_READY_STAT_EN,
    input bit [1-1:0] TRANSFER_ABORT_STAT_EN,
    input bit [1-1:0] TRANSFER_ERR_STAT_EN
);
  option.per_instance = 1;
  TX_THLD_STAT_EN_cp: coverpoint TX_THLD_STAT_EN;
  RX_THLD_STAT_EN_cp: coverpoint RX_THLD_STAT_EN;
  IBI_STATUS_THLD_STAT_EN_cp: coverpoint IBI_STATUS_THLD_STAT_EN;
  CMD_QUEUE_READY_STAT_EN_cp: coverpoint CMD_QUEUE_READY_STAT_EN;
  RESP_READY_STAT_EN_cp: coverpoint RESP_READY_STAT_EN;
  TRANSFER_ABORT_STAT_EN_cp: coverpoint TRANSFER_ABORT_STAT_EN;
  TRANSFER_ERR_STAT_EN_cp: coverpoint TRANSFER_ERR_STAT_EN;

endgroup

/*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_SIGNAL_ENABLE COVERGROUPS -----------------------*/
covergroup I3CCSR__PIOControl__PIO_INTR_SIGNAL_ENABLE_bit_cg with function sample (
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__PIOControl__PIO_INTR_SIGNAL_ENABLE_fld_cg with function sample (
    input bit [1-1:0] TX_THLD_SIGNAL_EN,
    input bit [1-1:0] RX_THLD_SIGNAL_EN,
    input bit [1-1:0] IBI_STATUS_THLD_SIGNAL_EN,
    input bit [1-1:0] CMD_QUEUE_READY_SIGNAL_EN,
    input bit [1-1:0] RESP_READY_SIGNAL_EN,
    input bit [1-1:0] TRANSFER_ABORT_SIGNAL_EN,
    input bit [1-1:0] TRANSFER_ERR_SIGNAL_EN
);
  option.per_instance = 1;
  TX_THLD_SIGNAL_EN_cp: coverpoint TX_THLD_SIGNAL_EN;
  RX_THLD_SIGNAL_EN_cp: coverpoint RX_THLD_SIGNAL_EN;
  IBI_STATUS_THLD_SIGNAL_EN_cp: coverpoint IBI_STATUS_THLD_SIGNAL_EN;
  CMD_QUEUE_READY_SIGNAL_EN_cp: coverpoint CMD_QUEUE_READY_SIGNAL_EN;
  RESP_READY_SIGNAL_EN_cp: coverpoint RESP_READY_SIGNAL_EN;
  TRANSFER_ABORT_SIGNAL_EN_cp: coverpoint TRANSFER_ABORT_SIGNAL_EN;
  TRANSFER_ERR_SIGNAL_EN_cp: coverpoint TRANSFER_ERR_SIGNAL_EN;

endgroup

/*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_FORCE COVERGROUPS -----------------------*/
covergroup I3CCSR__PIOControl__PIO_INTR_FORCE_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__PIOControl__PIO_INTR_FORCE_fld_cg with function sample (
    input bit [1-1:0] TX_THLD_FORCE,
    input bit [1-1:0] RX_THLD_FORCE,
    input bit [1-1:0] IBI_THLD_FORCE,
    input bit [1-1:0] CMD_QUEUE_READY_FORCE,
    input bit [1-1:0] RESP_READY_FORCE,
    input bit [1-1:0] TRANSFER_ABORT_FORCE,
    input bit [1-1:0] TRANSFER_ERR_FORCE
);
  option.per_instance = 1;
  TX_THLD_FORCE_cp: coverpoint TX_THLD_FORCE;
  RX_THLD_FORCE_cp: coverpoint RX_THLD_FORCE;
  IBI_THLD_FORCE_cp: coverpoint IBI_THLD_FORCE;
  CMD_QUEUE_READY_FORCE_cp: coverpoint CMD_QUEUE_READY_FORCE;
  RESP_READY_FORCE_cp: coverpoint RESP_READY_FORCE;
  TRANSFER_ABORT_FORCE_cp: coverpoint TRANSFER_ABORT_FORCE;
  TRANSFER_ERR_FORCE_cp: coverpoint TRANSFER_ERR_FORCE;

endgroup

/*----------------------- I3CCSR__PIOCONTROL__PIO_CONTROL COVERGROUPS -----------------------*/
covergroup I3CCSR__PIOControl__PIO_CONTROL_bit_cg with function sample (input bit reg_bit);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__PIOControl__PIO_CONTROL_fld_cg with function sample (
    input bit [1-1:0] ENABLE, input bit [1-1:0] RS, input bit [1-1:0] ABORT
);
  option.per_instance = 1;
  ENABLE_cp: coverpoint ENABLE;
  RS_cp: coverpoint RS;
  ABORT_cp: coverpoint ABORT;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__EXTCAP_HEADER COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__EXTCAP_HEADER_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__EXTCAP_HEADER_fld_cg with function sample(
    input bit [8-1:0] CAP_ID, input bit [16-1:0] CAP_LENGTH
);
  option.per_instance = 1;
  CAP_ID_cp: coverpoint CAP_ID;
  CAP_LENGTH_cp: coverpoint CAP_LENGTH;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__PROT_CAP_0 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_0_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_0_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__PROT_CAP_1 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_1_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_1_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__PROT_CAP_2 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_2_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_2_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__PROT_CAP_3 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_3_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_3_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_ID_0 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_0_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_0_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_ID_1 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_1_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_1_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_ID_2 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_2_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_2_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_ID_3 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_3_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_3_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_ID_4 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_4_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_4_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_ID_5 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_5_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_5_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_ID_6 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_6_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_6_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_STATUS_0 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_STATUS_0_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_STATUS_0_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_STATUS_1 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_STATUS_1_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_STATUS_1_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_RESET COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_RESET_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_RESET_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__RECOVERY_CTRL COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__RECOVERY_CTRL_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__RECOVERY_CTRL_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__RECOVERY_STATUS COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__RECOVERY_STATUS_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__RECOVERY_STATUS_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__HW_STATUS COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__HW_STATUS_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__HW_STATUS_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_CTRL_0 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_CTRL_0_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_CTRL_0_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_CTRL_1 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_CTRL_1_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_CTRL_1_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_STATUS_0 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_0_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_0_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_STATUS_1 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_1_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_1_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_STATUS_2 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_2_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_2_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_STATUS_3 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_3_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_3_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_STATUS_4 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_4_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_4_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_STATUS_5 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_5_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_5_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_DATA COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_DATA_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_DATA_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__TARGETTRANSACTIONINTERFACEREGISTERS__EXTCAP_HEADER COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__TargetTransactionInterfaceRegisters__EXTCAP_HEADER_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__TargetTransactionInterfaceRegisters__EXTCAP_HEADER_fld_cg with function sample(
    input bit [8-1:0] CAP_ID, input bit [16-1:0] CAP_LENGTH
);
  option.per_instance = 1;
  CAP_ID_cp: coverpoint CAP_ID;
  CAP_LENGTH_cp: coverpoint CAP_LENGTH;

endgroup

/*----------------------- I3CCSR__I3C_EC__TARGETTRANSACTIONINTERFACEREGISTERS__PLACE_HOLDER_1 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__TargetTransactionInterfaceRegisters__PLACE_HOLDER_1_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__TargetTransactionInterfaceRegisters__PLACE_HOLDER_1_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__SOCMANAGEMENTINTERFACEREGISTERS__EXTCAP_HEADER COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SoCManagementInterfaceRegisters__EXTCAP_HEADER_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SoCManagementInterfaceRegisters__EXTCAP_HEADER_fld_cg with function sample(
    input bit [8-1:0] CAP_ID, input bit [16-1:0] CAP_LENGTH
);
  option.per_instance = 1;
  CAP_ID_cp: coverpoint CAP_ID;
  CAP_LENGTH_cp: coverpoint CAP_LENGTH;

endgroup

/*----------------------- I3CCSR__I3C_EC__SOCMANAGEMENTINTERFACEREGISTERS__PLACE_HOLDER_1 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__SoCManagementInterfaceRegisters__PLACE_HOLDER_1_bit_cg with function sample(
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__SoCManagementInterfaceRegisters__PLACE_HOLDER_1_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

/*----------------------- I3CCSR__I3C_EC__CONTROLLERCONFIGREGISTERS__EXTCAP_HEADER COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__ControllerConfigRegisters__EXTCAP_HEADER_bit_cg with function sample (
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__ControllerConfigRegisters__EXTCAP_HEADER_fld_cg with function sample (
    input bit [8-1:0] CAP_ID, input bit [16-1:0] CAP_LENGTH
);
  option.per_instance = 1;
  CAP_ID_cp: coverpoint CAP_ID;
  CAP_LENGTH_cp: coverpoint CAP_LENGTH;

endgroup

/*----------------------- I3CCSR__I3C_EC__CONTROLLERCONFIGREGISTERS__PLACE_HOLDER_1 COVERGROUPS -----------------------*/
covergroup I3CCSR__I3C_EC__ControllerConfigRegisters__PLACE_HOLDER_1_bit_cg with function sample (
    input bit reg_bit
);
  option.per_instance = 1;
  reg_bit_cp: coverpoint reg_bit {bins value[2] = {0, 1};}
  reg_bit_edge_cp: coverpoint reg_bit {bins rise = (0 => 1); bins fall = (1 => 0);}

endgroup
covergroup I3CCSR__I3C_EC__ControllerConfigRegisters__PLACE_HOLDER_1_fld_cg with function sample (
    input bit [32-1:0] PLACEHOLDER
);
  option.per_instance = 1;
  PLACEHOLDER_cp: coverpoint PLACEHOLDER;

endgroup

`endif
