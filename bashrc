# .bashrc

# User specific environment
export PS1='\n\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\n\$'
export EDITOR=vim

export COMMONDEFS="$(dirname ${BASH_SOURCE[0]})/common_defs.sh"


# User specific aliases and functions
