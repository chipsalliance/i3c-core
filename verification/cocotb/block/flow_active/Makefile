# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

.PHONY: $(TEST_DIR)/sim_build/i3c_config.vh

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = test_wrapper

override CFG_NAME = axi_hc

override PLUSARGS := $(strip +FrontendBusInterface=AXI $(PLUSARGS))
COMPILE_ARGS += +define+I3C_USE_AXI

VERILOG_SOURCES += \
    $(SRC_DIR)/i3c_pkg.sv \
    $(SRC_DIR)/csr/I3CCSR_pkg.sv \
    $(SRC_DIR)/csr/I3CCSR.sv \
    $(SRC_DIR)/ctrl/controller_pkg.sv \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_count_pkg.sv \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_util_pkg.sv \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_pkg.sv \
    $(CALIPTRA_ROOT)/src/axi/rtl/axi_pkg.sv \
    $(CALIPTRA_ROOT)/src/axi/rtl/axi_if.sv \
    $(CALIPTRA_ROOT)/src/axi/rtl/axi_addr.v \
    $(CALIPTRA_ROOT)/src/libs/rtl/skidbuffer.v \
    $(SRC_DIR)/libs/axi_sub/i3c_axi_sub_arb.sv \
    $(SRC_DIR)/libs/axi_sub/i3c_axi_sub_rd.sv \
    $(SRC_DIR)/libs/axi_sub/i3c_axi_sub.sv \
    $(SRC_DIR)/libs/axi_sub/i3c_axi_sub_wr.sv \
    $(SRC_DIR)/libs/mem/prim_ram_1p_pkg.sv \
    $(SRC_DIR)/libs/mem/prim_generic_ram_1p.sv \
    $(SRC_DIR)/libs/mem/prim_ram_1p_adv.sv \
    $(SRC_DIR)/libs/mem/prim_ram_1p.sv \
    $(SRC_DIR)/ctrl/configuration.sv \
    $(SRC_DIR)/ctrl/flow_active.sv \
    $(SRC_DIR)/hci/axi_adapter.sv \
    $(SRC_DIR)/hci/queues/write_queue.sv \
    $(SRC_DIR)/hci/queues/read_queue.sv \
    $(SRC_DIR)/hci/queues.sv \
    $(SRC_DIR)/hci/csri.sv \
    $(SRC_DIR)/hci/dxt.sv \
    $(SRC_DIR)/hci/hci.sv \
    $(TEST_DIR)/../lib_flow_active/controller_active_flow_active.sv \
    $(TEST_DIR)/../lib_flow_active/controller_flow_active.sv \
    $(TEST_DIR)/../lib_flow_active/i3c_flow_active.sv \
    $(TEST_DIR)/../lib_flow_active/test_wrapper.sv \

include $(TEST_DIR)/../block_common.mk
