#!/bin/bash

# Directories created with this script should be removed with `make clean`
# TODO: Connect to Makefiles' installation directory variable,
# so that user can select installation directory
install(){
    NAME=$1
    URL=$2
    wget -O uvm-1.2.tar.gz $URL
    tar -xf uvm-1.2.tar.gz --strip-components=1 --one-top-level=$NAME/
    rm -f uvm-1.2.tar.gz
}

install generic https://www.accellera.org/images/downloads/standards/uvm/uvm-1.2.tar.gz
install verilator https://github.com/antmicro/uvm-verilator/archive/refs/heads/current-patches.tar.gz
