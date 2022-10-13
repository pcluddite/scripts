#!/bin/bash

if [[ "$COMMON_VARGS" = 'Y' ]]; then
    return $EXIT_SUCCESS
fi

vargs_sanitize() {
    local __POSITIONAL=()
    local __OUTVAR=

    if [[ "$1" = ':'* ]]; then
        __OUTVAR="${1#:}"
        declare -ng __SANITIZED="$__OUTVAR"
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

varg_contract_parse() {
    assert_arg_num -1 "$@"

    local FORMATTED="$1"
    local NAME="${FORMATTED%%=*}"
    local OPTIONAL='N'

    eval local DEFAULT=${FORMATTED#*=}

    if [[ "${NAME}" = '['* ]]; then
        NAME="${NAME:1}"
        OPTIONAL='Y'
    fi
    if [[ "${NAME}" = *']' ]]; then
        NAME="${NAME%%]*}"
        OPTIONAL='Y'
    fi

    local POSITION=0
    if [[ "${NAME}" = *'#'* ]]; then
        POSITION="${NAME#*#}"
        if [[ "${POSITION}" = *','* ]]; then
            POSITION="${POSITION%%,*}"
        fi
        NAME="${NAME/#${POSITION}/}"
        if [[ $(expr "$POSITION" + 0 2> /dev/null) != "$POSITION" ]]; then
            write_error "unexpected token '${POSITION}' in \"${FORMATTED}\""
            write_error 'position must be an integer'
            return $EXIT_FAILURE
        fi
    fi

    local VARG_NAME=
    local SHORT_NAME=
    if [[ "${NAME}" = *','* ]]; then
        SHORT_NAME="${NAME#*,}"
        NAME="${NAME%%,*}"
        if [[ "${SHORT_NAME}" = *','* ]]; then
            VARG_NAME="${SHORT_NAME#*,}"
            SHORT_NAME="${SHORT_NAME%%,*}"
        fi
    fi

    if [[ "${VARG_NAME}" = '' ]]; then
        VARG_NAME="VARG_${NAME}"
    fi

    local CONTRACT=(--name $NAME --short $SHORT_NAME --varname $VARG_NAME --position $POSITION --optional $OPTIONAL --default "${DEFAULT}")
    arr_print "${CONTRACT[@]}"
}

vargs_opt() {
    assert_arg_num 2 "$@" || return $EXIT_FAILURE

    local SEARCH_OPT="$1"
    shift

    if [[ "${SEARCH_OPT}" = *'=' ]]; then
        local ARGS=()
        vargs_sanitize :ARGS "$@"
        SEARCH_OPT="${SEARCH_OPT%%=*}"

        set -- "${ARGS[@]}"
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --)
                shift
                break
                ;;
            "${SEARCH_OPT}")
                shift
                printf '%q' "$1"
                return $EXIT_SUCCESS
                ;;
        esac
        shift
    done
    return $EXIT_FAILURE
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
                    local VARG_NAME=$(varg_contract --varname $CONTRACT)
                    local VARG_STATE="${VARG_NAME}_STATUS"
                    if [[ "${ARG_NAME}" = "--$(varg_contract --name $CONTRACT)" ]] || \
                       [[ "$(varg_contract --short $CONTRACT)" != '' && "${ARG_NAME}" = "-$(varg_contract --short $CONTRACT)" ]]; then
                        if [[ "${!VARG_STATE}" != '' ]]; then
                            write_error "option '${ARG_NAME}' has already been set to '${!VARG_NAME}'"
                            return $EXIT_FAILURE
                        fi
                        if [[ "${ARG_VALUE}" = '' ]]; then
                            export $VARG_NAME="$(varg_contract --default $CONTRACT)"
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
        local VARG_NAME=$(varg_contract --varname $CONTRACT)
        local VARG_STATE="${VARG_NAME}_STATUS"
        if [[ "${!VARG_STATE}" = '' ]]; then
            local POSITION=$(varg_contract --position $CONTRACT)
            if [[ "$POSITION" -eq 0 ]]; then
                if [[ $(varg_contract --optional $CONTRACT) = 'Y' ]]; then
                    echo "$CONTRACT"
                    export $VARG_NAME=$(varg_contract --default $CONTRACT)
                    export $VARG_STATE='default'
                else
                    write_error "--$(varg_contract --name $CONTRACT) is required"
                    return $EXIT_FAILURE
                fi
            else
                export $VARG_NAME=${!POSITION}
                export $VARG_STATE=$POSITION
            fi
        fi
    done <<< $EXPECTED
}

export COMMON_VARGS='Y'

. "${COMMONDEFS}"
vargs "[test,t]='hello how are you'" 'poop' -- potty fartman 'what about you?' #--test 'hi how are you'
echo ${VARG_test}