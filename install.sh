#!/bin/env bash

if [ -d ~/.pyenv ]; then
    echo ":::Skipping installation, pyenv is already installed."
else
    curl https://pyenv.run | bash
fi
