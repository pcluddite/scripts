#!/bin/bash

if [[ ! -v COMMONDEFS ]]; then
    COMMONDEFS="$(dirname "$0")/../common_defs.sh"
fi

if ! . "${COMMONDEFS}" ARRAY STDIO FILEIO ERREXIT; then
    return 1
fi

CFG_FILE="${HOME}/.dosbox/dosbox-0.74-3.conf"
ONEDRIVE="${HOME}/tbaxendale/OneDrive"

declare -A DRIVES=(
    [C]="${ONEDRIVE}/Program Files/PortableApps/DOSBoxPortable/files/win"
    [D]="${ONEDRIVE}/My Apps/Desktop/MS-DOS"
    [G]="${ONEDRIVE}/Games"
)

if [[ ! -e "${CFG_FILE}" ]]; then
    exit_error "'${CFG_FILE}' does not exist"
fi

if [[ $(prompt_yesno --prompt='Replace [autoexec] section?' --default='no') != 'Y' ]]; then
    exit_error 'configuration aborted'
fi

TMP_FILE=$(file_next_index "${CFG_FILE}.tmp")

tr -d '\r' < "${CFG_FILE}" | while read -r LINE; do
    if [[ "${LINE}" = '[autoexec]' ]]; then
        printf '%s\n' '[autoexec]'
        printf '%s\n' '# Lines in this section will be run at startup.'

        for LETTER in $(arr_sort -- "${!DRIVES[@]}"); do
            printf 'MOUNT %c "%s"\n' "${LETTER}" "${DRIVES[${LETTER}]}"
        done

        printf '%s\n' 'SET TEMP=C:\WINDOWS\TEMP'
        printf '%s\n' 'PATH %PATH%;C:\CMD;C:\QB'
        printf '%s\n' 'CALL C:\VBDOS\BIN\NEW-VARS.BAT'
        printf '%s\n' 'CALL C:\MSVC\BIN\MSVCVARS.BAT'
        printf '%s\n' 'C:'
        printf '%s\n' 'cls'
        break
    else
        printf '%s\n' "${LINE}"
    fi
done > "${TMP_FILE}"

if unix2dos -q -n "${TMP_FILE}" "${CFG_FILE}"; then
    unlink_rm "${TMP_FILE}"
fi
