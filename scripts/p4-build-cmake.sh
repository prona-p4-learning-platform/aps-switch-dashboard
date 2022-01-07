#!/bin/bash
CURRENT_DIR=$PWD
mkdir ~/build
cd ~/build
cmake $SDE/p4studio/ \
-DCMAKE_INSTALL_PREFIX=$SDE/install \
-DCMAKE_MODULE_PATH=$SDE/cmake \
-DP4_NAME=$1 \
-DP4_PATH=$CURRENT_DIR/$1.p4
make $1 && make install
