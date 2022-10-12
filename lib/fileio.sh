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
        if [[ -d "$1" ]]; then
            printf '%s\n' "$(cd "$1"; pwd)"
        else
            printf '%s/%s\n' "$(cd "$(dirname "$1")"; pwd)" "$(basename "$1")"
        fi
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

path_wine() {
    assert_arg_num 1 "$@" || return $EXIT_FAILURE
    local NIX_PATH=$(path_cannonical "$1")
    local WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
    local WINE_C="${WINEPREFIX}/dosdevices/c:"
    local WINE_HOME="${WINE_C}/users/${USER}"

    local WIN_BASE=
    for FILE in "$WINE_HOME"/*; do
        if [[ -d "${FILE}" && -L "${FILE}" ]]; then
            local DIR_NAME="$(basename "${FILE}")"
            local LINK_PATH=$(path_cannonical $(readlink "${FILE}"))
            if [[ "${NIX_PATH}" = "${LINK_PATH}"* ]]; then
                NIX_PATH="${NIX_PATH#${LINK_PATH}}"
                WIN_BASE="C:\\users\\${USER}\\${DIR_NAME}"
                break
            fi
        fi
    done

    if [[ "${WIN_BASE}" = '' ]]; then
        WIN_BASE='z:'
        NIX_PATH="${NIX_PATH#/}"
    fi

    local WIN_PATH=
    while [[ "${NIX_PATH}" != '.' ]]; do
        WIN_PATH="$(basename "${NIX_PATH}")\\${WIN_PATH}"
        NIX_PATH=$(dirname "${NIX_PATH}")
    done

    printf '%s\\%s' "${WIN_BASE}" "${WIN_PATH}"
}

return $EXIT_SUCCESS

COMMON_FILEIO='Y'
