# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

# Set appropriate bus interface via Cocotb's PLUSARGS:
export PLUSARGS="+FrontendBusInterface=AXI"

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = axi_adapter_wrapper

VERILOG_SOURCES  = \
    $(SRCDIR)/i3c_pkg.sv \
    $(SRCDIR)/libs/axi/axi_pkg.sv \
    $(SRCDIR)/libs/axi/axi_if.sv \
    $(SRCDIR)/csr/I3CCSR_pkg.sv \
    $(SRCDIR)/csr/I3CCSR.sv \
    $(SRCDIR)/hci/axi_adapter.sv \
    $(CURDIR)/axi_adapter/axi_adapter_wrapper.sv

include $(CURDIR)/../common.mk