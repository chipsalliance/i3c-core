# Copyright (C) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src/ctrl)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i3c_ctrl

VERILOG_SOURCES  = \
    $(SRCDIR)/../hci/hci_pkg.sv \
    $(SRCDIR)/i2c_pkg.sv \
    $(SRCDIR)/i2c_controller_fsm.sv \
    $(SRCDIR)/i2c_controller_shim.sv \
    $(SRCDIR)/i3c_ctrl_pkg.sv \
    $(SRCDIR)/i3c_ctrl.sv

include $(CURDIR)/../common.mk
