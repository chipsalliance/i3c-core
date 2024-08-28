# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i3c_wrapper

EXTRA_ARGS += -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-PINCONNECTEMPTY -Wno-UNUSEDPARAM

VERILOG_SOURCES  = \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_assert.sv \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_assert_dummy_macros.svh \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_util_pkg.sv \
    $(CALIPTRA_ROOT)/src/libs/rtl/ahb_defines_pkg.sv \
    $(SRC_DIR)/libs/axi/axi_pkg.sv \
    $(SRC_DIR)/libs/axi/axi_if.sv \
    $(SRC_DIR)/libs/axi/axi_sub_arb.sv \
    $(SRC_DIR)/libs/axi/axi_sub_rd.sv \
    $(SRC_DIR)/libs/axi/axi_sub.sv \
    $(SRC_DIR)/libs/axi/axi_sub_wr.sv \
    $(SRC_DIR)/libs/mem/prim_ram_1p_pkg.sv \
    $(SRC_DIR)/libs/mem/prim_generic_ram_1p.sv \
    $(SRC_DIR)/libs/mem/prim_ram_1p_adv.sv \
    $(SRC_DIR)/libs/mem/prim_ram_1p.sv \
    $(SRC_DIR)/csr/I3CCSR_pkg.sv \
    $(SRC_DIR)/ctrl/controller_pkg.sv \
    $(SRC_DIR)/i3c_pkg.sv \
    $(SRC_DIR)/phy/i3c_io.sv \
    $(SRC_DIR)/phy/i3c_muxed_phy.sv \
    $(SRC_DIR)/phy/i3c_phy_4to1_mux.sv \
    $(SRC_DIR)/phy/i3c_phy.sv \
    $(SRC_DIR)/csr/I3CCSR.sv \
    $(SRC_DIR)/hci/queues/read_queue.sv \
    $(SRC_DIR)/hci/queues/write_queue.sv \
    $(SRC_DIR)/hci/ahb_if.sv \
    $(SRC_DIR)/hci/axi_adapter.sv \
    $(SRC_DIR)/hci/configuration.sv \
    $(SRC_DIR)/hci/dxt.sv \
    $(SRC_DIR)/hci/tti.sv \
    $(SRC_DIR)/hci/queues.sv \
    $(SRC_DIR)/hci/hci.sv \
    $(SRC_DIR)/ctrl/bus_state.sv \
    $(SRC_DIR)/ctrl/ccc.sv \
    $(SRC_DIR)/ctrl/daa.sv \
    $(SRC_DIR)/ctrl/i2c_controller_fsm.sv \
    $(SRC_DIR)/ctrl/i2c_target_fsm.sv \
    $(SRC_DIR)/ctrl/i3c_controller_fsm.sv \
    $(SRC_DIR)/ctrl/bus_monitor.sv \
    $(SRC_DIR)/ctrl/i3c_target_fsm.sv \
    $(SRC_DIR)/ctrl/flow_active.sv \
    $(SRC_DIR)/ctrl/flow_standby_i2c.sv \
    $(SRC_DIR)/ctrl/flow_standby_i3c.sv \
    $(SRC_DIR)/ctrl/controller_standby_i2c.sv \
    $(SRC_DIR)/ctrl/controller_standby_i3c.sv \
    $(SRC_DIR)/ctrl/controller_active.sv \
    $(SRC_DIR)/ctrl/controller_standby.sv \
    $(SRC_DIR)/ctrl/controller.sv \
    $(SRC_DIR)/i3c.sv \
    $(SRC_DIR)/i3c_wrapper.sv

EXTRA_ARGS += +define+I3C_USE_AHB

include $(TEST_DIR)/../block_common.mk
