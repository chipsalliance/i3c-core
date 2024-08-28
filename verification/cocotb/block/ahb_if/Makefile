# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

# Set appropriate bus interface via Cocotb's PLUSARGS:
export PLUSARGS="+FrontendBusInterface=AHB"

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = ahb_if_wrapper

VERILOG_SOURCES  = \
    $(CALIPTRA_ROOT)/src/libs/rtl/ahb_defines_pkg.sv \
    $(SRC_DIR)/csr/I3CCSR_pkg.sv \
    $(SRC_DIR)/csr/I3CCSR.sv \
    $(SRC_DIR)/hci/ahb_if.sv \
    $(TEST_DIR)/ahb_if_wrapper.sv

include $(TEST_DIR)/../block_common.mk