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

`ifndef I3CCSR_SAMPLE
`define I3CCSR_SAMPLE

/*----------------------- I3CCSR__I3CBASE__HCI_VERSION SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__HCI_VERSION::sample (uvm_reg_data_t data, uvm_reg_data_t byte_en,
                                                    bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (VERSION_bit_cg[bt]) this.VERSION_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*VERSION*/);
  end
endfunction

function void I3CCSR__I3CBase__HCI_VERSION::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (VERSION_bit_cg[bt]) this.VERSION_bit_cg[bt].sample(VERSION.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(VERSION.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__HC_CONTROL SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__HC_CONTROL::sample (uvm_reg_data_t data, uvm_reg_data_t byte_en,
                                                   bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (IBA_INCLUDE_bit_cg[bt]) this.IBA_INCLUDE_bit_cg[bt].sample(data[0+bt]);
    foreach (AUTOCMD_DATA_RPT_bit_cg[bt]) this.AUTOCMD_DATA_RPT_bit_cg[bt].sample(data[3+bt]);
    foreach (DATA_BYTE_ORDER_MODE_bit_cg[bt])
    this.DATA_BYTE_ORDER_MODE_bit_cg[bt].sample(data[4+bt]);
    foreach (MODE_SELECTOR_bit_cg[bt]) this.MODE_SELECTOR_bit_cg[bt].sample(data[6+bt]);
    foreach (I2C_DEV_PRESENT_bit_cg[bt]) this.I2C_DEV_PRESENT_bit_cg[bt].sample(data[7+bt]);
    foreach (HOT_JOIN_CTRL_bit_cg[bt]) this.HOT_JOIN_CTRL_bit_cg[bt].sample(data[8+bt]);
    foreach (HALT_ON_CMD_SEQ_TIMEOUT_bit_cg[bt])
    this.HALT_ON_CMD_SEQ_TIMEOUT_bit_cg[bt].sample(data[12+bt]);
    foreach (ABORT_bit_cg[bt]) this.ABORT_bit_cg[bt].sample(data[29+bt]);
    foreach (RESUME_bit_cg[bt]) this.RESUME_bit_cg[bt].sample(data[30+bt]);
    foreach (BUS_ENABLE_bit_cg[bt]) this.BUS_ENABLE_bit_cg[bt].sample(data[31+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[0:0]  /*IBA_INCLUDE*/, data[3:3]  /*AUTOCMD_DATA_RPT*/,
                       data[4:4]  /*DATA_BYTE_ORDER_MODE*/, data[6:6]  /*MODE_SELECTOR*/,
                       data[7:7]  /*I2C_DEV_PRESENT*/, data[8:8]  /*HOT_JOIN_CTRL*/,
                       data[12:12]  /*HALT_ON_CMD_SEQ_TIMEOUT*/, data[29:29]  /*ABORT*/,
                       data[30:30]  /*RESUME*/, data[31:31]  /*BUS_ENABLE*/);
  end
endfunction

function void I3CCSR__I3CBase__HC_CONTROL::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (IBA_INCLUDE_bit_cg[bt])
    this.IBA_INCLUDE_bit_cg[bt].sample(IBA_INCLUDE.get_mirrored_value() >> bt);
    foreach (AUTOCMD_DATA_RPT_bit_cg[bt])
    this.AUTOCMD_DATA_RPT_bit_cg[bt].sample(AUTOCMD_DATA_RPT.get_mirrored_value() >> bt);
    foreach (DATA_BYTE_ORDER_MODE_bit_cg[bt])
    this.DATA_BYTE_ORDER_MODE_bit_cg[bt].sample(DATA_BYTE_ORDER_MODE.get_mirrored_value() >> bt);
    foreach (MODE_SELECTOR_bit_cg[bt])
    this.MODE_SELECTOR_bit_cg[bt].sample(MODE_SELECTOR.get_mirrored_value() >> bt);
    foreach (I2C_DEV_PRESENT_bit_cg[bt])
    this.I2C_DEV_PRESENT_bit_cg[bt].sample(I2C_DEV_PRESENT.get_mirrored_value() >> bt);
    foreach (HOT_JOIN_CTRL_bit_cg[bt])
    this.HOT_JOIN_CTRL_bit_cg[bt].sample(HOT_JOIN_CTRL.get_mirrored_value() >> bt);
    foreach (HALT_ON_CMD_SEQ_TIMEOUT_bit_cg[bt])
    this.HALT_ON_CMD_SEQ_TIMEOUT_bit_cg[bt].sample(
        HALT_ON_CMD_SEQ_TIMEOUT.get_mirrored_value() >> bt);
    foreach (ABORT_bit_cg[bt]) this.ABORT_bit_cg[bt].sample(ABORT.get_mirrored_value() >> bt);
    foreach (RESUME_bit_cg[bt]) this.RESUME_bit_cg[bt].sample(RESUME.get_mirrored_value() >> bt);
    foreach (BUS_ENABLE_bit_cg[bt])
    this.BUS_ENABLE_bit_cg[bt].sample(BUS_ENABLE.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(IBA_INCLUDE.get_mirrored_value(), AUTOCMD_DATA_RPT.get_mirrored_value(),
                       DATA_BYTE_ORDER_MODE.get_mirrored_value(),
                       MODE_SELECTOR.get_mirrored_value(), I2C_DEV_PRESENT.get_mirrored_value(),
                       HOT_JOIN_CTRL.get_mirrored_value(),
                       HALT_ON_CMD_SEQ_TIMEOUT.get_mirrored_value(), ABORT.get_mirrored_value(),
                       RESUME.get_mirrored_value(), BUS_ENABLE.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__CONTROLLER_DEVICE_ADDR SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__CONTROLLER_DEVICE_ADDR::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (DYNAMIC_ADDR_bit_cg[bt]) this.DYNAMIC_ADDR_bit_cg[bt].sample(data[16+bt]);
    foreach (DYNAMIC_ADDR_VALID_bit_cg[bt]) this.DYNAMIC_ADDR_VALID_bit_cg[bt].sample(data[31+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[22:16]  /*DYNAMIC_ADDR*/, data[31:31]  /*DYNAMIC_ADDR_VALID*/);
  end
endfunction

function void I3CCSR__I3CBase__CONTROLLER_DEVICE_ADDR::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (DYNAMIC_ADDR_bit_cg[bt])
    this.DYNAMIC_ADDR_bit_cg[bt].sample(DYNAMIC_ADDR.get_mirrored_value() >> bt);
    foreach (DYNAMIC_ADDR_VALID_bit_cg[bt])
    this.DYNAMIC_ADDR_VALID_bit_cg[bt].sample(DYNAMIC_ADDR_VALID.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(DYNAMIC_ADDR.get_mirrored_value(), DYNAMIC_ADDR_VALID.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__HC_CAPABILITIES SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__HC_CAPABILITIES::sample (uvm_reg_data_t data, uvm_reg_data_t byte_en,
                                                        bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (COMBO_COMMAND_bit_cg[bt]) this.COMBO_COMMAND_bit_cg[bt].sample(data[2+bt]);
    foreach (AUTO_COMMAND_bit_cg[bt]) this.AUTO_COMMAND_bit_cg[bt].sample(data[3+bt]);
    foreach (STANDBY_CR_CAP_bit_cg[bt]) this.STANDBY_CR_CAP_bit_cg[bt].sample(data[5+bt]);
    foreach (HDR_DDR_EN_bit_cg[bt]) this.HDR_DDR_EN_bit_cg[bt].sample(data[6+bt]);
    foreach (HDR_TS_EN_bit_cg[bt]) this.HDR_TS_EN_bit_cg[bt].sample(data[7+bt]);
    foreach (CMD_CCC_DEFBYTE_bit_cg[bt]) this.CMD_CCC_DEFBYTE_bit_cg[bt].sample(data[10+bt]);
    foreach (IBI_DATA_ABORT_EN_bit_cg[bt]) this.IBI_DATA_ABORT_EN_bit_cg[bt].sample(data[11+bt]);
    foreach (IBI_CREDIT_COUNT_EN_bit_cg[bt])
    this.IBI_CREDIT_COUNT_EN_bit_cg[bt].sample(data[12+bt]);
    foreach (SCHEDULED_COMMANDS_EN_bit_cg[bt])
    this.SCHEDULED_COMMANDS_EN_bit_cg[bt].sample(data[13+bt]);
    foreach (CMD_SIZE_bit_cg[bt]) this.CMD_SIZE_bit_cg[bt].sample(data[20+bt]);
    foreach (SG_CAPABILITY_CR_EN_bit_cg[bt])
    this.SG_CAPABILITY_CR_EN_bit_cg[bt].sample(data[28+bt]);
    foreach (SG_CAPABILITY_IBI_EN_bit_cg[bt])
    this.SG_CAPABILITY_IBI_EN_bit_cg[bt].sample(data[29+bt]);
    foreach (SG_CAPABILITY_DC_EN_bit_cg[bt])
    this.SG_CAPABILITY_DC_EN_bit_cg[bt].sample(data[30+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[2:2]  /*COMBO_COMMAND*/, data[3:3]  /*AUTO_COMMAND*/,
                       data[5:5]  /*STANDBY_CR_CAP*/, data[6:6]  /*HDR_DDR_EN*/,
                       data[7:7]  /*HDR_TS_EN*/, data[10:10]  /*CMD_CCC_DEFBYTE*/,
                       data[11:11]  /*IBI_DATA_ABORT_EN*/, data[12:12]  /*IBI_CREDIT_COUNT_EN*/,
                       data[13:13]  /*SCHEDULED_COMMANDS_EN*/, data[21:20]  /*CMD_SIZE*/,
                       data[28:28]  /*SG_CAPABILITY_CR_EN*/, data[29:29]  /*SG_CAPABILITY_IBI_EN*/,
                       data[30:30]  /*SG_CAPABILITY_DC_EN*/);
  end
endfunction

function void I3CCSR__I3CBase__HC_CAPABILITIES::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (COMBO_COMMAND_bit_cg[bt])
    this.COMBO_COMMAND_bit_cg[bt].sample(COMBO_COMMAND.get_mirrored_value() >> bt);
    foreach (AUTO_COMMAND_bit_cg[bt])
    this.AUTO_COMMAND_bit_cg[bt].sample(AUTO_COMMAND.get_mirrored_value() >> bt);
    foreach (STANDBY_CR_CAP_bit_cg[bt])
    this.STANDBY_CR_CAP_bit_cg[bt].sample(STANDBY_CR_CAP.get_mirrored_value() >> bt);
    foreach (HDR_DDR_EN_bit_cg[bt])
    this.HDR_DDR_EN_bit_cg[bt].sample(HDR_DDR_EN.get_mirrored_value() >> bt);
    foreach (HDR_TS_EN_bit_cg[bt])
    this.HDR_TS_EN_bit_cg[bt].sample(HDR_TS_EN.get_mirrored_value() >> bt);
    foreach (CMD_CCC_DEFBYTE_bit_cg[bt])
    this.CMD_CCC_DEFBYTE_bit_cg[bt].sample(CMD_CCC_DEFBYTE.get_mirrored_value() >> bt);
    foreach (IBI_DATA_ABORT_EN_bit_cg[bt])
    this.IBI_DATA_ABORT_EN_bit_cg[bt].sample(IBI_DATA_ABORT_EN.get_mirrored_value() >> bt);
    foreach (IBI_CREDIT_COUNT_EN_bit_cg[bt])
    this.IBI_CREDIT_COUNT_EN_bit_cg[bt].sample(IBI_CREDIT_COUNT_EN.get_mirrored_value() >> bt);
    foreach (SCHEDULED_COMMANDS_EN_bit_cg[bt])
    this.SCHEDULED_COMMANDS_EN_bit_cg[bt].sample(SCHEDULED_COMMANDS_EN.get_mirrored_value() >> bt);
    foreach (CMD_SIZE_bit_cg[bt])
    this.CMD_SIZE_bit_cg[bt].sample(CMD_SIZE.get_mirrored_value() >> bt);
    foreach (SG_CAPABILITY_CR_EN_bit_cg[bt])
    this.SG_CAPABILITY_CR_EN_bit_cg[bt].sample(SG_CAPABILITY_CR_EN.get_mirrored_value() >> bt);
    foreach (SG_CAPABILITY_IBI_EN_bit_cg[bt])
    this.SG_CAPABILITY_IBI_EN_bit_cg[bt].sample(SG_CAPABILITY_IBI_EN.get_mirrored_value() >> bt);
    foreach (SG_CAPABILITY_DC_EN_bit_cg[bt])
    this.SG_CAPABILITY_DC_EN_bit_cg[bt].sample(SG_CAPABILITY_DC_EN.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(
        COMBO_COMMAND.get_mirrored_value(), AUTO_COMMAND.get_mirrored_value(),
        STANDBY_CR_CAP.get_mirrored_value(), HDR_DDR_EN.get_mirrored_value(),
        HDR_TS_EN.get_mirrored_value(), CMD_CCC_DEFBYTE.get_mirrored_value(),
        IBI_DATA_ABORT_EN.get_mirrored_value(), IBI_CREDIT_COUNT_EN.get_mirrored_value(),
        SCHEDULED_COMMANDS_EN.get_mirrored_value(), CMD_SIZE.get_mirrored_value(),
        SG_CAPABILITY_CR_EN.get_mirrored_value(), SG_CAPABILITY_IBI_EN.get_mirrored_value(),
        SG_CAPABILITY_DC_EN.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__RESET_CONTROL SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__RESET_CONTROL::sample (uvm_reg_data_t data, uvm_reg_data_t byte_en,
                                                      bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (SOFT_RST_bit_cg[bt]) this.SOFT_RST_bit_cg[bt].sample(data[0+bt]);
    foreach (CMD_QUEUE_RST_bit_cg[bt]) this.CMD_QUEUE_RST_bit_cg[bt].sample(data[1+bt]);
    foreach (RESP_QUEUE_RST_bit_cg[bt]) this.RESP_QUEUE_RST_bit_cg[bt].sample(data[2+bt]);
    foreach (TX_FIFO_RST_bit_cg[bt]) this.TX_FIFO_RST_bit_cg[bt].sample(data[3+bt]);
    foreach (RX_FIFO_RST_bit_cg[bt]) this.RX_FIFO_RST_bit_cg[bt].sample(data[4+bt]);
    foreach (IBI_QUEUE_RST_bit_cg[bt]) this.IBI_QUEUE_RST_bit_cg[bt].sample(data[5+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[0:0]  /*SOFT_RST*/, data[1:1]  /*CMD_QUEUE_RST*/,
                       data[2:2]  /*RESP_QUEUE_RST*/, data[3:3]  /*TX_FIFO_RST*/,
                       data[4:4]  /*RX_FIFO_RST*/, data[5:5]  /*IBI_QUEUE_RST*/);
  end
endfunction

function void I3CCSR__I3CBase__RESET_CONTROL::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (SOFT_RST_bit_cg[bt])
    this.SOFT_RST_bit_cg[bt].sample(SOFT_RST.get_mirrored_value() >> bt);
    foreach (CMD_QUEUE_RST_bit_cg[bt])
    this.CMD_QUEUE_RST_bit_cg[bt].sample(CMD_QUEUE_RST.get_mirrored_value() >> bt);
    foreach (RESP_QUEUE_RST_bit_cg[bt])
    this.RESP_QUEUE_RST_bit_cg[bt].sample(RESP_QUEUE_RST.get_mirrored_value() >> bt);
    foreach (TX_FIFO_RST_bit_cg[bt])
    this.TX_FIFO_RST_bit_cg[bt].sample(TX_FIFO_RST.get_mirrored_value() >> bt);
    foreach (RX_FIFO_RST_bit_cg[bt])
    this.RX_FIFO_RST_bit_cg[bt].sample(RX_FIFO_RST.get_mirrored_value() >> bt);
    foreach (IBI_QUEUE_RST_bit_cg[bt])
    this.IBI_QUEUE_RST_bit_cg[bt].sample(IBI_QUEUE_RST.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(SOFT_RST.get_mirrored_value(), CMD_QUEUE_RST.get_mirrored_value(),
                       RESP_QUEUE_RST.get_mirrored_value(), TX_FIFO_RST.get_mirrored_value(),
                       RX_FIFO_RST.get_mirrored_value(), IBI_QUEUE_RST.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__PRESENT_STATE SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__PRESENT_STATE::sample (uvm_reg_data_t data, uvm_reg_data_t byte_en,
                                                      bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (AC_CURRENT_OWN_bit_cg[bt]) this.AC_CURRENT_OWN_bit_cg[bt].sample(data[2+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[2:2]  /*AC_CURRENT_OWN*/);
  end
endfunction

function void I3CCSR__I3CBase__PRESENT_STATE::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (AC_CURRENT_OWN_bit_cg[bt])
    this.AC_CURRENT_OWN_bit_cg[bt].sample(AC_CURRENT_OWN.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(AC_CURRENT_OWN.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__INTR_STATUS SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__INTR_STATUS::sample (uvm_reg_data_t data, uvm_reg_data_t byte_en,
                                                    bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (HC_INTERNAL_ERR_STAT_bit_cg[bt])
    this.HC_INTERNAL_ERR_STAT_bit_cg[bt].sample(data[10+bt]);
    foreach (HC_SEQ_CANCEL_STAT_bit_cg[bt]) this.HC_SEQ_CANCEL_STAT_bit_cg[bt].sample(data[11+bt]);
    foreach (HC_WARN_CMD_SEQ_STALL_STAT_bit_cg[bt])
    this.HC_WARN_CMD_SEQ_STALL_STAT_bit_cg[bt].sample(data[12+bt]);
    foreach (HC_ERR_CMD_SEQ_TIMEOUT_STAT_bit_cg[bt])
    this.HC_ERR_CMD_SEQ_TIMEOUT_STAT_bit_cg[bt].sample(data[13+bt]);
    foreach (SCHED_CMD_MISSED_TICK_STAT_bit_cg[bt])
    this.SCHED_CMD_MISSED_TICK_STAT_bit_cg[bt].sample(data[14+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[10:10]  /*HC_INTERNAL_ERR_STAT*/, data[11:11]  /*HC_SEQ_CANCEL_STAT*/,
                       data[12:12]  /*HC_WARN_CMD_SEQ_STALL_STAT*/,
                       data[13:13]  /*HC_ERR_CMD_SEQ_TIMEOUT_STAT*/,
                       data[14:14]  /*SCHED_CMD_MISSED_TICK_STAT*/);
  end
endfunction

function void I3CCSR__I3CBase__INTR_STATUS::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (HC_INTERNAL_ERR_STAT_bit_cg[bt])
    this.HC_INTERNAL_ERR_STAT_bit_cg[bt].sample(HC_INTERNAL_ERR_STAT.get_mirrored_value() >> bt);
    foreach (HC_SEQ_CANCEL_STAT_bit_cg[bt])
    this.HC_SEQ_CANCEL_STAT_bit_cg[bt].sample(HC_SEQ_CANCEL_STAT.get_mirrored_value() >> bt);
    foreach (HC_WARN_CMD_SEQ_STALL_STAT_bit_cg[bt])
    this.HC_WARN_CMD_SEQ_STALL_STAT_bit_cg[bt].sample(
        HC_WARN_CMD_SEQ_STALL_STAT.get_mirrored_value() >> bt);
    foreach (HC_ERR_CMD_SEQ_TIMEOUT_STAT_bit_cg[bt])
    this.HC_ERR_CMD_SEQ_TIMEOUT_STAT_bit_cg[bt].sample(
        HC_ERR_CMD_SEQ_TIMEOUT_STAT.get_mirrored_value() >> bt);
    foreach (SCHED_CMD_MISSED_TICK_STAT_bit_cg[bt])
    this.SCHED_CMD_MISSED_TICK_STAT_bit_cg[bt].sample(
        SCHED_CMD_MISSED_TICK_STAT.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(HC_INTERNAL_ERR_STAT.get_mirrored_value(),
                       HC_SEQ_CANCEL_STAT.get_mirrored_value(),
                       HC_WARN_CMD_SEQ_STALL_STAT.get_mirrored_value(),
                       HC_ERR_CMD_SEQ_TIMEOUT_STAT.get_mirrored_value(),
                       SCHED_CMD_MISSED_TICK_STAT.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__INTR_STATUS_ENABLE SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__INTR_STATUS_ENABLE::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (HC_INTERNAL_ERR_STAT_EN_bit_cg[bt])
    this.HC_INTERNAL_ERR_STAT_EN_bit_cg[bt].sample(data[10+bt]);
    foreach (HC_SEQ_CANCEL_STAT_EN_bit_cg[bt])
    this.HC_SEQ_CANCEL_STAT_EN_bit_cg[bt].sample(data[11+bt]);
    foreach (HC_WARN_CMD_SEQ_STALL_STAT_EN_bit_cg[bt])
    this.HC_WARN_CMD_SEQ_STALL_STAT_EN_bit_cg[bt].sample(data[12+bt]);
    foreach (HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN_bit_cg[bt])
    this.HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN_bit_cg[bt].sample(data[13+bt]);
    foreach (SCHED_CMD_MISSED_TICK_STAT_EN_bit_cg[bt])
    this.SCHED_CMD_MISSED_TICK_STAT_EN_bit_cg[bt].sample(data[14+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[10:10]  /*HC_INTERNAL_ERR_STAT_EN*/,
                       data[11:11]  /*HC_SEQ_CANCEL_STAT_EN*/,
                       data[12:12]  /*HC_WARN_CMD_SEQ_STALL_STAT_EN*/,
                       data[13:13]  /*HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN*/,
                       data[14:14]  /*SCHED_CMD_MISSED_TICK_STAT_EN*/);
  end
endfunction

function void I3CCSR__I3CBase__INTR_STATUS_ENABLE::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (HC_INTERNAL_ERR_STAT_EN_bit_cg[bt])
    this.HC_INTERNAL_ERR_STAT_EN_bit_cg[bt].sample(
        HC_INTERNAL_ERR_STAT_EN.get_mirrored_value() >> bt);
    foreach (HC_SEQ_CANCEL_STAT_EN_bit_cg[bt])
    this.HC_SEQ_CANCEL_STAT_EN_bit_cg[bt].sample(HC_SEQ_CANCEL_STAT_EN.get_mirrored_value() >> bt);
    foreach (HC_WARN_CMD_SEQ_STALL_STAT_EN_bit_cg[bt])
    this.HC_WARN_CMD_SEQ_STALL_STAT_EN_bit_cg[bt].sample(
        HC_WARN_CMD_SEQ_STALL_STAT_EN.get_mirrored_value() >> bt);
    foreach (HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN_bit_cg[bt])
    this.HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN_bit_cg[bt].sample(
        HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN.get_mirrored_value() >> bt);
    foreach (SCHED_CMD_MISSED_TICK_STAT_EN_bit_cg[bt])
    this.SCHED_CMD_MISSED_TICK_STAT_EN_bit_cg[bt].sample(
        SCHED_CMD_MISSED_TICK_STAT_EN.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(HC_INTERNAL_ERR_STAT_EN.get_mirrored_value(),
                       HC_SEQ_CANCEL_STAT_EN.get_mirrored_value(),
                       HC_WARN_CMD_SEQ_STALL_STAT_EN.get_mirrored_value(),
                       HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN.get_mirrored_value(),
                       SCHED_CMD_MISSED_TICK_STAT_EN.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__INTR_SIGNAL_ENABLE SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__INTR_SIGNAL_ENABLE::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (HC_INTERNAL_ERR_SIGNAL_EN_bit_cg[bt])
    this.HC_INTERNAL_ERR_SIGNAL_EN_bit_cg[bt].sample(data[10+bt]);
    foreach (HC_SEQ_CANCEL_SIGNAL_EN_bit_cg[bt])
    this.HC_SEQ_CANCEL_SIGNAL_EN_bit_cg[bt].sample(data[11+bt]);
    foreach (HC_WARN_CMD_SEQ_STALL_SIGNAL_EN_bit_cg[bt])
    this.HC_WARN_CMD_SEQ_STALL_SIGNAL_EN_bit_cg[bt].sample(data[12+bt]);
    foreach (HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN_bit_cg[bt])
    this.HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN_bit_cg[bt].sample(data[13+bt]);
    foreach (SCHED_CMD_MISSED_TICK_SIGNAL_EN_bit_cg[bt])
    this.SCHED_CMD_MISSED_TICK_SIGNAL_EN_bit_cg[bt].sample(data[14+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[10:10]  /*HC_INTERNAL_ERR_SIGNAL_EN*/,
                       data[11:11]  /*HC_SEQ_CANCEL_SIGNAL_EN*/,
                       data[12:12]  /*HC_WARN_CMD_SEQ_STALL_SIGNAL_EN*/,
                       data[13:13]  /*HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN*/,
                       data[14:14]  /*SCHED_CMD_MISSED_TICK_SIGNAL_EN*/);
  end
endfunction

function void I3CCSR__I3CBase__INTR_SIGNAL_ENABLE::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (HC_INTERNAL_ERR_SIGNAL_EN_bit_cg[bt])
    this.HC_INTERNAL_ERR_SIGNAL_EN_bit_cg[bt].sample(
        HC_INTERNAL_ERR_SIGNAL_EN.get_mirrored_value() >> bt);
    foreach (HC_SEQ_CANCEL_SIGNAL_EN_bit_cg[bt])
    this.HC_SEQ_CANCEL_SIGNAL_EN_bit_cg[bt].sample(
        HC_SEQ_CANCEL_SIGNAL_EN.get_mirrored_value() >> bt);
    foreach (HC_WARN_CMD_SEQ_STALL_SIGNAL_EN_bit_cg[bt])
    this.HC_WARN_CMD_SEQ_STALL_SIGNAL_EN_bit_cg[bt].sample(
        HC_WARN_CMD_SEQ_STALL_SIGNAL_EN.get_mirrored_value() >> bt);
    foreach (HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN_bit_cg[bt])
    this.HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN_bit_cg[bt].sample(
        HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN.get_mirrored_value() >> bt);
    foreach (SCHED_CMD_MISSED_TICK_SIGNAL_EN_bit_cg[bt])
    this.SCHED_CMD_MISSED_TICK_SIGNAL_EN_bit_cg[bt].sample(
        SCHED_CMD_MISSED_TICK_SIGNAL_EN.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(HC_INTERNAL_ERR_SIGNAL_EN.get_mirrored_value(),
                       HC_SEQ_CANCEL_SIGNAL_EN.get_mirrored_value(),
                       HC_WARN_CMD_SEQ_STALL_SIGNAL_EN.get_mirrored_value(),
                       HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN.get_mirrored_value(),
                       SCHED_CMD_MISSED_TICK_SIGNAL_EN.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__INTR_FORCE SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__INTR_FORCE::sample (uvm_reg_data_t data, uvm_reg_data_t byte_en,
                                                   bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (HC_INTERNAL_ERR_FORCE_bit_cg[bt])
    this.HC_INTERNAL_ERR_FORCE_bit_cg[bt].sample(data[10+bt]);
    foreach (HC_SEQ_CANCEL_FORCE_bit_cg[bt])
    this.HC_SEQ_CANCEL_FORCE_bit_cg[bt].sample(data[11+bt]);
    foreach (HC_WARN_CMD_SEQ_STALL_FORCE_bit_cg[bt])
    this.HC_WARN_CMD_SEQ_STALL_FORCE_bit_cg[bt].sample(data[12+bt]);
    foreach (HC_ERR_CMD_SEQ_TIMEOUT_FORCE_bit_cg[bt])
    this.HC_ERR_CMD_SEQ_TIMEOUT_FORCE_bit_cg[bt].sample(data[13+bt]);
    foreach (SCHED_CMD_MISSED_TICK_FORCE_bit_cg[bt])
    this.SCHED_CMD_MISSED_TICK_FORCE_bit_cg[bt].sample(data[14+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[10:10]  /*HC_INTERNAL_ERR_FORCE*/, data[11:11]  /*HC_SEQ_CANCEL_FORCE*/,
                       data[12:12]  /*HC_WARN_CMD_SEQ_STALL_FORCE*/,
                       data[13:13]  /*HC_ERR_CMD_SEQ_TIMEOUT_FORCE*/,
                       data[14:14]  /*SCHED_CMD_MISSED_TICK_FORCE*/);
  end
endfunction

function void I3CCSR__I3CBase__INTR_FORCE::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (HC_INTERNAL_ERR_FORCE_bit_cg[bt])
    this.HC_INTERNAL_ERR_FORCE_bit_cg[bt].sample(HC_INTERNAL_ERR_FORCE.get_mirrored_value() >> bt);
    foreach (HC_SEQ_CANCEL_FORCE_bit_cg[bt])
    this.HC_SEQ_CANCEL_FORCE_bit_cg[bt].sample(HC_SEQ_CANCEL_FORCE.get_mirrored_value() >> bt);
    foreach (HC_WARN_CMD_SEQ_STALL_FORCE_bit_cg[bt])
    this.HC_WARN_CMD_SEQ_STALL_FORCE_bit_cg[bt].sample(
        HC_WARN_CMD_SEQ_STALL_FORCE.get_mirrored_value() >> bt);
    foreach (HC_ERR_CMD_SEQ_TIMEOUT_FORCE_bit_cg[bt])
    this.HC_ERR_CMD_SEQ_TIMEOUT_FORCE_bit_cg[bt].sample(
        HC_ERR_CMD_SEQ_TIMEOUT_FORCE.get_mirrored_value() >> bt);
    foreach (SCHED_CMD_MISSED_TICK_FORCE_bit_cg[bt])
    this.SCHED_CMD_MISSED_TICK_FORCE_bit_cg[bt].sample(
        SCHED_CMD_MISSED_TICK_FORCE.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(HC_INTERNAL_ERR_FORCE.get_mirrored_value(),
                       HC_SEQ_CANCEL_FORCE.get_mirrored_value(),
                       HC_WARN_CMD_SEQ_STALL_FORCE.get_mirrored_value(),
                       HC_ERR_CMD_SEQ_TIMEOUT_FORCE.get_mirrored_value(),
                       SCHED_CMD_MISSED_TICK_FORCE.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__DAT_SECTION_OFFSET SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__DAT_SECTION_OFFSET::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TABLE_OFFSET_bit_cg[bt]) this.TABLE_OFFSET_bit_cg[bt].sample(data[0+bt]);
    foreach (TABLE_SIZE_bit_cg[bt]) this.TABLE_SIZE_bit_cg[bt].sample(data[12+bt]);
    foreach (ENTRY_SIZE_bit_cg[bt]) this.ENTRY_SIZE_bit_cg[bt].sample(data[28+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[11:0]  /*TABLE_OFFSET*/, data[18:12]  /*TABLE_SIZE*/,
                       data[31:28]  /*ENTRY_SIZE*/);
  end
endfunction

function void I3CCSR__I3CBase__DAT_SECTION_OFFSET::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TABLE_OFFSET_bit_cg[bt])
    this.TABLE_OFFSET_bit_cg[bt].sample(TABLE_OFFSET.get_mirrored_value() >> bt);
    foreach (TABLE_SIZE_bit_cg[bt])
    this.TABLE_SIZE_bit_cg[bt].sample(TABLE_SIZE.get_mirrored_value() >> bt);
    foreach (ENTRY_SIZE_bit_cg[bt])
    this.ENTRY_SIZE_bit_cg[bt].sample(ENTRY_SIZE.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(TABLE_OFFSET.get_mirrored_value(), TABLE_SIZE.get_mirrored_value(),
                       ENTRY_SIZE.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__DCT_SECTION_OFFSET SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__DCT_SECTION_OFFSET::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TABLE_OFFSET_bit_cg[bt]) this.TABLE_OFFSET_bit_cg[bt].sample(data[0+bt]);
    foreach (TABLE_SIZE_bit_cg[bt]) this.TABLE_SIZE_bit_cg[bt].sample(data[12+bt]);
    foreach (TABLE_INDEX_bit_cg[bt]) this.TABLE_INDEX_bit_cg[bt].sample(data[19+bt]);
    foreach (ENTRY_SIZE_bit_cg[bt]) this.ENTRY_SIZE_bit_cg[bt].sample(data[28+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[11:0]  /*TABLE_OFFSET*/, data[18:12]  /*TABLE_SIZE*/,
                       data[23:19]  /*TABLE_INDEX*/, data[31:28]  /*ENTRY_SIZE*/);
  end
endfunction

function void I3CCSR__I3CBase__DCT_SECTION_OFFSET::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TABLE_OFFSET_bit_cg[bt])
    this.TABLE_OFFSET_bit_cg[bt].sample(TABLE_OFFSET.get_mirrored_value() >> bt);
    foreach (TABLE_SIZE_bit_cg[bt])
    this.TABLE_SIZE_bit_cg[bt].sample(TABLE_SIZE.get_mirrored_value() >> bt);
    foreach (TABLE_INDEX_bit_cg[bt])
    this.TABLE_INDEX_bit_cg[bt].sample(TABLE_INDEX.get_mirrored_value() >> bt);
    foreach (ENTRY_SIZE_bit_cg[bt])
    this.ENTRY_SIZE_bit_cg[bt].sample(ENTRY_SIZE.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(TABLE_OFFSET.get_mirrored_value(), TABLE_SIZE.get_mirrored_value(),
                       TABLE_INDEX.get_mirrored_value(), ENTRY_SIZE.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__RING_HEADERS_SECTION_OFFSET SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__RING_HEADERS_SECTION_OFFSET::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (SECTION_OFFSET_bit_cg[bt]) this.SECTION_OFFSET_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[15:0]  /*SECTION_OFFSET*/);
  end
endfunction

function void I3CCSR__I3CBase__RING_HEADERS_SECTION_OFFSET::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (SECTION_OFFSET_bit_cg[bt])
    this.SECTION_OFFSET_bit_cg[bt].sample(SECTION_OFFSET.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(SECTION_OFFSET.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__PIO_SECTION_OFFSET SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__PIO_SECTION_OFFSET::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (SECTION_OFFSET_bit_cg[bt]) this.SECTION_OFFSET_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[15:0]  /*SECTION_OFFSET*/);
  end
endfunction

function void I3CCSR__I3CBase__PIO_SECTION_OFFSET::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (SECTION_OFFSET_bit_cg[bt])
    this.SECTION_OFFSET_bit_cg[bt].sample(SECTION_OFFSET.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(SECTION_OFFSET.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__EXT_CAPS_SECTION_OFFSET SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__EXT_CAPS_SECTION_OFFSET::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (SECTION_OFFSET_bit_cg[bt]) this.SECTION_OFFSET_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[15:0]  /*SECTION_OFFSET*/);
  end
endfunction

function void I3CCSR__I3CBase__EXT_CAPS_SECTION_OFFSET::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (SECTION_OFFSET_bit_cg[bt])
    this.SECTION_OFFSET_bit_cg[bt].sample(SECTION_OFFSET.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(SECTION_OFFSET.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__INT_CTRL_CMDS_EN SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__INT_CTRL_CMDS_EN::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (ICC_SUPPORT_bit_cg[bt]) this.ICC_SUPPORT_bit_cg[bt].sample(data[0+bt]);
    foreach (MIPI_CMDS_SUPPORTED_bit_cg[bt]) this.MIPI_CMDS_SUPPORTED_bit_cg[bt].sample(data[1+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[0:0]  /*ICC_SUPPORT*/, data[15:1]  /*MIPI_CMDS_SUPPORTED*/);
  end
endfunction

function void I3CCSR__I3CBase__INT_CTRL_CMDS_EN::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (ICC_SUPPORT_bit_cg[bt])
    this.ICC_SUPPORT_bit_cg[bt].sample(ICC_SUPPORT.get_mirrored_value() >> bt);
    foreach (MIPI_CMDS_SUPPORTED_bit_cg[bt])
    this.MIPI_CMDS_SUPPORTED_bit_cg[bt].sample(MIPI_CMDS_SUPPORTED.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(ICC_SUPPORT.get_mirrored_value(), MIPI_CMDS_SUPPORTED.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__IBI_NOTIFY_CTRL SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__IBI_NOTIFY_CTRL::sample (uvm_reg_data_t data, uvm_reg_data_t byte_en,
                                                        bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (NOTIFY_HJ_REJECTED_bit_cg[bt]) this.NOTIFY_HJ_REJECTED_bit_cg[bt].sample(data[0+bt]);
    foreach (NOTIFY_CRR_REJECTED_bit_cg[bt]) this.NOTIFY_CRR_REJECTED_bit_cg[bt].sample(data[1+bt]);
    foreach (NOTIFY_IBI_REJECTED_bit_cg[bt]) this.NOTIFY_IBI_REJECTED_bit_cg[bt].sample(data[3+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[0:0]  /*NOTIFY_HJ_REJECTED*/, data[1:1]  /*NOTIFY_CRR_REJECTED*/,
                       data[3:3]  /*NOTIFY_IBI_REJECTED*/);
  end
endfunction

function void I3CCSR__I3CBase__IBI_NOTIFY_CTRL::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (NOTIFY_HJ_REJECTED_bit_cg[bt])
    this.NOTIFY_HJ_REJECTED_bit_cg[bt].sample(NOTIFY_HJ_REJECTED.get_mirrored_value() >> bt);
    foreach (NOTIFY_CRR_REJECTED_bit_cg[bt])
    this.NOTIFY_CRR_REJECTED_bit_cg[bt].sample(NOTIFY_CRR_REJECTED.get_mirrored_value() >> bt);
    foreach (NOTIFY_IBI_REJECTED_bit_cg[bt])
    this.NOTIFY_IBI_REJECTED_bit_cg[bt].sample(NOTIFY_IBI_REJECTED.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(NOTIFY_HJ_REJECTED.get_mirrored_value(),
                       NOTIFY_CRR_REJECTED.get_mirrored_value(),
                       NOTIFY_IBI_REJECTED.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__IBI_DATA_ABORT_CTRL SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__IBI_DATA_ABORT_CTRL::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (MATCH_IBI_ID_bit_cg[bt]) this.MATCH_IBI_ID_bit_cg[bt].sample(data[8+bt]);
    foreach (AFTER_N_CHUNKS_bit_cg[bt]) this.AFTER_N_CHUNKS_bit_cg[bt].sample(data[16+bt]);
    foreach (MATCH_STATUS_TYPE_bit_cg[bt]) this.MATCH_STATUS_TYPE_bit_cg[bt].sample(data[18+bt]);
    foreach (IBI_DATA_ABORT_MON_bit_cg[bt]) this.IBI_DATA_ABORT_MON_bit_cg[bt].sample(data[31+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[15:8]  /*MATCH_IBI_ID*/, data[17:16]  /*AFTER_N_CHUNKS*/,
                       data[20:18]  /*MATCH_STATUS_TYPE*/, data[31:31]  /*IBI_DATA_ABORT_MON*/);
  end
endfunction

function void I3CCSR__I3CBase__IBI_DATA_ABORT_CTRL::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (MATCH_IBI_ID_bit_cg[bt])
    this.MATCH_IBI_ID_bit_cg[bt].sample(MATCH_IBI_ID.get_mirrored_value() >> bt);
    foreach (AFTER_N_CHUNKS_bit_cg[bt])
    this.AFTER_N_CHUNKS_bit_cg[bt].sample(AFTER_N_CHUNKS.get_mirrored_value() >> bt);
    foreach (MATCH_STATUS_TYPE_bit_cg[bt])
    this.MATCH_STATUS_TYPE_bit_cg[bt].sample(MATCH_STATUS_TYPE.get_mirrored_value() >> bt);
    foreach (IBI_DATA_ABORT_MON_bit_cg[bt])
    this.IBI_DATA_ABORT_MON_bit_cg[bt].sample(IBI_DATA_ABORT_MON.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(MATCH_IBI_ID.get_mirrored_value(), AFTER_N_CHUNKS.get_mirrored_value(),
                       MATCH_STATUS_TYPE.get_mirrored_value(),
                       IBI_DATA_ABORT_MON.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__DEV_CTX_BASE_LO SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__DEV_CTX_BASE_LO::sample (uvm_reg_data_t data, uvm_reg_data_t byte_en,
                                                        bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (BASE_LO_bit_cg[bt]) this.BASE_LO_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[0:0]  /*BASE_LO*/);
  end
endfunction

function void I3CCSR__I3CBase__DEV_CTX_BASE_LO::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (BASE_LO_bit_cg[bt]) this.BASE_LO_bit_cg[bt].sample(BASE_LO.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(BASE_LO.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__DEV_CTX_BASE_HI SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__DEV_CTX_BASE_HI::sample (uvm_reg_data_t data, uvm_reg_data_t byte_en,
                                                        bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (BASE_HI_bit_cg[bt]) this.BASE_HI_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[0:0]  /*BASE_HI*/);
  end
endfunction

function void I3CCSR__I3CBase__DEV_CTX_BASE_HI::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (BASE_HI_bit_cg[bt]) this.BASE_HI_bit_cg[bt].sample(BASE_HI.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(BASE_HI.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3CBASE__DEV_CTX_SG SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3CBase__DEV_CTX_SG::sample (uvm_reg_data_t data, uvm_reg_data_t byte_en,
                                                   bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (LIST_SIZE_bit_cg[bt]) this.LIST_SIZE_bit_cg[bt].sample(data[0+bt]);
    foreach (BLP_bit_cg[bt]) this.BLP_bit_cg[bt].sample(data[31+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[15:0]  /*LIST_SIZE*/, data[31:31]  /*BLP*/);
  end
endfunction

function void I3CCSR__I3CBase__DEV_CTX_SG::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (LIST_SIZE_bit_cg[bt])
    this.LIST_SIZE_bit_cg[bt].sample(LIST_SIZE.get_mirrored_value() >> bt);
    foreach (BLP_bit_cg[bt]) this.BLP_bit_cg[bt].sample(BLP.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(LIST_SIZE.get_mirrored_value(), BLP.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__PIOCONTROL__COMMAND_PORT SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__PIOControl__COMMAND_PORT::sample (uvm_reg_data_t data, uvm_reg_data_t byte_en,
                                                        bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (COMMAND_DATA_bit_cg[bt]) this.COMMAND_DATA_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[0:0]  /*COMMAND_DATA*/);
  end
endfunction

function void I3CCSR__PIOControl__COMMAND_PORT::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (COMMAND_DATA_bit_cg[bt])
    this.COMMAND_DATA_bit_cg[bt].sample(COMMAND_DATA.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(COMMAND_DATA.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__PIOCONTROL__RESPONSE_PORT SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__PIOControl__RESPONSE_PORT::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (RESPONSE_DATA_bit_cg[bt]) this.RESPONSE_DATA_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[0:0]  /*RESPONSE_DATA*/);
  end
endfunction

function void I3CCSR__PIOControl__RESPONSE_PORT::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (RESPONSE_DATA_bit_cg[bt])
    this.RESPONSE_DATA_bit_cg[bt].sample(RESPONSE_DATA.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(RESPONSE_DATA.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__PIOCONTROL__XFER_DATA_PORT SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__PIOControl__XFER_DATA_PORT::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TX_DATA_bit_cg[bt]) this.TX_DATA_bit_cg[bt].sample(data[0+bt]);
    foreach (RX_DATA_bit_cg[bt]) this.RX_DATA_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*TX_DATA*/, data[31:0]  /*RX_DATA*/);
  end
endfunction

function void I3CCSR__PIOControl__XFER_DATA_PORT::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TX_DATA_bit_cg[bt]) this.TX_DATA_bit_cg[bt].sample(TX_DATA.get_mirrored_value() >> bt);
    foreach (RX_DATA_bit_cg[bt]) this.RX_DATA_bit_cg[bt].sample(RX_DATA.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(TX_DATA.get_mirrored_value(), RX_DATA.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__PIOCONTROL__IBI_PORT SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__PIOControl__IBI_PORT::sample (uvm_reg_data_t data, uvm_reg_data_t byte_en,
                                                    bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (IBI_DATA_bit_cg[bt]) this.IBI_DATA_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[0:0]  /*IBI_DATA*/);
  end
endfunction

function void I3CCSR__PIOControl__IBI_PORT::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (IBI_DATA_bit_cg[bt])
    this.IBI_DATA_bit_cg[bt].sample(IBI_DATA.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(IBI_DATA.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__PIOCONTROL__QUEUE_THLD_CTRL SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__PIOControl__QUEUE_THLD_CTRL::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (CMD_EMPTY_BUF_THLD_bit_cg[bt]) this.CMD_EMPTY_BUF_THLD_bit_cg[bt].sample(data[0+bt]);
    foreach (RESP_BUF_THLD_bit_cg[bt]) this.RESP_BUF_THLD_bit_cg[bt].sample(data[8+bt]);
    foreach (IBI_DATA_SEGMENT_SIZE_bit_cg[bt])
    this.IBI_DATA_SEGMENT_SIZE_bit_cg[bt].sample(data[16+bt]);
    foreach (IBI_STATUS_THLD_bit_cg[bt]) this.IBI_STATUS_THLD_bit_cg[bt].sample(data[24+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[7:0]  /*CMD_EMPTY_BUF_THLD*/, data[15:8]  /*RESP_BUF_THLD*/,
                       data[23:16]  /*IBI_DATA_SEGMENT_SIZE*/, data[31:24]  /*IBI_STATUS_THLD*/);
  end
endfunction

function void I3CCSR__PIOControl__QUEUE_THLD_CTRL::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (CMD_EMPTY_BUF_THLD_bit_cg[bt])
    this.CMD_EMPTY_BUF_THLD_bit_cg[bt].sample(CMD_EMPTY_BUF_THLD.get_mirrored_value() >> bt);
    foreach (RESP_BUF_THLD_bit_cg[bt])
    this.RESP_BUF_THLD_bit_cg[bt].sample(RESP_BUF_THLD.get_mirrored_value() >> bt);
    foreach (IBI_DATA_SEGMENT_SIZE_bit_cg[bt])
    this.IBI_DATA_SEGMENT_SIZE_bit_cg[bt].sample(IBI_DATA_SEGMENT_SIZE.get_mirrored_value() >> bt);
    foreach (IBI_STATUS_THLD_bit_cg[bt])
    this.IBI_STATUS_THLD_bit_cg[bt].sample(IBI_STATUS_THLD.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(CMD_EMPTY_BUF_THLD.get_mirrored_value(), RESP_BUF_THLD.get_mirrored_value(),
                       IBI_DATA_SEGMENT_SIZE.get_mirrored_value(),
                       IBI_STATUS_THLD.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__PIOCONTROL__DATA_BUFFER_THLD_CTRL SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__PIOControl__DATA_BUFFER_THLD_CTRL::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TX_BUF_THLD_bit_cg[bt]) this.TX_BUF_THLD_bit_cg[bt].sample(data[0+bt]);
    foreach (RX_BUF_THLD_bit_cg[bt]) this.RX_BUF_THLD_bit_cg[bt].sample(data[8+bt]);
    foreach (TX_START_THLD_bit_cg[bt]) this.TX_START_THLD_bit_cg[bt].sample(data[16+bt]);
    foreach (RX_START_THLD_bit_cg[bt]) this.RX_START_THLD_bit_cg[bt].sample(data[24+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[2:0]  /*TX_BUF_THLD*/, data[10:8]  /*RX_BUF_THLD*/,
                       data[18:16]  /*TX_START_THLD*/, data[26:24]  /*RX_START_THLD*/);
  end
endfunction

function void I3CCSR__PIOControl__DATA_BUFFER_THLD_CTRL::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TX_BUF_THLD_bit_cg[bt])
    this.TX_BUF_THLD_bit_cg[bt].sample(TX_BUF_THLD.get_mirrored_value() >> bt);
    foreach (RX_BUF_THLD_bit_cg[bt])
    this.RX_BUF_THLD_bit_cg[bt].sample(RX_BUF_THLD.get_mirrored_value() >> bt);
    foreach (TX_START_THLD_bit_cg[bt])
    this.TX_START_THLD_bit_cg[bt].sample(TX_START_THLD.get_mirrored_value() >> bt);
    foreach (RX_START_THLD_bit_cg[bt])
    this.RX_START_THLD_bit_cg[bt].sample(RX_START_THLD.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(TX_BUF_THLD.get_mirrored_value(), RX_BUF_THLD.get_mirrored_value(),
                       TX_START_THLD.get_mirrored_value(), RX_START_THLD.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__PIOCONTROL__QUEUE_SIZE SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__PIOControl__QUEUE_SIZE::sample (uvm_reg_data_t data, uvm_reg_data_t byte_en,
                                                      bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (CR_QUEUE_SIZE_bit_cg[bt]) this.CR_QUEUE_SIZE_bit_cg[bt].sample(data[0+bt]);
    foreach (IBI_STATUS_SIZE_bit_cg[bt]) this.IBI_STATUS_SIZE_bit_cg[bt].sample(data[8+bt]);
    foreach (RX_DATA_BUFFER_SIZE_bit_cg[bt])
    this.RX_DATA_BUFFER_SIZE_bit_cg[bt].sample(data[16+bt]);
    foreach (TX_DATA_BUFFER_SIZE_bit_cg[bt])
    this.TX_DATA_BUFFER_SIZE_bit_cg[bt].sample(data[24+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[7:0]  /*CR_QUEUE_SIZE*/, data[15:8]  /*IBI_STATUS_SIZE*/,
                       data[23:16]  /*RX_DATA_BUFFER_SIZE*/, data[31:24]  /*TX_DATA_BUFFER_SIZE*/);
  end
endfunction

function void I3CCSR__PIOControl__QUEUE_SIZE::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (CR_QUEUE_SIZE_bit_cg[bt])
    this.CR_QUEUE_SIZE_bit_cg[bt].sample(CR_QUEUE_SIZE.get_mirrored_value() >> bt);
    foreach (IBI_STATUS_SIZE_bit_cg[bt])
    this.IBI_STATUS_SIZE_bit_cg[bt].sample(IBI_STATUS_SIZE.get_mirrored_value() >> bt);
    foreach (RX_DATA_BUFFER_SIZE_bit_cg[bt])
    this.RX_DATA_BUFFER_SIZE_bit_cg[bt].sample(RX_DATA_BUFFER_SIZE.get_mirrored_value() >> bt);
    foreach (TX_DATA_BUFFER_SIZE_bit_cg[bt])
    this.TX_DATA_BUFFER_SIZE_bit_cg[bt].sample(TX_DATA_BUFFER_SIZE.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(CR_QUEUE_SIZE.get_mirrored_value(), IBI_STATUS_SIZE.get_mirrored_value(),
                       RX_DATA_BUFFER_SIZE.get_mirrored_value(),
                       TX_DATA_BUFFER_SIZE.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__PIOCONTROL__ALT_QUEUE_SIZE SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__PIOControl__ALT_QUEUE_SIZE::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (ALT_RESP_QUEUE_SIZE_bit_cg[bt]) this.ALT_RESP_QUEUE_SIZE_bit_cg[bt].sample(data[0+bt]);
    foreach (ALT_RESP_QUEUE_EN_bit_cg[bt]) this.ALT_RESP_QUEUE_EN_bit_cg[bt].sample(data[24+bt]);
    foreach (EXT_IBI_QUEUE_EN_bit_cg[bt]) this.EXT_IBI_QUEUE_EN_bit_cg[bt].sample(data[28+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[7:0]  /*ALT_RESP_QUEUE_SIZE*/, data[24:24]  /*ALT_RESP_QUEUE_EN*/,
                       data[28:28]  /*EXT_IBI_QUEUE_EN*/);
  end
endfunction

function void I3CCSR__PIOControl__ALT_QUEUE_SIZE::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (ALT_RESP_QUEUE_SIZE_bit_cg[bt])
    this.ALT_RESP_QUEUE_SIZE_bit_cg[bt].sample(ALT_RESP_QUEUE_SIZE.get_mirrored_value() >> bt);
    foreach (ALT_RESP_QUEUE_EN_bit_cg[bt])
    this.ALT_RESP_QUEUE_EN_bit_cg[bt].sample(ALT_RESP_QUEUE_EN.get_mirrored_value() >> bt);
    foreach (EXT_IBI_QUEUE_EN_bit_cg[bt])
    this.EXT_IBI_QUEUE_EN_bit_cg[bt].sample(EXT_IBI_QUEUE_EN.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(ALT_RESP_QUEUE_SIZE.get_mirrored_value(),
                       ALT_RESP_QUEUE_EN.get_mirrored_value(),
                       EXT_IBI_QUEUE_EN.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_STATUS SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__PIOControl__PIO_INTR_STATUS::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TX_THLD_STAT_bit_cg[bt]) this.TX_THLD_STAT_bit_cg[bt].sample(data[0+bt]);
    foreach (RX_THLD_STAT_bit_cg[bt]) this.RX_THLD_STAT_bit_cg[bt].sample(data[1+bt]);
    foreach (IBI_STATUS_THLD_STAT_bit_cg[bt])
    this.IBI_STATUS_THLD_STAT_bit_cg[bt].sample(data[2+bt]);
    foreach (CMD_QUEUE_READY_STAT_bit_cg[bt])
    this.CMD_QUEUE_READY_STAT_bit_cg[bt].sample(data[3+bt]);
    foreach (RESP_READY_STAT_bit_cg[bt]) this.RESP_READY_STAT_bit_cg[bt].sample(data[4+bt]);
    foreach (TRANSFER_ABORT_STAT_bit_cg[bt]) this.TRANSFER_ABORT_STAT_bit_cg[bt].sample(data[5+bt]);
    foreach (TRANSFER_ERR_STAT_bit_cg[bt]) this.TRANSFER_ERR_STAT_bit_cg[bt].sample(data[9+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[0:0]  /*TX_THLD_STAT*/, data[1:1]  /*RX_THLD_STAT*/,
                       data[2:2]  /*IBI_STATUS_THLD_STAT*/, data[3:3]  /*CMD_QUEUE_READY_STAT*/,
                       data[4:4]  /*RESP_READY_STAT*/, data[5:5]  /*TRANSFER_ABORT_STAT*/,
                       data[9:9]  /*TRANSFER_ERR_STAT*/);
  end
endfunction

function void I3CCSR__PIOControl__PIO_INTR_STATUS::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TX_THLD_STAT_bit_cg[bt])
    this.TX_THLD_STAT_bit_cg[bt].sample(TX_THLD_STAT.get_mirrored_value() >> bt);
    foreach (RX_THLD_STAT_bit_cg[bt])
    this.RX_THLD_STAT_bit_cg[bt].sample(RX_THLD_STAT.get_mirrored_value() >> bt);
    foreach (IBI_STATUS_THLD_STAT_bit_cg[bt])
    this.IBI_STATUS_THLD_STAT_bit_cg[bt].sample(IBI_STATUS_THLD_STAT.get_mirrored_value() >> bt);
    foreach (CMD_QUEUE_READY_STAT_bit_cg[bt])
    this.CMD_QUEUE_READY_STAT_bit_cg[bt].sample(CMD_QUEUE_READY_STAT.get_mirrored_value() >> bt);
    foreach (RESP_READY_STAT_bit_cg[bt])
    this.RESP_READY_STAT_bit_cg[bt].sample(RESP_READY_STAT.get_mirrored_value() >> bt);
    foreach (TRANSFER_ABORT_STAT_bit_cg[bt])
    this.TRANSFER_ABORT_STAT_bit_cg[bt].sample(TRANSFER_ABORT_STAT.get_mirrored_value() >> bt);
    foreach (TRANSFER_ERR_STAT_bit_cg[bt])
    this.TRANSFER_ERR_STAT_bit_cg[bt].sample(TRANSFER_ERR_STAT.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(
        TX_THLD_STAT.get_mirrored_value(), RX_THLD_STAT.get_mirrored_value(),
        IBI_STATUS_THLD_STAT.get_mirrored_value(), CMD_QUEUE_READY_STAT.get_mirrored_value(),
        RESP_READY_STAT.get_mirrored_value(), TRANSFER_ABORT_STAT.get_mirrored_value(),
        TRANSFER_ERR_STAT.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_STATUS_ENABLE SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__PIOControl__PIO_INTR_STATUS_ENABLE::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TX_THLD_STAT_EN_bit_cg[bt]) this.TX_THLD_STAT_EN_bit_cg[bt].sample(data[0+bt]);
    foreach (RX_THLD_STAT_EN_bit_cg[bt]) this.RX_THLD_STAT_EN_bit_cg[bt].sample(data[1+bt]);
    foreach (IBI_STATUS_THLD_STAT_EN_bit_cg[bt])
    this.IBI_STATUS_THLD_STAT_EN_bit_cg[bt].sample(data[2+bt]);
    foreach (CMD_QUEUE_READY_STAT_EN_bit_cg[bt])
    this.CMD_QUEUE_READY_STAT_EN_bit_cg[bt].sample(data[3+bt]);
    foreach (RESP_READY_STAT_EN_bit_cg[bt]) this.RESP_READY_STAT_EN_bit_cg[bt].sample(data[4+bt]);
    foreach (TRANSFER_ABORT_STAT_EN_bit_cg[bt])
    this.TRANSFER_ABORT_STAT_EN_bit_cg[bt].sample(data[5+bt]);
    foreach (TRANSFER_ERR_STAT_EN_bit_cg[bt])
    this.TRANSFER_ERR_STAT_EN_bit_cg[bt].sample(data[9+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[0:0]  /*TX_THLD_STAT_EN*/, data[1:1]  /*RX_THLD_STAT_EN*/,
                       data[2:2]  /*IBI_STATUS_THLD_STAT_EN*/,
                       data[3:3]  /*CMD_QUEUE_READY_STAT_EN*/, data[4:4]  /*RESP_READY_STAT_EN*/,
                       data[5:5]  /*TRANSFER_ABORT_STAT_EN*/, data[9:9]  /*TRANSFER_ERR_STAT_EN*/);
  end
endfunction

function void I3CCSR__PIOControl__PIO_INTR_STATUS_ENABLE::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TX_THLD_STAT_EN_bit_cg[bt])
    this.TX_THLD_STAT_EN_bit_cg[bt].sample(TX_THLD_STAT_EN.get_mirrored_value() >> bt);
    foreach (RX_THLD_STAT_EN_bit_cg[bt])
    this.RX_THLD_STAT_EN_bit_cg[bt].sample(RX_THLD_STAT_EN.get_mirrored_value() >> bt);
    foreach (IBI_STATUS_THLD_STAT_EN_bit_cg[bt])
    this.IBI_STATUS_THLD_STAT_EN_bit_cg[bt].sample(
        IBI_STATUS_THLD_STAT_EN.get_mirrored_value() >> bt);
    foreach (CMD_QUEUE_READY_STAT_EN_bit_cg[bt])
    this.CMD_QUEUE_READY_STAT_EN_bit_cg[bt].sample(
        CMD_QUEUE_READY_STAT_EN.get_mirrored_value() >> bt);
    foreach (RESP_READY_STAT_EN_bit_cg[bt])
    this.RESP_READY_STAT_EN_bit_cg[bt].sample(RESP_READY_STAT_EN.get_mirrored_value() >> bt);
    foreach (TRANSFER_ABORT_STAT_EN_bit_cg[bt])
    this.TRANSFER_ABORT_STAT_EN_bit_cg[bt].sample(
        TRANSFER_ABORT_STAT_EN.get_mirrored_value() >> bt);
    foreach (TRANSFER_ERR_STAT_EN_bit_cg[bt])
    this.TRANSFER_ERR_STAT_EN_bit_cg[bt].sample(TRANSFER_ERR_STAT_EN.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(
        TX_THLD_STAT_EN.get_mirrored_value(), RX_THLD_STAT_EN.get_mirrored_value(),
        IBI_STATUS_THLD_STAT_EN.get_mirrored_value(), CMD_QUEUE_READY_STAT_EN.get_mirrored_value(),
        RESP_READY_STAT_EN.get_mirrored_value(), TRANSFER_ABORT_STAT_EN.get_mirrored_value(),
        TRANSFER_ERR_STAT_EN.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_SIGNAL_ENABLE SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__PIOControl__PIO_INTR_SIGNAL_ENABLE::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TX_THLD_SIGNAL_EN_bit_cg[bt]) this.TX_THLD_SIGNAL_EN_bit_cg[bt].sample(data[0+bt]);
    foreach (RX_THLD_SIGNAL_EN_bit_cg[bt]) this.RX_THLD_SIGNAL_EN_bit_cg[bt].sample(data[1+bt]);
    foreach (IBI_STATUS_THLD_SIGNAL_EN_bit_cg[bt])
    this.IBI_STATUS_THLD_SIGNAL_EN_bit_cg[bt].sample(data[2+bt]);
    foreach (CMD_QUEUE_READY_SIGNAL_EN_bit_cg[bt])
    this.CMD_QUEUE_READY_SIGNAL_EN_bit_cg[bt].sample(data[3+bt]);
    foreach (RESP_READY_SIGNAL_EN_bit_cg[bt])
    this.RESP_READY_SIGNAL_EN_bit_cg[bt].sample(data[4+bt]);
    foreach (TRANSFER_ABORT_SIGNAL_EN_bit_cg[bt])
    this.TRANSFER_ABORT_SIGNAL_EN_bit_cg[bt].sample(data[5+bt]);
    foreach (TRANSFER_ERR_SIGNAL_EN_bit_cg[bt])
    this.TRANSFER_ERR_SIGNAL_EN_bit_cg[bt].sample(data[9+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[0:0]  /*TX_THLD_SIGNAL_EN*/, data[1:1]  /*RX_THLD_SIGNAL_EN*/,
                       data[2:2]  /*IBI_STATUS_THLD_SIGNAL_EN*/,
                       data[3:3]  /*CMD_QUEUE_READY_SIGNAL_EN*/,
                       data[4:4]  /*RESP_READY_SIGNAL_EN*/, data[5:5]  /*TRANSFER_ABORT_SIGNAL_EN*/,
                       data[9:9]  /*TRANSFER_ERR_SIGNAL_EN*/);
  end
endfunction

function void I3CCSR__PIOControl__PIO_INTR_SIGNAL_ENABLE::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TX_THLD_SIGNAL_EN_bit_cg[bt])
    this.TX_THLD_SIGNAL_EN_bit_cg[bt].sample(TX_THLD_SIGNAL_EN.get_mirrored_value() >> bt);
    foreach (RX_THLD_SIGNAL_EN_bit_cg[bt])
    this.RX_THLD_SIGNAL_EN_bit_cg[bt].sample(RX_THLD_SIGNAL_EN.get_mirrored_value() >> bt);
    foreach (IBI_STATUS_THLD_SIGNAL_EN_bit_cg[bt])
    this.IBI_STATUS_THLD_SIGNAL_EN_bit_cg[bt].sample(
        IBI_STATUS_THLD_SIGNAL_EN.get_mirrored_value() >> bt);
    foreach (CMD_QUEUE_READY_SIGNAL_EN_bit_cg[bt])
    this.CMD_QUEUE_READY_SIGNAL_EN_bit_cg[bt].sample(
        CMD_QUEUE_READY_SIGNAL_EN.get_mirrored_value() >> bt);
    foreach (RESP_READY_SIGNAL_EN_bit_cg[bt])
    this.RESP_READY_SIGNAL_EN_bit_cg[bt].sample(RESP_READY_SIGNAL_EN.get_mirrored_value() >> bt);
    foreach (TRANSFER_ABORT_SIGNAL_EN_bit_cg[bt])
    this.TRANSFER_ABORT_SIGNAL_EN_bit_cg[bt].sample(
        TRANSFER_ABORT_SIGNAL_EN.get_mirrored_value() >> bt);
    foreach (TRANSFER_ERR_SIGNAL_EN_bit_cg[bt])
    this.TRANSFER_ERR_SIGNAL_EN_bit_cg[bt].sample(
        TRANSFER_ERR_SIGNAL_EN.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(
        TX_THLD_SIGNAL_EN.get_mirrored_value(), RX_THLD_SIGNAL_EN.get_mirrored_value(),
        IBI_STATUS_THLD_SIGNAL_EN.get_mirrored_value(),
        CMD_QUEUE_READY_SIGNAL_EN.get_mirrored_value(), RESP_READY_SIGNAL_EN.get_mirrored_value(),
        TRANSFER_ABORT_SIGNAL_EN.get_mirrored_value(), TRANSFER_ERR_SIGNAL_EN.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_FORCE SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__PIOControl__PIO_INTR_FORCE::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TX_THLD_FORCE_bit_cg[bt]) this.TX_THLD_FORCE_bit_cg[bt].sample(data[0+bt]);
    foreach (RX_THLD_FORCE_bit_cg[bt]) this.RX_THLD_FORCE_bit_cg[bt].sample(data[1+bt]);
    foreach (IBI_THLD_FORCE_bit_cg[bt]) this.IBI_THLD_FORCE_bit_cg[bt].sample(data[2+bt]);
    foreach (CMD_QUEUE_READY_FORCE_bit_cg[bt])
    this.CMD_QUEUE_READY_FORCE_bit_cg[bt].sample(data[3+bt]);
    foreach (RESP_READY_FORCE_bit_cg[bt]) this.RESP_READY_FORCE_bit_cg[bt].sample(data[4+bt]);
    foreach (TRANSFER_ABORT_FORCE_bit_cg[bt])
    this.TRANSFER_ABORT_FORCE_bit_cg[bt].sample(data[5+bt]);
    foreach (TRANSFER_ERR_FORCE_bit_cg[bt]) this.TRANSFER_ERR_FORCE_bit_cg[bt].sample(data[9+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[0:0]  /*TX_THLD_FORCE*/, data[1:1]  /*RX_THLD_FORCE*/,
                       data[2:2]  /*IBI_THLD_FORCE*/, data[3:3]  /*CMD_QUEUE_READY_FORCE*/,
                       data[4:4]  /*RESP_READY_FORCE*/, data[5:5]  /*TRANSFER_ABORT_FORCE*/,
                       data[9:9]  /*TRANSFER_ERR_FORCE*/);
  end
endfunction

function void I3CCSR__PIOControl__PIO_INTR_FORCE::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (TX_THLD_FORCE_bit_cg[bt])
    this.TX_THLD_FORCE_bit_cg[bt].sample(TX_THLD_FORCE.get_mirrored_value() >> bt);
    foreach (RX_THLD_FORCE_bit_cg[bt])
    this.RX_THLD_FORCE_bit_cg[bt].sample(RX_THLD_FORCE.get_mirrored_value() >> bt);
    foreach (IBI_THLD_FORCE_bit_cg[bt])
    this.IBI_THLD_FORCE_bit_cg[bt].sample(IBI_THLD_FORCE.get_mirrored_value() >> bt);
    foreach (CMD_QUEUE_READY_FORCE_bit_cg[bt])
    this.CMD_QUEUE_READY_FORCE_bit_cg[bt].sample(CMD_QUEUE_READY_FORCE.get_mirrored_value() >> bt);
    foreach (RESP_READY_FORCE_bit_cg[bt])
    this.RESP_READY_FORCE_bit_cg[bt].sample(RESP_READY_FORCE.get_mirrored_value() >> bt);
    foreach (TRANSFER_ABORT_FORCE_bit_cg[bt])
    this.TRANSFER_ABORT_FORCE_bit_cg[bt].sample(TRANSFER_ABORT_FORCE.get_mirrored_value() >> bt);
    foreach (TRANSFER_ERR_FORCE_bit_cg[bt])
    this.TRANSFER_ERR_FORCE_bit_cg[bt].sample(TRANSFER_ERR_FORCE.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(
        TX_THLD_FORCE.get_mirrored_value(), RX_THLD_FORCE.get_mirrored_value(),
        IBI_THLD_FORCE.get_mirrored_value(), CMD_QUEUE_READY_FORCE.get_mirrored_value(),
        RESP_READY_FORCE.get_mirrored_value(), TRANSFER_ABORT_FORCE.get_mirrored_value(),
        TRANSFER_ERR_FORCE.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__PIOCONTROL__PIO_CONTROL SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__PIOControl__PIO_CONTROL::sample (uvm_reg_data_t data, uvm_reg_data_t byte_en,
                                                       bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (ENABLE_bit_cg[bt]) this.ENABLE_bit_cg[bt].sample(data[0+bt]);
    foreach (RS_bit_cg[bt]) this.RS_bit_cg[bt].sample(data[1+bt]);
    foreach (ABORT_bit_cg[bt]) this.ABORT_bit_cg[bt].sample(data[2+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[0:0]  /*ENABLE*/, data[1:1]  /*RS*/, data[2:2]  /*ABORT*/);
  end
endfunction

function void I3CCSR__PIOControl__PIO_CONTROL::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (ENABLE_bit_cg[bt]) this.ENABLE_bit_cg[bt].sample(ENABLE.get_mirrored_value() >> bt);
    foreach (RS_bit_cg[bt]) this.RS_bit_cg[bt].sample(RS.get_mirrored_value() >> bt);
    foreach (ABORT_bit_cg[bt]) this.ABORT_bit_cg[bt].sample(ABORT.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(ENABLE.get_mirrored_value(), RS.get_mirrored_value(),
                       ABORT.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__EXTCAP_HEADER SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__EXTCAP_HEADER::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(data[0+bt]);
    foreach (CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(data[8+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[7:0]  /*CAP_ID*/, data[23:8]  /*CAP_LENGTH*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__EXTCAP_HEADER::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(CAP_ID.get_mirrored_value() >> bt);
    foreach (CAP_LENGTH_bit_cg[bt])
    this.CAP_LENGTH_bit_cg[bt].sample(CAP_LENGTH.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(CAP_ID.get_mirrored_value(), CAP_LENGTH.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__PROT_CAP_0 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_0::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_0::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__PROT_CAP_1 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_1::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_1::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__PROT_CAP_2 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_2::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_2::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__PROT_CAP_3 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_3::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__PROT_CAP_3::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_ID_0 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_0::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_0::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_ID_1 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_1::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_1::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_ID_2 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_2::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_2::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_ID_3 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_3::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_3::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_ID_4 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_4::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_4::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_ID_5 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_5::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_5::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_ID_6 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_6::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_ID_6::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_STATUS_0 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_STATUS_0::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_STATUS_0::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_STATUS_1 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_STATUS_1::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_STATUS_1::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__DEVICE_RESET SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_RESET::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__DEVICE_RESET::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__RECOVERY_CTRL SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__RECOVERY_CTRL::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__RECOVERY_CTRL::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__RECOVERY_STATUS SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__RECOVERY_STATUS::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__RECOVERY_STATUS::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__HW_STATUS SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__HW_STATUS::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__HW_STATUS::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_CTRL_0 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_CTRL_0::sample(
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_CTRL_0::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_CTRL_1 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_CTRL_1::sample(
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_CTRL_1::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_STATUS_0 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_0::sample(
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_0::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_STATUS_1 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_1::sample(
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_1::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_STATUS_2 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_2::sample(
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_2::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_STATUS_3 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_3::sample(
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_3::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_STATUS_4 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_4::sample(
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_4::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_STATUS_5 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_5::sample(
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_STATUS_5::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SECUREFIRMWARERECOVERYINTERFACEREGISTERS__INDIRECT_FIFO_DATA SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_DATA::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SecureFirmwareRecoveryInterfaceRegisters__INDIRECT_FIFO_DATA::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__TARGETTRANSACTIONINTERFACEREGISTERS__EXTCAP_HEADER SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__TargetTransactionInterfaceRegisters__EXTCAP_HEADER::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(data[0+bt]);
    foreach (CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(data[8+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[7:0]  /*CAP_ID*/, data[23:8]  /*CAP_LENGTH*/);
  end
endfunction

function void I3CCSR__I3C_EC__TargetTransactionInterfaceRegisters__EXTCAP_HEADER::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(CAP_ID.get_mirrored_value() >> bt);
    foreach (CAP_LENGTH_bit_cg[bt])
    this.CAP_LENGTH_bit_cg[bt].sample(CAP_LENGTH.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(CAP_ID.get_mirrored_value(), CAP_LENGTH.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__TARGETTRANSACTIONINTERFACEREGISTERS__PLACE_HOLDER_1 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__TargetTransactionInterfaceRegisters__PLACE_HOLDER_1::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__TargetTransactionInterfaceRegisters__PLACE_HOLDER_1::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SOCMANAGEMENTINTERFACEREGISTERS__EXTCAP_HEADER SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SoCManagementInterfaceRegisters__EXTCAP_HEADER::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(data[0+bt]);
    foreach (CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(data[8+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[7:0]  /*CAP_ID*/, data[23:8]  /*CAP_LENGTH*/);
  end
endfunction

function void I3CCSR__I3C_EC__SoCManagementInterfaceRegisters__EXTCAP_HEADER::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(CAP_ID.get_mirrored_value() >> bt);
    foreach (CAP_LENGTH_bit_cg[bt])
    this.CAP_LENGTH_bit_cg[bt].sample(CAP_LENGTH.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(CAP_ID.get_mirrored_value(), CAP_LENGTH.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__SOCMANAGEMENTINTERFACEREGISTERS__PLACE_HOLDER_1 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__SoCManagementInterfaceRegisters__PLACE_HOLDER_1::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__SoCManagementInterfaceRegisters__PLACE_HOLDER_1::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__CONTROLLERCONFIGREGISTERS__EXTCAP_HEADER SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__ControllerConfigRegisters__EXTCAP_HEADER::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(data[0+bt]);
    foreach (CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(data[8+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[7:0]  /*CAP_ID*/, data[23:8]  /*CAP_LENGTH*/);
  end
endfunction

function void I3CCSR__I3C_EC__ControllerConfigRegisters__EXTCAP_HEADER::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(CAP_ID.get_mirrored_value() >> bt);
    foreach (CAP_LENGTH_bit_cg[bt])
    this.CAP_LENGTH_bit_cg[bt].sample(CAP_LENGTH.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(CAP_ID.get_mirrored_value(), CAP_LENGTH.get_mirrored_value());
  end
endfunction

/*----------------------- I3CCSR__I3C_EC__CONTROLLERCONFIGREGISTERS__PLACE_HOLDER_1 SAMPLE FUNCTIONS -----------------------*/
function void I3CCSR__I3C_EC__ControllerConfigRegisters__PLACE_HOLDER_1::sample (
    uvm_reg_data_t data, uvm_reg_data_t byte_en, bit is_read, uvm_reg_map map);
  m_current = get();
  m_data    = data;
  m_is_read = is_read;
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0+bt]);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(data[31:0]  /*PLACEHOLDER*/);
  end
endfunction

function void I3CCSR__I3C_EC__ControllerConfigRegisters__PLACE_HOLDER_1::sample_values();
  if (get_coverage(UVM_CVR_REG_BITS)) begin
    foreach (PLACEHOLDER_bit_cg[bt])
    this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
  end
  if (get_coverage(UVM_CVR_FIELD_VALS)) begin
    this.fld_cg.sample(PLACEHOLDER.get_mirrored_value());
  end
endfunction

`endif
