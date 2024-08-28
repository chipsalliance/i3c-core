BLOCK_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export PYTHONPATH := $(PYTHONPATH):$(BLOCK_DIR)/lib_hci_queues:$(BLOCK_DIR)/lib_adapter

include $(BLOCK_DIR)/../common.mk
