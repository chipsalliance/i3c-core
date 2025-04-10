# SPDX-License-Identifier: Apache-2.0

VCS = vcs
BUILD_DIR = $(I3C_ROOT_DIR)/testbench/build

BUILD_ARGS += +define+DIGITAL_IO_I3C -full64 -sverilog +lint=TFIPC-L
BUILD_ARGS += +libext+.sv +libext+.v
BUILD_ARGS += $(foreach dir,$(VERILOG_INCLUDE_DIRS),-y $(dir))
BUILD_ARGS += -debug_access+all +memcbk -timescale=1ns/1ps -assert svaext

SIM_ARGS += +dumpon
EXTRA_ARGS += +vcs+vcdpluson +vpdfile+dump.vpd +warn=noLINX_KRNL

ifneq ($(COVERAGE_TYPE),)
	EXTRA_ARGS += -cm line+cond+fsm+tgl+branch
endif

.PHONY: all vcs-build vcs-sim clean
all: vcs-sim

vcs-build:
	mkdir -p $(BUILD_DIR) && cd $(BUILD_DIR) && \
	$(VCS) $(BUILD_ARGS) $(EXTRA_ARGS) -f $(I3C_ROOT_DIR)/src/i3c_target.f $(I3C_ROOT_DIR)/testbench/tb.sv

vcs-sim: vcs-build
	$(BUILD_DIR)/simv $(SIM_ARGS) $(EXTRA_ARGS) && vpd2vcd -full64 dump.vpd dump.vcd +splitpacked

clean:
	rm -rf $(BUILD_DIR)
