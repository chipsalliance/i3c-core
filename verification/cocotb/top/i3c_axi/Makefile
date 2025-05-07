# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)
FILELIST ?= $(I3C_ROOT_DIR)/src/i3c.f

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i3c_test_wrapper
override CFG_NAME = axi_bypass

# Set appropriate bus interface via Cocotb's PLUSARGS:
override PLUSARGS := $(strip +FrontendBusInterface=AXI $(PLUSARGS))

EXTRA_ARGS += -f $(FILELIST) $(I3C_ROOT_DIR)/verification/cocotb/top/lib_i3c_top/i3c_bus_harness.sv $(I3C_ROOT_DIR)/verification/cocotb/top/lib_i3c_top/i3c_test_wrapper.sv

include $(TEST_DIR)/../top_common.mk
