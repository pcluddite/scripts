#!/bin/bash

if [[ ! -v "${COMMONDEFS}" ]]; then
    COMMONDEFS="$(dirname "$0")/../common_defs.sh"
fi

if ! . "${COMMONDEFS}" STDIO FILEIO STRING ERREXIT; then
    exit 1
fi

XSESSION="$HOME"/.xsession
XSESSIONRC="$HOME"/.xsessionrc
FILES=("$XSESSION" "$XSESSIONRC")

if ! is_defined 'xrdp'; then
    assert_root
    if dnf install xrdp; then
        sed -e 's/^new_cursors=true/new_cursors=false/g' -i /etc/xrdp/xrdp.ini
        systemctl enable xrdp
        systemctl restart xrdp
    else
        write_error 'skipping xrdp installation'
    fi
else
    printf '%s: %s found, skipping installation.\n' "${SCRIPT_NAME}" "'xrdp'"
fi

config_xsession() {
    printf '/usr/bin/startplasma-x11\n'
}

config_xsessionrc() {
    local DATA_DIRS="/usr/share/plasma:/usr/local/share:/usr/share:/var/lib/snapd/desktop"
    local CFG_DIRS="/etc/xdg/xdg-plasma:/etc/xdg:/usr/share/kubuntu-default-settings/kf5-settings"
    printf 'export XDG_SESSION_DESKTOP=KDE\n'
    printf 'export XDG_DATA_DIRS=%s\n' "${DATA_DIRS}"
    printf 'export XDG_CONFIG_DIRS=%s\n' "${CFG_DIRS}"
}

SKIP=()
for FILE in ${FILES[@]}; do
    if [[ -e "$FILE" ]]; then
        printf '%s already exists.\n' "'${FILE}'"
        if [[ $(prompt_yesno --prompt='Do you want to append to the existing file?' --default='no') != 'Y' ]]; then
            SKIP+=("${FILE}")
            continue
        fi
    fi
    FILENAME=$(basename "${FILE}")
    config_$(lower ${FILENAME:1}) >> "${FILE}"
done

if [[ ${#SKIP[@]} -eq ${#FILES[@]} ]]; then
    return_error 'configuration aborted'
fi 
