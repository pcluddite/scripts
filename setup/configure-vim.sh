#!/bin/sh

set -o errexit

if [[ ! -v "${COMMONDEFS}" ]]; then
    COMMONDEFS='../common_defs.sh'
fi

. "${COMMONDEFS}" STDIO
if [[ $? -ne 0 ]]; then
    exit 1
fi

VIMRC="$HOME/.vimrc"

if [[ -f "${VIMRC}" ]]; then
    printf '%s already exists.\n' "'${VIMRC}'"
    if [[ $(prompt_yesno --prompt='Do you want to overwrite the existing file?' --default='no') != 'Y' ]]; then
        exit_error 'configuration aborted'
    fi
fi

printf \
'set nowrap
set expandtab
set tabstop=4
set visualbell
' > "${VIMRC}"

printf 'Created %s\n' "'${VIMRC}'"

