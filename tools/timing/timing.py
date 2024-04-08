# SPDX-License-Identifier: Apache-2.0

import sys
import logging
from engineering_notation import EngNumber as EN
from timing_requirements import *

def setupLogger(level=logging.INFO, filename="log.log"):
    logging.basicConfig(
        level=level,
        handlers=[
            logging.FileHandler(filename),
            logging.StreamHandler()
        ]
    )

# Ideal, symmetrical t_HIGH, t_LOW
def calc_thigh(freq):
    T = 1/freq
    return 0.5*T

# TODO: figure out if this still holds in our design
# https://opentitan.org/book/hw/ip/i2c/doc/programmers_guide.html
# > To guarantee clock stretching works correctly in Controller-Mode, there is a requirement of THIGH >= 4.
# > We are aware of two issues with timing calculations.
# > First, the fall time (T_F) is counted twice in host mode as is tracked in issue #18958.
# > Second, the high time (THIGH) is 3 cycles longer when no clock stretching is detected as tracked in issue #18962.
def main():
    setupLogger()
    # Suppose we use this clock
    sys_freq = 100e6
    sys_period = 1/sys_freq
    logging.info(f"sys_freq \t= {EN(sys_freq)}")
    logging.info(f"sys_period \t= {EN(sys_period)}")

    for mode in IXCModes:
        logging.info(f"mode  \t= {mode}")
        freq = freq_dict[mode]
        t_high = calc_thigh(freq)
        t_low = calc_thigh(freq)
        logging.info(f"freq  \t= {EN(freq)}")
        logging.info(f"t_high \t= {EN(t_high)}")
        logging.info(f"t_low \t= {EN(t_low)}")
        oversampling = sys_freq/freq
        logging.info(f"oversampling \t= {EN(oversampling)}")
        counter_high_low = 0.5*oversampling
        logging.info(f"counter_high_low \t= {EN(counter_high_low)}")

    get_firmware_settings(spec=spec_dict[IXCModes.LEGACY_400k], sys_clk=sys_freq)
    # TODO: Other specs
    # get_firmware_settings(spec=spec_dict[IXCModes.LEGACY_1M], sys_clk=sys_freq)
    # get_firmware_settings(spec=spec_dict[IXCModes.I3C_SDR_12M5], sys_clk=sys_freq)

if __name__ == "__main__":
    main()
