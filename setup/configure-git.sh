#!/bin/bash
# Copyright 2025 Timothy Baxendale (pcluddite@outlook.com)

if [[ ! -v COMMONDEFS ]]; then
    COMMONDEFS="$(dirname "$0")/../common_defs.sh"
fi

if ! . "${COMMONDEFS}" ARRAY ERREXIT; then
    exit 1
fi

declare -A CONFIGS=(
    [core.editor]='vim'
    [user.name]='Tim Baxendale'
    [user.email]='pcluddite@outlook.com'
    [pull.rebase]='true'
    [rebase.autoStash]='true'
)

for CFG_KEY in "${!CONFIGS[@]}"; do
    CFG_VALUE="${CONFIGS[${CFG_KEY}]}"
    printf '[%s] = %s: ' "${CFG_KEY}" "${CFG_VALUE}"
    if git config --global -- "${CFG_KEY}" "${CFG_VALUE}"; then
        printf '%s\n' 'OK'
    else
        printf '%s\n' 'FAILED'
    fi
done
