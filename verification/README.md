# Verification

The I3C Core is verified with rapid cocotb tests and the UVM test suite, located in `cocotb` and `uvm_i3c` directories, respectively.

## Cocotb

Tests are split into directories:
* `top` - top level, full I3C tests
* `block` - module level, unit tests, subsystems

Once setup is completed, then simulations can be launched with:

```{bash}
make tests
```

In order to run a specific test, you can also use:

```{bash}
TEST=<test_name> make test
```

### Debugging simulations

Launching simulation without `nox` is useful for debugging. In the root of project, export variables:

```{bash}
export CALIPTRA_ROOT=$(pwd)/third_party/caliptra-rtl
export I3C_ROOT_DIR=$(pwd)
```

enter `verification/cocotb/block` directory and run

```{bash}
make -C ./<block_name> clean all MODULE=<test_name>
```

## UVM

### Running I3C agent tests

* To run all I3C agent tests run `make tests-uvm SIMULATOR=simulator_of_your_choice` in the I3C core root folder.
* To run single I3C agent test run
`make i3c-verify-test-uvm SIMULATOR=simulator_of_your_choice TEST=virtual_sequence_to_run`
in the I3C core root folder.

### Running I3C core tests

* To run all I3C agent tests run `make tests-i3c-core-uvm SIMULATOR=simulator_of_your_choice` in the I3C core root folder.
* To run single I3C agent test run
`make i3c-core-verify-test-uvm SIMULATOR=simulator_of_your_choice TEST=virtual_sequence_to_run`
in the I3C core root folder.

## Tools

In directory `tools`, a noxfile is provided to test [the I3C Core Configuration Tool](../tools/i3c_config/i3c_core_config.py).
