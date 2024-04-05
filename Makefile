# Copyright (c) 2024 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

SHELL = /bin/bash
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(ROOT_DIR)/src
VERIFICATION_DIR := $(ROOT_DIR)/verification/block

# Ensure `make test` is called with `TEST` flag set
ifeq ($(MAKECMDGOALS), test)
    ifndef TEST
    $(error Run this target with the `TEST` flag set, i.e. 'TEST=i3c_ctrl make test')
    endif
endif

lint: ## Run lint on RTL source code
	$(SHELL) tools/verible-scripts/run.sh

lint-tests: ## Run lint on tests source code
	cd $(VERIFICATION_DIR) && nox -R -s isort flake8 black

test: ## Run single module test (use `TEST=<test_name>` flag)
	cd $(VERIFICATION_DIR) && nox -R -s $(TEST)_verify

tests: ## Run all RTL tests
	cd $(VERIFICATION_DIR) && nox -R -k "verify"

clean:
	$(RM) -rf $(VERIFICATION_DIR)/**/{sim_build,*.log,*.xml,*.vcd}
	$(RM) -f *.log *.rpt

generate: deps ## Generate I3C SystemVerilog registers from SystemRDL definition

generate-example: deps ## Generate example SystemVerilog registers from SystemRDL definition
	python -m peakrdl regblock src/rdl/example.rdl -o src/rdl/generate/ --cpuif passthrough

deps: ## Install python dependencies
	pip install -r requirements.txt

.PHONY: lint lint-tests test tests generate deps

.DEFAULT_GOAL := help
HELP_COLUMN_SPAN = 11
HELP_FORMAT_STRING = "\033[36m%-$(HELP_COLUMN_SPAN)s\033[0m %s\n"
help: ## Show this help message
	@echo List of available targets:
	@grep -hE '^[^#[:blank:]]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf $(HELP_FORMAT_STRING), $$1, $$2}'
	@echo
	@echo List of available optional parameters:
	@echo -e "\033[36mTEST\033[0m        Name of the test run by 'make test' (default: None)"
