# Copyright (C) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i3c_phy_io_wrapper

include $(TEST_DIR)/../../caliptra_common.mk

VERILOG_SOURCES += \
	$(SRC_DIR)/phy/buf_pp.sv \
	$(SRC_DIR)/phy/bufs.sv \
	$(SRC_DIR)/phy/i3c_io.sv \
	$(SRC_DIR)/phy/i3c_phy.sv \
	$(TEST_DIR)/i3c_phy_io_wrapper.sv

include $(TEST_DIR)/../block_common.mk

.PHONY: iverilog-test verilator-test
