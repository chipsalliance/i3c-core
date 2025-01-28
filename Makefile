# Copyright (c) 2024 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

SHELL = /bin/bash

# Directory structure
I3C_ROOT_DIR        := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

SRC_DIR             := $(I3C_ROOT_DIR)/src/
VERIFICATION_DIR    := $(I3C_ROOT_DIR)/verification/
THIRD_PARTY_DIR     := $(I3C_ROOT_DIR)/third_party/

COCOTB_VERIF_DIR    := $(VERIFICATION_DIR)/cocotb
BLOCK_VERIF_DIR     := $(COCOTB_VERIF_DIR)/block
TOP_VERIF_DIR       := $(COCOTB_VERIF_DIR)/top
TOOL_VERIF_DIR      := $(VERIFICATION_DIR)/tools/
UVM_VERIF_DIR       := $(VERIFICATION_DIR)/uvm_i3c/
TESTPLAN_DIR        := $(VERIFICATION_DIR)/testplan

TOOL_DIR            := $(I3C_ROOT_DIR)/tools/
UVM_TOOL_DIR        := $(TOOL_DIR)/uvm/
GENERIC_UVM_DIR     := $(UVM_TOOL_DIR)/generic/## Path: UVM installation directory
VERILATOR_UVM_DIR   := $(UVM_TOOL_DIR)/verilator/## Path: UVM installation directory with Verilator patches

CALIPTRA_ROOT       ?= $(THIRD_PARTY_DIR)/caliptra-rtl## Path: caliptra-rtl repository
# TODO: Connect to version selection in tools/simulators/
UVM_DIR             ?= $(VERILATOR_UVM_DIR)/## Select UVM version
SIMULATOR           ?= verilator## Supported: verilator, dsim, questa, vcs
REPO_URL            ?= https://github.com/chipsalliance/i3c-core/tree/main/

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
    $(error Run this target with the `TEST` flag set, i.e. 'TEST=i3c make test')
    endif
endif

#
# I3C configuration
#
CFG_FILE            ?= $(I3C_ROOT_DIR)/i3c_core_configs.yaml## Path: YAML file holding configuration of the I3C RTL
CFG_NAME            ?= ahb## Valid configuration name from the YAML configuration file
CFG_GEN              = $(TOOL_DIR)/i3c_config/i3c_core_config.py

config: config-rtl config-rdl ## Generate RDL and RTL configuration files

PYTHON ?= python3
config-rtl: config-print ## Generate top I3C definitions svh file
	$(PYTHON) $(CFG_GEN) $(CFG_NAME) $(CFG_FILE) svh_file --output-file $(SRC_DIR)/i3c_defines.svh

RDL_REGS    := $(SRC_DIR)/rdl/registers.rdl
RDL_GEN_DIR := $(SRC_DIR)/csr/
RDL_ARGS    := $(shell $(PYTHON) $(CFG_GEN) $(CFG_NAME) $(CFG_FILE) reg_gen_opts)

config-rdl: config-print
	$(PYTHON) $(TOOL_DIR)/reg_gen/reg_gen.py --input-file=$(RDL_REGS) --output-dir=$(RDL_GEN_DIR) $(RDL_ARGS) $(EXTRA_REG_GEN_ARGS)

config-print: ## Print configuration name, filename and RDL arguments
	@echo Using \'$(CFG_NAME)\' I3C configuration from \'$(CFG_FILE)\'.
	@echo Using RDL options: $(RDL_ARGS).

#
# Source code lint and format
#
lint: lint-rtl lint-tests ## Run RTL and tests lint

lint-check: lint-rtl ## Run RTL lint and check lint on tests source code without fixing errors
	cd $(COCOTB_VERIF_DIR) && $(PYTHON) -m nox -R -s test_lint --no-venv

lint-rtl: ## Run lint on RTL source code
	$(SHELL) $(TOOL_DIR)/verible-scripts/run.sh

lint-tests: ## Run lint on tests source code
	cd $(COCOTB_VERIF_DIR) && $(PYTHON) -m nox -R -s lint --no-venv

lint-verilator:
	verilator --timing -Wall --lint-only -f $(I3C_ROOT_DIR)/src/i3c.f

build-verilator:
	verilator --timing -Wall --binary -f $(I3C_ROOT_DIR)/src/i3c.f

#
# Tests
#
test: config ## Run single module test (use `TEST=<test_name>` flag)
	cd $(COCOTB_VERIF_DIR) && $(PYTHON) -m nox -R -s $(TEST)_verify --no-venv

tests-axi: ## Run all verification/cocotb/* RTL tests for AXI bus configuration without coverage
	$(MAKE) config CFG_NAME=axi
	cd $(COCOTB_VERIF_DIR) && $(PYTHON) -m nox -R -t "axi" --no-venv --forcecolor

