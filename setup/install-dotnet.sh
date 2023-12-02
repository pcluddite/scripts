#!/bin/bash

if [[ ! -v COMMONDEFS ]]; then
    COMMONDEFS="$(dirname "$0")/../common_defs.sh"
fi

if ! . "${COMMONDEFS}" ERREXIT; then
    exit 1
fi

assert_root

PACKAGE='dotnet-sdk-8.0'

if [[ "$1" = '-u' || "$1" = '--uninstall' ]]; then
    dnf remove "${PACKAGE}"
else
    if dnf install "${PACKAGE}"; then
        dotnet tool install --global dotnet-t4
    fi
fi
