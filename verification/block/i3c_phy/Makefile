# Copyright (C) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i3c_phy

SIMFILE = $(CURDIR)/i3c_phy/i3cPHYsim_$(SIM)

VERILOG_SOURCES  = \
    $(SRCDIR)/phy/i3c_phy.sv

RTL_TB_SOURCES = \
    $(SRCDIR)/phy/i3c_io.sv \
	$(CURDIR)/i3c_phy/i3c_phy_tb.sv

include $(CURDIR)/../common.mk

icarus-test:
	iverilog -g2012 -o $(SIMFILE) $(EXTRA_ARGS) $(VERILOG_SOURCES) $(RTL_TB_SOURCES)
	$(SIMFILE)

verilator-test:
	verilator -cc --timing --binary -o $(SIMFILE) $(EXTRA_ARGS) $(VERILOG_SOURCES) $(RTL_TB_SOURCES)
	$(SIMFILE)

.PHONY: iverilog-test verilator-test
