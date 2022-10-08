#!/bin/sh

set -o errexit

if [[ ! -v "${COMMONDEFS}" ]]; then
    COMMONDEFS='../common_defs.sh'
fi

if ! . "${COMMONDEFS}" STDIO; then
    exit 1
fi

ONEDRIVE="${HOME}/OneDrive"
HOME_FOLDERS=(Documents Pictures Music Videos 'Disc Images' Games)

for (( i=0; i < ${#HOME_FOLDERS[@]}; ++i )); do
    FOLDER="${HOME_FOLDERS[$i]}"
    HOME_DIR="${HOME}/${FOLDER}"
    ONEDRIVE_DIR="${ONEDRIVE}/${FOLDER}"
    YN='N'
    if [[ ! -d "${ONEDRIVE_DIR}" ]]; then
        YN='N'
        write_error "'${ONEDRIVE_DIR}' does not exist. It cannot be linked to '${HOME_DIR}'"
    elif [[ -d "${HOME_DIR}" ]]; then
        YN=$(prompt_yesno --prompt="'${HOME_DIR}' already exists! Replace?" --default='no')
        if [[ "${YN}" = 'Y' ]]; then
            YN='N'
            if [[ -L "${HOME_DIR}" ]] && unlink "${HOME_DIR}"; then
                YN='Y'
            elif [[ -d "${HOME_DIR}" ]] && rmdir "${HOME_DIR}"; then
                YN='Y'
            fi
            if [[ "${YN}" != 'Y' ]]; then
                write_error "Skipping '${ONEDRIVE_DIR}' because '${HOME_DIR}' could not be removed."
            fi
        fi
    else
        YN='Y'
    fi
    if [[ "${YN}" = 'Y' ]]; then
        ln -s "${ONEDRIVE_DIR}" "${HOME_DIR}"
    fi
done

HISTORY_FILE="${HOME}/.bash_history"

YN='N'
if [[ -e "${HISTORY_FILE}" ]]; then
    YN=$(prompt_yesno --prompt="'${HISTORY_FILE}' already exists! Replace with '/dev/null'?" --default='no')
    if [[ "${YN}" = 'Y' ]]; then
        if [[ -L "${HISTORY_FILE}" ]]; then
            unlink "${HISTORY_FILE}"
        else
            rm "${HISTORY_FILE}"
        fi
    fi
fi
if [[ "${YN}" = 'Y' ]]; then
    ln -s '/dev/null' "${HISTORY_FILE}"
fi
