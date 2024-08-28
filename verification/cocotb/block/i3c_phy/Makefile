# Copyright (C) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i3c_phy

SIMFILE = $(TEST_DIR)/i3cPHYsim_$(SIM)

VERILOG_SOURCES  = \
    $(SRC_DIR)/phy/i3c_phy.sv

RTL_TB_SOURCES = \
    $(SRC_DIR)/phy/i3c_io.sv \
	$(TEST_DIR)/i3c_phy_tb.sv

include $(TEST_DIR)/../block_common.mk

icarus-test:
	iverilog -g2012 -o $(SIMFILE) $(EXTRA_ARGS) $(VERILOG_SOURCES) $(RTL_TB_SOURCES)
	$(SIMFILE)

verilator-test:
	verilator -cc --timing --binary -o $(SIMFILE) $(EXTRA_ARGS) $(VERILOG_SOURCES) $(RTL_TB_SOURCES)
	$(SIMFILE)

.PHONY: iverilog-test verilator-test
