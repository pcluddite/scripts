#!/bin/bash

if [[ "$COMMON_FILEIO" = 'Y' ]]; then
    return $EXIT_SUCCESS
fi

is_defined() {
    assert_arg_num -1 "$@" || return $EXIT_FAILURE
    command -v "$1" &> /dev/null
}

next_no_exist() {
    assert_arg_num -1 "$@" || return $EXIT_FAILURE
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

path_cannonical() {
    assert_arg_num 1 "$@" || return $EXIT_FAILURE
    while [[ $# -gt 0 ]]; do
        printf '%s/%s\n' "$(cd "$(dirname "$1")"; pwd)" "$(basename "$1")"
        shift
    done
}

unlink_rm() {
    assert_arg_num 1 "$@" || return $EXIT_FAILURE
    while [[ $# -gt 0 ]]; do
        if [[ -L "$1" ]]; then
            unlink "$1" || return $?
        elif [[ -d "$1" ]]; then
            rmdir "$1" || return $?
        else [[ -f "$1" ]];
            rm "$1" || return $?
        fi
        shift
    done
}

ls_wine_drives() {
    if [[ $# -eq 0 ]]; then
        arr :ARGS path_cannonical "${WINEPREFIX:=${HOME}/.wine}"
    else
        arr :ARGS path_cannonical "$@"
    fi

    set -- "${ARGS[@]}"

    [[ $# -gt 1 ]] && printf '%q:\n' "$1"
    while [[ $# -gt 0 ]]; do
        local WINEPREFIX="$1"
        for FILE in "${WINEPREFIX}/dosdevices/"*':'; do
            printf '%c:\\ %q\n' "$(basename "$FILE")" "$(readlink "$FILE")"
        done
        [[ $# -gt 1 ]] && printf '\n%q:\n' "$2"
        shift
    done
}

COMMON_FILEIO='Y'
