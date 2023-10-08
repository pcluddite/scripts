#!/bin/bash

if [[ ! -v COMMONDEFS ]]; then
    COMMONDEFS="$(dirname "$0")/../common_defs.sh"
fi

if ! . "${COMMONDEFS}" ERREXIT; then
    exit 1
fi

assert_root

if [[ "$1" = '-u' || "$1" = '--uninstall' ]]; then
    if dnf remove code; then
        rm -v /etc/yum.repos.d/vscode.repo
    fi
else
    rpm --import https://packages.microsoft.com/keys/microsoft.asc
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo
    if ! dnf check-update; then
        dnf install code
    fi
fi
