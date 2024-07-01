# Verification

In this project, `nox` is used to manage the cocotb test suite.

## Block

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

enter `verification/block` directory and run

```{bash}
make -C ./<block_name> clean all MODULE=<test_name>
```

## UVM

TBD

## Tools

TBD
