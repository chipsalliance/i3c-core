# Verification

The I3C Core is verified with rapid cocotb tests and the UVM test suite, located in `cocotb` and `uvm_i3c` directories, respectively.

All verification should be launched from a shell in the project root.

## Cocotb Tests

Tests are split into directories:
* `top` - top level, full I3C tests
* `block` - module level, unit tests, subsystems

## Setup Dependencies

Clone this repository to a working directory.
Ensure that all submodules are initialized and populated (e.g. `git submodule update --init --recursive`)

If you wish to use VCS as a simulator, this will also need to be present on the path, and appropriate license server envvars set.

The following FOSS dependencies are required:
- python311
- verible
- lcov
- verilator 5.024
- zlib

The python module dependencies are specified in pyproject.toml.
Lockfiles suitable for pip (requirements.txt) and uv (uv.lock) are provided.

Running `./install.sh` will install `pyenv` and use it to build a virtual environment, which can be activated with `. activate.sh`.
Alternatively, `uv` can be used with `uv venv && uv sync` building a virtual environment and then activating it with `. .venv/bin/activate`.

### Nix-Alternative

A Nix-based environment is also present, which provides an ephemeral development shell environment containing all of the above FOSS dependencies, plus some conveniences such as GTKwave and Surfer for waveform viewing.
The python dependencies in this case are managed by uv, which is run at the time of entering the shell via a hook.

This can be convenient and valuable to avoid polluting the base computing environment with project dependencies.

With a Nix installation (e.g. https://nixos.org/download/ ) and the nix-command+flakes experimental features enabled (e.g. `/etc/nix/nix.conf` contains the line `experimental-features = nix-command flakes`), it can be used as follows:
```
## Enter the subshell, adding all deps to your path
$ nix develop

## Run tests
## e.g
$ SIMULATOR=verilator make tests-axi
$ surfer verification/cocotb/top/i3c_axi/test_recovery.fst

## Exit the subshell
$ exit
```

## Running tests

### Cocotb

The top-level Makefile contains a number of targets that can be used to run suites of tests.
All simulations can be launched with `make tests`.
In order to run a specific test, you can also use `TEST=<test_name> make test`.
`make list-tests` will print all of the available tests, which are of the form `<test_name>_verify`.

`make clean` should be run between test invocations where the RTL or testbench environment has been changed.

Passing extra environment variables allows for configuration of what will be run, and how.
Use `SIMULATOR=<verilator/vcs>` to choose the simulation tool.
Verilator is the default.
Setting `CFG_NAME=axi` will pass a set of parameterizations to use the AXI instantiation.
Wave dumping is enabled by default, but can be disabled by setting `WAVES=0`.
Setting `TEST` wil choose a specific cocotb test to be run.
These are selected via “sessions” defined in the noxfiles, which can be printed using `make list-tests`.

Logfiles/waves will be placed adjacent to the specific test run within `verification/cocotb/`.
e.g.
```
SIMULATOR=vcs CFG_NAME=axi TEST=i3c_axi make test
verdi -base -ssf ./verification/cocotb/top/i3c_axi/test_recovery.fsdb
```
or...
```
SIMULATOR=verilator CFG_NAME=axi TEST=i3c_axi make test
gtkwave verification/cocotb/top/i3c_axi/test_i3c_target.fst
```

Note that running many tests via `nox` can be slow, as it does not parallelize jobs.
To run a single test directly via a `nox` session parameterization, the `test-s` target can be used.
The parameterization shown can usually be extracted from the stdout of a larger regression, however note the additional quotations/escapes needed.
e.g.
```
SIMULATOR=vcs CFG_NAME=axi TEST="\"i3c_axi_verify(simulator='vcs', coverage=None, test_name='test_recovery', test_group='i3c_axi')\"" make test-s
```

### Debugging cocotb simulations

The top-level Makefile invokes `nox` to run tests as parameterized in a series of noxfiles throughout the project.
These noxfiles invoke the simulators via a seperate invocation of Make, to which the directory of the test is passed (via `-C`) and the test name (via `MODULE=<test_name>`).
For example, the command to invoke a test might be something like `make -C ./top/i3c_axi/ all TEST=test_ccc`.

Launching a simulation directly (i.e. without `nox` ) can be useful for debugging.
This can be done, from the project root, as follows:

```{bash}
# First ensure the environment is setup
export I3C_ROOT_DIR=$(pwd)
export CALIPTRA_ROOT=$(pwd)/third_party/caliptra-rtl
# Then run the following
pushd verification/cocotb
make clean
make -C ./<test_dir> all MODULE=<test_name>
```

### UVM

#### Running I3C agent tests

* `make tests-uvm SIMULATOR=simulator_of_your_choice` runs all I3C agent tests.
* `make i3c-verify-test-uvm SIMULATOR=simulator_of_your_choice TEST=virtual_sequence_to_run` runs a single I3C agent test.

#### Running I3C core tests

* `make tests-i3c-core-uvm SIMULATOR=simulator_of_your_choice` runs all I3C core tests.
* `make i3c-core-verify-test-uvm SIMULATOR=simulator_of_your_choice TEST=virtual_sequence_to_run` runs a single I3C core test.
