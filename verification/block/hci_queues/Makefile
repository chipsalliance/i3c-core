# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = hci_queues_wrapper

VERILOG_SOURCES  = \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_util_pkg.sv \
    $(CALIPTRA_ROOT)/src/libs/rtl/ahb_defines_pkg.sv \
    $(SRCDIR)/i3c_pkg.sv \
    $(SRCDIR)/csr/I3CCSR_pkg.sv \
    $(SRCDIR)/csr/I3CCSR.sv \
    $(SRCDIR)/hci/ahb_if.sv \
    $(SRCDIR)/hci/dxt.sv \
    $(SRCDIR)/hci/hci_pkg.sv \
    $(SRCDIR)/hci/hci_ctrl_queues.sv \
    $(SRCDIR)/hci/hci.sv \
    $(SRCDIR)/libs/mem/prim_ram_1p_pkg.sv \
    $(SRCDIR)/libs/mem/prim_generic_ram_1p.sv \
    $(SRCDIR)/libs/mem/prim_ram_1p.sv \
    $(SRCDIR)/libs/mem/prim_ram_1p_adv.sv \
    $(CURDIR)/hci_queues/hci_queues_wrapper.sv

include $(CURDIR)/../common.mk
export PYTHONPATH := $(PYTHONPATH):$(CURDIR)/ahb_if
