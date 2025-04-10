# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = controller_standby_i2c_harness

VERILOG_SOURCES  = \
    $(SRC_DIR)/ctrl/controller_pkg.sv \
    $(SRC_DIR)/i3c_pkg.sv \
    ${SRC_DIR}/ctrl/i2c_target_fsm.sv \
    ${SRC_DIR}/ctrl/flow_standby_i2c.sv \
    ${SRC_DIR}/ctrl/controller_standby_i2c.sv \
    $(TEST_DIR)/controller_standby_i2c_harness.sv

include $(TEST_DIR)/../block_common.mk
