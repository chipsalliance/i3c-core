# I3C Timing Generator & Validator

This module calculates and validates I3C and I2C Fast Mode timing parameters (in system clock cycles) for an I3C Controller based on the MIPI I3C Basic specification.

## Core Functions

* **`generate_timings(f_scl, f_sys, duty_cycle=0.5)`**: Calculates required CSR register cycle counts based on target SCL and system clock frequencies (in Hz). Clamps max SCL frequency to 12.9 MHz and automatically enforces physical hardware minimums.
* **`validate_timings(timings, f_sys)`**: Validates a dictionary of timing cycles against absolute I3C nanosecond constraints, logging errors for any spec violations.
* **`log_timing_configuration(timings, f_sys=None)`**: Neatly formats and logs the generated timing configuration into a table. If `f_sys` is provided, it also calculates and displays the physical time in nanoseconds for each register.

## Quick Start (Python)
```python
import logging
from timings import generate_timings, log_timing_configuration

logging.basicConfig(level=logging.INFO)

# Generate valid CSR timings for 12.5 MHz SCL and 333.33 MHz System Clock
SYS_CLK = 333.333e6
csr_timings = generate_timings(f_scl=12.5e6, f_sys=SYS_CLK)

# Print the nicely formatted table of cycle counts and physical times
log_timing_configuration(csr_timings, f_sys=SYS_CLK)
```

## CLI Usage

You can also run the module directly from the command line to calculate and validate timings without writing a custom script.
It accepts frequencies in scientific notation (e.g., `200e6`).

### Arguments:
* `--freq` **(Required)**: System clock frequency in Hz.
* `--bus_freq`: Target I3C bus frequency in Hz (Default: `12.5e6`).
* `--duty_cycle`: Target duty cycle ratio (Default: `0.5`).
* `--md`: Output the results as a MyST Markdown table (useful for CI/CD documentation generation).
* `--target_name`: Custom name for the Markdown table header (Default: `"I3C Target"`).

### Examples:

**1. Standard calculation for a 200 MHz system clock (uses default 12.5 MHz bus):**
```bash
python timings.py --freq=200e6
```

**2. Custom system clock and slower 10 MHz bus clock:**
```bash
python timings.py --freq=500e6 --bus_freq=10e6
```

**3. Generate MyST Markdown output for documentation:**
```bash
python timings.py --freq=333.333e6 --target_name="FPGA 333MHz" --md
```
