# SPDX-License-Identifier: Apache-2.0
from enum import Enum
import logging
import math
from engineering_notation import EngNumber as EN


class IXCModes(Enum):
    LEGACY_400k = 1
    LEGACY_1M = 2
    I3C_SDR_12M5 = 3


freq_dict = {
    IXCModes.LEGACY_400k: 400e3,
    IXCModes.LEGACY_1M: 1e6,
    IXCModes.I3C_SDR_12M5: 12.5e6,
}

# Table 85 Timing with I2C Legacy Devices
spec_legacy_400k = {
    "f_scl_max": 400e3,
    "t_su_sta_min": 600e-9,
    "t_hd_sta_min": 600e-9,
    "t_low_min": 1300e-9,
    "t_dig_l_min": "t_low+t_r_cl",
    "t_high_min": 600e-9,
    "t_dig_h_min": "t_high-t_r_cl",
    "t_su_dat_min": 100e-9,
    "t_hd_dat_min": None,
    "t_r_cl_min": 20e-9,
    "t_f_cl_min": "20*(Vdd/5.5V)",
    "t_r_da_min": 20e-9,
    "t_r_da_od_min": 20e-9,
    "t_f_da_min": "20*(Vdd/5.5V)",
    "t_su_sto_min": 600e-9,
    "t_buf_min": 1.3e-6,
    "t_spike_min": 0,
}

# TODO: other specs
spec_legacy_1M = []
spec_sdr_12M5 = []

spec_dict = {
    IXCModes.LEGACY_400k: spec_legacy_400k,
    IXCModes.LEGACY_1M: spec_legacy_1M,
    IXCModes.I3C_SDR_12M5: spec_sdr_12M5,
}


def get_firmware_settings(spec, sys_clk=100e6):
    sys_period = 1 / sys_clk
    logging.info(f"sys_period \t= {EN(sys_period)}")

    THIGH_MIN = math.ceil(max(spec["t_high_min"] / sys_period, 4))
    TLOW_MIN = math.ceil(spec["t_low_min"] / sys_period)
    THD_STA_MIN = math.ceil(spec["t_hd_sta_min"] / sys_period)
    TSU_STA_MIN = math.ceil(spec["t_su_sta_min"] / sys_period)
    # THD_DAT_MIN = math.ceil(spec["t_hd_dat_min"]/sys_period)
    TSU_DAT_MIN = math.ceil(spec["t_su_dat_min"] / sys_period)
    T_BUF_MIN = math.ceil(spec["t_buf_min"] / sys_period)
    T_STO_MIN = math.ceil(spec["t_su_sto_min"] / sys_period)

    settings = {
        "THIGH_MIN": THIGH_MIN,
        "TLOW_MIN": TLOW_MIN,
        "THD_STA_MIN": THD_STA_MIN,
        "TSU_STA_MIN": TSU_STA_MIN,
        "TSU_DAT_MIN": TSU_DAT_MIN,
        "T_BUF_MIN": T_BUF_MIN,
        "T_STO_MIN": T_STO_MIN,
    }

    # Rise/fall time
    # All rf in spec were the same, so simplifying
    T_R = T_F = math.ceil(spec["t_r_cl_min"] / sys_period)
    logging.info(f"T_R = {T_R}")
    logging.info(f"T_F = {T_F}")

    t_scl_min = 1 / spec["f_scl_max"]
    logging.info(f"t_scl_min = {t_scl_min}")

    MIN_PERIOD = math.ceil(t_scl_min / sys_period)
    logging.info(f"MIN_PERIOD = {MIN_PERIOD}")

    # Assuming THIGH=TLOW
    # 2*THIGH >= PERIOD - T_F - T_R
    T_HIGH = math.ceil(
        max((MIN_PERIOD - T_F - T_R) / 2, spec["t_high_min"] / sys_period)
    )
    T_LOW = T_HIGH
    logging.info(f"T_HIGH = {T_HIGH}")
    logging.info(f"T_LOW = {T_LOW}")

    settings["T_R"] = T_R
    settings["T_F"] = T_F
    settings["MIN_PERIOD"] = MIN_PERIOD
    settings["T_HIGH"] = T_HIGH
    settings["T_LOW"] = T_LOW
    logging.info(settings)
    # TODO: From discrete settings calculate physical values on bus to validate them (min,max)
