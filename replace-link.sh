#!/bin/sh
set -o errexit

if [[ ! -v "${COMMONDEFS}" ]]; then
    COMMONDEFS="$(dirname $(readlink -f "$0"))/common_defs.sh"
fi

if ! . "${COMMONDEFS}" STRING; then
    exit 1
fi

LINKS=(${@})
for (( i=0; i < "${#LINKS[@]}"; ++i )); do
    LINK_FILE="${LINKS[$i]}"
    YN='N'
    if [[ ! -L "${LINK_FILE}" ]]; then
        if [[ -f "${LINK_FILE}" ]]; then
            write_error "'${LINK_FILE}' is a regular file and not a link."
        else
            write_error "'${LINK_FILE}' does not exist."
        fi
    elif [[ ! -e "${LINK_FILE}" ]]; then
        write_error "'${LINK_FILE}' is broken"
    else
        YN='Y'
    fi

    if [[ -d "${LINK_FILE}" ]]; then
        write_error 'directories are currently unsupported.'
        YN='Y'
    fi

    if [[ "${YN}" = 'Y' ]]; then
        FILE_NAME=$(basename "${LINK_FILE}")
        LINK_PATH=$(readlink -f "${LINK_FILE}")
        TMP_FILE="$(dirname "${LINK_FILE}")/.replace-link-${FILE_NAME}"
        cp "${LINK_FILE}" "${TMP_FILE}"
        unlink "${LINK_FILE}"
        mv "${TMP_FILE}" "${LINK_FILE}"
        printf "Replaced %s with copy of %s\n" "'${FILE_NAME}'" "'${LINK_PATH}'"
    fi
done
