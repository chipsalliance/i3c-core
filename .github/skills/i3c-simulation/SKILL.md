---
name: i3c-simulation
description: Run I3C cocotb simulation tests and regressions. Use this skill when building, running, or debugging I3C testbench simulations, interpreting test results, or finding simulation logs and waveforms.
---

# I3C Simulation Skill

## Project Root

All paths in this skill are relative to the repository root, exported as
`$I3C_ROOT_DIR`. Set it once from your checkout:

```bash
export I3C_ROOT_DIR=$(git rev-parse --show-toplevel)
```

## Simulator

The default simulator is **VCS**. Always pass `SIM=vcs` unless the user explicitly requests Verilator.

If asked to run with **Verilator**, point `VERILATOR_ROOT` at your Verilator source tree:

```bash
SIM=verilator VERILATOR_ROOT="$VERILATOR_ROOT" make ...
```

## Compute Cluster (required for VCS)

EDA licenses (VCS/Verdi) **cannot be checked out on the login node** — running
`SIM=vcs make ...` directly there fails with a "LICENSE BLOCKED on a LOGIN NODE"
error. Pass **`CLUSTER=1`** to re-exec the whole flow (config + compile + sim) on
a compute node via the `submit` wrapper:

```bash
CLUSTER=1 SIM=vcs make MODULE=test_i3c_target TESTCASE=test_i3c_target_read_to_multiple_targets
```

- The scheduler is auto-detected (LSF, Altair/NC, ...).
- To force a scheduler or use a different wrapper, override `SUBMIT_CMD`, e.g.
  `SUBMIT_CMD='submit -i -s lsf --'` or `SUBMIT_CMD='bsub -Is'`.
- `LSF=1` is accepted as a backward-compatible alias for `CLUSTER=1`.
- Verilator runs do not need `CLUSTER=1`.

**Add `CLUSTER=1` to every `SIM=vcs` command below.**

## Running Tests

All tests are run from within a configuration directory. The primary configuration is AXI:

```bash
cd "$I3C_ROOT_DIR/verification/cocotb/top/i3c_axi/"
```

### Run a Single Test Case

```bash
CLUSTER=1 SIM=vcs make MODULE=test_i3c_target TESTCASE=test_i3c_target_read_to_multiple_targets
```

- `MODULE` = the Python file name (without `.py`)
- `TESTCASE` = the specific test function name within that file

### Run Without Waveforms (Faster)

```bash
CLUSTER=1 WAVES=0 SIM=vcs make MODULE=test_i3c_target TESTCASE=test_i3c_target_read_to_multiple_targets
```

### Run All Tests in a File

```bash
CLUSTER=1 SIM=vcs make MODULE=test_i3c_target
```

**⚠️ Use sparingly** — running all tests in a file can take a very long time. Only do this when 100% required (e.g., final regression check).

## Simulation Output

### Main Output (STDOUT)

**No official log file is generated** for the main simulation output. The output goes to STDOUT. To capture it for later analysis:

```bash
CLUSTER=1 SIM=vcs make MODULE=test_i3c_target TESTCASE=test_i3c_target_read 2>&1 | tee run.log
```

### SV Monitor Logs

SystemVerilog monitors automatically dump logs into the run directory (e.g., `i3c_axi/`):

| Log File | Contents |
|----------|----------|
| `axi_csr_transactions.log` | AXI CSR read/write transactions |
| `fsm_transitions.log` | Main FSM state transitions |
| `ccc_fsm_transitions.log` | CCC FSM transitions |
| `ccc_entdaa_fsm_transitions.log` | ENTDAA FSM transitions |
| `descriptor_ibi_fsm_transitions.log` | IBI descriptor FSM transitions |
| `recovery_receiver_fsm_transitions.log` | Recovery FSM transitions |

### Waveforms

- **File**: `dump.fsdb` in the run directory
- Use the `fsdb-waveform-debug` skill for FSDB extraction and analysis

### Test Results

- `results.xml` in the run directory (cocotb JUnit output)

## Running with Coverage

Add `COVERAGE_TYPE` to enable code coverage collection:

```bash
# All coverage metrics (line + cond + fsm + toggle + branch)
COVERAGE_TYPE=all CLUSTER=1 SIM=vcs make MODULE=test_i3c_target TESTCASE=test_i3c_target_read

# Specific coverage type
COVERAGE_TYPE=branch CLUSTER=1 SIM=vcs make MODULE=test_i3c_target TESTCASE=test_i3c_target_read
```

| `COVERAGE_TYPE` | VCS flags | Verilator flag |
|-----------------|-----------|----------------|
| `all` | `-cm line+cond+fsm+tgl+branch -lca` | `--coverage` |
| `branch` | same | `--coverage-line` |
| `toggle` | same | `--coverage-toggle` |
| `functional` | same | `--coverage-user` |

**Notes:**
- Coverage builds go to a separate directory: `sim_build-<MODULE>-<COVERAGE_TYPE>/`
- VCS supports multiple modules with coverage: `MODULE=test_i3c_target,test_i3c_ibi`
- Non-VCS simulators do **not** support multi-module coverage runs

## Recompilation Rules

| Change Type | Action Required |
|-------------|-----------------|
| **RTL change** (`.sv`, `.svh`) | **Must** delete `sim_build/` before re-running: `rm -rf sim_build/` |
| **cocotb change** (`.py`) | No rebuild needed — just re-run the make command |

**Common mistake**: Forgetting to remove `sim_build/` after an RTL change. The simulator will NOT auto-recompile.

## Configurations

Two configurations exist, both running the **same shared tests**:

| Config | Directory (relative to `$I3C_ROOT_DIR`) | Bus Interface |
|--------|------------------------------------------|---------------|
| **AXI** | `verification/cocotb/top/i3c_axi/` | AXI bus |
| **AHB** | `verification/cocotb/top/i3c_ahb/` | AHB bus |

Test Python files in `i3c_axi/` and `i3c_ahb/` are **symlinks** to the shared test library at `verification/cocotb/top/lib_i3c_top/`. Always edit tests in `lib_i3c_top/`, never in the config directories.

## Test File Locations

All paths are relative to `$I3C_ROOT_DIR`.

| Path | Purpose |
|------|---------|
| `verification/cocotb/top/lib_i3c_top/` | Shared test library — all test files live here |
| `verification/cocotb/top/lib_i3c_top/test_*.py` | Test files (symlinked into axi/ahb dirs) |
| `verification/cocotb/top/lib_i3c_top/common.py` | Common test utilities |
| `verification/cocotb/top/lib_i3c_top/interface.py` | Interface helpers |
| `verification/cocotb/top/lib_i3c_top/boot.py` | Boot sequence helpers |
| `verification/cocotb/top/lib_i3c_top/i3c_controller_fixed.py` | Overridden cocotbext-i3c classes |
| `third_party/cocotbext-i3c/` | Base I3C cocotb extension classes |

## Modifying cocotbext-i3c

If you need to modify behavior from `third_party/cocotbext-i3c/`, do **NOT** edit the third-party files directly. Instead, follow the override pattern in:

```
verification/cocotb/top/lib_i3c_top/i3c_controller_fixed.py
```

This file shows how to subclass and override the base cocotbext-i3c classes.
