# Copyright (C) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = width_converter_8toN

VERILOG_SOURCES  = \
    $(SRC_DIR)/ctrl/width_converter_8toN.sv \

include $(TEST_DIR)/../block_common.mk
