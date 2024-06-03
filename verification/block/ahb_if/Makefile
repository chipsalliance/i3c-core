# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src/hci)

TEST_FILES   = $(sort $(wildcard test_*.py))

# Set appropriate bus interface via Cocotb's PLUSARGS:
export PLUSARGS="+FrontendBusInterface=AHB"

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = ahb_if_wrapper

VERILOG_SOURCES  = \
    $(CALIPTRA_ROOT)/src/libs/rtl/ahb_defines_pkg.sv \
    $(SRCDIR)/../csr/I3CCSR_pkg.sv \
    $(SRCDIR)/../csr/I3CCSR.sv \
    $(SRCDIR)/ahb_if.sv \
    $(CURDIR)/ahb_if/ahb_if_wrapper.sv

include $(CURDIR)/../common.mk