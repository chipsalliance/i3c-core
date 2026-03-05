# Copyright (c) 2024 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

SHELL   = bash
PYTHON ?= python3

# Directory structure
I3C_ROOT_DIR        := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR             := $(I3C_ROOT_DIR)/src
VERIFICATION_DIR    := $(I3C_ROOT_DIR)/verification
THIRD_PARTY_DIR     := $(I3C_ROOT_DIR)/third_party

COCOTB_VERIF_DIR    := $(VERIFICATION_DIR)/cocotb
BLOCK_VERIF_DIR     := $(COCOTB_VERIF_DIR)/block
TOP_VERIF_DIR       := $(COCOTB_VERIF_DIR)/top
TOOL_VERIF_DIR      := $(VERIFICATION_DIR)/tools
UVM_VERIF_DIR       := $(VERIFICATION_DIR)/uvm_i3c
TESTPLAN_DIR        := $(VERIFICATION_DIR)/testplan

TOOL_DIR            := $(I3C_ROOT_DIR)/tools
UVM_TOOL_DIR        := $(TOOL_DIR)/uvm
GENERIC_UVM_DIR     := $(UVM_TOOL_DIR)/generic## Path: UVM installation directory
VERILATOR_UVM_DIR   := $(UVM_TOOL_DIR)/verilator## Path: UVM installation directory with Verilator patches

CALIPTRA_ROOT       ?= $(THIRD_PARTY_DIR)/caliptra-rtl## Path: caliptra-rtl repository

# TODO: Connect to version selection in tools/simulators/
UVM_DIR             ?= $(VERILATOR_UVM_DIR)/## Select UVM version
SIMULATOR           ?= verilator## Supported: verilator, dsim, questa, vcs

REPO_URL            ?= https://github.com/chipsalliance/i3c-core/tree/main/

# Path to directory with XMLs with tests' results
TESTS_RESULTS_DIR   ?= $(COCOTB_VERIF_DIR)
# Base directory present in "file" entries in XMLs with cocotb results
TESTS_XML_BASE_PATH ?= $(I3C_ROOT_DIR)

NOX                 ?= $(PYTHON) -m nox $(NOX_COMMON_ARGS) $(NOX_EXTRA_ARGS)
## The python environment is managed outside of Nox, so always pass these flags
NOX_COMMON_ARGS     ?= -R --no-venv
NOX_EXTRA_ARGS      ?=
COCOTB_NOXFILE      := $(COCOTB_VERIF_DIR)/noxfile.py
UVM_NOXFILE         := $(UVM_VERIF_DIR)/noxfile.py
TOOL_NOXFILE        := $(TOOL_VERIF_DIR)/noxfile.py


NUM_PROC            := $$(($$(nproc)-1))

# Environment variables
export I3C_ROOT_DIR
export CALIPTRA_ROOT
export SIMULATOR

# Include simulator makefiles (used by UVM tests)
include $(TOOL_DIR)/simulators/Makefile.$(SIMULATOR)

# Ensure `make test` is called with `TEST` flag set
ifeq ($(MAKECMDGOALS), test)
    ifndef TEST
    $(error Run this target with the `TEST` flag set, i.e. 'TEST=i3c_axi make test')
    endif
endif

################################################################################
#
# I3C configuration
#
# - The 'config' target builds any output collateral needed for the selected configuration
#   - This includes RTL headers files / defines and RDL
#   - This should be run before any other operations, and may leave in-tree untracked files
# - The 'config-print' target prints the selected config according to the variable selection

## Configuration generator tool
CFG_GEN   = $(TOOL_DIR)/i3c_config/i3c_core_config.py
## YAML file holding valid configuration sets for the I3C RTL
CFG_FILE ?= $(I3C_ROOT_DIR)/i3c_core_configs.yaml
## Selected configuration to use from CFG_FILE
CFG_NAME ?= ahb

config: config-rtl config-rdl ## Generate RDL and RTL configuration files

config-rtl: config-print ## Generate top I3C definitions .svh file
	$(PYTHON) $(CFG_GEN) $(CFG_NAME) $(CFG_FILE) svh_file --output-file $(SRC_DIR)/i3c_defines.svh

RDL_REGS    := $(SRC_DIR)/rdl/registers.rdl
RDL_GEN_DIR := $(SRC_DIR)/csr/
RDL_ARGS    := $(shell $(PYTHON) $(CFG_GEN) $(CFG_NAME) $(CFG_FILE) reg_gen_opts)

config-rdl: config-print
	$(PYTHON) $(TOOL_DIR)/reg_gen/reg_gen.py --input-file=$(RDL_REGS) --output-dir=$(RDL_GEN_DIR) $(RDL_ARGS) $(EXTRA_REG_GEN_ARGS)

config-print:
	@echo ""
	@echo "I3C configuration:         $(CFG_NAME)"
	@echo "I3C configuration file:    $(CFG_FILE)"
	@echo "RDL options:               $(RDL_ARGS)"
	@echo ""

