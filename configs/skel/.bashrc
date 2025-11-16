# ~/.bashrc

# Only execute in interactive shells
[[ $- != *i* ]] && return

# User environment paths
PATH="${PATH:+${PATH}:}${HOME}/.local/bin"

# Prompt color and foramtting
PS1="\[\e[0;34m\][\u@\h \W]\$ \[\e[m\]"

# Enable color output lists
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'

# Write history immediately after each cmd
PROMPT_COMMAND="history -a; history -n"

# Limit cmd history for all shells
export HISTSIZE=30
export HISTFILESIZE=50
export HISTCONTROL=ignoreboth
export HISTIGNORE="ssh *:passwd *:??:???"

# Prepend 'cd' when entering path
shopt -s autocd

# Source aliases and functions
[[ -f ${HOME}/.bash_aliases ]] && . ${HOME}/.bash_aliases

# Disable mail checking
MAILCHECK=-1

# New files only accessible by owner
umask 0077

# Limit access to bash history and config
chmod 600 ~/.bashrc
chmod 600 ~/.bash_history

