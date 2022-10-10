#!/bin/bash

set -o errexit

. "$(dirname $(readlink -f $0))/common_defs.sh" STRING FILEIO

DRIVE_C="${HOME}/.wine/drive_c"
DOSDRIVE_C="${HOME}/.wine/dosdevices/c:"

win_base() {
    local NIX_PATH="$1"
    local WINE_HOME="${DRIVE_C}/users/${USER}"
    
    for FILE in "$WINE_HOME"/*; do
        if [[ -d "${FILE}" && -L "${FILE}" ]]; then
            local DIR_NAME="$(basename "${FILE}")"
            local LINK_PATH=$(readlink "${FILE}")
            if [[ "${NIX_PATH}" = "${LINK_PATH}"* ]]; then
                printf '%s' "C:\\users\\${USER}\\${DIR_NAME}"
                return $EXIT_SUCCESS
            fi
        fi
    done

    if [[ "${NIX_PATH}" = "${DRIVE_C}"* ]] || [[ "${NIX_PATH}" = "${DOSDRIVE_C}"* ]]; then
        printf '%s' 'C:'
        return $EXIT_SUCCESS
    fi


    printf '%s' 'Z:'
    return $EXIT_SUCCESS
}

win_path() {
    local NIX_PATH="$(dirname "$1")"
    local WIN_PATH="$(basename "$1")"
    local WIN_BASE="$(win_base "$NIX_PATH")"

    while [[ "${NIX_PATH}" != '/' && "${NIX_PATH}" != 'z:' ]] && \
          [[ "${NIX_PATH}" != "${DRIVE_C}" && "${NIX_PATH}" != "${DOSDRIVE_C}" ]]; do
        WIN_PATH="$(basename "${NIX_PATH}")\\${WIN_PATH}"
        NIX_PATH=$(dirname "${NIX_PATH}")
    done

    WIN_PATH="${WIN_BASE}\\${WIN_PATH:$(( ${#WIN_BASE} - 2 ))}"

    printf '%q' "${WIN_PATH}"
    return $EXIT_SUCCESS
}

nix_path() {
    local WIN_PATH="$(printf '%b' "$1")"
    local NIX_PATH=''
    if [[ "$WIN_PATH" = 'C:'* ]]; then
        local BACKSLASH='\\'
        local SLASH='/'
        NIX_PATH="${WIN_PATH//${BACKSLASH}/${SLASH}}"
        NIX_PATH="$(lower "${NIX_PATH:0:1}")${NIX_PATH:1}"
        NIX_PATH="$(dirname "$NIX_PATH")"
    else
        NIX_PATH="z:${EXE_BASE}"
    fi
    NIX_PATH="${HOME}/.wine/dosdevices/${NIX_PATH}"
    printf "%s" "$NIX_PATH"
}

wineico() {
    local DEEPEST=0
    local BEST_NAME=''
    while read -r ICON_PATH; do
        ICON_NAME="$(basename "$ICON_PATH" ".${ICON_PATH##*.}")"
        local DEPTH=$(( 0x${ICON_NAME:0:4} ))
        if [[ $DEPTH -gt $DEEPEST ]]; then
            DEEPEST=$DEPTH
            BEST_NAME="$ICON_NAME"
        fi
    done < <("$SCRIPT_DIR/wineico.sh" --index=0 --name="$2" --plain "$1")
    if [[ $? -eq 0 ]]; then
        printf '%s\n' "$BEST_NAME"
    else
        return $EXIT_ERROR
    fi
}

EXE_FILE=''

ICON_SW='N'
ENTRY_NAME=''
ENTRY_ICON='application-x-wine-extension-msp'
ENTRY_COMMENT=''
ENTRY_TERMINAL='false'
ENTRY_NOTIFY='true'

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --name=*)
            ENTRY_NAME="${1#*=}"
            ;;
        --name)
            if [[ "$#" -gt 1 && "${2:0:1}" != '-' ]]; then
                ENTRY_NAME="$2"
                shift
            else
                exit_error 'no value was specified for --name'
            fi
            ;;
        --icon=*)
            ENTRY_ICON="${1#*=}"
            ;;
        --icon)
            if [[ "$#" -gt 1 && "${2:0:1}" != '-' ]]; then
                ENTRY_ICON="$2"
                shift
            else
                exit_error 'no value was specified for --icon'
            fi
            ;;
        --new-icon)
            ICON_SW='Y'
            ;;
        -c=*|--comment=*)
            ENTRY_COMMENT="${1#*=}"
            shift
            ;;
        -c|--comment)
            if [[ "$#" -gt 1 && "${2:0:1}" != '-' ]]; then
                ENTRY_COMMENT="$2"
                shift
            else
                exit_error "no value was specified for '$1' option"
            fi
            ;;
        -t|--terminal)
            ENTRY_TERMINAL='true'
            ;;
        --no-notify)
            ENTRY_NOTIFY='false'
            ;;
        -*)
            exit_error "unrecognized option '$1'"
            ;;
        *)
            if [[ "$EXE_FILE" = '' ]]; then
                EXE_FILE="$1"
            else
                exit_error "Too many arguments '$1'"
            fi
            ;;
    esac
    shift
done

if [[ "$EXE_FILE" = '' ]]; then
    exit_error 'No executable file was specified'
elif [[ ! -f "$EXE_FILE" ]]; then
    exit_error "'$EXE_FILE' does not exist"
fi

EXE_FILE="$(cannonicalize "$EXE_FILE")"

if [[ "$ENTRY_NAME" = '' ]]; then
    ENTRY_NAME="$( basename "$EXE_FILE" ".${EXE_FILE##*.}" )"
fi

WIN_PATH="$(win_path "$EXE_FILE")"
EXE_NAME="$(basename "$EXE_FILE")"
EXE_BASE="$(dirname "$EXE_FILE")"

if [[ "$ICON_SW" = 'Y' ]]; then
    ICON_NAME="$(wineico "$EXE_FILE" "$ENTRY_NAME")"
    if [[ $? -eq 0 && "$ICON_NAME" != '' ]]; then
        ENTRY_ICON="$ICON_NAME"
    else
        write_error 'icon could not be extracted'
    fi
fi

printf '[Desktop Entry]\n'
printf 'Name=%s\n' "$ENTRY_NAME"
printf 'Exec=env WINEPREFIX="%q/.wine" wine %s\n' "$HOME" "${WIN_PATH//\\/\\\\}"
printf 'Type=Application\n'
printf 'StartupNotify=%s\n' "$ENTRY_NOTIFY"
printf 'Path=%s\n' "$(nix_path "$WIN_PATH")"
printf 'Icon=%s\n' "$ENTRY_ICON"
printf 'StartupWMClass=%s\n' "$EXE_NAME"
printf 'Comment=%s\n' "$ENTRY_COMMENT"
printf 'Terminal=%s\n' "$ENTRY_TERMINAL"
