# SPDX-License-Identifier: Apache-2.0

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

comma := ,

# Per-test/seed output isolation via RUN_DIR
# Auto-generate a seed when the caller does not supply one so that every run
# gets an isolated output directory under sim_build/runs/.
# RUN_DIR can still be overridden explicitly on the make command line.
ifndef RANDOM_SEED
    RANDOM_SEED := $(shell python3 -c "import random,time; random.seed(time.time_ns()); print(random.randint(1,2**31-1))")
    $(info Auto-generated RANDOM_SEED=$(RANDOM_SEED))
endif
# Export so cocotb's recursive $(MAKE) in the 'sim' target inherits the same seed.
export RANDOM_SEED

ifneq ($(findstring $(comma),$(MODULE)),)
    RUN_DIR ?= sim_build/runs/all__$(RANDOM_SEED)
else
    RUN_DIR ?= sim_build/runs/$(MODULE)__$(RANDOM_SEED)
endif

COCOTB_RESULTS_FILE := $(RUN_DIR)/results.xml

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

ifeq ($(SIM), vcs)
    COMPILE_ARGS += -assert svaext
    COMPILE_ARGS += -Xcflags='-Wno-error=implicit-function-declaration -Wno-error=int-conversion'
    COMPILE_ARGS += -kdb
    COMPILE_ARGS += -debug_access+all +vcs+fsdbon
    ifeq ($(WAVES), 1)
        ifneq ($(RUN_DIR),)
            SIM_ARGS += +fsdbfile+$(RUN_DIR)/dump.fsdb +fsdb+all=on +fsdb+mda=on
        else
            SIM_ARGS += +fsdbfile+dump.fsdb +fsdb+all=on +fsdb+mda=on
        endif
    endif
    ifneq ($(RUN_DIR),)
        SIM_ARGS += -l $(RUN_DIR)/run.log
    endif
    EXTRA_ARGS += +vcs+lic+wait

    # Opt-in FSM state transition logging: make ... TRACK_FSM=1
    ifneq ($(TRACK_FSM),)
        COMPILE_ARGS += +define+TRACK_FSM_TRANSITIONS
    endif

    ifneq ($(COVERAGE_TYPE),)
        EXTRA_ARGS += -cm line+cond+fsm+tgl+branch -lca
        ifneq ($(RUN_DIR),)
            SIM_ARGS += -cm_dir $(RUN_DIR)/coverage
        endif
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

include $(shell python3 -m cocotb.config --makefiles)/Makefile.sim

# Ensure RUN_DIR exists before simulation writes outputs there
ifneq ($(RUN_DIR),)
$(COCOTB_RESULTS_FILE): | $(RUN_DIR)
$(RUN_DIR):
	mkdir -p $@
endif

# Collect stray logs into RUN_DIR after simulation completes.
# FSM tracker modules ($fopen) and VCS (novas*) write to CWD; move them.
ifneq ($(RUN_DIR),)
.PHONY: collect-run-logs
collect-run-logs: $(COCOTB_RESULTS_FILE)
	@for f in *_transitions.log *_transactions.log novas.fsdb novas_dump.log novas.rc; do \
	  if [ -e "$$f" ]; then mv -f "$$f" $(RUN_DIR)/; fi; \
	done

all: collect-run-logs
endif

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
CFG_NAME ?= axi## Valid configuration name from the YAML configuration file

$(TEST_DIR)/sim_build/i3c_config.vh:
	pushd $(I3C_ROOT_DIR) && CFG_FILE=$(CFG_FILE) CFG_NAME=$(CFG_NAME) make config && popd
	mkdir -p $(TEST_DIR)/sim_build
	touch $(TEST_DIR)/sim_build/i3c_config.vh
