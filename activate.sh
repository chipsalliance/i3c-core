#!/bin/env bash

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

if [ -n "$ZSH_VERSION" ]; then
   script_path="${(%):-%N}"
else
   script_path="${BASH_SOURCE[0]}"
fi

# Useful for running tests directly in verification/block
export I3C_ROOT_DIR=$( cd "$( dirname "$script_path" )" &> /dev/null && pwd )
export CALIPTRA_ROOT=${I3C_ROOT_DIR}/third_party/caliptra-rtl

# Pyenv
PYTHON_VERSION=3.11.0
VENV_NAME=i3c

pyenv install ${PYTHON_VERSION} --skip-existing
pyenv virtualenv ${PYTHON_VERSION} ${VENV_NAME} || true
pyenv shell ${VENV_NAME}
python --version
pip install --upgrade pip
python -m pip install -r "$(pwd)"/requirements.txt
