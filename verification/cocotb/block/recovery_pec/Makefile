# Copyright (C) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = recovery_pec

VERILOG_SOURCES  = \
    $(SRC_DIR)/recovery/recovery_pec.sv

include $(TEST_DIR)/../block_common.mk
