#!/bin/bash

do_modify=0
echo ":::Allow to modify bashrc (Y/n)?"
read let_modify
if [ "$let_modify" != "${let_modify#[Yy]}" ] ;then
    do_modify=1
else
    do_modify=0
fi

which pyenv
which_rc=$?
if [[ ${which_rc} -eq 0 ]]; then
    echo ":::Skipping installation, pyenv is already installed."
else
    curl https://pyenv.run | bash
fi

if [ ! -f ~/.bashrc ]; then
    touch ~/.bashrc
fi

grep -q PYENV_ROOT ~/.bashrc
grep_rc=$?
if [[ ${do_modify} -eq 1 ]] ;then
    echo ":::Patching ~/.bashrc..."
    if [[ ${grep_rc} -eq 0 ]]; then
        echo ":::... ~/.bashrc had correct contents. Did not modify."
    else
        cat "$(pwd)"/tools/pyenv/patch_bashrc.f >> ~/.bashrc
        echo ":::... patched."
    fi
else
    echo ":::Update ~/.bashrc on your own"
    echo ":::https://github.com/pyenv/pyenv?tab=readme-ov-file#set-up-your-shell-environment-for-pyenv"
    exit 0
fi
