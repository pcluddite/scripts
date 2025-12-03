#!/bin/bash
# Copyright 2025 Timothy Baxendale (pcluddite@outlook.com)

if [[ "$COMMON_VARGS" = 'Y' ]]; then
    return $EXIT_SUCCESS
fi

vargs_sanitize() {
    local __POSITIONAL=()
    local __OUTVAR=

    if [[ "$1" = ':'* ]]; then
        __OUTVAR="${1#:}"
        assert_identifier "${__OUTVAR}" || return $?
        declare -ng __SANITIZED="${__OUTVAR}" || return $?
        shift
    else
        declare -ag __SANITIZED
    fi

    assert_arg_num 1 "$@" || return $EXIT_FAILURE

    while [[ $# -gt 0 ]]; do
        local __NAME=''
        local __VALUE=''
        case $1 in
            --)
                shift
                break
                ;;
            -*=*)
                __NAME="${1%%=*}"
                __VALUE="${1#*=}"
                ;;
            -*)
                __NAME="$1"
                if [[ "$2" != '-'* ]] && [[ "$2" != '' ]]; then
                    __VALUE="$2"
                    shift
                fi
                ;;
            *)
                __POSITIONAL+=("$1")
                ;;
        esac

        if [[ "${__NAME}" != '' ]]; then
            __SANITIZED+=("${__NAME}")
            __SANITIZED+=("${__VALUE}")
        fi
        shift
    done

    if [[ $# -gt 0 ]]; then
        __POSITIONAL+=("$@")
    fi

    if [[ ${#__POSITIONAL[@]} -gt 0 ]]; then
        __SANITIZED+=('--')
        __SANITIZED+=("${__POSITIONAL[@]}")
    fi

    if [[ "${__OUTVAR}" = '' ]]; then
        arr_print "${__SANITIZED[@]}"
    fi
}

varg_parse_contract() {
    assert_arg_num 1 "$@" || return $?

    local __OUTVAR=
    if [[ "$1" = ':'* ]]; then
        __OUTVAR="${1#:}"
        assert_identifier "${__OUTVAR}" || return $?
        declare -gn __CONTRACT="${__OUTVAR}" || return $?
        shift
    else
        declare -A __CONTRACT=
    fi

    assert_arg_num -1 "$@" || return $?

    local __RAW="$1"
    local __OPTNAME="${__RAW%%=*}"
    local __OPTSW='N'
    local __DEFAULT="${__RAW#*=}"

    if [[ "${__OPTNAME}" = '['* ]]; then
        __OPTNAME="${__OPTNAME:1}"
        __OPTSW='Y'
    fi
    if [[ "${__OPTNAME}" = *']' ]]; then
        __OPTNAME="${__OPTNAME%%]*}"
        __OPTSW='Y'
    fi

    local __POSITION=0
    if [[ "${__OPTNAME}" = *'#'* ]]; then
        __POSITION="${__OPTNAME#*#}"
        if [[ "${__POSITION}" = *','* ]]; then
            __POSITION="${__POSITION%%,*}"
        fi
        __OPTNAME="${__OPTNAME/#${__POSITION}/}"
        if ! is_integer "${__POSITION}"; then
            errorf 'unexpected token %s in "%s": position must be an integer\n' "'${__POSITION}'" "${__RAW}"
            return $EXIT_FAILURE
        fi
    fi

    local __VARNAME=
    local __SHORTNAME=
    if [[ "${__OPTNAME}" = *','* ]]; then
        __SHORTNAME="${__OPTNAME#*,}"
        __OPTNAME="${__OPTNAME%%,*}"
        if [[ "${__SHORTNAME}" = *','* ]]; then
            __VARNAME="${__SHORTNAME#*,}"
            __SHORTNAME="${__SHORTNAME%%,*}"
        fi
    fi

    if [[ "${__VARNAME}" = '' ]]; then
        __VARNAME="VARG_${__OPTNAME}"
    fi

    declare -A __CONTRACT=([NAME]="${__OPTNAME}" [SHORT]="${__SHORTNAME}" [VAR]="${__VARNAME}" [POSITION]="${__POSITION}" [OPT]="${__OPTSW}" [DEFAULT]="${__DEFAULT}")
    arr_print
}

return $EXIT_SUCCESS

vargs() {
    local EXPECTED=
    while [[ $# -gt 0 && "$1" != '--' ]]; do
        arr CONTRACT= varg_contract_parse "$1"
        [[ $? -eq 0 ]] || return $EXIT_FAILURE
        printf -v EXPECTED '%s%s\n' "${EXPECTED}" "${CONTRACT}"
        shift
    done

    if [[ ${#EXPECTED[@]} -eq 0 ]]; then
        write_error 'there must be at least 1 expected argument'
        return $EXIT_FAILURE
    fi

    shift

    local POSITIONAL=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --)
                shift
                break
                ;;
            --*|-*)
                local ARG_NAME="${1%%=*}"
                local ARG_VALUE=
                if [[ "$ARG_NAME" = "$1" ]]; then
                    if [[ "$2" = '--' ]]; then
                        continue
                    elif [[ "$2" != '' ]]; then
                        ARG_VALUE="$2"
                    fi
                    shift
                else
                    ARG_VALUE="${1#*=}"
                fi
                while read CONTRACT; do
                    local VARG_NAME=$(vargs_opt --varname "${CONTRACT[@]}")
                    local VARG_STATE="${VARG_NAME}_STATUS"
                    if [[ "${ARG_NAME}" = "--$(vargs_opt --name "${CONTRACT[@]}")" ]] || \
                       [[ "$(vargs_opt --short "${CONTRACT[@]}")" != '' && "${ARG_NAME}" = "-$(vargs_opt --short "${CONTRACT[@]}")" ]]; then
                        if [[ "${!VARG_STATE}" != '' ]]; then
                            write_error "option '${ARG_NAME}' has already been set to '${!VARG_NAME}'"
                            return $EXIT_FAILURE
                        fi
                        if [[ "${ARG_VALUE}" = '' ]]; then
                            export $VARG_NAME="$(vargs_opt --default "${CONTRACT[@]}")"
                            export $VARG_STATE='default'
                        else
                            export $VARG_NAME="${ARG_VALUE}"
                            export $VARG_STATE='opt'
                        fi
                    fi
                done <<< $EXPECTED
                ;;
            *)
                POSITIONAL+=("$1")
                ;;
        esac
        shift
    done

    while [[ $# -gt 0 ]]; do
        POSITIONAL+=("$1")
        shift
    done

    set -- ${POSITIONAL[@]}

    while read CONTRACT; do
        local VARG_NAME=$(vargs_opt --varname "${CONTRACT[@]}")
        local VARG_STATE="${VARG_NAME}_STATUS"
        if [[ "${!VARG_STATE}" = '' ]]; then
            local POSITION=$(vargs_opt --position "${CONTRACT[@]}")
            if [[ "$POSITION" -eq 0 ]]; then
                if [[ $(vargs_opt --optional "${CONTRACT[@]}") = 'Y' ]]; then
                    declare -g $VARG_NAME="$(vargs_opt --default "${CONTRACT[@]}")"
                    declare -g $VARG_STATE='default'
                else
                    write_error "--$(vargs_opt --name "${CONTRACT[@]}") is required"
                    return $EXIT_FAILURE
                fi
            else
                declare -g $VARG_NAME="${!POSITION}"
                declare -g $VARG_STATE="${POSITION}"
            fi
        fi
    done <<< $EXPECTED
}

#COMMON_VARGS='Y'

. "${COMMONDEFS}"
vargs "[test,t]='hello how are you'" 'poop' -- potty fartman 'what about you?' #--test 'hi how are you'
echo ${VARG_test}