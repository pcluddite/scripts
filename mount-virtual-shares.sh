#!/bin/sh

SCRIPT_NAME=$(basename "$0")
SHARE_LIST=(OneDrive d)

if [[ $(id -u) -ne 0 ]]; then
    printf '%s: This script must be run as root.\n' "$SCRIPT_NAME" 1>&2
    exit 1
fi

for SHARE in ${SHARE_LIST[@]}; do
	MNT_POINT="/mnt/${SHARE}"
	if [[ $(findmnt -M "${MNT_POINT}") ]]; then
		umount "${MNT_POINT}"
	fi
	if mount -t vboxsf "${SHARE}" "${MNT_POINT}"; then
		printf 'Mounted %s -> %s\n' "'vboxsf ${SHARE}'" "'${MNT_POINT}'"
	else
		printf '%s: unable to mount vboxsf %s at %s\n' "${SCRIPT_NAME}" "${SHARE}" "${MNT_POINT}" 1>&2
	fi
done
