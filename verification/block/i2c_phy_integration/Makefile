# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i2c_phy_integration

VERILOG_SOURCES  = \
    $(SRCDIR)/i2c/i2c_pkg.sv \
    $(SRCDIR)/i2c/i2c_fsm.sv \
    $(SRCDIR)/phy/i3c_io.sv \
    $(SRCDIR)/phy/i3c_phy.sv \
    $(SRCDIR)/prim/dff_2sync.sv \
    $(SRCDIR)/i2c_phy_integration.sv

include $(CURDIR)/../common.mk
