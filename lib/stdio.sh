#!/bin/bash

prompt() {
    local PROMPT=''
    local DEFAULT_VALUE=''
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -p=*)
                PROMPT="${1#*=}"
                ;;
            -p)
                if [[ "$#" -gt 1 && "${2:0:1}" != '-' ]]; then
                    PROMPT="$2"
                    shift
                else
                    exit_error 'no value was specified for -p'
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
                    exit_error 'no value was specified for -d'
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
        PROMPT="$PROMPT (${DEFAULT_VALUE}) "
    fi
    read -p "$PROMPT" INPUT
    if [[ "$INPUT" = '' ]]; then
        printf '%s' "$DEFAULT_VALUE"
    else
        printf '%s' "$INPUT"
    fi
}

noop() {
    local ARGS="${@}"
    printf '### NO-OP ### %s\n' "$ARGS"
}
