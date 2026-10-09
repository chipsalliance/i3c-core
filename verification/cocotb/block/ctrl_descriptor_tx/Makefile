# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = descriptor_tx_test_wrapper

VERILOG_SOURCES  = \
    $(SRC_DIR)/i3c_pkg.sv \
    $(SRC_DIR)/ctrl/descriptor_tx.sv \
    $(TEST_DIR)/descriptor_tx_test_wrapper.sv

include $(TEST_DIR)/../block_common.mk
