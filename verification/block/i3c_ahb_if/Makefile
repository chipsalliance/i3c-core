# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src/i3c_ahb_if)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = i3c_ahb_if

VERILOG_SOURCES  = \
    $(SRCDIR)/i3c_ahb_if_pkg.sv \
    $(SRCDIR)/i3c_ahb_if.sv \
    $(SRCDIR)/../rdl/generate/I3CCSR_pkg.sv \
    $(SRCDIR)/../rdl/generate/I3CCSR.sv \
    $(CALIPTRA_ROOT)/src/libs/rtl/ahb_defines_pkg.sv

include $(CURDIR)/../common.mk
