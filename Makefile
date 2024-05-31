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

VERILATOR_MAKE_FLAGS = OPT_FAST="-Os"
GENERIC_UVM_DIR ?= $(ROOT_DIR)/uvm-1.2
VERILATOR_UVM_DIR ?= $(ROOT_DIR)/verilator-uvm-1.2

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

ifdef DEBUG
VCS_DEBUG = -debug_access
VERILATOR_DEBUG = --trace --trace-structs
CALIPTRA_DEBUG = debug=1
endif

#
# I3C configuration
#
CFG_FILE ?= i3c_core_configs.yaml
CFG_NAME ?= default
CFG_GEN = $(ROOT_DIR)/tools/i3c_config/i3c_core_config.py

config: config-rtl config-rdl ## Generate RDL and RTL configuration files

config-rtl: config-print ## Generate top I3C definitions svh file
	python $(CFG_GEN) $(CFG_NAME) $(CFG_FILE) svh_file --output-file $(SRC_DIR)/i3c_defines.svh

RDL_REGS := $(SRC_DIR)/rdl/registers.rdl
RDL_GEN_DIR := $(SRC_DIR)/csr/
RDL_ARGS := $(shell python $(CFG_GEN) $(CFG_NAME) $(CFG_FILE) reg_gen_opts)

config-rdl: config-print
	python tools/reg_gen/reg_gen.py --input-file=$(RDL_REGS) --output-dir=$(RDL_GEN_DIR) $(RDL_ARGS)

config-print: ## Print configuration name, filename and RDL arguments
	@echo Using \'$(CFG_NAME)\' I3C configuration from \'$(CFG_FILE)\'.
	@echo Using RDL options: $(RDL_ARGS).

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

sw-caliptra-test: config | $(SW_BUILD_DIR) ## Generate I3CCSR.h and run Caliptra I3C software test
	TESTNAME=smoke_test_i3c $(MAKE) -C $(SW_BUILD_DIR) -f $(CALIPTRA_ROOT)/tools/scripts/Makefile $(CALIPTRA_DEBUG) verilator

#
# Utilities
#
timings: ## Generate values for I2C/I3C timings
	python tools/timing/timing.py

deps: ## Install python dependencies
	pip install -r requirements.txt

ifdef QUESTA_ROOT

ifeq ($(GUI),1)
ENABLE_GUI := "-gui"
else
ENABLE_GUI := ""
endif

define questa_run =
	mkdir -p questa_run
	$(QUESTA_ROOT)/linux_x86_64/qrun -optimize \
	+define+VW_QSTA \
	+incdir+$(QUESTA_ROOT)/verilog_src/uvm-1.2/src/ \
	-sv -timescale 1ns/1ps \
	-outdir questa_run/qrun.out \
	-uvm -uvmhome $(QUESTA_ROOT)/verilog_src/uvm-1.2 \
	-mfcu -f $(1) \
	-uvmexthome $(QUESTA_ROOT)/verilog_src/questa_uvm_pkg-1.2 \
	$(foreach top,$(2), -top $(top)) \
	-voptargs="+acc=nr" $(3)
	$(QUESTA_ROOT)/linux_x86_64/qrun -simulate  \
	+cdc_instrumentation_enabled=1 \
	+UVM_NO_RELNOTES +UVM_VERBOSITY=UVM_LOW \
	-outdir questa_run/qrun.out \
	-suppress vsim-8323 \
	-64 \
	+UVM_TESTNAME=$(5) \
	+UVM_TEST_SEQ=$(6) \
	-log questa_run/run.log \
	-do $(4) \
	$(7) $(ENABLE_GUI)
endef

uvm-test-questa: config ## Run I2C UVM_VSEQ_TEST sequence in Questa
	$(call questa_run, \
		verification/uvm_i2c/dv_i2c_sim.scr,\
		i2c_bind sec_cm_prim_onehot_check_bind tb,\
		,\
		verification/uvm_i2c/questa_sim.tcl\
		,i2c_base_test\
		,$(UVM_VSEQ_TEST))

i3c-monitor-tests:
	$(call questa_run,\
		verification/uvm_i3c/dv_i3c/i3c_test/i3c_sim.scr \
		verification/uvm_i3c/dv_i3c/i3c_test/tb_monitor.sv,\
		i3c_monitor_test_from_csv,,\
		verification/uvm_i3c/questa_sim.tcl,,\
		+CSV_FILE_PATH="$(PWD)/verification/uvm_i3c/dv_i3c/i3c_test/digital.csv")
	$(call questa_run,\
		verification/uvm_i3c/dv_i3c/i3c_test/i3c_sim.scr \
		verification/uvm_i3c/dv_i3c/i3c_test/tb_monitor.sv,\
		i3c_monitor_test_from_csv,,\
		verification/uvm_i3c/questa_sim.tcl,,\
		+CSV_FILE_PATH="$(PWD)/verification/uvm_i3c/dv_i3c/i3c_test/digital_with_ibi.csv")

i3c-driver-tests:
	$(call questa_run,\
		verification/uvm_i3c/dv_i3c/i3c_test/i3c_sim.scr \
		verification/uvm_i3c/dv_i3c/i3c_test/tb_driver.sv,\
		i3c_driver_test,+incdir+verification/uvm_i3c/dv_i3c/i3c_test/,\
		verification/uvm_i3c/questa_sim.tcl,,\
	)
endif

