# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(abspath $(TEST_DIR)../../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = controller_standby_i2c_harness

EXTRA_ARGS += -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-PINCONNECTEMPTY -Wno-UNUSEDPARAM

VERILOG_SOURCES  = \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_assert.sv \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_assert_dummy_macros.svh \
    ${CALIPTRA_ROOT}/src/caliptra_prim/rtl/caliptra_prim_pkg.sv \
    ${CALIPTRA_ROOT}/src/caliptra_prim/rtl/caliptra_prim_util_pkg.sv \
    ${CALIPTRA_ROOT}/src/caliptra_prim/rtl/caliptra_prim_count_pkg.sv \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_util_pkg.sv \
    $(CALIPTRA_ROOT)/src/libs/rtl/ahb_defines_pkg.sv \
    $(CALIPTRA_ROOT)/src/axi/rtl/axi_pkg.sv \
    $(CALIPTRA_ROOT)/src/axi/rtl/axi_if.sv \
    $(SRC_DIR)/libs/axi_sub/i3c_axi_sub_wr.sv \
    $(SRC_DIR)/libs/axi_sub/i3c_axi_sub_arb.sv \
    $(SRC_DIR)/libs/axi_sub/i3c_axi_sub_rd.sv \
    $(SRC_DIR)/libs/axi_sub/i3c_axi_sub.sv \
    $(SRC_DIR)/libs/mem/prim_ram_1p_pkg.sv \
    $(SRC_DIR)/libs/mem/prim_generic_ram_1p.sv \
    $(SRC_DIR)/libs/mem/prim_ram_1p_adv.sv \
    $(SRC_DIR)/libs/mem/prim_ram_1p.sv \
    $(SRC_DIR)/csr/I3CCSR_pkg.sv \
    $(SRC_DIR)/ctrl/controller_pkg.sv \
    $(SRC_DIR)/i3c_pkg.sv \
    $(SRC_DIR)/phy/buf_pp.sv \
    $(SRC_DIR)/phy/bufs.sv \
    $(SRC_DIR)/phy/i3c_phy.sv \
    $(SRC_DIR)/csr/I3CCSR.sv \
    ${SRC_DIR}/hci/queues/read_queue.sv \
    ${SRC_DIR}/hci/queues/write_queue.sv \
    ${SRC_DIR}/hci/ahb_if.sv \
    ${SRC_DIR}/hci/axi_adapter.sv \
    ${SRC_DIR}/hci/dxt.sv \
    ${SRC_DIR}/hci/tti.sv \
    ${SRC_DIR}/hci/queues.sv \
    ${SRC_DIR}/hci/hci.sv \
    ${SRC_DIR}/ctrl/bus_monitor.sv \
    ${SRC_DIR}/ctrl/ibi.sv \
    ${SRC_DIR}/ctrl/bus_tx.sv \
    ${SRC_DIR}/ctrl/bus_tx_flow.sv \
    ${SRC_DIR}/ctrl/bus_rx_flow.sv \
    ${SRC_DIR}/ctrl/bus_timers.sv \
    ${SRC_DIR}/ctrl/target_reset_detector.sv \
    ${SRC_DIR}/ctrl/i3c_bus_monitor.sv \
    ${SRC_DIR}/ctrl/ccc.sv \
    ${SRC_DIR}/ctrl/configuration.sv \
    ${SRC_DIR}/ctrl/edge_detector.sv \
    ${SRC_DIR}/ctrl/descriptor_rx.sv \
    ${SRC_DIR}/ctrl/descriptor_tx.sv \
    ${SRC_DIR}/ctrl/descriptor_ibi.sv \
    ${SRC_DIR}/ctrl/i2c_controller_fsm.sv \
    ${SRC_DIR}/ctrl/i2c_target_fsm.sv \
    ${SRC_DIR}/ctrl/i3c_controller_fsm.sv \
    ${SRC_DIR}/ctrl/i3c_target_fsm.sv \
    ${SRC_DIR}/ctrl/flow_active.sv \
    ${SRC_DIR}/ctrl/flow_standby_i2c.sv \
    ${SRC_DIR}/ctrl/controller_standby_i2c.sv \
    ${SRC_DIR}/ctrl/controller_standby_i3c.sv \
    ${SRC_DIR}/ctrl/controller_active.sv \
    ${SRC_DIR}/ctrl/controller_standby.sv \
    ${SRC_DIR}/ctrl/controller.sv \
    ${SRC_DIR}/ctrl/stable_high_detector.sv \
    $(TEST_DIR)/controller_standby_i2c_harness.sv

EXTRA_ARGS += +define+I3C_USE_AHB

include $(TEST_DIR)/../block_common.mk
