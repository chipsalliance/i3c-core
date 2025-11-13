# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = bus_rx_flow_test_wrapper

EXTRA_ARGS +=

VERILOG_SOURCES  = \
	$(SRC_DIR)/libs/i3c_sva.svh \
	$(SRC_DIR)/ctrl/bus_rx_flow.sv \
	$(TEST_DIR)/bus_rx_flow_test_wrapper.sv

include $(TEST_DIR)/../block_common.mk