################################################################################
#
# Source code lint and formatting
#

lint: lint-rtl lint-tests ## Run RTL and tests lint

lint-check: lint-rtl ## Run RTL lint and check lint on tests source code without fixing errors
	$(NOX) -f $(COCOTB_NOXFILE) -s test_lint

lint-rtl: ## Run lint on RTL source code
	$(SHELL) $(TOOL_DIR)/verible-scripts/run.sh

lint-tests: ## Run lint on tests source code
	$(NOX) -f $(COCOTB_NOXFILE) -s lint

lint-verilator:
	verilator --timing -Wall --lint-only -f $(I3C_ROOT_DIR)/src/i3c.f

build-verilator:
	verilator --timing -Wall --binary -f $(I3C_ROOT_DIR)/src/i3c.f

################################################################################
#
# Testplanning
#

BLOCKS_VERIFICATION_PLANS = $(shell find $(TESTPLAN_DIR) -type f -name "*.hjson" ! -name "target*.hjson" | sort)
CORE_VERIFICATION_PLANS = $(shell find $(TESTPLAN_DIR) -type f -name "*target*.hjson" | sort)
verification-docs:
	testplanner $(BLOCKS_VERIFICATION_PLANS) -ot $(TESTPLAN_DIR)/generated/testplans_blocks.md --project-root $(I3C_ROOT_DIR) --testplan-file-map $(TESTPLAN_DIR)/source-maps.yml --source-url-prefix $(REPO_URL)
	testplanner $(CORE_VERIFICATION_PLANS) -ot $(TESTPLAN_DIR)/generated/testplans_core.md --project-root $(I3C_ROOT_DIR) --testplan-file-map $(TESTPLAN_DIR)/source-maps.yml --source-url-prefix $(REPO_URL)

VERIFICATION_SIM_RESULTS_XMLS = $(shell find $(TESTS_RESULTS_DIR) -type f -name "*.xml" | sort)
cocotbxml-to-hjson-sim-results:
	cocotbxml-to-hjson -i $(VERIFICATION_SIM_RESULTS_XMLS) -t $(BLOCKS_VERIFICATION_PLANS) -o $(TESTS_RESULTS_DIR) --tests-base-dir $(TESTS_XML_BASE_PATH) --tests-ignore-dirs venv .venv .pyenv
	cocotbxml-to-hjson -i $(VERIFICATION_SIM_RESULTS_XMLS) -t $(CORE_VERIFICATION_PLANS) -o $(TESTS_RESULTS_DIR) --tests-base-dir $(TESTS_XML_BASE_PATH) --tests-ignore-dirs venv .venv .pyenv

BLOCKS_VERIFICATION_SIM_RESULTS = $(shell find $(TESTS_RESULTS_DIR) -type f -name "*.hjson" ! -name "target*.hjson" | sort)
CORE_VERIFICATION_SIM_RESULTS = $(shell find $(TESTS_RESULTS_DIR) -type f -name "*target*.hjson" | sort)
verification-docs-with-sim: cocotbxml-to-hjson-sim-results
	testplanner $(BLOCKS_VERIFICATION_PLANS) -s $(BLOCKS_VERIFICATION_SIM_RESULTS) -ot $(TESTPLAN_DIR)/generated/testplans_blocks.md -os $(TESTPLAN_DIR)/generated/sim-results --output-summary-title "Tests for individual blocks" --output-summary $(TESTPLAN_DIR)/generated/sim-results/index-blocks.html --project-root $(I3C_ROOT_DIR) --testplan-file-map $(TESTPLAN_DIR)/source-maps.yml --source-url-prefix $(REPO_URL)
	testplanner $(CORE_VERIFICATION_PLANS) -s $(CORE_VERIFICATION_SIM_RESULTS) -ot $(TESTPLAN_DIR)/generated/testplans_core.md -os $(TESTPLAN_DIR)/generated/sim-results --output-summary-title "Tests for the core" --output-summary $(TESTPLAN_DIR)/generated/sim-results/index-top.html --project-root $(I3C_ROOT_DIR) --testplan-file-map $(TESTPLAN_DIR)/source-maps.yml --source-url-prefix $(REPO_URL)
	cat $(TESTPLAN_DIR)/generated/sim-results/index-blocks.html $(TESTPLAN_DIR)/generated/sim-results/index-top.html > $(TESTPLAN_DIR)/generated/sim-results/index.html

################################################################################
#
# Tests
#

list-tests:
	$(NOX) -f $(COCOTB_NOXFILE) --list
	$(NOX) -f $(UVM_NOXFILE)    --list
	$(NOX) -f $(TOOL_NOXFILE)  --list

# COCOTB

# All tests map to the testplan, and are implemented as a Nox session named "$(TEST)_verify"
# Passing the testname as `TEST=<test_name>` will run all sub-testpoints associated with the test
#
test: config ## Run all testpoints for a single test (use `TEST=<test_name>` flag)
	$(MAKE) config CFG_NAME=$(CFG_NAME)
	$(NOX) -f $(COCOTB_NOXFILE) -s $(TEST)_verify

