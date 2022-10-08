#!/bin/bash

if [[ "$COMMON_FILEIO" = 'Y' ]]; then
    return $EXIT_SUCCESS
fi

is_defined() {
    command -v "$1" &> /dev/null
}

next_no_exist() {
    if [[ -f "$1" ]]; then
        local EXT="${1##*.}"
        local DIR_PATH=$(dirname "$1")
        local FILE_NAME=$(basename "$1" ".${EXT}")
        local IDX=1
        while [[ -f "${DIR_PATH}/${FILE_NAME}-${IDX}.${EXT}" ]]; do
            IDX=$(( $IDX + 1 ))
        done
        printf '%s/%s-%d.%s\n' "$DIR_PATH" "$FILE_NAME" $IDX "$EXT"
    else
        printf '%s\n' "$1"
    fi
}

export COMMON_FILEIO='Y'
