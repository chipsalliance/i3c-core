# SPDX-License-Identifier: Apache-2.0

# ---------------------------------------------------------------------------
# Optionally run the whole flow on the compute cluster.
#
# EDA licenses (e.g. Synopsys VCS) cannot be checked out on login nodes. Set
# CLUSTER=1 to re-exec the requested make goals on a compute node via the
# `submit` wrapper. This covers config build, RTL compile and simulation in a
# single cluster job.
#
# By default the scheduler is auto-detected. To force a scheduler or use a
# different wrapper entirely, override SUBMIT_CMD, e.g.
#
#   make MODULE=... TESTCASE=... SIM=vcs CLUSTER=1
#   make MODULE=... TESTCASE=... SIM=vcs CLUSTER=1 SUBMIT_CMD='submit -i -s lsf --'
#   make MODULE=... TESTCASE=... SIM=vcs CLUSTER=1 SUBMIT_CMD='bsub -Is'
# ---------------------------------------------------------------------------
CLUSTER    ?= 0
SUBMIT_CMD ?= submit -i --

ifeq ($(CLUSTER),1)

# Re-run on a compute node and skip local (cocotb) rule processing entirely.
.DEFAULT_GOAL := cluster-submit
.PHONY: cluster-submit $(MAKECMDGOALS)
$(MAKECMDGOALS): cluster-submit ;
cluster-submit:
	+$(SUBMIT_CMD) $(MAKE) $(MAKECMDGOALS) CLUSTER=0

else

TOPLEVEL_LANG    = verilog
SIM             ?= verilator
WAVES           ?= 0
TRACK_FSM       ?= 1

# Paths
CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
CFGDIR :=
CONFIG :=
$(info From common.mk, CURDIR is $(CURDIR))

# Set pythonpath so that tests can access common modules
export PYTHONPATH := $(PYTHONPATH):$(CURDIR)/common

# Compile the selected configuration first and retain it with each build.
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
    # Caliptra's full assertion set includes SVA unsupported by Verilator 5.024.
    COMPILE_ARGS += +define+I3C_ASSERT_ON
    # Enable processing of #delay statements
    COMPILE_ARGS += --timing --assert
    COMPILE_ARGS += -Wall -Wno-fatal
    COMPILE_ARGS += --x-assign unique --x-initial unique

    ifeq ($(WAVES), 1)
        EXTRA_ARGS += --trace --trace-structs --trace-fst
    endif
    EXTRA_ARGS += $(VERILATOR_COVERAGE)
    EXTRA_ARGS += -Wno-DECLFILENAME -Wno-TIMESCALEMOD
else
    COMPILE_ARGS += +define+CLP_ASSERT_ON
endif

ifeq ($(SIM), vcs)
    COMPILE_ARGS += -assert svaext
    COMPILE_ARGS += -Xcflags='-Wno-error=implicit-function-declaration -Wno-error=int-conversion'
    COMPILE_ARGS += -kdb
    COMPILE_ARGS += -debug_access+all +vcs+fsdbon
    ifeq ($(WAVES), 1)
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

CUSTOM_COMPILE_DEPS += $(I3C_ROOT_DIR)/verification/cocotb/common.mk $(TEST_DIR)/Makefile
CUSTOM_COMPILE_DEPS += $(I3C_ROOT_DIR)/src/i3c_defines.svh
CUSTOM_COMPILE_DEPS += $(I3C_ROOT_DIR)/src/csr/I3CCSR.sv $(I3C_ROOT_DIR)/src/csr/I3CCSR_pkg.sv
CUSTOM_COMPILE_DEPS += $(SIM_BUILD)/i3c_build_config.txt

include $(shell cocotb-config --makefiles)/Makefile.sim

export I3C_BUILD_FLAGS := $(COMPILE_ARGS)
export I3C_BUILD_EXTRA_FLAGS = $(EXTRA_ARGS)
export I3C_BUILD_SIM = $(SIM)
export I3C_BUILD_TOPLEVEL = $(TOPLEVEL)

ifeq ($(SIM), vcs)

