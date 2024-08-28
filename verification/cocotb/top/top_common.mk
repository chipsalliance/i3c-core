TOP_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export PYTHONPATH := $(PYTHONPATH):$(TOP_DIR)/lib_i3c_top

include $(TOP_DIR)/../common.mk
