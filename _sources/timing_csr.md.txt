# I3C Timing Register Configurations

The tables below provide example Control and Status Register (CSR) timing values for the I3C controller.
These cycle counts are automatically calculated to comply with the absolute physical nanosecond constraints defined in the MIPI I3C Basic and I2C Fast Mode specifications.
The configurations shown represent valid, ready-to-use timings for a selection of common system clock frequencies.

## Generating Custom Timings

If your specific FPGA or ASIC target uses a different underlying system clock (`f_sys`), or if you need to operate at a slower I3C bus frequency (`f_scl`), you should generate a custom set of timings. 

You can calculate and validate new configurations using the `timings.py` utility via the command line:

```bash
# Calculate timings for a 200 MHz system clock and the default 12.5 MHz I3C bus
python tools/timing/timings.py --freq=200e6

# Calculate timings for a specific 10 MHz I3C bus on a 500 MHz system clock
python tools/timing/timings.py --freq=500e6 --bus_freq=10e6

# Output the results directly as a MyST Markdown table for documentation
python tools/timing/timings.py --freq=333.333e6 --target_name="FPGA 333MHz" --md

```

## Example Timing CSRs
