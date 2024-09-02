# SPDX-License-Identifier: Apache-2.0

null  :=
space := $(null) #
comma := ,

CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRCDIR := $(abspath $(CURDIR)../../../../src)

TEST_FILES   = $(sort $(wildcard test_*.py))

MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))
TOPLEVEL     = bus_timers

VERILOG_SOURCES  = \
    $(SRCDIR)/ctrl/controller_pkg.sv \
    $(SRCDIR)/ctrl/bus_timers.sv \

include $(CURDIR)/../common.mk
