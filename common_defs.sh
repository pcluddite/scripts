#!/bin/bash

if [[ ! -v "${COMMONDEFS}" ]]; then
    # define COMMONDEFS if not already defined
    COMMONDEFS=$(readlink -f -- "${BASH_SOURCE[0]}")
fi

SCRIPT_NAME="$(basename -- "$0")"
SCRIPT_DIR=$(dirname -- $(readlink -f -- "$0"))
COMMON_DIR=$(dirname -- "${COMMONDEFS}")
LIB_DIR="${COMMON_DIR}/lib"

EXIT_ERROR=1
EXIT_FAILURE=1
EXIT_SUCCESS=0

write_error() {
    printf '%s: %s\n' "${SCRIPT_NAME}" "$*" 1>&2
}

infof() {
    local VARNAME=
    local PREFIX=
    while [[ $# -gt 0 ]]; do
        case $1 in
            --)
                shift
                break
                ;;
            -v*)
                VARNAME="${1:2}"
                if [[ "${VARNAME}" = '' ]]; then
                    VARNAME="$2"
                    shift
                fi
                ;;
            --prefix*)
                PREFIX="${1#--prefix}"
                if [[ "${PREFIX}" = '='* ]]; then
                    PREFIX=${PREFIX:1}
                elif [[ "${PREFIX}" = '' ]]; then
                    PREFIX="$2"
                    shift
                fi
                ;;
            *)
                break
                ;;
        esac
        shift
    done

    local FORMAT="$1"
    shift

    if [[ "$VARNAME" = '' ]]; then
        declare INFOMSG=
    else
        declare -n INFOMSG=$VARNAME || return $?
    fi

    printf -v INFOMSG "${FORMAT}" "$@" || return $?
    printf -v INFOMSG '%s %s' "${PREFIX:=${SCRIPT_NAME}:}" "${INFOMSG}" || return $?
    if [[ "$VARNAME" = '' ]]; then
        printf '%s\n' "$INFOMSG"
    fi
}

errorf() {
    infof --prefix "${SCRIPT_NAME}: " "$@" 1>&2
}

return_error() {
    local MESSAGE=''
    local EXIT_CODE=$EXIT_FAILURE
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -c=*|--exitcode=)
                EXIT_CODE="${1#*=}"
                ;;
            -c|--exitcode)
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
                    MESSAGE="${MESSAGE} $1"
                fi
                ;;
        esac
        shift
    done
    if [[ "$MESSAGE" != '' ]]; then
        write_error "$MESSAGE"
    fi
    return "$EXIT_CODE"
}

exit_error() {
    return_error "$@"
    exit $?
}

is_identifier() {
    [[ "$*" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]
}

assert_arg_num() {
    local NUM=0
    if [[ $# -gt 0 ]]; then
        NUM="$1"
        shift
    fi
    if [[ $NUM -le 0 ]]; then
        NUM=$(( -$NUM ))
        if [[ $# -gt $NUM ]]; then
            if [[ $NUM -eq 0 ]]; then
                write_error 'no arguments expected'
            else
                write_error "only $NUM argument was expected"
            fi
            return $EXIT_FAILURE
        fi
    fi
    if [[ $# -lt $NUM ]]; then
        if [[ $NUM -eq 1 ]]; then
            write_error 'expected 1 argument'
        else
            write_error "expected ${NUM} arguments"
        fi
        return $EXIT_FAILURE
    fi
    return $EXIT_SUCCESS
}

assert_identifier() {
    is_identifier "$@" || return_error "'$*' is not a valid identifier"
}

is_root() {
    [[ $(id -u) = 0 ]];
}

assert_root() {
    assert_arg_num 0 "$@" || return $EXIT_FAILURE
    if ! is_root; then
        return_error 'This script must be run as root.'
    fi
}

arr_print() {
    assert_arg_num 1 "$@" || return $EXIT_FAILURE
    
    printf '%q' "$1"
    shift

    while [[ $# -gt 0 ]]; do
        printf '\n%q' "$1"
        shift
    done
}

arr() {
    assert_arg_num 1 "$@" || return $EXIT_FAILURE

    local __OUTVAR="$1"
    [[ "${__OUTVAR}" = *'=' ]] && __OUTVAR="${__OUTVAR%%=}"
    [[ "${__OUTVAR}" = ':'* ]] && __OUTVAR="${__OUTVAR#:}"

    if [[ "$__OUTVAR" = '' ]]; then
        return_error 'variable must be specified'
    elif ! is_identifier "${__OUTVAR}"; then
        return_error 'not a valid identifier'
    fi
    [[ $? -eq 0 ]] || return $EXIT_FAILURE
    
    shift

    local __OPTION=
    local __ARGS=()

    if [[ "$1" =~ -[vtf]+.* ]]; then
        local ARG="${1:2}"
        __OPTION="${1:1:1}"
        shift
        if [[ "${ARG}" = '' ]]; then
            if [[ $# -eq 0 ]]; then
                write_error "no value specified for '-${__OPTION}'"
                return $EXIT_FAILURE
            fi
        else
            if [[ "${ARG}" = '='* ]] || [[ "${ARG}" = ':'* ]]; then
                ARG="${ARG:1}"
            fi
            __ARGS+=("${ARG}")
        fi
    elif [[ "$1" = '-c' ]]; then
        __OPTION='c'
        shift
    fi

    if [[ "$1" = '--' ]]; then
        shift
    elif [[ "$1" = '-'* ]]; then
        write_error "unrecognized __OPTION '$1'" 
        return $EXIT_FAILURE
    fi

    if [[ $# -gt 0 ]]; then
        __ARGS+=("$@")
    fi

    set -- "${__ARGS[@]}"

    if [[ $# -eq 0 ]] && [[ "${__OPTION}" = '' ]]; then
        mapfile -t "${__OUTVAR}"
    else
        if [[ "${__OPTION:=c}" = 'c' ]]; then
            assert_arg_num 1 "$@" || return $EXIT_FAILURE
            mapfile -t "${__OUTVAR}" < <("$@" || exit $EXIT_FAILURE)
        else
            assert_arg_num -1 "$@" || return $EXIT_FAILURE
            if [[ "$__OPTION" = 'v' ]]; then
                local VARNAME="$1"
                mapfile -t "${__OUTVAR}" <<< "${!VARNAME}"
            elif [[ "$__OPTION" = 't' ]]; then
                mapfile -t "${__OUTVAR}" <<< "$1"
            elif [[ "$__OPTION" = 'f' ]]; then
                mapfile -t "${__OUTVAR}" < "$1"
            fi
        fi
    fi
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        STRING)
            . "${LIB_DIR}/string.sh"
            ;;
        VARGS)
            . "${LIB_DIR}/vargs.sh"
            ;;
        STDIO)
            . "${LIB_DIR}/stdio.sh"
            ;;
        FILEIO)
            . "${LIB_DIR}/fileio.sh"
            ;;
        ERREXIT|EXITERR)
            set -o errexit
            ;;
        *)
            return_error "unrecognized option '$1'"
            ;;
    esac
    shift
done
