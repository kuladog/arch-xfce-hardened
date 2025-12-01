# ~/.bashrc

# Don't run if non-interactive
[[ $- != *i* ]] && return

# User path if directory exists
[[ -d ~/.local/bin ]] && PATH="$HOME/.local/bin:$PATH"

# Prompt color and formatting
PS1="\[\e[0;38;5;68m\]\u@\h \[\e[38;5;43m\]\W\[\e[m\]\$ "

# Prepend 'cd' when entering path
shopt -s autocd

# Write history immediately after each cmd
PROMPT_COMMAND="history -a; history -n${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

# Limit history size
export HISTSIZE=30
export HISTFILESIZE=50

# Ignore password history
export HISTCONTROL=ignoreboth
export HISTIGNORE="ssh *:passwd *:??:???"

# Limit access to bash history
[[ -f ~/.bash_history ]] && chmod 600 "$HOME/.bash_history"

# Load aliases and functions
[[ -f ~/.bash_aliases ]] && source ~/.bash_aliases

# Colored list output
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'

# Disable mail checking
MAILCHECK=-1

# New file permissions
umask 0077
