# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i2c_controller_fsm

VERILOG_SOURCES  = \
    $(SRCDIR)/i2c/i2c_pkg.sv \
    $(SRCDIR)/i2c/i2c_controller_fsm.sv

include $(CURDIR)/../common.mk
