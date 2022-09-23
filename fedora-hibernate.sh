#!/bin/bash

set -o errexit

. $(dirname $(readlink -f $0))/common_defs.sh

SWAP_VOLUME='/swap'

printf 'Setting up swap file for hibernate.\n'
SWAP_VOLUME=$(prompt "Enter a name for swap volume:" -d "$SWAP_VOLUME")

noop btrfs subvolume create "$SWAP_VOLUME"
printf 'Subvolume %s created\n' "$SWAP_VOLUME"
printf '\n'

SWAP_FILE="$SWAP_VOLUME/swapfile"

SWAP_SIZE=$(swapon --show=SIZE --noheading)
SWAP_SIZE="$(awk "BEGIN {print ${SWAP_SIZE/G}*2 + ${SWAP_SIZE/G}}")G"

printf 'Output of swapon:\n'
swapon
printf '\n'

SWAP_SIZE=$(prompt "Enter swapfile size:" -d "$SWAP_SIZE")
SWAP_FILE=$(prompt "Enter swapfile location:" -d "$SWAP_FILE")

noop touch "$SWAP_FILE"
noop chattr +C "$SWAP_FILE"
noop fallocate --length "$SWAP_SIZE" "$SWAP_FILE"
noop chmod 600 "$SWAP_FILE"
noop mkswap "$SWAP_FILE"

printf '%s created with size of %s\n' "$SWAP_FILE" "$SWAP_SIZE"
printf '\n'

printf 'Adding resume module to dracut configuration...\n'
#printf 'add_dracutmodules+=" resume "\n' >> /etc/dracut.conf.d/resume.conf
printf 'Rebuilding initramfs...'
noop dracut -f

SWAP_UUID=$(findmnt -no UUID -T "$SWAP_FILE")
printf 'Swapfile UUID detected to be %s\n' "'$(SWAP_UUID)'"