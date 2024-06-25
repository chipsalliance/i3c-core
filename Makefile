# Copyright (c) 2024 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

SHELL = /bin/bash
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
I3C_ROOT_DIR := $(ROOT_DIR)
export I3C_ROOT_DIR
SRC_DIR := $(ROOT_DIR)/src
VERIFICATION_DIR := $(ROOT_DIR)/verification/block
TOOL_VERIFICATION_DIR := $(ROOT_DIR)/verification/tools
THIRD_PARTY_DIR = $(ROOT_DIR)/third_party
BUILD_DIR = $(ROOT_DIR)/build
CALIPTRA_ROOT ?= $(THIRD_PARTY_DIR)/caliptra-rtl ## Path to caliptra-rtl repository
DOCS ?= $(THIRD_PARTY_DIR)/caliptra-rtl


VERILATOR_MAKE_FLAGS = OPT_FAST="-Os"
GENERIC_UVM_DIR ?= $(ROOT_DIR)/uvm-1.2 ## Path to UVM installation directory
VERILATOR_UVM_DIR ?= $(ROOT_DIR)/verilator-uvm-1.2 ## Path to UVM installation directory with Verilator patches

ifeq (, $(shell which qrun))
else
QUESTA_ROOT = $(abspath $(dir $(shell which qrun))../)
endif

ifeq (, $(shell which vcs))
else
VCS = $(shell which vcs)
endif

ifeq (, $(shell which dsim))
else
DSIM = $(shell which dsim)
DSIM_HOME = $(abspath $(dir $(shell which dsim))../)
endif

UVM_VSEQ_TEST ?= i2c_host_stress_all_vseq ## UVM Virtual test sequence to be run

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
endif

#
# I3C configuration
#
CFG_FILE ?= i3c_core_configs.yaml ## Path YAML configuration file used to configure the I3C RTL
CFG_NAME ?= ahb ## Valid configuration name from the YAML configuration file
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
	cd $(VERIFICATION_DIR) && python -m nox -R -s test_lint

lint-rtl: ## Run lint on RTL source code
	$(SHELL) tools/verible-scripts/run.sh

lint-tests: ## Run lint on tests source code
	cd $(VERIFICATION_DIR) && python -m nox -R -s lint

#
# RTL tests
#
test: config ## Run single module test (use `TEST=<test_name>` flag)
	cd $(VERIFICATION_DIR) && python -m nox -R -s $(TEST)_verify

tests: config ## Run all RTL tests
	cd $(VERIFICATION_DIR) && python -m nox -R -k "verify"

#
# Tool tests
#
tool-tests: ## Run all tool tests
	cd $(TOOL_VERIFICATION_DIR) && python -m nox -k "verify"

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
	-log questa_run/$(8)run.log \
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

i3c-monitor-tests-questa:
	$(call questa_run,\
		verification/uvm_i3c/dv_i3c/i3c_test/i3c_sim.scr \
		verification/uvm_i3c/dv_i3c/i3c_test/tb_monitor.sv,\
		i3c_monitor_test_from_csv,,\
		verification/uvm_i3c/questa_sim.tcl,,,\
		+CSV_FILE_PATH="$(PWD)/verification/uvm_i3c/dv_i3c/i3c_test/digital.csv",simple_I3C_transaction.)
	$(call questa_run,\
		verification/uvm_i3c/dv_i3c/i3c_test/i3c_sim.scr \
		verification/uvm_i3c/dv_i3c/i3c_test/tb_monitor.sv,\
		i3c_monitor_test_from_csv,,\
		verification/uvm_i3c/questa_sim.tcl,,,\
		+CSV_FILE_PATH="$(PWD)/verification/uvm_i3c/dv_i3c/i3c_test/digital_with_ibi.csv",IBI_I3C_transaction.)

i3c-driver-tests-questa:
	$(call questa_run,\
		verification/uvm_i3c/dv_i3c/i3c_test/i3c_sim.scr \
		verification/uvm_i3c/dv_i3c/i3c_test/tb_driver.sv,\
		i3c_driver_test,+incdir+verification/uvm_i3c/dv_i3c/i3c_test/,\
		verification/uvm_i3c/questa_sim.tcl,,\
	)
endif

# $1 - defining file
# $2 - top module(s)
# $3 - extra build args
# $4 - simulation script
# $5 - UVM_TESTNAME plusarg
# $6 - UVM_TEST_SEQ plusarg
# $7 - extra run args
# $8 - log file prefix
ifdef DSIM
define dsim_run =
	mkdir -p dsim_run
	DSIM_HOME=$(DSIM_HOME) dsim -sv +acc+b -uvm 1.2 -work dsim_run -genimage image \
	-f $(1) -timescale 1ns/1ps -all-class-spec -all-pkgs \
	$(foreach top,$(2), -top $(top)) -l dsim_run/$(8)dsim.build -j $$(nproc) $(3)
	DSIM_HOME=$(DSIM_HOME) dsim +acc+rwb -work dsim_run -uvm 1.2 -image image \
	-cov-db dsim_run/$(8)dsim_metrics.db \
	+UVM_TESTNAME=$(5) \
	+UVM_TEST_SEQ=$(6) \
	-l dsim_run/$(8)dsim.run $(7)
endef

uvm-test-dsim: config ## Run I2C UVM_VSEQ_TEST sequence in DSim
	$(call dsim_run, \
		verification/uvm_i2c/dv_i2c_sim.scr,\
		i2c_bind sec_cm_prim_onehot_check_bind tb,\
		,\
		verification/uvm_i2c/dsim_sim.tcl\
		,i2c_base_test\
		,$(UVM_VSEQ_TEST))

