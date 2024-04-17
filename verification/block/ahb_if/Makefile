# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src/hci)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = ahb_if

VERILOG_SOURCES  = \
    $(CALIPTRA_ROOT)/src/libs/rtl/ahb_defines_pkg.sv \
    $(SRCDIR)/../csr/I3CCSR_pkg.sv \
    $(SRCDIR)/../csr/I3CCSR.sv \
    $(SRCDIR)/ahb_if.sv

include $(CURDIR)/../common.mk
