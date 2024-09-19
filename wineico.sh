#!/bin/bash

set -o errexit

. "$(dirname $(readlink -f $0))/common_defs.sh" STDIO FILEIO STRING

extract_png() {
    local ICO_INDEX='667'
    local ICO_HEIGHT='0'
    local ICO_WIDTH='0'
    local ICO_DEPTH='208'
    local ICO_PALLET='15'
    local ICO_FILE=''
    local IS_ICON='N'
    local ARG_LIST=${@}

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --file=*)
                ICO_FILE="${1#*=}"
                ARG_LIST="${ARG_LIST#$1}"
                ;;
            --icon)
                IS_ICON='Y'
                ;;
            --height=*)
                ICO_HEIGHT="${1#*=}"
                ;;
            --width=*)
                ICO_WIDTH="${1#*=}"
                ;;
            --bit-depth=*)
                ICO_DEPTH="${1#*=}"
                ;;
            --palette-size=*)
                ICO_PALLET="${1#*=}"
                if is_integer "$ICO_PALLET" && [[ "$ICO_PALLET" -ne 0 ]]; then
                    ICO_PALLET=$(( $ICO_PALLET - 1 ))
                fi
                ;;
            --index=*)
                ICO_INDEX="${1#*=}"
                ;;
            *)
                exit_error "unrecognized option '$1'"
                ;;
        esac
        shift
    done

    if [[ $IS_ICON != 'Y' ]]; then
        return $EXIT_ERROR
    fi

    printf -v ICO_DEPTH "%02X" "$ICO_DEPTH"
    if [[ $? -ne 0 ]]; then
        ICO_DEPTH='D0'
    fi
    
    printf -v ICO_PALLET "%02X" "$ICO_PALLET"
    if [[ $? -ne 0 ]]; then
        ICO_PALLET='0F'
    fi
    
    local PNG_PATH="$OUT_PATH/${ICO_HEIGHT}x${ICO_WIDTH}/apps"
    local PNG_NAME="${ICO_DEPTH}${ICO_PALLET}_${ICON_NAME// /_}.${ICON_INDEX}.png"

    if [[ ! -d "$PNG_PATH" ]] && [[ "$DRY_SW" != 'Y' ]]; then
        mkdir -p "$PNG_PATH"
    fi

    if [[ "$PLAIN_SW" = 'Y' ]]; then
        printf '%q/%q\n' "$PNG_PATH" "$PNG_NAME"
    else
        printf 'Extracting "%s/%s"\n' "$PNG_PATH" "$PNG_NAME"
    fi
    if [[ "$DRY_SW" != 'Y' ]]; then
        if ! icotool -x $ARG_LIST --output="/tmp" "$ICO_FILE"; then
            return $EXIT_ERROR
        fi
        TMP_PNG="$(basename "$ICO_FILE" .ico)_${ICO_INDEX}_${ICO_HEIGHT}x${ICO_WIDTH}x$(( 0x$ICO_DEPTH )).png"
        if mv "/tmp/$TMP_PNG" "$PNG_PATH/$PNG_NAME"; then
            printf 'rm %q\n' "$PNG_PATH/$PNG_NAME" >> "$TMP_RM_SCRIPT"
        fi
    fi
    return $EXIT_SUCCESS
}

extract_ico() {
    local IDX="$1"
    local TMP_FILE="/tmp/wineico-${ICON_NAME}.${IDX}.ico"
    icoextract -n $IDX "$EXE_PATH" "$TMP_FILE" &> /dev/null
    if [[ $? -ne 0 ]]; then
        rm "$TMP_FILE" &> /dev/null
        return $EXIT_ERROR
    fi
    printf '\n# Icon(%d):\n' "$IDX" >> "$TMP_RM_SCRIPT"
    while read ICON_ARG_LINE; do
        if extract_png --file="$TMP_FILE" $ICON_ARG_LINE; then
            GOOD=$(( $GOOD + 1 ))
        else
            BAD=$(( $BAD + 1 ))
        fi
    done < <(icotool --list "$TMP_FILE")
    rm "$TMP_FILE" &> /dev/null
    return $EXIT_SUCCESS
}

