#!/bin/sh

if [[ ! -v "${COMMONDEFS}" ]]; then
    COMMONDEFS="$(dirname "$0")/../common_defs.sh"
fi

if ! . "${COMMONDEFS}" STDIO ERREXIT; then
    exit 1
fi

DESKTOP="${HOME}/Desktop"

FILES=("home.desktop" "trash.desktop")
ENTRIES=('[Desktop Entry]
Encoding=UTF-8
Name=Home
GenericName=Personal Files
URL[$e]=$HOME
Icon=user-home
Type=Link
'
'[Desktop Entry]
Name=Trash
Comment=Contains removed files
Icon=user-trash-full
EmptyIcon=user-trash
Type=Link
URL=trash:/
OnlyShowIn=KDE;
')

for (( i=0; i < ${#FILES[@]}; ++i )); do
    FILEPATH="${DESKTOP}/${FILES[$i]}"
    ENTRY="${ENTRIES[$i]}"
    YN='N'
    if [[ -e "${FILEPATH}" ]]; then
        YN=$(prompt_yesno --prompt="'${FILEPATH}' already exists! Replace?" --default='no')
        if [[ "${YN}" = 'Y' ]]; then
            YN='N'
            if [[ -L "${FILEPATH}" ]] && unlink "${FILEPATH}"; then
                YN='Y'
            elif [[ -f "${FILEPATH}" ]] && rm "${FILEPATH}"; then
                YN='Y'
            fi
            if [[ "${YN}" != 'Y' ]]; then
                write_error "Skipping '${FILEPATH}'."
            fi
        fi
    else
        YN='Y'
    fi
    printf '%s' "${ENTRY}" > "${FILEPATH}"
done
