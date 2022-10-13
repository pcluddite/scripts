#!/bin/bash

if [[ ! -v "${COMMONDEFS}" ]]; then
    COMMONDEFS="$(dirname "$0")/common_defs.sh"
fi

if ! . "${COMMONDEFS}" ERREXIT FILEIO; then
    exit 1
fi

assert_root

OPTIONS=()
POSITIONAL=()
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --)
            shift
            break
            ;;
        -*)
            if [[ "$1" = *'='* ]]; then
                OPTIONS+=("${1%%=*}" "${1#*=}")
            elif [[ "$2" = '-*' ]] || [[ "$2" = '' ]]; then
                OPTIONS+=("$1" '')
            else
                OPTIONS+=("$1" "$2")
                shift
            fi
            ;;
        *)
            POSITIONAL+=($1)
            ;;
    esac
    shift
done

if [[ "$#" -gt 0 ]]; then
    POSITIONAL+=("$@")
fi

set -- "${OPTIONS[@]}"

VMDK_FILE=
DEV_FILE=

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --output|-o)
            VMDK_FILE="$2"
            shift
            ;;
        --device|-d)
            DEV_FILE="$2"
            shift
            ;;
        --*|-*)
            exit_error "unrecognized option '$1'"
            ;;
        *)
            POSITIONAL+=($1)
            ;;
    esac
    shift
done

set -- "${POSITIONAL[@]}"

while [[ "$#" -gt 0 ]]; do
    if [[ "${VMDK_FILE}" = '' ]]; then
        VMDK_FILE="$1"
    elif [[ "${DEV_FILE}" = '' ]]; then
        DEV_FILE="$1"
    else
        exit_error 'too many arguments'
    fi
    shift
done

if [[ 

#VBoxManage internalcommands createrawvmdk -filename "${VMDK_FILE}" -rawdisk /dev/sda