# SPDX-License-Identifier: Apache-2.0

TOPLEVEL_LANG    = verilog
SIM             ?= verilator
WAVES           ?= 1
TRACK_FSM       ?= 1

# Paths
CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
CFGDIR :=
CONFIG :=
$(info From common.mk, CURDIR is $(CURDIR))

# Set pythonpath so that tests can access common modules
export PYTHONPATH := $(PYTHONPATH):$(CURDIR)/common

# Add empty file to common sources to enforce configuration build before running the tests
COMMON_SOURCES += $(TEST_DIR)/sim_build/i3c_config.vh

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

COMPILE_ARGS += +define+DIGITAL_IO_I3C

ifeq ($(SIM), verilator)
    # Enable processing of #delay statements
    COMPILE_ARGS += --timing
    COMPILE_ARGS += -Wall -Wno-fatal
    COMPILE_ARGS += --x-assign unique --x-initial unique

    ifeq ($(WAVES), 1)
        EXTRA_ARGS += --trace --trace-structs --trace-fst
    endif
    EXTRA_ARGS += $(VERILATOR_COVERAGE)
    EXTRA_ARGS += -Wno-DECLFILENAME -Wno-TIMESCALEMOD
endif

# Switch between Verdi FSDB PLI and "classic" waveform dumping
VERDI_PLI ?= 1

ifeq ($(SIM), vcs)
    COMPILE_ARGS += -assert svaext
    COMPILE_ARGS += -Xcflags='-Wno-error=implicit-function-declaration -Wno-error=int-conversion'
    ifeq ($(VERDI_PLI), 1)
        COMPILE_ARGS += -P $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a
    else
        COMPILE_ARGS += -debug_access+all
    COMPILE_ARGS += -kdb +vcs+fsdbon
    endif
    ifeq ($(WAVES), 1)
        # Sim args seem to work for both wave dumping types (?)
    SIM_ARGS += +fsdbfile+dump.fsdb +fsdb+all=on +fsdb+mda=on
    endif
    EXTRA_ARGS += +vcs+lic+wait

    # Opt-in FSM state transition logging: make ... TRACK_FSM=1
    ifneq ($(TRACK_FSM),)
        COMPILE_ARGS += +define+TRACK_FSM_TRANSITIONS
    endif

    ifneq ($(COVERAGE_TYPE),)
        EXTRA_ARGS += -cm line+cond+fsm+tgl+branch -lca
    endif
endif

ifeq ($(SIM), xcelium)
    ifeq ($(WAVES), 1)
        SIM_ARGS += -input "@database -open cocotb_waves -default"
        SIM_ARGS += -input "@probe -database cocotb_waves -create $(TOPLEVEL) -all -depth all"
        SIM_ARGS += -input "@run" -input "@exit"
    endif
endif

COCOTB_HDL_TIMEUNIT         = 1ns
COCOTB_HDL_TIMEPRECISION    = 1fs ## we need 1fs resolution to handle 333MHz clocks

# Build directory
comma := ,
ifneq ($(COVERAGE_TYPE),)
    # Check if more than one test is provided
    ifeq ($(findstring $(comma),$(MODULE)),$(comma))
        ifneq ($(SIM), vcs)
            # Non-VCS sims need a unique SIM_BUILD per test to avoid overwriting coverage data.
            $(error Collecting coverage for multiple tests is not supported with $(SIM). Either unset 'COVERAGE_TYPE' to run tests without coverage reporting or use nox.)
        else
            SIM_BUILD := sim_build-$(COVERAGE_TYPE)
        endif
    else
        # Construct a unique directory for each test and coverage type
        SIM_BUILD := sim_build-$(MODULE)-$(COVERAGE_TYPE)
    endif
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

ifeq ($(SIM), vcs)

.PHONY: convert-vpd2vcd
convert-vpd2vcd: $(COCOTB_RESULTS_FILE)
	vpd2vcd -full64 dump.vpd dump.vcd +splitpacked

all: sim convert-vpd2vcd

endif

CFG_FILE ?= $(I3C_ROOT_DIR)/i3c_core_configs.yaml## Path: YAML file holding configuration of the I3C RTL
CFG_NAME ?= axi## Valid configuration name from the YAML configuration file

$(TEST_DIR)/sim_build/i3c_config.vh:
	pushd $(I3C_ROOT_DIR) && CFG_FILE=$(CFG_FILE) CFG_NAME=$(CFG_NAME) make config && popd
	mkdir -p $(TEST_DIR)/sim_build
	touch $(TEST_DIR)/sim_build/i3c_config.vh
