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
            foreach(REC_MAGIC_STRING_0_bit_cg[bt]) this.REC_MAGIC_STRING_0_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*REC_MAGIC_STRING_0*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_0::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(REC_MAGIC_STRING_0_bit_cg[bt]) this.REC_MAGIC_STRING_0_bit_cg[bt].sample(REC_MAGIC_STRING_0.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( REC_MAGIC_STRING_0.get_mirrored_value()   );
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
            foreach(REC_MAGIC_STRING_1_bit_cg[bt]) this.REC_MAGIC_STRING_1_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*REC_MAGIC_STRING_1*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_1::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(REC_MAGIC_STRING_1_bit_cg[bt]) this.REC_MAGIC_STRING_1_bit_cg[bt].sample(REC_MAGIC_STRING_1.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( REC_MAGIC_STRING_1.get_mirrored_value()   );
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
            foreach(REC_PROT_VERSION_bit_cg[bt]) this.REC_PROT_VERSION_bit_cg[bt].sample(data[0 + bt]);
            foreach(AGENT_CAPS_bit_cg[bt]) this.AGENT_CAPS_bit_cg[bt].sample(data[16 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[15:0]/*REC_PROT_VERSION*/  ,  data[31:16]/*AGENT_CAPS*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_2::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(REC_PROT_VERSION_bit_cg[bt]) this.REC_PROT_VERSION_bit_cg[bt].sample(REC_PROT_VERSION.get_mirrored_value() >> bt);
            foreach(AGENT_CAPS_bit_cg[bt]) this.AGENT_CAPS_bit_cg[bt].sample(AGENT_CAPS.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( REC_PROT_VERSION.get_mirrored_value()  ,  AGENT_CAPS.get_mirrored_value()   );
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
            foreach(NUM_OF_CMS_REGIONS_bit_cg[bt]) this.NUM_OF_CMS_REGIONS_bit_cg[bt].sample(data[0 + bt]);
            foreach(MAX_RESP_TIME_bit_cg[bt]) this.MAX_RESP_TIME_bit_cg[bt].sample(data[8 + bt]);
            foreach(HEARTBEAT_PERIOD_bit_cg[bt]) this.HEARTBEAT_PERIOD_bit_cg[bt].sample(data[16 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*NUM_OF_CMS_REGIONS*/  ,  data[15:8]/*MAX_RESP_TIME*/  ,  data[23:16]/*HEARTBEAT_PERIOD*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__PROT_CAP_3::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(NUM_OF_CMS_REGIONS_bit_cg[bt]) this.NUM_OF_CMS_REGIONS_bit_cg[bt].sample(NUM_OF_CMS_REGIONS.get_mirrored_value() >> bt);
            foreach(MAX_RESP_TIME_bit_cg[bt]) this.MAX_RESP_TIME_bit_cg[bt].sample(MAX_RESP_TIME.get_mirrored_value() >> bt);
            foreach(HEARTBEAT_PERIOD_bit_cg[bt]) this.HEARTBEAT_PERIOD_bit_cg[bt].sample(HEARTBEAT_PERIOD.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( NUM_OF_CMS_REGIONS.get_mirrored_value()  ,  MAX_RESP_TIME.get_mirrored_value()  ,  HEARTBEAT_PERIOD.get_mirrored_value()   );
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
            foreach(DESC_TYPE_bit_cg[bt]) this.DESC_TYPE_bit_cg[bt].sample(data[0 + bt]);
            foreach(VENDOR_SPECIFIC_STR_LENGTH_bit_cg[bt]) this.VENDOR_SPECIFIC_STR_LENGTH_bit_cg[bt].sample(data[8 + bt]);
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(data[16 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*DESC_TYPE*/  ,  data[15:8]/*VENDOR_SPECIFIC_STR_LENGTH*/  ,  data[31:16]/*DATA*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_0::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DESC_TYPE_bit_cg[bt]) this.DESC_TYPE_bit_cg[bt].sample(DESC_TYPE.get_mirrored_value() >> bt);
            foreach(VENDOR_SPECIFIC_STR_LENGTH_bit_cg[bt]) this.VENDOR_SPECIFIC_STR_LENGTH_bit_cg[bt].sample(VENDOR_SPECIFIC_STR_LENGTH.get_mirrored_value() >> bt);
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( DESC_TYPE.get_mirrored_value()  ,  VENDOR_SPECIFIC_STR_LENGTH.get_mirrored_value()  ,  DATA.get_mirrored_value()   );
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
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*DATA*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_1::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( DATA.get_mirrored_value()   );
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
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*DATA*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_2::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( DATA.get_mirrored_value()   );
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
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*DATA*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_3::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( DATA.get_mirrored_value()   );
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
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*DATA*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_4::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( DATA.get_mirrored_value()   );
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
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*DATA*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_5::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( DATA.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__DEVICE_ID_RESERVED SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_RESERVED::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*DATA*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_ID_RESERVED::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( DATA.get_mirrored_value()   );
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
            foreach(DEV_STATUS_bit_cg[bt]) this.DEV_STATUS_bit_cg[bt].sample(data[0 + bt]);
            foreach(PROT_ERROR_bit_cg[bt]) this.PROT_ERROR_bit_cg[bt].sample(data[8 + bt]);
            foreach(REC_REASON_CODE_bit_cg[bt]) this.REC_REASON_CODE_bit_cg[bt].sample(data[16 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*DEV_STATUS*/  ,  data[15:8]/*PROT_ERROR*/  ,  data[31:16]/*REC_REASON_CODE*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_STATUS_0::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DEV_STATUS_bit_cg[bt]) this.DEV_STATUS_bit_cg[bt].sample(DEV_STATUS.get_mirrored_value() >> bt);
            foreach(PROT_ERROR_bit_cg[bt]) this.PROT_ERROR_bit_cg[bt].sample(PROT_ERROR.get_mirrored_value() >> bt);
            foreach(REC_REASON_CODE_bit_cg[bt]) this.REC_REASON_CODE_bit_cg[bt].sample(REC_REASON_CODE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( DEV_STATUS.get_mirrored_value()  ,  PROT_ERROR.get_mirrored_value()  ,  REC_REASON_CODE.get_mirrored_value()   );
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
            foreach(HEARTBEAT_bit_cg[bt]) this.HEARTBEAT_bit_cg[bt].sample(data[0 + bt]);
            foreach(VENDOR_STATUS_LENGTH_bit_cg[bt]) this.VENDOR_STATUS_LENGTH_bit_cg[bt].sample(data[16 + bt]);
            foreach(VENDOR_STATUS_bit_cg[bt]) this.VENDOR_STATUS_bit_cg[bt].sample(data[25 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[15:0]/*HEARTBEAT*/  ,  data[24:16]/*VENDOR_STATUS_LENGTH*/  ,  data[31:25]/*VENDOR_STATUS*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_STATUS_1::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(HEARTBEAT_bit_cg[bt]) this.HEARTBEAT_bit_cg[bt].sample(HEARTBEAT.get_mirrored_value() >> bt);
            foreach(VENDOR_STATUS_LENGTH_bit_cg[bt]) this.VENDOR_STATUS_LENGTH_bit_cg[bt].sample(VENDOR_STATUS_LENGTH.get_mirrored_value() >> bt);
            foreach(VENDOR_STATUS_bit_cg[bt]) this.VENDOR_STATUS_bit_cg[bt].sample(VENDOR_STATUS.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( HEARTBEAT.get_mirrored_value()  ,  VENDOR_STATUS_LENGTH.get_mirrored_value()  ,  VENDOR_STATUS.get_mirrored_value()   );
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
            foreach(RESET_CTRL_bit_cg[bt]) this.RESET_CTRL_bit_cg[bt].sample(data[0 + bt]);
            foreach(FORCED_RECOVERY_bit_cg[bt]) this.FORCED_RECOVERY_bit_cg[bt].sample(data[8 + bt]);
            foreach(IF_CTRL_bit_cg[bt]) this.IF_CTRL_bit_cg[bt].sample(data[16 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*RESET_CTRL*/  ,  data[15:8]/*FORCED_RECOVERY*/  ,  data[23:16]/*IF_CTRL*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__DEVICE_RESET::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(RESET_CTRL_bit_cg[bt]) this.RESET_CTRL_bit_cg[bt].sample(RESET_CTRL.get_mirrored_value() >> bt);
            foreach(FORCED_RECOVERY_bit_cg[bt]) this.FORCED_RECOVERY_bit_cg[bt].sample(FORCED_RECOVERY.get_mirrored_value() >> bt);
            foreach(IF_CTRL_bit_cg[bt]) this.IF_CTRL_bit_cg[bt].sample(IF_CTRL.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( RESET_CTRL.get_mirrored_value()  ,  FORCED_RECOVERY.get_mirrored_value()  ,  IF_CTRL.get_mirrored_value()   );
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
            foreach(CMS_bit_cg[bt]) this.CMS_bit_cg[bt].sample(data[0 + bt]);
            foreach(REC_IMG_SEL_bit_cg[bt]) this.REC_IMG_SEL_bit_cg[bt].sample(data[8 + bt]);
            foreach(ACTIVATE_REC_IMG_bit_cg[bt]) this.ACTIVATE_REC_IMG_bit_cg[bt].sample(data[16 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*CMS*/  ,  data[15:8]/*REC_IMG_SEL*/  ,  data[23:16]/*ACTIVATE_REC_IMG*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__RECOVERY_CTRL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CMS_bit_cg[bt]) this.CMS_bit_cg[bt].sample(CMS.get_mirrored_value() >> bt);
            foreach(REC_IMG_SEL_bit_cg[bt]) this.REC_IMG_SEL_bit_cg[bt].sample(REC_IMG_SEL.get_mirrored_value() >> bt);
            foreach(ACTIVATE_REC_IMG_bit_cg[bt]) this.ACTIVATE_REC_IMG_bit_cg[bt].sample(ACTIVATE_REC_IMG.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( CMS.get_mirrored_value()  ,  REC_IMG_SEL.get_mirrored_value()  ,  ACTIVATE_REC_IMG.get_mirrored_value()   );
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
            foreach(DEV_REC_STATUS_bit_cg[bt]) this.DEV_REC_STATUS_bit_cg[bt].sample(data[0 + bt]);
            foreach(REC_IMG_INDEX_bit_cg[bt]) this.REC_IMG_INDEX_bit_cg[bt].sample(data[4 + bt]);
            foreach(VENDOR_SPECIFIC_STATUS_bit_cg[bt]) this.VENDOR_SPECIFIC_STATUS_bit_cg[bt].sample(data[8 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[3:0]/*DEV_REC_STATUS*/  ,  data[7:4]/*REC_IMG_INDEX*/  ,  data[15:8]/*VENDOR_SPECIFIC_STATUS*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__RECOVERY_STATUS::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DEV_REC_STATUS_bit_cg[bt]) this.DEV_REC_STATUS_bit_cg[bt].sample(DEV_REC_STATUS.get_mirrored_value() >> bt);
            foreach(REC_IMG_INDEX_bit_cg[bt]) this.REC_IMG_INDEX_bit_cg[bt].sample(REC_IMG_INDEX.get_mirrored_value() >> bt);
            foreach(VENDOR_SPECIFIC_STATUS_bit_cg[bt]) this.VENDOR_SPECIFIC_STATUS_bit_cg[bt].sample(VENDOR_SPECIFIC_STATUS.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( DEV_REC_STATUS.get_mirrored_value()  ,  REC_IMG_INDEX.get_mirrored_value()  ,  VENDOR_SPECIFIC_STATUS.get_mirrored_value()   );
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
            foreach(TEMP_CRITICAL_bit_cg[bt]) this.TEMP_CRITICAL_bit_cg[bt].sample(data[0 + bt]);
            foreach(SOFT_ERR_bit_cg[bt]) this.SOFT_ERR_bit_cg[bt].sample(data[1 + bt]);
            foreach(FATAL_ERR_bit_cg[bt]) this.FATAL_ERR_bit_cg[bt].sample(data[2 + bt]);
            foreach(RESERVED_7_3_bit_cg[bt]) this.RESERVED_7_3_bit_cg[bt].sample(data[3 + bt]);
            foreach(VENDOR_HW_STATUS_bit_cg[bt]) this.VENDOR_HW_STATUS_bit_cg[bt].sample(data[8 + bt]);
            foreach(CTEMP_bit_cg[bt]) this.CTEMP_bit_cg[bt].sample(data[16 + bt]);
            foreach(VENDOR_HW_STATUS_LEN_bit_cg[bt]) this.VENDOR_HW_STATUS_LEN_bit_cg[bt].sample(data[24 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*TEMP_CRITICAL*/  ,  data[1:1]/*SOFT_ERR*/  ,  data[2:2]/*FATAL_ERR*/  ,  data[7:3]/*RESERVED_7_3*/  ,  data[15:8]/*VENDOR_HW_STATUS*/  ,  data[23:16]/*CTEMP*/  ,  data[31:24]/*VENDOR_HW_STATUS_LEN*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__HW_STATUS::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(TEMP_CRITICAL_bit_cg[bt]) this.TEMP_CRITICAL_bit_cg[bt].sample(TEMP_CRITICAL.get_mirrored_value() >> bt);
            foreach(SOFT_ERR_bit_cg[bt]) this.SOFT_ERR_bit_cg[bt].sample(SOFT_ERR.get_mirrored_value() >> bt);
            foreach(FATAL_ERR_bit_cg[bt]) this.FATAL_ERR_bit_cg[bt].sample(FATAL_ERR.get_mirrored_value() >> bt);
            foreach(RESERVED_7_3_bit_cg[bt]) this.RESERVED_7_3_bit_cg[bt].sample(RESERVED_7_3.get_mirrored_value() >> bt);
            foreach(VENDOR_HW_STATUS_bit_cg[bt]) this.VENDOR_HW_STATUS_bit_cg[bt].sample(VENDOR_HW_STATUS.get_mirrored_value() >> bt);
            foreach(CTEMP_bit_cg[bt]) this.CTEMP_bit_cg[bt].sample(CTEMP.get_mirrored_value() >> bt);
            foreach(VENDOR_HW_STATUS_LEN_bit_cg[bt]) this.VENDOR_HW_STATUS_LEN_bit_cg[bt].sample(VENDOR_HW_STATUS_LEN.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( TEMP_CRITICAL.get_mirrored_value()  ,  SOFT_ERR.get_mirrored_value()  ,  FATAL_ERR.get_mirrored_value()  ,  RESERVED_7_3.get_mirrored_value()  ,  VENDOR_HW_STATUS.get_mirrored_value()  ,  CTEMP.get_mirrored_value()  ,  VENDOR_HW_STATUS_LEN.get_mirrored_value()   );
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
            foreach(CMS_bit_cg[bt]) this.CMS_bit_cg[bt].sample(data[0 + bt]);
            foreach(RESET_bit_cg[bt]) this.RESET_bit_cg[bt].sample(data[8 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*CMS*/  ,  data[15:8]/*RESET*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_CTRL_0::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(CMS_bit_cg[bt]) this.CMS_bit_cg[bt].sample(CMS.get_mirrored_value() >> bt);
            foreach(RESET_bit_cg[bt]) this.RESET_bit_cg[bt].sample(RESET.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( CMS.get_mirrored_value()  ,  RESET.get_mirrored_value()   );
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
            foreach(IMAGE_SIZE_bit_cg[bt]) this.IMAGE_SIZE_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*IMAGE_SIZE*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_CTRL_1::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(IMAGE_SIZE_bit_cg[bt]) this.IMAGE_SIZE_bit_cg[bt].sample(IMAGE_SIZE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( IMAGE_SIZE.get_mirrored_value()   );
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
            foreach(EMPTY_bit_cg[bt]) this.EMPTY_bit_cg[bt].sample(data[0 + bt]);
            foreach(FULL_bit_cg[bt]) this.FULL_bit_cg[bt].sample(data[1 + bt]);
            foreach(REGION_TYPE_bit_cg[bt]) this.REGION_TYPE_bit_cg[bt].sample(data[8 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*EMPTY*/  ,  data[1:1]/*FULL*/  ,  data[10:8]/*REGION_TYPE*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_0::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(EMPTY_bit_cg[bt]) this.EMPTY_bit_cg[bt].sample(EMPTY.get_mirrored_value() >> bt);
            foreach(FULL_bit_cg[bt]) this.FULL_bit_cg[bt].sample(FULL.get_mirrored_value() >> bt);
            foreach(REGION_TYPE_bit_cg[bt]) this.REGION_TYPE_bit_cg[bt].sample(REGION_TYPE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( EMPTY.get_mirrored_value()  ,  FULL.get_mirrored_value()  ,  REGION_TYPE.get_mirrored_value()   );
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
            foreach(WRITE_INDEX_bit_cg[bt]) this.WRITE_INDEX_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*WRITE_INDEX*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_1::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(WRITE_INDEX_bit_cg[bt]) this.WRITE_INDEX_bit_cg[bt].sample(WRITE_INDEX.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( WRITE_INDEX.get_mirrored_value()   );
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
            foreach(READ_INDEX_bit_cg[bt]) this.READ_INDEX_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*READ_INDEX*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_2::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(READ_INDEX_bit_cg[bt]) this.READ_INDEX_bit_cg[bt].sample(READ_INDEX.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( READ_INDEX.get_mirrored_value()   );
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
            foreach(FIFO_SIZE_bit_cg[bt]) this.FIFO_SIZE_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*FIFO_SIZE*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_3::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(FIFO_SIZE_bit_cg[bt]) this.FIFO_SIZE_bit_cg[bt].sample(FIFO_SIZE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( FIFO_SIZE.get_mirrored_value()   );
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
            foreach(MAX_TRANSFER_SIZE_bit_cg[bt]) this.MAX_TRANSFER_SIZE_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*MAX_TRANSFER_SIZE*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_STATUS_4::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(MAX_TRANSFER_SIZE_bit_cg[bt]) this.MAX_TRANSFER_SIZE_bit_cg[bt].sample(MAX_TRANSFER_SIZE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( MAX_TRANSFER_SIZE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SECFWRECOVERYIF__INDIRECT_FIFO_RESERVED SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_RESERVED::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*DATA*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_RESERVED::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( DATA.get_mirrored_value()   );
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
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(data[0 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[31:0]/*DATA*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SecFwRecoveryIf__INDIRECT_FIFO_DATA::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DATA_bit_cg[bt]) this.DATA_bit_cg[bt].sample(DATA.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( DATA.get_mirrored_value()   );
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

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_VIRTUAL_DEVICE_CHAR SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_VIRTUAL_DEVICE_CHAR::sample(uvm_reg_data_t  data,
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

    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_VIRTUAL_DEVICE_CHAR::sample_values();
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

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_VIRTUAL_DEVICE_PID_LO SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_VIRTUAL_DEVICE_PID_LO::sample(uvm_reg_data_t  data,
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

    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_VIRTUAL_DEVICE_PID_LO::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PID_LO_bit_cg[bt]) this.PID_LO_bit_cg[bt].sample(PID_LO.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PID_LO.get_mirrored_value()   );
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

    /*----------------------- I3CCSR__I3C_EC__STDBYCTRLMODE__STBY_CR_VIRT_DEVICE_ADDR SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_VIRT_DEVICE_ADDR::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(VIRT_STATIC_ADDR_bit_cg[bt]) this.VIRT_STATIC_ADDR_bit_cg[bt].sample(data[0 + bt]);
            foreach(VIRT_STATIC_ADDR_VALID_bit_cg[bt]) this.VIRT_STATIC_ADDR_VALID_bit_cg[bt].sample(data[15 + bt]);
            foreach(VIRT_DYNAMIC_ADDR_bit_cg[bt]) this.VIRT_DYNAMIC_ADDR_bit_cg[bt].sample(data[16 + bt]);
            foreach(VIRT_DYNAMIC_ADDR_VALID_bit_cg[bt]) this.VIRT_DYNAMIC_ADDR_VALID_bit_cg[bt].sample(data[31 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[6:0]/*VIRT_STATIC_ADDR*/  ,  data[15:15]/*VIRT_STATIC_ADDR_VALID*/  ,  data[22:16]/*VIRT_DYNAMIC_ADDR*/  ,  data[31:31]/*VIRT_DYNAMIC_ADDR_VALID*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__StdbyCtrlMode__STBY_CR_VIRT_DEVICE_ADDR::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(VIRT_STATIC_ADDR_bit_cg[bt]) this.VIRT_STATIC_ADDR_bit_cg[bt].sample(VIRT_STATIC_ADDR.get_mirrored_value() >> bt);
            foreach(VIRT_STATIC_ADDR_VALID_bit_cg[bt]) this.VIRT_STATIC_ADDR_VALID_bit_cg[bt].sample(VIRT_STATIC_ADDR_VALID.get_mirrored_value() >> bt);
            foreach(VIRT_DYNAMIC_ADDR_bit_cg[bt]) this.VIRT_DYNAMIC_ADDR_bit_cg[bt].sample(VIRT_DYNAMIC_ADDR.get_mirrored_value() >> bt);
            foreach(VIRT_DYNAMIC_ADDR_VALID_bit_cg[bt]) this.VIRT_DYNAMIC_ADDR_VALID_bit_cg[bt].sample(VIRT_DYNAMIC_ADDR_VALID.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( VIRT_STATIC_ADDR.get_mirrored_value()  ,  VIRT_STATIC_ADDR_VALID.get_mirrored_value()  ,  VIRT_DYNAMIC_ADDR.get_mirrored_value()  ,  VIRT_DYNAMIC_ADDR_VALID.get_mirrored_value()   );
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
            foreach(HJ_EN_bit_cg[bt]) this.HJ_EN_bit_cg[bt].sample(data[10 + bt]);
            foreach(CRR_EN_bit_cg[bt]) this.CRR_EN_bit_cg[bt].sample(data[11 + bt]);
            foreach(IBI_EN_bit_cg[bt]) this.IBI_EN_bit_cg[bt].sample(data[12 + bt]);
            foreach(IBI_RETRY_NUM_bit_cg[bt]) this.IBI_RETRY_NUM_bit_cg[bt].sample(data[13 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[10:10]/*HJ_EN*/  ,  data[11:11]/*CRR_EN*/  ,  data[12:12]/*IBI_EN*/  ,  data[15:13]/*IBI_RETRY_NUM*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__CONTROL::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(HJ_EN_bit_cg[bt]) this.HJ_EN_bit_cg[bt].sample(HJ_EN.get_mirrored_value() >> bt);
            foreach(CRR_EN_bit_cg[bt]) this.CRR_EN_bit_cg[bt].sample(CRR_EN.get_mirrored_value() >> bt);
            foreach(IBI_EN_bit_cg[bt]) this.IBI_EN_bit_cg[bt].sample(IBI_EN.get_mirrored_value() >> bt);
            foreach(IBI_RETRY_NUM_bit_cg[bt]) this.IBI_RETRY_NUM_bit_cg[bt].sample(IBI_RETRY_NUM.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( HJ_EN.get_mirrored_value()  ,  CRR_EN.get_mirrored_value()  ,  IBI_EN.get_mirrored_value()  ,  IBI_RETRY_NUM.get_mirrored_value()   );
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
            foreach(PROTOCOL_ERROR_bit_cg[bt]) this.PROTOCOL_ERROR_bit_cg[bt].sample(data[13 + bt]);
            foreach(LAST_IBI_STATUS_bit_cg[bt]) this.LAST_IBI_STATUS_bit_cg[bt].sample(data[14 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[13:13]/*PROTOCOL_ERROR*/  ,  data[15:14]/*LAST_IBI_STATUS*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__STATUS::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(PROTOCOL_ERROR_bit_cg[bt]) this.PROTOCOL_ERROR_bit_cg[bt].sample(PROTOCOL_ERROR.get_mirrored_value() >> bt);
            foreach(LAST_IBI_STATUS_bit_cg[bt]) this.LAST_IBI_STATUS_bit_cg[bt].sample(LAST_IBI_STATUS.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( PROTOCOL_ERROR.get_mirrored_value()  ,  LAST_IBI_STATUS.get_mirrored_value()   );
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
            foreach(IBI_DONE_bit_cg[bt]) this.IBI_DONE_bit_cg[bt].sample(data[13 + bt]);
            foreach(PENDING_INTERRUPT_bit_cg[bt]) this.PENDING_INTERRUPT_bit_cg[bt].sample(data[15 + bt]);
            foreach(TRANSFER_ABORT_STAT_bit_cg[bt]) this.TRANSFER_ABORT_STAT_bit_cg[bt].sample(data[25 + bt]);
            foreach(TX_DESC_COMPLETE_bit_cg[bt]) this.TX_DESC_COMPLETE_bit_cg[bt].sample(data[26 + bt]);
            foreach(TRANSFER_ERR_STAT_bit_cg[bt]) this.TRANSFER_ERR_STAT_bit_cg[bt].sample(data[31 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*RX_DESC_STAT*/  ,  data[1:1]/*TX_DESC_STAT*/  ,  data[2:2]/*RX_DESC_TIMEOUT*/  ,  data[3:3]/*TX_DESC_TIMEOUT*/  ,  data[8:8]/*TX_DATA_THLD_STAT*/  ,  data[9:9]/*RX_DATA_THLD_STAT*/  ,  data[10:10]/*TX_DESC_THLD_STAT*/  ,  data[11:11]/*RX_DESC_THLD_STAT*/  ,  data[12:12]/*IBI_THLD_STAT*/  ,  data[13:13]/*IBI_DONE*/  ,  data[18:15]/*PENDING_INTERRUPT*/  ,  data[25:25]/*TRANSFER_ABORT_STAT*/  ,  data[26:26]/*TX_DESC_COMPLETE*/  ,  data[31:31]/*TRANSFER_ERR_STAT*/   );
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
            foreach(IBI_DONE_bit_cg[bt]) this.IBI_DONE_bit_cg[bt].sample(IBI_DONE.get_mirrored_value() >> bt);
            foreach(PENDING_INTERRUPT_bit_cg[bt]) this.PENDING_INTERRUPT_bit_cg[bt].sample(PENDING_INTERRUPT.get_mirrored_value() >> bt);
            foreach(TRANSFER_ABORT_STAT_bit_cg[bt]) this.TRANSFER_ABORT_STAT_bit_cg[bt].sample(TRANSFER_ABORT_STAT.get_mirrored_value() >> bt);
            foreach(TX_DESC_COMPLETE_bit_cg[bt]) this.TX_DESC_COMPLETE_bit_cg[bt].sample(TX_DESC_COMPLETE.get_mirrored_value() >> bt);
            foreach(TRANSFER_ERR_STAT_bit_cg[bt]) this.TRANSFER_ERR_STAT_bit_cg[bt].sample(TRANSFER_ERR_STAT.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( RX_DESC_STAT.get_mirrored_value()  ,  TX_DESC_STAT.get_mirrored_value()  ,  RX_DESC_TIMEOUT.get_mirrored_value()  ,  TX_DESC_TIMEOUT.get_mirrored_value()  ,  TX_DATA_THLD_STAT.get_mirrored_value()  ,  RX_DATA_THLD_STAT.get_mirrored_value()  ,  TX_DESC_THLD_STAT.get_mirrored_value()  ,  RX_DESC_THLD_STAT.get_mirrored_value()  ,  IBI_THLD_STAT.get_mirrored_value()  ,  IBI_DONE.get_mirrored_value()  ,  PENDING_INTERRUPT.get_mirrored_value()  ,  TRANSFER_ABORT_STAT.get_mirrored_value()  ,  TX_DESC_COMPLETE.get_mirrored_value()  ,  TRANSFER_ERR_STAT.get_mirrored_value()   );
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
            foreach(RX_DESC_STAT_EN_bit_cg[bt]) this.RX_DESC_STAT_EN_bit_cg[bt].sample(data[0 + bt]);
            foreach(TX_DESC_STAT_EN_bit_cg[bt]) this.TX_DESC_STAT_EN_bit_cg[bt].sample(data[1 + bt]);
            foreach(RX_DESC_TIMEOUT_EN_bit_cg[bt]) this.RX_DESC_TIMEOUT_EN_bit_cg[bt].sample(data[2 + bt]);
            foreach(TX_DESC_TIMEOUT_EN_bit_cg[bt]) this.TX_DESC_TIMEOUT_EN_bit_cg[bt].sample(data[3 + bt]);
            foreach(TX_DATA_THLD_STAT_EN_bit_cg[bt]) this.TX_DATA_THLD_STAT_EN_bit_cg[bt].sample(data[8 + bt]);
            foreach(RX_DATA_THLD_STAT_EN_bit_cg[bt]) this.RX_DATA_THLD_STAT_EN_bit_cg[bt].sample(data[9 + bt]);
            foreach(TX_DESC_THLD_STAT_EN_bit_cg[bt]) this.TX_DESC_THLD_STAT_EN_bit_cg[bt].sample(data[10 + bt]);
            foreach(RX_DESC_THLD_STAT_EN_bit_cg[bt]) this.RX_DESC_THLD_STAT_EN_bit_cg[bt].sample(data[11 + bt]);
            foreach(IBI_THLD_STAT_EN_bit_cg[bt]) this.IBI_THLD_STAT_EN_bit_cg[bt].sample(data[12 + bt]);
            foreach(IBI_DONE_EN_bit_cg[bt]) this.IBI_DONE_EN_bit_cg[bt].sample(data[13 + bt]);
            foreach(TRANSFER_ABORT_STAT_EN_bit_cg[bt]) this.TRANSFER_ABORT_STAT_EN_bit_cg[bt].sample(data[25 + bt]);
            foreach(TX_DESC_COMPLETE_EN_bit_cg[bt]) this.TX_DESC_COMPLETE_EN_bit_cg[bt].sample(data[26 + bt]);
            foreach(TRANSFER_ERR_STAT_EN_bit_cg[bt]) this.TRANSFER_ERR_STAT_EN_bit_cg[bt].sample(data[31 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*RX_DESC_STAT_EN*/  ,  data[1:1]/*TX_DESC_STAT_EN*/  ,  data[2:2]/*RX_DESC_TIMEOUT_EN*/  ,  data[3:3]/*TX_DESC_TIMEOUT_EN*/  ,  data[8:8]/*TX_DATA_THLD_STAT_EN*/  ,  data[9:9]/*RX_DATA_THLD_STAT_EN*/  ,  data[10:10]/*TX_DESC_THLD_STAT_EN*/  ,  data[11:11]/*RX_DESC_THLD_STAT_EN*/  ,  data[12:12]/*IBI_THLD_STAT_EN*/  ,  data[13:13]/*IBI_DONE_EN*/  ,  data[25:25]/*TRANSFER_ABORT_STAT_EN*/  ,  data[26:26]/*TX_DESC_COMPLETE_EN*/  ,  data[31:31]/*TRANSFER_ERR_STAT_EN*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__INTERRUPT_ENABLE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(RX_DESC_STAT_EN_bit_cg[bt]) this.RX_DESC_STAT_EN_bit_cg[bt].sample(RX_DESC_STAT_EN.get_mirrored_value() >> bt);
            foreach(TX_DESC_STAT_EN_bit_cg[bt]) this.TX_DESC_STAT_EN_bit_cg[bt].sample(TX_DESC_STAT_EN.get_mirrored_value() >> bt);
            foreach(RX_DESC_TIMEOUT_EN_bit_cg[bt]) this.RX_DESC_TIMEOUT_EN_bit_cg[bt].sample(RX_DESC_TIMEOUT_EN.get_mirrored_value() >> bt);
            foreach(TX_DESC_TIMEOUT_EN_bit_cg[bt]) this.TX_DESC_TIMEOUT_EN_bit_cg[bt].sample(TX_DESC_TIMEOUT_EN.get_mirrored_value() >> bt);
            foreach(TX_DATA_THLD_STAT_EN_bit_cg[bt]) this.TX_DATA_THLD_STAT_EN_bit_cg[bt].sample(TX_DATA_THLD_STAT_EN.get_mirrored_value() >> bt);
            foreach(RX_DATA_THLD_STAT_EN_bit_cg[bt]) this.RX_DATA_THLD_STAT_EN_bit_cg[bt].sample(RX_DATA_THLD_STAT_EN.get_mirrored_value() >> bt);
            foreach(TX_DESC_THLD_STAT_EN_bit_cg[bt]) this.TX_DESC_THLD_STAT_EN_bit_cg[bt].sample(TX_DESC_THLD_STAT_EN.get_mirrored_value() >> bt);
            foreach(RX_DESC_THLD_STAT_EN_bit_cg[bt]) this.RX_DESC_THLD_STAT_EN_bit_cg[bt].sample(RX_DESC_THLD_STAT_EN.get_mirrored_value() >> bt);
            foreach(IBI_THLD_STAT_EN_bit_cg[bt]) this.IBI_THLD_STAT_EN_bit_cg[bt].sample(IBI_THLD_STAT_EN.get_mirrored_value() >> bt);
            foreach(IBI_DONE_EN_bit_cg[bt]) this.IBI_DONE_EN_bit_cg[bt].sample(IBI_DONE_EN.get_mirrored_value() >> bt);
            foreach(TRANSFER_ABORT_STAT_EN_bit_cg[bt]) this.TRANSFER_ABORT_STAT_EN_bit_cg[bt].sample(TRANSFER_ABORT_STAT_EN.get_mirrored_value() >> bt);
            foreach(TX_DESC_COMPLETE_EN_bit_cg[bt]) this.TX_DESC_COMPLETE_EN_bit_cg[bt].sample(TX_DESC_COMPLETE_EN.get_mirrored_value() >> bt);
            foreach(TRANSFER_ERR_STAT_EN_bit_cg[bt]) this.TRANSFER_ERR_STAT_EN_bit_cg[bt].sample(TRANSFER_ERR_STAT_EN.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( RX_DESC_STAT_EN.get_mirrored_value()  ,  TX_DESC_STAT_EN.get_mirrored_value()  ,  RX_DESC_TIMEOUT_EN.get_mirrored_value()  ,  TX_DESC_TIMEOUT_EN.get_mirrored_value()  ,  TX_DATA_THLD_STAT_EN.get_mirrored_value()  ,  RX_DATA_THLD_STAT_EN.get_mirrored_value()  ,  TX_DESC_THLD_STAT_EN.get_mirrored_value()  ,  RX_DESC_THLD_STAT_EN.get_mirrored_value()  ,  IBI_THLD_STAT_EN.get_mirrored_value()  ,  IBI_DONE_EN.get_mirrored_value()  ,  TRANSFER_ABORT_STAT_EN.get_mirrored_value()  ,  TX_DESC_COMPLETE_EN.get_mirrored_value()  ,  TRANSFER_ERR_STAT_EN.get_mirrored_value()   );
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
            foreach(RX_DESC_STAT_FORCE_bit_cg[bt]) this.RX_DESC_STAT_FORCE_bit_cg[bt].sample(data[0 + bt]);
            foreach(TX_DESC_STAT_FORCE_bit_cg[bt]) this.TX_DESC_STAT_FORCE_bit_cg[bt].sample(data[1 + bt]);
            foreach(RX_DESC_TIMEOUT_FORCE_bit_cg[bt]) this.RX_DESC_TIMEOUT_FORCE_bit_cg[bt].sample(data[2 + bt]);
            foreach(TX_DESC_TIMEOUT_FORCE_bit_cg[bt]) this.TX_DESC_TIMEOUT_FORCE_bit_cg[bt].sample(data[3 + bt]);
            foreach(TX_DATA_THLD_FORCE_bit_cg[bt]) this.TX_DATA_THLD_FORCE_bit_cg[bt].sample(data[8 + bt]);
            foreach(RX_DATA_THLD_FORCE_bit_cg[bt]) this.RX_DATA_THLD_FORCE_bit_cg[bt].sample(data[9 + bt]);
            foreach(TX_DESC_THLD_FORCE_bit_cg[bt]) this.TX_DESC_THLD_FORCE_bit_cg[bt].sample(data[10 + bt]);
            foreach(RX_DESC_THLD_FORCE_bit_cg[bt]) this.RX_DESC_THLD_FORCE_bit_cg[bt].sample(data[11 + bt]);
            foreach(IBI_THLD_FORCE_bit_cg[bt]) this.IBI_THLD_FORCE_bit_cg[bt].sample(data[12 + bt]);
            foreach(IBI_DONE_FORCE_bit_cg[bt]) this.IBI_DONE_FORCE_bit_cg[bt].sample(data[13 + bt]);
            foreach(TRANSFER_ABORT_STAT_FORCE_bit_cg[bt]) this.TRANSFER_ABORT_STAT_FORCE_bit_cg[bt].sample(data[25 + bt]);
            foreach(TX_DESC_COMPLETE_FORCE_bit_cg[bt]) this.TX_DESC_COMPLETE_FORCE_bit_cg[bt].sample(data[26 + bt]);
            foreach(TRANSFER_ERR_STAT_FORCE_bit_cg[bt]) this.TRANSFER_ERR_STAT_FORCE_bit_cg[bt].sample(data[31 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*RX_DESC_STAT_FORCE*/  ,  data[1:1]/*TX_DESC_STAT_FORCE*/  ,  data[2:2]/*RX_DESC_TIMEOUT_FORCE*/  ,  data[3:3]/*TX_DESC_TIMEOUT_FORCE*/  ,  data[8:8]/*TX_DATA_THLD_FORCE*/  ,  data[9:9]/*RX_DATA_THLD_FORCE*/  ,  data[10:10]/*TX_DESC_THLD_FORCE*/  ,  data[11:11]/*RX_DESC_THLD_FORCE*/  ,  data[12:12]/*IBI_THLD_FORCE*/  ,  data[13:13]/*IBI_DONE_FORCE*/  ,  data[25:25]/*TRANSFER_ABORT_STAT_FORCE*/  ,  data[26:26]/*TX_DESC_COMPLETE_FORCE*/  ,  data[31:31]/*TRANSFER_ERR_STAT_FORCE*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__TTI__INTERRUPT_FORCE::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(RX_DESC_STAT_FORCE_bit_cg[bt]) this.RX_DESC_STAT_FORCE_bit_cg[bt].sample(RX_DESC_STAT_FORCE.get_mirrored_value() >> bt);
            foreach(TX_DESC_STAT_FORCE_bit_cg[bt]) this.TX_DESC_STAT_FORCE_bit_cg[bt].sample(TX_DESC_STAT_FORCE.get_mirrored_value() >> bt);
            foreach(RX_DESC_TIMEOUT_FORCE_bit_cg[bt]) this.RX_DESC_TIMEOUT_FORCE_bit_cg[bt].sample(RX_DESC_TIMEOUT_FORCE.get_mirrored_value() >> bt);
            foreach(TX_DESC_TIMEOUT_FORCE_bit_cg[bt]) this.TX_DESC_TIMEOUT_FORCE_bit_cg[bt].sample(TX_DESC_TIMEOUT_FORCE.get_mirrored_value() >> bt);
            foreach(TX_DATA_THLD_FORCE_bit_cg[bt]) this.TX_DATA_THLD_FORCE_bit_cg[bt].sample(TX_DATA_THLD_FORCE.get_mirrored_value() >> bt);
            foreach(RX_DATA_THLD_FORCE_bit_cg[bt]) this.RX_DATA_THLD_FORCE_bit_cg[bt].sample(RX_DATA_THLD_FORCE.get_mirrored_value() >> bt);
            foreach(TX_DESC_THLD_FORCE_bit_cg[bt]) this.TX_DESC_THLD_FORCE_bit_cg[bt].sample(TX_DESC_THLD_FORCE.get_mirrored_value() >> bt);
            foreach(RX_DESC_THLD_FORCE_bit_cg[bt]) this.RX_DESC_THLD_FORCE_bit_cg[bt].sample(RX_DESC_THLD_FORCE.get_mirrored_value() >> bt);
            foreach(IBI_THLD_FORCE_bit_cg[bt]) this.IBI_THLD_FORCE_bit_cg[bt].sample(IBI_THLD_FORCE.get_mirrored_value() >> bt);
            foreach(IBI_DONE_FORCE_bit_cg[bt]) this.IBI_DONE_FORCE_bit_cg[bt].sample(IBI_DONE_FORCE.get_mirrored_value() >> bt);
            foreach(TRANSFER_ABORT_STAT_FORCE_bit_cg[bt]) this.TRANSFER_ABORT_STAT_FORCE_bit_cg[bt].sample(TRANSFER_ABORT_STAT_FORCE.get_mirrored_value() >> bt);
            foreach(TX_DESC_COMPLETE_FORCE_bit_cg[bt]) this.TX_DESC_COMPLETE_FORCE_bit_cg[bt].sample(TX_DESC_COMPLETE_FORCE.get_mirrored_value() >> bt);
            foreach(TRANSFER_ERR_STAT_FORCE_bit_cg[bt]) this.TRANSFER_ERR_STAT_FORCE_bit_cg[bt].sample(TRANSFER_ERR_STAT_FORCE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( RX_DESC_STAT_FORCE.get_mirrored_value()  ,  TX_DESC_STAT_FORCE.get_mirrored_value()  ,  RX_DESC_TIMEOUT_FORCE.get_mirrored_value()  ,  TX_DESC_TIMEOUT_FORCE.get_mirrored_value()  ,  TX_DATA_THLD_FORCE.get_mirrored_value()  ,  RX_DATA_THLD_FORCE.get_mirrored_value()  ,  TX_DESC_THLD_FORCE.get_mirrored_value()  ,  RX_DESC_THLD_FORCE.get_mirrored_value()  ,  IBI_THLD_FORCE.get_mirrored_value()  ,  IBI_DONE_FORCE.get_mirrored_value()  ,  TRANSFER_ABORT_STAT_FORCE.get_mirrored_value()  ,  TX_DESC_COMPLETE_FORCE.get_mirrored_value()  ,  TRANSFER_ERR_STAT_FORCE.get_mirrored_value()   );
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

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__REC_INTF_CFG SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__REC_INTF_CFG::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(REC_INTF_BYPASS_bit_cg[bt]) this.REC_INTF_BYPASS_bit_cg[bt].sample(data[0 + bt]);
            foreach(REC_PAYLOAD_DONE_bit_cg[bt]) this.REC_PAYLOAD_DONE_bit_cg[bt].sample(data[1 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[0:0]/*REC_INTF_BYPASS*/  ,  data[1:1]/*REC_PAYLOAD_DONE*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__REC_INTF_CFG::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(REC_INTF_BYPASS_bit_cg[bt]) this.REC_INTF_BYPASS_bit_cg[bt].sample(REC_INTF_BYPASS.get_mirrored_value() >> bt);
            foreach(REC_PAYLOAD_DONE_bit_cg[bt]) this.REC_PAYLOAD_DONE_bit_cg[bt].sample(REC_PAYLOAD_DONE.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( REC_INTF_BYPASS.get_mirrored_value()  ,  REC_PAYLOAD_DONE.get_mirrored_value()   );
        end
    endfunction

    /*----------------------- I3CCSR__I3C_EC__SOCMGMTIF__REC_INTF_REG_W1C_ACCESS SAMPLE FUNCTIONS -----------------------*/
    function void I3CCSR__I3C_EC__SoCMgmtIf__REC_INTF_REG_W1C_ACCESS::sample(uvm_reg_data_t  data,
                                                   uvm_reg_data_t  byte_en,
                                                   bit             is_read,
                                                   uvm_reg_map     map);
        m_current = get();
        m_data    = data;
        m_is_read = is_read;
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DEVICE_RESET_CTRL_bit_cg[bt]) this.DEVICE_RESET_CTRL_bit_cg[bt].sample(data[0 + bt]);
            foreach(RECOVERY_CTRL_ACTIVATE_REC_IMG_bit_cg[bt]) this.RECOVERY_CTRL_ACTIVATE_REC_IMG_bit_cg[bt].sample(data[8 + bt]);
            foreach(INDIRECT_FIFO_CTRL_RESET_bit_cg[bt]) this.INDIRECT_FIFO_CTRL_RESET_bit_cg[bt].sample(data[16 + bt]);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( data[7:0]/*DEVICE_RESET_CTRL*/  ,  data[15:8]/*RECOVERY_CTRL_ACTIVATE_REC_IMG*/  ,  data[23:16]/*INDIRECT_FIFO_CTRL_RESET*/   );
        end
    endfunction

    function void I3CCSR__I3C_EC__SoCMgmtIf__REC_INTF_REG_W1C_ACCESS::sample_values();
        if (get_coverage(UVM_CVR_REG_BITS)) begin
            foreach(DEVICE_RESET_CTRL_bit_cg[bt]) this.DEVICE_RESET_CTRL_bit_cg[bt].sample(DEVICE_RESET_CTRL.get_mirrored_value() >> bt);
            foreach(RECOVERY_CTRL_ACTIVATE_REC_IMG_bit_cg[bt]) this.RECOVERY_CTRL_ACTIVATE_REC_IMG_bit_cg[bt].sample(RECOVERY_CTRL_ACTIVATE_REC_IMG.get_mirrored_value() >> bt);
            foreach(INDIRECT_FIFO_CTRL_RESET_bit_cg[bt]) this.INDIRECT_FIFO_CTRL_RESET_bit_cg[bt].sample(INDIRECT_FIFO_CTRL_RESET.get_mirrored_value() >> bt);
        end
        if (get_coverage(UVM_CVR_FIELD_VALS)) begin
            this.fld_cg.sample( DEVICE_RESET_CTRL.get_mirrored_value()  ,  RECOVERY_CTRL_ACTIVATE_REC_IMG.get_mirrored_value()  ,  INDIRECT_FIFO_CTRL_RESET.get_mirrored_value()   );
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