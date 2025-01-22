# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i3c_bus_monitor_wrapper

VERILOG_SOURCES  = \
    $(SRC_DIR)/i3c_pkg.sv \
    $(SRC_DIR)/ctrl/controller_pkg.sv \
    $(SRC_DIR)/ctrl/edge_detector.sv \
    $(SRC_DIR)/ctrl/stable_high_detector.sv \
    $(SRC_DIR)/ctrl/target_reset_detector.sv \
    $(SRC_DIR)/ctrl/bus_monitor.sv \
    $(SRC_DIR)/ctrl/i3c_bus_monitor.sv \
    i3c_bus_monitor_wrapper.sv

include $(TEST_DIR)/../block_common.mk
