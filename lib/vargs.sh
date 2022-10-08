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

    if [[ "${NAME:0:1}" = '[' ]]; then
        NAME="${NAME:1}"
        OPTIONAL='Y'
    fi
    if [[ "${NAME:$(( ${#NAME} - 1)):1}" = ']' ]]; then
        NAME="${NAME%%]*}"
        OPTIONAL='Y'
    fi

    local SHORT_NAME="${NAME#*:}"
    local POSITION=0
    if [[ "${SHORT_NAME}" != '' ]]; then
        NAME="${NAME%%:*}"
        POSITION="${SHORT_NAME#*:}"
        if [[ "${POSITION}" != '' ]]; then
            if [[ $(expr "$POSITION" + 0 2> /dev/null) != "$POSITION" ]]; then
                write_error "unexpected token '${POSITION}' in \"${FORMATTED}\""
                write_error 'position must be an integer'
                return $EXIT_FAILURE
            fi
            SHORT_NAME="${NAME%%:*}"
        else
            POSITION=0
        fi
    fi

    printf '%s\n%c\n%d\n%c\n%s\n' "${NAME}" "${SHORT_NAME}" "${POSITION}" "${OPTIONAL}" "${DEFAULT}"
}

vargs() {
    local EXPECTED=()
    local INPUT=()

    assert_arg_num 2 $@

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --expected=*)
                EXPECTED=("${1#*=}")
                ;;
            --expected)
                if [[ "$#" -gt 1 && "${2:0:1}" != '-' ]]; then
                    EXPECTED=($2)
                    shift
                else
                    write_error "no value was specified for '$1'"
                    return $EXIT_FAILURE
                fi
                ;;
            --args=*)
                INPUT=("${1#*=}")
                ;;
            --args)
                if [[ "$#" -gt 1 && "${2:0:1}" != '-' ]]; then
                    INPUT=($2)
                    shift
                else
                    write_error "no value was specified for '$1'"
                    return $EXIT_FAILURE
                fi
                ;;
            -*)
                write_error "unrecognized option '$1'"
                return $EXIT_FAILURE
                ;;
            *)
                if [[ ${#EXPECTED[@]} -eq 0 ]]; then
                    EXPECTED=($1)
                elif [[ ${#INPUT[@]} -eq 0 ]]; then
                    INPUT=($1)
                else
                    write_error 'too many arguments'
                    return $EXIT_FAILURE
                fi
                ;;
        esac
        shift
    done
    if [[ ${#EXPECTED[@]} -eq 0 ]]; then
        write_error 'there must be at least 1 expected argument'
        return $EXIT_FAILURE
    fi
}

export COMMON_VARGS='Y'

. "${COMMONDEFS}"
vargs_parse_expected "[test:t:0]='hello how are you'"
