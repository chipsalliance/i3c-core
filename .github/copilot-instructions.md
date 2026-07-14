# Copilot Instructions for I3C Core

I3C Core is a SystemVerilog hardware IP (MIPI I3C Basic 1.1.1 / HCI 1.2 / TCRI 1.0)
verified with cocotb+Verilator and UVM. It depends on
[Caliptra RTL](https://github.com/chipsalliance/caliptra-rtl) (a submodule).

## Environment setup

All commands run from the repo root and require the submodules and two env vars:

```bash
git submodule update --init --recursive
export I3C_ROOT_DIR=$(pwd)
export CALIPTRA_ROOT=$(pwd)/third_party/caliptra-rtl
```

Python env (choose one): `./install.sh && . activate.sh` (pyenv + uv, Python 3.11.0),
or `uv venv && uv sync && . .venv/bin/activate`, or `nix develop` (also provides
Verilator, Verible, LCOV, waveform viewers). `. setenv.sh` exports the env vars above
without building the venv.

## Configuration (run before anything else)

The RTL is parameterized by a named configuration. `make config CFG_NAME=<name>`
generates two **in-tree, untracked, and required** artifacts before RTL builds/tests:
- `src/i3c_defines.svh` (defines/parameters)
- `src/csr/` register block (from `src/rdl/registers.rdl` via PeakRDL)

Configs are defined in `i3c_core_configs.yaml`: `ahb` (default), `axi`, `axi_hc`,
`axi-controller`, `axi_bypass`. They select the frontend bus (AHB/AXI), FIFO depths,
and controller/target support. The test targets run `make config` themselves.

## Build, test, lint

- `make help` — lists all targets and overridable variables (`CFG_NAME`, `SIMULATOR`,
  `TEST`, `WAVES`).
- `make tests` — full cocotb suite (AHB + AXI). `make tests-axi` / `make tests-ahb` /
  `make tests-i2c` for subsets.
- `make list-tests` — lists every runnable test (nox sessions of the form
  `<test_name>_verify`).
- **Single test:** `TEST=<test_name> make test` (runs all sub-testpoints for that test).
  For a single parameterized session directly, use `make test-s` (see
  `verification/README.md` for the exact quoting).
- `SIMULATOR=verilator` (default) or `SIMULATOR=vcs`. `WAVES=0` disables wave dumping.
  Logs/waves land next to the test dir under `verification/cocotb/`.
- **Run `make clean` between test runs whenever RTL or the testbench changed.**
- UVM: `make tests-uvm` (core), `make tests-i3c-vip-uvm` (agent); single via `TEST=`.
- Lint: `make lint` (RTL via Verible + tests via nox flake8/black/isort).
  `make lint-check` lints without auto-fixing.

## Architecture (`src/`)

Top level: `i3c.sv` (core, no bus I/O) wrapped by `i3c_wrapper.sv`. The frontend bus is
AXI or AHB, selected at elaboration by generated `I3C_USE_AHB`/`I3C_USE_AXI` defines.

- `hci/` — Host Controller Interface: AHB/AXI adapters, DMA-style `queues/`, TTI, CSRI,
  DXT. Bridges the frontend bus to the controller.
- `ctrl/` — protocol core: I3C/I2C target & controller FSMs, active/standby flows,
  CCC handling, bus monitor/timers, RX/TX descriptor and width-conversion logic.
- `phy/` — I3C PHY (pad drivers, open-drain/push-pull select).
- `recovery/` — OCP recovery handler + PEC.
- `csr/` — **generated** register block (do not hand-edit; regenerate via `make config`).
- `rdl/registers.rdl` — SystemRDL source of truth for all CSRs.
- `libs/` — memory primitives and AXI subordinate helpers.

## Conventions

- Every hand-written source file starts with `// SPDX-License-Identifier: Apache-2.0`.
- Filelists are `.f` files (e.g. `src/i3c.f`) using `+incdir+` and `${I3C_ROOT_DIR}`/
  `${CALIPTRA_ROOT}` variables — add new RTL files here, not to a build script.
- Never edit generated files (`src/csr/*`, `src/i3c_defines.svh`); change `registers.rdl`
  or `i3c_core_configs.yaml` and rerun `make config`.
- Cocotb tests live in `verification/cocotb/{block,top}/<name>/` with a `Makefile`
  including `../{block,top}_common.mk`; test files are named `test_*.py`. Test names map
  to testplan `.hjson` files under `verification/testplan/`; keep them in sync.
- Nox drives every test suite; the top-level Makefile invokes nox, which invokes the
  per-test Makefiles. To debug a sim without nox, run
  `make -C verification/cocotb/<test_dir> all MODULE=<test_name>` (see
  `verification/README.md`).
- In-repo tools live in `tools/` (`i3c_config`, `reg_gen`, `timing`, `verible-scripts`),
  each with its own README; test them with `make tests-tool`.
