#!/bin/bash

PYTHON_VERSION=3.11.0
VENV_NAME=i3c

pyenv install ${PYTHON_VERSION} --skip-existing
pyenv virtualenv ${PYTHON_VERSION} ${VENV_NAME} || true
pyenv shell ${VENV_NAME}
python --version
python -m pip install -r "$(pwd)"/requirements.txt
