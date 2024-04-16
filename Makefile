# Copyright (c) 2024 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

SHELL = /bin/bash
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(ROOT_DIR)/src
SW_DIR := $(ROOT_DIR)/sw
VERIFICATION_DIR := $(ROOT_DIR)/verification/block
THIRD_PARTY_DIR = $(ROOT_DIR)/third_party
CALIPTRA_ROOT ?= $(THIRD_PARTY_DIR)/caliptra-rtl

export CALIPTRA_ROOT

# Ensure `make test` is called with `TEST` flag set
ifeq ($(MAKECMDGOALS), test)
    ifndef TEST
    $(error Run this target with the `TEST` flag set, i.e. 'TEST=i3c_ctrl make test')
    endif
endif

lint: lint-rtl lint-tests ## Run RTL and tests lint

lint-check: lint-rtl ## Run RTL lint and check lint on tests source code without fixing errors
	cd $(VERIFICATION_DIR) && nox -R -s test_lint

lint-rtl: ## Run lint on RTL source code
	$(SHELL) tools/verible-scripts/run.sh

lint-tests: ## Run lint on tests source code
	cd $(VERIFICATION_DIR) && nox -R -s lint

test: ## Run single module test (use `TEST=<test_name>` flag)
	cd $(VERIFICATION_DIR) && nox -R -s $(TEST)_verify

tests: ## Run all RTL tests
	cd $(VERIFICATION_DIR) && nox -R -k "verify"

clean: ## Clean all generated sources
	$(RM) -rf $(VERIFICATION_DIR)/**/{sim_build,*.log,*.xml,*.vcd}
	$(RM) -f $(VERIFICATION_DIR)/**/*sim*
	$(RM) -f *.log *.rpt

#
# SystemRDL
#
PEAKRDL_CFG := $(SRC_DIR)/rdl/peakrdl.toml
RDL_REGS := $(SRC_DIR)/rdl/registers.rdl
RDL_GEN_DIR := $(SRC_DIR)/csr/
export PEAKRDL_CFG
generate: deps ## Generate I3C SystemVerilog registers from SystemRDL definition
	python -m peakrdl regblock $(RDL_REGS) -o $(RDL_GEN_DIR) --cpuif passthrough
	python -m peakrdl c-header $(RDL_REGS) -o $(SW_DIR)/I3CCSR.h

generate-docs: deps ## Generate documentation from SystemRDL definition
	python -m peakrdl html $(RDL_REGS) -o $(RDL_GEN_DIR)/html/
	python -m peakrdl markdown $(RDL_REGS) -o $(RDL_GEN_DIR)/md/documentation.md

generate-example: deps ## Generate example SystemVerilog registers from SystemRDL definition
	python -m peakrdl regblock src/rdl/example.rdl -o $(RDL_GEN_DIR) --cpuif passthrough
	python -m peakrdl html src/rdl/example.rdl -o $(RDL_GEN_DIR)/html/

deps: ## Install python dependencies
	pip install -r requirements.txt

timings:
	python tools/timing/timing.py

.PHONY: lint lint-check lint-rtl lint-tests test tests generate generate-example deps


.DEFAULT_GOAL := help
HELP_COLUMN_SPAN = 11
HELP_FORMAT_STRING = "\033[36m%-$(HELP_COLUMN_SPAN)s\033[0m %s\n"
help: ## Show this help message
	@echo List of available targets:
	@grep -hE '^[^#[:blank:]]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf $(HELP_FORMAT_STRING), $$1, $$2}'
	@echo
	@echo List of available optional parameters:
	@echo -e "\033[36mTEST\033[0m        Name of the test run by 'make test' (default: None)"
