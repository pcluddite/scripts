#!/bin/bash

if [[ ! -v "${COMMONDEFS}" ]]; then
    COMMONDEFS="$(dirname "$0")/../common_defs.sh"
fi

if ! . "${COMMONDEFS}" FILEIO ERREXIT; then
    exit 1
fi

if ! is_defined 'wine' || ! is_defined 'cabextract'; then
    assert_root
    dnf install wine cabextract
fi

mkcd "${BIN_DIR}"
wget  https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
chmod +x winetricks