.PHONY: convert-waves2vcd
convert-waves2vcd: $(COCOTB_RESULTS_FILE)
	@if [ -f dump.vpd ]; then \
		echo "Converting dump.vpd to dump.vcd..."; \
		vpd2vcd -full64 dump.vpd dump.vcd +splitpacked; \
	elif [ -f dump.fsdb ]; then \
		if command -v fsdb2vcd >/dev/null 2>&1; then \
			echo "Converting dump.fsdb to dump.vcd..."; \
			fsdb2vcd dump.fsdb -o dump.vcd; \
		else \
			echo "Warning: dump.fsdb found but fsdb2vcd not in PATH. Skipping VCD conversion."; \
		fi \
	fi

ifeq ($(WAVES), 1)
all: sim convert-waves2vcd
else
all: sim
endif

endif

CFG_FILE ?= $(I3C_ROOT_DIR)/i3c_core_configs.yaml## Path: YAML file holding configuration of the I3C RTL
CFG_NAME ?= axi_bypass## AXI integration profile; AHB benches override this explicitly

.PHONY: force-i3c-config-check
force-i3c-config-check:

$(TEST_DIR)/sim_build/i3c_config.vh: force-i3c-config-check
	@mkdir -p $(TEST_DIR)/sim_build $(SIM_BUILD)
	@$(PYTHON_BIN) $(I3C_ROOT_DIR)/tools/i3c_config/i3c_core_config.py $(CFG_NAME) $(CFG_FILE) svh_file --output-file $@.expected
	@if ! cmp -s $@.expected $(I3C_ROOT_DIR)/src/i3c_defines.svh || \
	    [ ! -f $(I3C_ROOT_DIR)/src/csr/I3CCSR.sv ] || \
	    [ ! -f $(I3C_ROOT_DIR)/src/csr/I3CCSR_pkg.sv ] || \
	    [ $(I3C_ROOT_DIR)/src/rdl/registers.rdl -nt $(I3C_ROOT_DIR)/src/csr/I3CCSR.sv ]; then \
	    $(MAKE) -C $(I3C_ROOT_DIR) config CFG_FILE=$(CFG_FILE) CFG_NAME=$(CFG_NAME); \
	fi
	@cmp $@.expected $(I3C_ROOT_DIR)/src/i3c_defines.svh
	@if ! cmp -s $@.expected $@; then cp $@.expected $@; fi
	@if ! cmp -s $@ $(SIM_BUILD)/i3c_defines.svh; then cp $@ $(SIM_BUILD)/i3c_defines.svh; fi
	@$(PYTHON_BIN) -c 'import os, sys; print("CFG_NAME=" + sys.argv[1]); print("CFG_FILE=" + sys.argv[2]); print("SIM=" + os.environ["I3C_BUILD_SIM"]); print("TOPLEVEL=" + os.environ["I3C_BUILD_TOPLEVEL"]); print("COMPILE_ARGS=" + os.environ["I3C_BUILD_FLAGS"]); print("EXTRA_ARGS=" + os.environ["I3C_BUILD_EXTRA_FLAGS"])' "$(CFG_NAME)" "$(abspath $(CFG_FILE))" > $(SIM_BUILD)/i3c_build_config.txt.expected
	@if ! cmp -s $(SIM_BUILD)/i3c_build_config.txt.expected $(SIM_BUILD)/i3c_build_config.txt; then mv $(SIM_BUILD)/i3c_build_config.txt.expected $(SIM_BUILD)/i3c_build_config.txt; else rm -f $(SIM_BUILD)/i3c_build_config.txt.expected; fi
	@cat $(SIM_BUILD)/i3c_build_config.txt $(SIM_BUILD)/i3c_defines.svh
	@rm -f $@.expected

$(SIM_BUILD)/i3c_build_config.txt: $(TEST_DIR)/sim_build/i3c_config.vh
	@test -f $@

$(I3C_ROOT_DIR)/src/i3c_defines.svh $(I3C_ROOT_DIR)/src/csr/I3CCSR.sv $(I3C_ROOT_DIR)/src/csr/I3CCSR_pkg.sv: | $(TEST_DIR)/sim_build/i3c_config.vh
	@test -f $@

endif # CLUSTER
