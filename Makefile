# Copyright (c) 2024 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

SHELL = /bin/bash
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(ROOT_DIR)/src
SW_DIR := $(ROOT_DIR)/sw
VERIFICATION_DIR := $(ROOT_DIR)/verification/block
TOOL_VERIFICATION_DIR := $(ROOT_DIR)/verification/tools
THIRD_PARTY_DIR = $(ROOT_DIR)/third_party
BUILD_DIR = $(ROOT_DIR)/build
SW_BUILD_DIR = $(BUILD_DIR)/sw
CALIPTRA_ROOT ?= $(THIRD_PARTY_DIR)/caliptra-rtl

ifeq (, $(shell which qrun))
else
QUESTA_ROOT = $(abspath $(dir $(shell which qrun))../)
endif

ifeq (, $(shell which vcs))
else
VCS = $(shell which vcs)
endif

UVM_VSEQ_TEST ?= i2c_host_stress_all_vseq

export CALIPTRA_ROOT

# Ensure `make test` is called with `TEST` flag set
ifeq ($(MAKECMDGOALS), test)
    ifndef TEST
    $(error Run this target with the `TEST` flag set, i.e. 'TEST=i3c_ctrl make test')
    endif
endif

#
# Source code lint and format
#
lint: lint-rtl lint-tests ## Run RTL and tests lint

lint-check: lint-rtl ## Run RTL lint and check lint on tests source code without fixing errors
	cd $(VERIFICATION_DIR) && nox -R -s test_lint

lint-rtl: ## Run lint on RTL source code
	$(SHELL) tools/verible-scripts/run.sh

lint-tests: ## Run lint on tests source code
	cd $(VERIFICATION_DIR) && nox -R -s lint

#
# RTL tests
#
test: ## Run single module test (use `TEST=<test_name>` flag)
	cd $(VERIFICATION_DIR) && nox -R -s $(TEST)_verify

tests: ## Run all RTL tests
	cd $(VERIFICATION_DIR) && nox -R -k "verify"

#
# Tool tests
#
tool-tests: ## Run all tool tests
	cd $(TOOL_VERIFICATION_DIR) && nox -k "verify"

#
# Software tests
#
$(SW_BUILD_DIR):
	mkdir -p $(SW_BUILD_DIR)

sw-caliptra-test: | $(SW_BUILD_DIR) ## Run Caliptra I3C software test
	debug=$(DEBUG) TESTNAME=smoke_test_i3c $(MAKE) -C $(SW_BUILD_DIR) -f $(CALIPTRA_ROOT)/tools/scripts/Makefile verilator

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

#
# Utilities
#
parse-config: deps ## Generate tool-specific arguments from a common configuration
	python tools/i3c_config/i3c_core_config.py default i3c_core_configs.yaml svh_file

timings: deps ## Generate values for I2C/I3C timings
	python tools/timing/timing.py

deps: ## Install python dependencies
	pip install -r requirements.txt

ifdef QUESTA_ROOT
uvm-test-questa: ## Run I2C UVM_VSEQ_TEST sequence in Questa
	mkdir -p questa_run
	$(QUESTA_ROOT)/linux_x86_64/qrun -optimize \
	+define+VW_QSTA \
	+incdir+$(QUESTA_ROOT)/verilog_src/uvm-1.2/src/ \
	-sv -timescale 1ns/1ps \
	-outdir questa_run/qrun.out \
	-uvm -uvmhome $(QUESTA_ROOT)/verilog_src/uvm-1.2 \
	-mfcu -f verification/uvm_i2c/dv_i2c_sim.scr \
	-uvmexthome $(QUESTA_ROOT)/verilog_src/questa_uvm_pkg-1.2 \
	-top i2c_bind \
	-top sec_cm_prim_onehot_check_bind \
	-top tb \
	-voptargs="+acc=nr"
	$(QUESTA_ROOT)/linux_x86_64/qrun -simulate  \
	+cdc_instrumentation_enabled=1 \
	+UVM_NO_RELNOTES +UVM_VERBOSITY=UVM_LOW \
	-outdir questa_run/qrun.out \
	-sv_seed 55439844359 \
	-suppress vsim-8323 \
	-permit_unmatched_virtual_intf \
	-64 \
	+UVM_TESTNAME=i2c_base_test \
	+UVM_TEST_SEQ=$(UVM_VSEQ_TEST) \
	-do verification/uvm_i2c/questa_sim.tcl
endif

ifdef VCS
uvm-test-vcs: ## Run I2C UVM_VSEQ_TEST sequence in VCS
	mkdir -p vcs_run
	vcs -sverilog -full64 -licqueue -ntb_opts uvm-1.2 -timescale=1ns/1ps \
	-Mdir=vcs_run/simv.csrc -o vcs_run/i2c_uvm_test \
	-f verification/uvm_i2c/dv_i2c_sim.scr \
	-lca -top i2c_bind -top sec_cm_prim_onehot_check_bind -top tb \
	+warn=SV-NFIVC +warn=noUII-L +warn=noLCA_FEATURES_ENABLED +warn=noBNA \
	-assert svaext \
	-xlrm uniq_prior_final \
	-CFLAGS --std=c99 -CFLAGS -fno-extended-identifiers -CFLAGS --std=c++11 \
	-LDFLAGS -Wl,--no-as-needed -debug_region=cell+lib -debug_access+f \
	+define+VCS \
	-error=IPDW -error=UPF_ISPND -error=IGPA -error=PCSRMIO -error=AOUP \
	-error=ELW_UNBOUND -error=IUWI -error=INAV -error=SV-ISC -error=OSVF-NPVIUFPI \
	-error=DPIMI -error=IPDASP -error=CM-HIER-FNF -error=CWUC -error=MATN \
	-error=STASKW_NDTAZ1 -error=TMPO -error=SV-OHCM -error=ENUMASSIGN -error=TEIF \
	-deraceclockdata -assert novpi+dbgopt
	./vcs_run/i2c_uvm_test -l vcs.log -licqueue -ucli \
	-assert nopostproc -do verification/uvm_i2c/vcs_sim.tcl \
	+UVM_TESTNAME=i2c_base_test +UVM_TEST_SEQ=$(UVM_VSEQ_TEST)
endif

clean: ## Clean all generated sources
	$(RM) -rf $(VERIFICATION_DIR)/**/{sim_build,*.log,*.xml,*.vcd}
	$(RM) -f $(VERIFICATION_DIR)/**/*sim*
	$(RM) -f *.log *.rpt
	$(RM) -rf $(BUILD_DIR)

.PHONY: lint lint-check lint-rtl lint-tests test tests sw-caliptra-test generate generate-example deps parse-config timings clean


.DEFAULT_GOAL := help
HELP_COLUMN_SPAN = 11
HELP_FORMAT_STRING = "\033[36m%-$(HELP_COLUMN_SPAN)s\033[0m %s\n"
help: ## Show this help message
	@echo List of available targets:
	@grep -hE '^[^#[:blank:]]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf $(HELP_FORMAT_STRING), $$1, $$2}'
	@echo
	@echo List of available optional parameters:
	@echo -e "\033[36mTEST\033[0m        Name of the test run by 'make test' (default: None)"
