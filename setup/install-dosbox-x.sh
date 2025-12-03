#!/bin/bash
# Copyright 2025 Timothy Baxendale (pcluddite@outlook.com)

if [[ ! -v COMMONDEFS ]]; then
    COMMONDEFS="$(dirname "$0")/../common_defs.sh"
fi

if ! . "${COMMONDEFS}" ERREXIT; then
    exit 1
fi

assert_root

OS_VERSION="${OS_VERSION:-35}"
REPO="rob72-DOSBox-X-fedora-${OS_VERSION}.repo"
FILE="/etc/yum.repos.d/${REPO}"
URL="https://copr.fedorainfracloud.org/coprs/rob72/DOSBox-X/repo/${OS_VERSION}/rob72-DOSBox-X-${OS_VERSION}.repo"

if [[ "$1" = '-u' || "$1" = '--uninstall' ]]; then
    if dnf remove dosbox-x; then
        rm -v "${FILE}"
    fi
else
    curl "${URL}" | tee "${FILE}"
    dnf makecache
    dnf install dosbox-x
fi
