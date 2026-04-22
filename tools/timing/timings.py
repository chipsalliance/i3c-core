# SPDX-License-Identifier: Apache-2.0

import logging
import math
import argparse

# --- 1. BASE SPECIFICATION CONSTRAINTS ---
# Absolute minimums according to the I3C Basic/I2C FM spec (in nanoseconds)
I3C_MIN_TIMINGS_NS = {
    "T_R": 0.0,              # Managed physically
    "T_F": 0.0,              # Managed physically
    "T_SU_DAT": 3.0,
    "T_SU_DAT_I2C": 100.0,
    "T_HD_DAT": 0.0,
    "T_HIGH": 24.0,          # I3C PP High >= 24 ns
    "T_HIGH_OD": 24.0,       # I3C OD High >= 24 ns
    "T_HIGH_INIT_OD": 200.0, # I3C Init OD High >= 200 ns
    "T_HIGH_I2C": 600.0,
    "T_LOW": 24.0,           # I3C PP Low >= 24 ns
    "T_LOW_OD": 200.0,       # I3C OD Low >= 200 ns
    "T_LOW_I2C": 1300.0,
    "T_HD_STA": 38.4,
    "T_HD_STA_I2C": 600.0,
    "T_HD_RSTA": 19.2,
    "T_SU_STA": 19.2,
    "T_SU_STA_I2C": 600.0,
    "T_SU_STO": 19.2,
    "T_SU_STO_I2C": 600.0,
    "T_DS_OD": 19.2,
    "T_FREE": 38.4,
    "T_FREE_I2C": 1300.0,
    "T_AVAL": 1000.0,
    "T_IDLE": 200000.0,
}

def validate_timings(timings: dict, f_sys: float) -> bool:
    """
    Validates a dictionary of timing registers against the I3C Basic spec.
    """
    t_sys_ns = 1e9 / f_sys
    is_valid = True
    
    # 1. Check individual minimum constraints
    for key, min_ns in I3C_MIN_TIMINGS_NS.items():
        if key not in timings:
            logging.error(f"Validation Error: Missing timing parameter '{key}'")
            is_valid = False
            continue
            
        min_cycles = math.ceil(min_ns / t_sys_ns)
        
        if timings[key] < min_cycles:
            logging.error(
                f"Validation Error: {key} ({timings[key]} cycles) is less than "
                f"the minimum spec requirement ({min_cycles} cycles)."
            )
            is_valid = False

    if "T_HIGH" in timings and "T_LOW" in timings:
        # T_HIGH + T_LOW must be >= 80 ns (max frequency is 12.5 MHz)
        period_ns = (timings["T_HIGH"] + timings["T_LOW"]) * t_sys_ns
        if period_ns < 80.0:
            logging.error(
                f"Validation Error: I3C SDR Period ({period_ns:.1f} ns) "
                f"violates the 12.5 MHz max frequency (Must be >= 80.0 ns)."
            )
            is_valid = False

    if is_valid:
        logging.info("All timings validated successfully against I3C Basic Spec!")
        
    return is_valid

def generate_timings(f_scl: float, f_sys: float, duty_cycle: float = 0.5) -> dict:
    """
    Generates valid I3C timing registers (in clock cycles) based on target SCL freq,
    system clock freq, and desired duty cycle. Warns if requested timings are overridden.
    """
    MAX_F_SCL = 12.9e6
    
    # Enforce maximum f_SCL limit
    if f_scl > MAX_F_SCL:
        logging.error(
            f"Requested f_SCL ({f_scl/1e6:.2f} MHz) exceeds the maximum allowed "
            f"limit! Clamping f_SCL to {MAX_F_SCL/1e6:.2f} MHz."
        )
        f_scl = MAX_F_SCL

    t_sys_ns = 1e9 / f_sys
    t_scl_ns = 1e9 / f_scl

    # Calculate target high/low times in ns based on SCL frequency and duty cycle
    t_high_req_ns = t_scl_ns * duty_cycle
    t_low_req_ns = t_scl_ns * (1.0 - duty_cycle)

    min_t_high = I3C_MIN_TIMINGS_NS["T_HIGH"]
    min_t_low = I3C_MIN_TIMINGS_NS["T_LOW"]

    # Check if the requested parameters violate the baseline I3C specs
    if t_high_req_ns < min_t_high or t_low_req_ns < min_t_low:
        logging.error(
            f"Target f_SCL ({f_scl/1e6:.2f} MHz) with {duty_cycle*100:.0f}% duty cycle "
            f"yields T_HIGH={t_high_req_ns:.1f}ns and T_LOW={t_low_req_ns:.1f}ns. "
            f"This violates I3C limits! Overriding to safe minimums "
            f"(T_HIGH>={min_t_high}ns, T_LOW>={min_t_low}ns)."
        )

    # Enforce standard spec minimums so we don't accidentally violate them
    t_high_ns = max(t_high_req_ns, min_t_high)
    t_low_ns = max(t_low_req_ns, min_t_low)

    # Create a working copy of our timings in ns
    timings_ns = I3C_MIN_TIMINGS_NS.copy()
    timings_ns["T_HIGH"] = t_high_ns
    timings_ns["T_LOW"] = t_low_ns

    # Convert all nanosecond values to system clock cycles
    def ns_to_cycles(ns: float) -> int:
        return math.ceil(ns / t_sys_ns)

    timings_cycles = {reg: ns_to_cycles(ns) for reg, ns in timings_ns.items()}

    assert validate_timings(timings=timings_cycles, f_sys=f_sys)

    return timings_cycles

