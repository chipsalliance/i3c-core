# SPDX-License-Identifier: Apache-2.0

TOPLEVEL_LANG    = verilog
SIM             ?= verilator
WAVES           ?= 1

# Paths
CURDIR = $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
I3C_ROOT := $(abspath $(CURDIR)/../..)
CFGDIR :=
CONFIG :=
$(info From common.mk, CURDIR is $(CURDIR))

# Set pythonpath so that tests can access common modules
export PYTHONPATH := $(PYTHONPATH):$(CURDIR)/common

# Common sources
COMMON_SOURCES  = \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_assert.sv \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_pkg.sv \
    $(CALIPTRA_ROOT)/src/caliptra_prim_generic/rtl/caliptra_prim_generic_flop.sv \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_flop.sv \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_flop_2sync.sv

COMMON_INCLUDES = \
    -I$(CALIPTRA_ROOT)/src/libs/rtl \
    -I$(CALIPTRA_ROOT)/src/caliptra_prim/rtl \
    -I$(I3C_ROOT)/src \
    -I$(I3C_ROOT)/src/libs/axi

$(info VERILOG_SOURCES = $(VERILOG_SOURCES))
VERILOG_SOURCES := $(COMMON_SOURCES) $(VERILOG_SOURCES)
$(info VERILOG_SOURCES = $(VERILOG_SOURCES))


# Coverage reporting
COVERAGE_TYPE ?=
ifeq ("$(COVERAGE_TYPE)", "all")
    VERILATOR_COVERAGE = --coverage
else ifeq ("$(COVERAGE_TYPE)", "branch")
    VERILATOR_COVERAGE = --coverage-line
else ifeq ("$(COVERAGE_TYPE)", "toggle")
    VERILATOR_COVERAGE = --coverage-toggle
else ifeq ("$(COVERAGE_TYPE)", "functional")
    VERILATOR_COVERAGE = --coverage-user
else
    VERILATOR_COVERAGE = ""
endif

# Enable processing of #delay statements
ifeq ($(SIM), verilator)
    COMPILE_ARGS += --timing
    COMPILE_ARGS += -Wall -Wno-fatal

    EXTRA_ARGS += --trace --trace-structs
    EXTRA_ARGS += $(VERILATOR_COVERAGE)
    EXTRA_ARGS += -Wno-DECLFILENAME -Wno-TIMESCALEMOD
endif

COCOTB_HDL_TIMEUNIT         = 1ns
COCOTB_HDL_TIMEPRECISION    = 10ps

ifneq ($(CFGDIR),)
EXTRA_ARGS += -I$(CFGDIR)
endif

EXTRA_ARGS += $(COMMON_INCLUDES) -DSIM=$(SIM)

# Build directory
ifneq ($(COVERAGE_TYPE),)
    SIM_BUILD := sim-build-$(COVERAGE_TYPE)
endif

# Do not import cocotb configuration if it's a RTL testbench
ifeq (,$(filter icarus-test verilator-test,$(MAKECMDGOALS)))
    include $(shell cocotb-config --makefiles)/Makefile.sim
endif
