#!/bin/bash

exportif() {
    local ARG="${@}"
    local VARNAME="${ARG%%=*}"
    local VARVALUE="${ARG#*=}"
    if [[ ! -v "$VARNAME" ]]; then
        export "${VARNAME}"="${VARVALUE}"
    fi
    export TPB_$VARNAME=$VARVALUE
}

exportif SCRIPT_DIR=$(dirname $(readlink -f $0))
exportif LIB_DIR="${TPB_SCRIPT_DIR}/lib"

exportif EXIT_ERROR=1
exportif EXIT_SUCCESS=0

write_error() {
    printf '%s: %s\n' $(basename "$0") "$1" 1>&2
}

exit_error() {
    local MESSAGE=''
    local EXIT_CODE="$TPB_EXIT_ERROR"
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
