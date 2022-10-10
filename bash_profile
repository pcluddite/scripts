# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# User specific environment and startup programs

wine_pgrep() {
    pgrep --list-full --ignore-case 'exe' | while read -r LINE; do
        local ARGS=($LINE)
        local PID="${ARGS[0]}"
        if [[ "${ARGS[1]:1:2}" = ':\' ]]; then
            ARGS=$(cat -v "/proc/$PID/cmdline")
            echo "$ARGS"
        fi
    done
}

if command -v 'wine' &> /dev/null; then
    export WINEPREFIX=${WINEPREFIX="${HOME}/.wine"}
    for DOSDEVICE in "${WINEPREFIX}/dosdevices"/*; do
        DOSDEVICE=$(basename "${DOSDEVICE}")
        if [[ "${DOSDEVICE}" = *':' ]]; then
            export "wine_${DOSDEVICE:0:1}"="$(readlink -f "${WINEPREFIX}/dosdevices/${DOSDEVICE}")"
        fi
    done
    if [[ -e "${wine_c}/Program Files/Notepad++/notepad++.exe" ]]; then
        alias notepad="wine 'C:\\Program Files\\Notepad++\\notepad++.exe'"
    fi
fi

if command -v 'trash' &> /dev/null; then
    alias rm='trash -i'
else
    alias rm='rm -i'
fi

alias cp='cp -i'
alias mv='mv -i'

alias status='sudo systemctl status'
alias ustatus='systemctl --user status'

alias screen='tmux attach -t'
