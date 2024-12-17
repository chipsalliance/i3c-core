# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i3c_target_fsm_test_wrapper

VERILOG_SOURCES  = \
    $(SRC_DIR)/i3c_pkg.sv \
    $(SRC_DIR)/ctrl/controller_pkg.sv \
    $(SRC_DIR)/ctrl/i3c_target_fsm.sv \
    $(TEST_DIR)/i3c_target_fsm_test_wrapper.sv

include $(TEST_DIR)/../block_common.mk