EXE_PATH=''
ICON_NAME=''
ICON_INDEX=''
OUT_PATH="$HOME/.local/share/icons/hicolor"
DRY_SW='N'
PLAIN_SW='N'
UNINSTALL_SW='Y'

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUT_PATH="$2"
            shift
            ;;
        -d|--dry-run)
            DRY_SW='Y'
            ;;
        --no-uninstall)
            UNINSTALL_SW='N'
            ;;
        -n|--name|--name=*)
            ICON_NAME="${1#*=}"
            if [[ "$ICON_NAME" = '' && "$2" != '' && "${2:0:1}" != '-' ]]; then
                ICON_NAME="$2"
                shift
            fi
            if [[ "$ICON_NAME" = '' ]]; then
                exit_error 'no value was specified for --name'
            fi
            ;;
        -i|--index|--index=*)
            ICON_INDEX="${1#*=}"
            if [[ "$ICON_INDEX" = '' && "$2" != '' && "${2:0:1}" != '-' ]]; then
                ICON_INDEX="$2"
                shift
            fi
            if [[ "$ICON_INDEX" = '' ]]; then
                exit_error "no index number specified"
            elif ! is_integer "$ICON_INDEX"; then
                exit_error "invalid index '$ICON_INDEX'"
            fi
            ;;
        -p|--plain)
            PLAIN_SW='Y'
            ;;
        -*)
            exit_error "unrecognized option '$1'"
            ;;
        *)
            if [[ "$EXE_PATH" = '' ]]; then
                EXE_PATH="$1"
            else
                exit_error "Too many arguments '$1'"
            fi
            ;;
    esac
    shift
done

# pre checks

if [[ "$EXE_PATH" = '' ]]; then
    exit_error "Usage: './$(basename "$0")' <executable path>"
elif [[ ! -f "$EXE_PATH" ]]; then
    exit_error "'$EXE_PATH' does not exist"
fi

if [[ ! -d "$OUT_PATH" ]]; then
    exit_error "'$OUT_PATH' does not exist"
fi

if ! is_defined 'icoextract'; then
    exit_error\
"'icoextract' does not exist. It can be installed using python3-pip.

    pip3 install icoextract[thumbnailer]

See https://github.com/jlu5/icoextract/"
fi

if ! is_defined 'icotool'; then
    exit_error \
"'icotool' does not exist. It can be installed from the icoutils package.

    sudo dnf install icoutils"
fi

EXE_PATH=$(readlink -f "$EXE_PATH")
if [[ "$ICON_NAME" = '' ]]; then
    ICON_NAME=$(basename "$EXE_PATH" ".${EXE_PATH##*.}")
fi

GOOD=0
BAD=0

TMP_RM_SCRIPT="/tmp/uninstall-wineico-${ICON_NAME// /-}.tmp"
if [[ '$DRY_SW' = 'Y' ]]; then
    TMP_RM_SCRIPT='/dev/null'
elif [[ -f "$TMP_RM_SCRIPT" ]]; then
    rm "$TMP_RM_SCRIPT"
fi

if [[ "$ICON_INDEX" = '' ]]; then
    ICON_INDEX=0
    while extract_ico $ICON_INDEX; do
        ICON_INDEX=$(( $ICON_INDEX + 1 ))
    done
else
    extract_ico $ICON_INDEX
fi

if [[ -f "$TMP_RM_SCRIPT" && "$DRY_SW" != 'Y' ]]; then
    if [[ "$UNINSTALL_SW" = 'Y' ]]; then
        printf -v UNICON_DIR '%s/un-icon' $(dirname $0)
        printf -v RM_SCRIPT '%s/%s.sh' "$UNICON_DIR" $(basename "$TMP_RM_SCRIPT" .tmp)
        if [[ ! -d "$UNICON_DIR" ]]; then
            mkdir -p "$UNICON_DIR"
        fi
        #RM_SCRIPT=$(next_no_exist "$RM_SCRIPT")
        EXISTING_RM_SCRIPT="$RM_SCRIPT"
        if [[ -f "$RM_SCRIPT" ]]; then
            RM_SCRIPT="/tmp/$(basename "$RM_SCRIPT")"
        fi
        printf '#!/bin/sh\n\n' > "$RM_SCRIPT"
        printf '#\n' >> "$RM_SCRIPT"
        printf '# Remove icon script for %s (%s)\n#\n' "'$ICON_NAME'" $(basename "$EXE_PATH") >> "$RM_SCRIPT"
        cat "$TMP_RM_SCRIPT" >> "$RM_SCRIPT"
        if [[ "$EXISTING_RM_SCRIPT" = "$RM_SCRIPT" ]]; then
            chmod +x "$RM_SCRIPT"
        else
            write_error "'${EXISTING_RM_SCRIPT}' already exists. Uninstall script is '${RM_SCRIPT}'"
        fi
    else
        rm "$TMP_RM_SCRIPT" &> /dev/null
    fi
fi

if [[ $BAD -gt 0 ]]; then
    if [[ $GOOD -le 0 ]]; then
        exit_error 'No icons were extracted.'
    else
        exit_error "${GOOD} icon(s) extracted. ${BAD} icon(s) failed."
    fi
elif [[ $GOOD -eq 0 ]]; then
    exit_error 'No icons found.'
elif [[ "$PLAIN_SW" -ne 'Y' ]]; then
    printf 'Successfully extracted %d icon(s).\n' $GOOD
fi
