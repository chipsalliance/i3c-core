# SPDX-License-Identifier: Apache-2.0

VCS = vcs

BUILD_ARGS += +define+VERILATOR -full64 -sverilog
BUILD_ARGS += +libext+.sv +libext+.v
BUILD_ARGS += $(foreach dir,$(VERILOG_INCLUDE_DIRS),-y $(dir))
BUILD_ARGS += -debug_access+all +memcbk -timescale=1ns/1ps

vcs-build:
	$(VCS) $(BUILD_ARGS) -f $(I3C_ROOT_DIR)/src/i3c.f $(I3C_ROOT_DIR)/testbench/tb.sv

vcs-sim: vcs-build
	./simv +dumpon +vpdfile+dump.vpd && vpd2vcd -full64 dump.vpd dump.vcd +splitpacked
