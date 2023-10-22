#!/bin/sh

if [[ ! -v COMMONDEFS ]]; then
    COMMONDEFS="$(dirname "$0")/../common_defs.sh"
fi

if ! . "${COMMONDEFS}" FILEIO ERREXIT; then
    exit 1
fi

assert_root

dnf install gcc gcc-c++ json-devel \
 openssl-devel SDL2-devel libicu-devel \
 speexdsp-devel libcurl-devel \
 cmake fontconfig-devel freetype-devel \
 libpng-devel libzip-devel mesa-libGL-devel \
 duktape-devel

mkcd "${BIN_DIR}"

git clone --depth=1 https://github.com/OpenRCT2/OpenRCT2.git
cd ./OpenRCT2
mkdir build
cd build
cmake ../
make

cp -r ../data/ ./data/ && make g2 && mv ./g2.dat ./data/g2.dat
