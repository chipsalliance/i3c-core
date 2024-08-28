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
    function void I3CCSR__I3CBase__HCI_VERSION::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(VERSION_bit_cg[bt]) this.VERSION_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*VERSION*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__HCI_VERSION::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(VERSION_bit_cg[bt]) this.VERSION_bit_cg[bt].sample(VERSION.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( VERSION.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__HC_CONTROL SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__HC_CONTROL::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(IBA_INCLUDE_bit_cg[bt]) this.IBA_INCLUDE_bit_cg[bt].sample(data[0 + bt]);
            foreach(AUTOCMD_DATA_RPT_bit_cg[bt]) this.AUTOCMD_DATA_RPT_bit_cg[bt].sample(data[3 + bt]);
            foreach(DATA_BYTE_ORDER_MODE_bit_cg[bt]) this.DATA_BYTE_ORDER_MODE_bit_cg[bt].sample(data[4 + bt]);
            foreach(MODE_SELECTOR_bit_cg[bt]) this.MODE_SELECTOR_bit_cg[bt].sample(data[6 + bt]);
            foreach(I2C_DEV_PRESENT_bit_cg[bt]) this.I2C_DEV_PRESENT_bit_cg[bt].sample(data[7 + bt]);
            foreach(HOT_JOIN_CTRL_bit_cg[bt]) this.HOT_JOIN_CTRL_bit_cg[bt].sample(data[8 + bt]);
            foreach(HALT_ON_CMD_SEQ_TIMEOUT_bit_cg[bt]) this.HALT_ON_CMD_SEQ_TIMEOUT_bit_cg[bt].sample(data[12 + bt]);
            foreach(ABORT_bit_cg[bt]) this.ABORT_bit_cg[bt].sample(data[29 + bt]);
            foreach(RESUME_bit_cg[bt]) this.RESUME_bit_cg[bt].sample(data[30 + bt]);
            foreach(BUS_ENABLE_bit_cg[bt]) this.BUS_ENABLE_bit_cg[bt].sample(data[31 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*IBA_INCLUDE*/  ,  data[3:3]/*AUTOCMD_DATA_RPT*/  ,  data[4:4]/*DATA_BYTE_ORDER_MODE*/  ,  data[6:6]/*MODE_SELECTOR*/  ,  data[7:7]/*I2C_DEV_PRESENT*/  ,  data[8:8]/*HOT_JOIN_CTRL*/  ,  data[12:12]/*HALT_ON_CMD_SEQ_TIMEOUT*/  ,  data[29:29]/*ABORT*/  ,  data[30:30]/*RESUME*/  ,  data[31:31]/*BUS_ENABLE*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__HC_CONTROL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(IBA_INCLUDE_bit_cg[bt]) this.IBA_INCLUDE_bit_cg[bt].sample(IBA_INCLUDE.get_mirrored_value() >> bt);
            foreach(AUTOCMD_DATA_RPT_bit_cg[bt]) this.AUTOCMD_DATA_RPT_bit_cg[bt].sample(AUTOCMD_DATA_RPT.get_mirrored_value() >> bt);
            foreach(DATA_BYTE_ORDER_MODE_bit_cg[bt]) this.DATA_BYTE_ORDER_MODE_bit_cg[bt].sample(DATA_BYTE_ORDER_MODE.get_mirrored_value() >> bt);
            foreach(MODE_SELECTOR_bit_cg[bt]) this.MODE_SELECTOR_bit_cg[bt].sample(MODE_SELECTOR.get_mirrored_value() >> bt);
            foreach(I2C_DEV_PRESENT_bit_cg[bt]) this.I2C_DEV_PRESENT_bit_cg[bt].sample(I2C_DEV_PRESENT.get_mirrored_value() >> bt);
            foreach(HOT_JOIN_CTRL_bit_cg[bt]) this.HOT_JOIN_CTRL_bit_cg[bt].sample(HOT_JOIN_CTRL.get_mirrored_value() >> bt);
            foreach(HALT_ON_CMD_SEQ_TIMEOUT_bit_cg[bt]) this.HALT_ON_CMD_SEQ_TIMEOUT_bit_cg[bt].sample(HALT_ON_CMD_SEQ_TIMEOUT.get_mirrored_value() >> bt);
            foreach(ABORT_bit_cg[bt]) this.ABORT_bit_cg[bt].sample(ABORT.get_mirrored_value() >> bt);
            foreach(RESUME_bit_cg[bt]) this.RESUME_bit_cg[bt].sample(RESUME.get_mirrored_value() >> bt);
            foreach(BUS_ENABLE_bit_cg[bt]) this.BUS_ENABLE_bit_cg[bt].sample(BUS_ENABLE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( IBA_INCLUDE.get_mirrored_value()  ,  AUTOCMD_DATA_RPT.get_mirrored_value()  ,  DATA_BYTE_ORDER_MODE.get_mirrored_value()  ,  MODE_SELECTOR.get_mirrored_value()  ,  I2C_DEV_PRESENT.get_mirrored_value()  ,  HOT_JOIN_CTRL.get_mirrored_value()  ,  HALT_ON_CMD_SEQ_TIMEOUT.get_mirrored_value()  ,  ABORT.get_mirrored_value()  ,  RESUME.get_mirrored_value()  ,  BUS_ENABLE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__CONTROLLER_DEVICE_ADDR SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__CONTROLLER_DEVICE_ADDR::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DYNAMIC_ADDR_bit_cg[bt]) this.DYNAMIC_ADDR_bit_cg[bt].sample(data[16 + bt]);
            foreach(DYNAMIC_ADDR_VALID_bit_cg[bt]) this.DYNAMIC_ADDR_VALID_bit_cg[bt].sample(data[31 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[22:16]/*DYNAMIC_ADDR*/  ,  data[31:31]/*DYNAMIC_ADDR_VALID*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__CONTROLLER_DEVICE_ADDR::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DYNAMIC_ADDR_bit_cg[bt]) this.DYNAMIC_ADDR_bit_cg[bt].sample(DYNAMIC_ADDR.get_mirrored_value() >> bt);
            foreach(DYNAMIC_ADDR_VALID_bit_cg[bt]) this.DYNAMIC_ADDR_VALID_bit_cg[bt].sample(DYNAMIC_ADDR_VALID.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( DYNAMIC_ADDR.get_mirrored_value()  ,  DYNAMIC_ADDR_VALID.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__HC_CAPABILITIES SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__HC_CAPABILITIES::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(COMBO_COMMAND_bit_cg[bt]) this.COMBO_COMMAND_bit_cg[bt].sample(data[2 + bt]);
            foreach(AUTO_COMMAND_bit_cg[bt]) this.AUTO_COMMAND_bit_cg[bt].sample(data[3 + bt]);
            foreach(STANDBY_CR_CAP_bit_cg[bt]) this.STANDBY_CR_CAP_bit_cg[bt].sample(data[5 + bt]);
            foreach(HDR_DDR_EN_bit_cg[bt]) this.HDR_DDR_EN_bit_cg[bt].sample(data[6 + bt]);
            foreach(HDR_TS_EN_bit_cg[bt]) this.HDR_TS_EN_bit_cg[bt].sample(data[7 + bt]);
            foreach(CMD_CCC_DEFBYTE_bit_cg[bt]) this.CMD_CCC_DEFBYTE_bit_cg[bt].sample(data[10 + bt]);
            foreach(IBI_DATA_ABORT_EN_bit_cg[bt]) this.IBI_DATA_ABORT_EN_bit_cg[bt].sample(data[11 + bt]);
            foreach(IBI_CREDIT_COUNT_EN_bit_cg[bt]) this.IBI_CREDIT_COUNT_EN_bit_cg[bt].sample(data[12 + bt]);
            foreach(SCHEDULED_COMMANDS_EN_bit_cg[bt]) this.SCHEDULED_COMMANDS_EN_bit_cg[bt].sample(data[13 + bt]);
            foreach(CMD_SIZE_bit_cg[bt]) this.CMD_SIZE_bit_cg[bt].sample(data[20 + bt]);
            foreach(SG_CAPABILITY_CR_EN_bit_cg[bt]) this.SG_CAPABILITY_CR_EN_bit_cg[bt].sample(data[28 + bt]);
            foreach(SG_CAPABILITY_IBI_EN_bit_cg[bt]) this.SG_CAPABILITY_IBI_EN_bit_cg[bt].sample(data[29 + bt]);
            foreach(SG_CAPABILITY_DC_EN_bit_cg[bt]) this.SG_CAPABILITY_DC_EN_bit_cg[bt].sample(data[30 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[2:2]/*COMBO_COMMAND*/  ,  data[3:3]/*AUTO_COMMAND*/  ,  data[5:5]/*STANDBY_CR_CAP*/  ,  data[6:6]/*HDR_DDR_EN*/  ,  data[7:7]/*HDR_TS_EN*/  ,  data[10:10]/*CMD_CCC_DEFBYTE*/  ,  data[11:11]/*IBI_DATA_ABORT_EN*/  ,  data[12:12]/*IBI_CREDIT_COUNT_EN*/  ,  data[13:13]/*SCHEDULED_COMMANDS_EN*/  ,  data[21:20]/*CMD_SIZE*/  ,  data[28:28]/*SG_CAPABILITY_CR_EN*/  ,  data[29:29]/*SG_CAPABILITY_IBI_EN*/  ,  data[30:30]/*SG_CAPABILITY_DC_EN*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__HC_CAPABILITIES::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(COMBO_COMMAND_bit_cg[bt]) this.COMBO_COMMAND_bit_cg[bt].sample(COMBO_COMMAND.get_mirrored_value() >> bt);
            foreach(AUTO_COMMAND_bit_cg[bt]) this.AUTO_COMMAND_bit_cg[bt].sample(AUTO_COMMAND.get_mirrored_value() >> bt);
            foreach(STANDBY_CR_CAP_bit_cg[bt]) this.STANDBY_CR_CAP_bit_cg[bt].sample(STANDBY_CR_CAP.get_mirrored_value() >> bt);
            foreach(HDR_DDR_EN_bit_cg[bt]) this.HDR_DDR_EN_bit_cg[bt].sample(HDR_DDR_EN.get_mirrored_value() >> bt);
            foreach(HDR_TS_EN_bit_cg[bt]) this.HDR_TS_EN_bit_cg[bt].sample(HDR_TS_EN.get_mirrored_value() >> bt);
            foreach(CMD_CCC_DEFBYTE_bit_cg[bt]) this.CMD_CCC_DEFBYTE_bit_cg[bt].sample(CMD_CCC_DEFBYTE.get_mirrored_value() >> bt);
            foreach(IBI_DATA_ABORT_EN_bit_cg[bt]) this.IBI_DATA_ABORT_EN_bit_cg[bt].sample(IBI_DATA_ABORT_EN.get_mirrored_value() >> bt);
            foreach(IBI_CREDIT_COUNT_EN_bit_cg[bt]) this.IBI_CREDIT_COUNT_EN_bit_cg[bt].sample(IBI_CREDIT_COUNT_EN.get_mirrored_value() >> bt);
            foreach(SCHEDULED_COMMANDS_EN_bit_cg[bt]) this.SCHEDULED_COMMANDS_EN_bit_cg[bt].sample(SCHEDULED_COMMANDS_EN.get_mirrored_value() >> bt);
            foreach(CMD_SIZE_bit_cg[bt]) this.CMD_SIZE_bit_cg[bt].sample(CMD_SIZE.get_mirrored_value() >> bt);
            foreach(SG_CAPABILITY_CR_EN_bit_cg[bt]) this.SG_CAPABILITY_CR_EN_bit_cg[bt].sample(SG_CAPABILITY_CR_EN.get_mirrored_value() >> bt);
            foreach(SG_CAPABILITY_IBI_EN_bit_cg[bt]) this.SG_CAPABILITY_IBI_EN_bit_cg[bt].sample(SG_CAPABILITY_IBI_EN.get_mirrored_value() >> bt);
            foreach(SG_CAPABILITY_DC_EN_bit_cg[bt]) this.SG_CAPABILITY_DC_EN_bit_cg[bt].sample(SG_CAPABILITY_DC_EN.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( COMBO_COMMAND.get_mirrored_value()  ,  AUTO_COMMAND.get_mirrored_value()  ,  STANDBY_CR_CAP.get_mirrored_value()  ,  HDR_DDR_EN.get_mirrored_value()  ,  HDR_TS_EN.get_mirrored_value()  ,  CMD_CCC_DEFBYTE.get_mirrored_value()  ,  IBI_DATA_ABORT_EN.get_mirrored_value()  ,  IBI_CREDIT_COUNT_EN.get_mirrored_value()  ,  SCHEDULED_COMMANDS_EN.get_mirrored_value()  ,  CMD_SIZE.get_mirrored_value()  ,  SG_CAPABILITY_CR_EN.get_mirrored_value()  ,  SG_CAPABILITY_IBI_EN.get_mirrored_value()  ,  SG_CAPABILITY_DC_EN.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__RESET_CONTROL SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__RESET_CONTROL::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(SOFT_RST_bit_cg[bt]) this.SOFT_RST_bit_cg[bt].sample(data[0 + bt]);
            foreach(CMD_QUEUE_RST_bit_cg[bt]) this.CMD_QUEUE_RST_bit_cg[bt].sample(data[1 + bt]);
            foreach(RESP_QUEUE_RST_bit_cg[bt]) this.RESP_QUEUE_RST_bit_cg[bt].sample(data[2 + bt]);
            foreach(TX_FIFO_RST_bit_cg[bt]) this.TX_FIFO_RST_bit_cg[bt].sample(data[3 + bt]);
            foreach(RX_FIFO_RST_bit_cg[bt]) this.RX_FIFO_RST_bit_cg[bt].sample(data[4 + bt]);
            foreach(IBI_QUEUE_RST_bit_cg[bt]) this.IBI_QUEUE_RST_bit_cg[bt].sample(data[5 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*SOFT_RST*/  ,  data[1:1]/*CMD_QUEUE_RST*/  ,  data[2:2]/*RESP_QUEUE_RST*/  ,  data[3:3]/*TX_FIFO_RST*/  ,  data[4:4]/*RX_FIFO_RST*/  ,  data[5:5]/*IBI_QUEUE_RST*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__RESET_CONTROL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(SOFT_RST_bit_cg[bt]) this.SOFT_RST_bit_cg[bt].sample(SOFT_RST.get_mirrored_value() >> bt);
            foreach(CMD_QUEUE_RST_bit_cg[bt]) this.CMD_QUEUE_RST_bit_cg[bt].sample(CMD_QUEUE_RST.get_mirrored_value() >> bt);
            foreach(RESP_QUEUE_RST_bit_cg[bt]) this.RESP_QUEUE_RST_bit_cg[bt].sample(RESP_QUEUE_RST.get_mirrored_value() >> bt);
            foreach(TX_FIFO_RST_bit_cg[bt]) this.TX_FIFO_RST_bit_cg[bt].sample(TX_FIFO_RST.get_mirrored_value() >> bt);
            foreach(RX_FIFO_RST_bit_cg[bt]) this.RX_FIFO_RST_bit_cg[bt].sample(RX_FIFO_RST.get_mirrored_value() >> bt);
            foreach(IBI_QUEUE_RST_bit_cg[bt]) this.IBI_QUEUE_RST_bit_cg[bt].sample(IBI_QUEUE_RST.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( SOFT_RST.get_mirrored_value()  ,  CMD_QUEUE_RST.get_mirrored_value()  ,  RESP_QUEUE_RST.get_mirrored_value()  ,  TX_FIFO_RST.get_mirrored_value()  ,  RX_FIFO_RST.get_mirrored_value()  ,  IBI_QUEUE_RST.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__PRESENT_STATE SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__PRESENT_STATE::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(AC_CURRENT_OWN_bit_cg[bt]) this.AC_CURRENT_OWN_bit_cg[bt].sample(data[2 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[2:2]/*AC_CURRENT_OWN*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__PRESENT_STATE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(AC_CURRENT_OWN_bit_cg[bt]) this.AC_CURRENT_OWN_bit_cg[bt].sample(AC_CURRENT_OWN.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( AC_CURRENT_OWN.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__INTR_STATUS SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__INTR_STATUS::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(HC_INTERNAL_ERR_STAT_bit_cg[bt]) this.HC_INTERNAL_ERR_STAT_bit_cg[bt].sample(data[10 + bt]);
            foreach(HC_SEQ_CANCEL_STAT_bit_cg[bt]) this.HC_SEQ_CANCEL_STAT_bit_cg[bt].sample(data[11 + bt]);
            foreach(HC_WARN_CMD_SEQ_STALL_STAT_bit_cg[bt]) this.HC_WARN_CMD_SEQ_STALL_STAT_bit_cg[bt].sample(data[12 + bt]);
            foreach(HC_ERR_CMD_SEQ_TIMEOUT_STAT_bit_cg[bt]) this.HC_ERR_CMD_SEQ_TIMEOUT_STAT_bit_cg[bt].sample(data[13 + bt]);
            foreach(SCHED_CMD_MISSED_TICK_STAT_bit_cg[bt]) this.SCHED_CMD_MISSED_TICK_STAT_bit_cg[bt].sample(data[14 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[10:10]/*HC_INTERNAL_ERR_STAT*/  ,  data[11:11]/*HC_SEQ_CANCEL_STAT*/  ,  data[12:12]/*HC_WARN_CMD_SEQ_STALL_STAT*/  ,  data[13:13]/*HC_ERR_CMD_SEQ_TIMEOUT_STAT*/  ,  data[14:14]/*SCHED_CMD_MISSED_TICK_STAT*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__INTR_STATUS::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(HC_INTERNAL_ERR_STAT_bit_cg[bt]) this.HC_INTERNAL_ERR_STAT_bit_cg[bt].sample(HC_INTERNAL_ERR_STAT.get_mirrored_value() >> bt);
            foreach(HC_SEQ_CANCEL_STAT_bit_cg[bt]) this.HC_SEQ_CANCEL_STAT_bit_cg[bt].sample(HC_SEQ_CANCEL_STAT.get_mirrored_value() >> bt);
            foreach(HC_WARN_CMD_SEQ_STALL_STAT_bit_cg[bt]) this.HC_WARN_CMD_SEQ_STALL_STAT_bit_cg[bt].sample(HC_WARN_CMD_SEQ_STALL_STAT.get_mirrored_value() >> bt);
            foreach(HC_ERR_CMD_SEQ_TIMEOUT_STAT_bit_cg[bt]) this.HC_ERR_CMD_SEQ_TIMEOUT_STAT_bit_cg[bt].sample(HC_ERR_CMD_SEQ_TIMEOUT_STAT.get_mirrored_value() >> bt);
            foreach(SCHED_CMD_MISSED_TICK_STAT_bit_cg[bt]) this.SCHED_CMD_MISSED_TICK_STAT_bit_cg[bt].sample(SCHED_CMD_MISSED_TICK_STAT.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( HC_INTERNAL_ERR_STAT.get_mirrored_value()  ,  HC_SEQ_CANCEL_STAT.get_mirrored_value()  ,  HC_WARN_CMD_SEQ_STALL_STAT.get_mirrored_value()  ,  HC_ERR_CMD_SEQ_TIMEOUT_STAT.get_mirrored_value()  ,  SCHED_CMD_MISSED_TICK_STAT.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__INTR_STATUS_ENABLE SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__INTR_STATUS_ENABLE::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(HC_INTERNAL_ERR_STAT_EN_bit_cg[bt]) this.HC_INTERNAL_ERR_STAT_EN_bit_cg[bt].sample(data[10 + bt]);
            foreach(HC_SEQ_CANCEL_STAT_EN_bit_cg[bt]) this.HC_SEQ_CANCEL_STAT_EN_bit_cg[bt].sample(data[11 + bt]);
            foreach(HC_WARN_CMD_SEQ_STALL_STAT_EN_bit_cg[bt]) this.HC_WARN_CMD_SEQ_STALL_STAT_EN_bit_cg[bt].sample(data[12 + bt]);
            foreach(HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN_bit_cg[bt]) this.HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN_bit_cg[bt].sample(data[13 + bt]);
            foreach(SCHED_CMD_MISSED_TICK_STAT_EN_bit_cg[bt]) this.SCHED_CMD_MISSED_TICK_STAT_EN_bit_cg[bt].sample(data[14 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[10:10]/*HC_INTERNAL_ERR_STAT_EN*/  ,  data[11:11]/*HC_SEQ_CANCEL_STAT_EN*/  ,  data[12:12]/*HC_WARN_CMD_SEQ_STALL_STAT_EN*/  ,  data[13:13]/*HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN*/  ,  data[14:14]/*SCHED_CMD_MISSED_TICK_STAT_EN*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__INTR_STATUS_ENABLE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(HC_INTERNAL_ERR_STAT_EN_bit_cg[bt]) this.HC_INTERNAL_ERR_STAT_EN_bit_cg[bt].sample(HC_INTERNAL_ERR_STAT_EN.get_mirrored_value() >> bt);
            foreach(HC_SEQ_CANCEL_STAT_EN_bit_cg[bt]) this.HC_SEQ_CANCEL_STAT_EN_bit_cg[bt].sample(HC_SEQ_CANCEL_STAT_EN.get_mirrored_value() >> bt);
            foreach(HC_WARN_CMD_SEQ_STALL_STAT_EN_bit_cg[bt]) this.HC_WARN_CMD_SEQ_STALL_STAT_EN_bit_cg[bt].sample(HC_WARN_CMD_SEQ_STALL_STAT_EN.get_mirrored_value() >> bt);
            foreach(HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN_bit_cg[bt]) this.HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN_bit_cg[bt].sample(HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN.get_mirrored_value() >> bt);
            foreach(SCHED_CMD_MISSED_TICK_STAT_EN_bit_cg[bt]) this.SCHED_CMD_MISSED_TICK_STAT_EN_bit_cg[bt].sample(SCHED_CMD_MISSED_TICK_STAT_EN.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( HC_INTERNAL_ERR_STAT_EN.get_mirrored_value()  ,  HC_SEQ_CANCEL_STAT_EN.get_mirrored_value()  ,  HC_WARN_CMD_SEQ_STALL_STAT_EN.get_mirrored_value()  ,  HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN.get_mirrored_value()  ,  SCHED_CMD_MISSED_TICK_STAT_EN.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__INTR_SIGNAL_ENABLE SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__INTR_SIGNAL_ENABLE::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(HC_INTERNAL_ERR_SIGNAL_EN_bit_cg[bt]) this.HC_INTERNAL_ERR_SIGNAL_EN_bit_cg[bt].sample(data[10 + bt]);
            foreach(HC_SEQ_CANCEL_SIGNAL_EN_bit_cg[bt]) this.HC_SEQ_CANCEL_SIGNAL_EN_bit_cg[bt].sample(data[11 + bt]);
            foreach(HC_WARN_CMD_SEQ_STALL_SIGNAL_EN_bit_cg[bt]) this.HC_WARN_CMD_SEQ_STALL_SIGNAL_EN_bit_cg[bt].sample(data[12 + bt]);
            foreach(HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN_bit_cg[bt]) this.HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN_bit_cg[bt].sample(data[13 + bt]);
            foreach(SCHED_CMD_MISSED_TICK_SIGNAL_EN_bit_cg[bt]) this.SCHED_CMD_MISSED_TICK_SIGNAL_EN_bit_cg[bt].sample(data[14 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[10:10]/*HC_INTERNAL_ERR_SIGNAL_EN*/  ,  data[11:11]/*HC_SEQ_CANCEL_SIGNAL_EN*/  ,  data[12:12]/*HC_WARN_CMD_SEQ_STALL_SIGNAL_EN*/  ,  data[13:13]/*HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN*/  ,  data[14:14]/*SCHED_CMD_MISSED_TICK_SIGNAL_EN*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__INTR_SIGNAL_ENABLE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(HC_INTERNAL_ERR_SIGNAL_EN_bit_cg[bt]) this.HC_INTERNAL_ERR_SIGNAL_EN_bit_cg[bt].sample(HC_INTERNAL_ERR_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(HC_SEQ_CANCEL_SIGNAL_EN_bit_cg[bt]) this.HC_SEQ_CANCEL_SIGNAL_EN_bit_cg[bt].sample(HC_SEQ_CANCEL_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(HC_WARN_CMD_SEQ_STALL_SIGNAL_EN_bit_cg[bt]) this.HC_WARN_CMD_SEQ_STALL_SIGNAL_EN_bit_cg[bt].sample(HC_WARN_CMD_SEQ_STALL_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN_bit_cg[bt]) this.HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN_bit_cg[bt].sample(HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(SCHED_CMD_MISSED_TICK_SIGNAL_EN_bit_cg[bt]) this.SCHED_CMD_MISSED_TICK_SIGNAL_EN_bit_cg[bt].sample(SCHED_CMD_MISSED_TICK_SIGNAL_EN.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( HC_INTERNAL_ERR_SIGNAL_EN.get_mirrored_value()  ,  HC_SEQ_CANCEL_SIGNAL_EN.get_mirrored_value()  ,  HC_WARN_CMD_SEQ_STALL_SIGNAL_EN.get_mirrored_value()  ,  HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN.get_mirrored_value()  ,  SCHED_CMD_MISSED_TICK_SIGNAL_EN.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__INTR_FORCE SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__INTR_FORCE::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(HC_INTERNAL_ERR_FORCE_bit_cg[bt]) this.HC_INTERNAL_ERR_FORCE_bit_cg[bt].sample(data[10 + bt]);
            foreach(HC_SEQ_CANCEL_FORCE_bit_cg[bt]) this.HC_SEQ_CANCEL_FORCE_bit_cg[bt].sample(data[11 + bt]);
            foreach(HC_WARN_CMD_SEQ_STALL_FORCE_bit_cg[bt]) this.HC_WARN_CMD_SEQ_STALL_FORCE_bit_cg[bt].sample(data[12 + bt]);
            foreach(HC_ERR_CMD_SEQ_TIMEOUT_FORCE_bit_cg[bt]) this.HC_ERR_CMD_SEQ_TIMEOUT_FORCE_bit_cg[bt].sample(data[13 + bt]);
            foreach(SCHED_CMD_MISSED_TICK_FORCE_bit_cg[bt]) this.SCHED_CMD_MISSED_TICK_FORCE_bit_cg[bt].sample(data[14 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[10:10]/*HC_INTERNAL_ERR_FORCE*/  ,  data[11:11]/*HC_SEQ_CANCEL_FORCE*/  ,  data[12:12]/*HC_WARN_CMD_SEQ_STALL_FORCE*/  ,  data[13:13]/*HC_ERR_CMD_SEQ_TIMEOUT_FORCE*/  ,  data[14:14]/*SCHED_CMD_MISSED_TICK_FORCE*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__INTR_FORCE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(HC_INTERNAL_ERR_FORCE_bit_cg[bt]) this.HC_INTERNAL_ERR_FORCE_bit_cg[bt].sample(HC_INTERNAL_ERR_FORCE.get_mirrored_value() >> bt);
            foreach(HC_SEQ_CANCEL_FORCE_bit_cg[bt]) this.HC_SEQ_CANCEL_FORCE_bit_cg[bt].sample(HC_SEQ_CANCEL_FORCE.get_mirrored_value() >> bt);
            foreach(HC_WARN_CMD_SEQ_STALL_FORCE_bit_cg[bt]) this.HC_WARN_CMD_SEQ_STALL_FORCE_bit_cg[bt].sample(HC_WARN_CMD_SEQ_STALL_FORCE.get_mirrored_value() >> bt);
            foreach(HC_ERR_CMD_SEQ_TIMEOUT_FORCE_bit_cg[bt]) this.HC_ERR_CMD_SEQ_TIMEOUT_FORCE_bit_cg[bt].sample(HC_ERR_CMD_SEQ_TIMEOUT_FORCE.get_mirrored_value() >> bt);
            foreach(SCHED_CMD_MISSED_TICK_FORCE_bit_cg[bt]) this.SCHED_CMD_MISSED_TICK_FORCE_bit_cg[bt].sample(SCHED_CMD_MISSED_TICK_FORCE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( HC_INTERNAL_ERR_FORCE.get_mirrored_value()  ,  HC_SEQ_CANCEL_FORCE.get_mirrored_value()  ,  HC_WARN_CMD_SEQ_STALL_FORCE.get_mirrored_value()  ,  HC_ERR_CMD_SEQ_TIMEOUT_FORCE.get_mirrored_value()  ,  SCHED_CMD_MISSED_TICK_FORCE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__DAT_SECTION_OFFSET SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__DAT_SECTION_OFFSET::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TABLE_OFFSET_bit_cg[bt]) this.TABLE_OFFSET_bit_cg[bt].sample(data[0 + bt]);
            foreach(TABLE_SIZE_bit_cg[bt]) this.TABLE_SIZE_bit_cg[bt].sample(data[12 + bt]);
            foreach(ENTRY_SIZE_bit_cg[bt]) this.ENTRY_SIZE_bit_cg[bt].sample(data[28 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[11:0]/*TABLE_OFFSET*/  ,  data[18:12]/*TABLE_SIZE*/  ,  data[31:28]/*ENTRY_SIZE*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__DAT_SECTION_OFFSET::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TABLE_OFFSET_bit_cg[bt]) this.TABLE_OFFSET_bit_cg[bt].sample(TABLE_OFFSET.get_mirrored_value() >> bt);
            foreach(TABLE_SIZE_bit_cg[bt]) this.TABLE_SIZE_bit_cg[bt].sample(TABLE_SIZE.get_mirrored_value() >> bt);
            foreach(ENTRY_SIZE_bit_cg[bt]) this.ENTRY_SIZE_bit_cg[bt].sample(ENTRY_SIZE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( TABLE_OFFSET.get_mirrored_value()  ,  TABLE_SIZE.get_mirrored_value()  ,  ENTRY_SIZE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__DCT_SECTION_OFFSET SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__DCT_SECTION_OFFSET::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TABLE_OFFSET_bit_cg[bt]) this.TABLE_OFFSET_bit_cg[bt].sample(data[0 + bt]);
            foreach(TABLE_SIZE_bit_cg[bt]) this.TABLE_SIZE_bit_cg[bt].sample(data[12 + bt]);
            foreach(TABLE_INDEX_bit_cg[bt]) this.TABLE_INDEX_bit_cg[bt].sample(data[19 + bt]);
            foreach(ENTRY_SIZE_bit_cg[bt]) this.ENTRY_SIZE_bit_cg[bt].sample(data[28 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[11:0]/*TABLE_OFFSET*/  ,  data[18:12]/*TABLE_SIZE*/  ,  data[23:19]/*TABLE_INDEX*/  ,  data[31:28]/*ENTRY_SIZE*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__DCT_SECTION_OFFSET::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TABLE_OFFSET_bit_cg[bt]) this.TABLE_OFFSET_bit_cg[bt].sample(TABLE_OFFSET.get_mirrored_value() >> bt);
            foreach(TABLE_SIZE_bit_cg[bt]) this.TABLE_SIZE_bit_cg[bt].sample(TABLE_SIZE.get_mirrored_value() >> bt);
            foreach(TABLE_INDEX_bit_cg[bt]) this.TABLE_INDEX_bit_cg[bt].sample(TABLE_INDEX.get_mirrored_value() >> bt);
            foreach(ENTRY_SIZE_bit_cg[bt]) this.ENTRY_SIZE_bit_cg[bt].sample(ENTRY_SIZE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( TABLE_OFFSET.get_mirrored_value()  ,  TABLE_SIZE.get_mirrored_value()  ,  TABLE_INDEX.get_mirrored_value()  ,  ENTRY_SIZE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__RING_HEADERS_SECTION_OFFSET SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__RING_HEADERS_SECTION_OFFSET::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(SECTION_OFFSET_bit_cg[bt]) this.SECTION_OFFSET_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[15:0]/*SECTION_OFFSET*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__RING_HEADERS_SECTION_OFFSET::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(SECTION_OFFSET_bit_cg[bt]) this.SECTION_OFFSET_bit_cg[bt].sample(SECTION_OFFSET.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( SECTION_OFFSET.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__PIO_SECTION_OFFSET SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__PIO_SECTION_OFFSET::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(SECTION_OFFSET_bit_cg[bt]) this.SECTION_OFFSET_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[15:0]/*SECTION_OFFSET*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__PIO_SECTION_OFFSET::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(SECTION_OFFSET_bit_cg[bt]) this.SECTION_OFFSET_bit_cg[bt].sample(SECTION_OFFSET.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( SECTION_OFFSET.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__EXT_CAPS_SECTION_OFFSET SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__EXT_CAPS_SECTION_OFFSET::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(SECTION_OFFSET_bit_cg[bt]) this.SECTION_OFFSET_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[15:0]/*SECTION_OFFSET*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__EXT_CAPS_SECTION_OFFSET::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(SECTION_OFFSET_bit_cg[bt]) this.SECTION_OFFSET_bit_cg[bt].sample(SECTION_OFFSET.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( SECTION_OFFSET.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__INT_CTRL_CMDS_EN SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__INT_CTRL_CMDS_EN::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(ICC_SUPPORT_bit_cg[bt]) this.ICC_SUPPORT_bit_cg[bt].sample(data[0 + bt]);
            foreach(MIPI_CMDS_SUPPORTED_bit_cg[bt]) this.MIPI_CMDS_SUPPORTED_bit_cg[bt].sample(data[1 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*ICC_SUPPORT*/  ,  data[15:1]/*MIPI_CMDS_SUPPORTED*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__INT_CTRL_CMDS_EN::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(ICC_SUPPORT_bit_cg[bt]) this.ICC_SUPPORT_bit_cg[bt].sample(ICC_SUPPORT.get_mirrored_value() >> bt);
            foreach(MIPI_CMDS_SUPPORTED_bit_cg[bt]) this.MIPI_CMDS_SUPPORTED_bit_cg[bt].sample(MIPI_CMDS_SUPPORTED.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( ICC_SUPPORT.get_mirrored_value()  ,  MIPI_CMDS_SUPPORTED.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__IBI_NOTIFY_CTRL SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__IBI_NOTIFY_CTRL::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(NOTIFY_HJ_REJECTED_bit_cg[bt]) this.NOTIFY_HJ_REJECTED_bit_cg[bt].sample(data[0 + bt]);
            foreach(NOTIFY_CRR_REJECTED_bit_cg[bt]) this.NOTIFY_CRR_REJECTED_bit_cg[bt].sample(data[1 + bt]);
            foreach(NOTIFY_IBI_REJECTED_bit_cg[bt]) this.NOTIFY_IBI_REJECTED_bit_cg[bt].sample(data[3 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*NOTIFY_HJ_REJECTED*/  ,  data[1:1]/*NOTIFY_CRR_REJECTED*/  ,  data[3:3]/*NOTIFY_IBI_REJECTED*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__IBI_NOTIFY_CTRL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(NOTIFY_HJ_REJECTED_bit_cg[bt]) this.NOTIFY_HJ_REJECTED_bit_cg[bt].sample(NOTIFY_HJ_REJECTED.get_mirrored_value() >> bt);
            foreach(NOTIFY_CRR_REJECTED_bit_cg[bt]) this.NOTIFY_CRR_REJECTED_bit_cg[bt].sample(NOTIFY_CRR_REJECTED.get_mirrored_value() >> bt);
            foreach(NOTIFY_IBI_REJECTED_bit_cg[bt]) this.NOTIFY_IBI_REJECTED_bit_cg[bt].sample(NOTIFY_IBI_REJECTED.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( NOTIFY_HJ_REJECTED.get_mirrored_value()  ,  NOTIFY_CRR_REJECTED.get_mirrored_value()  ,  NOTIFY_IBI_REJECTED.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__IBI_DATA_ABORT_CTRL SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__IBI_DATA_ABORT_CTRL::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(MATCH_IBI_ID_bit_cg[bt]) this.MATCH_IBI_ID_bit_cg[bt].sample(data[8 + bt]);
            foreach(AFTER_N_CHUNKS_bit_cg[bt]) this.AFTER_N_CHUNKS_bit_cg[bt].sample(data[16 + bt]);
            foreach(MATCH_STATUS_TYPE_bit_cg[bt]) this.MATCH_STATUS_TYPE_bit_cg[bt].sample(data[18 + bt]);
            foreach(IBI_DATA_ABORT_MON_bit_cg[bt]) this.IBI_DATA_ABORT_MON_bit_cg[bt].sample(data[31 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[15:8]/*MATCH_IBI_ID*/  ,  data[17:16]/*AFTER_N_CHUNKS*/  ,  data[20:18]/*MATCH_STATUS_TYPE*/  ,  data[31:31]/*IBI_DATA_ABORT_MON*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__IBI_DATA_ABORT_CTRL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(MATCH_IBI_ID_bit_cg[bt]) this.MATCH_IBI_ID_bit_cg[bt].sample(MATCH_IBI_ID.get_mirrored_value() >> bt);
            foreach(AFTER_N_CHUNKS_bit_cg[bt]) this.AFTER_N_CHUNKS_bit_cg[bt].sample(AFTER_N_CHUNKS.get_mirrored_value() >> bt);
            foreach(MATCH_STATUS_TYPE_bit_cg[bt]) this.MATCH_STATUS_TYPE_bit_cg[bt].sample(MATCH_STATUS_TYPE.get_mirrored_value() >> bt);
            foreach(IBI_DATA_ABORT_MON_bit_cg[bt]) this.IBI_DATA_ABORT_MON_bit_cg[bt].sample(IBI_DATA_ABORT_MON.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( MATCH_IBI_ID.get_mirrored_value()  ,  AFTER_N_CHUNKS.get_mirrored_value()  ,  MATCH_STATUS_TYPE.get_mirrored_value()  ,  IBI_DATA_ABORT_MON.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__DEV_CTX_BASE_LO SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__DEV_CTX_BASE_LO::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(BASE_LO_bit_cg[bt]) this.BASE_LO_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*BASE_LO*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__DEV_CTX_BASE_LO::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(BASE_LO_bit_cg[bt]) this.BASE_LO_bit_cg[bt].sample(BASE_LO.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( BASE_LO.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__DEV_CTX_BASE_HI SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__DEV_CTX_BASE_HI::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(BASE_HI_bit_cg[bt]) this.BASE_HI_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*BASE_HI*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__DEV_CTX_BASE_HI::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(BASE_HI_bit_cg[bt]) this.BASE_HI_bit_cg[bt].sample(BASE_HI.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( BASE_HI.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3CBASE__DEV_CTX_SG SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3CBase__DEV_CTX_SG::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(LIST_SIZE_bit_cg[bt]) this.LIST_SIZE_bit_cg[bt].sample(data[0 + bt]);
            foreach(BLP_bit_cg[bt]) this.BLP_bit_cg[bt].sample(data[31 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[15:0]/*LIST_SIZE*/  ,  data[31:31]/*BLP*/   );
        end
    endfunction

    function void I3CCSR__I3CBase__DEV_CTX_SG::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(LIST_SIZE_bit_cg[bt]) this.LIST_SIZE_bit_cg[bt].sample(LIST_SIZE.get_mirrored_value() >> bt);
            foreach(BLP_bit_cg[bt]) this.BLP_bit_cg[bt].sample(BLP.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( LIST_SIZE.get_mirrored_value()  ,  BLP.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__PIOCONTROL__COMMAND_PORT SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__PIOControl__COMMAND_PORT::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(COMMAND_DATA_bit_cg[bt]) this.COMMAND_DATA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*COMMAND_DATA*/   );
        end
    endfunction

    function void I3CCSR__PIOControl__COMMAND_PORT::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(COMMAND_DATA_bit_cg[bt]) this.COMMAND_DATA_bit_cg[bt].sample(COMMAND_DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( COMMAND_DATA.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__PIOCONTROL__RESPONSE_PORT SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__PIOControl__RESPONSE_PORT::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(RESPONSE_DATA_bit_cg[bt]) this.RESPONSE_DATA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*RESPONSE_DATA*/   );
        end
    endfunction

    function void I3CCSR__PIOControl__RESPONSE_PORT::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(RESPONSE_DATA_bit_cg[bt]) this.RESPONSE_DATA_bit_cg[bt].sample(RESPONSE_DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( RESPONSE_DATA.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__PIOCONTROL__XFER_DATA_PORT SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__PIOControl__XFER_DATA_PORT::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_DATA_bit_cg[bt]) this.TX_DATA_bit_cg[bt].sample(data[0 + bt]);
            foreach(RX_DATA_bit_cg[bt]) this.RX_DATA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*TX_DATA*/  ,  data[31:0]/*RX_DATA*/   );
        end
    endfunction

    function void I3CCSR__PIOControl__XFER_DATA_PORT::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_DATA_bit_cg[bt]) this.TX_DATA_bit_cg[bt].sample(TX_DATA.get_mirrored_value() >> bt);
            foreach(RX_DATA_bit_cg[bt]) this.RX_DATA_bit_cg[bt].sample(RX_DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( TX_DATA.get_mirrored_value()  ,  RX_DATA.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__PIOCONTROL__IBI_PORT SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__PIOControl__IBI_PORT::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(IBI_DATA_bit_cg[bt]) this.IBI_DATA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*IBI_DATA*/   );
        end
    endfunction

    function void I3CCSR__PIOControl__IBI_PORT::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(IBI_DATA_bit_cg[bt]) this.IBI_DATA_bit_cg[bt].sample(IBI_DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( IBI_DATA.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__PIOCONTROL__QUEUE_THLD_CTRL SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__PIOControl__QUEUE_THLD_CTRL::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CMD_EMPTY_BUF_THLD_bit_cg[bt]) this.CMD_EMPTY_BUF_THLD_bit_cg[bt].sample(data[0 + bt]);
            foreach(RESP_BUF_THLD_bit_cg[bt]) this.RESP_BUF_THLD_bit_cg[bt].sample(data[8 + bt]);
            foreach(IBI_DATA_SEGMENT_SIZE_bit_cg[bt]) this.IBI_DATA_SEGMENT_SIZE_bit_cg[bt].sample(data[16 + bt]);
            foreach(IBI_STATUS_THLD_bit_cg[bt]) this.IBI_STATUS_THLD_bit_cg[bt].sample(data[24 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*CMD_EMPTY_BUF_THLD*/  ,  data[15:8]/*RESP_BUF_THLD*/  ,  data[23:16]/*IBI_DATA_SEGMENT_SIZE*/  ,  data[31:24]/*IBI_STATUS_THLD*/   );
        end
    endfunction

    function void I3CCSR__PIOControl__QUEUE_THLD_CTRL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CMD_EMPTY_BUF_THLD_bit_cg[bt]) this.CMD_EMPTY_BUF_THLD_bit_cg[bt].sample(CMD_EMPTY_BUF_THLD.get_mirrored_value() >> bt);
            foreach(RESP_BUF_THLD_bit_cg[bt]) this.RESP_BUF_THLD_bit_cg[bt].sample(RESP_BUF_THLD.get_mirrored_value() >> bt);
            foreach(IBI_DATA_SEGMENT_SIZE_bit_cg[bt]) this.IBI_DATA_SEGMENT_SIZE_bit_cg[bt].sample(IBI_DATA_SEGMENT_SIZE.get_mirrored_value() >> bt);
            foreach(IBI_STATUS_THLD_bit_cg[bt]) this.IBI_STATUS_THLD_bit_cg[bt].sample(IBI_STATUS_THLD.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( CMD_EMPTY_BUF_THLD.get_mirrored_value()  ,  RESP_BUF_THLD.get_mirrored_value()  ,  IBI_DATA_SEGMENT_SIZE.get_mirrored_value()  ,  IBI_STATUS_THLD.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__PIOCONTROL__DATA_BUFFER_THLD_CTRL SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__PIOControl__DATA_BUFFER_THLD_CTRL::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_BUF_THLD_bit_cg[bt]) this.TX_BUF_THLD_bit_cg[bt].sample(data[0 + bt]);
            foreach(RX_BUF_THLD_bit_cg[bt]) this.RX_BUF_THLD_bit_cg[bt].sample(data[8 + bt]);
            foreach(TX_START_THLD_bit_cg[bt]) this.TX_START_THLD_bit_cg[bt].sample(data[16 + bt]);
            foreach(RX_START_THLD_bit_cg[bt]) this.RX_START_THLD_bit_cg[bt].sample(data[24 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[2:0]/*TX_BUF_THLD*/  ,  data[10:8]/*RX_BUF_THLD*/  ,  data[18:16]/*TX_START_THLD*/  ,  data[26:24]/*RX_START_THLD*/   );
        end
    endfunction

    function void I3CCSR__PIOControl__DATA_BUFFER_THLD_CTRL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_BUF_THLD_bit_cg[bt]) this.TX_BUF_THLD_bit_cg[bt].sample(TX_BUF_THLD.get_mirrored_value() >> bt);
            foreach(RX_BUF_THLD_bit_cg[bt]) this.RX_BUF_THLD_bit_cg[bt].sample(RX_BUF_THLD.get_mirrored_value() >> bt);
            foreach(TX_START_THLD_bit_cg[bt]) this.TX_START_THLD_bit_cg[bt].sample(TX_START_THLD.get_mirrored_value() >> bt);
            foreach(RX_START_THLD_bit_cg[bt]) this.RX_START_THLD_bit_cg[bt].sample(RX_START_THLD.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( TX_BUF_THLD.get_mirrored_value()  ,  RX_BUF_THLD.get_mirrored_value()  ,  TX_START_THLD.get_mirrored_value()  ,  RX_START_THLD.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__PIOCONTROL__QUEUE_SIZE SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__PIOControl__QUEUE_SIZE::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CR_QUEUE_SIZE_bit_cg[bt]) this.CR_QUEUE_SIZE_bit_cg[bt].sample(data[0 + bt]);
            foreach(IBI_STATUS_SIZE_bit_cg[bt]) this.IBI_STATUS_SIZE_bit_cg[bt].sample(data[8 + bt]);
            foreach(RX_DATA_BUFFER_SIZE_bit_cg[bt]) this.RX_DATA_BUFFER_SIZE_bit_cg[bt].sample(data[16 + bt]);
            foreach(TX_DATA_BUFFER_SIZE_bit_cg[bt]) this.TX_DATA_BUFFER_SIZE_bit_cg[bt].sample(data[24 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*CR_QUEUE_SIZE*/  ,  data[15:8]/*IBI_STATUS_SIZE*/  ,  data[23:16]/*RX_DATA_BUFFER_SIZE*/  ,  data[31:24]/*TX_DATA_BUFFER_SIZE*/   );
        end
    endfunction

    function void I3CCSR__PIOControl__QUEUE_SIZE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CR_QUEUE_SIZE_bit_cg[bt]) this.CR_QUEUE_SIZE_bit_cg[bt].sample(CR_QUEUE_SIZE.get_mirrored_value() >> bt);
            foreach(IBI_STATUS_SIZE_bit_cg[bt]) this.IBI_STATUS_SIZE_bit_cg[bt].sample(IBI_STATUS_SIZE.get_mirrored_value() >> bt);
            foreach(RX_DATA_BUFFER_SIZE_bit_cg[bt]) this.RX_DATA_BUFFER_SIZE_bit_cg[bt].sample(RX_DATA_BUFFER_SIZE.get_mirrored_value() >> bt);
            foreach(TX_DATA_BUFFER_SIZE_bit_cg[bt]) this.TX_DATA_BUFFER_SIZE_bit_cg[bt].sample(TX_DATA_BUFFER_SIZE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( CR_QUEUE_SIZE.get_mirrored_value()  ,  IBI_STATUS_SIZE.get_mirrored_value()  ,  RX_DATA_BUFFER_SIZE.get_mirrored_value()  ,  TX_DATA_BUFFER_SIZE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__PIOCONTROL__ALT_QUEUE_SIZE SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__PIOControl__ALT_QUEUE_SIZE::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(ALT_RESP_QUEUE_SIZE_bit_cg[bt]) this.ALT_RESP_QUEUE_SIZE_bit_cg[bt].sample(data[0 + bt]);
            foreach(ALT_RESP_QUEUE_EN_bit_cg[bt]) this.ALT_RESP_QUEUE_EN_bit_cg[bt].sample(data[24 + bt]);
            foreach(EXT_IBI_QUEUE_EN_bit_cg[bt]) this.EXT_IBI_QUEUE_EN_bit_cg[bt].sample(data[28 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*ALT_RESP_QUEUE_SIZE*/  ,  data[24:24]/*ALT_RESP_QUEUE_EN*/  ,  data[28:28]/*EXT_IBI_QUEUE_EN*/   );
        end
    endfunction

    function void I3CCSR__PIOControl__ALT_QUEUE_SIZE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(ALT_RESP_QUEUE_SIZE_bit_cg[bt]) this.ALT_RESP_QUEUE_SIZE_bit_cg[bt].sample(ALT_RESP_QUEUE_SIZE.get_mirrored_value() >> bt);
            foreach(ALT_RESP_QUEUE_EN_bit_cg[bt]) this.ALT_RESP_QUEUE_EN_bit_cg[bt].sample(ALT_RESP_QUEUE_EN.get_mirrored_value() >> bt);
            foreach(EXT_IBI_QUEUE_EN_bit_cg[bt]) this.EXT_IBI_QUEUE_EN_bit_cg[bt].sample(EXT_IBI_QUEUE_EN.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( ALT_RESP_QUEUE_SIZE.get_mirrored_value()  ,  ALT_RESP_QUEUE_EN.get_mirrored_value()  ,  EXT_IBI_QUEUE_EN.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_STATUS SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__PIOControl__PIO_INTR_STATUS::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_THLD_STAT_bit_cg[bt]) this.TX_THLD_STAT_bit_cg[bt].sample(data[0 + bt]);
            foreach(RX_THLD_STAT_bit_cg[bt]) this.RX_THLD_STAT_bit_cg[bt].sample(data[1 + bt]);
            foreach(IBI_STATUS_THLD_STAT_bit_cg[bt]) this.IBI_STATUS_THLD_STAT_bit_cg[bt].sample(data[2 + bt]);
            foreach(CMD_QUEUE_READY_STAT_bit_cg[bt]) this.CMD_QUEUE_READY_STAT_bit_cg[bt].sample(data[3 + bt]);
            foreach(RESP_READY_STAT_bit_cg[bt]) this.RESP_READY_STAT_bit_cg[bt].sample(data[4 + bt]);
            foreach(TRANSFER_ABORT_STAT_bit_cg[bt]) this.TRANSFER_ABORT_STAT_bit_cg[bt].sample(data[5 + bt]);
            foreach(TRANSFER_ERR_STAT_bit_cg[bt]) this.TRANSFER_ERR_STAT_bit_cg[bt].sample(data[9 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*TX_THLD_STAT*/  ,  data[1:1]/*RX_THLD_STAT*/  ,  data[2:2]/*IBI_STATUS_THLD_STAT*/  ,  data[3:3]/*CMD_QUEUE_READY_STAT*/  ,  data[4:4]/*RESP_READY_STAT*/  ,  data[5:5]/*TRANSFER_ABORT_STAT*/  ,  data[9:9]/*TRANSFER_ERR_STAT*/   );
        end
    endfunction

    function void I3CCSR__PIOControl__PIO_INTR_STATUS::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_THLD_STAT_bit_cg[bt]) this.TX_THLD_STAT_bit_cg[bt].sample(TX_THLD_STAT.get_mirrored_value() >> bt);
            foreach(RX_THLD_STAT_bit_cg[bt]) this.RX_THLD_STAT_bit_cg[bt].sample(RX_THLD_STAT.get_mirrored_value() >> bt);
            foreach(IBI_STATUS_THLD_STAT_bit_cg[bt]) this.IBI_STATUS_THLD_STAT_bit_cg[bt].sample(IBI_STATUS_THLD_STAT.get_mirrored_value() >> bt);
            foreach(CMD_QUEUE_READY_STAT_bit_cg[bt]) this.CMD_QUEUE_READY_STAT_bit_cg[bt].sample(CMD_QUEUE_READY_STAT.get_mirrored_value() >> bt);
            foreach(RESP_READY_STAT_bit_cg[bt]) this.RESP_READY_STAT_bit_cg[bt].sample(RESP_READY_STAT.get_mirrored_value() >> bt);
            foreach(TRANSFER_ABORT_STAT_bit_cg[bt]) this.TRANSFER_ABORT_STAT_bit_cg[bt].sample(TRANSFER_ABORT_STAT.get_mirrored_value() >> bt);
            foreach(TRANSFER_ERR_STAT_bit_cg[bt]) this.TRANSFER_ERR_STAT_bit_cg[bt].sample(TRANSFER_ERR_STAT.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( TX_THLD_STAT.get_mirrored_value()  ,  RX_THLD_STAT.get_mirrored_value()  ,  IBI_STATUS_THLD_STAT.get_mirrored_value()  ,  CMD_QUEUE_READY_STAT.get_mirrored_value()  ,  RESP_READY_STAT.get_mirrored_value()  ,  TRANSFER_ABORT_STAT.get_mirrored_value()  ,  TRANSFER_ERR_STAT.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_STATUS_ENABLE SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__PIOControl__PIO_INTR_STATUS_ENABLE::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_THLD_STAT_EN_bit_cg[bt]) this.TX_THLD_STAT_EN_bit_cg[bt].sample(data[0 + bt]);
            foreach(RX_THLD_STAT_EN_bit_cg[bt]) this.RX_THLD_STAT_EN_bit_cg[bt].sample(data[1 + bt]);
            foreach(IBI_STATUS_THLD_STAT_EN_bit_cg[bt]) this.IBI_STATUS_THLD_STAT_EN_bit_cg[bt].sample(data[2 + bt]);
            foreach(CMD_QUEUE_READY_STAT_EN_bit_cg[bt]) this.CMD_QUEUE_READY_STAT_EN_bit_cg[bt].sample(data[3 + bt]);
            foreach(RESP_READY_STAT_EN_bit_cg[bt]) this.RESP_READY_STAT_EN_bit_cg[bt].sample(data[4 + bt]);
            foreach(TRANSFER_ABORT_STAT_EN_bit_cg[bt]) this.TRANSFER_ABORT_STAT_EN_bit_cg[bt].sample(data[5 + bt]);
            foreach(TRANSFER_ERR_STAT_EN_bit_cg[bt]) this.TRANSFER_ERR_STAT_EN_bit_cg[bt].sample(data[9 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*TX_THLD_STAT_EN*/  ,  data[1:1]/*RX_THLD_STAT_EN*/  ,  data[2:2]/*IBI_STATUS_THLD_STAT_EN*/  ,  data[3:3]/*CMD_QUEUE_READY_STAT_EN*/  ,  data[4:4]/*RESP_READY_STAT_EN*/  ,  data[5:5]/*TRANSFER_ABORT_STAT_EN*/  ,  data[9:9]/*TRANSFER_ERR_STAT_EN*/   );
        end
    endfunction

    function void I3CCSR__PIOControl__PIO_INTR_STATUS_ENABLE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_THLD_STAT_EN_bit_cg[bt]) this.TX_THLD_STAT_EN_bit_cg[bt].sample(TX_THLD_STAT_EN.get_mirrored_value() >> bt);
            foreach(RX_THLD_STAT_EN_bit_cg[bt]) this.RX_THLD_STAT_EN_bit_cg[bt].sample(RX_THLD_STAT_EN.get_mirrored_value() >> bt);
            foreach(IBI_STATUS_THLD_STAT_EN_bit_cg[bt]) this.IBI_STATUS_THLD_STAT_EN_bit_cg[bt].sample(IBI_STATUS_THLD_STAT_EN.get_mirrored_value() >> bt);
            foreach(CMD_QUEUE_READY_STAT_EN_bit_cg[bt]) this.CMD_QUEUE_READY_STAT_EN_bit_cg[bt].sample(CMD_QUEUE_READY_STAT_EN.get_mirrored_value() >> bt);
            foreach(RESP_READY_STAT_EN_bit_cg[bt]) this.RESP_READY_STAT_EN_bit_cg[bt].sample(RESP_READY_STAT_EN.get_mirrored_value() >> bt);
            foreach(TRANSFER_ABORT_STAT_EN_bit_cg[bt]) this.TRANSFER_ABORT_STAT_EN_bit_cg[bt].sample(TRANSFER_ABORT_STAT_EN.get_mirrored_value() >> bt);
            foreach(TRANSFER_ERR_STAT_EN_bit_cg[bt]) this.TRANSFER_ERR_STAT_EN_bit_cg[bt].sample(TRANSFER_ERR_STAT_EN.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( TX_THLD_STAT_EN.get_mirrored_value()  ,  RX_THLD_STAT_EN.get_mirrored_value()  ,  IBI_STATUS_THLD_STAT_EN.get_mirrored_value()  ,  CMD_QUEUE_READY_STAT_EN.get_mirrored_value()  ,  RESP_READY_STAT_EN.get_mirrored_value()  ,  TRANSFER_ABORT_STAT_EN.get_mirrored_value()  ,  TRANSFER_ERR_STAT_EN.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_SIGNAL_ENABLE SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__PIOControl__PIO_INTR_SIGNAL_ENABLE::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_THLD_SIGNAL_EN_bit_cg[bt]) this.TX_THLD_SIGNAL_EN_bit_cg[bt].sample(data[0 + bt]);
            foreach(RX_THLD_SIGNAL_EN_bit_cg[bt]) this.RX_THLD_SIGNAL_EN_bit_cg[bt].sample(data[1 + bt]);
            foreach(IBI_STATUS_THLD_SIGNAL_EN_bit_cg[bt]) this.IBI_STATUS_THLD_SIGNAL_EN_bit_cg[bt].sample(data[2 + bt]);
            foreach(CMD_QUEUE_READY_SIGNAL_EN_bit_cg[bt]) this.CMD_QUEUE_READY_SIGNAL_EN_bit_cg[bt].sample(data[3 + bt]);
            foreach(RESP_READY_SIGNAL_EN_bit_cg[bt]) this.RESP_READY_SIGNAL_EN_bit_cg[bt].sample(data[4 + bt]);
            foreach(TRANSFER_ABORT_SIGNAL_EN_bit_cg[bt]) this.TRANSFER_ABORT_SIGNAL_EN_bit_cg[bt].sample(data[5 + bt]);
            foreach(TRANSFER_ERR_SIGNAL_EN_bit_cg[bt]) this.TRANSFER_ERR_SIGNAL_EN_bit_cg[bt].sample(data[9 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*TX_THLD_SIGNAL_EN*/  ,  data[1:1]/*RX_THLD_SIGNAL_EN*/  ,  data[2:2]/*IBI_STATUS_THLD_SIGNAL_EN*/  ,  data[3:3]/*CMD_QUEUE_READY_SIGNAL_EN*/  ,  data[4:4]/*RESP_READY_SIGNAL_EN*/  ,  data[5:5]/*TRANSFER_ABORT_SIGNAL_EN*/  ,  data[9:9]/*TRANSFER_ERR_SIGNAL_EN*/   );
        end
    endfunction

    function void I3CCSR__PIOControl__PIO_INTR_SIGNAL_ENABLE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_THLD_SIGNAL_EN_bit_cg[bt]) this.TX_THLD_SIGNAL_EN_bit_cg[bt].sample(TX_THLD_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(RX_THLD_SIGNAL_EN_bit_cg[bt]) this.RX_THLD_SIGNAL_EN_bit_cg[bt].sample(RX_THLD_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(IBI_STATUS_THLD_SIGNAL_EN_bit_cg[bt]) this.IBI_STATUS_THLD_SIGNAL_EN_bit_cg[bt].sample(IBI_STATUS_THLD_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(CMD_QUEUE_READY_SIGNAL_EN_bit_cg[bt]) this.CMD_QUEUE_READY_SIGNAL_EN_bit_cg[bt].sample(CMD_QUEUE_READY_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(RESP_READY_SIGNAL_EN_bit_cg[bt]) this.RESP_READY_SIGNAL_EN_bit_cg[bt].sample(RESP_READY_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(TRANSFER_ABORT_SIGNAL_EN_bit_cg[bt]) this.TRANSFER_ABORT_SIGNAL_EN_bit_cg[bt].sample(TRANSFER_ABORT_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(TRANSFER_ERR_SIGNAL_EN_bit_cg[bt]) this.TRANSFER_ERR_SIGNAL_EN_bit_cg[bt].sample(TRANSFER_ERR_SIGNAL_EN.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( TX_THLD_SIGNAL_EN.get_mirrored_value()  ,  RX_THLD_SIGNAL_EN.get_mirrored_value()  ,  IBI_STATUS_THLD_SIGNAL_EN.get_mirrored_value()  ,  CMD_QUEUE_READY_SIGNAL_EN.get_mirrored_value()  ,  RESP_READY_SIGNAL_EN.get_mirrored_value()  ,  TRANSFER_ABORT_SIGNAL_EN.get_mirrored_value()  ,  TRANSFER_ERR_SIGNAL_EN.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__PIOCONTROL__PIO_INTR_FORCE SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__PIOControl__PIO_INTR_FORCE::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_THLD_FORCE_bit_cg[bt]) this.TX_THLD_FORCE_bit_cg[bt].sample(data[0 + bt]);
            foreach(RX_THLD_FORCE_bit_cg[bt]) this.RX_THLD_FORCE_bit_cg[bt].sample(data[1 + bt]);
            foreach(IBI_THLD_FORCE_bit_cg[bt]) this.IBI_THLD_FORCE_bit_cg[bt].sample(data[2 + bt]);
            foreach(CMD_QUEUE_READY_FORCE_bit_cg[bt]) this.CMD_QUEUE_READY_FORCE_bit_cg[bt].sample(data[3 + bt]);
            foreach(RESP_READY_FORCE_bit_cg[bt]) this.RESP_READY_FORCE_bit_cg[bt].sample(data[4 + bt]);
            foreach(TRANSFER_ABORT_FORCE_bit_cg[bt]) this.TRANSFER_ABORT_FORCE_bit_cg[bt].sample(data[5 + bt]);
            foreach(TRANSFER_ERR_FORCE_bit_cg[bt]) this.TRANSFER_ERR_FORCE_bit_cg[bt].sample(data[9 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*TX_THLD_FORCE*/  ,  data[1:1]/*RX_THLD_FORCE*/  ,  data[2:2]/*IBI_THLD_FORCE*/  ,  data[3:3]/*CMD_QUEUE_READY_FORCE*/  ,  data[4:4]/*RESP_READY_FORCE*/  ,  data[5:5]/*TRANSFER_ABORT_FORCE*/  ,  data[9:9]/*TRANSFER_ERR_FORCE*/   );
        end
    endfunction

    function void I3CCSR__PIOControl__PIO_INTR_FORCE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_THLD_FORCE_bit_cg[bt]) this.TX_THLD_FORCE_bit_cg[bt].sample(TX_THLD_FORCE.get_mirrored_value() >> bt);
            foreach(RX_THLD_FORCE_bit_cg[bt]) this.RX_THLD_FORCE_bit_cg[bt].sample(RX_THLD_FORCE.get_mirrored_value() >> bt);
            foreach(IBI_THLD_FORCE_bit_cg[bt]) this.IBI_THLD_FORCE_bit_cg[bt].sample(IBI_THLD_FORCE.get_mirrored_value() >> bt);
            foreach(CMD_QUEUE_READY_FORCE_bit_cg[bt]) this.CMD_QUEUE_READY_FORCE_bit_cg[bt].sample(CMD_QUEUE_READY_FORCE.get_mirrored_value() >> bt);
            foreach(RESP_READY_FORCE_bit_cg[bt]) this.RESP_READY_FORCE_bit_cg[bt].sample(RESP_READY_FORCE.get_mirrored_value() >> bt);
            foreach(TRANSFER_ABORT_FORCE_bit_cg[bt]) this.TRANSFER_ABORT_FORCE_bit_cg[bt].sample(TRANSFER_ABORT_FORCE.get_mirrored_value() >> bt);
            foreach(TRANSFER_ERR_FORCE_bit_cg[bt]) this.TRANSFER_ERR_FORCE_bit_cg[bt].sample(TRANSFER_ERR_FORCE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( TX_THLD_FORCE.get_mirrored_value()  ,  RX_THLD_FORCE.get_mirrored_value()  ,  IBI_THLD_FORCE.get_mirrored_value()  ,  CMD_QUEUE_READY_FORCE.get_mirrored_value()  ,  RESP_READY_FORCE.get_mirrored_value()  ,  TRANSFER_ABORT_FORCE.get_mirrored_value()  ,  TRANSFER_ERR_FORCE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__PIOCONTROL__PIO_CONTROL SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__PIOControl__PIO_CONTROL::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(ENABLE_bit_cg[bt]) this.ENABLE_bit_cg[bt].sample(data[0 + bt]);
            foreach(RS_bit_cg[bt]) this.RS_bit_cg[bt].sample(data[1 + bt]);
            foreach(ABORT_bit_cg[bt]) this.ABORT_bit_cg[bt].sample(data[2 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*ENABLE*/  ,  data[1:1]/*RS*/  ,  data[2:2]/*ABORT*/   );
        end
    endfunction

    function void I3CCSR__PIOControl__PIO_CONTROL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(ENABLE_bit_cg[bt]) this.ENABLE_bit_cg[bt].sample(ENABLE.get_mirrored_value() >> bt);
            foreach(RS_bit_cg[bt]) this.RS_bit_cg[bt].sample(RS.get_mirrored_value() >> bt);
            foreach(ABORT_bit_cg[bt]) this.ABORT_bit_cg[bt].sample(ABORT.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( ENABLE.get_mirrored_value()  ,  RS.get_mirrored_value()  ,  ABORT.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__EXTCAP_HEADER SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__EXTCAP_HEADER::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(data[0 + bt]);
            foreach(CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(data[8 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*CAP_ID*/  ,  data[23:8]/*CAP_LENGTH*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__EXTCAP_HEADER::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(CAP_ID.get_mirrored_value() >> bt);
            foreach(CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(CAP_LENGTH.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( CAP_ID.get_mirrored_value()  ,  CAP_LENGTH.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__PROT_CAP_0 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_0::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_0::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__PROT_CAP_1 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_1::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_1::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__PROT_CAP_2 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_2::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_2::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__PROT_CAP_3 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_3::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_3::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_ID_0 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_0::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_0::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_ID_1 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_1::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_1::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_ID_2 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_2::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_2::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_ID_3 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_3::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_3::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_ID_4 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_4::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_4::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_ID_5 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_5::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_5::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_ID_6 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_6::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_6::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_STATUS_0 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_STATUS_0::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_STATUS_0::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_STATUS_1 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_STATUS_1::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_STATUS_1::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_RESET SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_RESET::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_RESET::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__RECOVERY_CTRL SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__RECOVERY_CTRL::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__RECOVERY_CTRL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__RECOVERY_STATUS SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__RECOVERY_STATUS::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__RECOVERY_STATUS::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__HW_STATUS SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__HW_STATUS::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__HW_STATUS::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_CTRL_0 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_CTRL_0::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_CTRL_0::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_CTRL_1 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_CTRL_1::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_CTRL_1::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_STATUS_0 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_0::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_0::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_STATUS_1 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_1::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_1::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_STATUS_2 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_2::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_2::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_STATUS_3 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_3::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_3::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_STATUS_4 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_4::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_4::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_STATUS_5 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_5::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_5::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_DATA SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_DATA::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_DATA::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__EXTCAP_HEADER SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode__EXTCAP_HEADER::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(data[0 + bt]);
            foreach(CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(data[8 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*CAP_ID*/  ,  data[23:8]/*CAP_LENGTH*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode__EXTCAP_HEADER::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(CAP_ID.get_mirrored_value() >> bt);
            foreach(CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(CAP_LENGTH.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( CAP_ID.get_mirrored_value()  ,  CAP_LENGTH.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_CONTROL SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CONTROL::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PENDING_RX_NACK_bit_cg[bt]) this.PENDING_RX_NACK_bit_cg[bt].sample(data[0 + bt]);
            foreach(HANDOFF_DELAY_NACK_bit_cg[bt]) this.HANDOFF_DELAY_NACK_bit_cg[bt].sample(data[1 + bt]);
            foreach(ACR_FSM_OP_SELECT_bit_cg[bt]) this.ACR_FSM_OP_SELECT_bit_cg[bt].sample(data[2 + bt]);
            foreach(PRIME_ACCEPT_GETACCCR_bit_cg[bt]) this.PRIME_ACCEPT_GETACCCR_bit_cg[bt].sample(data[3 + bt]);
            foreach(HANDOFF_DEEP_SLEEP_bit_cg[bt]) this.HANDOFF_DEEP_SLEEP_bit_cg[bt].sample(data[4 + bt]);
            foreach(CR_REQUEST_SEND_bit_cg[bt]) this.CR_REQUEST_SEND_bit_cg[bt].sample(data[5 + bt]);
            foreach(BAST_CCC_IBI_RING_bit_cg[bt]) this.BAST_CCC_IBI_RING_bit_cg[bt].sample(data[8 + bt]);
            foreach(TARGET_XACT_ENABLE_bit_cg[bt]) this.TARGET_XACT_ENABLE_bit_cg[bt].sample(data[12 + bt]);
            foreach(DAA_SETAASA_ENABLE_bit_cg[bt]) this.DAA_SETAASA_ENABLE_bit_cg[bt].sample(data[13 + bt]);
            foreach(DAA_SETDASA_ENABLE_bit_cg[bt]) this.DAA_SETDASA_ENABLE_bit_cg[bt].sample(data[14 + bt]);
            foreach(DAA_ENTDAA_ENABLE_bit_cg[bt]) this.DAA_ENTDAA_ENABLE_bit_cg[bt].sample(data[15 + bt]);
            foreach(RSTACT_DEFBYTE_02_bit_cg[bt]) this.RSTACT_DEFBYTE_02_bit_cg[bt].sample(data[20 + bt]);
            foreach(STBY_CR_ENABLE_INIT_bit_cg[bt]) this.STBY_CR_ENABLE_INIT_bit_cg[bt].sample(data[30 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*PENDING_RX_NACK*/  ,  data[1:1]/*HANDOFF_DELAY_NACK*/  ,  data[2:2]/*ACR_FSM_OP_SELECT*/  ,  data[3:3]/*PRIME_ACCEPT_GETACCCR*/  ,  data[4:4]/*HANDOFF_DEEP_SLEEP*/  ,  data[5:5]/*CR_REQUEST_SEND*/  ,  data[10:8]/*BAST_CCC_IBI_RING*/  ,  data[12:12]/*TARGET_XACT_ENABLE*/  ,  data[13:13]/*DAA_SETAASA_ENABLE*/  ,  data[14:14]/*DAA_SETDASA_ENABLE*/  ,  data[15:15]/*DAA_ENTDAA_ENABLE*/  ,  data[20:20]/*RSTACT_DEFBYTE_02*/  ,  data[31:30]/*STBY_CR_ENABLE_INIT*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CONTROL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PENDING_RX_NACK_bit_cg[bt]) this.PENDING_RX_NACK_bit_cg[bt].sample(PENDING_RX_NACK.get_mirrored_value() >> bt);
            foreach(HANDOFF_DELAY_NACK_bit_cg[bt]) this.HANDOFF_DELAY_NACK_bit_cg[bt].sample(HANDOFF_DELAY_NACK.get_mirrored_value() >> bt);
            foreach(ACR_FSM_OP_SELECT_bit_cg[bt]) this.ACR_FSM_OP_SELECT_bit_cg[bt].sample(ACR_FSM_OP_SELECT.get_mirrored_value() >> bt);
            foreach(PRIME_ACCEPT_GETACCCR_bit_cg[bt]) this.PRIME_ACCEPT_GETACCCR_bit_cg[bt].sample(PRIME_ACCEPT_GETACCCR.get_mirrored_value() >> bt);
            foreach(HANDOFF_DEEP_SLEEP_bit_cg[bt]) this.HANDOFF_DEEP_SLEEP_bit_cg[bt].sample(HANDOFF_DEEP_SLEEP.get_mirrored_value() >> bt);
            foreach(CR_REQUEST_SEND_bit_cg[bt]) this.CR_REQUEST_SEND_bit_cg[bt].sample(CR_REQUEST_SEND.get_mirrored_value() >> bt);
            foreach(BAST_CCC_IBI_RING_bit_cg[bt]) this.BAST_CCC_IBI_RING_bit_cg[bt].sample(BAST_CCC_IBI_RING.get_mirrored_value() >> bt);
            foreach(TARGET_XACT_ENABLE_bit_cg[bt]) this.TARGET_XACT_ENABLE_bit_cg[bt].sample(TARGET_XACT_ENABLE.get_mirrored_value() >> bt);
            foreach(DAA_SETAASA_ENABLE_bit_cg[bt]) this.DAA_SETAASA_ENABLE_bit_cg[bt].sample(DAA_SETAASA_ENABLE.get_mirrored_value() >> bt);
            foreach(DAA_SETDASA_ENABLE_bit_cg[bt]) this.DAA_SETDASA_ENABLE_bit_cg[bt].sample(DAA_SETDASA_ENABLE.get_mirrored_value() >> bt);
            foreach(DAA_ENTDAA_ENABLE_bit_cg[bt]) this.DAA_ENTDAA_ENABLE_bit_cg[bt].sample(DAA_ENTDAA_ENABLE.get_mirrored_value() >> bt);
            foreach(RSTACT_DEFBYTE_02_bit_cg[bt]) this.RSTACT_DEFBYTE_02_bit_cg[bt].sample(RSTACT_DEFBYTE_02.get_mirrored_value() >> bt);
            foreach(STBY_CR_ENABLE_INIT_bit_cg[bt]) this.STBY_CR_ENABLE_INIT_bit_cg[bt].sample(STBY_CR_ENABLE_INIT.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PENDING_RX_NACK.get_mirrored_value()  ,  HANDOFF_DELAY_NACK.get_mirrored_value()  ,  ACR_FSM_OP_SELECT.get_mirrored_value()  ,  PRIME_ACCEPT_GETACCCR.get_mirrored_value()  ,  HANDOFF_DEEP_SLEEP.get_mirrored_value()  ,  CR_REQUEST_SEND.get_mirrored_value()  ,  BAST_CCC_IBI_RING.get_mirrored_value()  ,  TARGET_XACT_ENABLE.get_mirrored_value()  ,  DAA_SETAASA_ENABLE.get_mirrored_value()  ,  DAA_SETDASA_ENABLE.get_mirrored_value()  ,  DAA_ENTDAA_ENABLE.get_mirrored_value()  ,  RSTACT_DEFBYTE_02.get_mirrored_value()  ,  STBY_CR_ENABLE_INIT.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_DEVICE_ADDR SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_DEVICE_ADDR::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(STATIC_ADDR_bit_cg[bt]) this.STATIC_ADDR_bit_cg[bt].sample(data[0 + bt]);
            foreach(STATIC_ADDR_VALID_bit_cg[bt]) this.STATIC_ADDR_VALID_bit_cg[bt].sample(data[15 + bt]);
            foreach(DYNAMIC_ADDR_bit_cg[bt]) this.DYNAMIC_ADDR_bit_cg[bt].sample(data[16 + bt]);
            foreach(DYNAMIC_ADDR_VALID_bit_cg[bt]) this.DYNAMIC_ADDR_VALID_bit_cg[bt].sample(data[31 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[6:0]/*STATIC_ADDR*/  ,  data[15:15]/*STATIC_ADDR_VALID*/  ,  data[22:16]/*DYNAMIC_ADDR*/  ,  data[31:31]/*DYNAMIC_ADDR_VALID*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_DEVICE_ADDR::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(STATIC_ADDR_bit_cg[bt]) this.STATIC_ADDR_bit_cg[bt].sample(STATIC_ADDR.get_mirrored_value() >> bt);
            foreach(STATIC_ADDR_VALID_bit_cg[bt]) this.STATIC_ADDR_VALID_bit_cg[bt].sample(STATIC_ADDR_VALID.get_mirrored_value() >> bt);
            foreach(DYNAMIC_ADDR_bit_cg[bt]) this.DYNAMIC_ADDR_bit_cg[bt].sample(DYNAMIC_ADDR.get_mirrored_value() >> bt);
            foreach(DYNAMIC_ADDR_VALID_bit_cg[bt]) this.DYNAMIC_ADDR_VALID_bit_cg[bt].sample(DYNAMIC_ADDR_VALID.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( STATIC_ADDR.get_mirrored_value()  ,  STATIC_ADDR_VALID.get_mirrored_value()  ,  DYNAMIC_ADDR.get_mirrored_value()  ,  DYNAMIC_ADDR_VALID.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_CAPABILITIES SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CAPABILITIES::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(SIMPLE_CRR_SUPPORT_bit_cg[bt]) this.SIMPLE_CRR_SUPPORT_bit_cg[bt].sample(data[5 + bt]);
            foreach(TARGET_XACT_SUPPORT_bit_cg[bt]) this.TARGET_XACT_SUPPORT_bit_cg[bt].sample(data[12 + bt]);
            foreach(DAA_SETAASA_SUPPORT_bit_cg[bt]) this.DAA_SETAASA_SUPPORT_bit_cg[bt].sample(data[13 + bt]);
            foreach(DAA_SETDASA_SUPPORT_bit_cg[bt]) this.DAA_SETDASA_SUPPORT_bit_cg[bt].sample(data[14 + bt]);
            foreach(DAA_ENTDAA_SUPPORT_bit_cg[bt]) this.DAA_ENTDAA_SUPPORT_bit_cg[bt].sample(data[15 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[5:5]/*SIMPLE_CRR_SUPPORT*/  ,  data[12:12]/*TARGET_XACT_SUPPORT*/  ,  data[13:13]/*DAA_SETAASA_SUPPORT*/  ,  data[14:14]/*DAA_SETDASA_SUPPORT*/  ,  data[15:15]/*DAA_ENTDAA_SUPPORT*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CAPABILITIES::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(SIMPLE_CRR_SUPPORT_bit_cg[bt]) this.SIMPLE_CRR_SUPPORT_bit_cg[bt].sample(SIMPLE_CRR_SUPPORT.get_mirrored_value() >> bt);
            foreach(TARGET_XACT_SUPPORT_bit_cg[bt]) this.TARGET_XACT_SUPPORT_bit_cg[bt].sample(TARGET_XACT_SUPPORT.get_mirrored_value() >> bt);
            foreach(DAA_SETAASA_SUPPORT_bit_cg[bt]) this.DAA_SETAASA_SUPPORT_bit_cg[bt].sample(DAA_SETAASA_SUPPORT.get_mirrored_value() >> bt);
            foreach(DAA_SETDASA_SUPPORT_bit_cg[bt]) this.DAA_SETDASA_SUPPORT_bit_cg[bt].sample(DAA_SETDASA_SUPPORT.get_mirrored_value() >> bt);
            foreach(DAA_ENTDAA_SUPPORT_bit_cg[bt]) this.DAA_ENTDAA_SUPPORT_bit_cg[bt].sample(DAA_ENTDAA_SUPPORT.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( SIMPLE_CRR_SUPPORT.get_mirrored_value()  ,  TARGET_XACT_SUPPORT.get_mirrored_value()  ,  DAA_SETAASA_SUPPORT.get_mirrored_value()  ,  DAA_SETDASA_SUPPORT.get_mirrored_value()  ,  DAA_ENTDAA_SUPPORT.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE____RSVD_0 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode____rsvd_0::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(__rsvd_bit_cg[bt]) this.__rsvd_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*__rsvd*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode____rsvd_0::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(__rsvd_bit_cg[bt]) this.__rsvd_bit_cg[bt].sample(__rsvd.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( __rsvd.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_STATUS SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_STATUS::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(AC_CURRENT_OWN_bit_cg[bt]) this.AC_CURRENT_OWN_bit_cg[bt].sample(data[2 + bt]);
            foreach(SIMPLE_CRR_STATUS_bit_cg[bt]) this.SIMPLE_CRR_STATUS_bit_cg[bt].sample(data[5 + bt]);
            foreach(HJ_REQ_STATUS_bit_cg[bt]) this.HJ_REQ_STATUS_bit_cg[bt].sample(data[8 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[2:2]/*AC_CURRENT_OWN*/  ,  data[7:5]/*SIMPLE_CRR_STATUS*/  ,  data[8:8]/*HJ_REQ_STATUS*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_STATUS::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(AC_CURRENT_OWN_bit_cg[bt]) this.AC_CURRENT_OWN_bit_cg[bt].sample(AC_CURRENT_OWN.get_mirrored_value() >> bt);
            foreach(SIMPLE_CRR_STATUS_bit_cg[bt]) this.SIMPLE_CRR_STATUS_bit_cg[bt].sample(SIMPLE_CRR_STATUS.get_mirrored_value() >> bt);
            foreach(HJ_REQ_STATUS_bit_cg[bt]) this.HJ_REQ_STATUS_bit_cg[bt].sample(HJ_REQ_STATUS.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( AC_CURRENT_OWN.get_mirrored_value()  ,  SIMPLE_CRR_STATUS.get_mirrored_value()  ,  HJ_REQ_STATUS.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_DEVICE_CHAR SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_DEVICE_CHAR::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PID_HI_bit_cg[bt]) this.PID_HI_bit_cg[bt].sample(data[1 + bt]);
            foreach(DCR_bit_cg[bt]) this.DCR_bit_cg[bt].sample(data[16 + bt]);
            foreach(BCR_VAR_bit_cg[bt]) this.BCR_VAR_bit_cg[bt].sample(data[24 + bt]);
            foreach(BCR_FIXED_bit_cg[bt]) this.BCR_FIXED_bit_cg[bt].sample(data[29 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[15:1]/*PID_HI*/  ,  data[23:16]/*DCR*/  ,  data[28:24]/*BCR_VAR*/  ,  data[31:29]/*BCR_FIXED*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_DEVICE_CHAR::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PID_HI_bit_cg[bt]) this.PID_HI_bit_cg[bt].sample(PID_HI.get_mirrored_value() >> bt);
            foreach(DCR_bit_cg[bt]) this.DCR_bit_cg[bt].sample(DCR.get_mirrored_value() >> bt);
            foreach(BCR_VAR_bit_cg[bt]) this.BCR_VAR_bit_cg[bt].sample(BCR_VAR.get_mirrored_value() >> bt);
            foreach(BCR_FIXED_bit_cg[bt]) this.BCR_FIXED_bit_cg[bt].sample(BCR_FIXED.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PID_HI.get_mirrored_value()  ,  DCR.get_mirrored_value()  ,  BCR_VAR.get_mirrored_value()  ,  BCR_FIXED.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_DEVICE_PID_LO SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_DEVICE_PID_LO::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PID_LO_bit_cg[bt]) this.PID_LO_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PID_LO*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_DEVICE_PID_LO::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PID_LO_bit_cg[bt]) this.PID_LO_bit_cg[bt].sample(PID_LO.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PID_LO.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_INTR_STATUS SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_INTR_STATUS::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(ACR_HANDOFF_OK_REMAIN_STAT_bit_cg[bt]) this.ACR_HANDOFF_OK_REMAIN_STAT_bit_cg[bt].sample(data[0 + bt]);
            foreach(ACR_HANDOFF_OK_PRIMED_STAT_bit_cg[bt]) this.ACR_HANDOFF_OK_PRIMED_STAT_bit_cg[bt].sample(data[1 + bt]);
            foreach(ACR_HANDOFF_ERR_FAIL_STAT_bit_cg[bt]) this.ACR_HANDOFF_ERR_FAIL_STAT_bit_cg[bt].sample(data[2 + bt]);
            foreach(ACR_HANDOFF_ERR_M3_STAT_bit_cg[bt]) this.ACR_HANDOFF_ERR_M3_STAT_bit_cg[bt].sample(data[3 + bt]);
            foreach(CRR_RESPONSE_STAT_bit_cg[bt]) this.CRR_RESPONSE_STAT_bit_cg[bt].sample(data[10 + bt]);
            foreach(STBY_CR_DYN_ADDR_STAT_bit_cg[bt]) this.STBY_CR_DYN_ADDR_STAT_bit_cg[bt].sample(data[11 + bt]);
            foreach(STBY_CR_ACCEPT_NACKED_STAT_bit_cg[bt]) this.STBY_CR_ACCEPT_NACKED_STAT_bit_cg[bt].sample(data[12 + bt]);
            foreach(STBY_CR_ACCEPT_OK_STAT_bit_cg[bt]) this.STBY_CR_ACCEPT_OK_STAT_bit_cg[bt].sample(data[13 + bt]);
            foreach(STBY_CR_ACCEPT_ERR_STAT_bit_cg[bt]) this.STBY_CR_ACCEPT_ERR_STAT_bit_cg[bt].sample(data[14 + bt]);
            foreach(STBY_CR_OP_RSTACT_STAT_bit_cg[bt]) this.STBY_CR_OP_RSTACT_STAT_bit_cg[bt].sample(data[16 + bt]);
            foreach(CCC_PARAM_MODIFIED_STAT_bit_cg[bt]) this.CCC_PARAM_MODIFIED_STAT_bit_cg[bt].sample(data[17 + bt]);
            foreach(CCC_UNHANDLED_NACK_STAT_bit_cg[bt]) this.CCC_UNHANDLED_NACK_STAT_bit_cg[bt].sample(data[18 + bt]);
            foreach(CCC_FATAL_RSTDAA_ERR_STAT_bit_cg[bt]) this.CCC_FATAL_RSTDAA_ERR_STAT_bit_cg[bt].sample(data[19 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*ACR_HANDOFF_OK_REMAIN_STAT*/  ,  data[1:1]/*ACR_HANDOFF_OK_PRIMED_STAT*/  ,  data[2:2]/*ACR_HANDOFF_ERR_FAIL_STAT*/  ,  data[3:3]/*ACR_HANDOFF_ERR_M3_STAT*/  ,  data[10:10]/*CRR_RESPONSE_STAT*/  ,  data[11:11]/*STBY_CR_DYN_ADDR_STAT*/  ,  data[12:12]/*STBY_CR_ACCEPT_NACKED_STAT*/  ,  data[13:13]/*STBY_CR_ACCEPT_OK_STAT*/  ,  data[14:14]/*STBY_CR_ACCEPT_ERR_STAT*/  ,  data[16:16]/*STBY_CR_OP_RSTACT_STAT*/  ,  data[17:17]/*CCC_PARAM_MODIFIED_STAT*/  ,  data[18:18]/*CCC_UNHANDLED_NACK_STAT*/  ,  data[19:19]/*CCC_FATAL_RSTDAA_ERR_STAT*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_INTR_STATUS::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(ACR_HANDOFF_OK_REMAIN_STAT_bit_cg[bt]) this.ACR_HANDOFF_OK_REMAIN_STAT_bit_cg[bt].sample(ACR_HANDOFF_OK_REMAIN_STAT.get_mirrored_value() >> bt);
            foreach(ACR_HANDOFF_OK_PRIMED_STAT_bit_cg[bt]) this.ACR_HANDOFF_OK_PRIMED_STAT_bit_cg[bt].sample(ACR_HANDOFF_OK_PRIMED_STAT.get_mirrored_value() >> bt);
            foreach(ACR_HANDOFF_ERR_FAIL_STAT_bit_cg[bt]) this.ACR_HANDOFF_ERR_FAIL_STAT_bit_cg[bt].sample(ACR_HANDOFF_ERR_FAIL_STAT.get_mirrored_value() >> bt);
            foreach(ACR_HANDOFF_ERR_M3_STAT_bit_cg[bt]) this.ACR_HANDOFF_ERR_M3_STAT_bit_cg[bt].sample(ACR_HANDOFF_ERR_M3_STAT.get_mirrored_value() >> bt);
            foreach(CRR_RESPONSE_STAT_bit_cg[bt]) this.CRR_RESPONSE_STAT_bit_cg[bt].sample(CRR_RESPONSE_STAT.get_mirrored_value() >> bt);
            foreach(STBY_CR_DYN_ADDR_STAT_bit_cg[bt]) this.STBY_CR_DYN_ADDR_STAT_bit_cg[bt].sample(STBY_CR_DYN_ADDR_STAT.get_mirrored_value() >> bt);
            foreach(STBY_CR_ACCEPT_NACKED_STAT_bit_cg[bt]) this.STBY_CR_ACCEPT_NACKED_STAT_bit_cg[bt].sample(STBY_CR_ACCEPT_NACKED_STAT.get_mirrored_value() >> bt);
            foreach(STBY_CR_ACCEPT_OK_STAT_bit_cg[bt]) this.STBY_CR_ACCEPT_OK_STAT_bit_cg[bt].sample(STBY_CR_ACCEPT_OK_STAT.get_mirrored_value() >> bt);
            foreach(STBY_CR_ACCEPT_ERR_STAT_bit_cg[bt]) this.STBY_CR_ACCEPT_ERR_STAT_bit_cg[bt].sample(STBY_CR_ACCEPT_ERR_STAT.get_mirrored_value() >> bt);
            foreach(STBY_CR_OP_RSTACT_STAT_bit_cg[bt]) this.STBY_CR_OP_RSTACT_STAT_bit_cg[bt].sample(STBY_CR_OP_RSTACT_STAT.get_mirrored_value() >> bt);
            foreach(CCC_PARAM_MODIFIED_STAT_bit_cg[bt]) this.CCC_PARAM_MODIFIED_STAT_bit_cg[bt].sample(CCC_PARAM_MODIFIED_STAT.get_mirrored_value() >> bt);
            foreach(CCC_UNHANDLED_NACK_STAT_bit_cg[bt]) this.CCC_UNHANDLED_NACK_STAT_bit_cg[bt].sample(CCC_UNHANDLED_NACK_STAT.get_mirrored_value() >> bt);
            foreach(CCC_FATAL_RSTDAA_ERR_STAT_bit_cg[bt]) this.CCC_FATAL_RSTDAA_ERR_STAT_bit_cg[bt].sample(CCC_FATAL_RSTDAA_ERR_STAT.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( ACR_HANDOFF_OK_REMAIN_STAT.get_mirrored_value()  ,  ACR_HANDOFF_OK_PRIMED_STAT.get_mirrored_value()  ,  ACR_HANDOFF_ERR_FAIL_STAT.get_mirrored_value()  ,  ACR_HANDOFF_ERR_M3_STAT.get_mirrored_value()  ,  CRR_RESPONSE_STAT.get_mirrored_value()  ,  STBY_CR_DYN_ADDR_STAT.get_mirrored_value()  ,  STBY_CR_ACCEPT_NACKED_STAT.get_mirrored_value()  ,  STBY_CR_ACCEPT_OK_STAT.get_mirrored_value()  ,  STBY_CR_ACCEPT_ERR_STAT.get_mirrored_value()  ,  STBY_CR_OP_RSTACT_STAT.get_mirrored_value()  ,  CCC_PARAM_MODIFIED_STAT.get_mirrored_value()  ,  CCC_UNHANDLED_NACK_STAT.get_mirrored_value()  ,  CCC_FATAL_RSTDAA_ERR_STAT.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE____RSVD_1 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode____rsvd_1::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(__rsvd_bit_cg[bt]) this.__rsvd_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*__rsvd*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode____rsvd_1::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(__rsvd_bit_cg[bt]) this.__rsvd_bit_cg[bt].sample(__rsvd.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( __rsvd.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_INTR_SIGNAL_ENABLE SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_INTR_SIGNAL_ENABLE::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(ACR_HANDOFF_OK_REMAIN_SIGNAL_EN_bit_cg[bt]) this.ACR_HANDOFF_OK_REMAIN_SIGNAL_EN_bit_cg[bt].sample(data[0 + bt]);
            foreach(ACR_HANDOFF_OK_PRIMED_SIGNAL_EN_bit_cg[bt]) this.ACR_HANDOFF_OK_PRIMED_SIGNAL_EN_bit_cg[bt].sample(data[1 + bt]);
            foreach(ACR_HANDOFF_ERR_FAIL_SIGNAL_EN_bit_cg[bt]) this.ACR_HANDOFF_ERR_FAIL_SIGNAL_EN_bit_cg[bt].sample(data[2 + bt]);
            foreach(ACR_HANDOFF_ERR_M3_SIGNAL_EN_bit_cg[bt]) this.ACR_HANDOFF_ERR_M3_SIGNAL_EN_bit_cg[bt].sample(data[3 + bt]);
            foreach(CRR_RESPONSE_SIGNAL_EN_bit_cg[bt]) this.CRR_RESPONSE_SIGNAL_EN_bit_cg[bt].sample(data[10 + bt]);
            foreach(STBY_CR_DYN_ADDR_SIGNAL_EN_bit_cg[bt]) this.STBY_CR_DYN_ADDR_SIGNAL_EN_bit_cg[bt].sample(data[11 + bt]);
            foreach(STBY_CR_ACCEPT_NACKED_SIGNAL_EN_bit_cg[bt]) this.STBY_CR_ACCEPT_NACKED_SIGNAL_EN_bit_cg[bt].sample(data[12 + bt]);
            foreach(STBY_CR_ACCEPT_OK_SIGNAL_EN_bit_cg[bt]) this.STBY_CR_ACCEPT_OK_SIGNAL_EN_bit_cg[bt].sample(data[13 + bt]);
            foreach(STBY_CR_ACCEPT_ERR_SIGNAL_EN_bit_cg[bt]) this.STBY_CR_ACCEPT_ERR_SIGNAL_EN_bit_cg[bt].sample(data[14 + bt]);
            foreach(STBY_CR_OP_RSTACT_SIGNAL_EN_bit_cg[bt]) this.STBY_CR_OP_RSTACT_SIGNAL_EN_bit_cg[bt].sample(data[16 + bt]);
            foreach(CCC_PARAM_MODIFIED_SIGNAL_EN_bit_cg[bt]) this.CCC_PARAM_MODIFIED_SIGNAL_EN_bit_cg[bt].sample(data[17 + bt]);
            foreach(CCC_UNHANDLED_NACK_SIGNAL_EN_bit_cg[bt]) this.CCC_UNHANDLED_NACK_SIGNAL_EN_bit_cg[bt].sample(data[18 + bt]);
            foreach(CCC_FATAL_RSTDAA_ERR_SIGNAL_EN_bit_cg[bt]) this.CCC_FATAL_RSTDAA_ERR_SIGNAL_EN_bit_cg[bt].sample(data[19 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*ACR_HANDOFF_OK_REMAIN_SIGNAL_EN*/  ,  data[1:1]/*ACR_HANDOFF_OK_PRIMED_SIGNAL_EN*/  ,  data[2:2]/*ACR_HANDOFF_ERR_FAIL_SIGNAL_EN*/  ,  data[3:3]/*ACR_HANDOFF_ERR_M3_SIGNAL_EN*/  ,  data[10:10]/*CRR_RESPONSE_SIGNAL_EN*/  ,  data[11:11]/*STBY_CR_DYN_ADDR_SIGNAL_EN*/  ,  data[12:12]/*STBY_CR_ACCEPT_NACKED_SIGNAL_EN*/  ,  data[13:13]/*STBY_CR_ACCEPT_OK_SIGNAL_EN*/  ,  data[14:14]/*STBY_CR_ACCEPT_ERR_SIGNAL_EN*/  ,  data[16:16]/*STBY_CR_OP_RSTACT_SIGNAL_EN*/  ,  data[17:17]/*CCC_PARAM_MODIFIED_SIGNAL_EN*/  ,  data[18:18]/*CCC_UNHANDLED_NACK_SIGNAL_EN*/  ,  data[19:19]/*CCC_FATAL_RSTDAA_ERR_SIGNAL_EN*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_INTR_SIGNAL_ENABLE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(ACR_HANDOFF_OK_REMAIN_SIGNAL_EN_bit_cg[bt]) this.ACR_HANDOFF_OK_REMAIN_SIGNAL_EN_bit_cg[bt].sample(ACR_HANDOFF_OK_REMAIN_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(ACR_HANDOFF_OK_PRIMED_SIGNAL_EN_bit_cg[bt]) this.ACR_HANDOFF_OK_PRIMED_SIGNAL_EN_bit_cg[bt].sample(ACR_HANDOFF_OK_PRIMED_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(ACR_HANDOFF_ERR_FAIL_SIGNAL_EN_bit_cg[bt]) this.ACR_HANDOFF_ERR_FAIL_SIGNAL_EN_bit_cg[bt].sample(ACR_HANDOFF_ERR_FAIL_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(ACR_HANDOFF_ERR_M3_SIGNAL_EN_bit_cg[bt]) this.ACR_HANDOFF_ERR_M3_SIGNAL_EN_bit_cg[bt].sample(ACR_HANDOFF_ERR_M3_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(CRR_RESPONSE_SIGNAL_EN_bit_cg[bt]) this.CRR_RESPONSE_SIGNAL_EN_bit_cg[bt].sample(CRR_RESPONSE_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(STBY_CR_DYN_ADDR_SIGNAL_EN_bit_cg[bt]) this.STBY_CR_DYN_ADDR_SIGNAL_EN_bit_cg[bt].sample(STBY_CR_DYN_ADDR_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(STBY_CR_ACCEPT_NACKED_SIGNAL_EN_bit_cg[bt]) this.STBY_CR_ACCEPT_NACKED_SIGNAL_EN_bit_cg[bt].sample(STBY_CR_ACCEPT_NACKED_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(STBY_CR_ACCEPT_OK_SIGNAL_EN_bit_cg[bt]) this.STBY_CR_ACCEPT_OK_SIGNAL_EN_bit_cg[bt].sample(STBY_CR_ACCEPT_OK_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(STBY_CR_ACCEPT_ERR_SIGNAL_EN_bit_cg[bt]) this.STBY_CR_ACCEPT_ERR_SIGNAL_EN_bit_cg[bt].sample(STBY_CR_ACCEPT_ERR_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(STBY_CR_OP_RSTACT_SIGNAL_EN_bit_cg[bt]) this.STBY_CR_OP_RSTACT_SIGNAL_EN_bit_cg[bt].sample(STBY_CR_OP_RSTACT_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(CCC_PARAM_MODIFIED_SIGNAL_EN_bit_cg[bt]) this.CCC_PARAM_MODIFIED_SIGNAL_EN_bit_cg[bt].sample(CCC_PARAM_MODIFIED_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(CCC_UNHANDLED_NACK_SIGNAL_EN_bit_cg[bt]) this.CCC_UNHANDLED_NACK_SIGNAL_EN_bit_cg[bt].sample(CCC_UNHANDLED_NACK_SIGNAL_EN.get_mirrored_value() >> bt);
            foreach(CCC_FATAL_RSTDAA_ERR_SIGNAL_EN_bit_cg[bt]) this.CCC_FATAL_RSTDAA_ERR_SIGNAL_EN_bit_cg[bt].sample(CCC_FATAL_RSTDAA_ERR_SIGNAL_EN.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( ACR_HANDOFF_OK_REMAIN_SIGNAL_EN.get_mirrored_value()  ,  ACR_HANDOFF_OK_PRIMED_SIGNAL_EN.get_mirrored_value()  ,  ACR_HANDOFF_ERR_FAIL_SIGNAL_EN.get_mirrored_value()  ,  ACR_HANDOFF_ERR_M3_SIGNAL_EN.get_mirrored_value()  ,  CRR_RESPONSE_SIGNAL_EN.get_mirrored_value()  ,  STBY_CR_DYN_ADDR_SIGNAL_EN.get_mirrored_value()  ,  STBY_CR_ACCEPT_NACKED_SIGNAL_EN.get_mirrored_value()  ,  STBY_CR_ACCEPT_OK_SIGNAL_EN.get_mirrored_value()  ,  STBY_CR_ACCEPT_ERR_SIGNAL_EN.get_mirrored_value()  ,  STBY_CR_OP_RSTACT_SIGNAL_EN.get_mirrored_value()  ,  CCC_PARAM_MODIFIED_SIGNAL_EN.get_mirrored_value()  ,  CCC_UNHANDLED_NACK_SIGNAL_EN.get_mirrored_value()  ,  CCC_FATAL_RSTDAA_ERR_SIGNAL_EN.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_INTR_FORCE SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_INTR_FORCE::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CRR_RESPONSE_FORCE_bit_cg[bt]) this.CRR_RESPONSE_FORCE_bit_cg[bt].sample(data[10 + bt]);
            foreach(STBY_CR_DYN_ADDR_FORCE_bit_cg[bt]) this.STBY_CR_DYN_ADDR_FORCE_bit_cg[bt].sample(data[11 + bt]);
            foreach(STBY_CR_ACCEPT_NACKED_FORCE_bit_cg[bt]) this.STBY_CR_ACCEPT_NACKED_FORCE_bit_cg[bt].sample(data[12 + bt]);
            foreach(STBY_CR_ACCEPT_OK_FORCE_bit_cg[bt]) this.STBY_CR_ACCEPT_OK_FORCE_bit_cg[bt].sample(data[13 + bt]);
            foreach(STBY_CR_ACCEPT_ERR_FORCE_bit_cg[bt]) this.STBY_CR_ACCEPT_ERR_FORCE_bit_cg[bt].sample(data[14 + bt]);
            foreach(STBY_CR_OP_RSTACT_FORCE_bit_cg[bt]) this.STBY_CR_OP_RSTACT_FORCE_bit_cg[bt].sample(data[16 + bt]);
            foreach(CCC_PARAM_MODIFIED_FORCE_bit_cg[bt]) this.CCC_PARAM_MODIFIED_FORCE_bit_cg[bt].sample(data[17 + bt]);
            foreach(CCC_UNHANDLED_NACK_FORCE_bit_cg[bt]) this.CCC_UNHANDLED_NACK_FORCE_bit_cg[bt].sample(data[18 + bt]);
            foreach(CCC_FATAL_RSTDAA_ERR_FORCE_bit_cg[bt]) this.CCC_FATAL_RSTDAA_ERR_FORCE_bit_cg[bt].sample(data[19 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[10:10]/*CRR_RESPONSE_FORCE*/  ,  data[11:11]/*STBY_CR_DYN_ADDR_FORCE*/  ,  data[12:12]/*STBY_CR_ACCEPT_NACKED_FORCE*/  ,  data[13:13]/*STBY_CR_ACCEPT_OK_FORCE*/  ,  data[14:14]/*STBY_CR_ACCEPT_ERR_FORCE*/  ,  data[16:16]/*STBY_CR_OP_RSTACT_FORCE*/  ,  data[17:17]/*CCC_PARAM_MODIFIED_FORCE*/  ,  data[18:18]/*CCC_UNHANDLED_NACK_FORCE*/  ,  data[19:19]/*CCC_FATAL_RSTDAA_ERR_FORCE*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_INTR_FORCE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CRR_RESPONSE_FORCE_bit_cg[bt]) this.CRR_RESPONSE_FORCE_bit_cg[bt].sample(CRR_RESPONSE_FORCE.get_mirrored_value() >> bt);
            foreach(STBY_CR_DYN_ADDR_FORCE_bit_cg[bt]) this.STBY_CR_DYN_ADDR_FORCE_bit_cg[bt].sample(STBY_CR_DYN_ADDR_FORCE.get_mirrored_value() >> bt);
            foreach(STBY_CR_ACCEPT_NACKED_FORCE_bit_cg[bt]) this.STBY_CR_ACCEPT_NACKED_FORCE_bit_cg[bt].sample(STBY_CR_ACCEPT_NACKED_FORCE.get_mirrored_value() >> bt);
            foreach(STBY_CR_ACCEPT_OK_FORCE_bit_cg[bt]) this.STBY_CR_ACCEPT_OK_FORCE_bit_cg[bt].sample(STBY_CR_ACCEPT_OK_FORCE.get_mirrored_value() >> bt);
            foreach(STBY_CR_ACCEPT_ERR_FORCE_bit_cg[bt]) this.STBY_CR_ACCEPT_ERR_FORCE_bit_cg[bt].sample(STBY_CR_ACCEPT_ERR_FORCE.get_mirrored_value() >> bt);
            foreach(STBY_CR_OP_RSTACT_FORCE_bit_cg[bt]) this.STBY_CR_OP_RSTACT_FORCE_bit_cg[bt].sample(STBY_CR_OP_RSTACT_FORCE.get_mirrored_value() >> bt);
            foreach(CCC_PARAM_MODIFIED_FORCE_bit_cg[bt]) this.CCC_PARAM_MODIFIED_FORCE_bit_cg[bt].sample(CCC_PARAM_MODIFIED_FORCE.get_mirrored_value() >> bt);
            foreach(CCC_UNHANDLED_NACK_FORCE_bit_cg[bt]) this.CCC_UNHANDLED_NACK_FORCE_bit_cg[bt].sample(CCC_UNHANDLED_NACK_FORCE.get_mirrored_value() >> bt);
            foreach(CCC_FATAL_RSTDAA_ERR_FORCE_bit_cg[bt]) this.CCC_FATAL_RSTDAA_ERR_FORCE_bit_cg[bt].sample(CCC_FATAL_RSTDAA_ERR_FORCE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( CRR_RESPONSE_FORCE.get_mirrored_value()  ,  STBY_CR_DYN_ADDR_FORCE.get_mirrored_value()  ,  STBY_CR_ACCEPT_NACKED_FORCE.get_mirrored_value()  ,  STBY_CR_ACCEPT_OK_FORCE.get_mirrored_value()  ,  STBY_CR_ACCEPT_ERR_FORCE.get_mirrored_value()  ,  STBY_CR_OP_RSTACT_FORCE.get_mirrored_value()  ,  CCC_PARAM_MODIFIED_FORCE.get_mirrored_value()  ,  CCC_UNHANDLED_NACK_FORCE.get_mirrored_value()  ,  CCC_FATAL_RSTDAA_ERR_FORCE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_CCC_CONFIG_GETCAPS SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CCC_CONFIG_GETCAPS::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(F2_CRCAP1_BUS_CONFIG_bit_cg[bt]) this.F2_CRCAP1_BUS_CONFIG_bit_cg[bt].sample(data[0 + bt]);
            foreach(F2_CRCAP2_DEV_INTERACT_bit_cg[bt]) this.F2_CRCAP2_DEV_INTERACT_bit_cg[bt].sample(data[8 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[2:0]/*F2_CRCAP1_BUS_CONFIG*/  ,  data[11:8]/*F2_CRCAP2_DEV_INTERACT*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CCC_CONFIG_GETCAPS::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(F2_CRCAP1_BUS_CONFIG_bit_cg[bt]) this.F2_CRCAP1_BUS_CONFIG_bit_cg[bt].sample(F2_CRCAP1_BUS_CONFIG.get_mirrored_value() >> bt);
            foreach(F2_CRCAP2_DEV_INTERACT_bit_cg[bt]) this.F2_CRCAP2_DEV_INTERACT_bit_cg[bt].sample(F2_CRCAP2_DEV_INTERACT.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( F2_CRCAP1_BUS_CONFIG.get_mirrored_value()  ,  F2_CRCAP2_DEV_INTERACT.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_CCC_CONFIG_RSTACT_PARAMS SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CCC_CONFIG_RSTACT_PARAMS::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(RST_ACTION_bit_cg[bt]) this.RST_ACTION_bit_cg[bt].sample(data[0 + bt]);
            foreach(RESET_TIME_PERIPHERAL_bit_cg[bt]) this.RESET_TIME_PERIPHERAL_bit_cg[bt].sample(data[8 + bt]);
            foreach(RESET_TIME_TARGET_bit_cg[bt]) this.RESET_TIME_TARGET_bit_cg[bt].sample(data[16 + bt]);
            foreach(RESET_DYNAMIC_ADDR_bit_cg[bt]) this.RESET_DYNAMIC_ADDR_bit_cg[bt].sample(data[31 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*RST_ACTION*/  ,  data[15:8]/*RESET_TIME_PERIPHERAL*/  ,  data[23:16]/*RESET_TIME_TARGET*/  ,  data[31:31]/*RESET_DYNAMIC_ADDR*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_CCC_CONFIG_RSTACT_PARAMS::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(RST_ACTION_bit_cg[bt]) this.RST_ACTION_bit_cg[bt].sample(RST_ACTION.get_mirrored_value() >> bt);
            foreach(RESET_TIME_PERIPHERAL_bit_cg[bt]) this.RESET_TIME_PERIPHERAL_bit_cg[bt].sample(RESET_TIME_PERIPHERAL.get_mirrored_value() >> bt);
            foreach(RESET_TIME_TARGET_bit_cg[bt]) this.RESET_TIME_TARGET_bit_cg[bt].sample(RESET_TIME_TARGET.get_mirrored_value() >> bt);
            foreach(RESET_DYNAMIC_ADDR_bit_cg[bt]) this.RESET_DYNAMIC_ADDR_bit_cg[bt].sample(RESET_DYNAMIC_ADDR.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( RST_ACTION.get_mirrored_value()  ,  RESET_TIME_PERIPHERAL.get_mirrored_value()  ,  RESET_TIME_TARGET.get_mirrored_value()  ,  RESET_DYNAMIC_ADDR.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE____RSVD_2 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode____rsvd_2::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(__rsvd_bit_cg[bt]) this.__rsvd_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*__rsvd*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode____rsvd_2::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(__rsvd_bit_cg[bt]) this.__rsvd_bit_cg[bt].sample(__rsvd.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( __rsvd.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE____RSVD_3 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode____rsvd_3::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(__rsvd_bit_cg[bt]) this.__rsvd_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*__rsvd*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode____rsvd_3::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(__rsvd_bit_cg[bt]) this.__rsvd_bit_cg[bt].sample(__rsvd.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( __rsvd.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__EXTCAP_HEADER SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__EXTCAP_HEADER::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(data[0 + bt]);
            foreach(CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(data[8 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*CAP_ID*/  ,  data[23:8]/*CAP_LENGTH*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__EXTCAP_HEADER::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(CAP_ID.get_mirrored_value() >> bt);
            foreach(CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(CAP_LENGTH.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( CAP_ID.get_mirrored_value()  ,  CAP_LENGTH.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__CONTROL SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__CONTROL::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__CONTROL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__STATUS SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__STATUS::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__STATUS::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__RESET_CONTROL SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__RESET_CONTROL::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(SOFT_RST_bit_cg[bt]) this.SOFT_RST_bit_cg[bt].sample(data[0 + bt]);
            foreach(TX_DESC_RST_bit_cg[bt]) this.TX_DESC_RST_bit_cg[bt].sample(data[1 + bt]);
            foreach(RX_DESC_RST_bit_cg[bt]) this.RX_DESC_RST_bit_cg[bt].sample(data[2 + bt]);
            foreach(TX_DATA_RST_bit_cg[bt]) this.TX_DATA_RST_bit_cg[bt].sample(data[3 + bt]);
            foreach(RX_DATA_RST_bit_cg[bt]) this.RX_DATA_RST_bit_cg[bt].sample(data[4 + bt]);
            foreach(IBI_QUEUE_RST_bit_cg[bt]) this.IBI_QUEUE_RST_bit_cg[bt].sample(data[5 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*SOFT_RST*/  ,  data[1:1]/*TX_DESC_RST*/  ,  data[2:2]/*RX_DESC_RST*/  ,  data[3:3]/*TX_DATA_RST*/  ,  data[4:4]/*RX_DATA_RST*/  ,  data[5:5]/*IBI_QUEUE_RST*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__RESET_CONTROL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(SOFT_RST_bit_cg[bt]) this.SOFT_RST_bit_cg[bt].sample(SOFT_RST.get_mirrored_value() >> bt);
            foreach(TX_DESC_RST_bit_cg[bt]) this.TX_DESC_RST_bit_cg[bt].sample(TX_DESC_RST.get_mirrored_value() >> bt);
            foreach(RX_DESC_RST_bit_cg[bt]) this.RX_DESC_RST_bit_cg[bt].sample(RX_DESC_RST.get_mirrored_value() >> bt);
            foreach(TX_DATA_RST_bit_cg[bt]) this.TX_DATA_RST_bit_cg[bt].sample(TX_DATA_RST.get_mirrored_value() >> bt);
            foreach(RX_DATA_RST_bit_cg[bt]) this.RX_DATA_RST_bit_cg[bt].sample(RX_DATA_RST.get_mirrored_value() >> bt);
            foreach(IBI_QUEUE_RST_bit_cg[bt]) this.IBI_QUEUE_RST_bit_cg[bt].sample(IBI_QUEUE_RST.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( SOFT_RST.get_mirrored_value()  ,  TX_DESC_RST.get_mirrored_value()  ,  RX_DESC_RST.get_mirrored_value()  ,  TX_DATA_RST.get_mirrored_value()  ,  RX_DATA_RST.get_mirrored_value()  ,  IBI_QUEUE_RST.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__INTERRUPT_STATUS SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__INTERRUPT_STATUS::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(RX_DESC_STAT_bit_cg[bt]) this.RX_DESC_STAT_bit_cg[bt].sample(data[0 + bt]);
            foreach(TX_DESC_STAT_bit_cg[bt]) this.TX_DESC_STAT_bit_cg[bt].sample(data[1 + bt]);
            foreach(RX_DESC_TIMEOUT_bit_cg[bt]) this.RX_DESC_TIMEOUT_bit_cg[bt].sample(data[2 + bt]);
            foreach(TX_DESC_TIMEOUT_bit_cg[bt]) this.TX_DESC_TIMEOUT_bit_cg[bt].sample(data[3 + bt]);
            foreach(TX_DATA_THLD_STAT_bit_cg[bt]) this.TX_DATA_THLD_STAT_bit_cg[bt].sample(data[8 + bt]);
            foreach(RX_DATA_THLD_STAT_bit_cg[bt]) this.RX_DATA_THLD_STAT_bit_cg[bt].sample(data[9 + bt]);
            foreach(TX_DESC_THLD_STAT_bit_cg[bt]) this.TX_DESC_THLD_STAT_bit_cg[bt].sample(data[10 + bt]);
            foreach(RX_DESC_THLD_STAT_bit_cg[bt]) this.RX_DESC_THLD_STAT_bit_cg[bt].sample(data[11 + bt]);
            foreach(IBI_THLD_STAT_bit_cg[bt]) this.IBI_THLD_STAT_bit_cg[bt].sample(data[12 + bt]);
            foreach(TRANSFER_ABORT_STAT_bit_cg[bt]) this.TRANSFER_ABORT_STAT_bit_cg[bt].sample(data[25 + bt]);
            foreach(TRANSFER_ERR_STAT_bit_cg[bt]) this.TRANSFER_ERR_STAT_bit_cg[bt].sample(data[31 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*RX_DESC_STAT*/  ,  data[1:1]/*TX_DESC_STAT*/  ,  data[2:2]/*RX_DESC_TIMEOUT*/  ,  data[3:3]/*TX_DESC_TIMEOUT*/  ,  data[8:8]/*TX_DATA_THLD_STAT*/  ,  data[9:9]/*RX_DATA_THLD_STAT*/  ,  data[10:10]/*TX_DESC_THLD_STAT*/  ,  data[11:11]/*RX_DESC_THLD_STAT*/  ,  data[12:12]/*IBI_THLD_STAT*/  ,  data[25:25]/*TRANSFER_ABORT_STAT*/  ,  data[31:31]/*TRANSFER_ERR_STAT*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__INTERRUPT_STATUS::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(RX_DESC_STAT_bit_cg[bt]) this.RX_DESC_STAT_bit_cg[bt].sample(RX_DESC_STAT.get_mirrored_value() >> bt);
            foreach(TX_DESC_STAT_bit_cg[bt]) this.TX_DESC_STAT_bit_cg[bt].sample(TX_DESC_STAT.get_mirrored_value() >> bt);
            foreach(RX_DESC_TIMEOUT_bit_cg[bt]) this.RX_DESC_TIMEOUT_bit_cg[bt].sample(RX_DESC_TIMEOUT.get_mirrored_value() >> bt);
            foreach(TX_DESC_TIMEOUT_bit_cg[bt]) this.TX_DESC_TIMEOUT_bit_cg[bt].sample(TX_DESC_TIMEOUT.get_mirrored_value() >> bt);
            foreach(TX_DATA_THLD_STAT_bit_cg[bt]) this.TX_DATA_THLD_STAT_bit_cg[bt].sample(TX_DATA_THLD_STAT.get_mirrored_value() >> bt);
            foreach(RX_DATA_THLD_STAT_bit_cg[bt]) this.RX_DATA_THLD_STAT_bit_cg[bt].sample(RX_DATA_THLD_STAT.get_mirrored_value() >> bt);
            foreach(TX_DESC_THLD_STAT_bit_cg[bt]) this.TX_DESC_THLD_STAT_bit_cg[bt].sample(TX_DESC_THLD_STAT.get_mirrored_value() >> bt);
            foreach(RX_DESC_THLD_STAT_bit_cg[bt]) this.RX_DESC_THLD_STAT_bit_cg[bt].sample(RX_DESC_THLD_STAT.get_mirrored_value() >> bt);
            foreach(IBI_THLD_STAT_bit_cg[bt]) this.IBI_THLD_STAT_bit_cg[bt].sample(IBI_THLD_STAT.get_mirrored_value() >> bt);
            foreach(TRANSFER_ABORT_STAT_bit_cg[bt]) this.TRANSFER_ABORT_STAT_bit_cg[bt].sample(TRANSFER_ABORT_STAT.get_mirrored_value() >> bt);
            foreach(TRANSFER_ERR_STAT_bit_cg[bt]) this.TRANSFER_ERR_STAT_bit_cg[bt].sample(TRANSFER_ERR_STAT.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( RX_DESC_STAT.get_mirrored_value()  ,  TX_DESC_STAT.get_mirrored_value()  ,  RX_DESC_TIMEOUT.get_mirrored_value()  ,  TX_DESC_TIMEOUT.get_mirrored_value()  ,  TX_DATA_THLD_STAT.get_mirrored_value()  ,  RX_DATA_THLD_STAT.get_mirrored_value()  ,  TX_DESC_THLD_STAT.get_mirrored_value()  ,  RX_DESC_THLD_STAT.get_mirrored_value()  ,  IBI_THLD_STAT.get_mirrored_value()  ,  TRANSFER_ABORT_STAT.get_mirrored_value()  ,  TRANSFER_ERR_STAT.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__INTERRUPT_ENABLE SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__INTERRUPT_ENABLE::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_DATA_THLD_STAT_EN_bit_cg[bt]) this.TX_DATA_THLD_STAT_EN_bit_cg[bt].sample(data[0 + bt]);
            foreach(RX_DATA_THLD_STAT_EN_bit_cg[bt]) this.RX_DATA_THLD_STAT_EN_bit_cg[bt].sample(data[1 + bt]);
            foreach(TX_DESC_THLD_STAT_EN_bit_cg[bt]) this.TX_DESC_THLD_STAT_EN_bit_cg[bt].sample(data[2 + bt]);
            foreach(RX_DESC_THLD_STAT_EN_bit_cg[bt]) this.RX_DESC_THLD_STAT_EN_bit_cg[bt].sample(data[3 + bt]);
            foreach(IBI_THLD_STAT_EN_bit_cg[bt]) this.IBI_THLD_STAT_EN_bit_cg[bt].sample(data[4 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*TX_DATA_THLD_STAT_EN*/  ,  data[1:1]/*RX_DATA_THLD_STAT_EN*/  ,  data[2:2]/*TX_DESC_THLD_STAT_EN*/  ,  data[3:3]/*RX_DESC_THLD_STAT_EN*/  ,  data[4:4]/*IBI_THLD_STAT_EN*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__INTERRUPT_ENABLE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_DATA_THLD_STAT_EN_bit_cg[bt]) this.TX_DATA_THLD_STAT_EN_bit_cg[bt].sample(TX_DATA_THLD_STAT_EN.get_mirrored_value() >> bt);
            foreach(RX_DATA_THLD_STAT_EN_bit_cg[bt]) this.RX_DATA_THLD_STAT_EN_bit_cg[bt].sample(RX_DATA_THLD_STAT_EN.get_mirrored_value() >> bt);
            foreach(TX_DESC_THLD_STAT_EN_bit_cg[bt]) this.TX_DESC_THLD_STAT_EN_bit_cg[bt].sample(TX_DESC_THLD_STAT_EN.get_mirrored_value() >> bt);
            foreach(RX_DESC_THLD_STAT_EN_bit_cg[bt]) this.RX_DESC_THLD_STAT_EN_bit_cg[bt].sample(RX_DESC_THLD_STAT_EN.get_mirrored_value() >> bt);
            foreach(IBI_THLD_STAT_EN_bit_cg[bt]) this.IBI_THLD_STAT_EN_bit_cg[bt].sample(IBI_THLD_STAT_EN.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( TX_DATA_THLD_STAT_EN.get_mirrored_value()  ,  RX_DATA_THLD_STAT_EN.get_mirrored_value()  ,  TX_DESC_THLD_STAT_EN.get_mirrored_value()  ,  RX_DESC_THLD_STAT_EN.get_mirrored_value()  ,  IBI_THLD_STAT_EN.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__INTERRUPT_FORCE SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__INTERRUPT_FORCE::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_DATA_THLD_FORCE_bit_cg[bt]) this.TX_DATA_THLD_FORCE_bit_cg[bt].sample(data[0 + bt]);
            foreach(RX_DATA_THLD_FORCE_bit_cg[bt]) this.RX_DATA_THLD_FORCE_bit_cg[bt].sample(data[1 + bt]);
            foreach(TX_DESC_THLD_FORCE_bit_cg[bt]) this.TX_DESC_THLD_FORCE_bit_cg[bt].sample(data[2 + bt]);
            foreach(RX_DESC_THLD_FORCE_bit_cg[bt]) this.RX_DESC_THLD_FORCE_bit_cg[bt].sample(data[3 + bt]);
            foreach(IBI_THLD_FORCE_bit_cg[bt]) this.IBI_THLD_FORCE_bit_cg[bt].sample(data[4 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*TX_DATA_THLD_FORCE*/  ,  data[1:1]/*RX_DATA_THLD_FORCE*/  ,  data[2:2]/*TX_DESC_THLD_FORCE*/  ,  data[3:3]/*RX_DESC_THLD_FORCE*/  ,  data[4:4]/*IBI_THLD_FORCE*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__INTERRUPT_FORCE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_DATA_THLD_FORCE_bit_cg[bt]) this.TX_DATA_THLD_FORCE_bit_cg[bt].sample(TX_DATA_THLD_FORCE.get_mirrored_value() >> bt);
            foreach(RX_DATA_THLD_FORCE_bit_cg[bt]) this.RX_DATA_THLD_FORCE_bit_cg[bt].sample(RX_DATA_THLD_FORCE.get_mirrored_value() >> bt);
            foreach(TX_DESC_THLD_FORCE_bit_cg[bt]) this.TX_DESC_THLD_FORCE_bit_cg[bt].sample(TX_DESC_THLD_FORCE.get_mirrored_value() >> bt);
            foreach(RX_DESC_THLD_FORCE_bit_cg[bt]) this.RX_DESC_THLD_FORCE_bit_cg[bt].sample(RX_DESC_THLD_FORCE.get_mirrored_value() >> bt);
            foreach(IBI_THLD_FORCE_bit_cg[bt]) this.IBI_THLD_FORCE_bit_cg[bt].sample(IBI_THLD_FORCE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( TX_DATA_THLD_FORCE.get_mirrored_value()  ,  RX_DATA_THLD_FORCE.get_mirrored_value()  ,  TX_DESC_THLD_FORCE.get_mirrored_value()  ,  RX_DESC_THLD_FORCE.get_mirrored_value()  ,  IBI_THLD_FORCE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__RX_DESC_QUEUE_PORT SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__RX_DESC_QUEUE_PORT::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(RX_DESC_bit_cg[bt]) this.RX_DESC_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*RX_DESC*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__RX_DESC_QUEUE_PORT::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(RX_DESC_bit_cg[bt]) this.RX_DESC_bit_cg[bt].sample(RX_DESC.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( RX_DESC.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__RX_DATA_PORT SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__RX_DATA_PORT::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(RX_DATA_bit_cg[bt]) this.RX_DATA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*RX_DATA*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__RX_DATA_PORT::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(RX_DATA_bit_cg[bt]) this.RX_DATA_bit_cg[bt].sample(RX_DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( RX_DATA.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__TX_DESC_QUEUE_PORT SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__TX_DESC_QUEUE_PORT::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_DESC_bit_cg[bt]) this.TX_DESC_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*TX_DESC*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__TX_DESC_QUEUE_PORT::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_DESC_bit_cg[bt]) this.TX_DESC_bit_cg[bt].sample(TX_DESC.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( TX_DESC.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__TX_DATA_PORT SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__TX_DATA_PORT::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_DATA_bit_cg[bt]) this.TX_DATA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*TX_DATA*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__TX_DATA_PORT::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_DATA_bit_cg[bt]) this.TX_DATA_bit_cg[bt].sample(TX_DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( TX_DATA.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__IBI_PORT SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__IBI_PORT::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(IBI_DATA_bit_cg[bt]) this.IBI_DATA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*IBI_DATA*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__IBI_PORT::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(IBI_DATA_bit_cg[bt]) this.IBI_DATA_bit_cg[bt].sample(IBI_DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( IBI_DATA.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__QUEUE_SIZE SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__QUEUE_SIZE::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(RX_DESC_BUFFER_SIZE_bit_cg[bt]) this.RX_DESC_BUFFER_SIZE_bit_cg[bt].sample(data[0 + bt]);
            foreach(TX_DESC_BUFFER_SIZE_bit_cg[bt]) this.TX_DESC_BUFFER_SIZE_bit_cg[bt].sample(data[8 + bt]);
            foreach(RX_DATA_BUFFER_SIZE_bit_cg[bt]) this.RX_DATA_BUFFER_SIZE_bit_cg[bt].sample(data[16 + bt]);
            foreach(TX_DATA_BUFFER_SIZE_bit_cg[bt]) this.TX_DATA_BUFFER_SIZE_bit_cg[bt].sample(data[24 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*RX_DESC_BUFFER_SIZE*/  ,  data[15:8]/*TX_DESC_BUFFER_SIZE*/  ,  data[23:16]/*RX_DATA_BUFFER_SIZE*/  ,  data[31:24]/*TX_DATA_BUFFER_SIZE*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__QUEUE_SIZE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(RX_DESC_BUFFER_SIZE_bit_cg[bt]) this.RX_DESC_BUFFER_SIZE_bit_cg[bt].sample(RX_DESC_BUFFER_SIZE.get_mirrored_value() >> bt);
            foreach(TX_DESC_BUFFER_SIZE_bit_cg[bt]) this.TX_DESC_BUFFER_SIZE_bit_cg[bt].sample(TX_DESC_BUFFER_SIZE.get_mirrored_value() >> bt);
            foreach(RX_DATA_BUFFER_SIZE_bit_cg[bt]) this.RX_DATA_BUFFER_SIZE_bit_cg[bt].sample(RX_DATA_BUFFER_SIZE.get_mirrored_value() >> bt);
            foreach(TX_DATA_BUFFER_SIZE_bit_cg[bt]) this.TX_DATA_BUFFER_SIZE_bit_cg[bt].sample(TX_DATA_BUFFER_SIZE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( RX_DESC_BUFFER_SIZE.get_mirrored_value()  ,  TX_DESC_BUFFER_SIZE.get_mirrored_value()  ,  RX_DATA_BUFFER_SIZE.get_mirrored_value()  ,  TX_DATA_BUFFER_SIZE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__IBI_QUEUE_SIZE SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__IBI_QUEUE_SIZE::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(IBI_QUEUE_SIZE_bit_cg[bt]) this.IBI_QUEUE_SIZE_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*IBI_QUEUE_SIZE*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__IBI_QUEUE_SIZE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(IBI_QUEUE_SIZE_bit_cg[bt]) this.IBI_QUEUE_SIZE_bit_cg[bt].sample(IBI_QUEUE_SIZE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( IBI_QUEUE_SIZE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__QUEUE_THLD_CTRL SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__QUEUE_THLD_CTRL::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_DESC_THLD_bit_cg[bt]) this.TX_DESC_THLD_bit_cg[bt].sample(data[0 + bt]);
            foreach(RX_DESC_THLD_bit_cg[bt]) this.RX_DESC_THLD_bit_cg[bt].sample(data[8 + bt]);
            foreach(IBI_THLD_bit_cg[bt]) this.IBI_THLD_bit_cg[bt].sample(data[24 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*TX_DESC_THLD*/  ,  data[15:8]/*RX_DESC_THLD*/  ,  data[31:24]/*IBI_THLD*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__QUEUE_THLD_CTRL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_DESC_THLD_bit_cg[bt]) this.TX_DESC_THLD_bit_cg[bt].sample(TX_DESC_THLD.get_mirrored_value() >> bt);
            foreach(RX_DESC_THLD_bit_cg[bt]) this.RX_DESC_THLD_bit_cg[bt].sample(RX_DESC_THLD.get_mirrored_value() >> bt);
            foreach(IBI_THLD_bit_cg[bt]) this.IBI_THLD_bit_cg[bt].sample(IBI_THLD.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( TX_DESC_THLD.get_mirrored_value()  ,  RX_DESC_THLD.get_mirrored_value()  ,  IBI_THLD.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TTI__DATA_BUFFER_THLD_CTRL SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TTI__DATA_BUFFER_THLD_CTRL::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_DATA_THLD_bit_cg[bt]) this.TX_DATA_THLD_bit_cg[bt].sample(data[0 + bt]);
            foreach(RX_DATA_THLD_bit_cg[bt]) this.RX_DATA_THLD_bit_cg[bt].sample(data[8 + bt]);
            foreach(TX_START_THLD_bit_cg[bt]) this.TX_START_THLD_bit_cg[bt].sample(data[16 + bt]);
            foreach(RX_START_THLD_bit_cg[bt]) this.RX_START_THLD_bit_cg[bt].sample(data[24 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[2:0]/*TX_DATA_THLD*/  ,  data[10:8]/*RX_DATA_THLD*/  ,  data[18:16]/*TX_START_THLD*/  ,  data[26:24]/*RX_START_THLD*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__DATA_BUFFER_THLD_CTRL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TX_DATA_THLD_bit_cg[bt]) this.TX_DATA_THLD_bit_cg[bt].sample(TX_DATA_THLD.get_mirrored_value() >> bt);
            foreach(RX_DATA_THLD_bit_cg[bt]) this.RX_DATA_THLD_bit_cg[bt].sample(RX_DATA_THLD.get_mirrored_value() >> bt);
            foreach(TX_START_THLD_bit_cg[bt]) this.TX_START_THLD_bit_cg[bt].sample(TX_START_THLD.get_mirrored_value() >> bt);
            foreach(RX_START_THLD_bit_cg[bt]) this.RX_START_THLD_bit_cg[bt].sample(RX_START_THLD.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( TX_DATA_THLD.get_mirrored_value()  ,  RX_DATA_THLD.get_mirrored_value()  ,  TX_START_THLD.get_mirrored_value()  ,  RX_START_THLD.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__EXTCAP_HEADER SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__EXTCAP_HEADER::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(data[0 + bt]);
            foreach(CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(data[8 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*CAP_ID*/  ,  data[23:8]/*CAP_LENGTH*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__EXTCAP_HEADER::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(CAP_ID.get_mirrored_value() >> bt);
            foreach(CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(CAP_LENGTH.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( CAP_ID.get_mirrored_value()  ,  CAP_LENGTH.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_CONTROL SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_CONTROL::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_CONTROL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_STATUS SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_STATUS::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_STATUS::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_RSVD_0 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_0::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_0::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_RSVD_1 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_1::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_1::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_RSVD_2 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_2::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_2::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_RSVD_3 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_3::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_RSVD_3::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_PAD_CONF SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_PAD_CONF::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(INPUT_ENABLE_bit_cg[bt]) this.INPUT_ENABLE_bit_cg[bt].sample(data[0 + bt]);
            foreach(SCHMITT_EN_bit_cg[bt]) this.SCHMITT_EN_bit_cg[bt].sample(data[1 + bt]);
            foreach(KEEPER_EN_bit_cg[bt]) this.KEEPER_EN_bit_cg[bt].sample(data[2 + bt]);
            foreach(PULL_DIR_bit_cg[bt]) this.PULL_DIR_bit_cg[bt].sample(data[3 + bt]);
            foreach(PULL_EN_bit_cg[bt]) this.PULL_EN_bit_cg[bt].sample(data[4 + bt]);
            foreach(IO_INVERSION_bit_cg[bt]) this.IO_INVERSION_bit_cg[bt].sample(data[5 + bt]);
            foreach(OD_EN_bit_cg[bt]) this.OD_EN_bit_cg[bt].sample(data[6 + bt]);
            foreach(VIRTUAL_OD_EN_bit_cg[bt]) this.VIRTUAL_OD_EN_bit_cg[bt].sample(data[7 + bt]);
            foreach(PAD_TYPE_bit_cg[bt]) this.PAD_TYPE_bit_cg[bt].sample(data[24 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*INPUT_ENABLE*/  ,  data[1:1]/*SCHMITT_EN*/  ,  data[2:2]/*KEEPER_EN*/  ,  data[3:3]/*PULL_DIR*/  ,  data[4:4]/*PULL_EN*/  ,  data[5:5]/*IO_INVERSION*/  ,  data[6:6]/*OD_EN*/  ,  data[7:7]/*VIRTUAL_OD_EN*/  ,  data[31:24]/*PAD_TYPE*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_PAD_CONF::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(INPUT_ENABLE_bit_cg[bt]) this.INPUT_ENABLE_bit_cg[bt].sample(INPUT_ENABLE.get_mirrored_value() >> bt);
            foreach(SCHMITT_EN_bit_cg[bt]) this.SCHMITT_EN_bit_cg[bt].sample(SCHMITT_EN.get_mirrored_value() >> bt);
            foreach(KEEPER_EN_bit_cg[bt]) this.KEEPER_EN_bit_cg[bt].sample(KEEPER_EN.get_mirrored_value() >> bt);
            foreach(PULL_DIR_bit_cg[bt]) this.PULL_DIR_bit_cg[bt].sample(PULL_DIR.get_mirrored_value() >> bt);
            foreach(PULL_EN_bit_cg[bt]) this.PULL_EN_bit_cg[bt].sample(PULL_EN.get_mirrored_value() >> bt);
            foreach(IO_INVERSION_bit_cg[bt]) this.IO_INVERSION_bit_cg[bt].sample(IO_INVERSION.get_mirrored_value() >> bt);
            foreach(OD_EN_bit_cg[bt]) this.OD_EN_bit_cg[bt].sample(OD_EN.get_mirrored_value() >> bt);
            foreach(VIRTUAL_OD_EN_bit_cg[bt]) this.VIRTUAL_OD_EN_bit_cg[bt].sample(VIRTUAL_OD_EN.get_mirrored_value() >> bt);
            foreach(PAD_TYPE_bit_cg[bt]) this.PAD_TYPE_bit_cg[bt].sample(PAD_TYPE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( INPUT_ENABLE.get_mirrored_value()  ,  SCHMITT_EN.get_mirrored_value()  ,  KEEPER_EN.get_mirrored_value()  ,  PULL_DIR.get_mirrored_value()  ,  PULL_EN.get_mirrored_value()  ,  IO_INVERSION.get_mirrored_value()  ,  OD_EN.get_mirrored_value()  ,  VIRTUAL_OD_EN.get_mirrored_value()  ,  PAD_TYPE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_PAD_ATTR SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_PAD_ATTR::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DRIVE_SLEW_RATE_bit_cg[bt]) this.DRIVE_SLEW_RATE_bit_cg[bt].sample(data[8 + bt]);
            foreach(DRIVE_STRENGTH_bit_cg[bt]) this.DRIVE_STRENGTH_bit_cg[bt].sample(data[24 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[15:8]/*DRIVE_SLEW_RATE*/  ,  data[31:24]/*DRIVE_STRENGTH*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_PAD_ATTR::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DRIVE_SLEW_RATE_bit_cg[bt]) this.DRIVE_SLEW_RATE_bit_cg[bt].sample(DRIVE_SLEW_RATE.get_mirrored_value() >> bt);
            foreach(DRIVE_STRENGTH_bit_cg[bt]) this.DRIVE_STRENGTH_bit_cg[bt].sample(DRIVE_STRENGTH.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( DRIVE_SLEW_RATE.get_mirrored_value()  ,  DRIVE_STRENGTH.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_FEATURE_2 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_FEATURE_2::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_FEATURE_2::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__SOC_MGMT_FEATURE_3 SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_FEATURE_3::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*PLACEHOLDER*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__SOC_MGMT_FEATURE_3::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PLACEHOLDER_bit_cg[bt]) this.PLACEHOLDER_bit_cg[bt].sample(PLACEHOLDER.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PLACEHOLDER.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_R_REG SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__T_R_REG::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_R_bit_cg[bt]) this.T_R_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[19:0]/*T_R*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__T_R_REG::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_R_bit_cg[bt]) this.T_R_bit_cg[bt].sample(T_R.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( T_R.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_F_REG SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__T_F_REG::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_F_bit_cg[bt]) this.T_F_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[19:0]/*T_F*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__T_F_REG::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_F_bit_cg[bt]) this.T_F_bit_cg[bt].sample(T_F.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( T_F.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_SU_DAT_REG SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__T_SU_DAT_REG::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_SU_DAT_bit_cg[bt]) this.T_SU_DAT_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[19:0]/*T_SU_DAT*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__T_SU_DAT_REG::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_SU_DAT_bit_cg[bt]) this.T_SU_DAT_bit_cg[bt].sample(T_SU_DAT.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( T_SU_DAT.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_HD_DAT_REG SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__T_HD_DAT_REG::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_HD_DAT_bit_cg[bt]) this.T_HD_DAT_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[19:0]/*T_HD_DAT*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__T_HD_DAT_REG::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_HD_DAT_bit_cg[bt]) this.T_HD_DAT_bit_cg[bt].sample(T_HD_DAT.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( T_HD_DAT.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_HIGH_REG SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__T_HIGH_REG::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_HIGH_bit_cg[bt]) this.T_HIGH_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[19:0]/*T_HIGH*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__T_HIGH_REG::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_HIGH_bit_cg[bt]) this.T_HIGH_bit_cg[bt].sample(T_HIGH.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( T_HIGH.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_LOW_REG SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__T_LOW_REG::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_LOW_bit_cg[bt]) this.T_LOW_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[19:0]/*T_LOW*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__T_LOW_REG::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_LOW_bit_cg[bt]) this.T_LOW_bit_cg[bt].sample(T_LOW.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( T_LOW.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_HD_STA_REG SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__T_HD_STA_REG::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_HD_STA_bit_cg[bt]) this.T_HD_STA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[19:0]/*T_HD_STA*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__T_HD_STA_REG::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_HD_STA_bit_cg[bt]) this.T_HD_STA_bit_cg[bt].sample(T_HD_STA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( T_HD_STA.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_SU_STA_REG SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__T_SU_STA_REG::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_SU_STA_bit_cg[bt]) this.T_SU_STA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[19:0]/*T_SU_STA*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__T_SU_STA_REG::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_SU_STA_bit_cg[bt]) this.T_SU_STA_bit_cg[bt].sample(T_SU_STA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( T_SU_STA.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_SU_STO_REG SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__T_SU_STO_REG::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_SU_STO_bit_cg[bt]) this.T_SU_STO_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[19:0]/*T_SU_STO*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__T_SU_STO_REG::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_SU_STO_bit_cg[bt]) this.T_SU_STO_bit_cg[bt].sample(T_SU_STO.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( T_SU_STO.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_FREE_REG SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__T_FREE_REG::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_FREE_bit_cg[bt]) this.T_FREE_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*T_FREE*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__T_FREE_REG::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_FREE_bit_cg[bt]) this.T_FREE_bit_cg[bt].sample(T_FREE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( T_FREE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_AVAL_REG SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__T_AVAL_REG::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_AVAL_bit_cg[bt]) this.T_AVAL_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*T_AVAL*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__T_AVAL_REG::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_AVAL_bit_cg[bt]) this.T_AVAL_bit_cg[bt].sample(T_AVAL.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( T_AVAL.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__T_IDLE_REG SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__T_IDLE_REG::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_IDLE_bit_cg[bt]) this.T_IDLE_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*T_IDLE*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__T_IDLE_REG::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(T_IDLE_bit_cg[bt]) this.T_IDLE_bit_cg[bt].sample(T_IDLE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( T_IDLE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__CTRLCFG__EXTCAP_HEADER SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__CtrlCfg__EXTCAP_HEADER::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(data[0 + bt]);
            foreach(CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(data[8 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*CAP_ID*/  ,  data[23:8]/*CAP_LENGTH*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__CtrlCfg__EXTCAP_HEADER::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(CAP_ID.get_mirrored_value() >> bt);
            foreach(CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(CAP_LENGTH.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( CAP_ID.get_mirrored_value()  ,  CAP_LENGTH.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__CTRLCFG__CONTROLLER_CONFIG SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__CtrlCfg__CONTROLLER_CONFIG::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(OPERATION_MODE_bit_cg[bt]) this.OPERATION_MODE_bit_cg[bt].sample(data[4 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[5:4]/*OPERATION_MODE*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__CtrlCfg__CONTROLLER_CONFIG::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(OPERATION_MODE_bit_cg[bt]) this.OPERATION_MODE_bit_cg[bt].sample(OPERATION_MODE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( OPERATION_MODE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__TERMINATION_EXTCAP_HEADER SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__TERMINATION_EXTCAP_HEADER::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(data[0 + bt]);
            foreach(CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(data[8 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*CAP_ID*/  ,  data[23:8]/*CAP_LENGTH*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TERMINATION_EXTCAP_HEADER::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CAP_ID_bit_cg[bt]) this.CAP_ID_bit_cg[bt].sample(CAP_ID.get_mirrored_value() >> bt);
            foreach(CAP_LENGTH_bit_cg[bt]) this.CAP_LENGTH_bit_cg[bt].sample(CAP_LENGTH.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( CAP_ID.get_mirrored_value()  ,  CAP_LENGTH.get_mirrored_value()   );
        end
    endfunction

`endif