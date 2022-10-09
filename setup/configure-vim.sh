#!/bin/bash

if [[ ! -v "${COMMONDEFS}" ]]; then
    COMMONDEFS="$(dirname "$0")/../common_defs.sh"
fi

if ! . "${COMMONDEFS}" STDIO ERREXIT; then
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

