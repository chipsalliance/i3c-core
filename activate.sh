#!/bin/bash

# Useful for running tests directly in verification/block
export I3C_ROOT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
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