i3c-all-tests-dsim: i3c-monitor-tests-dsim i3c-driver-tests-dsim i3c-sequence-tests-dsim

i3c-monitor-tests-dsim:
	$(call dsim_run,\
		verification/uvm_i3c/dv_i3c/i3c_test/i3c_sim.scr \
		verification/uvm_i3c/dv_i3c/i3c_test/tb_monitor.sv,\
		i3c_monitor_test_from_csv,,\
		verification/uvm_i3c/dsim_sim.tcl,,,\
		+CSV_FILE_PATH="$(PWD)/verification/uvm_i3c/dv_i3c/i3c_test/digital.csv",simple_I3C_transaction.)
	$(call dsim_run,\
		verification/uvm_i3c/dv_i3c/i3c_test/i3c_sim.scr \
		verification/uvm_i3c/dv_i3c/i3c_test/tb_monitor.sv,\
		i3c_monitor_test_from_csv,,\
		verification/uvm_i3c/dsim_sim.tcl,,,\
		+CSV_FILE_PATH="$(PWD)/verification/uvm_i3c/dv_i3c/i3c_test/digital_with_ibi.csv",IBI_I3C_transaction.)

i3c-driver-tests-dsim:
	$(call dsim_run,\
		verification/uvm_i3c/dv_i3c/i3c_test/i3c_sim.scr \
		verification/uvm_i3c/dv_i3c/i3c_test/tb_driver.sv,\
		i3c_driver_test,+incdir+verification/uvm_i3c/dv_i3c/i3c_test/,\
		verification/uvm_i3c/dsim_sim.tcl,,\
	)

dsim_run/tb_sequence.%.dsim.run:
	$(call dsim_run,\
		verification/uvm_i3c/dv_i3c/i3c_test/i3c_sim.scr \
		verification/uvm_i3c/dv_i3c/i3c_test/tb_sequencer.sv\
		,tb\
		,\
		,verification/uvm_i3c/dsim_sim.tcl\
		,i3c_sequence_test\
		,$*\
		,\
		,tb_sequence.$*.)

tb_sequence.%.vcd:
	$(call dsim_run,\
		verification/uvm_i3c/dv_i3c/i3c_test/i3c_sim.scr \
		verification/uvm_i3c/dv_i3c/i3c_test/tb_sequencer.sv\
		,tb\
		,\
		,verification/uvm_i3c/dsim_sim.tcl\
		,i3c_sequence_test\
		,$*\
		,-waves $@\
		,tb_sequence.$*.)

i3c-sequence-tests-dsim: dsim_run/tb_sequence.direct_vseq.dsim.run
i3c-sequence-tests-dsim: dsim_run/tb_sequence.direct_with_rstart_vseq.dsim.run
i3c-sequence-tests-dsim: dsim_run/tb_sequence.broadcast_followed_by_data_vseq.dsim.run
i3c-sequence-tests-dsim: dsim_run/tb_sequence.broadcast_followed_by_data_with_rstart_vseq.dsim.run
i3c-sequence-tests-dsim: dsim_run/tb_sequence.direct_i2c_vseq.dsim.run
i3c-sequence-tests-dsim: dsim_run/tb_sequence.direct_i2c_with_rstart_vseq.dsim.run
i3c-sequence-tests-dsim: dsim_run/tb_sequence.broadcast_followed_by_i2c_data_vseq.dsim.run
i3c-sequence-tests-dsim: dsim_run/tb_sequence.broadcast_followed_by_i2c_data_with_rstart_vseq.dsim.run

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

i3c-monitor-tests-vcs:
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
	$(RM) -rf $(VERIFICATION_DIR)/**/{sim_build,obj_dir,__pycache__,*.log,*.xml,*.vcd}
	$(RM) -rf $(VERIFICATION_DIR)/__pycache__
	$(RM) -rf $(VERIFICATION_DIR)/.nox
	$(RM) -f $(VERIFICATION_DIR)/**/*sim*
	$(RM) -f *.log *.rpt
	$(RM) -rf $(BUILD_DIR)
	$(RM) -rf vcs_run questa_run dsim_run
	$(RM) -rf download-uvm-1.2 uvm-verilator-build download-verilator-uvm-1.2 verilator-uvm-verilator-build
	$(RM) -rf $(GENERIC_UVM_DIR) $(VERILATOR_UVM_DIR)

.PHONY: lint lint-check lint-rtl lint-tests \
		test tests sw-caliptra-test \
		config config-rtl config-rdl config-print  \
		clean config deps timings \
		uvm-verilator verilator-uvm-verilator

.DEFAULT_GOAL := help
HELP_COLUMN_SPAN_NARROW = 25
HELP_COLUMN_SPAN_WIDE = 51
HELP_FORMAT_STRING_NARROW = "\033[36m%-$(HELP_COLUMN_SPAN_NARROW)s\033[0m %s\n"
HELP_FORMAT_STRING_WIDE = "\033[36m%-$(HELP_COLUMN_SPAN_WIDE)s\033[0m %s\n"
help: ## Show this help message
	@echo List of available targets:
	@grep -hE '^[^#[:blank:]]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf $(HELP_FORMAT_STRING_NARROW), $$1, $$2}'
	@echo
	@echo List of overridable parameters:
	@grep -hE '^[[:print:]]*\?=[[:print:]]*##[[:print:]]*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = "##"};{printf $(HELP_FORMAT_STRING_WIDE), $$1, $$2}'
	@echo
	@echo List of available optional parameters:
	@echo -e "\033[36mTEST\033[0m        Name of the test run by 'make test' (default: None)"
