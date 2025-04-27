# Design verification

This chapter presents the available models and tools which are used for I3C verification.
The core is verified with [the Cocotb + unit tests](https://github.com/chipsalliance/i3c-core/tree/main/verification/cocotb/block) and [the UVM test suite](https://github.com/chipsalliance/i3c-core/tree/main/verification/uvm_i3c).


This section contains testplans for the verification.

Definitions:
* `testplan` - an organized collection of testpoints
* `testpoint` - an actionable item, which can be turned into a test:
    * `name` - typically related to the tested feature
    * `desc` - detailed description; should contain description of the feature, configuration mode, stimuli, expected behavior.
    * `stage` - can be used to assign testpoints to milestones.
    * `tests` - names of implemented tests, which cover the testpoint. Relation test-testpoint can be many to many.
    * `tags` - additional tags that can be used to group testpoints

Full overview of tests can be found in [Testplan summary](./sim-results/index.html){.external}.

## Testplans for individual blocks

```{include} ../../verification/testplan/generated/testplans_blocks.md
:heading-offset: 2
```

## Testplans for the core

```{include} ../../verification/testplan/generated/testplans_core.md
:heading-offset: 2
```

## Compliance test suite

The list of non-public tests which utilize Avery I3C VIP framework and have been successfully ran against the design is available in the [CTS list](https://github.com/chipsalliance/i3c-core/blob/main/doc/cts-list.md).


