#!/bin/bash
# Copyright 2025 Timothy Baxendale (pcluddite@outlook.com)

if [[ "${COMMON_STDIO}" = 'Y' ]]; then
    return $EXIT_SUCCESS
fi

prompt() {
    local PROMPT=''
    local DEFAULT_VALUE=''
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -p=*|--prompt=*)
                PROMPT="${1#*=}"
                ;;
            -p|--prompt)
                if [[ "$#" -gt 1 && "${2:0:1}" != '-' ]]; then
                    PROMPT="$2"
                    shift
                else
                    exit_error "no value was specified for $1"
                fi
                ;;
            -d=*|--default=*)
                DEFAULT_VALUE="${1#*=}"
                ;;
            -d|--default)
                if [[ "$#" -gt 1 ]]; then
                    DEFAULT_VALUE="$2"
                    shift
                else
                    exit_error "no value was specified for $1"
                fi
                ;;
            -*)
                exit_error "unrecognized option '$1'"
                ;;
            *)
                if [[ "$PROMPT" = '' ]]; then
                    PROMPT="$1"
                else
                    exit_error "Too many arguments '$1'"
                fi
                ;;
        esac
        shift
    done
    local INPUT=''
    if [[ "$DEFAULT_VALUE" != '' ]]; then
        PROMPT="$PROMPT [${DEFAULT_VALUE}] "
    fi
    read -p "$PROMPT" INPUT
    if [[ "$INPUT" = '' ]]; then
        printf '%s' "$DEFAULT_VALUE"
    else
        printf '%s' "$INPUT"
    fi
}

prompt_yesno() {
    local INPUT=$(prompt "${@}")
    local YN=''
    while [[ "${YN}" = '' ]]; do
        if [[ "${INPUT}" = 'y' ]] || [[ "${INPUT}" = 'yes' ]]; then
            YN='Y'
        elif [[ "${INPUT}" = 'n' ]] || [[ "${INPUT}" = 'no' ]]; then
            YN='N'
        else
            printf "Type 'yes' or 'no'\n" 1>&2
            INPUT=$(prompt "${@}")
        fi
    done
    printf '%s' "${YN}"
}

noop() {
    local ARGS="${@}"
    printf '### NO-OP ### %s\n' "$ARGS"
}

COMMON_STDIO='Y'
