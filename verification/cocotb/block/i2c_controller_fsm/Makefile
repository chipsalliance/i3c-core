# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i2c_controller_fsm

VERILOG_SOURCES  = \
    $(SRC_DIR)/ctrl/controller_pkg.sv \
    $(SRC_DIR)/ctrl/i2c_controller_fsm.sv

include $(TEST_DIR)/../block_common.mk
