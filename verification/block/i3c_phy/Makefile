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

IVERILOG_SIMFILE = $(CURDIR)/i3c_phy/i3cPHYsim_iverilog
VERILATOR_SIMFILE = $(CURDIR)/i3c_phy/i3cPHYsim_verilator
PRIM_SV = $(wildcard $(SRCDIR)/prim/*.sv)

VERILOG_SOURCES  = \
    $(PRIM_SV) \
    $(SRCDIR)/phy/i3c_phy.sv

IVERILOG_SOURCES = \
    $(SRCDIR)/phy/i3c_io.sv \
	$(CURDIR)/i3c_phy/i3c_phy_tb.sv

include $(CURDIR)/../common.mk

iverilog-test:
	iverilog -g2012 -o $(IVERILOG_SIMFILE) $(VERILOG_SOURCES) $(IVERILOG_SOURCES)
	$(IVERILOG_SIMFILE)

verilator-test:
	verilator -cc --timing --binary --trace -o $(VERILATOR_SIMFILE) $(VERILOG_SOURCES) $(IVERILOG_SOURCES)
	$(VERILATOR_SIMFILE)

.PHONY: iverilog-test verilator-test
