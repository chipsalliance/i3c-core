# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = hci_queues_wrapper

# Set appropriate bus interface via Cocotb's PLUSARGS:
export PLUSARGS="+FrontendBusInterface=AXI"

VERILOG_SOURCES  = \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_util_pkg.sv \
    $(SRCDIR)/i3c_pkg.sv \
    $(SRCDIR)/csr/I3CCSR_pkg.sv \
    $(SRCDIR)/csr/I3CCSR.sv \
    $(SRCDIR)/libs/axi/axi_pkg.sv \
    $(SRCDIR)/libs/axi/axi_if.sv \
    $(SRCDIR)/hci/axi_adapter.sv \
    $(SRCDIR)/hci/dxt.sv \
    $(SRCDIR)/hci/hci_pkg.sv \
    $(SRCDIR)/hci/configuration.sv \
    $(SRCDIR)/hci/queues/write_queue.sv \
    $(SRCDIR)/hci/queues/read_queue.sv \
    $(SRCDIR)/hci/hci_ctrl_queues.sv \
    $(SRCDIR)/hci/hci.sv \
    $(SRCDIR)/libs/mem/prim_ram_1p_pkg.sv \
    $(SRCDIR)/libs/mem/prim_generic_ram_1p.sv \
    $(SRCDIR)/libs/mem/prim_ram_1p.sv \
    $(SRCDIR)/libs/mem/prim_ram_1p_adv.sv \
    $(CURDIR)/hci_queues_axi/hci_queues_wrapper.sv

include $(CURDIR)/../common.mk
