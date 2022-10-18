# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# User specific environment and startup programs

if command -v 'wine' &> /dev/null; then
    export WINEPREFIX=${WINEPREFIX="${HOME}/.wine"}
    for DOSDEVICE in "${WINEPREFIX}/dosdevices"/*; do
        DOSDEVICE=$(basename "${DOSDEVICE}")
        if [[ "${DOSDEVICE}" = *':' ]]; then
            export "wine_${DOSDEVICE:0:1}"="$(readlink -f "${WINEPREFIX}/dosdevices/${DOSDEVICE}")"
        fi
    done
fi

export ONEDRIVE="${HOME}/OneDrive"
export WIN31="${ONEDRIVE}/Program Files/PortableApps/DOSBoxPortable/files/win"
export WIN311="${WIN31}"
