# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i2c_target_fsm_harness

EXTRA_ARGS += -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND

VERILOG_SOURCES  = \
    $(SRCDIR)/ctrl/controller_pkg.sv \
    $(SRCDIR)/ctrl/i2c_target_fsm.sv \
    $(CURDIR)/i2c_target_fsm/i2c_target_fsm_harness.sv

include $(CURDIR)/../common.mk