def log_timing_configuration(timings: dict, f_sys: float = None):
    """
    Nicely formats and logs the current timing configuration.
    If f_sys is provided, it also calculates the actual time in nanoseconds.
    """
    logging.info("=== I3C Timing Configuration ===")
    
    if f_sys:
        t_sys_ns = 1e9 / f_sys
        logging.info(f"{'Register':<16} | {'Cycles':<8} | {'Time (ns)':<10}")
        logging.info("-" * 40)
        for key, cycles in timings.items():
            time_ns = cycles * t_sys_ns
            logging.info(f"{key:<16} | {cycles:<8} | {time_ns:.2f}")
    else:
        logging.info(f"{'Register':<16} | {'Cycles':<8}")
        logging.info("-" * 28)
        for key, cycles in timings.items():
            logging.info(f"{key:<16} | {cycles:<8}")
            
    logging.info("================================")

def print_myst_table(timings: dict, f_sys: float, target_name: str):
    """Prints the timing configuration as a MyST list-table."""
    t_sys_ns = 1e9 / f_sys
    target_scl_mhz = 1e9 / (timings['T_HIGH']*t_sys_ns + timings['T_LOW']*t_sys_ns) / 1e6
    
    # Safe reference name (lowercase, no spaces)
    ref_name = f"timing-csr-{target_name.lower().replace(' ', '-')}"

    # Print header context outside the table
    print(f"### {target_name} Configuration\n")
    print(f"**System Clock:** {f_sys / 1e6:.2f} MHz | **Target SCL:** {target_scl_mhz:.2f} MHz\n")
    
    # Print the MyST table
    print(f":::{{list-table}} {target_name} Timing Registers")
    print(f":name: {ref_name}")
    print(":widths: 40 30 30")
    print(":header-rows: 1\n")
    
    # Table Headers
    print("* - **Register**")
    print("  - **Cycles**")
    print("  - **Time (ns)**")
    
    # Table Data
    for key, cycles in timings.items():
        time_ns = cycles * t_sys_ns
        print(f"* - {key}")
        print(f"  - {cycles}")
        print(f"  - {time_ns:.2f}")
        
    print(":::\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate and validate I3C timings.")
    
    parser.add_argument(
        "--freq", 
        type=float, 
        default=200.0e6,
        help="System clock frequency in Hz (Default: 200.0e6)"
    )
    
    parser.add_argument(
        "--bus_freq", 
        type=float, 
        default=12.5e6, 
        help="Target I3C bus frequency in Hz (Default: 12.5e6)"
    )
    
    parser.add_argument(
        "--duty_cycle", 
        type=float, 
        default=0.5, 
        help="Target duty cycle (Default: 0.5)"
    )

    parser.add_argument(
        "--md", 
        action="store_true", 
        help="Output the results as a MyST Markdown table (suppresses standard logging)"
    )
    
    parser.add_argument(
        "--target_name", 
        type=str, 
        default="I3C Target", 
        help="Name of the configuration for the Markdown header (e.g., 'FPGA', 'ASIC')"
    )

    args = parser.parse_args()

    log_level = logging.WARNING if args.md else logging.INFO
    logging.basicConfig(level=log_level, force=True)

    if not args.md:
        logging.info(f"Generating timings for System Clock: {args.freq / 1e6:.2f} MHz, Bus Clock: {args.bus_freq / 1e6:.2f} MHz")

    # Generate the timings
    timings = generate_timings(f_scl=args.bus_freq, f_sys=args.freq, duty_cycle=args.duty_cycle)
    
    # Output the results based on the flags
    if args.md:
        print_myst_table(timings, f_sys=args.freq, target_name=args.target_name)
    else:
        log_timing_configuration(timings, f_sys=args.freq)
