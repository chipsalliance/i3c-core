# Copyright (c) 2024 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

TOPLEVEL_LANG    = verilog
SIM             ?= verilator
WAVES           ?= 1

# Paths
CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
CFGDIR :=
CONFIG :=

# Set pythonpath so that tests can access common modules
export PYTHONPATH := $(CURDIR)/common

# Common sources
COMMON_SOURCES  =

VERILOG_SOURCES := $(COMMON_SOURCES) $(VERILOG_SOURCES)


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

    EXTRA_ARGS   += --trace --trace-structs
    EXTRA_ARGS   += $(VERILATOR_COVERAGE)
endif

COCOTB_HDL_TIMEUNIT         = 1ns
COCOTB_HDL_TIMEPRECISION    = 10ps

EXTRA_ARGS += -I$(CFGDIR) -Wno-DECLFILENAME

# Build directory
ifneq ($(COVERAGE_TYPE),)
    SIM_BUILD := sim-build-$(COVERAGE_TYPE)
endif

include $(shell cocotb-config --makefiles)/Makefile.sim