test-s: config
	$(MAKE) config CFG_NAME=$(CFG_NAME)
	$(NOX) -f $(COCOTB_NOXFILE) -s $(TEST)

tests: tests-axi tests-ahb ## Run all verification/cocotb/* RTL tests fro AHB and AXI bus configurations without coverage

tests-axi: ## Run all verification/cocotb/* RTL tests for AXI bus configuration without coverage
	$(MAKE) config CFG_NAME=axi
	$(NOX) -f $(COCOTB_NOXFILE) -t "axi"

tests-ahb: ## Run all verification/cocotb/* RTL tests for AHB bus configuration without coverage
	$(MAKE) config CFG_NAME=ahb
	$(NOX) -f $(COCOTB_NOXFILE) -t "ahb"

tests-i2c: ## Run all I2C tests without coverage
	$(MAKE) config CFG_NAME=ahb
	$(NOX) -f $(COCOTB_NOXFILE) -t "i2c"

# TODO: Enable full coverage flow
tests-coverage: ## Run all verification/block/* RTL tests with coverage
	cd $(COCOTB_VERIF_DIR) && BLOCK_COVERAGE_ENABLE=1 $(NOX) -k "verify"

# UVM

test-i3c-uvm-tag: config
	$(NOX) -f $(UVM_NOXFILE) -t $(TAG)

test-i3c-uvm-session: config
	$(NOX) -f $(UVM_NOXFILE) -s $(TEST)

test-i3c-vip-uvm: config ## Run single I3C VIP UVM test (use 'TEST=<i3c_driver|i3c_monitor>' flag)
	$(NOX) -f $(UVM_NOXFILE) -s $(TEST)

tests-i3c-vip-uvm: config ## Run all I3C VIP UVM tests
	$(NOX) -f $(UVM_NOXFILE) -s "i3c_verify_uvm"

tests-i3c-vip-uvm-debug: config ## Run debugging I3C VIP UVM tests
	$(NOX) -f $(UVM_NOXFILE) -t "uvm_debug_tests"

tests-uvm: config ## Run all I3C Core UVM tests
	$(NOX) -f $(UVM_NOXFILE) -s "i3c_core_verify_uvm"

tests-uvm-debug: config ## Run debugging I3C Core UVM tests
	$(NOX) -f $(UVM_NOXFILE) -t "i3c_core_uvm_debug_tests"

# Tools

tests-tool: ## Run all tool tests
	$(NOX) -f $(TOOL_NOXFILE) -k "verify"

################################################################################
#
# Misc & Utilities
#

print-timings: ## Generate values for I2C/I3C timings
	$(PYTHON) $(TOOL_DIR)/timing/timing.py

install-uvm:
	cd $(TOOL_DIR)/uvm/ && bash install-uvm.sh

clean: ## Clean all generated sources
	rm -rf $(I3C_ROOT_DIR)/{dsim.env,dsim_work,sw,*.log,*.rpt,*.vcd}
	rm -rf $(GENERIC_UVM_DIR) $(VERILATOR_UVM_DIR)
	rm -rf {$(VERIFICATION_DIR),$(COCOTB_VERIF_DIR),$(BLOCK_VERIF_DIR),$(TOP_VERIF_DIR),$(UVM_VERIF_DIR)}/**/{.nox,obj_dir,__pycache__,report,sim_build,*.dat,*.info,*.json,*.log,*.vpd,*.vcd,*.fsdb,*.fst,*.shm,*.xml,ucli.key,xrun.history}
	rm -rf $(TOOL_DIR)/**/{.nox,obj_dir,__pycache__,report,sim_build,*.dat,*.info,*.log,*.vcd,*.xml}

.PHONY: lint lint-check lint-rtl lint-tests \
        test tests \
        config config-rtl config-rdl config-print \
        clean config deps timings

.DEFAULT_GOAL := help
HELP_COLUMN_SPAN_NARROW   = 25
HELP_COLUMN_SPAN_WIDE     = 55
HELP_FORMAT_STRING_NARROW = "\033[36m%-$(HELP_COLUMN_SPAN_NARROW)s\033[0m %s\n"
HELP_FORMAT_STRING_WIDE   = "\033[36m%-$(HELP_COLUMN_SPAN_WIDE)s\033[0m %s\n"
help: ## Show this help message
	@echo List of available targets:
	@grep -hE '^[^#[:blank:]]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf $(HELP_FORMAT_STRING_NARROW), $$1, $$2}'
	@echo
	@echo List of overridable parameters:
	@grep -hE '^[[:print:]]*[[:blank:]]*\?=[[:print:]]*##[[:print:]]*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = "##"};{printf $(HELP_FORMAT_STRING_WIDE), $$1, $$2}'
	@echo
	@echo List of available optional parameters:
	@echo -e "\033[36mTEST\033[0m        Name of the test run by 'make test' (default: None)"
