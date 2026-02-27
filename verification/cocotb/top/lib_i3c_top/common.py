# SPDX-License-Identifier: Apache-2.0
"""Shared constants and helpers for I3C Target cocotb tests."""

import cocotb
from cocotb.triggers import Timer

# Canonical I3C address list — single source of truth
# 0x23 is excluded: it is hardcoded as the I3CTarget sim model address
# and selecting it for DUT addresses causes bus contention.
VALID_I3C_ADDRESSES = (
    [i for i in range(0x03, 0x23)]
    + [i for i in range(0x24, 0x3E)]
    + [i for i in range(0x3F, 0x5E)]
    + [i for i in range(0x5F, 0x6E)]
    + [i for i in range(0x6F, 0x76)]
    + [i for i in range(0x77, 0x7A)]
    + [0x7B, 0x7D]
)


async def timeout_task(timeout_us):
    """Generic test timeout. Raises TimeoutError after timeout_us microseconds."""
    await Timer(timeout_us, "us")
    raise TimeoutError(f"Test timeout after {timeout_us} us!")


def log_seed(dut):
    """Log the random seed for reproducibility."""
    seed = cocotb.plusargs.get("seed", None)
    dut._log.info(f"Random seed: {seed or 'unknown (set via RANDOM_SEED plusarg)'}")
