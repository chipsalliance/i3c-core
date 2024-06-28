# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i3c_wrapper

EXTRA_ARGS += -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-PINCONNECTEMPTY -Wno-UNUSEDPARAM

VERILOG_SOURCES  = \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_assert.sv \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_assert_dummy_macros.svh \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_util_pkg.sv \
    $(CALIPTRA_ROOT)/src/libs/rtl/ahb_defines_pkg.sv \
    $(SRCDIR)/libs/axi/axi_pkg.sv \
    $(SRCDIR)/libs/axi/axi_if.sv \
    $(SRCDIR)/libs/axi/axi_sub_arb.sv \
    $(SRCDIR)/libs/axi/axi_sub_rd.sv \
    $(SRCDIR)/libs/axi/axi_sub.sv \
    $(SRCDIR)/libs/axi/axi_sub_wr.sv \
    $(SRCDIR)/libs/mem/prim_ram_1p_pkg.sv \
    $(SRCDIR)/libs/mem/prim_generic_ram_1p.sv \
    $(SRCDIR)/libs/mem/prim_ram_1p_adv.sv \
    $(SRCDIR)/libs/mem/prim_ram_1p.sv \
    $(SRCDIR)/csr/I3CCSR_pkg.sv \
    $(SRCDIR)/hci/hci_pkg.sv \
    $(SRCDIR)/ctrl/controller_pkg.sv \
    $(SRCDIR)/i3c_pkg.sv \
    $(SRCDIR)/phy/i3c_io.sv \
    $(SRCDIR)/phy/i3c_muxed_phy.sv \
    $(SRCDIR)/phy/i3c_phy_4to1_mux.sv \
    $(SRCDIR)/phy/i3c_phy.sv \
    $(SRCDIR)/csr/I3CCSR.sv \
    $(SRCDIR)/hci/queues/read_queue.sv \
    $(SRCDIR)/hci/queues/write_queue.sv \
    $(SRCDIR)/hci/ahb_if.sv \
    $(SRCDIR)/hci/axi_adapter.sv \
    $(SRCDIR)/hci/configuration.sv \
    $(SRCDIR)/hci/dxt.sv \
    $(SRCDIR)/hci/tti.sv \
    $(SRCDIR)/hci/queues.sv \
    $(SRCDIR)/hci/hci.sv \
    $(SRCDIR)/ctrl/bus_state.sv \
    $(SRCDIR)/ctrl/ccc.sv \
    $(SRCDIR)/ctrl/daa.sv \
    $(SRCDIR)/ctrl/i2c_controller_fsm.sv \
    $(SRCDIR)/ctrl/i2c_target_fsm.sv \
    $(SRCDIR)/ctrl/i3c_controller_fsm.sv \
    $(SRCDIR)/ctrl/bus_monitor.sv \
    $(SRCDIR)/ctrl/i3c_target_fsm.sv \
    $(SRCDIR)/ctrl/flow_active.sv \
    $(SRCDIR)/ctrl/flow_standby_i2c.sv \
    $(SRCDIR)/ctrl/flow_standby_i3c.sv \
    $(SRCDIR)/ctrl/controller_standby_i2c.sv \
    $(SRCDIR)/ctrl/controller_standby_i3c.sv \
    $(SRCDIR)/ctrl/controller_active.sv \
    $(SRCDIR)/ctrl/controller_standby.sv \
    $(SRCDIR)/ctrl/controller.sv \
    $(SRCDIR)/i3c.sv \
    $(SRCDIR)/i3c_wrapper.sv

EXTRA_ARGS += +define+I3C_USE_AHB

include $(CURDIR)/../common.mk
