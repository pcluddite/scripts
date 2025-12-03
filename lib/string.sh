#!/bin/bash
# Copyright 2025 Timothy Baxendale (pcluddite@outlook.com)

if [[ "${COMMON_STRING}" = 'Y' ]]; then
    return ${EXIT_SUCCESS}
fi

lower() {
    assert_arg_num 1 "$@" || return $EXIT_FAILUER
    printf '%s' "${*,,}"
}

upper() {
    assert_arg_num 1 "$@" || return $EXIT_FAILURE
    printf '%s' "${*^^}"
}

starts_with() {
    assert_arg_num -2 "$@" || return $EXIT_FAILURE
    [[ "$1" = "$2"* ]]
}

ends_with() {
    assert_arg_num -2 "$@" || return $EXIT_FAILURE
    [[ "$1" = *"$2" ]]
}

is_integer() {
    assert_arg_num -1 "$@" || return $EXIT_FAILURE
    local INT="$1"
    if [[ "$INT" = '' ]]; then
        # false if empty string
        return $EXIT_FAILURE
    elif [[ "$INT" = '-'* ]] || [[ "$INT" = '+'* ]]; then
        # remove any leading sign
        INT="${INT:1}"
    fi

    expr "${INT}" + 0 &> /dev/null && return $EXIT_SUCCESS
    [[ $? -eq 1 ]] # err status 1 means expression was 0
}

COMMON_STRING='Y'
