#!/bin/bash

if [[ ! -v COMMONDEFS ]]; then
    COMMONDEFS="$(dirname "$0")/../common_defs.sh"
fi

if ! . "${COMMONDEFS}" ERREXIT; then
    exit 1
fi

assert_root

if [[ "$1" = '-u' || "$1" = '--uninstall' ]]; then
    if dnf remove powershell; then
        rm -v /etc/yum.repos.d/microsoft.repo
    fi
else
    rpm --import https://packages.microsoft.com/keys/microsoft.asc
    curl https://packages.microsoft.com/config/rhel/7/prod.repo | tee /etc/yum.repos.d/microsoft.repo
    dnf makecache
    dnf install powershell
fi
