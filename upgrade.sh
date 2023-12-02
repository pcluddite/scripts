#!/bin/bash

if [[ ! -v COMMONDEFS ]]; then
    COMMONDEFS="$(dirname "$0")/common_defs.sh"
fi

if ! . "${COMMONDEFS}" STDIO; then
    exit 1
fi

if ! assert_root; then
    exit 1
fi

dnf check-update --refresh
EXIT_STATUS=$?
if [[ $EXIT_STATUS -eq 100 ]]; then
    if dnf upgrade; then
        echo 'System will reboot in 1 minute. Re-run this script after start-up to continue upgrade.'
        shutdown -r +1 'System scheduled to reboot'
        exit 0
    fi
elif [[ $EXIT_STATUS -ne 0 ]]; then
    echo 'Upgrade could not complete'
    exit 1
fi

. /etc/os-release

NEXT_VERSION=$(( $VERSION_ID + 1 ))
echo "Preparing to upgrade to ${NAME} ${NEXT_VERSION}"

if dnf install dnf-plugin-system-upgrade; then
    if dnf system-upgrade download --releasever="${NEXT_VERSION}"; then
        YN=$(prompt_yesno -p='Upgrade packages downloaded. Reboot?')
        if [[ "$YN" == 'Y' ]]; then
            dnf system-upgrade reboot
        fi
    fi
fi