tests-axi-ff: ## Run all verification/cocotb/* RTL tests for AXI bus configuration without coverage (input FF enabled)
	$(MAKE) config CFG_NAME=axi_ff
	cd $(COCOTB_VERIF_DIR) && $(PYTHON) -m nox -R -t "axi" --no-venv --forcecolor -- +MinSystemClockFrequency=200.0

tests-ahb: ## Run all verification/cocotb/* RTL tests for AHB bus configuration without coverage
	$(MAKE) config CFG_NAME=ahb
	cd $(COCOTB_VERIF_DIR) && $(PYTHON) -m nox -R -t "ahb" --no-venv --forcecolor

tests-ahb-ff: ## Run all verification/cocotb/* RTL tests for AHB bus configuration without coverage (input FF enabled)
	$(MAKE) config CFG_NAME=ahb_ff
	cd $(COCOTB_VERIF_DIR) && $(PYTHON) -m nox -R -t "ahb" --no-venv --forcecolor -- +MinSystemClockFrequency=200.0

tests: tests-axi tests-ahb ## Run all verification/cocotb/* RTL tests fro AHB and AXI bus configurations without coverage

# TODO: Enable full coverage flow
tests-coverage: ## Run all verification/block/* RTL tests with coverage
	cd $(COCOTB_VERIF_DIR) && BLOCK_COVERAGE_ENABLE=1 $(PYTHON) -m nox -R -k "verify" --no-venv

test-i3c-vip-uvm: config ## Run single I3C VIP UVM test with nox (use 'TEST=<i3c_driver|i3c_monitor>' flag)
	cd $(UVM_VERIF_DIR) && $(PYTHON) -m nox -R -s $(TEST) --no-venv

tests-i3c-vip-uvm: config ## Run all I3C VIP UVM tests with nox
	cd $(UVM_VERIF_DIR) && $(PYTHON) -m nox -R -s "i3c_verify_uvm" --no-venv

tests-i3c-vip-uvm-debug: config ## Run debugging I3C VIP UVM tests with nox
	cd $(UVM_VERIF_DIR) && $(PYTHON) -m nox -R -t "uvm_debug_tests" --no-venv

tests-uvm: config ## Run all I3C Core UVM tests with nox
	cd $(UVM_VERIF_DIR) && $(PYTHON) -m nox -R -s "i3c_core_verify_uvm" --no-venv

tests-uvm-debug: config ## Run debugging I3C Core UVM tests with nox
	cd $(UVM_VERIF_DIR) && $(PYTHON) -m nox -R -s "i3c_core_uvm_debug_tests" --no-venv

tests-tool: ## Run all tool tests
	cd $(TOOL_VERIF_DIR) && $(PYTHON) -m nox -k "verify" --no-venv

BLOCKS_VERIFICATION_PLANS = $(shell find $(TESTPLAN_DIR) -type f -name "*.hjson" ! -name "target*.hjson" -printf "%P\n")
CORE_VERIFICATION_PLANS = $(shell find $(TESTPLAN_DIR) -type f -name "*target*.hjson" -printf "%P\n")
verification-docs:
	cd $(TESTPLAN_DIR) && testplanner $(BLOCKS_VERIFICATION_PLANS) -ot $(TESTPLAN_DIR)/generated/testplans_blocks.md --project-root $(I3C_ROOT_DIR) --testplan-file-map $(TESTPLAN_DIR)/source-maps.yml --source-url-prefix $(REPO_URL)
	cd $(TESTPLAN_DIR) && testplanner $(CORE_VERIFICATION_PLANS) -ot $(TESTPLAN_DIR)/generated/testplans_core.md --project-root $(I3C_ROOT_DIR) --testplan-file-map $(TESTPLAN_DIR)/source-maps.yml --source-url-prefix $(REPO_URL)

#
# Utilities
#
timings: ## Generate values for I2C/I3C timings
	$(PYTHON) $(TOOL_DIR)/timing/timing.py

deps: ## Install python dependencies
	pip install -r $(I3C_ROOT_DIR)/requirements.txt

install-uvm:
	cd $(TOOL_DIR)/uvm/ && bash install-uvm.sh

clean: ## Clean all generated sources
	rm -rf $(I3C_ROOT_DIR)/{dsim.env,dsim_work,sw,*.log,*.rpt,*.vcd}
	rm -rf $(GENERIC_UVM_DIR) $(VERILATOR_UVM_DIR)
	rm -rf {$(VERIFICATION_DIR),$(COCOTB_VERIF_DIR),$(BLOCK_VERIF_DIR),$(TOP_VERIF_DIR),$(UVM_VERIF_DIR)}/**/{.nox,obj_dir,__pycache__,report,sim_build,*.dat,*.info,*.json,*.log,*.vcd,*.xml}
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
