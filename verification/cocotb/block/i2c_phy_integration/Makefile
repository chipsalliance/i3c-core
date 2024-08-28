# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i2c_phy_integration_wrapper

VERILOG_SOURCES  = \
    $(SRC_DIR)/ctrl/controller_pkg.sv \
    $(SRC_DIR)/ctrl/i2c_controller_fsm.sv \
    $(SRC_DIR)/phy/i3c_io.sv \
    $(SRC_DIR)/phy/i3c_phy.sv \
    $(SRC_DIR)/i2c_phy_integration.sv \
    $(TEST_DIR)/i2c_phy_integration_wrapper.sv

include $(TEST_DIR)/../block_common.mk
