# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = bus_tx_test_wrapper

EXTRA_ARGS +=

VERILOG_SOURCES  = \
	$(SRC_DIR)/ctrl/bus_tx.sv \
	$(TEST_DIR)/bus_tx_test_wrapper.sv

include $(TEST_DIR)/../block_common.mk
