TOP_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export PYTHONPATH := $(PYTHONPATH):$(TOP_DIR)/lib_i3c_top
PYTHONPATH := $(PYTHONPATH):$(TOP_DIR)/lib_i3c_top_controller
export PYTHONPATH

include $(TOP_DIR)/../common.mk

# Opt-in FSM state transition tracker (bind module).
# Compiled after RTL so the bind resolves i3c_target_fsm.
ifneq ($(TRACK_FSM),)
    EXTRA_ARGS += $(TOP_DIR)/lib_i3c_top/fsm_state_tracker.sv
    EXTRA_ARGS += $(TOP_DIR)/lib_i3c_top/descriptor_ibi_fsm_tracker.sv
    EXTRA_ARGS += $(TOP_DIR)/lib_i3c_top/ccc_fsm_tracker.sv
    EXTRA_ARGS += $(TOP_DIR)/lib_i3c_top/ccc_entdaa_fsm_tracker.sv
    EXTRA_ARGS += $(TOP_DIR)/lib_i3c_top/recovery_receiver_fsm_tracker.sv
    EXTRA_ARGS += $(TOP_DIR)/lib_i3c_top/axi_csr_tracker.sv
endif
