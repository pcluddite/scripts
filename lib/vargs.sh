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

vargs() {
    #if ! assert_arg_num -2 $@; then
    #    return 1
    #fi
    local EXPECTED=
    while [[ $# -gt 0 && "$1" != '--' ]]; do
        printf -v EXPECTED '%s%s\n' "${EXPECTED}" "$(vargs_parse_expected "$1")"
        shift
    done
    
    if [[ ${#EXPECTED[@]} -eq 0 ]]; then
        write_error 'there must be at least 1 expected argument'
        return $EXIT_FAILURE
    fi

    shift

    local POSITIONAL=()
    while [[ $# -gt 0 && "$1" != '--' ]]; do
        case "$1" in
            --)
                break
                ;;
            --*|-*)
                local ARG_NAME="${1%%=*}"
                local ARG_VALUE=
                if [[ "$ARG_NAME" = "$1" ]]; then
                    if [[ "$2" != '' ]] && [[ "$2" != '--' ]]; then
                        ARG_VALUE="$2"
                    fi
                else
                    ARG_VALUE="${1#*=}"
                fi
                while read LINE; do
                    CONTRACT=($LINE)
                    local VARG_NAME="VARG_${CONTRACT[0]}"
                    local VARG_STATE="VARG_STATE_${VARG_NAME}"
                    if [[ "${ARG_NAME}" = "--${CONTRACT[0]}" ]] || \
                       [[ "${CONTRACT[1]}" != '' && "${ARG_NAME}" = "-${CONTRACT[1]}" ]]; then
                        if [[ "${!VARG_STATE}" != '' ]]; then
                            write_error "option '${ARG_NAME}' has already been set to '${!VARG_NAME}'"
                            return 1
                        fi
                        if [[ "${ARG_VALUE}" = '' ]]; then
                            export $VARG_NAME=${CONTRACT[4]}
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
    exit 0
}

export COMMON_VARGS='Y'

. "${COMMONDEFS}"
vargs "[test,t]='hello how are you'" 'poop' -- --test 'hi how are you' --poop="i'm good" 'what about you?' --poop='hi'
echo ${VARG_poop} 