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

wine_canonical() {
    assert_arg_num 1 "$@" || return $EXIT_FAILURE
    local WINEPREFIX="${WINEPREFIX:-${HOME}/.wine}"
    local WIN_PATH="$1"
    while [[ $# -gt 0 ]]; do
        local WIN_PATH=$(env WINEPREFIX="$WINEPREFIX" wine c:\\windows\\system32\\cmd.exe /c "cd ${WIN_PATH} & cd")
        if [[ $? -eq 0 ]]; then
            printf '%s' "${WIN_PATH}"
        else
            return $EXIT_FAILURE
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
            printf '%c:\\ %q\n' "$(basename "$FILE")" "$(path_cannonical "$FILE")"
        done
        [[ $# -gt 1 ]] && printf '\n%q:\n' "$2"
        shift
    done
}

path_wine() {
    assert_arg_num 1 "$@" || return $EXIT_FAILURE
    local NIX_PATH=$(readlink -f "$1")
    local WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"

    local WIN_BASE=
    local WINE_C=
    while read -r DRIVE && [[ "${WIN_BASE}" = '' ]]; do
        local DRIVE_LETTER="${DRIVE%%\\*}"
        local DRIVE_PATH="$(readlink -f "${DRIVE#*\\ }")"
        [[ "${DRIVE_LETTER}" = 'c:' ]] && WINE_C="${DRIVE_PATH}"
        if [[ "${DRIVE_LETTER}" != 'z:' && "${NIX_PATH}" = "${DRIVE_PATH}"* ]]; then
            WIN_BASE="${DRIVE_LETTER^^}"
            NIX_PATH="${NIX_PATH#${DRIVE_PATH}}"
        fi
    done < <(ls_wine_drives "${WINEPREFIX}")

    if [[ "$WIN_BASE" = '' ]]; then
        WINE_C="${WINE_C:-${WINEPREFIX}/dosdevices/c:}"
        local WINE_HOME="${WINE_C}/users/${USER}"
        for FILE in "$WINE_HOME"/*; do
            if [[ -d "${FILE}" && -L "${FILE}" ]]; then
                local DIR_NAME="$(basename "${FILE}")"
                local LINK_PATH="$(readlink -f "${FILE}")"
                if [[ "${NIX_PATH}" = "${LINK_PATH}"* ]]; then
                    WIN_BASE="C:\\users\\${USER}\\${DIR_NAME}"
                    NIX_PATH="${NIX_PATH#${LINK_PATH}}"
                    break
                fi
            fi
        done
    fi

    if [[ "${WIN_BASE}" = '' ]]; then
        WIN_BASE='z:'
        NIX_PATH="${NIX_PATH#/}"
    fi

    local WIN_PATH=$(basename "${NIX_PATH}")
    NIX_PATH=$(dirname "${NIX_PATH}")

    while [[ "${NIX_PATH}" != '.' && "${NIX_PATH}" != '/' ]]; do
        WIN_PATH="$(basename "${NIX_PATH}")\\${WIN_PATH}"
        NIX_PATH="$(dirname "${NIX_PATH}")"
    done

    printf '%s\\%s' "${WIN_BASE}" "${WIN_PATH}"
}

return $EXIT_SUCCESS

path_unix() {
    assert_arg_num -1 "$@" || return $EXIT_FAILURE

    local WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
    local WIN_PATH=$(wine_canonical "$1") || return $?
    local NIX_PATH=

    while read -r DRIVE && [[ "${NIX_PATH}" = '' ]]; do
        local DRIVE_LETTER="${DRIVE%%\\*}"
        local DRIVE_PATH="$(readlink -f "${DRIVE#*\\ }")"
        if [[ "${WIN_PATH^^}" = "${DRIVE_LETTER^^}"* ]]; then
            NIX_PATH="${DRIVE_PATH}"
            WIN_PATH="${WIN_PATH:${#DRIVE_LETTER}}"
        fi
    done < <(ls_wine_drives "${WINEPREFIX}")

    if [[ "${WIN_PATH}" = '\'* ]]; then
        WIN_PATH="${WIN_PATH:1}"
    fi
    echo "'this is a test${WIN_PATH} '"
    return

    while [[ "${WIN_PATH}" != '' ]]; do
        NIX_PATH="${NIX_PATH}/${WIN_PATH%%\\*}"
        WIN_PATH="${WIN_PATH#\\}"
    done

    printf '%s' "${NIX_PATH}"
}

COMMON_FILEIO='Y'
