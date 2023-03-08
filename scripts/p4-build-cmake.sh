#!/bin/bash

# expects SDE and SDE_INSTALL env vars to be set correctly, i.e., pointing to an SDE installation
#
# usage: p4-build-cmake.sh <p4-program-name>
# example: p4-build-cmake.sh pronarepeater
#   this would compile pronarepeater.p4 from the current directory to be available as 
#   program pronarepeater in $SDE_INSTALL

WORKDIR=$PWD
mkdir $WORKDIR/build
cd $WORKDIR/build
cmake $SDE/p4studio/ \
-DCMAKE_INSTALL_PREFIX=$SDE/install \
-DCMAKE_MODULE_PATH=$SDE/cmake \
-DP4_NAME=$1 \
-DP4_PATH=$WORKDIR/$1.p4
make $1 && make install
