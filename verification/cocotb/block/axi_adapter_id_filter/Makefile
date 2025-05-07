# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

# Set appropriate bus interface via Cocotb's PLUSARGS:
override PLUSARGS := $(strip +FrontendBusInterface=AXI $(PLUSARGS))

MODULE  ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL = axi_adapter_wrapper
override CFG_NAME = axi
override CFG_FILE = $(TEST_DIR)/i3c_cfg.yaml

VERILOG_SOURCES  = \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_pkg.sv \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_util_pkg.sv \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_count_pkg.sv \
    $(SRC_DIR)/i3c_pkg.sv \
    $(CALIPTRA_ROOT)/src/axi/rtl/axi_pkg.sv \
    $(CALIPTRA_ROOT)/src/axi/rtl/axi_if.sv \
    $(CALIPTRA_ROOT)/src/axi/rtl/axi_addr.v \
    $(CALIPTRA_ROOT)/src/libs/rtl/skidbuffer.v \
    $(SRC_DIR)/libs/axi_sub/i3c_axi_sub_wr.sv \
    $(SRC_DIR)/libs/axi_sub/i3c_axi_sub_arb.sv \
    $(SRC_DIR)/libs/axi_sub/i3c_axi_sub_rd.sv \
    $(SRC_DIR)/libs/axi_sub/i3c_axi_sub.sv \
    $(SRC_DIR)/csr/I3CCSR_pkg.sv \
    $(SRC_DIR)/csr/I3CCSR.sv \
    $(SRC_DIR)/hci/axi_adapter.sv \
    $(TEST_DIR)/../lib_adapter/axi_adapter_wrapper.sv

include $(TEST_DIR)/../block_common.mk
