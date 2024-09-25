# VCD to PulseView

This tool converts VCD to contain just signals specifiec by the TCL script provided for the GTKWave.
The generated VCD is then loaded to PulseView with a provided configuration file.
It provides additional flags and default setup.

# Prerequisites

In order to succesfully use this tool, first install:
* Python 3
* GTKWave with TCL support (<= [0bc00e1](https://github.com/gtkwave/gtkwave/tree/0bc00e129123278313d3e042250cb5004cb66d09))
* PulseView

# Usage
```bash
vcd2pulseview --waveform waves.vcd
```

The default script run will extract SCL and SDA signals from the provided VCD and will run PulseView with the I2C analyzer enabled.
There are multiple arguments to alter the default behavior:
* `--no-vcd-update` - omits generating new VCD file, useful if you want to run PulseView with the analyzer on old VCD
* `--no-run-pulseview` - omits running PulseView, useful to just regenerate VCD which can be reloaded in the PulseView GUI
* `--pulseview-config config.cfg` - provides a custom config file for the PulseView which might be used to load different decoder or alter the view
* `--gtkwave-config` - provides a custom TCL script for GTKWave which might be used to extract different signals from the generated VCD

**Note:** In case of the default GTKWave TCL script, it will extract SDA and SCL signals properly but since they might be extracted from a hierarchy, they might require manual adding to the analyzer in PulseView.
