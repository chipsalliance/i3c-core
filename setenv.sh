#!/bin/env bash

if [ -n "$ZSH_VERSION" ]; then
   script_path="${(%):-%N}"
else
   script_path="${BASH_SOURCE[0]}"
fi

# Useful for running tests directly in verification/block
export I3C_ROOT_DIR=$( cd "$( dirname "$script_path" )" &> /dev/null && pwd )
export CALIPTRA_ROOT=${I3C_ROOT_DIR}/third_party/caliptra-rtl

export CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic
export CALIPTRA_PRIM_ROOT=${CALIPTRA_ROOT}/src/caliptra_prim_generic
