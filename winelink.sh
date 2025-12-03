#!/bin/bash
# Copyright 2025 Timothy Baxendale (pcluddite@outlook.com)

if [[ ! -v COMMONDEFS ]]; then
    COMMONDEFS="$(dirname "$0")/common_defs.sh"
fi

if ! . "${COMMONDEFS}" FILEIO STRING ERREXIT; then
    return $EXIT_FAILURE
fi

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

ENV_XDGOPEN='N'
ENTRY_NAME=''
ENTRY_ICON='application-x-ms-dos-executable'
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
        --xdg-open)
            ENV_XDGOPEN='Y'
            ;;
        -c=*|--comment=*)
            ENTRY_COMMENT="${1#*=}"
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
                exit_error "too many arguments '$1'"
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

EXE_FILE="$(path_canonical "$EXE_FILE")"

if [[ "$ENTRY_NAME" = '' ]]; then
    ENTRY_NAME="$( basename "$EXE_FILE" ".${EXE_FILE##*.}" )"
fi

EXE_NAME="$(basename "$EXE_FILE")"
EXE_BASE="$(dirname "$EXE_FILE")"
WIN_PATH=

printf -v WIN_PATH '%q' "$(path2wine "$EXE_FILE")"

if [[ "$ICON_SW" = 'Y' ]]; then
    ICON_NAME="$(wineico "$EXE_FILE" "$ENTRY_NAME")"
    if [[ $? -eq 0 && "$ICON_NAME" != '' ]]; then
        ENTRY_ICON="$ICON_NAME"
    else
        write_error 'icon could not be extracted'
    fi
fi

if [[ "$ENV_XDGOPEN" = 'Y' ]]; then
    printf '%s\n' "#!/usr/bin/env xdg-open"
fi

printf '[Desktop Entry]\n'
printf 'Name=%s\n' "$ENTRY_NAME"
printf 'Exec=env WINEPREFIX="%q/.wine" wine %s\n' "$HOME" "${WIN_PATH//\\/\\\\}"
printf 'Type=Application\n'
printf 'StartupNotify=%s\n' "$ENTRY_NOTIFY"
printf 'Path=%s\n' "$(eval path2unix $WIN_PATH)"
printf 'Icon=%s\n' "$ENTRY_ICON"
printf 'StartupWMClass=%s\n' "$EXE_NAME"
printf 'Comment=%s\n' "$ENTRY_COMMENT"
printf 'Terminal=%s\n' "$ENTRY_TERMINAL"
