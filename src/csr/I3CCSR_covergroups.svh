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
    covergroup I3CCSR__I3CBase__HCI_VERSION_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__HCI_VERSION_fld_cg with function sample(
    input bit [32-1:0] VERSION
    );
        option.per_instance = 1;
        VERSION_cp : coverpoint VERSION;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__HC_CONTROL COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__HC_CONTROL_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__HC_CONTROL_fld_cg with function sample(
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
        IBA_INCLUDE_cp : coverpoint IBA_INCLUDE;
        AUTOCMD_DATA_RPT_cp : coverpoint AUTOCMD_DATA_RPT;
        DATA_BYTE_ORDER_MODE_cp : coverpoint DATA_BYTE_ORDER_MODE;
        MODE_SELECTOR_cp : coverpoint MODE_SELECTOR;
        I2C_DEV_PRESENT_cp : coverpoint I2C_DEV_PRESENT;
        HOT_JOIN_CTRL_cp : coverpoint HOT_JOIN_CTRL;
        HALT_ON_CMD_SEQ_TIMEOUT_cp : coverpoint HALT_ON_CMD_SEQ_TIMEOUT;
        ABORT_cp : coverpoint ABORT;
        RESUME_cp : coverpoint RESUME;
        BUS_ENABLE_cp : coverpoint BUS_ENABLE;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__CONTROLLER_DEVICE_ADDR COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__CONTROLLER_DEVICE_ADDR_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__CONTROLLER_DEVICE_ADDR_fld_cg with function sample(
    input bit [7-1:0] DYNAMIC_ADDR,
    input bit [1-1:0] DYNAMIC_ADDR_VALID
    );
        option.per_instance = 1;
        DYNAMIC_ADDR_cp : coverpoint DYNAMIC_ADDR;
        DYNAMIC_ADDR_VALID_cp : coverpoint DYNAMIC_ADDR_VALID;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__HC_CAPABILITIES COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__HC_CAPABILITIES_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__HC_CAPABILITIES_fld_cg with function sample(
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
        COMBO_COMMAND_cp : coverpoint COMBO_COMMAND;
        AUTO_COMMAND_cp : coverpoint AUTO_COMMAND;
        STANDBY_CR_CAP_cp : coverpoint STANDBY_CR_CAP;
        HDR_DDR_EN_cp : coverpoint HDR_DDR_EN;
        HDR_TS_EN_cp : coverpoint HDR_TS_EN;
        CMD_CCC_DEFBYTE_cp : coverpoint CMD_CCC_DEFBYTE;
        IBI_DATA_ABORT_EN_cp : coverpoint IBI_DATA_ABORT_EN;
        IBI_CREDIT_COUNT_EN_cp : coverpoint IBI_CREDIT_COUNT_EN;
        SCHEDULED_COMMANDS_EN_cp : coverpoint SCHEDULED_COMMANDS_EN;
        CMD_SIZE_cp : coverpoint CMD_SIZE;
        SG_CAPABILITY_CR_EN_cp : coverpoint SG_CAPABILITY_CR_EN;
        SG_CAPABILITY_IBI_EN_cp : coverpoint SG_CAPABILITY_IBI_EN;
        SG_CAPABILITY_DC_EN_cp : coverpoint SG_CAPABILITY_DC_EN;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__RESET_CONTROL COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__RESET_CONTROL_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__RESET_CONTROL_fld_cg with function sample(
    input bit [1-1:0] SOFT_RST,
    input bit [1-1:0] CMD_QUEUE_RST,
    input bit [1-1:0] RESP_QUEUE_RST,
    input bit [1-1:0] TX_FIFO_RST,
    input bit [1-1:0] RX_FIFO_RST,
    input bit [1-1:0] IBI_QUEUE_RST
    );
        option.per_instance = 1;
        SOFT_RST_cp : coverpoint SOFT_RST;
        CMD_QUEUE_RST_cp : coverpoint CMD_QUEUE_RST;
        RESP_QUEUE_RST_cp : coverpoint RESP_QUEUE_RST;
        TX_FIFO_RST_cp : coverpoint TX_FIFO_RST;
        RX_FIFO_RST_cp : coverpoint RX_FIFO_RST;
        IBI_QUEUE_RST_cp : coverpoint IBI_QUEUE_RST;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__PRESENT_STATE COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__PRESENT_STATE_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__PRESENT_STATE_fld_cg with function sample(
    input bit [1-1:0] AC_CURRENT_OWN
    );
        option.per_instance = 1;
        AC_CURRENT_OWN_cp : coverpoint AC_CURRENT_OWN;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__INTR_STATUS COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__INTR_STATUS_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__INTR_STATUS_fld_cg with function sample(
    input bit [1-1:0] HC_INTERNAL_ERR_STAT,
    input bit [1-1:0] HC_SEQ_CANCEL_STAT,
    input bit [1-1:0] HC_WARN_CMD_SEQ_STALL_STAT,
    input bit [1-1:0] HC_ERR_CMD_SEQ_TIMEOUT_STAT,
    input bit [1-1:0] SCHED_CMD_MISSED_TICK_STAT
    );
        option.per_instance = 1;
        HC_INTERNAL_ERR_STAT_cp : coverpoint HC_INTERNAL_ERR_STAT;
        HC_SEQ_CANCEL_STAT_cp : coverpoint HC_SEQ_CANCEL_STAT;
        HC_WARN_CMD_SEQ_STALL_STAT_cp : coverpoint HC_WARN_CMD_SEQ_STALL_STAT;
        HC_ERR_CMD_SEQ_TIMEOUT_STAT_cp : coverpoint HC_ERR_CMD_SEQ_TIMEOUT_STAT;
        SCHED_CMD_MISSED_TICK_STAT_cp : coverpoint SCHED_CMD_MISSED_TICK_STAT;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__INTR_STATUS_ENABLE COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__INTR_STATUS_ENABLE_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__INTR_STATUS_ENABLE_fld_cg with function sample(
    input bit [1-1:0] HC_INTERNAL_ERR_STAT_EN,
    input bit [1-1:0] HC_SEQ_CANCEL_STAT_EN,
    input bit [1-1:0] HC_WARN_CMD_SEQ_STALL_STAT_EN,
    input bit [1-1:0] HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN,
    input bit [1-1:0] SCHED_CMD_MISSED_TICK_STAT_EN
    );
        option.per_instance = 1;
        HC_INTERNAL_ERR_STAT_EN_cp : coverpoint HC_INTERNAL_ERR_STAT_EN;
        HC_SEQ_CANCEL_STAT_EN_cp : coverpoint HC_SEQ_CANCEL_STAT_EN;
        HC_WARN_CMD_SEQ_STALL_STAT_EN_cp : coverpoint HC_WARN_CMD_SEQ_STALL_STAT_EN;
        HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN_cp : coverpoint HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN;
        SCHED_CMD_MISSED_TICK_STAT_EN_cp : coverpoint SCHED_CMD_MISSED_TICK_STAT_EN;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__INTR_SIGNAL_ENABLE COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__INTR_SIGNAL_ENABLE_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__INTR_SIGNAL_ENABLE_fld_cg with function sample(
    input bit [1-1:0] HC_INTERNAL_ERR_SIGNAL_EN,
    input bit [1-1:0] HC_SEQ_CANCEL_SIGNAL_EN,
    input bit [1-1:0] HC_WARN_CMD_SEQ_STALL_SIGNAL_EN,
    input bit [1-1:0] HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN,
    input bit [1-1:0] SCHED_CMD_MISSED_TICK_SIGNAL_EN
    );
        option.per_instance = 1;
        HC_INTERNAL_ERR_SIGNAL_EN_cp : coverpoint HC_INTERNAL_ERR_SIGNAL_EN;
        HC_SEQ_CANCEL_SIGNAL_EN_cp : coverpoint HC_SEQ_CANCEL_SIGNAL_EN;
        HC_WARN_CMD_SEQ_STALL_SIGNAL_EN_cp : coverpoint HC_WARN_CMD_SEQ_STALL_SIGNAL_EN;
        HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN_cp : coverpoint HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN;
        SCHED_CMD_MISSED_TICK_SIGNAL_EN_cp : coverpoint SCHED_CMD_MISSED_TICK_SIGNAL_EN;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__INTR_FORCE COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__INTR_FORCE_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__INTR_FORCE_fld_cg with function sample(
    input bit [1-1:0] HC_INTERNAL_ERR_FORCE,
    input bit [1-1:0] HC_SEQ_CANCEL_FORCE,
    input bit [1-1:0] HC_WARN_CMD_SEQ_STALL_FORCE,
    input bit [1-1:0] HC_ERR_CMD_SEQ_TIMEOUT_FORCE,
    input bit [1-1:0] SCHED_CMD_MISSED_TICK_FORCE
    );
        option.per_instance = 1;
        HC_INTERNAL_ERR_FORCE_cp : coverpoint HC_INTERNAL_ERR_FORCE;
        HC_SEQ_CANCEL_FORCE_cp : coverpoint HC_SEQ_CANCEL_FORCE;
        HC_WARN_CMD_SEQ_STALL_FORCE_cp : coverpoint HC_WARN_CMD_SEQ_STALL_FORCE;
        HC_ERR_CMD_SEQ_TIMEOUT_FORCE_cp : coverpoint HC_ERR_CMD_SEQ_TIMEOUT_FORCE;
        SCHED_CMD_MISSED_TICK_FORCE_cp : coverpoint SCHED_CMD_MISSED_TICK_FORCE;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__DAT_SECTION_OFFSET COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__DAT_SECTION_OFFSET_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__DAT_SECTION_OFFSET_fld_cg with function sample(
    input bit [12-1:0] TABLE_OFFSET,
    input bit [7-1:0] TABLE_SIZE,
    input bit [4-1:0] ENTRY_SIZE
    );
        option.per_instance = 1;
        TABLE_OFFSET_cp : coverpoint TABLE_OFFSET;
        TABLE_SIZE_cp : coverpoint TABLE_SIZE;
        ENTRY_SIZE_cp : coverpoint ENTRY_SIZE;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__DCT_SECTION_OFFSET COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__DCT_SECTION_OFFSET_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__DCT_SECTION_OFFSET_fld_cg with function sample(
    input bit [12-1:0] TABLE_OFFSET,
    input bit [7-1:0] TABLE_SIZE,
    input bit [5-1:0] TABLE_INDEX,
    input bit [4-1:0] ENTRY_SIZE
    );
        option.per_instance = 1;
        TABLE_OFFSET_cp : coverpoint TABLE_OFFSET;
        TABLE_SIZE_cp : coverpoint TABLE_SIZE;
        TABLE_INDEX_cp : coverpoint TABLE_INDEX;
        ENTRY_SIZE_cp : coverpoint ENTRY_SIZE;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__RING_HEADERS_SECTION_OFFSET COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__RING_HEADERS_SECTION_OFFSET_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__RING_HEADERS_SECTION_OFFSET_fld_cg with function sample(
    input bit [16-1:0] SECTION_OFFSET
    );
        option.per_instance = 1;
        SECTION_OFFSET_cp : coverpoint SECTION_OFFSET;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__PIO_SECTION_OFFSET COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__PIO_SECTION_OFFSET_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__PIO_SECTION_OFFSET_fld_cg with function sample(
    input bit [16-1:0] SECTION_OFFSET
    );
        option.per_instance = 1;
        SECTION_OFFSET_cp : coverpoint SECTION_OFFSET;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__EXT_CAPS_SECTION_OFFSET COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__EXT_CAPS_SECTION_OFFSET_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__EXT_CAPS_SECTION_OFFSET_fld_cg with function sample(
    input bit [16-1:0] SECTION_OFFSET
    );
        option.per_instance = 1;
        SECTION_OFFSET_cp : coverpoint SECTION_OFFSET;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__INT_CTRL_CMDS_EN COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__INT_CTRL_CMDS_EN_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__INT_CTRL_CMDS_EN_fld_cg with function sample(
    input bit [1-1:0] ICC_SUPPORT,
    input bit [15-1:0] MIPI_CMDS_SUPPORTED
    );
        option.per_instance = 1;
        ICC_SUPPORT_cp : coverpoint ICC_SUPPORT;
        MIPI_CMDS_SUPPORTED_cp : coverpoint MIPI_CMDS_SUPPORTED;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__IBI_NOTIFY_CTRL COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__IBI_NOTIFY_CTRL_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__IBI_NOTIFY_CTRL_fld_cg with function sample(
    input bit [1-1:0] NOTIFY_HJ_REJECTED,
    input bit [1-1:0] NOTIFY_CRR_REJECTED,
    input bit [1-1:0] NOTIFY_IBI_REJECTED
    );
        option.per_instance = 1;
        NOTIFY_HJ_REJECTED_cp : coverpoint NOTIFY_HJ_REJECTED;
        NOTIFY_CRR_REJECTED_cp : coverpoint NOTIFY_CRR_REJECTED;
        NOTIFY_IBI_REJECTED_cp : coverpoint NOTIFY_IBI_REJECTED;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__IBI_DATA_ABORT_CTRL COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__IBI_DATA_ABORT_CTRL_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__IBI_DATA_ABORT_CTRL_fld_cg with function sample(
    input bit [8-1:0] MATCH_IBI_ID,
    input bit [2-1:0] AFTER_N_CHUNKS,
    input bit [3-1:0] MATCH_STATUS_TYPE,
    input bit [1-1:0] IBI_DATA_ABORT_MON
    );
        option.per_instance = 1;
        MATCH_IBI_ID_cp : coverpoint MATCH_IBI_ID;
        AFTER_N_CHUNKS_cp : coverpoint AFTER_N_CHUNKS;
        MATCH_STATUS_TYPE_cp : coverpoint MATCH_STATUS_TYPE;
        IBI_DATA_ABORT_MON_cp : coverpoint IBI_DATA_ABORT_MON;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__DEV_CTX_BASE_LO COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__DEV_CTX_BASE_LO_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__DEV_CTX_BASE_LO_fld_cg with function sample(
    input bit [1-1:0] BASE_LO
    );
        option.per_instance = 1;
        BASE_LO_cp : coverpoint BASE_LO;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__DEV_CTX_BASE_HI COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__DEV_CTX_BASE_HI_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__DEV_CTX_BASE_HI_fld_cg with function sample(
    input bit [1-1:0] BASE_HI
    );
        option.per_instance = 1;
        BASE_HI_cp : coverpoint BASE_HI;

    endgroup

    /*----------------------- I3CCSR__I3CBASE__DEV_CTX_SG COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3CBase__DEV_CTX_SG_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3CBase__DEV_CTX_SG_fld_cg with function sample(
    input bit [16-1:0] LIST_SIZE,
    input bit [1-1:0] BLP
    );
        option.per_instance = 1;
        LIST_SIZE_cp : coverpoint LIST_SIZE;
        BLP_cp : coverpoint BLP;

    endgroup

    /*----------------------- I3CCSR__PIOCONTROL__COMMAND_PORT COVERGROUPS -----------------------*/
    covergroup I3CCSR__PIOControl__COMMAND_PORT_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__PIOControl__COMMAND_PORT_fld_cg with function sample(
    input bit [32-1:0] COMMAND_DATA
    );
        option.per_instance = 1;
        COMMAND_DATA_cp : coverpoint COMMAND_DATA;

    endgroup

    /*----------------------- I3CCSR__PIOCONTROL__RESPONSE_PORT COVERGROUPS -----------------------*/
    covergroup I3CCSR__PIOControl__RESPONSE_PORT_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__PIOControl__RESPONSE_PORT_fld_cg with function sample(
    input bit [32-1:0] RESPONSE_DATA
    );
        option.per_instance = 1;
        RESPONSE_DATA_cp : coverpoint RESPONSE_DATA;

    endgroup

    /*----------------------- I3CCSR__PIOCONTROL__TX_DATA_PORT COVERGROUPS -----------------------*/
    covergroup I3CCSR__PIOControl__TX_DATA_PORT_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__PIOControl__TX_DATA_PORT_fld_cg with function sample(
    input bit [32-1:0] TX_DATA
    );
        option.per_instance = 1;
        TX_DATA_cp : coverpoint TX_DATA;

    endgroup

    /*----------------------- I3CCSR__PIOCONTROL__RX_DATA_PORT COVERGROUPS -----------------------*/
    covergroup I3CCSR__PIOControl__RX_DATA_PORT_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__PIOControl__RX_DATA_PORT_fld_cg with function sample(
    input bit [32-1:0] RX_DATA
    );
        option.per_instance = 1;
        RX_DATA_cp : coverpoint RX_DATA;

    endgroup

    /*----------------------- I3CCSR__PIOCONTROL__IBI_PORT COVERGROUPS -----------------------*/
    covergroup I3CCSR__PIOControl__IBI_PORT_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__PIOControl__IBI_PORT_fld_cg with function sample(
    input bit [32-1:0] IBI_DATA
    );
        option.per_instance = 1;
        IBI_DATA_cp : coverpoint IBI_DATA;

    endgroup

    /*----------------------- I3CCSR__PIOCONTROL__QUEUE_THLD_CTRL COVERGROUPS -----------------------*/
    covergroup I3CCSR__PIOControl__QUEUE_THLD_CTRL_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__PIOControl__QUEUE_THLD_CTRL_fld_cg with function sample(
    input bit [8-1:0] CMD_EMPTY_BUF_THLD,
    input bit [8-1:0] RESP_BUF_THLD,
    input bit [8-1:0] IBI_DATA_SEGMENT_SIZE,
    input bit [8-1:0] IBI_STATUS_THLD
    );
        option.per_instance = 1;
        CMD_EMPTY_BUF_THLD_cp : coverpoint CMD_EMPTY_BUF_THLD;
        RESP_BUF_THLD_cp : coverpoint RESP_BUF_THLD;
        IBI_DATA_SEGMENT_SIZE_cp : coverpoint IBI_DATA_SEGMENT_SIZE;
        IBI_STATUS_THLD_cp : coverpoint IBI_STATUS_THLD;

    endgroup

    /*----------------------- I3CCSR__PIOCONTROL__DATA_BUFFER_THLD_CTRL COVERGROUPS -----------------------*/
    covergroup I3CCSR__PIOControl__DATA_BUFFER_THLD_CTRL_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__PIOControl__DATA_BUFFER_THLD_CTRL_fld_cg with function sample(
    input bit [3-1:0] TX_BUF_THLD,
    input bit [3-1:0] RX_BUF_THLD,
    input bit [3-1:0] TX_START_THLD,
    input bit [3-1:0] RX_START_THLD
    );
        option.per_instance = 1;
        TX_BUF_THLD_cp : coverpoint TX_BUF_THLD;
        RX_BUF_THLD_cp : coverpoint RX_BUF_THLD;
        TX_START_THLD_cp : coverpoint TX_START_THLD;
        RX_START_THLD_cp : coverpoint RX_START_THLD;

    endgroup

    /*----------------------- I3CCSR__PIOCONTROL__QUEUE_SIZE COVERGROUPS -----------------------*/
    covergroup I3CCSR__PIOControl__QUEUE_SIZE_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__PIOControl__QUEUE_SIZE_fld_cg with function sample(
    input bit [8-1:0] CR_QUEUE_SIZE,
    input bit [8-1:0] IBI_STATUS_SIZE,
    input bit [8-1:0] RX_DATA_BUFFER_SIZE,
    input bit [8-1:0] TX_DATA_BUFFER_SIZE
    );
        option.per_instance = 1;
        CR_QUEUE_SIZE_cp : coverpoint CR_QUEUE_SIZE;
        IBI_STATUS_SIZE_cp : coverpoint IBI_STATUS_SIZE;
        RX_DATA_BUFFER_SIZE_cp : coverpoint RX_DATA_BUFFER_SIZE;
        TX_DATA_BUFFER_SIZE_cp : coverpoint TX_DATA_BUFFER_SIZE;

    endgroup

    /*----------------------- I3CCSR__PIOCONTROL__ALT_QUEUE_SIZE COVERGROUPS -----------------------*/
    covergroup I3CCSR__PIOControl__ALT_QUEUE_SIZE_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__PIOControl__ALT_QUEUE_SIZE_fld_cg with function sample(
    input bit [8-1:0] ALT_RESP_QUEUE_SIZE,
    input bit [1-1:0] ALT_RESP_QUEUE_EN,
    input bit [1-1:0] EXT_IBI_QUEUE_EN
    );
        option.per_instance = 1;
        ALT_RESP_QUEUE_SIZE_cp : coverpoint ALT_RESP_QUEUE_SIZE;
        ALT_RESP_QUEUE_EN_cp : coverpoint ALT_RESP_QUEUE_EN;
        EXT_IBI_QUEUE_EN_cp : coverpoint EXT_IBI_QUEUE_EN;

    endgroup

    /*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_STATUS COVERGROUPS -----------------------*/
    covergroup I3CCSR__PIOControl__PIO_INTR_STATUS_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__PIOControl__PIO_INTR_STATUS_fld_cg with function sample(
    input bit [1-1:0] TX_THLD_STAT,
    input bit [1-1:0] RX_THLD_STAT,
    input bit [1-1:0] IBI_STATUS_THLD_STAT,
    input bit [1-1:0] CMD_QUEUE_READY_STAT,
    input bit [1-1:0] RESP_READY_STAT,
    input bit [1-1:0] TRANSFER_ABORT_STAT,
    input bit [1-1:0] TRANSFER_ERR_STAT
    );
        option.per_instance = 1;
        TX_THLD_STAT_cp : coverpoint TX_THLD_STAT;
        RX_THLD_STAT_cp : coverpoint RX_THLD_STAT;
        IBI_STATUS_THLD_STAT_cp : coverpoint IBI_STATUS_THLD_STAT;
        CMD_QUEUE_READY_STAT_cp : coverpoint CMD_QUEUE_READY_STAT;
        RESP_READY_STAT_cp : coverpoint RESP_READY_STAT;
        TRANSFER_ABORT_STAT_cp : coverpoint TRANSFER_ABORT_STAT;
        TRANSFER_ERR_STAT_cp : coverpoint TRANSFER_ERR_STAT;

    endgroup

    /*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_STATUS_ENABLE COVERGROUPS -----------------------*/
    covergroup I3CCSR__PIOControl__PIO_INTR_STATUS_ENABLE_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__PIOControl__PIO_INTR_STATUS_ENABLE_fld_cg with function sample(
    input bit [1-1:0] TX_THLD_STAT_EN,
    input bit [1-1:0] RX_THLD_STAT_EN,
    input bit [1-1:0] IBI_STATUS_THLD_STAT_EN,
    input bit [1-1:0] CMD_QUEUE_READY_STAT_EN,
    input bit [1-1:0] RESP_READY_STAT_EN,
    input bit [1-1:0] TRANSFER_ABORT_STAT_EN,
    input bit [1-1:0] TRANSFER_ERR_STAT_EN
    );
        option.per_instance = 1;
        TX_THLD_STAT_EN_cp : coverpoint TX_THLD_STAT_EN;
        RX_THLD_STAT_EN_cp : coverpoint RX_THLD_STAT_EN;
        IBI_STATUS_THLD_STAT_EN_cp : coverpoint IBI_STATUS_THLD_STAT_EN;
        CMD_QUEUE_READY_STAT_EN_cp : coverpoint CMD_QUEUE_READY_STAT_EN;
        RESP_READY_STAT_EN_cp : coverpoint RESP_READY_STAT_EN;
        TRANSFER_ABORT_STAT_EN_cp : coverpoint TRANSFER_ABORT_STAT_EN;
        TRANSFER_ERR_STAT_EN_cp : coverpoint TRANSFER_ERR_STAT_EN;

    endgroup

    /*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_SIGNAL_ENABLE COVERGROUPS -----------------------*/
    covergroup I3CCSR__PIOControl__PIO_INTR_SIGNAL_ENABLE_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__PIOControl__PIO_INTR_SIGNAL_ENABLE_fld_cg with function sample(
    input bit [1-1:0] TX_THLD_SIGNAL_EN,
    input bit [1-1:0] RX_THLD_SIGNAL_EN,
    input bit [1-1:0] IBI_STATUS_THLD_SIGNAL_EN,
    input bit [1-1:0] CMD_QUEUE_READY_SIGNAL_EN,
    input bit [1-1:0] RESP_READY_SIGNAL_EN,
    input bit [1-1:0] TRANSFER_ABORT_SIGNAL_EN,
    input bit [1-1:0] TRANSFER_ERR_SIGNAL_EN
    );
        option.per_instance = 1;
        TX_THLD_SIGNAL_EN_cp : coverpoint TX_THLD_SIGNAL_EN;
        RX_THLD_SIGNAL_EN_cp : coverpoint RX_THLD_SIGNAL_EN;
        IBI_STATUS_THLD_SIGNAL_EN_cp : coverpoint IBI_STATUS_THLD_SIGNAL_EN;
        CMD_QUEUE_READY_SIGNAL_EN_cp : coverpoint CMD_QUEUE_READY_SIGNAL_EN;
        RESP_READY_SIGNAL_EN_cp : coverpoint RESP_READY_SIGNAL_EN;
        TRANSFER_ABORT_SIGNAL_EN_cp : coverpoint TRANSFER_ABORT_SIGNAL_EN;
        TRANSFER_ERR_SIGNAL_EN_cp : coverpoint TRANSFER_ERR_SIGNAL_EN;

    endgroup

    /*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_FORCE COVERGROUPS -----------------------*/
    covergroup I3CCSR__PIOControl__PIO_INTR_FORCE_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__PIOControl__PIO_INTR_FORCE_fld_cg with function sample(
    input bit [1-1:0] TX_THLD_FORCE,
    input bit [1-1:0] RX_THLD_FORCE,
    input bit [1-1:0] IBI_THLD_FORCE,
    input bit [1-1:0] CMD_QUEUE_READY_FORCE,
    input bit [1-1:0] RESP_READY_FORCE,
    input bit [1-1:0] TRANSFER_ABORT_FORCE,
    input bit [1-1:0] TRANSFER_ERR_FORCE
    );
        option.per_instance = 1;
        TX_THLD_FORCE_cp : coverpoint TX_THLD_FORCE;
        RX_THLD_FORCE_cp : coverpoint RX_THLD_FORCE;
        IBI_THLD_FORCE_cp : coverpoint IBI_THLD_FORCE;
        CMD_QUEUE_READY_FORCE_cp : coverpoint CMD_QUEUE_READY_FORCE;
        RESP_READY_FORCE_cp : coverpoint RESP_READY_FORCE;
        TRANSFER_ABORT_FORCE_cp : coverpoint TRANSFER_ABORT_FORCE;
        TRANSFER_ERR_FORCE_cp : coverpoint TRANSFER_ERR_FORCE;

    endgroup

    /*----------------------- I3CCSR__PIOCONTROL__PIO_CONTROL COVERGROUPS -----------------------*/
    covergroup I3CCSR__PIOControl__PIO_CONTROL_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__PIOControl__PIO_CONTROL_fld_cg with function sample(
    input bit [1-1:0] ENABLE,
    input bit [1-1:0] RS,
    input bit [1-1:0] ABORT
    );
        option.per_instance = 1;
        ENABLE_cp : coverpoint ENABLE;
        RS_cp : coverpoint RS;
        ABORT_cp : coverpoint ABORT;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__EXTCAP_HEADER COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__EXTCAP_HEADER_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__EXTCAP_HEADER_fld_cg with function sample(
    input bit [8-1:0] CAP_ID,
    input bit [16-1:0] CAP_LENGTH
    );
        option.per_instance = 1;
        CAP_ID_cp : coverpoint CAP_ID;
        CAP_LENGTH_cp : coverpoint CAP_LENGTH;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__PROT_CAP_0 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_0_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_0_fld_cg with function sample(
    input bit [32-1:0] REC_MAGIC_STRING_0
    );
        option.per_instance = 1;
        REC_MAGIC_STRING_0_cp : coverpoint REC_MAGIC_STRING_0;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__PROT_CAP_1 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_1_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_1_fld_cg with function sample(
    input bit [32-1:0] REC_MAGIC_STRING_1
    );
        option.per_instance = 1;
        REC_MAGIC_STRING_1_cp : coverpoint REC_MAGIC_STRING_1;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__PROT_CAP_2 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_2_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_2_fld_cg with function sample(
    input bit [16-1:0] REC_PROT_VERSION,
    input bit [16-1:0] AGENT_CAPS
    );
        option.per_instance = 1;
        REC_PROT_VERSION_cp : coverpoint REC_PROT_VERSION;
        AGENT_CAPS_cp : coverpoint AGENT_CAPS;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__PROT_CAP_3 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_3_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_3_fld_cg with function sample(
    input bit [8-1:0] NUM_OF_CMS_REGIONS,
    input bit [8-1:0] MAX_RESP_TIME,
    input bit [8-1:0] HEARTBEAT_PERIOD
    );
        option.per_instance = 1;
        NUM_OF_CMS_REGIONS_cp : coverpoint NUM_OF_CMS_REGIONS;
        MAX_RESP_TIME_cp : coverpoint MAX_RESP_TIME;
        HEARTBEAT_PERIOD_cp : coverpoint HEARTBEAT_PERIOD;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_ID_0 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_0_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_0_fld_cg with function sample(
    input bit [8-1:0] DESC_TYPE,
    input bit [8-1:0] VENDOR_SPECIFIC_STR_LENGTH,
    input bit [16-1:0] DATA
    );
        option.per_instance = 1;
        DESC_TYPE_cp : coverpoint DESC_TYPE;
        VENDOR_SPECIFIC_STR_LENGTH_cp : coverpoint VENDOR_SPECIFIC_STR_LENGTH;
        DATA_cp : coverpoint DATA;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_ID_1 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_1_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_1_fld_cg with function sample(
    input bit [32-1:0] DATA
    );
        option.per_instance = 1;
        DATA_cp : coverpoint DATA;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_ID_2 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_2_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_2_fld_cg with function sample(
    input bit [32-1:0] DATA
    );
        option.per_instance = 1;
        DATA_cp : coverpoint DATA;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_ID_3 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_3_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_3_fld_cg with function sample(
    input bit [32-1:0] DATA
    );
        option.per_instance = 1;
        DATA_cp : coverpoint DATA;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_ID_4 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_4_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_4_fld_cg with function sample(
    input bit [32-1:0] DATA
    );
        option.per_instance = 1;
        DATA_cp : coverpoint DATA;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_ID_5 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_5_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_5_fld_cg with function sample(
    input bit [32-1:0] DATA
    );
        option.per_instance = 1;
        DATA_cp : coverpoint DATA;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_ID_6 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_6_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_6_fld_cg with function sample(
    input bit [32-1:0] DATA
    );
        option.per_instance = 1;
        DATA_cp : coverpoint DATA;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_STATUS_0 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_STATUS_0_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_STATUS_0_fld_cg with function sample(
    input bit [8-1:0] DEV_STATUS,
    input bit [8-1:0] PROT_ERROR,
    input bit [16-1:0] REC_REASON_CODE
    );
        option.per_instance = 1;
        DEV_STATUS_cp : coverpoint DEV_STATUS;
        PROT_ERROR_cp : coverpoint PROT_ERROR;
        REC_REASON_CODE_cp : coverpoint REC_REASON_CODE;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_STATUS_1 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_STATUS_1_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_STATUS_1_fld_cg with function sample(
    input bit [16-1:0] HEARTBEAT,
    input bit [9-1:0] VENDOR_STATUS_LENGTH,
    input bit [7-1:0] VENDOR_STATUS
    );
        option.per_instance = 1;
        HEARTBEAT_cp : coverpoint HEARTBEAT;
        VENDOR_STATUS_LENGTH_cp : coverpoint VENDOR_STATUS_LENGTH;
        VENDOR_STATUS_cp : coverpoint VENDOR_STATUS;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_RESET COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_RESET_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_RESET_fld_cg with function sample(
    input bit [8-1:0] RESET_CTRL,
    input bit [8-1:0] FORCED_RECOVERY,
    input bit [8-1:0] IF_CTRL
    );
        option.per_instance = 1;
        RESET_CTRL_cp : coverpoint RESET_CTRL;
        FORCED_RECOVERY_cp : coverpoint FORCED_RECOVERY;
        IF_CTRL_cp : coverpoint IF_CTRL;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__RECOVERY_CTRL COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__RECOVERY_CTRL_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__RECOVERY_CTRL_fld_cg with function sample(
    input bit [8-1:0] CMS,
    input bit [8-1:0] REC_IMG_SEL,
    input bit [8-1:0] ACTIVATE_REC_IMG
    );
        option.per_instance = 1;
        CMS_cp : coverpoint CMS;
        REC_IMG_SEL_cp : coverpoint REC_IMG_SEL;
        ACTIVATE_REC_IMG_cp : coverpoint ACTIVATE_REC_IMG;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__RECOVERY_STATUS COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__RECOVERY_STATUS_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__RECOVERY_STATUS_fld_cg with function sample(
    input bit [4-1:0] DEV_REC_STATUS,
    input bit [4-1:0] REC_IMG_INDEX,
    input bit [8-1:0] VENDOR_SPECIFIC_STATUS
    );
        option.per_instance = 1;
        DEV_REC_STATUS_cp : coverpoint DEV_REC_STATUS;
        REC_IMG_INDEX_cp : coverpoint REC_IMG_INDEX;
        VENDOR_SPECIFIC_STATUS_cp : coverpoint VENDOR_SPECIFIC_STATUS;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__HW_STATUS COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__HW_STATUS_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__HW_STATUS_fld_cg with function sample(
    input bit [1-1:0] TEMP_CRITICAL,
    input bit [1-1:0] SOFT_ERR,
    input bit [1-1:0] FATAL_ERR,
    input bit [5-1:0] RESERVED_7_3,
    input bit [8-1:0] VENDOR_HW_STATUS,
    input bit [8-1:0] CTEMP,
    input bit [8-1:0] VENDOR_HW_STATUS_LEN
    );
        option.per_instance = 1;
        TEMP_CRITICAL_cp : coverpoint TEMP_CRITICAL;
        SOFT_ERR_cp : coverpoint SOFT_ERR;
        FATAL_ERR_cp : coverpoint FATAL_ERR;
        RESERVED_7_3_cp : coverpoint RESERVED_7_3;
        VENDOR_HW_STATUS_cp : coverpoint VENDOR_HW_STATUS;
        CTEMP_cp : coverpoint CTEMP;
        VENDOR_HW_STATUS_LEN_cp : coverpoint VENDOR_HW_STATUS_LEN;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_CTRL_0 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_CTRL_0_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_CTRL_0_fld_cg with function sample(
    input bit [8-1:0] CMS,
    input bit [8-1:0] RESET,
    input bit [16-1:0] IMAGE_SIZE_MSB
    );
        option.per_instance = 1;
        CMS_cp : coverpoint CMS;
        RESET_cp : coverpoint RESET;
        IMAGE_SIZE_MSB_cp : coverpoint IMAGE_SIZE_MSB;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_CTRL_1 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_CTRL_1_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_CTRL_1_fld_cg with function sample(
    input bit [16-1:0] IMAGE_SIZE_LSB
    );
        option.per_instance = 1;
        IMAGE_SIZE_LSB_cp : coverpoint IMAGE_SIZE_LSB;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_STATUS_0 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_0_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_0_fld_cg with function sample(
    input bit [1-1:0] EMPTY,
    input bit [1-1:0] FULL,
    input bit [3-1:0] REGION_TYPE
    );
        option.per_instance = 1;
        EMPTY_cp : coverpoint EMPTY;
        FULL_cp : coverpoint FULL;
        REGION_TYPE_cp : coverpoint REGION_TYPE;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_STATUS_1 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_1_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_1_fld_cg with function sample(
    input bit [32-1:0] WRITE_INDEX
    );
        option.per_instance = 1;
        WRITE_INDEX_cp : coverpoint WRITE_INDEX;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_STATUS_2 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_2_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_2_fld_cg with function sample(
    input bit [32-1:0] READ_INDEX
    );
        option.per_instance = 1;
        READ_INDEX_cp : coverpoint READ_INDEX;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_STATUS_3 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_3_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_3_fld_cg with function sample(
    input bit [32-1:0] FIFO_SIZE
    );
        option.per_instance = 1;
        FIFO_SIZE_cp : coverpoint FIFO_SIZE;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_STATUS_4 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_4_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_4_fld_cg with function sample(
    input bit [32-1:0] MAX_TRANSFER_SIZE
    );
        option.per_instance = 1;
        MAX_TRANSFER_SIZE_cp : coverpoint MAX_TRANSFER_SIZE;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_RESERVED COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_RESERVED_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_RESERVED_fld_cg with function sample(
    input bit [32-1:0] DATA
    );
        option.per_instance = 1;
        DATA_cp : coverpoint DATA;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_DATA COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_DATA_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_DATA_fld_cg with function sample(
    input bit [32-1:0] DATA
    );
        option.per_instance = 1;
        DATA_cp : coverpoint DATA;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__EXTCAP_HEADER COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__EXTCAP_HEADER_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__EXTCAP_HEADER_fld_cg with function sample(
    input bit [8-1:0] CAP_ID,
    input bit [16-1:0] CAP_LENGTH
    );
        option.per_instance = 1;
        CAP_ID_cp : coverpoint CAP_ID;
        CAP_LENGTH_cp : coverpoint CAP_LENGTH;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_CONTROL COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CONTROL_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CONTROL_fld_cg with function sample(
    input bit [1-1:0] PENDING_RX_NACK,
    input bit [1-1:0] HANDOFF_DELAY_NACK,
    input bit [1-1:0] ACR_FSM_OP_SELECT,
    input bit [1-1:0] PRIME_ACCEPT_GETACCCR,
    input bit [1-1:0] HANDOFF_DEEP_SLEEP,
    input bit [1-1:0] CR_REQUEST_SEND,
    input bit [3-1:0] BAST_CCC_IBI_RING,
    input bit [1-1:0] TARGET_XACT_ENABLE,
    input bit [1-1:0] DAA_SETAASA_ENABLE,
    input bit [1-1:0] DAA_SETDASA_ENABLE,
    input bit [1-1:0] DAA_ENTDAA_ENABLE,
    input bit [1-1:0] RSTACT_DEFBYTE_02,
    input bit [2-1:0] STBY_CR_ENABLE_INIT
    );
        option.per_instance = 1;
        PENDING_RX_NACK_cp : coverpoint PENDING_RX_NACK;
        HANDOFF_DELAY_NACK_cp : coverpoint HANDOFF_DELAY_NACK;
        ACR_FSM_OP_SELECT_cp : coverpoint ACR_FSM_OP_SELECT;
        PRIME_ACCEPT_GETACCCR_cp : coverpoint PRIME_ACCEPT_GETACCCR;
        HANDOFF_DEEP_SLEEP_cp : coverpoint HANDOFF_DEEP_SLEEP;
        CR_REQUEST_SEND_cp : coverpoint CR_REQUEST_SEND;
        BAST_CCC_IBI_RING_cp : coverpoint BAST_CCC_IBI_RING;
        TARGET_XACT_ENABLE_cp : coverpoint TARGET_XACT_ENABLE;
        DAA_SETAASA_ENABLE_cp : coverpoint DAA_SETAASA_ENABLE;
        DAA_SETDASA_ENABLE_cp : coverpoint DAA_SETDASA_ENABLE;
        DAA_ENTDAA_ENABLE_cp : coverpoint DAA_ENTDAA_ENABLE;
        RSTACT_DEFBYTE_02_cp : coverpoint RSTACT_DEFBYTE_02;
        STBY_CR_ENABLE_INIT_cp : coverpoint STBY_CR_ENABLE_INIT;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_DEVICE_ADDR COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_DEVICE_ADDR_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_DEVICE_ADDR_fld_cg with function sample(
    input bit [7-1:0] STATIC_ADDR,
    input bit [1-1:0] STATIC_ADDR_VALID,
    input bit [7-1:0] DYNAMIC_ADDR,
    input bit [1-1:0] DYNAMIC_ADDR_VALID
    );
        option.per_instance = 1;
        STATIC_ADDR_cp : coverpoint STATIC_ADDR;
        STATIC_ADDR_VALID_cp : coverpoint STATIC_ADDR_VALID;
        DYNAMIC_ADDR_cp : coverpoint DYNAMIC_ADDR;
        DYNAMIC_ADDR_VALID_cp : coverpoint DYNAMIC_ADDR_VALID;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_CAPABILITIES COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CAPABILITIES_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CAPABILITIES_fld_cg with function sample(
    input bit [1-1:0] SIMPLE_CRR_SUPPORT,
    input bit [1-1:0] TARGET_XACT_SUPPORT,
    input bit [1-1:0] DAA_SETAASA_SUPPORT,
    input bit [1-1:0] DAA_SETDASA_SUPPORT,
    input bit [1-1:0] DAA_ENTDAA_SUPPORT
    );
        option.per_instance = 1;
        SIMPLE_CRR_SUPPORT_cp : coverpoint SIMPLE_CRR_SUPPORT;
        TARGET_XACT_SUPPORT_cp : coverpoint TARGET_XACT_SUPPORT;
        DAA_SETAASA_SUPPORT_cp : coverpoint DAA_SETAASA_SUPPORT;
        DAA_SETDASA_SUPPORT_cp : coverpoint DAA_SETDASA_SUPPORT;
        DAA_ENTDAA_SUPPORT_cp : coverpoint DAA_ENTDAA_SUPPORT;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE____RSVD_0 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode____rsvd_0_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode____rsvd_0_fld_cg with function sample(
    input bit [32-1:0] __rsvd
    );
        option.per_instance = 1;
        __rsvd_cp : coverpoint __rsvd;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_STATUS COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_STATUS_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_STATUS_fld_cg with function sample(
    input bit [1-1:0] AC_CURRENT_OWN,
    input bit [3-1:0] SIMPLE_CRR_STATUS,
    input bit [1-1:0] HJ_REQ_STATUS
    );
        option.per_instance = 1;
        AC_CURRENT_OWN_cp : coverpoint AC_CURRENT_OWN;
        SIMPLE_CRR_STATUS_cp : coverpoint SIMPLE_CRR_STATUS;
        HJ_REQ_STATUS_cp : coverpoint HJ_REQ_STATUS;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_DEVICE_CHAR COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_DEVICE_CHAR_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_DEVICE_CHAR_fld_cg with function sample(
    input bit [15-1:0] PID_HI,
    input bit [8-1:0] DCR,
    input bit [5-1:0] BCR_VAR,
    input bit [3-1:0] BCR_FIXED
    );
        option.per_instance = 1;
        PID_HI_cp : coverpoint PID_HI;
        DCR_cp : coverpoint DCR;
        BCR_VAR_cp : coverpoint BCR_VAR;
        BCR_FIXED_cp : coverpoint BCR_FIXED;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_DEVICE_PID_LO COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_DEVICE_PID_LO_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_DEVICE_PID_LO_fld_cg with function sample(
    input bit [32-1:0] PID_LO
    );
        option.per_instance = 1;
        PID_LO_cp : coverpoint PID_LO;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_INTR_STATUS COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_INTR_STATUS_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_INTR_STATUS_fld_cg with function sample(
    input bit [1-1:0] ACR_HANDOFF_OK_REMAIN_STAT,
    input bit [1-1:0] ACR_HANDOFF_OK_PRIMED_STAT,
    input bit [1-1:0] ACR_HANDOFF_ERR_FAIL_STAT,
    input bit [1-1:0] ACR_HANDOFF_ERR_M3_STAT,
    input bit [1-1:0] CRR_RESPONSE_STAT,
    input bit [1-1:0] STBY_CR_DYN_ADDR_STAT,
    input bit [1-1:0] STBY_CR_ACCEPT_NACKED_STAT,
    input bit [1-1:0] STBY_CR_ACCEPT_OK_STAT,
    input bit [1-1:0] STBY_CR_ACCEPT_ERR_STAT,
    input bit [1-1:0] STBY_CR_OP_RSTACT_STAT,
    input bit [1-1:0] CCC_PARAM_MODIFIED_STAT,
    input bit [1-1:0] CCC_UNHANDLED_NACK_STAT,
    input bit [1-1:0] CCC_FATAL_RSTDAA_ERR_STAT
    );
        option.per_instance = 1;
        ACR_HANDOFF_OK_REMAIN_STAT_cp : coverpoint ACR_HANDOFF_OK_REMAIN_STAT;
        ACR_HANDOFF_OK_PRIMED_STAT_cp : coverpoint ACR_HANDOFF_OK_PRIMED_STAT;
        ACR_HANDOFF_ERR_FAIL_STAT_cp : coverpoint ACR_HANDOFF_ERR_FAIL_STAT;
        ACR_HANDOFF_ERR_M3_STAT_cp : coverpoint ACR_HANDOFF_ERR_M3_STAT;
        CRR_RESPONSE_STAT_cp : coverpoint CRR_RESPONSE_STAT;
        STBY_CR_DYN_ADDR_STAT_cp : coverpoint STBY_CR_DYN_ADDR_STAT;
        STBY_CR_ACCEPT_NACKED_STAT_cp : coverpoint STBY_CR_ACCEPT_NACKED_STAT;
        STBY_CR_ACCEPT_OK_STAT_cp : coverpoint STBY_CR_ACCEPT_OK_STAT;
        STBY_CR_ACCEPT_ERR_STAT_cp : coverpoint STBY_CR_ACCEPT_ERR_STAT;
        STBY_CR_OP_RSTACT_STAT_cp : coverpoint STBY_CR_OP_RSTACT_STAT;
        CCC_PARAM_MODIFIED_STAT_cp : coverpoint CCC_PARAM_MODIFIED_STAT;
        CCC_UNHANDLED_NACK_STAT_cp : coverpoint CCC_UNHANDLED_NACK_STAT;
        CCC_FATAL_RSTDAA_ERR_STAT_cp : coverpoint CCC_FATAL_RSTDAA_ERR_STAT;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE____RSVD_1 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode____rsvd_1_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode____rsvd_1_fld_cg with function sample(
    input bit [32-1:0] __rsvd
    );
        option.per_instance = 1;
        __rsvd_cp : coverpoint __rsvd;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_INTR_SIGNAL_ENABLE COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_INTR_SIGNAL_ENABLE_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_INTR_SIGNAL_ENABLE_fld_cg with function sample(
    input bit [1-1:0] ACR_HANDOFF_OK_REMAIN_SIGNAL_EN,
    input bit [1-1:0] ACR_HANDOFF_OK_PRIMED_SIGNAL_EN,
    input bit [1-1:0] ACR_HANDOFF_ERR_FAIL_SIGNAL_EN,
    input bit [1-1:0] ACR_HANDOFF_ERR_M3_SIGNAL_EN,
    input bit [1-1:0] CRR_RESPONSE_SIGNAL_EN,
    input bit [1-1:0] STBY_CR_DYN_ADDR_SIGNAL_EN,
    input bit [1-1:0] STBY_CR_ACCEPT_NACKED_SIGNAL_EN,
    input bit [1-1:0] STBY_CR_ACCEPT_OK_SIGNAL_EN,
    input bit [1-1:0] STBY_CR_ACCEPT_ERR_SIGNAL_EN,
    input bit [1-1:0] STBY_CR_OP_RSTACT_SIGNAL_EN,
    input bit [1-1:0] CCC_PARAM_MODIFIED_SIGNAL_EN,
    input bit [1-1:0] CCC_UNHANDLED_NACK_SIGNAL_EN,
    input bit [1-1:0] CCC_FATAL_RSTDAA_ERR_SIGNAL_EN
    );
        option.per_instance = 1;
        ACR_HANDOFF_OK_REMAIN_SIGNAL_EN_cp : coverpoint ACR_HANDOFF_OK_REMAIN_SIGNAL_EN;
        ACR_HANDOFF_OK_PRIMED_SIGNAL_EN_cp : coverpoint ACR_HANDOFF_OK_PRIMED_SIGNAL_EN;
        ACR_HANDOFF_ERR_FAIL_SIGNAL_EN_cp : coverpoint ACR_HANDOFF_ERR_FAIL_SIGNAL_EN;
        ACR_HANDOFF_ERR_M3_SIGNAL_EN_cp : coverpoint ACR_HANDOFF_ERR_M3_SIGNAL_EN;
        CRR_RESPONSE_SIGNAL_EN_cp : coverpoint CRR_RESPONSE_SIGNAL_EN;
        STBY_CR_DYN_ADDR_SIGNAL_EN_cp : coverpoint STBY_CR_DYN_ADDR_SIGNAL_EN;
        STBY_CR_ACCEPT_NACKED_SIGNAL_EN_cp : coverpoint STBY_CR_ACCEPT_NACKED_SIGNAL_EN;
        STBY_CR_ACCEPT_OK_SIGNAL_EN_cp : coverpoint STBY_CR_ACCEPT_OK_SIGNAL_EN;
        STBY_CR_ACCEPT_ERR_SIGNAL_EN_cp : coverpoint STBY_CR_ACCEPT_ERR_SIGNAL_EN;
        STBY_CR_OP_RSTACT_SIGNAL_EN_cp : coverpoint STBY_CR_OP_RSTACT_SIGNAL_EN;
        CCC_PARAM_MODIFIED_SIGNAL_EN_cp : coverpoint CCC_PARAM_MODIFIED_SIGNAL_EN;
        CCC_UNHANDLED_NACK_SIGNAL_EN_cp : coverpoint CCC_UNHANDLED_NACK_SIGNAL_EN;
        CCC_FATAL_RSTDAA_ERR_SIGNAL_EN_cp : coverpoint CCC_FATAL_RSTDAA_ERR_SIGNAL_EN;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_INTR_FORCE COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_INTR_FORCE_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_INTR_FORCE_fld_cg with function sample(
    input bit [1-1:0] CRR_RESPONSE_FORCE,
    input bit [1-1:0] STBY_CR_DYN_ADDR_FORCE,
    input bit [1-1:0] STBY_CR_ACCEPT_NACKED_FORCE,
    input bit [1-1:0] STBY_CR_ACCEPT_OK_FORCE,
    input bit [1-1:0] STBY_CR_ACCEPT_ERR_FORCE,
    input bit [1-1:0] STBY_CR_OP_RSTACT_FORCE,
    input bit [1-1:0] CCC_PARAM_MODIFIED_FORCE,
    input bit [1-1:0] CCC_UNHANDLED_NACK_FORCE,
    input bit [1-1:0] CCC_FATAL_RSTDAA_ERR_FORCE
    );
        option.per_instance = 1;
        CRR_RESPONSE_FORCE_cp : coverpoint CRR_RESPONSE_FORCE;
        STBY_CR_DYN_ADDR_FORCE_cp : coverpoint STBY_CR_DYN_ADDR_FORCE;
        STBY_CR_ACCEPT_NACKED_FORCE_cp : coverpoint STBY_CR_ACCEPT_NACKED_FORCE;
        STBY_CR_ACCEPT_OK_FORCE_cp : coverpoint STBY_CR_ACCEPT_OK_FORCE;
        STBY_CR_ACCEPT_ERR_FORCE_cp : coverpoint STBY_CR_ACCEPT_ERR_FORCE;
        STBY_CR_OP_RSTACT_FORCE_cp : coverpoint STBY_CR_OP_RSTACT_FORCE;
        CCC_PARAM_MODIFIED_FORCE_cp : coverpoint CCC_PARAM_MODIFIED_FORCE;
        CCC_UNHANDLED_NACK_FORCE_cp : coverpoint CCC_UNHANDLED_NACK_FORCE;
        CCC_FATAL_RSTDAA_ERR_FORCE_cp : coverpoint CCC_FATAL_RSTDAA_ERR_FORCE;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_CCC_CONFIG_GETCAPS COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CCC_CONFIG_GETCAPS_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CCC_CONFIG_GETCAPS_fld_cg with function sample(
    input bit [3-1:0] F2_CRCAP1_BUS_CONFIG,
    input bit [4-1:0] F2_CRCAP2_DEV_INTERACT
    );
        option.per_instance = 1;
        F2_CRCAP1_BUS_CONFIG_cp : coverpoint F2_CRCAP1_BUS_CONFIG;
        F2_CRCAP2_DEV_INTERACT_cp : coverpoint F2_CRCAP2_DEV_INTERACT;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_CCC_CONFIG_RSTACT_PARAMS COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CCC_CONFIG_RSTACT_PARAMS_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CCC_CONFIG_RSTACT_PARAMS_fld_cg with function sample(
    input bit [8-1:0] RST_ACTION,
    input bit [8-1:0] RESET_TIME_PERIPHERAL,
    input bit [8-1:0] RESET_TIME_TARGET,
    input bit [1-1:0] RESET_DYNAMIC_ADDR
    );
        option.per_instance = 1;
        RST_ACTION_cp : coverpoint RST_ACTION;
        RESET_TIME_PERIPHERAL_cp : coverpoint RESET_TIME_PERIPHERAL;
        RESET_TIME_TARGET_cp : coverpoint RESET_TIME_TARGET;
        RESET_DYNAMIC_ADDR_cp : coverpoint RESET_DYNAMIC_ADDR;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_VIRT_DEVICE_ADDR COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_VIRT_DEVICE_ADDR_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_VIRT_DEVICE_ADDR_fld_cg with function sample(
    input bit [7-1:0] VIRT_STATIC_ADDR,
    input bit [1-1:0] VIRT_STATIC_ADDR_VALID,
    input bit [7-1:0] VIRT_DYNAMIC_ADDR,
    input bit [1-1:0] VIRT_DYNAMIC_ADDR_VALID
    );
        option.per_instance = 1;
        VIRT_STATIC_ADDR_cp : coverpoint VIRT_STATIC_ADDR;
        VIRT_STATIC_ADDR_VALID_cp : coverpoint VIRT_STATIC_ADDR_VALID;
        VIRT_DYNAMIC_ADDR_cp : coverpoint VIRT_DYNAMIC_ADDR;
        VIRT_DYNAMIC_ADDR_VALID_cp : coverpoint VIRT_DYNAMIC_ADDR_VALID;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE____RSVD_3 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode____rsvd_3_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__StdbyCtrlMode____rsvd_3_fld_cg with function sample(
    input bit [32-1:0] __rsvd
    );
        option.per_instance = 1;
        __rsvd_cp : coverpoint __rsvd;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__EXTCAP_HEADER COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__EXTCAP_HEADER_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__EXTCAP_HEADER_fld_cg with function sample(
    input bit [8-1:0] CAP_ID,
    input bit [16-1:0] CAP_LENGTH
    );
        option.per_instance = 1;
        CAP_ID_cp : coverpoint CAP_ID;
        CAP_LENGTH_cp : coverpoint CAP_LENGTH;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__CONTROL COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__CONTROL_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__CONTROL_fld_cg with function sample(
    input bit [1-1:0] HJ_EN,
    input bit [1-1:0] CRR_EN,
    input bit [1-1:0] IBI_EN,
    input bit [3-1:0] IBI_RETRY_NUM
    );
        option.per_instance = 1;
        HJ_EN_cp : coverpoint HJ_EN;
        CRR_EN_cp : coverpoint CRR_EN;
        IBI_EN_cp : coverpoint IBI_EN;
        IBI_RETRY_NUM_cp : coverpoint IBI_RETRY_NUM;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__STATUS COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__STATUS_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__STATUS_fld_cg with function sample(
    input bit [1-1:0] PROTOCOL_ERROR,
    input bit [2-1:0] LAST_IBI_STATUS
    );
        option.per_instance = 1;
        PROTOCOL_ERROR_cp : coverpoint PROTOCOL_ERROR;
        LAST_IBI_STATUS_cp : coverpoint LAST_IBI_STATUS;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__RESET_CONTROL COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__RESET_CONTROL_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__RESET_CONTROL_fld_cg with function sample(
    input bit [1-1:0] SOFT_RST,
    input bit [1-1:0] TX_DESC_RST,
    input bit [1-1:0] RX_DESC_RST,
    input bit [1-1:0] TX_DATA_RST,
    input bit [1-1:0] RX_DATA_RST,
    input bit [1-1:0] IBI_QUEUE_RST
    );
        option.per_instance = 1;
        SOFT_RST_cp : coverpoint SOFT_RST;
        TX_DESC_RST_cp : coverpoint TX_DESC_RST;
        RX_DESC_RST_cp : coverpoint RX_DESC_RST;
        TX_DATA_RST_cp : coverpoint TX_DATA_RST;
        RX_DATA_RST_cp : coverpoint RX_DATA_RST;
        IBI_QUEUE_RST_cp : coverpoint IBI_QUEUE_RST;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__INTERRUPT_STATUS COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__INTERRUPT_STATUS_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__INTERRUPT_STATUS_fld_cg with function sample(
    input bit [1-1:0] RX_DESC_STAT,
    input bit [1-1:0] TX_DESC_STAT,
    input bit [1-1:0] RX_DESC_TIMEOUT,
    input bit [1-1:0] TX_DESC_TIMEOUT,
    input bit [1-1:0] TX_DATA_THLD_STAT,
    input bit [1-1:0] RX_DATA_THLD_STAT,
    input bit [1-1:0] TX_DESC_THLD_STAT,
    input bit [1-1:0] RX_DESC_THLD_STAT,
    input bit [1-1:0] IBI_THLD_STAT,
    input bit [1-1:0] IBI_DONE,
    input bit [4-1:0] PENDING_INTERRUPT,
    input bit [1-1:0] TRANSFER_ABORT_STAT,
    input bit [1-1:0] TRANSFER_ERR_STAT
    );
        option.per_instance = 1;
        RX_DESC_STAT_cp : coverpoint RX_DESC_STAT;
        TX_DESC_STAT_cp : coverpoint TX_DESC_STAT;
        RX_DESC_TIMEOUT_cp : coverpoint RX_DESC_TIMEOUT;
        TX_DESC_TIMEOUT_cp : coverpoint TX_DESC_TIMEOUT;
        TX_DATA_THLD_STAT_cp : coverpoint TX_DATA_THLD_STAT;
        RX_DATA_THLD_STAT_cp : coverpoint RX_DATA_THLD_STAT;
        TX_DESC_THLD_STAT_cp : coverpoint TX_DESC_THLD_STAT;
        RX_DESC_THLD_STAT_cp : coverpoint RX_DESC_THLD_STAT;
        IBI_THLD_STAT_cp : coverpoint IBI_THLD_STAT;
        IBI_DONE_cp : coverpoint IBI_DONE;
        PENDING_INTERRUPT_cp : coverpoint PENDING_INTERRUPT;
        TRANSFER_ABORT_STAT_cp : coverpoint TRANSFER_ABORT_STAT;
        TRANSFER_ERR_STAT_cp : coverpoint TRANSFER_ERR_STAT;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__INTERRUPT_ENABLE COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__INTERRUPT_ENABLE_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__INTERRUPT_ENABLE_fld_cg with function sample(
    input bit [1-1:0] RX_DESC_STAT_EN,
    input bit [1-1:0] TX_DESC_STAT_EN,
    input bit [1-1:0] RX_DESC_TIMEOUT_EN,
    input bit [1-1:0] TX_DESC_TIMEOUT_EN,
    input bit [1-1:0] TX_DATA_THLD_STAT_EN,
    input bit [1-1:0] RX_DATA_THLD_STAT_EN,
    input bit [1-1:0] TX_DESC_THLD_STAT_EN,
    input bit [1-1:0] RX_DESC_THLD_STAT_EN,
    input bit [1-1:0] IBI_THLD_STAT_EN,
    input bit [1-1:0] IBI_DONE_EN,
    input bit [1-1:0] TRANSFER_ABORT_STAT_EN,
    input bit [1-1:0] TRANSFER_ERR_STAT_EN
    );
        option.per_instance = 1;
        RX_DESC_STAT_EN_cp : coverpoint RX_DESC_STAT_EN;
        TX_DESC_STAT_EN_cp : coverpoint TX_DESC_STAT_EN;
        RX_DESC_TIMEOUT_EN_cp : coverpoint RX_DESC_TIMEOUT_EN;
        TX_DESC_TIMEOUT_EN_cp : coverpoint TX_DESC_TIMEOUT_EN;
        TX_DATA_THLD_STAT_EN_cp : coverpoint TX_DATA_THLD_STAT_EN;
        RX_DATA_THLD_STAT_EN_cp : coverpoint RX_DATA_THLD_STAT_EN;
        TX_DESC_THLD_STAT_EN_cp : coverpoint TX_DESC_THLD_STAT_EN;
        RX_DESC_THLD_STAT_EN_cp : coverpoint RX_DESC_THLD_STAT_EN;
        IBI_THLD_STAT_EN_cp : coverpoint IBI_THLD_STAT_EN;
        IBI_DONE_EN_cp : coverpoint IBI_DONE_EN;
        TRANSFER_ABORT_STAT_EN_cp : coverpoint TRANSFER_ABORT_STAT_EN;
        TRANSFER_ERR_STAT_EN_cp : coverpoint TRANSFER_ERR_STAT_EN;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__INTERRUPT_FORCE COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__INTERRUPT_FORCE_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__INTERRUPT_FORCE_fld_cg with function sample(
    input bit [1-1:0] RX_DESC_STAT_FORCE,
    input bit [1-1:0] TX_DESC_STAT_FORCE,
    input bit [1-1:0] RX_DESC_TIMEOUT_FORCE,
    input bit [1-1:0] TX_DESC_TIMEOUT_FORCE,
    input bit [1-1:0] TX_DATA_THLD_FORCE,
    input bit [1-1:0] RX_DATA_THLD_FORCE,
    input bit [1-1:0] TX_DESC_THLD_FORCE,
    input bit [1-1:0] RX_DESC_THLD_FORCE,
    input bit [1-1:0] IBI_THLD_FORCE,
    input bit [1-1:0] IBI_DONE_FORCE,
    input bit [1-1:0] TRANSFER_ABORT_STAT_FORCE,
    input bit [1-1:0] TRANSFER_ERR_STAT_FORCE
    );
        option.per_instance = 1;
        RX_DESC_STAT_FORCE_cp : coverpoint RX_DESC_STAT_FORCE;
        TX_DESC_STAT_FORCE_cp : coverpoint TX_DESC_STAT_FORCE;
        RX_DESC_TIMEOUT_FORCE_cp : coverpoint RX_DESC_TIMEOUT_FORCE;
        TX_DESC_TIMEOUT_FORCE_cp : coverpoint TX_DESC_TIMEOUT_FORCE;
        TX_DATA_THLD_FORCE_cp : coverpoint TX_DATA_THLD_FORCE;
        RX_DATA_THLD_FORCE_cp : coverpoint RX_DATA_THLD_FORCE;
        TX_DESC_THLD_FORCE_cp : coverpoint TX_DESC_THLD_FORCE;
        RX_DESC_THLD_FORCE_cp : coverpoint RX_DESC_THLD_FORCE;
        IBI_THLD_FORCE_cp : coverpoint IBI_THLD_FORCE;
        IBI_DONE_FORCE_cp : coverpoint IBI_DONE_FORCE;
        TRANSFER_ABORT_STAT_FORCE_cp : coverpoint TRANSFER_ABORT_STAT_FORCE;
        TRANSFER_ERR_STAT_FORCE_cp : coverpoint TRANSFER_ERR_STAT_FORCE;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__RX_DESC_QUEUE_PORT COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__RX_DESC_QUEUE_PORT_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__RX_DESC_QUEUE_PORT_fld_cg with function sample(
    input bit [32-1:0] RX_DESC
    );
        option.per_instance = 1;
        RX_DESC_cp : coverpoint RX_DESC;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__RX_DATA_PORT COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__RX_DATA_PORT_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__RX_DATA_PORT_fld_cg with function sample(
    input bit [32-1:0] RX_DATA
    );
        option.per_instance = 1;
        RX_DATA_cp : coverpoint RX_DATA;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__TX_DESC_QUEUE_PORT COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__TX_DESC_QUEUE_PORT_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__TX_DESC_QUEUE_PORT_fld_cg with function sample(
    input bit [32-1:0] TX_DESC
    );
        option.per_instance = 1;
        TX_DESC_cp : coverpoint TX_DESC;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__TX_DATA_PORT COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__TX_DATA_PORT_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__TX_DATA_PORT_fld_cg with function sample(
    input bit [32-1:0] TX_DATA
    );
        option.per_instance = 1;
        TX_DATA_cp : coverpoint TX_DATA;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__IBI_PORT COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__IBI_PORT_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__IBI_PORT_fld_cg with function sample(
    input bit [32-1:0] IBI_DATA
    );
        option.per_instance = 1;
        IBI_DATA_cp : coverpoint IBI_DATA;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__QUEUE_SIZE COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__QUEUE_SIZE_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__QUEUE_SIZE_fld_cg with function sample(
    input bit [8-1:0] RX_DESC_BUFFER_SIZE,
    input bit [8-1:0] TX_DESC_BUFFER_SIZE,
    input bit [8-1:0] RX_DATA_BUFFER_SIZE,
    input bit [8-1:0] TX_DATA_BUFFER_SIZE
    );
        option.per_instance = 1;
        RX_DESC_BUFFER_SIZE_cp : coverpoint RX_DESC_BUFFER_SIZE;
        TX_DESC_BUFFER_SIZE_cp : coverpoint TX_DESC_BUFFER_SIZE;
        RX_DATA_BUFFER_SIZE_cp : coverpoint RX_DATA_BUFFER_SIZE;
        TX_DATA_BUFFER_SIZE_cp : coverpoint TX_DATA_BUFFER_SIZE;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__IBI_QUEUE_SIZE COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__IBI_QUEUE_SIZE_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__IBI_QUEUE_SIZE_fld_cg with function sample(
    input bit [8-1:0] IBI_QUEUE_SIZE
    );
        option.per_instance = 1;
        IBI_QUEUE_SIZE_cp : coverpoint IBI_QUEUE_SIZE;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__QUEUE_THLD_CTRL COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__QUEUE_THLD_CTRL_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__QUEUE_THLD_CTRL_fld_cg with function sample(
    input bit [8-1:0] TX_DESC_THLD,
    input bit [8-1:0] RX_DESC_THLD,
    input bit [8-1:0] IBI_THLD
    );
        option.per_instance = 1;
        TX_DESC_THLD_cp : coverpoint TX_DESC_THLD;
        RX_DESC_THLD_cp : coverpoint RX_DESC_THLD;
        IBI_THLD_cp : coverpoint IBI_THLD;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TTI__DATA_BUFFER_THLD_CTRL COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TTI__DATA_BUFFER_THLD_CTRL_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TTI__DATA_BUFFER_THLD_CTRL_fld_cg with function sample(
    input bit [3-1:0] TX_DATA_THLD,
    input bit [3-1:0] RX_DATA_THLD,
    input bit [3-1:0] TX_START_THLD,
    input bit [3-1:0] RX_START_THLD
    );
        option.per_instance = 1;
        TX_DATA_THLD_cp : coverpoint TX_DATA_THLD;
        RX_DATA_THLD_cp : coverpoint RX_DATA_THLD;
        TX_START_THLD_cp : coverpoint TX_START_THLD;
        RX_START_THLD_cp : coverpoint RX_START_THLD;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__EXTCAP_HEADER COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__EXTCAP_HEADER_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__EXTCAP_HEADER_fld_cg with function sample(
    input bit [8-1:0] CAP_ID,
    input bit [16-1:0] CAP_LENGTH
    );
        option.per_instance = 1;
        CAP_ID_cp : coverpoint CAP_ID;
        CAP_LENGTH_cp : coverpoint CAP_LENGTH;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_CONTROL COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_CONTROL_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_CONTROL_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
    );
        option.per_instance = 1;
        PLACEHOLDER_cp : coverpoint PLACEHOLDER;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_STATUS COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_STATUS_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_STATUS_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
    );
        option.per_instance = 1;
        PLACEHOLDER_cp : coverpoint PLACEHOLDER;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_RSVD_0 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_0_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_0_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
    );
        option.per_instance = 1;
        PLACEHOLDER_cp : coverpoint PLACEHOLDER;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_RSVD_1 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_1_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_1_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
    );
        option.per_instance = 1;
        PLACEHOLDER_cp : coverpoint PLACEHOLDER;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_RSVD_2 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_2_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_2_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
    );
        option.per_instance = 1;
        PLACEHOLDER_cp : coverpoint PLACEHOLDER;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_RSVD_3 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_3_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_3_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
    );
        option.per_instance = 1;
        PLACEHOLDER_cp : coverpoint PLACEHOLDER;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_PAD_CONF COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_PAD_CONF_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_PAD_CONF_fld_cg with function sample(
    input bit [1-1:0] INPUT_ENABLE,
    input bit [1-1:0] SCHMITT_EN,
    input bit [1-1:0] KEEPER_EN,
    input bit [1-1:0] PULL_DIR,
    input bit [1-1:0] PULL_EN,
    input bit [1-1:0] IO_INVERSION,
    input bit [1-1:0] OD_EN,
    input bit [1-1:0] VIRTUAL_OD_EN,
    input bit [8-1:0] PAD_TYPE
    );
        option.per_instance = 1;
        INPUT_ENABLE_cp : coverpoint INPUT_ENABLE;
        SCHMITT_EN_cp : coverpoint SCHMITT_EN;
        KEEPER_EN_cp : coverpoint KEEPER_EN;
        PULL_DIR_cp : coverpoint PULL_DIR;
        PULL_EN_cp : coverpoint PULL_EN;
        IO_INVERSION_cp : coverpoint IO_INVERSION;
        OD_EN_cp : coverpoint OD_EN;
        VIRTUAL_OD_EN_cp : coverpoint VIRTUAL_OD_EN;
        PAD_TYPE_cp : coverpoint PAD_TYPE;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_PAD_ATTR COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_PAD_ATTR_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_PAD_ATTR_fld_cg with function sample(
    input bit [8-1:0] DRIVE_SLEW_RATE,
    input bit [8-1:0] DRIVE_STRENGTH
    );
        option.per_instance = 1;
        DRIVE_SLEW_RATE_cp : coverpoint DRIVE_SLEW_RATE;
        DRIVE_STRENGTH_cp : coverpoint DRIVE_STRENGTH;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_FEATURE_2 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_FEATURE_2_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_FEATURE_2_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
    );
        option.per_instance = 1;
        PLACEHOLDER_cp : coverpoint PLACEHOLDER;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_FEATURE_3 COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_FEATURE_3_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_FEATURE_3_fld_cg with function sample(
    input bit [32-1:0] PLACEHOLDER
    );
        option.per_instance = 1;
        PLACEHOLDER_cp : coverpoint PLACEHOLDER;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_R_REG COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_R_REG_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_R_REG_fld_cg with function sample(
    input bit [20-1:0] T_R
    );
        option.per_instance = 1;
        T_R_cp : coverpoint T_R;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_F_REG COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_F_REG_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_F_REG_fld_cg with function sample(
    input bit [20-1:0] T_F
    );
        option.per_instance = 1;
        T_F_cp : coverpoint T_F;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_SU_DAT_REG COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_SU_DAT_REG_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_SU_DAT_REG_fld_cg with function sample(
    input bit [20-1:0] T_SU_DAT
    );
        option.per_instance = 1;
        T_SU_DAT_cp : coverpoint T_SU_DAT;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_HD_DAT_REG COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_HD_DAT_REG_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_HD_DAT_REG_fld_cg with function sample(
    input bit [20-1:0] T_HD_DAT
    );
        option.per_instance = 1;
        T_HD_DAT_cp : coverpoint T_HD_DAT;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_HIGH_REG COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_HIGH_REG_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_HIGH_REG_fld_cg with function sample(
    input bit [20-1:0] T_HIGH
    );
        option.per_instance = 1;
        T_HIGH_cp : coverpoint T_HIGH;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_LOW_REG COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_LOW_REG_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_LOW_REG_fld_cg with function sample(
    input bit [20-1:0] T_LOW
    );
        option.per_instance = 1;
        T_LOW_cp : coverpoint T_LOW;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_HD_STA_REG COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_HD_STA_REG_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_HD_STA_REG_fld_cg with function sample(
    input bit [20-1:0] T_HD_STA
    );
        option.per_instance = 1;
        T_HD_STA_cp : coverpoint T_HD_STA;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_SU_STA_REG COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_SU_STA_REG_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_SU_STA_REG_fld_cg with function sample(
    input bit [20-1:0] T_SU_STA
    );
        option.per_instance = 1;
        T_SU_STA_cp : coverpoint T_SU_STA;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_SU_STO_REG COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_SU_STO_REG_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_SU_STO_REG_fld_cg with function sample(
    input bit [20-1:0] T_SU_STO
    );
        option.per_instance = 1;
        T_SU_STO_cp : coverpoint T_SU_STO;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_FREE_REG COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_FREE_REG_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_FREE_REG_fld_cg with function sample(
    input bit [32-1:0] T_FREE
    );
        option.per_instance = 1;
        T_FREE_cp : coverpoint T_FREE;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_AVAL_REG COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_AVAL_REG_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_AVAL_REG_fld_cg with function sample(
    input bit [32-1:0] T_AVAL
    );
        option.per_instance = 1;
        T_AVAL_cp : coverpoint T_AVAL;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_IDLE_REG COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_IDLE_REG_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__SoCMgmtIf__T_IDLE_REG_fld_cg with function sample(
    input bit [32-1:0] T_IDLE
    );
        option.per_instance = 1;
        T_IDLE_cp : coverpoint T_IDLE;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__CTRLCFG__EXTCAP_HEADER COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__CtrlCfg__EXTCAP_HEADER_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__CtrlCfg__EXTCAP_HEADER_fld_cg with function sample(
    input bit [8-1:0] CAP_ID,
    input bit [16-1:0] CAP_LENGTH
    );
        option.per_instance = 1;
        CAP_ID_cp : coverpoint CAP_ID;
        CAP_LENGTH_cp : coverpoint CAP_LENGTH;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__CTRLCFG__CONTROLLER_CONFIG COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__CtrlCfg__CONTROLLER_CONFIG_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__CtrlCfg__CONTROLLER_CONFIG_fld_cg with function sample(
    input bit [2-1:0] OPERATION_MODE
    );
        option.per_instance = 1;
        OPERATION_MODE_cp : coverpoint OPERATION_MODE;

    endgroup

    /*----------------------- I3CCSR__I3C_EC__TERMINATION_EXTCAP_HEADER COVERGROUPS -----------------------*/
    covergroup I3CCSR__I3C_EC__TERMINATION_EXTCAP_HEADER_bit_cg with function sample(input bit reg_bit);
        option.per_instance = 1;
        reg_bit_cp : coverpoint reg_bit {
            bins value[2] = {0,1};
        }
        reg_bit_edge_cp : coverpoint reg_bit {
            bins rise = (0 => 1);
            bins fall = (1 => 0);
        }

    endgroup
    covergroup I3CCSR__I3C_EC__TERMINATION_EXTCAP_HEADER_fld_cg with function sample(
    input bit [8-1:0] CAP_ID,
    input bit [16-1:0] CAP_LENGTH
    );
        option.per_instance = 1;
        CAP_ID_cp : coverpoint CAP_ID;
        CAP_LENGTH_cp : coverpoint CAP_LENGTH;

    endgroup

`endif