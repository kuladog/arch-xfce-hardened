# 
# ~/.profile
#

# get aliases and functions
[[ -f ~/.bashrc ]] && . ~/.bashrc

# user environment paths
PATH="${PATH:+${PATH}:}${HOME}/local/.bin"
