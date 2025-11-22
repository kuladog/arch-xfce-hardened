# ~/.bashrc

# Exit if not an interactive shell
[[ $- != *i* ]] && return

# User path if directory exists
[[ -d "$HOME/.local/bin" ]] && PATH="$HOME/.local/bin:$PATH"

# Prompt color and foramtting
PS1="\[\e[0;38;5;81m\]\u@\h \[\e[38;5;121m\]\W\[\e[m\]\$ "

# Prepend 'cd' when entering path
shopt -s autocd

# Write history immediately after each cmd
PROMPT_COMMAND="history -a; history -n${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

# Limit history size
export HISTSIZE=30
export HISTFILESIZE=50

# Ignore useless history
export HISTCONTROL=ignoreboth
export HISTIGNORE="ssh *:passwd *:??:???"

# Limit access to bash history
[[ -f "$HOME/.bash_history" ]] && chmod 600 "$HOME/.bash_history"

# Source aliases and functions
[[ -f "$HOME/.bash_aliases" ]] && source "$HOME/.bash_aliases"

# Colored lists output
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'

# Disable mail checking
MAILCHECK=-1

# New file permissions
umask 0077
