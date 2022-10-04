#!/bin/bash

SCRIPT_DIR=$(dirname $(readlink -f $0))
LIB_DIR="${SCRIPT_DIR}/lib"

EXIT_ERROR=1
EXIT_SUCCESS=0

write_error() {
    printf '%s: %s\n' $(basename "$0") "$1" 1>&2
}

exit_error() {
    local MESSAGE=''
    local EXIT_CODE="$EXIT_ERROR"
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -c=*)
                EXIT_CODE="${1#*=}"
                ;;
            -c)
                if [[ "$#" -gt 1 && "${2:0:1}" != '-' ]]; then
                    EXIT_CODE="$2"
                    shift
                else
                    write_error 'no value was specified for -c'
                fi
                ;;
            -*)
                write_error "unrecognized option '$1'"
                ;;
            *)
                if [[ "$MESSAGE" = '' ]]; then
                    MESSAGE="$1"
                else
                    write_error "Too many arguments '$1'"
                fi
                ;;
        esac
        shift
    done
    if [[ "$MESSAGE" != '' ]]; then
        write_error "$MESSAGE"
    fi
    exit "$EXIT_CODE"
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        STDIO)
            . "${LIB_DIR}/stdio.sh"
            ;;
        STRING)
            . "${LIB_DIR}/string.sh"
            ;;
        FILEIO)
            . "${LIB_DIR}/fileio.sh"
            ;;
        *)
            exit_error "unrecognized option '$1'"
            ;;
    esac
    shift
done
