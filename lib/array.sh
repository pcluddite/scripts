#!/bin/bash

if [[ "${COMMON_ARRAY}" = 'Y' ]]; then
    return $EXIT_SUCCESS
fi

is_array() {
    local __INVAR="$1"
    while [[ $# -gt 0 ]]; do
        local __DECL=$(declare -p "$__INVAR" 2> /dev/null) || return $EXIT_FAILURE
        if [[ "${__DECL}" = 'declare -a'* ]]; then
            shift
            __INVAR="$1"
        else
            if [[ "${__DECL}" = 'declare -n'* ]]; then
                eval __INVAR="${__DECL#*=}"
            else
                return $EXIT_FAILURE
            fi
        fi
    done
    return $EXIT_SUCCESS
}

is_map() {
    local __INVAR="$1"
    while [[ $# -gt 0 ]]; do
        local __DECL=$(declare -p "$__INVAR" 2> /dev/null) || return $EXIT_FAILURE
        if [[ "${__DECL}" = 'declare -A'* ]]; then
            shift
            __INVAR="$1"
        else
            if [[ "${__DECL}" = 'declare -n'* ]]; then
                eval __INVAR="${__DECL#*=}"
            else
                return $EXIT_FAILURE
            fi
        fi
    done
    return $EXIT_SUCCESS
}

assert_array() {
    is_array "$@" || return_error "'$*' is not an array"
}

assert_map() {
    is_map "$@" || return_error "'$*' is not an associative array"
}

map_print() {
    assert_arg_num -1 "$@" || return $EXIT_FAILURE

    declare -n _MAPVAR="${1#:}" || return $?
    assert_map _MAPVAR || return $EXIT_FAILURE

    set -- "${!_MAPVAR[@]}"

    printf '('
    while [[ $# -gt 0 ]]; do
        printf ' [%s]=%q ' "$1" "${_MAPVAR[$1]}"
        shift
    done
    printf ')'
}

arr_print() {
    assert_arg_num -1 "$@" || return $EXIT_FAILURE
    declare -n __INVAR="${1#:}" || return $?
    assert_arr __INVAR || return $EXIT_FAILURE

    set -- "${!__INVAR[@]}"

    printf '('
    [[ $# -gt 0 ]] && printf ' %q ' "$@"
    printf ')'
}

read_arr() {
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
        local __ARG="${1:2}"
        __OPTION="${1:1:1}"
        shift
        if [[ "${__ARG}" = '' ]]; then
            if [[ $# -eq 0 ]]; then
                write_error "no value specified for '-${__OPTION}'"
                return $EXIT_FAILURE
            fi
        else
            if [[ "${__ARG}" = '='* ]] || [[ "${__ARG}" = ':'* ]]; then
                __ARG="${__ARG:1}"
            fi
            ____ARGS+=("${__ARG}")
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

COMMON_ARRAY='Y'
