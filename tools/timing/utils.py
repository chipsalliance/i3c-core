# SPDX-License-Identifier: Apache-2.0

import logging
import math


def setupLogger(level=logging.INFO, filename="log.log"):
    logging.basicConfig(
        level=level, handlers=[logging.FileHandler(filename), logging.StreamHandler()]
    )


def f2T(freq):
    T = 1 / freq
    return T


def T2f(T):
    freq = 1 / T
    return freq


def f2halfT(freq):
    T = f2T(freq)
    return 0.5 * T


def norm_ceil(val, period):
    return math.ceil(val / period)


def cycles2seconds(val, period):
    return val * period
