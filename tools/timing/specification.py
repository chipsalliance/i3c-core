# SPDX-License-Identifier: Apache-2.0
from enum import Enum
from engineering_notation import EngNumber as EN


class IXCModes(Enum):
    LEGACY_400k = 1
    LEGACY_1M = 2
    I3C_SDR_12M5_OD = 3
    I3C_SDR_12M5_PP = 4


MODE_FREQ_DICT = {
    IXCModes.LEGACY_400k: 400e3,
    IXCModes.LEGACY_1M: 1e6,
    IXCModes.I3C_SDR_12M5_OD: 12.5e6,
    IXCModes.I3C_SDR_12M5_PP: 12.5e6,
}

# Table 85 Timing with I2C Legacy Devices
SPECIFICATIONS = {
    IXCModes.LEGACY_400k: {
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
    },
    IXCModes.LEGACY_1M: {
        "f_scl_max": 1e6,
        "t_su_sta_min": 260e-9,
        "t_hd_sta_min": 260e-9,
        "t_low_min": 500e-9,
        "t_dig_l_min": "t_low+t_r_cl",
        "t_high_min": 260e-9,
        "t_dig_h_min": "t_high-t_r_cl",
        "t_su_dat_min": 50e-9,
        "t_hd_dat_min": None,
        "t_r_cl_min": None,
        "t_f_cl_min": "20*(Vdd/5.5V)",
        "t_r_da_min": None,
        "t_r_da_od_min": None,
        "t_f_da_min": "20*(Vdd/5.5V)",
        "t_su_sto_min": 260e-9,
        "t_buf_min": 0.5e-6,
        "t_spike_min": 0,
    }
}

class IXCSpecification:
    def __init__(self, mode):
        self.mode = mode
        self.mode_freq = self.get_mode_freq(mode)
        self.spec = self.get_spec(mode)

    def get_mode_freq(self, mode):
        return MODE_FREQ_DICT[mode]

    def get_spec(self, mode):
        return SPECIFICATIONS[mode]
