# SPDX-License-Identifier: Apache-2.0

import logging
from engineering_notation import EngNumber as EN
from specification import *
from utils import *


def get_firmware_settings(spec, sys_clk=100e6):
    sys_period = f2T(sys_clk)
    logging.debug(f"sys_period \t= {EN(sys_period)}")

    THIGH_MIN = max(norm_ceil(spec.spec["t_high_min"], sys_period), 4)
    TLOW_MIN = norm_ceil(spec.spec["t_low_min"], sys_period)
    THD_STA_MIN = norm_ceil(spec.spec["t_hd_sta_min"], sys_period)
    TSU_STA_MIN = norm_ceil(spec.spec["t_su_sta_min"], sys_period)
    TSU_DAT_MIN = norm_ceil(spec.spec["t_su_dat_min"], sys_period)
    T_BUF_MIN = norm_ceil(spec.spec["t_buf_min"], sys_period)
    T_STO_MIN = norm_ceil(spec.spec["t_su_sto_min"], sys_period)

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
    if spec.mode == IXCModes.LEGACY_1M:
        T_R = T_F = norm_ceil(20e-9, sys_period)
        logging.debug(f"Arbitrarily set T_R and T_F to 20ns")
        logging.debug(f"Specification does not constrain it.")
        logging.debug(f"C.f. Table 85 Legacy Mody 1MHz/Fm+, entry: t_r_cl")
    else:
        T_R = T_F = norm_ceil(spec.spec["t_r_cl_min"], sys_period)

    logging.debug(
        f"Rise/fall times are not fw controlled. They depend on electrical design."
    )
    logging.debug(f"T_R = {EN(T_R)}")
    logging.debug(f"T_F = {EN(T_F)}")
    settings["T_R"] = T_R
    settings["T_F"] = T_F

    t_scl_min = f2T(spec.spec["f_scl_max"])
    logging.debug(f"t_scl_min = {EN(t_scl_min)}")

    MIN_PERIOD = math.ceil(t_scl_min / sys_period)
    logging.debug(f"MIN_PERIOD = {MIN_PERIOD}")

    # Assuming THIGH=TLOW
    # 2*THIGH >= PERIOD - T_F - T_R
    T_HIGH = math.ceil(
        max((MIN_PERIOD - T_F - T_R) / 2, spec.spec["t_high_min"] / sys_period)
    )
    T_LOW = T_HIGH
    logging.debug(f"T_HIGH = {T_HIGH}")
    logging.debug(f"T_LOW = {T_LOW}")

    settings["MIN_PERIOD"] = MIN_PERIOD
    settings["T_HIGH"] = T_HIGH
    settings["T_LOW"] = T_LOW
    logging.info(f"Settings={settings}")


def generic_timings(mode, sys_freq):
    freq = MODE_FREQ_DICT[mode]
    t_high = f2halfT(freq)
    t_low = f2halfT(freq)
    oversampling = sys_freq / freq
    counter_high_low = 0.5 * oversampling

    logging.info(f"freq             = {EN(freq)}")
    logging.info(f"t_high           = {EN(t_high)}")
    logging.info(f"t_low            = {EN(t_low)}")
    logging.info(f"oversampling     = {EN(oversampling)}")
    logging.info(f"counter_high_low = {EN(counter_high_low)}")


# TODO: Finish i3c settings
def get_i3c_firmware_settings():
    pass


# TODO: From discrete settings calculate physical values on bus to validate them (min,max)
def firmware_to_timings():
    pass


