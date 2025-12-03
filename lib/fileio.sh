#!/bin/bash
# Copyright 2025 Timothy Baxendale (pcluddite@outlook.com)

if [[ "$COMMON_FILEIO" = 'Y' ]]; then
    return $EXIT_SUCCESS
fi

if [[ "${COMMON_ARRAY}" != 'Y' ]]; then
    . "${LIB_DIR}"/array.sh
fi

is_defined() {
    assert_arg_num -1 "$@" || return $EXIT_FAILURE
    command -v "$1" &> /dev/null
}

file_next_index() {
    assert_arg_num -1 "$@" || return $EXIT_FAILURE
    if [[ -e "$1" ]]; then
        local EXT="${1##*.}"
        local DIR_PATH=$(dirname "$1")
        local FILE_NAME=$(basename "$1" ".${EXT}")
        local IDX=1
        while [[ -e "${DIR_PATH}/${FILE_NAME}-${IDX}.${EXT}" ]]; do
            IDX=$(( $IDX + 1 ))
        done
        printf '%s/%s-%d.%s\n' "$DIR_PATH" "$FILE_NAME" $IDX "$EXT"
    else
        printf '%s\n' "$1"
    fi
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

mkcd() {
    assert_arg_num -1 "$@" || return $EXIT_FAILURE
    if [[ ! -e "$1" ]]; then
        mkdir -p -- "$1" || return $EXIT_FAILURE
    fi
    cd -P -- "$1"
}

path_canonical() {
    assert_arg_num 1 "$@" || return $EXIT_FAILURE
    local NIX_PATH="$PWD"
    while [[ $# -gt 0 ]]; do
        local REL_PATH="$1"
        local ABS_PATH=

        if [[ "${REL_PATH}" = '/'* ]]; then
            REL_PATH="${REL_PATH#*/}"
        else
            ABS_PATH="${NIX_PATH}"
        fi

        if [[ "${REL_PATH}" = *'/' ]]; then
            REL_PATH="${REL_PATH%/*}"
        fi

        local LEAF=
        while [[ "${LEAF}" != "${REL_PATH}" ]]; do
            LEAF="${REL_PATH%%/*}"
            if [[ "${LEAF}" = '..' && "${ABS_PATH}" != '/' ]]; then
                ABS_PATH="${ABS_PATH%/*}"
            elif [[ "${LEAF}" != '.' ]]; then
                ABS_PATH="${ABS_PATH}/${LEAF}"
            fi
            REL_PATH="${REL_PATH#${LEAF}/}"
        done

        printf '%s\n' "${ABS_PATH}"
        shift
    done
}

wine_canonical() {
    assert_arg_num 1 "$@" || return $EXIT_FAILURE
    local WINEPREFIX="${WINEPREFIX:-${HOME}/.wine}"
    local NIX_PATH="$PWD"
    while [[ $# -gt 0 ]]; do
        local REL_WIN="$1"
        local ABS_WIN=

        if [[ "${REL_WIN}" =~ ^[a-zA-Z]:.*$ ]]; then
            ABS_WIN="${REL_WIN%%:*}:"
            REL_WIN="${REL_WIN#*:}"
            if [[ "${REL_WIN}" = '\'* ]]; then
                REL_WIN="${REL_WIN:1}"
            fi
        elif [[ "${NIX_PATH}" = '/' ]]; then
            ABS_WIN='z:'
        else
            while read -r DRIVE && [[ "${ABS_WIN}" = '' ]]; do
                local DRIVE_LETTER="${DRIVE%%\\*}"
                local DRIVE_PATH="$(readlink -f "${DRIVE#*\\ }")"
                if [[ "${DRIVE_LETTER,,}" != 'z:' && "${NIX_PATH}" = "${DRIVE_PATH}"* ]]; then
                    if [[ "${NIX_PATH}" = "${DRIVE_PATH}" ]]; then
                        ABS_WIN="${DRIVE_LETTER,,}"
                    else
                        ABS_WIN="${DRIVE_LETTER,,}\\$(basename "${NIX_PATH}")"
                    fi
                fi
            done < <(ls_wine_drives "${WINEPREFIX}")

            if [[ "${ABS_WIN}" = '' ]]; then
                NIX_PATH=$(dirname "${NIX_PATH}")

                while [[ "${NIX_PATH}" != '.' && "${NIX_PATH}" != '/' ]]; do
                    ABS_WIN="$(basename "${NIX_PATH}")\\${ABS_WIN}"
                    NIX_PATH="$(dirname "${NIX_PATH}")"
                done
                ABS_WIN="z:\\${ABS_WIN}"
            fi
        fi

        local DRIVE_LETTER="${ABS_WIN%%\\*}\\"
        local LEAF=
        while [[ "${LEAF}" != "${REL_WIN}" ]]; do
            LEAF="${REL_WIN%%\\*}"
            if [[ "${LEAF}" = '..' && "${ABS_WIN,,}" != "${DRIVE_LETTER}" ]]; then
                ABS_WIN="${ABS_WIN%\\*}"
            elif [[ "${LEAF}" != '.' ]]; then
                ABS_WIN="${ABS_WIN}\\${LEAF}"
            fi
            REL_WIN="${REL_WIN#${LEAF}\\}"
        done

        printf '%s\n' "${ABS_WIN}"
        shift
    done
}

ls_wine_drives() {
    if [[ $# -eq 0 ]]; then
        arr_read :ARGS path_canonical "${WINEPREFIX:=${HOME}/.wine}"
    else
        arr_read :ARGS path_canonical "$@"
    fi

    set -- "${ARGS[@]}"

    [[ $# -gt 1 ]] && printf '%q:\n' "$1"
    while [[ $# -gt 0 ]]; do
        local WINEPREFIX="$1"
        for FILE in "${WINEPREFIX}/dosdevices/"*':'; do
            printf '%c:\\ %q\n' "$(basename "$FILE")" "$(path_canonical "$FILE")"
        done
        [[ $# -gt 1 ]] && printf '\n%q:\n' "$2"
        shift
    done
}

path2wine() {
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

path2unix() {
    assert_arg_num -1 "$@" || return $EXIT_FAILURE

    local WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
    local NIX_PATH=
    local WIN_PATH="$1"

    while read -r DRIVE && [[ "${NIX_PATH}" = '' ]]; do
        local DRIVE_LETTER="${DRIVE%%\\*}"
        local DRIVE_PATH="$(readlink -f "${DRIVE#*\\ }")"
        if [[ "${WIN_PATH^^}" = "${DRIVE_LETTER^^}"* ]]; then
            NIX_PATH="${DRIVE_PATH%%/}"
            WIN_PATH="${WIN_PATH:$(( ${#DRIVE_LETTER} + 1 ))}"
        fi
    done < <(ls_wine_drives "${WINEPREFIX}")

    while [[ "${WIN_PATH}" = *'\'* ]]; do
        NIX_PATH="${NIX_PATH}/${WIN_PATH%%\\*}"
        WIN_PATH="${WIN_PATH#*\\}"
    done
    NIX_PATH="${NIX_PATH}/${WIN_PATH#*\\}"

    printf '%s' "${NIX_PATH}"
}

pretty_path() {
    while [[ $# -gt 0 ]]; do
        if [[ "$1" = "${HOME}"* ]]; then
            printf '~%s\n' "${1#${HOME}}"
        else
            printf '%s\n' "$1"
        fi
        shift
    done
}

COMMON_FILEIO='Y'
