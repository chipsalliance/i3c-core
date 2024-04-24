# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i3c_phy_integration_wrapper

VERILOG_SOURCES  = \
    $(CALIPTRA_ROOT)/src/libs/rtl/ahb_defines_pkg.sv \
    $(SRCDIR)/csr/I3CCSR_pkg.sv \
    $(SRCDIR)/csr/I3CCSR.sv \
    $(SRCDIR)/hci/ahb_if.sv \
    $(SRCDIR)/hci/hci.sv \
    $(SRCDIR)/hci/cmd_queue.sv \
    $(CURDIR)/ahb_if/ahb_if_wrapper.sv \
    $(SRCDIR)/ctrl/i2c_pkg.sv \
    $(SRCDIR)/ctrl/i2c_controller_fsm.sv \
    $(SRCDIR)/phy/i3c_phy.sv \
    $(SRCDIR)/phy/i3c_io.sv \
    $(SRCDIR)/i3c_pkg.sv \
    $(SRCDIR)/i3c.sv \
    $(CURDIR)/i3c/i3c_phy_integration_wrapper.sv

EXTRA_ARGS += +define+I3C_USE_AHB

include $(CURDIR)/../common.mk