# Fig 144 I3C Start Timing
# Timing t_ds_od on figure 144 is not defined in text!
def i3c_start_timings():
    start_timings = {
        "tSDA_LOW": 0,
        "tSCL_LOW": 0,  # t_fda_od+t_cas
        "tSDA_RELEASE": 0,  # t_cf + t_ds_od # t_ds_od is NOT DEFINED!
        "tSCL_RELEASE": 0,  # t_low_od + t_cr + t_cf
    }

    spec = {
        "f_scl_max": 12.5e6,
        "t_f_da_od_max": 12e-9,
        "t_cf": 12e-9,
        "t_cr": 12e-9,
        "t_ds_od": 1e-9,  # NOT DEFINED
        "t_cas_min": 38.4e-9,
        "t_low_od_min": 200e-9,
    }
    tSCL_LOW = spec["t_f_da_od_max"] + spec["t_cas_min"]
    tSDA_RELEASE = spec["t_cf"] + spec["t_ds_od"]
    tSCL_RELEASE = spec["t_f_da_od_max"] + spec["t_cr"] + spec["t_cf"]

    start_timings["tSCL_LOW"] = tSCL_LOW
    start_timings["tSDA_RELEASE"] = tSDA_RELEASE
    start_timings["tSCL_RELEASE"] = tSCL_RELEASE

    logging.info(start_timings)
    return start_timings

# TODO: Finish i3c timings
def i3c_sdr_timings(spec, sys_clk=100e6):
    spec = {
        "f_scl_max": 12.5e6,
        "t_cr": 12e-9,
    }
    bus_period = f2T(spec["f_scl_max"])
    duty_cycle = 0.5
    t_dig_h = duty_cycle * bus_period
    t_dig_l = (1 - duty_cycle) * bus_period

    sdr_timings = {
        "tCLK_PULSE": 0,  # t_cr + t_high
        # From clock low to start
        # or from clock high to low
    }

    tSAMPLE_SDA = spec["t_cr"]
    tCLK_PULSE = bus_period - tSAMPLE_SDA

    sdr_timings["tCLK_PULSE"] = tCLK_PULSE
    sdr_timings["tSAMPLE_SDA"] = tSAMPLE_SDA
    logging.info(f"Settings={sdr_timings}")


def i3c_rise_fall_timings(bus_period):
    tcr = 150e6 * bus_period * 1e-9
    logging.info(f"Worst case rise/fall time = {EN(tcr)}")


# Fig 145 I3C Start Timing
def i3c_stop_timings(spec, sys_clk=100e6):
    sys_period = f2T(sys_clk)
    spec = {
        "f_scl_max": 12.5e6,
        "t_cr_max": 12e-9,
        "t_cbp_min": 38.4e-9 / 2,
    }
    T_PULL_SDA_HIGH = norm_ceil((spec["t_cr_max"] + spec["t_cbp_min"]), sys_period)
    t = cycles2seconds(T_PULL_SDA_HIGH, sys_period)
    logging.info(f"T_PULL_SDA_HIGH={T_PULL_SDA_HIGH}")
    logging.info(f"t={t}")


def main():
    setupLogger()
    # Expected system frequency
    # TODO: Allow setting clock frequency with a script parameter
    sys_freq = 333.333e6
    sys_period = 1 / sys_freq
    logging.info(f"sys_freq         = {EN(sys_freq)}")
    logging.info(f"sys_period       = {EN(sys_period)}")
    for mode in [IXCModes.LEGACY_400k, IXCModes.LEGACY_1M]:
        logging.info(f"*** FW Settings ***")
        logging.info(f"mode             = {mode}")
        generic_timings(mode, sys_freq)
        spec = IXCSpecification(mode)
        get_firmware_settings(spec=spec, sys_clk=sys_freq)

    bus_freq = 12.5e6
    bus_period = f2T(bus_freq)
    logging.info(f"\033[92mI3C :: SDR PUSH-PULL TIMINGS\033[0m")
    logging.info(f"\033[92mI3C :: RISE FALL\033[0m")
    i3c_rise_fall_timings(bus_period)

    logging.info(f"\033[92mI3C :: START\033[0m")
    i3c_start_timings()

    logging.info(f"\033[92mI3C :: SDR \033[0m")
    i3c_sdr_timings(spec=None, sys_clk=sys_freq)

    logging.info(f"\033[92mI3C :: STOP TIMINGS\033[0m")
    i3c_stop_timings(spec=None, sys_clk=sys_freq)


if __name__ == "__main__":
    main()
