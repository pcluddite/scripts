# .bashrc

# User specific environment
export PS1='\n\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\n\$'
export EDITOR=vim

export COMMONDEFS="$(dirname ${BASH_SOURCE[0]})/common_defs.sh"


# User specific aliases and functions

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

if [[ -e "${wine_c}/Program Files/Notepad++/notepad++.exe" ]]; then
    alias notepad='env WINEPREFIX="${HOME}/.wine" wine C:\\Program\ Files\\Notepad++\\notepad++.exe'
fi
