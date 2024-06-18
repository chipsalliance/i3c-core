# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i3c_test_wrapper

# VERILOG_SOURCES  =

EXTRA_ARGS += -f $(I3C_ROOT_DIR)/src/i3c.f i3c_test_wrapper.sv
# EXTRA_ARGS += +define+I3C_USE_AHB

include $(CURDIR)/../common.mk