ifdef VCS
define vcs_run =
	mkdir -p vcs_run
	vcs -sverilog -full64 -licqueue -ntb_opts uvm-1.2 -timescale=1ns/1ps \
	-Mdir=vcs_run/simv.csrc -o vcs_run/vcs_test \
	-f $(1) \
	-lca $(foreach top,$(2), -top $(top)) \
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
	-deraceclockdata -assert novpi+dbgopt $(3)
	./vcs_run/vcs_test -l vcs.log -licqueue -ucli \
	-assert nopostproc -do $(4) \
	+UVM_TESTNAME=$(5) +UVM_TEST_SEQ=$(6) $(7)
endef

uvm-test-vcs: config ## Run I2C UVM_VSEQ_TEST sequence in VCS
	$(call vcs_run, \
		verification/uvm_i2c/dv_i2c_sim.scr,\
		i2c_bind sec_cm_prim_onehot_check_bind tb,\
		,\
		verification/uvm_i2c/vcs_sim.tcl\
		,i2c_base_test\
		,$(UVM_VSEQ_TEST))

i3c-monitor-tests:
	$(call vcs_run,\
		verification/uvm_i3c/dv_i3c/i3c_test/i3c_sim.scr,\
		i3c_monitor_test_from_csv,,\
		verification/uvm_i2c/vcs_sim.tcl,,\
		+CSV_FILE_PATH="$(PWD)/verification/uvm_i3c/dv_i3c/i3c_test/digital.csv")
	$(call vcs_run,\
		verification/uvm_i3c/dv_i3c/i3c_test/i3c_sim.scr,\
		i3c_monitor_test_from_csv,,\
		verification/uvm_i2c/vcs_sim.tcl,,\
		+CSV_FILE_PATH="$(PWD)/verification/uvm_i3c/dv_i3c/i3c_test/digital_with_ibi.csv")
endif

download-uvm-1.2:
	wget -O uvm-1.2.tar.gz https://www.accellera.org/images/downloads/standards/uvm/uvm-1.2.tar.gz
	tar -xf uvm-1.2.tar.gz
	rm -fr uvm-1.2.tar.gz
	touch download-uvm-1.2

uvm-verilator-build: download-uvm-1.2
	verilator --cc \
	          --main \
	          --timing \
	          --timescale 1ns/1ps \
	          --top-module i3c_monitor_test_from_csv \
	          -GCSV_FILE_PATH="$(PWD)/verification/uvm_i3c/dv_i3c/i3c_test/digital.csv" \
	          +incdir+$(GENERIC_UVM_DIR)/src \
	          --trace \
	          $(GENERIC_UVM_DIR)/src/uvm.sv \
	          -f verification/uvm_i3c/dv_i3c/i3c_test/i3c_sim.scr
	$(MAKE) -j -e -C obj_dir/ -f Vi3c_monitor_test_from_csv.mk $(VERILATOR_MAKE_FLAGS) VM_PARALLEL_BUILDS=1
	touch uvm-verilator-build

uvm-verilator: uvm-verilator-build ## Run I3C uvm agent test with verilator using generic UVM implementation
	./obj_dir/Vi3c_monitor_test_from_csv

download-verilator-uvm-1.2:
	wget -O verilator-uvm-1.2.zip https://github.com/antmicro/uvm-verilator/archive/refs/heads/current-patches.zip
	unzip verilator-uvm-1.2.zip
	rm -fr verilator-uvm-1.2.zip
	mv uvm-verilator-current-patches $(VERILATOR_UVM_DIR)
	touch download-verilator-uvm-1.2

verilator-uvm-verilator-build: download-verilator-uvm-1.2
	verilator --cc \
	          --main \
	          --timing \
	          --timescale 1ns/1ps \
	          --top-module i3c_monitor_test_from_csv \
	          -GCSV_FILE_PATH="$(PWD)/verification/uvm_i3c/dv_i3c/i3c_test/digital.csv" \
	          +incdir+$(VERILATOR_UVM_DIR)/src \
	          --trace \
	          $(VERILATOR_UVM_DIR)/src/uvm.sv \
	          -f verification/uvm_i3c/dv_i3c/i3c_test/i3c_sim.scr
	$(MAKE) -j -e -C obj_dir/ -f Vi3c_monitor_test_from_csv.mk $(VERILATOR_MAKE_FLAGS) VM_PARALLEL_BUILDS=1
	touch verilator-uvm-verilator-build

verilator-uvm-verilator: verilator-uvm-verilator-build ## Run I3C uvm agent test with verilator using verilator specific UVM implementation
	./obj_dir/Vi3c_monitor_test_from_csv

clean: ## Clean all generated sources
	$(RM) -rf $(VERIFICATION_DIR)/**/{sim_build,*.log,*.xml,*.vcd}
	$(RM) -f $(VERIFICATION_DIR)/**/*sim*
	$(RM) -f *.log *.rpt
	$(RM) -rf $(BUILD_DIR)
	$(RM) -rf vcs_run questa_run
	$(RM) -rf download-uvm-1.2 uvm-verilator-build download-verilator-uvm-1.2 verilator-uvm-verilator-build
	$(RM) -rf $(GENERIC_UVM_DIR) $(VERILATOR_UVM_DIR)

.PHONY: lint lint-check lint-rtl lint-tests \
		test tests sw-caliptra-test \
		config config-rtl config-rdl config-print  \
		clean config deps timings \
		uvm-verilator verilator-uvm-verilator

.DEFAULT_GOAL := help
HELP_COLUMN_SPAN = 11
HELP_FORMAT_STRING = "\033[36m%-$(HELP_COLUMN_SPAN)s\033[0m %s\n"
help: ## Show this help message
	@echo List of available targets:
	@grep -hE '^[^#[:blank:]]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf $(HELP_FORMAT_STRING), $$1, $$2}'
	@echo
	@echo List of available optional parameters:
	@echo -e "\033[36mTEST\033[0m        Name of the test run by 'make test' (default: None)"
