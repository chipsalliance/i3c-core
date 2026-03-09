BLOCK_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export PYTHONPATH := $(PYTHONPATH):$(BLOCK_DIR)/lib_hci_queues:$(BLOCK_DIR)/lib_adapter

VERILOG_INCLUDE_DIRS= \
    $(CALIPTRA_ROOT)/src/libs/rtl \
    $(CALIPTRA_ROOT)/src/caliptra_prim/rtl \
    $(I3C_ROOT_DIR)/src \
    $(I3C_ROOT_DIR)/src/libs

include $(BLOCK_DIR)/../common.mk
