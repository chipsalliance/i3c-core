# I3C Core

This repository provides an I3C Core, which will be:
* compliant with
  * MIPI Alliance Specification for I3C Basic, Version 1.1.1
  * MIPI Alliance Specification for I3C HCI, Version 1.2
  * MIPI Alliance Specification for I3C TCRI, Version 1.0
* operational in both Active and Secondary Controller Mode

A login with MIPI Alliance account is required to access the document on [MIPI website](https://www.mipi.org/specifications/i3c-sensor-specification).

This repository provides:
* [SystemVerilog description of the hardware](src)
* [Software tests](sw)
* [Cocotb/Verilator verification](verification/block)
* [UVM tests](verification)

This repository depends on:
* [Caliptra RTL](https://github.com/chipsalliance/caliptra-rtl)

## Setup

### System requirements

This repository is currently tested on Debian 12 and Ubuntu 22.04. In order to use all features, you need to install:
* [RISC-V toolchain == 12.1.0](https://github.com/chipsalliance/caliptra-tools/releases/download/gcc-v12.1.0/riscv64-unknown-elf.gcc-12.1.0.tar.gz)
* [Verilator >= 5.012](https://github.com/verilator/verilator?tab=readme-ov-file#installation--documentation)
* [LCOV == v1.16](https://github.com/linux-test-project/lcov)
* [Verible == v0.0-3624-gd256d779](https://github.com/chipsalliance/verible?tab=readme-ov-file#installation-1)
* [Icarus Verilog >= 12.0](https://github.com/steveicarus/iverilog.git)

### Submodules

Make sure submodules are checked out. Use the `--recursive` flag when cloning, or run

```{bash}
git submodule update --init --recursive
```

if you already cloned the repository.

### Python

Python 3.11.0 is recommended for this project. A bootstrap script is provided:

```{bash}
bash install.sh
```

This script installs `pyenv`. Then, you can activate the environment:

```{bash}
. activate.sh
```

Activate script creates a virtual environment with Python3.11 and installs python packages from the `requirements.txt`.

## Verification

This core is verified by 2 approaches:
* rapid tests written in cocotb
* UVM test suite

To check if the environment is properly configured, run tests:

```{bash}
make tests
```

More details can be found in [`verification README`](./verification/README.md).

## Tools

Tools developed for this project are located in `tools` directory. You can find more detailed information in README of each tool:
- [`i3c_config`](./tools/i3c_config/README.md) - manage configuration and produce header files
- [`pyenv`](./tools/pyenv/README.md) - enable usage of pyenv in BASH
- [`reg_gen`](./tools/reg_gen/README.md) - scripts to generate SystemVerilog description from the SystemRDL files
- [`timing`](./tools/timing/README.md) - helper script to estimate timings on the bus
- [`verible-scripts`](./tools/verible-scripts/README.md) - scripts to manage configuration and runs of Verible formatter and linter
