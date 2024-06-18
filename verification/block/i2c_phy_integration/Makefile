# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i2c_phy_integration_wrapper

VERILOG_SOURCES  = \
    $(SRCDIR)/ctrl/controller_pkg.sv \
    $(SRCDIR)/ctrl/i2c_controller_fsm.sv \
    $(SRCDIR)/phy/i3c_io.sv \
    $(SRCDIR)/phy/i3c_phy.sv \
    $(SRCDIR)/i2c_phy_integration.sv \
    $(CURDIR)/i2c_phy_integration/i2c_phy_integration_wrapper.sv

include $(CURDIR)/../common.mk
