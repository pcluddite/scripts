#!/bin/bash
# Copyright 2025 Timothy Baxendale (pcluddite@outlook.com)

if [[ ! -v COMMONDEFS ]]; then
    COMMONDEFS="$(dirname "$0")/../common_defs.sh"
fi

if ! . "${COMMONDEFS}" FILEIO STDIO ERREXIT; then
    exit 1
fi

link_home() {
    while [[ $# -gt 0 ]]; do
        local LINK="${HOME}/${1%%=*}"
        local TARGET="${1#*=}"
        local YN='N'
        if [[ ! -e "${TARGET}" ]]; then
            write_error "'${TARGET}' does not exist. It cannot be linked to '${LINK}'"
        elif [[ -e "${LINK}" || -L "${LINK}" ]]; then
            YN=$(prompt_yesno --prompt="'$(pretty_path "${LINK}")' already exists! Replace with '$(pretty_path "${TARGET}")'?" --default='no')
            if [[ "${YN}" = 'Y' ]] && ! unlink_rm "${LINK}"; then
                YN='N'
                write_error "Skipping '$(pretty_path "${TARGET}")' because '$(pretty_path "${LINK}")' could not be removed."
            fi
        else
            YN='Y'
        fi
        if [[ "${YN}" = 'Y' ]]; then
            ln -s "${TARGET}" "${LINK}"
        fi
        shift
    done
}

link_onedrive() {
    local ONEDRIVE="${HOME}/OneDrive"
    local ARGS=()
    while [[ $# -gt 0 ]]; do
        ARGS+=("$1=${ONEDRIVE}/$1")
        shift
    done
    link_home "${ARGS[@]}"
}

link_home \
    '.bash_history'='/dev/null' \
    '.bash_profile'="${COMMON_DIR}/bash_profile"

link_onedrive \
    Documents \
    Pictures \
    Music \
    Videos \
    'Disc Images' \
    Games
