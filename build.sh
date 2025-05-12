#!/usr/bin/env bash

BUILD_DIR=.build

if [[ ! -d $BUILD_DIR ]]; then
    mkdir -p $BUILD_DIR
    echo "*" > $BUILD_DIR/.gitignore
fi

odin run ./src -out:$BUILD_DIR/elementals -define:SHADERS=true -define:VR=false "$@"
