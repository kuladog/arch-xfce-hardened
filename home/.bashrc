#
# ~/.bashrc
#

# if not running interactively.. don't
[[ $- != *i* ]] && return

# prompt color and foramtting
PS1="\[\e[1;34m\][Arch-X \W]\$ \[\e[m\]"

# other users can't rw data
umask 077

# prepend 'cd' when entering path
shopt -s autocd

# don't store two character commands
declare -x HISTIGNORE='??'

# no duplicates or lines start with space
HISTCONTROL=ignoreboth

# limit bash command history
HISTSIZE=50
HISTFILESIZE=50

# enable color output lists
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'

# get user aliases
[[ -f ~/.aliases ]] && . ~/.aliases
