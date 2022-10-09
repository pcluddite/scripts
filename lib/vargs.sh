#!/bin/bash

if [[ "$COMMON_VARGS" = 'Y' ]]; then
    return $EXIT_SUCCESS
fi

vargs_parse_expected() {
    assert_arg_num -1 "$@"

    local FORMATTED="$1"
    local DEFAULT="${FORMATTED#*=}"
    local NAME="${FORMATTED%%=*}"
    local OPTIONAL='N'

    if [[ "${NAME}" = '['* ]]; then
        NAME="${NAME:1}"
        OPTIONAL='Y'
    fi
    if [[ "${NAME}" = *']' ]]; then
        NAME="${NAME%%]*}"
        OPTIONAL='Y'
    fi

    local POSITION=0
    local SHORT_NAME=''
    if [[ "${NAME}" = *'#'* ]]; then
        POSITION="${NAME#*#}"
        NAME="${NAME%%#*}"
        if [[ "${NAME}" = *':'* ]]; then
            SHORT_NAME="${NAME#*,}"
            NAME="${NAME%%,*}"
        elif [[ "${POSITION}" = *','* ]]; then
            SHORT_NAME="${POSITION#*,}"
            POSITION="${POSITION%%,*}"
        fi
        if [[ $(expr "$POSITION" + 0 2> /dev/null) != "$POSITION" ]]; then
            write_error "unexpected token '${POSITION}' in \"${FORMATTED}\""
            write_error 'position must be an integer'
            return $EXIT_FAILURE
        fi
    elif [[ "${NAME}" = *','* ]]; then
        SHORT_NAME="${NAME#*,}"
        NAME="${NAME%%,*}"
    fi

    printf '%s %s %d %c %s' "${NAME}" "${SHORT_NAME}" "${POSITION}" "${OPTIONAL}" "${DEFAULT}"
}

varg_contract_name() {
    printf '%s' "$1"
}

varg_contract_shortname() {
    printf '%s' "$2"
}

varg_contract_position() {
    printf '%d' "$3"
}

varg_contract_is_optional() {
    [[ "$4" = 'Y' ]]
}

varg_contract_default() {
    printf '%s' "$5"
}

vargs() {
    #if ! assert_arg_num -2 $@; then
    #    return 1
    #fi
    local EXPECTED=
    while [[ $# -gt 0 && "$1" != '--' ]]; do
        local CONTRACT=$(vargs_parse_expected "$1")
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
                while read LINE; do
                    CONTRACT="$LINE"
                    local VARG_NAME="VARG_$(varg_contract_name "${CONTRACT}")"
                    local VARG_STATE="VARG_STATE_${VARG_NAME}"
                    if [[ "${ARG_NAME}" = "--$(varg_contract_name "${CONTRACT}")" ]] || \
                       [[ "$(varg_contract_shortname "${CONTRACT}")" != '' && "${ARG_NAME}" = "-$(varg_contract_shortname "${CONTRACT}")" ]]; then
                        if [[ "${!VARG_STATE}" != '' ]]; then
                            write_error "option '${ARG_NAME}' has already been set to '${!VARG_NAME}'"
                            return $EXIT_FAILURE
                        fi
                        if [[ "${ARG_VALUE}" = '' ]]; then
                            export $VARG_NAME=$(varg_contract_default "${CONTRACT}")
                            export $VARG_STATE='default'
                        else
                            export $VARG_NAME="${ARG_VALUE}"
                            export $VARG_STATE='set'
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
    echo "$*"
}

export COMMON_VARGS='Y'

. "${COMMONDEFS}"
vargs "[test,t]='hello how are you'" 'poop' -- --test 'hi how are you' potty -- fartman --poop="i'm good" 'what about you?'
echo ${VARG_poop} 