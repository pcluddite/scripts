#!/bin/bash
# Copyright 2025 Timothy Baxendale (pcluddite@outlook.com)

if [[ ! -v COMMONDEFS ]]; then
    COMMONDEFS="$(dirname "$0")/../common_defs.sh"
fi

if ! . "${COMMONDEFS}" STDIO ERREXIT STRING; then
    exit 1
fi

BASH_PROFILE="${COMMON_DIR}/bash_profile"
BASH_RC="${COMMON_DIR}/bashrc"

OUT_PROFILE="${HOME}/.bash_profile"
OUT_RC="${HOME}/.bashrc"

if [[ -e "${HOME}/.bash_aliases" ]]; then
    if [[ $(prompt_yesno --prompt="Use '${HOME}/.bash_aliases' instead of '${OUT_RC}'?" --default='no') = 'Y' ]]; then
        OUT_RC="${HOME}/.bash_aliases"
    fi
fi

printf \
"

# use custom bashrc
if [ -f %q ]; then
    . %q
fi
" "${BASH_RC}" "${BASH_RC}" >> "${OUT_RC}"
printf "Appended to '%s'\n" "${OUT_RC}"

printf \
"

# use custom bash_profile
if [ -f %q ]; then
    . %q
fi
" "${BASH_PROFILE}" "${BASH_PROFILE}" >> "${OUT_PROFILE}"
printf "Appended to '%s'\n" "$OUT_PROFILE"

if [[ $(prompt_yesno --prompt='Suppress history?' --default='no') = 'Y' ]]; then
    ln -sf /dev/null "${HOME}/.bash_history"
fi
