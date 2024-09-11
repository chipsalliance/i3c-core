# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = hci_queues_wrapper

# Set appropriate bus interface via Cocotb's PLUSARGS:
export PLUSARGS="+FrontendBusInterface=AHB"

VERILOG_SOURCES  = \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_util_pkg.sv \
    $(CALIPTRA_ROOT)/src/libs/rtl/ahb_defines_pkg.sv \
    $(SRC_DIR)/i3c_pkg.sv \
    $(SRC_DIR)/csr/I3CCSR_pkg.sv \
    $(SRC_DIR)/csr/I3CCSR.sv \
    $(SRC_DIR)/hci/ahb_if.sv \
    $(SRC_DIR)/hci/dxt.sv \
    $(SRC_DIR)/hci/configuration.sv \
    $(SRC_DIR)/hci/queues/write_queue.sv \
    $(SRC_DIR)/hci/queues/read_queue.sv \
    $(SRC_DIR)/hci/tti.sv \
    $(SRC_DIR)/hci/queues.sv \
    $(SRC_DIR)/hci/hci.sv \
    $(SRC_DIR)/recovery/recovery_handler.sv \
    $(SRC_DIR)/libs/mem/prim_ram_1p_pkg.sv \
    $(SRC_DIR)/libs/mem/prim_generic_ram_1p.sv \
    $(SRC_DIR)/libs/mem/prim_ram_1p.sv \
    $(SRC_DIR)/libs/mem/prim_ram_1p_adv.sv \
    $(TEST_DIR)/hci_queues_wrapper.sv

include $(TEST_DIR)/../block_common.mk
